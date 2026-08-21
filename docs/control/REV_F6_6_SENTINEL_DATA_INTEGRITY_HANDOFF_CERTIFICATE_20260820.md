# REV-F6.6 — Sentinel Data-Integrity Handoff — Terminal Certificate

**Status:** TECHNICAL LIVE ACCEPTANCE PASS / PENDING TERMINAL EXACT-HEAD CI + MERGE  
**Date:** 2026-08-20 / 2026-08-21 UTC  
**Repository:** `CESARJAUREGUITORRES/ascenda-os`  
**PR:** #317  
**Implementation exact-head accepted before terminal docs:** `b8e5b897af830cd2c0d816338d8a352a4786676c`

## 1. Scope certified

REV-F6.6 extends Sentinel with ten aggregate, zero-PII/PHI business-data integrity signals while preserving the ownership rule that Sentinel observes integrity and never becomes business truth.

The handoff is observation-only:

- no patient/sales/F3/F4/F5/F6 business-fact mutation;
- no silent auto-repair;
- no automatic F8 incident ingest;
- no PII/PHI in health envelopes, incident candidates, logs or notifications;
- missing telemetry is `UNKNOWN`, never green.

## 2. Pre-LIVE exact-head CI

Exact head `b8e5b897af830cd2c0d816338d8a352a4786676c` passed the full required suite:

| Gate | Run | Result |
|---|---:|---|
| Ascenda CI | #2715 | SUCCESS |
| REV-F6.0 Data Contract | #64 | SUCCESS |
| REV-F6.1 Patient Commercial 360 V2 | #64 | SUCCESS |
| REV-F6.2 Customer Lifecycle | #43 | SUCCESS |
| REV-F6.3 Identity Confidence + Metric Trust | #34 | SUCCESS |
| REV-F6.4 Sales Intelligence 3.0 | #29 | SUCCESS |
| REV-F6.5 Historical Sales Plug-in | #21 | SUCCESS |
| REV-F6.6 Sentinel Data-Integrity Handoff | #15 | SUCCESS |

The F6.6 DB gate passed synthetic A–X, ACL, zero-PII, Sentinel F8 compatibility, protected truth, bounded performance, full idempotent migration replay and recovery.

## 3. LIVE migrations

Applied to LIVE project `ituyqwstonmhnfshnaqz`:

- `20260820232649 rev_f6_6_sentinel_integrity_handoff_v1`
- `20260821004152 rev_f6_6_sensor_cache_performance_hotfix_v1`

The performance hotfix keeps the original full aggregate snapshot as a controlled service-only refresh path and moves Sentinel health evaluation to a private bounded cache. Statement-level dirty markers only mark aggregate domains stale; they do not modify business rows. Dirty domains remove dependent evidence so evaluation fails closed to `UNKNOWN` until governed refresh.

## 4. LIVE signal acceptance

Two consecutive health evaluations returned all ten signals with **0 `state_digest` mismatches**.

Final health summary:

- `OK = 9`
- `UNKNOWN = 1`
- `DEGRADED = 0`
- `BROKEN = 0`
- `REVIEW_REQUIRED = 0`

Signal states:

- `SEN-DQ-F5-001 SOURCE_BATCH_MISMATCH` → OK
- `SEN-DQ-F5-002 IDENTITY_MEMBERSHIP_MISMATCH` → OK
- `SEN-DQ-F5-003 IDENTITY_BRIDGE_COLLISION` → OK
- `SEN-DQ-F5-004 APPLY_WITHOUT_GOVERNANCE` → OK
- `SEN-DQ-F5-005 DUPLICATE_PROFILE_DRIFT` → UNKNOWN
- `SEN-DQ-REV-001 PRODUCT_SALE_ORPHAN` → OK
- `SEN-DQ-REV-002 RECONCILIATION_ORPHAN` → OK
- `SEN-DQ-F6-001 READMODEL_STALE` → OK
- `SEN-DQ-F6-002 COVERAGE_REGRESSION` → OK
- `SEN-DQ-360-001 PATIENT360_IDENTITY_RESOLUTION_REGRESSION` → OK

`SEN-DQ-F5-005` remains intentionally `UNKNOWN` because the requested duplicate-profile classes are not materialized as LIVE telemetry. This is the required fail-closed behavior and is not a certification defect.

## 5. Sentinel detected a real stale-readmodel condition

Immediately after the hotfix, Sentinel correctly reported `SEN-DQ-F6-001 = DEGRADED`:

- dashboard cache rows: `22`
- cache newest: `2026-08-20T21:19:17.770945+00:00`
- relevant source latest: `2026-08-21T00:09:20.63017+00:00`
- `source_newer_than_cache = true`
- `version_mismatch_count = 0`

This was not hidden or waived. The canonical derived-only refresh `aos_rev_si_refresh_v1()` rebuilt F6.4 materialized read models/dashboard cache, followed by `aos_sentinel_rev_f6_6_refresh_cache_v1()`. No business source rows were modified. The final signal returned to `OK`.

## 6. Security / zero-PII acceptance

All ten F6.6 functions are:

- `anon EXECUTE = false`
- `authenticated EXECUTE = false`
- `service_role EXECUTE = true`

The private sensor-cache table is unreadable by `anon` and `authenticated` and readable by `service_role` only.

Health and incident-candidate envelopes passed scans for forbidden identifier-bearing keys, 8/9-digit identifier-like values and email-like values.

Sentinel F8 compatibility:

- `f8_compatible = true`
- `auto_ingest = false`
- candidate count = `1` because F5-005 is intentionally UNKNOWN
- before and after candidate generation: `3 incidents / 5 incident_signals / 17 timeline rows`

Therefore candidate generation caused **zero automatic incident mutation**.

## 7. Performance acceptance

Five repeated LIVE samples, target `<1000 ms`:

| Path | Min ms | Avg ms | Max ms | Result |
|---|---:|---:|---:|---|
| F6.6 contract | 0.076 | 0.186 | 0.602 | PASS |
| F6.6 health | 1.204 | 12.765 | 58.643 | PASS |
| F6.6 cached snapshot | 0.123 | 0.160 | 0.244 | PASS |

The controlled full cache refresh measured approximately `23204.999 ms`, but it is deliberately outside the health hot path. The hot path never calls the full refresh.

## 8. Protected business truth

Boundary immediately before the LIVE hotfix and readback after hotfix + governed derived refresh:

- patients: `7694 → 7694`
- sales: `1299 → 1299`
- F3 product-sale fact rows: `406 → 406`
- F4 reconciliation rows: `162 → 162`

The increase from the earlier historical closeout baseline `7690` to `7694` patients occurred operationally **before** the hotfix terminal boundary. It is legitimate concurrent business activity and must not be reverted or attributed to REV-F6.6.

Protected fingerprints remained stable across the LIVE hotfix and derived refresh:

- REV-F6.0: `d8a86d5787ffeaee436eabbbff502d51`
- REV-F6.3: `4d4f22d764a43da965caa65f864d9a0f`
- REV-F6.4: `5c0879041eb8d21e29a3407a8197935b`
- REV-F6.5: `7534bdd97182593788d0a8b0e980ac1d`
- REV-F6.6: `a1959bb7bc39034efab2657607c5a45d`

## 9. Historical semantics preserved

Transactional historical revenue remains:

- 2024 → `source_status = NO_CERTIFIED_SOURCE`, `value = null`
- 2025 → `source_status = NO_CERTIFIED_SOURCE`, `value = null`

No historical patient source was reinterpreted as historical sales and no unavailable revenue was converted to zero.

## 10. Terminal gate

Technical implementation + LIVE acceptance are PASS. Final `REV-F6.6 PASS / CERTIFIED` declaration requires only:

1. terminal exact-head CI on the branch containing this certificate and snapshot;
2. merge PR #317 with `expected_head_sha`;
3. post-merge LIVE reconciliation;
4. continuity synchronization in order: `aos_memory 502 → Notion → GitHub CURRENT`;
5. final cross-source readback.

Snapshot: `docs/control/REV_F6_6_SENTINEL_DATA_INTEGRITY_HANDOFF_SNAPSHOT_20260820.json`.
