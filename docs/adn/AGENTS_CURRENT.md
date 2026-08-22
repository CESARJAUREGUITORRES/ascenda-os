# ASCENDA OS — AGENTS CURRENT OVERLAY

**Applies to:** every CURRENT ASCENDA agent/chat  
**Captured:** 2026-08-22 America/Lima  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE GATE:** `WA-V2-0 — BASELINE & GOVERNANCE`

This overlay supersedes operational assumptions in historical `docs/adn/AGENTS.md` and earlier CURRENT snapshots while preserving them as provenance.

## Mandatory bootstrap

Before any write:

1. root `AGENTS.md` + `SECURITY.md`;
2. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
3. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. `docs/MEMORY_CURRENT.md`;
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
8. exact GitHub `main`, Railway status/runtime and live Supabase state;
9. the current WhatsApp/Meta/Knowledge/Revenue checkpoint only.

Historical chat statements never override CURRENT or live persisted state.

## Portfolio Controller

Declare `WORKSTREAM_ID=WHATSAPP-REVENUE-HUB-V2`.

Enforce one global HIGH/CRITICAL mutable workstream. MKT Loop 6 is PAUSED at its preserved 0/5 genuine-operation checkpoint; Revenue, CIA, KronIA and unrelated mutation remain read-only while WA owns the lane.

## WhatsApp Product Agent

Current live entry baseline:

- 15 messages = 11 inbound / 4 outbound;
- 2 conversations;
- 25 events;
- 9 outbound requests;
- 11 routing events;
- 2 active boxes (`VENTAS_GENERAL`, `WA_TEST`);
- 2 active memberships for the current single operational actor;
- 1 active assignment;
- 0 AI runs;
- human send ON;
- auto routing OFF;
- AI send OFF;
- Copilot OFF;
- auto reply OFF.

Notifications S13–S15.5 are CLOSED / 100% CERTIFIED / REGRESSION ONLY. Do not reopen them unless a current regression is proven.

## Meta / Provider Agent

Inbound signed Meta flow is historically demonstrated. Human outbound transport has historical ACCEPTED sends, but current credential/provider health is not certified. The outbound ledger contains historical `META_190` and `META_SEND_REJECTED` failures.

Before calling WhatsApp production-selling ready:

1. verify current WABA/phone/provider health without exposing credentials;
2. use a long-lived/system-user access token stored server-side only;
3. controlled allowlisted human outbound canary;
4. require provider message ID and delivery/read/failure observability;
5. preserve idempotency and customer-service-window rules.

Never place Meta tokens in chat, Git, Notion, frontend or logs.

## Human Operations Agent — WA-3

After WA-V2-0 certification, DISCOVER first:

- boxes/members;
- `whatsapp-agent` permissions;
- claim/reassign/release;
- supervisor override;
- ownership_version;
- presence/readiness;
- max_active/capacity;
- exact per-agent inbox visibility;
- no cross-owner leakage;
- routing events and queue integrity.

First multiagent canary keeps:

- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `auto_reply_enabled=false`.

Do not create boxes by sede/treatment without evidence. Evaluate `BOT_INBOX`, `VENTAS_GENERAL`, `FOLLOW_UP`, `ESCALAMIENTO_CLINICO` as the initial topology.

## Revenue Inbox UX Agent — WA-3.5

Do not mutate during WA-3. Preserve planned work only:

- smart inbox / unread / SLA / hot-lead / follow-up views;
- campaign/treatment/stage/owner filters;
- clean timeline with delivery states and separable events;
- quick replies/templates/media/notes/drafts/shortcuts;
- Agenda/call actions;
- right panel: DETAILS / COPILOT / CUSTOMER 360 / CAMPAIGN / ACTIVITY;
- notification click → Auth if needed → restore exact destination.

## Knowledge / Sales Agent

The ecosystem now contains:

- 7,702 canonical patients;
- 1,331 canonical sales;
- 5,880 leads;
- 11,911 CIA contact/email facts;
- 221 active catalog services.

WA must consume canonical truth. No second CRM/customer master/sales ledger/email ledger/agenda engine.

Knowledge authority order:

1. transactional live facts;
2. approved commercial knowledge;
3. approved enterprise docs;
4. campaign context;
5. Customer 360 facts;
6. current conversation context;
7. general LLM knowledge last.

No price, promo, availability, stock or clinical fact may be invented from general model knowledge.

## Attribution Agent

Current explicit WA attribution is 0/15 for `campaign_source`, `ad_id`, `lead_id`, and `raw_referral`.

WA-7A owns provenance ingress. Never attribute campaign/revenue solely by phone coincidence. Preserve touchpoint IDs and explicit Meta referral/ad lineage.

## Security Guardian

- use root `SECURITY.md`;
- no PII/PHI in GitHub/public artifacts;
- no secrets in docs/examples/prompts;
- no autonomous diagnosis or clinical recommendation;
- no SQL arbitrary from AI;
- exact owner / Auth V3 / 2FA boundaries remain authoritative;
- no auto-send AI before later controlled-autonomy gates.

## CI / Runner Governor

- runners are execution capacity, never source of truth;
- exact commit/diff + live post-conditions are authority;
- any unrelated `main` advance requires exact-head revalidation before the next WA mutation;
- use parallel runners only for independent validation; never parallel HIGH/CRITICAL writes.

## Historian / Memory Manager

For every material gate:

1. freeze exact GitHub evidence;
2. read live production state;
3. record persisted counters/invariants;
4. update CURRENT docs;
5. update `aos_memory` only after merge/live proof;
6. update Notion last;
7. explicitly supersede stale claims.

## Release Certifier

No WA phase is `100%` from code completion alone. Require exact-head CI, deploy, live Supabase invariants, security/rollback evidence and physical canary when the gate is user-visible or provider-dependent.
