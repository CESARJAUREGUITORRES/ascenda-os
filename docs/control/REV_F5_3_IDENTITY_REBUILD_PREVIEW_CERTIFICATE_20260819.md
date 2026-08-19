# REV-F5.3 — IDENTITY REBUILD / PREVIEW CERTIFICATE

**Captured:** 2026-08-19 America/Lima  
**Workstream:** `REV-F5-CLOSEOUT`  
**Baseline:** `main@7128e079021a204c41e2b1d8e8ce1e8f809858e1`  
**Scope:** identity rebuild + link/enrichment preview only. This certificate does **not** authorize canonical Apply and does not certify overall REV-F5.

## Preconditions

- REV-F5.1 ingest: PASS — 15,498 / 15,498.
- REV-F5.2 source staging: PASS — 6 / 6 batches complete.
- LIVE source keys distinct: 15,498 / 15,498.
- Rebuild RPC is private: `anon=false`, `authenticated=false`, `service_role=true`.
- Canonical baseline: 7,686 rows; fingerprint `3a39e782224b832ac0e603658345567e`.
- Canonical Apply events before rebuild: 0.

## Rebuild receipt

`aos_f5_rebuild_identity_preview_v1()` returned:

- `ok=true`
- source rows = **15,498**
- members = **15,498**
- clusters = **8,716**
- previews = **8,716**
- AUTO_CANDIDATE = **408**
- REVIEW_REQUIRED = **6,872**
- UNMATCHED = **1,436**
- source-conflict clusters = **111**
- canonical mutation = **false**
- canonical patient count = **7,686**

## Membership / provenance gates

PASS:

- 15,498 members for 15,498 source rows;
- 15,498 distinct source rows represented;
- 0 orphan source rows;
- 0 source rows with multiple memberships;
- 0 null source memberships;
- 0 cluster/member-count mismatches;
- 0 empty/invalid clusters;
- 0 blank cluster keys;
- 0 duplicate cluster keys.

Per-source membership coverage is exact:

| Source | Expected | Members |
|---|---:|---:|
| PUEBLO LIBRE 2024.xlsx | 4,192 | 4,192 |
| PUEBLO LIBRE 2025.xlsx | 3,053 | 3,053 |
| PUEBLO LIBRE 2026.xlsx | 993 | 993 |
| SAN ISIDRO 2024.xlsx | 3,190 | 3,190 |
| SAN ISIDRO 2025.xlsx | 3,066 | 3,066 |
| SAN ISIDRO 2026.xlsx | 1,004 | 1,004 |
| **TOTAL** | **15,498** | **15,498** |

## Preview safety gates

PASS:

- clusters = previews = 8,716;
- 0 clusters without preview;
- 0 previews without cluster;
- 0 AUTO_CANDIDATE rows without target;
- 0 UNMATCHED rows with target;
- 0 invalid match statuses;
- all 8,716 preview rows remain `requires_human=true`;
- 0 preview rows already reviewed;
- 0 preview rows applied;
- 0 canonical apply events;
- 408 AUTO_CANDIDATE rows resolve to 408 distinct canonical targets;
- maximum AUTO clusters pointing to the same target = 1.

## Determinism proof

The complete rebuild was executed twice against unchanged certified staging.

Both receipts were identical:

- 15,498 members;
- 8,716 clusters;
- 408 AUTO_CANDIDATE;
- 6,872 REVIEW_REQUIRED;
- 1,436 UNMATCHED;
- 111 source-conflict clusters;
- canonical mutation = false.

Preview semantic fingerprint after run 1: `261ccc46f3f4862a3018c5159a784792`.  
Preview semantic fingerprint after run 2: `261ccc46f3f4862a3018c5159a784792`.

Result: **deterministic PASS**.

## Canonical boundary after rebuild

- canonical rows = **7,686**;
- canonical fingerprint = `3a39e782224b832ac0e603658345567e` — unchanged from baseline;
- preview applied rows = 0;
- canonical apply events = 0.

No automatic Apply, physical merge, overwrite or canonical mutation was performed.

## Gate result

- `REV-F5.3 — IDENTITY REBUILD — PASS`
- `REV-F5.4 — CANONICAL MATCHING / MATCH-REVIEW-NEW — UNBLOCKED / NOT STARTED`
- `REV-F5.6 — REVIEW & APPLY — BLOCKED`

The next mutable gate must revalidate CURRENT GitHub + Supabase LIVE before performing any classification/enrichment work. Apply remains explicitly prohibited until its own governed gate is reviewed and proven.