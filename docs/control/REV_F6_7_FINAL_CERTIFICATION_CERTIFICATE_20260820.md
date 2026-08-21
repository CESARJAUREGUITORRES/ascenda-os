# REV-F6.7 — FINAL CERTIFICATION / UI / PERFORMANCE / ACCEPTANCE

**Status:** PASS / TECHNICALLY CERTIFIED  
**Date:** 2026-08-20 America/Lima  
**PR:** #319  
**Base main:** `6a240e82b886e372581d59df4d287af52ef2aaec`  
**Technical exact-head:** `bf2ca5406735ce32f00015d7a7654d731eadc623`

## Scope closed

REV-F6.7 closes the Revenue F6 phase without creating a new business-truth layer. The existing Sales Intelligence surface was upgraded in place from V2 presentation to the already-certified V3 analytical contract while preserving the same-origin `/api/f4/sales-intelligence-read` transport, admin + 2FA authorization boundary, read-only semantics and V2 response compatibility.

No Patient 360 redesign, no new sales facts, no new patient master, no F3/F4/F5 mutation and no REV-F7 implementation are part of this gate.

## Exact-head CI evidence

The same technical head `bf2ca5406735ce32f00015d7a7654d731eadc623` completed all required regressions successfully:

- Ascenda CI #2730 — SUCCESS
- REV-F6.0 #68 — SUCCESS
- REV-F6.1 #68 — SUCCESS
- REV-F6.2 #47 — SUCCESS
- REV-F6.3 #38 — SUCCESS
- REV-F6.4 #33 — SUCCESS
- REV-F6.5 #25 — SUCCESS
- REV-F6.6 #19 — SUCCESS
- REV-F6.7 #2 — SUCCESS
- Sales Intelligence Phase 1 #157 — SUCCESS

The earlier Phase 1 red was not a product/runtime defect: the smoke test still required the literal label `Sales Intelligence V2`. Runtime health, JS, staging isolation and write blocking were already green. The obsolete literal was aligned to V3 and the complete legacy workflow then passed.

## REV-F6.7 focal gates

F6.7 FAST acceptance passed:

- Sales Intelligence V3 UI contract;
- legacy Sales Intelligence compatibility contract;
- Patient Commercial 360 V2 compatibility;
- loading / empty / error / restricted-access states;
- responsive surface markers;
- same-origin single-request transport;
- no direct raw V3 browser access.

F6.7 isolated DB acceptance passed:

- F6.0–F6.4 certified prerequisites;
- exact F6.7 gateway migration;
- independent SQL reconciliation;
- ACL/security topology;
- five bounded gateway reads under 1,000 ms;
- idempotent replay;
- recovery to the certified F6.4 gateway topology.

## Supabase LIVE

Applied migration:

`20260821013922 rev_f6_7_ui_acceptance_gateway_v1`

Post-deploy protected boundary remained exactly:

- patients: **7,694**
- sales: **1,299**
- F3 product-sale facts: **406**
- F4 reconciliation rows: **162**

Current upstream fingerprints remain unchanged:

- F6.0 `d8a86d5787ffeaee436eabbbff502d51`
- F6.1 `cd313998c5b5b38d5cb9e2f08882b826`
- F6.2 `d977b9669b9e741e8785cd863caaf9c2`
- F6.3 `4d4f22d764a43da965caa65f864d9a0f`
- F6.4 `5c0879041eb8d21e29a3407a8197935b`
- F6.5 `7534bdd97182593788d0a8b0e980ac1d`
- F6.6 `a1959bb7bc39034efab2657607c5a45d`

This proves no migration-induced mutation of the certified Revenue truth layers.

## LIVE analytical reconciliation

2026 Sales Intelligence V3 reconciles to the canonical sales source:

- billed amount: **S/ 561,889.27**
- transactions: **1,299**
- executive revenue coverage: **100%**
- confidence: **HIGH**
- freshness: **CURRENT**
- sample size: **1,299**

Direct LIVE core execution measured **37.533 ms**, below the **1,000 ms** performance gate.

Historical transactional revenue semantics remain non-negotiable:

- 2024: `value=null / NO_CERTIFIED_SOURCE`
- 2025: `value=null / NO_CERTIFIED_SOURCE`

`NO_CERTIFIED_SOURCE != zero`.

## Security / authorization

LIVE acceptance confirms:

- invalid gateway token -> `UNAUTHORIZED`;
- private V2 compatibility base is closed to `anon` and `authenticated`;
- private V2 compatibility base remains executable by `service_role`;
- governed compatibility gateway remains browser-callable through the existing protected flow;
- raw V3 analytical function is closed to `anon` and `authenticated`;
- admin + 2FA authorization remains the authority;
- same-origin route remains unchanged;
- F6.7 is read-only.

A real user session token was deliberately not fabricated during LIVE certification. The valid governed-path behavior is covered by the isolated F6.7 DB suite; LIVE certification used invalid-token rejection plus raw service-side reconciliation to avoid generating synthetic user/auth state in production.

## Sentinel

Post-F6.7 health remains:

- OK: **9**
- UNKNOWN: **1**
- DEGRADED: **0**
- REVIEW_REQUIRED: **0**
- BROKEN: **0**

The single UNKNOWN remains `SEN-DQ-F5-005 DUPLICATE_PROFILE_DRIFT` because the requested duplicate-profile classification telemetry is not materialized. This is intentional fail-closed behavior and not an F6.7 defect.

## Decision

REV-F6.7 technical acceptance is **PASS**. No unresolved implementation defect remains in F6.7. The remaining actions are terminal repository merge and continuity synchronization only.

After PR #319 merges with the exact terminal head and post-merge readback confirms the same LIVE boundary, declare:

`REV-F6.7 — PASS / CERTIFIED — 100%`  
`REV-F6 — PRODUCTION CERTIFIED — 100%`  
`REV-F7 — NEXT / UNBLOCKED`
