# REV-F6.5 — HISTORICAL SALES PLUG-IN V1

**Status:** IN PROGRESS / PRE-LIVE  
**Entry main:** `c73b41b318639ef09027956b3c183f8379c42e33`  
**Branch:** `data/rev-f6-5-historical-sales-plugin-20260820`  
**Scope:** future 2024/2025 transactional-source readiness without inventing historical revenue.

## Objective

Replace the active runtime's fixed 2024/2025 availability labels with a dynamic, governed Historical Coverage Contract while preserving REV-F6.4 as the certified analytical base.

No 2024/2025 sales files have been supplied at this gate. Therefore LIVE must continue to return `value=null` and `NO_CERTIFIED_SOURCE` until a real source is registered, staged, reconciled and certified.

## Architecture

F6.5 introduces a zero-PII source manifest registry:

`aos_rev_historical_source_manifest_v1`

A source is keyed by exact SHA-256 and preserves:

- source year;
- filename/site/format;
- exact SHA-256;
- source row and column count;
- schema fingerprint;
- source date range;
- manifest provenance;
- canonical-sale row coverage after future reconciliation;
- certification fingerprint/provenance/limitations.

The active pipeline remains the frozen Revenue contract:

`MANIFEST/SHA → ROW PROVENANCE → STAGING → DEDUP/VALIDATION → aos_ventas-compatible canonical sale → F3 product → F5 patient → F4 financial evidence → recompute F6`.

F6.5 itself does **not** mass-insert business rows into `aos_ventas` and does not create a second patient/product/revenue master.

## Dynamic Historical Coverage Contract

`aos_rev_historical_year_coverage_v1(year)` derives one of:

- `NO_CERTIFIED_SOURCE`;
- `SOURCE_PRESENT_NOT_CERTIFIED`;
- `CERTIFIED_PARTIAL_SOURCE_SET`;
- `CERTIFIED_EMPTY_SOURCE`;
- `CERTIFIED_PARTIAL_COVERAGE`;
- `CERTIFIED_COMPLETE`.

Every state keeps `value=null` at the source-coverage layer. Manifest availability or even complete source certification is not itself revenue value. Revenue becomes available only through canonical transaction rows and recomputed F6 read models.

`aos_rev_historical_coverage_v1()` aggregates 2024/2025 dynamically. `aos_rev_historical_status_map_v1()` and `aos_rev_historical_detailed_status_v1()` feed the active Sales Intelligence runtime.

## Runtime hardcoding removal

The certified F6.4 `aos_rev_sales_intelligence_v3(integer,text,text)` runtime is renamed once to the private internal base:

`aos_rev_sales_intelligence_v3_f6_4_runtime_base(...)`.

F6.5 then owns the active service-only `aos_rev_sales_intelligence_v3(...)` wrapper and dynamically overlays historical availability on every call. Existing F6.4 analytical logic/cache remains the base; fixed 2024/2025 labels inside that frozen implementation are no longer authoritative runtime output.

The existing admin + 2FA gateway continues calling the same public function name and therefore receives the governed F6.5 historical coverage without a parallel UI contract.

## Idempotency / provenance

`aos_rev_historical_source_register_v1(jsonb)` is service-only:

- same SHA + same immutable metadata → idempotent replay;
- same SHA + different immutable metadata → fail closed;
- invalid year/SHA/schema/count/date range → rejected.

`aos_rev_historical_source_certify_v1(...)` freezes canonical-row coverage + source fingerprint + certification provenance. Replaying the exact certification is idempotent; changing a certified source fails closed.

## Recompute

`aos_rev_historical_recompute_v1()` is service-only and calls the certified F6.4 read-model refresh. It does not ingest source rows. Future import automation must first complete canonical staging/reconciliation and only then invoke recompute.

## Security

- manifest table RLS enabled;
- no anon/authenticated table access;
- registration/certification/coverage/recompute contracts are service-only;
- active V3 remains service-only;
- browser access stays behind the existing governed admin/2FA gateway;
- legacy `aos_paciente_360` remains closed;
- no raw PII/PHI appears in aggregate coverage contracts.

## Performance

The F6.4 `<1000 ms` live RPC target remains mandatory. F6.5 adds only bounded manifest lookups and must not solve latency by raising timeouts.

## Fixtures A–J

CI explicitly tests:

A. no source / null historical value;
B. source registered but not certified;
C. same-SHA idempotent replay;
D. same-SHA conflicting metadata fail-closed;
E. invalid source year/SHA rejection;
F. certified partial canonical coverage + immutable certification;
G. year isolation;
H. certified complete source still not revenue by itself;
I. recompute idempotency + protected-truth invariants;
J. active runtime overlay + ACL + deterministic fingerprint + `<1000 ms` performance.

## Certification gate

Do not mark F6.5 PASS until:

- exact-head F6.5 FAST + DB/security/semantic/performance/recovery PASS;
- upstream F6.0–F6.4 + Ascenda CI PASS on the same exact head;
- LIVE migration + no-source readback PASS;
- protected patients/sales/F3/F4/F6.3/F6.4 unchanged;
- active 2024/2025 runtime remains `value=null` with dynamic `NO_CERTIFIED_SOURCE` when no files exist;
- F6.5 fingerprint reproduced twice;
- exact-head PR merge with `expected_head_sha`;
- post-merge LIVE fingerprint/security/performance exact;
- `aos_memory`, Notion and CURRENT reconciled last.

Only then:

`REV-F6.5 — PASS / CERTIFIED — 100%`

and `REV-F6 global = 75%`, with `REV-F6.6 — Sentinel Data-Integrity Handoff` as NEXT / UNBLOCKED.
