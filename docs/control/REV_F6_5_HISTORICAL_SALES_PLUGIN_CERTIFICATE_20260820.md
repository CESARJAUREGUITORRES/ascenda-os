# REV-F6.5 — Historical Sales Plug-in — CERTIFICATE 2026-08-20

**Status:** PRE-MERGE TERMINAL CANDIDATE — LIVE + CI PASS  
**Workstream:** REV — Revenue Data & Intelligence Core  
**Phase:** REV-F6.5 — Historical Sales Plug-in  
**PR:** #315  
**Entry main:** `c73b41b318639ef09027956b3c183f8379c42e33`  
**Implementation head before certificate:** `6736b005b2e4b6ebbfeb1e3d589b3d0e48a21b30`  
**Upstream certified F6.4 fingerprint:** `b0f06d841c74ceeb231451aecdeceef2`  

## 1. Purpose and semantic boundary

REV-F6.5 certifies the dynamic Historical Sales Plug-in boundary. It does not fabricate, infer, or backfill historical transactional revenue.

The certified pipeline is:

`MANIFEST/SHA -> ROW PROVENANCE -> STAGING -> DEDUP/VALIDATION -> AOS_VENTAS-COMPATIBLE CANONICAL SALE -> F3 PRODUCT -> F5 PATIENT -> F4 FINANCIAL -> RECOMPUTE F6`.

F6.5 reuses the existing Revenue, Product, Patient Identity and Financial truth layers. It creates no parallel historical patient/product/revenue master and authorizes no direct mass insert into `aos_ventas`.

## 2. GitHub exact-head CI evidence

Implementation exact-head `6736b005b2e4b6ebbfeb1e3d589b3d0e48a21b30` passed all required pull-request workflows:

- Ascenda CI #2671 — SUCCESS
- REV-F6.0 #43 — SUCCESS
- REV-F6.1 #44 — SUCCESS
- REV-F6.2 #23 — SUCCESS
- REV-F6.3 #14 — SUCCESS
- REV-F6.4 #9 — SUCCESS
- REV-F6.5 #1 — SUCCESS

The dedicated F6.5 workflow passed:

- FAST/static Historical Sales Plug-in contract;
- isolated Postgres bootstrap;
- F6.0–F6.4 certified prerequisites;
- F6.4 regression revalidation;
- fixtures A–J;
- F6.5 DB/security/semantic/performance invariants;
- full idempotent migration replay;
- recovery restoring the exact F6.4 boundary.

## 3. Supabase LIVE migration

Applied migration ledger:

- `20260820201634` — `rev_f6_5_historical_sales_plugin_v1`

No historical source manifest was registered in LIVE and no historical business sale row was fabricated.

## 4. LIVE historical coverage truth

Current LIVE state after migration:

- manifest rows: **0**;
- certified historical sources: **0**;
- 2024: `value=null`, `source_status=NO_CERTIFIED_SOURCE`, `trust_level=UNAVAILABLE`;
- 2025: `value=null`, `source_status=NO_CERTIFIED_SOURCE`, `trust_level=UNAVAILABLE`;
- 2026: **1,299** certified transactions, billed amount **561889.27**.

`NO_CERTIFIED_SOURCE` explicitly does not mean zero revenue.

The active Sales Intelligence runtime now exposes `REV-F6.5_HISTORICAL_COVERAGE_V1` dynamically instead of treating hardcoded 2024/2025 status as the authority. The certified F6.4 runtime remains preserved as an internal base.

## 5. Deterministic fingerprint

F6.5 terminal PRE-MERGE fingerprint candidate:

`88a6dab1f3ef228eaa79f8489d6d8eb0`

It was reproduced twice in LIVE before recompute and remained the same after the governed recompute hook.

Upstream F6.4 fingerprint remained exact before/after recompute:

`b0f06d841c74ceeb231451aecdeceef2`

## 6. Protected truth / non-mutation

LIVE protected truth remained unchanged:

- patients: **7,688**;
- canonical sales: **1,299**;
- F3 product facts: **406**;
- F4 reconciliation rows: **162**;
- F6.3 fingerprint: `3f4174660107661a2c4509f6f8817d7a`;
- F6.4 sales fact rows: **1,299**.

F6.5 did not mutate `aos_pacientes`, existing canonical sales, F3, F4, F5 identity truth, or F6.0–F6.4 certified source truth.

## 7. Security

LIVE security readback PASS:

- historical manifest anon SELECT: false;
- historical manifest authenticated SELECT: false;
- source registration anon EXECUTE: false;
- source certification authenticated EXECUTE: false;
- recompute authenticated EXECUTE: false;
- internal Sales Intelligence V3 anon EXECUTE: false;
- governed V3 gateway anon EXECUTE remains true through the existing admin/2FA boundary;
- legacy `aos_paciente_360(text)` anon EXECUTE remains false.

Raw PII/PHI is not exposed by the aggregate historical coverage contract.

## 8. Performance

Repeated LIVE V3 calls after F6.5 overlay:

- global: **11.983 ms**;
- San Isidro: **8.780 ms**;
- Pueblo Libre: **7.861 ms**.

Certification target remains `<1000 ms`; no timeout increase was used.

## 9. Replay / recovery

Synthetic certification proved:

- same SHA + same immutable metadata is idempotent;
- same SHA + conflicting immutable metadata fails closed;
- uncertified source remains non-revenue;
- partial coverage is explicit;
- complete manifest coverage is still not revenue by itself;
- year isolation is preserved;
- recompute is derived-read-model only;
- recovery removes F6.5 objects and restores the exact certified F6.4 runtime boundary.

## 10. Final merge gate

This certificate becomes terminal only after:

1. this certificate + snapshot are committed atomically;
2. the new exact-head passes Ascenda CI + REV-F6.0 through REV-F6.5;
3. PR #315 is merged with `expected_head_sha` equal to that final exact-head;
4. post-merge LIVE reproduces F6.5 fingerprint `88a6dab1f3ef228eaa79f8489d6d8eb0`, preserves security/performance/protected truth and historical no-source semantics;
5. `aos_memory`, Notion and GitHub CURRENT are reconciled last.

Only then declare:

`REV-F6.5 — PASS / CERTIFIED — 100%`

`REV-F6 global = 75%`

`REV-F6.6 — Sentinel Data-Integrity Handoff = NEXT / UNBLOCKED`
