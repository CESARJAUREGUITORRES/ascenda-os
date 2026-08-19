# REV-F5.2 — SOURCE STAGING CERTIFICATE

**Captured:** 2026-08-19 America/Lima  
**Workstream:** `REV-F5-CLOSEOUT`  
**Scope:** source ingestion/staging only. This certificate does **not** certify overall REV-F5 and does not assert identity rebuild, matching, enrichment or canonical apply.

## Certified source universe

| Source | Expected | Staged | Status |
|---|---:|---:|---|
| PUEBLO LIBRE 2024.xlsx | 4,192 | 4,192 | PASS |
| PUEBLO LIBRE 2025.xlsx | 3,053 | 3,053 | PASS |
| PUEBLO LIBRE 2026.xlsx | 993 | 993 | PASS |
| SAN ISIDRO 2024.xlsx | 3,190 | 3,190 | PASS |
| SAN ISIDRO 2025.xlsx | 3,066 | 3,066 | PASS |
| SAN ISIDRO 2026.xlsx | 1,004 | 1,004 | PASS |
| **TOTAL** | **15,498** | **15,498** | **PASS** |

All six manifests retain 27 source columns and their previously registered SHA-256 source identity.

## Persistence proof

Each completed source passed the REV-F5 source-closeout contract:

1. execution receipts from `aos_f5_ingest_compact_rows_v1`;
2. direct Supabase LIVE persisted readback;
3. independent structural invariant checks;
4. full idempotent replay with all source rows resolving as existing and zero new inserts/conflicts.

## Global audit gate 1

PASS conditions proven:

- 6 source batches;
- 15,498 expected rows;
- 15,498 persisted rows;
- 6/6 `staging_complete` with metadata row count exact;
- source columns = 27 for all six;
- registered source SHA identities match the six manifests;
- exact per-source row ranges;
- 0 structural duplicate `(batch_id, source_row_num)` keys;
- 0 orphan source rows;
- `identity_cluster_members = 0`;
- `patient_link_preview = 0`;
- `canonical_apply_events = 0`.

## Global audit gate 2

A separately constructed expected-row universe was compared with persisted source rows.

PASS:

- expected total = 15,498;
- actual total = 15,498;
- missing = 0;
- extra = 0;
- bad multiplicity = 0;
- F5 members = 0;
- previews = 0;
- apply events = 0;
- temporary private transport rows = 0;
- temporary PGP rows = 0;
- temporary gzip rows = 0;
- temporary credential rows = 0.

## Canonical-data boundary

This staging closeout did not execute identity rebuild, MATCH/REVIEW/NEW, enrichment preview or canonical apply. `aos_pacientes`, Revenue F3/F4 facts and other canonical business domains were not intentionally mutated by the staging path.

## Gate result

- `REV-F5.1 — INGEST COMPLETE — PASS — 15,498/15,498`
- `REV-F5.2 — SOURCE STAGING CERTIFIED — PASS — 6/6`
- `REV-F5.3 — IDENTITY REBUILD — UNBLOCKED / NOT STARTED`

The next mutable step must revalidate exact CURRENT GitHub/deploy + Supabase LIVE and then execute the existing governed identity rebuild only if this staging certificate has not regressed.