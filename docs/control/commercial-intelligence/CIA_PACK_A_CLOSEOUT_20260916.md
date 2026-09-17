# CIA-PANEL · PACK-A — Foundation & Live Reconciliation CLOSEOUT

**Captured:** 2026-09-16 America/Lima  
**Product:** ASCENDA CLINIC / ASCENDA OS  
**Workstream:** Commercial Intelligence & Audience OS V3  
**Base reconciled:** `main@ed20fab28ddebf917a9de660dacb2cbf14daaedb`  
**Production Railway at observation:** deployment `b40cb55e-cc4d-4502-b0f2-0b466ad868da` · `SUCCESS` · exact SHA `ed20fab28ddebf917a9de660dacb2cbf14daaedb`  
**PACK-A status:** `PASS · CLOSED WITH EXPLICIT PACK-B PREREQUISITES`  
**Mutation scope:** control/docs + CI contract hygiene only. No production SQL, frontend, runtime, transport or assignment mutation was applied by PACK-A.

## 1. Executive result

PACK-A completed the required live reconciliation against current GitHub, Supabase production, Railway and the CIA control documentation.

The existing CIA backend is materially more complete than the visible panel: identity, commercial facts, segmentation, audience DSL/resolver, presets, persisted Audience/Activation/Assignment structures, governance/readiness functions and channel-era contracts already exist. The missing product layer is mainly safe human consumption, rollout and compatibility migration rather than a greenfield data model.

PACK-A does **not** authorize PACK-B implementation automatically. The previous control text that allowed direct PACK-A → PACK-B continuation is superseded by this checkpoint and the owner's current instruction to finish PACK-A and stop before PACK-B.

## 2. Canonical identity and facts

### Identity authority — REUSE

- Canonical commercial identity: `public.aos_cia_contact_identity_v1`.
- Live population observed: **13,238 canonical contacts**.
- `contact_key` / normalized phone remains a governed bridge key; it is not treated as an eternal master identity outside the resolver contract.
- No per-channel duplicate customer truth is authorized.

### Commercial fact authority — REUSE

Observed dependency/provenance contract:

- Leads → `public.aos_leads` via `aos_cia_lead_facts_v1`.
- Calls → `public.aos_llamadas` via `aos_cia_call_facts_v1`.
- Appointments → `public.aos_agenda_citas` via `aos_cia_appointment_facts_v1`.
- Sales → `public.aos_ventas` via `aos_cia_sales_facts_v1`.
- Follow-up → `public.aos_seguimientos` via `aos_cia_followup_facts_v1`.
- Email → `aos_email_envios` + `aos_email_eventos` + `aos_emails_enviados` through `aos_cia_email_facts_v1`.
- WhatsApp bridge → `aos_wa_messages_v1` through `aos_cia_whatsapp_bridge_v1`.
- Composite commercial read-model → `aos_cia_commercial_facts_v1`.
- Segmentation → `aos_cia_commercial_facts_v1` + `aos_cia_current_segmentation_policy_v1` through `aos_cia_customer_segments_v1`.

No competing fact ledger should be introduced in PACK-B.

## 3. Audience resolver and filter dictionary

### Resolver contract — REUSE + REPAIR performance/freshness

Authoritative RPCs observed:

- `aos_cia_audience_validate_v1(p_filter jsonb)`
- `aos_cia_audience_count_v2(p_filter jsonb)`
- `aos_cia_audience_preview_v2(p_filter jsonb, p_limit integer, p_offset integer)`
- `aos_cia_audience_explain_v2(p_filter jsonb, p_contact_key text)`

The preview RPC caps a page to **100 rows**, but the current resolver computes the complete matching key set before pagination. Therefore browser-side fetch of the full 13k population is neither required nor authorized.

### Filter registry — PASS

- **73/73 governed filters mapped**.
- Missing mappings: **0**.
- Missing sources: **0**.
- Type mismatches: **0**.
- Filters without operators: **0**.
- Existing presets observed: **10**, all validating/resolving during the PACK-A check.

The governed dictionary covers the intended CIA dimensions, including lead/campaign, calls, appointments, sales/purchases, product/service, follow-up/debt/recurrence, segmentation/tier/lifecycle/engagement, recency, geography/branch and channel-related eligibility context where available.

## 4. Segmentation freshness — REPAIR before interactive PACK-B rollout

The audience resolver reports `segment_cache_refreshed_at = 2026-08-14`.

A live reconciliation against current segmentation logic found material cache drift:

- **1,692 contacts missing from the segment runtime cache** relative to the current live population.
- **2,454 lifecycle mismatches** against the current live segmentation calculation.

This means the filter registry is structurally complete, but tier/lifecycle/engagement filters must not be presented as freshly current until the segment runtime cache refresh contract is repaired, rerun and read back.

**PACK-B prerequisite P1:** repair/refresh the governed segment runtime cache and prove coverage + freshness + semantic parity before relying on segmentation filters for assignment decisions.

## 5. Audience / Activation / Assignment persistence — REUSE, not yet adopted live

The production schema contains the persisted CIA structures required for reusable audiences, snapshots/activations and assignment-era governance. During PACK-A, the human product path showed little/no current production adoption of these newer structures; they must therefore be integrated incrementally rather than assumed to be the live Call Center authority.

Contract remains:

`Audience definition/version → immutable activation/snapshot when required → channel context/eligibility → assignment/lease → advisor work view → governed outcomes`.

These concepts must remain distinct. Audience ≠ Activation ≠ Assignment ≠ Work View ≠ Request/Approval ≠ Execution.

## 6. Current Call Center compatibility boundary

### Legacy runtime — LEGACY, MUST PRESERVE AS FALLBACK DURING PACK-B

The current human Call Center surface still uses `admin-calls.html` and historical queue tabs translated into `tipo_cola` modes such as `global`, `campana`, `tipificacion`, `no_asistio` and related legacy modes.

Production still contains **4 advisors in `global` mode** while the newer governed assignment rollout is not the active universal authority (`global_enabled=false` in the newer path observed during reconciliation).

Therefore PACK-B may not delete or silently replace Global Logic. Migration must be parallel and reversible until advisor-level parity is proven.

### Security/compatibility debt — CRITICAL REPAIR SEQUENCE

The current `admin-calls.html` path still performs a direct browser `PATCH` on `aos_cola_config`, and production retains an `ALL` policy broad enough for `anon/authenticated` compatibility.

Do **not** revoke the policy first; that would break the current UI.

**PACK-B prerequisite P2 / required migration order:**

1. introduce a governed server/RPC gateway for queue configuration;
2. migrate the admin UI to that gateway;
3. run legacy-equivalence + advisor smoke;
4. only then harden/revoke the broad direct-write RLS compatibility path;
5. retain rollback/fallback until the new path is certified.

## 7. Performance baseline — REPAIR before count-on-every-keystroke UX

Observed `EXPLAIN (ANALYZE, BUFFERS)` on preset `LEADS_UNWORKED_7D`:

- `aos_cia_audience_count_v2`: approximately **2.91 s**.
- `aos_cia_audience_preview_v2(... limit 25 ...)`: approximately **1.66 s** and used temp buffers.

This is usable for deliberate actions but not for naive count requests on every filter keystroke.

**PACK-B prerequisite P3:** builder UX must use debounce/single-flight/cancellation, explicit Apply/Preview semantics where appropriate, bounded preview pages, and resolver/cache optimization if benchmark remains above interactive budget. Never solve this by increasing client/server timeouts.

## 8. Channels/readiness

### Email — REUSE

Historical CIA F16 Email Integration remains production-certified at its demonstrated boundary. Email activation still requires its own current consent/suppression/context preflight; transactional appointment email remains separate from Email Marketing.

### WhatsApp — REUSE ONLY AS CERTIFIED BRIDGE / FAIL CLOSED

The observed CIA WhatsApp bridge contained only **82 rows** and was dominated by evidence from roughly two canary conversations; observed identity rows were `UNRESOLVED`. This is not a reusable marketing-audience identity base and must not be promoted into one.

WhatsApp transport/conversation remains owned by the separate Conversations/WhatsApp workstream. CIA may consume only its certified identity/context bridge. No live CIA WhatsApp activation may be claimed until the current transport/canary/webhook/idempotency readiness is independently certified.

Production autonomous WhatsApp remains `SAFE-OFF`.

## 9. Frontend/read-model classification

### REUSE

- Existing Auth V3/app-session pattern.
- Server-side strong-token gateway pattern already used by Sales Intelligence V3.
- Explicit frontend states: loading / empty / error / ready.
- Trust metadata pattern: coverage / confidence / freshness / sample.
- Existing Audience DSL/RPC contracts and persisted CIA backend structures.

### REPAIR

- Segment cache freshness/coverage drift.
- Audience resolver interactive performance.
- Direct browser queue-config mutation and broad compatibility RLS.
- Human adoption/visibility of persisted Audience/Activation/Assignment structures.
- Explicit bridge between saved audiences and governed Call Center assignment while preserving Global fallback.

### LEGACY

- `admin-calls.html` tab/`tipo_cola` queue routing as current compatibility runtime.
- Direct `aos_cola_config` browser mutation path.
- Global Logic for unassigned/default workload until governed assignment parity is proven.

### MISSING for the modern human product surface

- Dedicated responsive Audience Control Center builder/library in the current visible admin shell.
- Governed queue-config gateway consumed by the admin UI.
- Clear freshness warning/repair path for stale segmentation-dependent filters.
- Certified saved-audience → controlled assignment → advisor work-view human flow on the current September runtime.

## 10. PACK-B exact implementation delta — frozen, NOT EXECUTED

When PACK-B is explicitly started, its first implementation loop must be prerequisite-first:

1. **P1 Segment freshness:** refresh/repair segment runtime cache; prove coverage and parity.
2. **P2 Queue governance:** add governed `aos_cola_config` mutation gateway, migrate UI, then harden RLS after smoke.
3. **P3 Resolver UX/performance:** benchmark and optimize only where needed; add debounce/single-flight/bounded pagination.
4. Build Audience Builder/Library on existing 73-filter resolver contracts; do not invent a second filter engine.
5. Save/version/reopen using existing persisted Audience authority.
6. Add controlled Audience → Assignment bridge using existing assignment contracts.
7. Keep legacy Global Logic as fallback for users/workloads not yet governed by V3 assignment.
8. Human Canary #1: one saved audience → one advisor → exact work visibility → no source duplication → outcome readback.

No PACK-C channel-send implementation is included in this delta.

## 11. CI hygiene discovered during closeout

The exact-head closeout exposed repository-level CI drift, repaired without changing product behavior:

- Booking V3.2 gate + production smoke used prohibited `ubuntu-latest`; both now use the canonical self-hosted Zero-Cost runner.
- CONV L0/L1/L2 and P0 governance tests assumed Conversations must always own the active mutable lock; they now accept an explicit transfer to CIA only when `CONV-001` is preserved and SAFE-OFF remains explicit.
- Booking V3.2 still asserted the retired advisor-link modal; it now validates the current `booking-link-center-v37.js` / `aos_booking_advisor_link_dashboard_v38` authority.

These are CI/control repairs only: no booking runtime, Conversations runtime, provider dispatch, database state or customer data was changed.

## 12. Exit gate readback

- Current-state map: **PASS**.
- Canonical identity authority: **PASS**.
- Commercial fact provenance: **PASS**.
- Governed filter dictionary: **PASS · 73/73**.
- Audience resolver contract: **PASS**, with performance repair prerequisite.
- Segment freshness: **DEGRADED / FAIL-CLOSED FOR FRESHNESS CLAIMS** until P1.
- Call Center compatibility map: **PASS**, with P2 security migration required.
- F17/F18/channel readiness: **known and bounded**; Email certified at historical/current demonstrated boundary, WhatsApp live activation not certified by PACK-A.
- Exact PACK-B delta: **FROZEN**.
- Production mutation residue from PACK-A: **0**.

## 13. Final PACK-A decision

**PACK-A = CLOSED / PASS WITH EXPLICIT PREREQUISITES.**

This is a successful reconciliation closeout, not a claim that all legacy debt is gone. The point of PACK-A is precisely to prevent a big-bang frontend/assignment cutover on top of stale segmentation, an ungoverned legacy mutation path or an interactive query storm.

**STOP BOUNDARY:** do not start PACK-B from this checkpoint unless the owner explicitly starts the next pack. PACK-B must begin with P1/P2/P3 before the Audience Control Center human canary.
