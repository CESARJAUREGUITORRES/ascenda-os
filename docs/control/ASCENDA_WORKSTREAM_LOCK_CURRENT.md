# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT YET PRODUCTION CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**Entry control baseline:** `main@7d96eb9d39bb7bb2c6b23bb82e9a225f29843d17`  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT MUTABLE GATE:** `REV-F5.5 — ENRICHMENT PREVIEW`  
**REV-F5.6 REVIEW & APPLY:** `BLOCKED`

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 LIVE checkpoint

Certified production truth after REV-F5.4:

- REV-F5.1 ingest = PASS;
- REV-F5.2 staging = PASS;
- REV-F5.3 identity rebuild/preview = PASS;
- REV-F5.4 canonical matching classification = PASS;
- 6/6 source batches complete;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- F5.4 classifications = **8,716 / 8,716**;
- MATCH = **296**;
- REVIEW = **6,984**;
- NEW = **1,436**;
- unclassified clusters = 0;
- classification orphans = 0;
- source orphans = 0;
- preview applied rows = 0;
- canonical Apply events = 0;
- observational `aos_pacientes` CURRENT count = **7,687**;
- canonical fingerprint = `619f20596f6f9181f96332997ee3d953`;
- semantic F5.4 classification fingerprint = `7a2c36e1e7a3ff6fb12196cbf7bacdfd`.

The `aos_pacientes` count moved externally from 7,686 at the F5.3 certificate to 7,687 before F5.4. F5 Apply events remained zero. F5.4 therefore rebuilt the preview against CURRENT before classifying; no F5 canonical mutation occurred.

## REV-F5.4 safety correction

The F5.3 internal preview contained 408 `AUTO_CANDIDATE`. REV-F5.4 introduced a separate private classification layer and conservatively downgraded **112** of those candidates to REVIEW when canonical strong-field contradiction and/or target collision was detected.

Final operational taxonomy:

- `MATCH` = strong compatible evidence and no blocking conflict/collision;
- `REVIEW` = ambiguous, conflicting, tied or collision-prone identity;
- `NEW` = no supported canonical candidate.

All 111 source strong-identifier conflict clusters remain REVIEW. No MATCH is authorized by name alone or phone alone.

## Mandatory persistence proof

Every data checkpoint requires all three:

1. execution receipt;
2. direct LIVE persisted readback;
3. independent invariant query.

REV-F5.4 additionally proved deterministic replay: two complete classifications returned identical counts and semantic fingerprint.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock ownership — maintained.
2. REV-F5.1 complete exact source ingestion — **PASS**.
3. REV-F5.2 certify staging/manifests/replay — **PASS**.
4. REV-F5.3 rebuild identity memberships and preview — **PASS**.
5. REV-F5.4 classify MATCH / REVIEW / NEW conservatively — **PASS**.
6. REV-F5.5 generate fill-only enrichment preview; no silent overwrite — **NEXT / UNBLOCKED**.
7. REV-F5.6 governed Review & Apply with admin+2FA, dry-run, canary, rollback proof and progressive safe apply — **BLOCKED**.
8. REV-F5.7 certify patient → sale → F3 product → F4 payment/revenue/cartera linkage.
9. REV-F5.8 audit real transaction coverage for 2024–2025; prohibit unsupported YoY.
10. REV-F5.9 numeric Coverage & Data Quality Report.
11. REV-F5.10 independent final exact-head/live certification; only then can REV-F6 be unblocked.

## Safety invariants

- no merge by name alone;
- phone alone does not authorize merge;
- canonical strong-field contradiction blocks MATCH;
- canonical target collision blocks automatic MATCH;
- source patient ID and HC remain source-specific unless proven otherwise;
- `Último presupuesto` is evidence only;
- `ADELANTO` is payment evidence only;
- clinical notes/allergies stay outside automatic commercial enrichment;
- every retry reconciles persisted state first;
- no competing HIGH/CRITICAL migrations/imports/canaries;
- no Apply before REV-F5.6 governance gate.

## Cross-domain boundary

- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- F6 will consume certified facts;
- CIA/WA must not create a second canonical customer identity.

## Main-moving policy

Before each mutable gate, re-read `main`. If `main` moves, stop new F5 writes, inspect diff, revalidate compatibility, then continue from LIVE. Never infer persistence from an execution transcript.

## Exit / handback

Do not release the lock automatically. REV-F5 releases it only after REV-F5.10 is proven from exact GitHub/CI/deploy + LIVE Supabase invariants + rollback/recovery + final documentation, or after an explicit owner-approved recoverable pause.
