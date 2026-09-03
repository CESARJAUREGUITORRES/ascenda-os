# WA-L7 — WhatsApp / AI Cost Intelligence Contract

**Workstream:** `WA-L7`  
**GitHub authority:** issue `#449`  
**ENTRY baseline:** `main@4a34f0f982f7d740f3d0817a04a6d7442a9f826e`  
**Governance lock acquisition:** `ae796fb6357a36bbc9714844fb7aac4ff4521f65`  
**Branch:** `wa-l7-cost-intelligence-20260903`  
**Safety:** `AUTO_OFF · kill switch engaged · autonomous send=false · CANARY NOT AUTHORIZED`

## 1. Objective

WA-L7 converts already-existing WhatsApp provider pricing metadata and AI usage telemetry into a governed, reproducible and conversation-scoped cost read model.

It does **not** create a second attribution model, identity resolver, booking authority, sales truth or autonomous-send authority.

Authoritative dependency chain:

`provider cost evidence + AI run telemetry → governed effective-dated pricing authority → conversation_id cost reconciliation → WA-L6 strong-key journey → booking / attendance / explicit sale / revenue KPIs`.

## 2. Existing authorities reused

### Meta / WhatsApp

`aos_wa_messages_v1` remains the canonical normalized message ledger and already persists provider-observed:

- `pricing_category`;
- `pricing_model`;
- `billable`;
- `provider_message_id`;
- `conversation_id`.

WA-L7 does not change webhook parsing or message persistence.

### AI

`aos_wa_ai_runs_v1` remains the append-only AI execution ledger and already persists:

- `conversation_id`;
- provider;
- main model;
- safety model;
- prompt/completion/total token counts;
- latency;
- legacy runtime `estimated_cost_usd`.

WA-L7 does not rewrite historical AI run rows.

### Revenue journey

`aos_wa_l6_attribution_journey_v1` remains the strong-key authority for:

`provider touchpoint → conversation_id → booking/rebook → appointment_id → attendance → explicit venta_id_match → canonical venta_id`.

No L7 cost or revenue linkage may use phone, contact name, username or BSUID alone.

## 3. Pricing authority

`aos_wa_l7_pricing_authority_v1` is append-only and effective-dated.

Every monetary rate requires:

- provider;
- pricing kind;
- model;
- category where applicable;
- market scope;
- currency;
- rate shape;
- `authority_grade`;
- evidence reference;
- validity start/end;
- authenticated 2FA administrator provenance.

Supported authority grades:

- `VERIFIED` — evidence-backed rate permitted to produce monetary `KNOWN` cost;
- `LEGACY_ESTIMATE` — explicitly non-authoritative rate that may support `PARTIAL` visibility only.

No implicit/default provider price exists. Missing or unmapped pricing is not converted to zero.

The governed append RPC is `aos_wa_l7_pricing_authority_append_v1(text,jsonb)` and requires `admin-whatsapp` or `admin-marketing` with 2FA.

## 4. Meta cost semantics

`aos_wa_l7_meta_cost_events_v1` is a derived read-only view over outbound normalized WhatsApp messages.

Rules:

1. `billable=false` from the provider is an explicit **KNOWN zero** (`PROVIDER_NON_BILLABLE`). This is not a guessed rate.
2. `billable=true` becomes monetary `KNOWN` only when an effective `VERIFIED` pricing row matches the provider category/model.
3. `billable=true` with only a legacy-estimate authority remains `PARTIAL`.
4. Missing billable/pricing evidence or missing governed rate remains `UNKNOWN`.
5. No provider price is fabricated from an ad name, campaign name, phone, contact identity or hard-coded fallback.

## 5. AI cost semantics

`aos_wa_l7_ai_cost_events_v1` verifies historical WA-4 AI telemetry against the governed pricing authority.

Current WA-4 history stores aggregate prompt/completion tokens for the main + safety model pair after a successful safety pass. Therefore:

- deterministic/no-provider executions are known zero;
- zero tokens + zero runtime estimate are known zero;
- a single governed model can be recalculated exactly;
- main + safety can be recalculated exactly when both effective verified rates are identical;
- when main and safety rates differ but historical token usage is not split per model, WA-L7 preserves the existing runtime estimate as `PARTIAL` with reason `AI_USAGE_NOT_SPLIT_BY_MODEL`;
- missing governed pricing never upgrades a runtime estimate to authoritative `KNOWN` cost.

This prevents false precision while preserving historical observability.

## 6. Cost completeness

All cost surfaces use three explicit states:

- `KNOWN` — monetary value is directly proven or exactly governed;
- `PARTIAL` — useful evidence exists but one or more components are not authoritative/comparable;
- `UNKNOWN` — monetary cost cannot be resolved without fabrication.

Unknown is never silently rendered as zero.

A legitimate zero is possible only from explicit semantics such as:

- provider `billable=false`;
- deterministic/no-provider AI work;
- no outbound messages / no AI runs in the scoped conversation.

## 7. Conversation-scoped cost RPC

`aos_wa_l7_conversation_cost_v1(uuid)`:

- accepts exactly one `conversation_id`;
- aggregates Meta and AI cost only for that conversation;
- reports known/partial/unknown counts and reasons;
- refuses to sum incompatible non-zero currencies;
- returns `COST_CURRENCY_MISMATCH_REQUIRES_FX` rather than inventing an FX conversion.

It is service-role-only. Browser roles cannot execute it directly.

## 8. Strong-key journey KPI RPC

`aos_wa_l7_journey_cost_v1(uuid)` consumes the scoped cost RPC and the WA-L6 journey.

It deduplicates appointment and explicit sale IDs so multiple provider touchpoints cannot double-count outcome metrics.

KPIs:

- cost / conversation;
- cost / booking;
- cost / attendance;
- cost / sale;
- revenue / cost.

Revenue/cost is emitted only when the revenue and cost currencies are directly comparable. Otherwise it returns null plus `REVENUE_COST_CURRENCY_MISMATCH_REQUIRES_FX`.

No FX table is introduced in L7.

## 9. UI / runtime contract

Admin API:

`GET /api/wa/conversations/:conversation_id/cost`

Boundary:

- existing `admin-whatsapp` panel authorization;
- active admin user;
- 2FA required;
- service-role call stays server-side;
- exact UUID only.

The WhatsApp sidebar adds a read-only Cost Intelligence mini-panel showing:

- total cost + completeness state;
- Meta cost;
- AI cost;
- billable message count;
- AI run count;
- bookings / rebooks;
- attendances;
- sales / revenue;
- cost per booking / attendance / sale;
- revenue/cost or explicit non-comparability reason.

## 10. Performance isolation

P0 #432 / ASCENDA reliability doctrine is binding.

WA-L7 therefore introduces:

- no trigger on `aos_wa_messages_v1`;
- no trigger on `aos_wa_ai_runs_v1`;
- no trigger on booking/Agenda/Sales ledgers;
- no materialized view;
- no synchronous refresh;
- no pricing/cost enrichment in inbox-list reads;
- exact conversation predicate pushdown;
- existing conversation indexes for messages, AI runs and booking operations;
- lazy cost loading only for the selected conversation;
- 15-second UI cost TTL/coalescing while message/inbox polling remains independent;
- cost failure that cannot hide or block the core conversation/messages UI.

Dedicated CI enforces a 3-second statement timeout on scoped cost RPC canaries and verifies expected strong-key indexes.

## 11. Recovery

The L7 rollback may structurally remove the empty L7 layer before governed pricing history exists.

Once any pricing-authority row exists, recovery fails closed with:

`WA_L7_RECOVERY_BLOCKED_PRICING_HISTORY`.

The rollback never deletes or rewrites:

- WA message ledger;
- AI run ledger;
- booking operations;
- Agenda;
- Sales;
- L6 attribution evidence.

## 12. Production deployment rule

Production deployment is additive and dormant:

1. merge exact certified head;
2. deploy runtime/UI from merged lineage;
3. apply exact merged L7 migration to Supabase PROD;
4. do **not** seed synthetic pricing, attribution, booking or sale rows;
5. leave pricing authority empty unless a separate evidence-backed pricing administration action is required;
6. perform live read-only cost/safety readback;
7. revalidate cross-module performance and data integrity;
8. preserve `AUTO_OFF` and kill switch engaged.

Current provider rows with explicit `billable=false` can legitimately resolve to known zero with an empty pricing authority. Billable rows without a verified rate remain unknown/partial.

## 13. Out of scope

WA-L7 does not authorize:

- `AUTO_OFF → CANARY`;
- kill-switch disengagement;
- autonomous routing/reply/send;
- direct LLM → Meta authority;
- direct LLM → SQL authority;
- broadcast/bulk send;
- L8/L9/L10 work;
- soft identity attribution;
- provider price fabrication;
- synthetic production business/cost rows;
- rewrite of Marketing Attribution V2.
