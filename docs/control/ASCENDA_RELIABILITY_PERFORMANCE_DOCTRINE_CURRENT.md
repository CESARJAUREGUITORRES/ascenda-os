# ASCENDA OS — RELIABILITY & PERFORMANCE DOCTRINE CURRENT

**Captured:** 2026-09-02 America/Lima  
**Scope:** all HIGH/CRITICAL ASCENDA workstreams  
**Applies to:** WhatsApp, Agenda, Call Center, Marketing, Patients/Identity, Sales, Commissions, Revenue, CIA and shared background/runtime infrastructure  
**Status:** MANDATORY REGRESSION BOUNDARY · PRE-L4 FREEZE

## Why this exists

ASCENDA has repeatedly demonstrated the same systemic risk: functionality can be correct in isolation while degrading another panel through shared database pressure, duplicated reads, analytic work in operational hot paths, stale runtime behavior or unsafe identity shortcuts. A local PASS is therefore not sufficient.

> **CODE PASS != DEPLOY PASS != PROD PASS.**
>
> A user-visible or load-sensitive change closes only after exact-head CI, deploy proof, live backend invariants, cross-module regression and realistic production smoke/readback.

## Core architecture rule

**Critical path first; analytics later; background retreats.**

Operational synchronous actions must resolve only the facts required for the action. Historical analytics, lifecycle, attribution, identity scoring and other expensive enrichments must not block booking, call handling, Patient 360 core rendering, sales reads or autonomous WhatsApp authority checks.

## Non-negotiable guardrails

1. **No global analytic views inside operational writes or critical reads.** Lifecycle/history/attribution/global identity materialization stays out of booking, call, Patient 360 core, sale and WA authority hot paths unless strictly required.
2. **Do not raise `statement_timeout` to hide slow SQL.** Browser `anon` remains approximately 3 s; this is a design budget.
3. **Push predicates down.** Prefer phone-, patient-, period-, site-, advisor-, conversation- or entity-scoped reads.
4. **Parity before optimization.** SQL/identity/attribution replacements require 0 unexplained differences before PROD.
5. **No legacy + new duplicate generation.** When V2/V4/new authority owns output, obsolete reads may not continue consuming Supabase.
6. **Single-flight and selective serialization.** Identical reads coalesce; heavy reads sharing a graph/dataset do not fan out unnecessarily.
7. **Never cache failures.** Cache successful reads only; never cache 5xx, 52x, SQLSTATE 57014, provider or transport failures.
8. **Browser abort is not PostgreSQL cancellation.** UI may discard stale callbacks, but must not assume server work vanished.
9. **Heavy enrichment is independently survivable.** Operational core must remain usable if analytics/enrichment fails or is deferred.
10. **Annual/global analytics stay off monthly/operational critical paths.** History/LTV/cohorts lazy-load and quiesce.
11. **Background retreat is shared infrastructure.** Cron, notification claims, caches and non-critical jobs back off during degradation.
12. **Cold path matters.** Warm-cache success cannot certify a first-load browser path.
13. **Do not run heavy diagnostics during an active business incident.** Use targeted read-only probes first.
14. **Identity remains fail-closed.** No merge/link by name alone, no merge/link by phone alone, no fuzzy phone proximity, no silent overwrite of canonical phone/email/document.
15. **Historical identity is provenance, not permission to overwrite.** Historical PHONE/EMAIL/DOCUMENT may resolve or enrich identity only through governed alias/conflict rules.
16. **FUSIONADO targets are never valid live identity targets.** Stale historical aliases must not route traffic or authority to fused records.

## Mandatory remediation / optimization sequence

1. Capture **LIVE baseline**: API/Postgres logs, `pg_stat_statements`, latency, calls, buffers, error rate.
2. Identify exact endpoint/RPC; do not patch from visual perception alone.
3. Run `EXPLAIN (ANALYZE, BUFFERS)` on the real failing case when safe.
4. Locate the dominant hotspot.
5. Design a scoped fast path with identical business semantics.
6. Prove parity before mutation.
7. Branch from exact `main`.
8. Require dedicated gate + relevant transversal CI/Performance Guard/Audit.
9. Anti-drift immediately before merge; use `expected_head_sha` when available.
10. Deploy code and DB migration only from merged lineage.
11. Canary under real boundary: writes with `BEGIN -> real path -> assertions -> ROLLBACK`; reads with real role/timeout and cold behavior where possible.
12. Human LIVE smoke when the defect depends on browser, concurrency, cache/runtime or real workflow.
13. Read back HTTP status, Postgres errors, latency, persistence/rollback and residual rows.
14. Run the cross-module regression matrix.
15. Only then mark **PRODUCTION CERTIFIED**.

## Proven lessons — Call Center / Agenda

- `prepare_action` could return 200 while governed `commit_action` timed out; success of one stage does not certify the transaction.
- `customer lifecycle` analytics did not belong in synchronous booking commit.
- Phone-scoped identity + indexed operational facts reduced critical work from seconds to milliseconds without changing semantics.
- Required booking canary: `prepare -> commit/confirm -> llamada + agenda + action COMPLETE -> ROLLBACK`.
- A UI 500 does not prove partial persistence; verify residual rows.
- Agenda and Call Center are shared critical infrastructure for WhatsApp. L4/L5 changes cannot degrade their latency or transactional consistency.

## Proven lessons — Marketing

- Legacy generation + V4.2 + annual History/LTV created duplicate load.
- History/LTV runs lazily, not once per month.
- Attribution/Intent/Detail must not compete in unnecessary parallel bursts.
- Indexes reduce buffers but do not cure repeated global materialization.
- First/cold access is part of the SLO.
- Month switching must not trigger annual/global fan-out or cache failures.

## Proven lessons — Sales / Commissions

REV-PERF demonstrated that performance improvements can preserve financial truth when the query graph is scoped rather than semantically rewritten.

- Monthly Sales uses period-scoped materialized bases and preserves legacy filter semantics.
- Annual Sales reuses one annual base instead of rescanning the same universe repeatedly.
- Commissions derives month/ranking from one advisor-year base; canonical commission tables/rules remain authority.
- `rankingTop` was additive only; financial totals and commission semantics remained unchanged.
- Performance remediation made **no write to `aos_ventas`** and did **not** increase timeouts.
- Every future WA change must preserve Sales/Commissions totals, ownership, commission lineage and responsive browser reads.

## Proven lessons — Patient 360

P0 #436 proved that a canonical record can exist correctly while its UI fails because synchronous enrichment exceeds the browser budget.

- Canonical patient row was cheap; the failure came from serial heavy enrichments exceeding `anon=3s`.
- `aos_patient_360_current_v3` now owns the operational core only.
- Identity confidence and lifecycle are governed deferred enrichments, one section per request.
- UI renders the operational patient before enrichment.
- Enrichment loads serially (`IDENTITY_CONFIDENCE -> LIFECYCLE`), not concurrent fan-out.
- Selection-generation guards prevent stale callbacks from overwriting a newly selected patient.
- No heavy V3 retry, no polling, no timeout inflation.
- No phone/document fallback for canonical identity.
- **Operational patient data must remain visible even if analytical enrichment is unavailable.**

This pattern applies directly to WhatsApp: conversation authority/dispatch must not wait on non-essential analytics.

## Proven lessons — Historical Patient Identity / REV-F5.11

- 15,498 historical source rows remain immutable provenance and are fully accounted for.
- Existing canonical contacts were protected; historical data did not mass-overwrite phone/email/document.
- Deterministic existing-patient resolution uses strong evidence and current non-FUSIONADO targets only.
- Phone alone remains insufficient to auto-link.
- Conflicting aliases remain explicit `CONFLICT`; ambiguity is not hidden for convenience.
- Only a small HIGH-confidence subset was safe for deterministic new-patient creation.
- Historical aliases are now useful to future CRM/WhatsApp identity resolution without becoming a second patient master.

WhatsApp must consume this governed identity bridge rather than invent a parallel identity matcher.

## Proven lessons — Supabase / infrastructure

- Separate provider/API Gateway degradation from project compute capacity before upgrade decisions.
- Optimize software first and certify provider stability before concluding compute is undersized.
- Restart is exceptional recovery, not performance architecture.
- Provider/compute upgrades require reproducible capacity evidence after software containment.

## Mandatory cross-module regression matrix for WhatsApp L4+

Every L4/L5+ change touching runtime, Supabase, identity, Agenda, booking, notifications, provider dispatch, cron/background, sales truth or attribution must demonstrate:

### Agenda
- governed create/edit/status path functional;
- no browser 404/500/schema-cache regression;
- booking path transactionally consistent;
- no additional heavy analytic dependency introduced.

### Call Center
- next-lead critical path prioritized;
- prepare + governed commit/confirm within budget;
- no lifecycle/global identity work returned to the write path;
- background/calendar reads do not fan out ahead of lead work.

### Marketing
- month switch has no legacy+new duplicate reads;
- annual analytics do not repeat per month;
- no cached 500/timeout;
- no heavy-RPC burst competing with revenue traffic.

### Sales / Commissions
- monthly/year Sales contracts preserve exact totals and filters;
- commission rules/ownership/lineage unchanged;
- no new duplicate polling/fan-out;
- critical browser reads remain healthy under concurrent WA activity.

### Patients / Patient 360
- canonical patient search + operational Patient 360 render remains healthy;
- phone/email remain visible when present;
- deferred enrichments may fail independently without hiding the core record;
- no canonical identity fallback or unsafe auto-merge is introduced.

### Identity
- current non-FUSIONADO patient master remains authority;
- historical aliases are provenance/supporting evidence;
- phone-only, name-only and conflicting identity remain fail-closed;
- no alias resolves to FUSIONADO/null targets.

### WhatsApp safety
Until the separate L4 authority transition is explicitly authorized and certified:
- authority mode = `AUTO_OFF`;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- no provider autonomous dispatch;
- no direct LLM->Meta authority;
- no direct LLM->SQL authority.

### Background / shared Supabase pressure
- non-critical jobs retreat during degradation;
- no job success clears another subsystem's cooldown;
- no new burst of shared reads competes with Agenda/Call Center/Patients/Sales/WA;
- recent Postgres/API logs remain free of new timeout/lock amplification attributable to the change.

## L4-specific certification boundary

L4 may be developed while `AUTO_OFF`, but it cannot be certified or moved toward CANARY merely because its own tests pass.

Before any L4 exit:
1. revalidate exact current `main`;
2. snapshot safety flags and provider dispatch state;
3. prove global kill switch + authority modes fail closed;
4. prove allowlist enforcement before provider dispatch;
5. prove duplicate/cooldown/idempotency/budget/rate/max-turn controls;
6. prove clinical and identity handoff boundaries;
7. run full cross-module matrix above;
8. inspect shared Supabase/Postgres pressure after the test window;
9. preserve `AUTO_OFF` unless a **separate explicit authorization** permits CANARY.

## Performance budget guidance

A 3 s browser timeout does not make 2.9 s acceptable.

- strive for sub-second hot paths where practical;
- target p95 comfortably below 2 s for critical browser RPCs;
- evaluate latency + buffers + request count + error rate together;
- record cold and warm behavior separately;
- for WA authority checks, prefer deterministic/scoped facts and defer non-essential analytics.

## WhatsApp continuation rule

The next eligible HIGH/CRITICAL workstream is WA-L4, currently `NOT STARTED · AUTO_OFF · SAFE-OFF`.

This doctrine is a transversal entry and exit gate. **A WA phase is not complete if it makes Agenda, Call Center, Marketing, Sales/Commissions, Patients/Identity or shared Supabase pressure regress.**

L4 Authority + Kill Switch remains a separate authorization boundary. Development may proceed under `AUTO_OFF`; transition to CANARY requires its own explicit authorization and production evidence.
