# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F6 ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Current main at REV-F6.6 entry:** `589f790b72b9373fa983f745f7e4d9c0e3090b4d`  
**REV-F6.5 certification merge:** `ad2a879c895177d375fac89c64911ce3ea12f49a`  
**ACTIVE LOCK:** `REV-F6-CLOSEOUT`  
**CURRENT GATE:** `REV-F6.6 — Sentinel Data-Integrity Handoff / IN PROGRESS`  
**ACTIVE BRANCH:** `data/rev-f6-6-sentinel-integrity-handoff-20260820`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — 100%` · fp `f81a1b8fcfe010cd5254c4ab2e6048d2`  
**REV-F6.1:** `PASS / CERTIFIED — 100%` · fp `cd313998c5b5b38d5cb9e2f08882b826`  
**REV-F6.2:** `PASS / CERTIFIED — 100%` · fp `d977b9669b9e741e8785cd863caaf9c2`  
**REV-F6.3:** `PASS / CERTIFIED — 100%` · fp `186a1da2c29b498dad26223ae264adea`  
**REV-F6.4:** `PASS / CERTIFIED — 100%` · fp `54c07961f191147860f6acd3a3e85c2a`  
**REV-F6.5:** `PASS / CERTIFIED — 100%` · fp `88957cec3d785e4931a8f834c0259a91`  
**REV-F6 global:** `75%` until REV-F6.6 terminal certification  
**REV-F6.6:** `IN PROGRESS`  
**REV-F6.7:** `BLOCKED until REV-F6.6 PASS`  
**REV-F7:** `BLOCKED until REV-F6.6 + REV-F6.7 complete`

GitHub CURRENT + Supabase LIVE remain authoritative. `REV-F6-CLOSEOUT` is the only mutable HIGH/CRITICAL lane.

## REV-F6.5 certified input

PR #316 is merged. Terminal exact-head before merge: `0cfdc71cfe5b1110be3ceaab952f184f926cf0a7`. Final exact-head CI was 7/7 SUCCESS: Ascenda CI #2680, REV-F6.0 #49, REV-F6.1 #49, REV-F6.2 #28, REV-F6.3 #19, REV-F6.4 #14, REV-F6.5 #6.

Supabase LIVE hardening migration: `20260820211638 rev_f6_5_rev_f6_0_fingerprint_isolation_v1`.

Historical 2024/2025 transactional sales remain `value=null / NO_CERTIFIED_SOURCE`. REV-F6.5 terminal LIVE baseline at handoff: patients **7,690**, sales **1,299**, F3 **406**, F4 **162**.

## REV-F6.6 execution contract

Purpose: register and implement aggregate zero-PII data-integrity sensors for certified F5/F3/F4/F6 boundaries while keeping Sentinel observation-only.

Canonical signal contract: `docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`.

Implementation rules:

- reuse Sentinel F2 registry extension semantics and existing F8 incident schema;
- do not rewrite Sentinel F1–F13;
- no automatic incident ingest;
- no auto-repair;
- no business-table mutation;
- missing telemetry = `UNKNOWN`, never `OK`;
- sensor payloads contain counts/status/contract IDs/timestamps/digests only;
- no names, phones, emails, documents, clinical data, messages, payment references, raw rows or secrets.

Canonical signal set:

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

LIVE discovery found that the requested `AUTO_ELIGIBLE_EXACT / REVIEW_STRONG / BLOCK_CONFLICT / NO_MERGE` duplicate-profile telemetry is not currently materialized. Therefore `SEN-DQ-F5-005` must remain `UNKNOWN` until that telemetry exists; it must not false-green.

No REV-F6.6 production migration may be applied until dedicated Zero-Cost DB/security/semantic/replay/recovery, upstream REV-F6.0–F6.5 regression, Sentinel F8 regression and Ascenda CI pass on the exact branch head.
