# REV-F6.6 — Sentinel Data-Integrity Handoff — Impact Report

**Date:** 2026-08-20 America/Lima  
**Entry main:** `589f790b72b9373fa983f745f7e4d9c0e3090b4d`  
**Branch:** `data/rev-f6-6-sentinel-integrity-handoff-20260820`  
**Risk:** HIGH — cross-domain read-only integrity telemetry.

## Objective

Implement aggregate zero-PII integrity sensors for certified Revenue/F5/F6 contracts while keeping Sentinel observation-only. No automatic incident ingest and no business-data remediation are introduced.

## Runtime / data impact

No Node runtime-chain or browser surface changes. The existing Sentinel F8 incident engine is reused through a sanitized candidate adapter only; F8 is not modified.

Additive service-role-only functions:

- `aos_rev_f6_6_integrity_baseline_v1()`
- `aos_sentinel_rev_f6_6_signal_envelope_v1(...)`
- `aos_sentinel_rev_f6_6_evaluate_v1(jsonb)`
- `aos_sentinel_rev_f6_6_snapshot_v1()`
- `aos_sentinel_rev_f6_6_integrity_health_v1()`
- `aos_sentinel_rev_f6_6_incident_candidates_v1()`
- `aos_rev_f6_6_contract_v1()`

No triggers and no business-table DML.

## Signal scope

`SEN-DQ-F5-001`, `SEN-DQ-F5-002`, `SEN-DQ-F5-003`, `SEN-DQ-F5-004`, `SEN-DQ-F5-005`, `SEN-DQ-REV-001`, `SEN-DQ-REV-002`, `SEN-DQ-F6-001`, `SEN-DQ-F6-002`, `SEN-DQ-360-001`.

`SEN-DQ-F5-005` is deliberately `UNKNOWN` in current LIVE because the requested duplicate-profile classes (`AUTO_ELIGIBLE_EXACT`, `REVIEW_STRONG`, `BLOCK_CONFLICT`, `NO_MERGE`) are not materialized as a current telemetry source. Missing telemetry is never treated as OK.

## Security

All F6.6 functions are revoked from `public`, `anon`, and `authenticated`; `service_role` is the only direct EXECUTE role. `SECURITY DEFINER` functions use `search_path=''`. Envelopes contain aggregate counts, states, contract IDs, timestamps, safe refs and digests only. Adapter has `auto_ingest=false`.

## Tests / rollback

Static scope and secret guards; synthetic A–X state matrix; zero-PII scan; UNKNOWN semantics; deterministic state digest; existing F8 regression and isolated replay/dedup compatibility; protected patients/sales/F3/F4 and F6.0/F6.3/F6.4/F6.5 fingerprints; <1000 ms isolated gate; migration replay; rollback dropping only F6.6 functions.

`REV-F6-CLOSEOUT` remains the only mutable HIGH/CRITICAL lane. Sentinel F1–F13 remains closed/regression-only.
