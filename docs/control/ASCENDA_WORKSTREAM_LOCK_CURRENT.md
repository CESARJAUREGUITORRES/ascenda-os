# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**Current control baseline:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21`  
**Previous lock:** `MKT-INTEGRITY-HOTFIX-V3` — Loop 5 PASS; Loop 6 NOT STARTED / PAUSED  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until REV-F5 production certification or explicit owner handoff.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 LIVE checkpoint

Fresh Supabase production truth:

- 6 source batches / 15,498 expected rows;
- **8,264 persisted source rows**;
- **7,234 remaining**;
- **1/6 staging-complete batches**;
- 3,950 provisional identity clusters;
- members 0;
- preview 0;
- apply events 0;
- structural duplicate source keys 0;
- orphan source rows 0;
- observational `aos_pacientes` count 7,685.

Per source:

- PL2024 = 3,949 / 4,192 — missing Excel 3951–4193;
- PL2025 = 1,801 / 3,053 — missing Excel 1703–1802 and 1903–3054;
- PL2026 = 993 / 993 — complete;
- SI2024 = 1,521 / 3,190 — missing Excel 1523–3191;
- SI2025 = 0 / 3,066 — missing Excel 2–3067;
- SI2026 = 0 / 1,004 — missing Excel 2–1005.

The older certified-pause checkpoint remains provenance, but this live state is the current resume contract.

## Explicit correction

Any prior assistant/chat statement claiming:

- 15,498/15,498 staging;
- 15,498 members;
- completed Review/Apply;
- `REV-F5 — PRODUCTION CERTIFIED — 100%`;
- `REV-F6 — UNBLOCKED`;

is **SUPERSEDED_BY_LIVE_TRUTH**.

The repository contains no merged REV-F5 final-certification PR after #298 and production post-conditions remain incomplete.

## Mandatory persistence proof

Every data checkpoint requires all three:

1. execution receipt;
2. direct live persisted readback;
3. independent invariant query.

Every source-batch closure additionally requires full idempotent replay of the SHA-bound source with zero new inserts/conflicts.

No tool response, timeout assumption, local loop completion or generated payload can substitute for persisted production proof.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock ownership — maintained.
2. REV-F5.1 complete all exact missing source ranges through existing private/idempotent compact ingest.
3. REV-F5.2 certify 6/6 batches, manifests, SHA, exact ranges, duplicates/orphans and full replay; require 15,498/15,498.
4. REV-F5.3 rebuild identity only after source certification; require 15,498 memberships.
5. REV-F5.4 classify every cluster as MATCH / REVIEW / NEW with evidence.
6. REV-F5.5 generate fill-only enrichment preview; no silent overwrite.
7. REV-F5.6 governed Review & Apply with admin+2FA, dry-run, canary, rollback proof and progressive safe apply.
8. REV-F5.7 certify patient → sale → F3 product → F4 payment/revenue/cartera linkage.
9. REV-F5.8 audit real transaction coverage for 2024–2025; prohibit unsupported YoY.
10. REV-F5.9 numeric Coverage & Data Quality Report.
11. REV-F5.10 independent final exact-head/live certification; only then can REV-F6 be unblocked.

## Safety invariants

- no merge by name alone;
- phone alone does not authorize merge;
- source patient ID and HC remain source-specific unless proven otherwise;
- `Último presupuesto` is evidence only;
- `ADELANTO` is payment evidence only;
- clinical notes/allergies stay outside automatic commercial enrichment;
- every retry reconciles persisted state first;
- no Google Drive, GitHub PII, new bucket, transport table or alternate uploader while the existing compact-ingest route remains usable;
- no competing HIGH/CRITICAL migrations/imports/canaries.

## Cross-domain boundary

- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- F6 will consume certified facts;
- CIA/WA must not create a second canonical customer identity.

See:

- `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`;
- `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

## Main-moving policy

Before each mutable gate, re-read `main`. If `main` moves, stop new F5 writes, inspect diff, revalidate compatibility, then continue from LIVE. Never infer persistence from an execution transcript.

## Exit / handback

Do not move the lock automatically. REV-F5 releases it only after REV-F5.10 is proven from exact GitHub/CI/deploy + live Supabase invariants + rollback/recovery + final documentation, or after an explicit owner-approved recoverable pause.
