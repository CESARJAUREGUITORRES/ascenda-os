# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Current main at REV-F6.7 entry:** `6a240e82b886e372581d59df4d287af52ef2aaec`  
**REV-F6.6 certification merge:** `0f7b9d4c6867b420e49156b9651664fac92481c0`  
**REV-F6.6 terminal exact-head:** `0aa45e2c0d478fdac11a6afeb9e9f7d981662091`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.7 — Certification / UI / Performance / Acceptance / IN PROGRESS`  
**ACTIVE BRANCH:** `data/rev-f6-7-final-certification-20260820`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — 100%`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%`  
**REV-F6.4:** `PASS / CERTIFIED — 100%`  
**REV-F6.5:** `PASS / CERTIFIED — 100%`  
**REV-F6.6:** `PASS / CERTIFIED — 100%` · fp `a1959bb7bc39034efab2657607c5a45d`  
**REV-F6 global:** `87.5% until REV-F6.7 terminal certification`  
**REV-F6.7:** `IN PROGRESS`  
**REV-F7:** `BLOCKED until REV-F6.7 completes`

GitHub CURRENT + Supabase LIVE remain authoritative. `REV-F6-CLOSEOUT` remains the only mutable HIGH/CRITICAL lane.

## REV-F6.6 certified input

PR **#317** merged with `expected_head_sha=0aa45e2c0d478fdac11a6afeb9e9f7d981662091` to certification `main@0f7b9d4c6867b420e49156b9651664fac92481c0`. Final docs-only synchronization moved `main` to `6a240e82b886e372581d59df4d287af52ef2aaec` without changing application code or Supabase.

F6.6 terminal exact-head CI was **8/8 SUCCESS**: Ascenda CI #2719, F6.0 #66, F6.1 #66, F6.2 #45, F6.3 #36, F6.4 #31, F6.5 #23, F6.6 #17.

LIVE baseline at F6.7 entry:

- patients **7,694**;
- sales **1,299**;
- F3 **406**;
- F4 **162**;
- F6.0 `d8a86d5787ffeaee436eabbbff502d51`;
- F6.1 `cd313998c5b5b38d5cb9e2f08882b826`;
- F6.2 `d977b9669b9e741e8785cd863caaf9c2`;
- F6.3 `4d4f22d764a43da965caa65f864d9a0f`;
- F6.4 `5c0879041eb8d21e29a3407a8197935b`;
- F6.5 `7534bdd97182593788d0a8b0e980ac1d`;
- F6.6 `a1959bb7bc39034efab2657607c5a45d`.

Sentinel terminal health: **9 OK + 1 UNKNOWN + 0 DEGRADED + 0 BROKEN**. The only UNKNOWN remains `SEN-DQ-F5-005` because requested duplicate-profile telemetry is not materialized. Missing telemetry must never false-green.

Historical transactional revenue remains:

- 2024: `value=null / NO_CERTIFIED_SOURCE`;
- 2025: `value=null / NO_CERTIFIED_SOURCE`.

## REV-F6.7 execution contract

REV-F6.7 is the terminal product/certification gate. It may make only the minimum governed read-path/UI changes required to expose already-certified F6 intelligence truthfully. It must not create a parallel analytics master or mutate patients, sales, F3, F4 or F5 business truth.

Entry discovery found a real certification gap: the backend V3 contract already exposes `metric_trust` with coverage, confidence, freshness and sample size, but the active `admin-sales-intelligence.html` surface remained labeled V2 and did not visibly expose that trust metadata.

F6.7 therefore owns only this bounded cutover:

- preserve `/api/f4/sales-intelligence-read` as the sole browser read request;
- preserve existing admin + 2FA + explicit panel authorization;
- preserve the existing RPC name consumed by `server-f4.js`;
- make the certified V2 gateway a private authorization/compatibility base;
- return V3 analytics + V2-compatible keys through the governed same-origin entrypoint;
- upgrade the existing UI in place to Sales Intelligence V3;
- display coverage/confidence/freshness/sample-size/source-status truthfully;
- add explicit loading/empty/error/responsive states;
- preserve known Patient 360 workflows unchanged;
- keep raw V3/read models browser-closed;
- no direct `.supabase.co` browser read and no N+1 secondary fetch.

Formal gate contract: `docs/control/REV_F6_7_FINAL_CERTIFICATION_V1.md`.

## Terminal acceptance requirements

Before any LIVE F6.7 migration:

1. dedicated F6.7 FAST UI/privacy/compatibility PASS;
2. dedicated F6.7 isolated DB reconciliation/security/performance/replay/recovery PASS;
3. existing Sales Intelligence UI contract PASS;
4. existing Patient 360 UI contract PASS;
5. Ascenda CI + F6.0–F6.6 upstream regressions PASS on the exact branch head;
6. fresh LIVE anti-drift readback PASS.

LIVE acceptance must independently reconcile executive billed amount/transaction count and monthly totals against canonical `aos_ventas`, prove bounded latency <1000 ms, preserve ACL/2FA topology, preserve historical null semantics and prove no protected business mutation.

Only after certificate/snapshot, terminal exact-head CI, protected merge, post-merge LIVE reconciliation and continuity synchronization may REV-F6 close as `PRODUCTION CERTIFIED — 100%`.

REV-F7 remains blocked during this entire loop. Do not start it automatically.
