# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Current main at REV-F6.7 entry:** `0f7b9d4c6867b420e49156b9651664fac92481c0`  
**REV-F6.6 certification merge:** `0f7b9d4c6867b420e49156b9651664fac92481c0`  
**REV-F6.6 terminal exact-head:** `0aa45e2c0d478fdac11a6afeb9e9f7d981662091`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.7 — Certification / UI / Performance / Acceptance = NEXT / UNBLOCKED`  
**ACTIVE BRANCH:** `NONE — REV-F6.7 not started`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — 100%`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%`  
**REV-F6.4:** `PASS / CERTIFIED — 100%`  
**REV-F6.5:** `PASS / CERTIFIED — 100%`  
**REV-F6.6:** `PASS / CERTIFIED — 100%` · fp `a1959bb7bc39034efab2657607c5a45d`  
**REV-F6 global:** `87.5%`  
**REV-F6.7:** `NEXT / UNBLOCKED`  
**REV-F7:** `BLOCKED until REV-F6.7 completes`

GitHub CURRENT + Supabase LIVE remain authoritative. `REV-F6-CLOSEOUT` remains the only mutable HIGH/CRITICAL lane.

## REV-F6.6 terminal certification

PR **#317** merged with `expected_head_sha=0aa45e2c0d478fdac11a6afeb9e9f7d981662091` to certification `main@0f7b9d4c6867b420e49156b9651664fac92481c0`.

Terminal exact-head CI on `0aa45e2c...` was **8/8 SUCCESS**:

- Ascenda CI **#2719**
- REV-F6.0 **#66**
- REV-F6.1 **#66**
- REV-F6.2 **#45**
- REV-F6.3 **#36**
- REV-F6.4 **#31**
- REV-F6.5 **#23**
- REV-F6.6 **#17**

Supabase LIVE migrations:

- `20260820232649 rev_f6_6_sentinel_integrity_handoff_v1`
- `20260821004152 rev_f6_6_sensor_cache_performance_hotfix_v1`

Certificate: `docs/control/REV_F6_6_SENTINEL_DATA_INTEGRITY_HANDOFF_CERTIFICATE_20260820.md`  
Snapshot: `docs/control/REV_F6_6_SENTINEL_DATA_INTEGRITY_HANDOFF_SNAPSHOT_20260820.json`

## Sentinel data-integrity terminal state

Canonical registry contains **10 zero-PII signals**:

- `SEN-DQ-F5-001 SOURCE_BATCH_MISMATCH`
- `SEN-DQ-F5-002 IDENTITY_MEMBERSHIP_MISMATCH`
- `SEN-DQ-F5-003 IDENTITY_BRIDGE_COLLISION`
- `SEN-DQ-F5-004 APPLY_WITHOUT_GOVERNANCE`
- `SEN-DQ-F5-005 DUPLICATE_PROFILE_DRIFT`
- `SEN-DQ-REV-001 PRODUCT_SALE_ORPHAN`
- `SEN-DQ-REV-002 RECONCILIATION_ORPHAN`
- `SEN-DQ-F6-001 READMODEL_STALE`
- `SEN-DQ-F6-002 COVERAGE_REGRESSION`
- `SEN-DQ-360-001 PATIENT360_IDENTITY_RESOLUTION_REGRESSION`

Final LIVE health after canonical read-model refresh: **9 OK + 1 UNKNOWN + 0 DEGRADED + 0 BROKEN**. The only UNKNOWN is `SEN-DQ-F5-005`, because `AUTO_ELIGIBLE_EXACT / REVIEW_STRONG / BLOCK_CONFLICT / NO_MERGE` telemetry is not materialized. Missing telemetry must never false-green.

Security and safety terminal state:

- F6.6 control/sensor functions are service-role-only;
- private sensor cache is browser-closed;
- zero-PII/PHI scans PASS;
- `auto_repair=false`;
- `auto_incident_ingest=false`;
- F8 compatibility PASS;
- Sentinel counters remained **3 incidents / 5 signals / 17 timeline**, proving no auto-ingest.

Performance hot path PASS under the **1,000 ms** gate across repeated LIVE calls:

- contract max **0.602 ms**;
- health max **58.643 ms**;
- snapshot max **0.244 ms**.

The slow full refresh remains outside the health hot path by design. A real `READMODEL_STALE` condition was detected after legitimate operational patient growth, then resolved through the canonical derived read-model refresh plus F6.6 cache refresh without business-source mutation.

## Post-merge LIVE reconciliation

Protected truth after merge:

- patients **7,694**;
- sales **1,299**;
- F3 **406**;
- F4 **162**;
- patients created after certification merge timestamp: **0**;
- sales created after certification merge timestamp: **0**.

The increase from **7,690 → 7,694 patients** occurred operationally before the REV-F6.6 certification merge and must not be reverted or attributed to F6.6.

Current LIVE fingerprints at post-merge reconciliation:

- F6.0 `d8a86d5787ffeaee436eabbbff502d51`
- F6.1 `cd313998c5b5b38d5cb9e2f08882b826`
- F6.2 `d977b9669b9e741e8785cd863caaf9c2`
- F6.3 `4d4f22d764a43da965caa65f864d9a0f`
- F6.4 `5c0879041eb8d21e29a3407a8197935b`
- F6.5 `7534bdd97182593788d0a8b0e980ac1d`
- F6.6 `a1959bb7bc39034efab2657607c5a45d`

Historical transactional revenue remains:

- 2024: `value=null / NO_CERTIFIED_SOURCE`
- 2025: `value=null / NO_CERTIFIED_SOURCE`

`NO_CERTIFIED_SOURCE != zero` remains non-negotiable.

## Next gate

`REV-F6.7 — Certification / UI / Performance / Acceptance` is **NEXT / UNBLOCKED**. REV-F7 remains blocked until REV-F6.7 is terminally complete. Do not start another mutable HIGH/CRITICAL workstream while REV-F6-CLOSEOUT owns the lock.
