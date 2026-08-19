# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT YET PRODUCTION CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**REV-F5.5 entry baseline:** `main@a9e5d0940d5bf43d43d65589d4ad739bd02276f2`  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT MUTABLE GATE:** `REV-F5.6 — REVIEW & APPLY`  
**REV-F5.6 STATUS:** `BLOCKED PENDING EXPLICIT OWNER AUTHORIZATION`

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 LIVE checkpoint

Certified production truth after REV-F5.5:

- REV-F5.1 ingest = **PASS**;
- REV-F5.2 staging = **PASS**;
- REV-F5.3 identity rebuild/preview = **PASS**;
- REV-F5.4 canonical matching classification = **PASS**;
- REV-F5.5 fill-only enrichment preview = **PASS**;
- 6/6 source batches complete;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- classifications = **8,716 / 8,716**;
- MATCH = **296**;
- REVIEW = **6,984**;
- NEW = **1,436**;
- F5.5 MATCH patients with at least one fill-only proposal = **202**;
- F5.5 field-level enrichment preview rows = **455**;
- F5.5 policy states = **229 APPLY_ALLOWED / 23 POLICY_BLOCKED / 203 POLICY_UNDEFINED**;
- ambiguous source-value previews = **0**;
- canonical overwrite violations = **0**;
- non-MATCH enrichment previews = **0**;
- clinical-note/allergy enrichment previews = **0**;
- F5.5 apply-eligible rows = **0**;
- preview applied rows = **0**;
- canonical Apply events = **0**;
- `aos_pacientes` = **7,687**;
- canonical fingerprint = `619f20596f6f9181f96332997ee3d953`;
- F5.4 classification fingerprint = `7a2c36e1e7a3ff6fb12196cbf7bacdfd`;
- F5.5 enrichment fingerprint = `d22f2542813dcf71e767abc9e78d1021`.

## REV-F5.5 enrichment boundary

F5.5 reuses the established F5.3 fill-only `proposed_patch` field semantics and materializes them only for REV-F5.4 MATCH identities.

Every F5.5 preview row requires:

- canonical target field is empty;
- exactly one distinct historical value for that field;
- source-row provenance retained;
- human review remains mandatory;
- `apply_eligible=false`.

The current 455 field proposals are:

- Sexo **121**;
- distrito **108**;
- Fecha de nacimiento **75**;
- Ocupación **67**;
- Dirección **57**;
- Email **23**;
- N° documento **4**.

The existing apply-field policy was not widened. `Email` remains explicitly blocked; fields without policy remain undefined. Even the 229 rows whose field policy is currently allowed are not Apply-authorized by F5.5.

Potential fills for latest appointment (**201**) and acquisition channel/origin (**1**) remain deferred because their destination semantics are not yet governed by an approved canonical mapping. Phone has **0** current fill opportunities. Clinical notes/allergies remain excluded.

## Mandatory persistence proof

Every data checkpoint requires all three:

1. execution receipt;
2. direct LIVE persisted readback;
3. independent invariant query.

F5.4 and F5.5 additionally proved deterministic replay with identical semantic fingerprints across two complete runs.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock ownership — maintained.
2. REV-F5.1 exact source ingestion — **PASS**.
3. REV-F5.2 staging/manifests/replay — **PASS**.
4. REV-F5.3 identity memberships and preview — **PASS**.
5. REV-F5.4 MATCH / REVIEW / NEW classification — **PASS**.
6. REV-F5.5 fill-only enrichment preview — **PASS**.
7. REV-F5.6 governed Review & Apply with admin+2FA, dry-run, optimistic lock, canary, audit and rollback proof — **BLOCKED PENDING OWNER AUTHORIZATION**.
8. REV-F5.7 patient → sale → F3 product → F4 payment/revenue/cartera linkage.
9. REV-F5.8 real transaction coverage for 2024–2025; prohibit unsupported YoY.
10. REV-F5.9 numeric Coverage & Data Quality Report.
11. REV-F5.10 independent exact-head/live final certification; only then can REV-F6 be unblocked.

## Safety invariants

- no merge by name alone;
- phone alone does not authorize merge;
- canonical strong-field contradiction blocks MATCH;
- canonical target collision blocks automatic MATCH;
- no overwrite of populated canonical fields through F5.5;
- source patient ID and HC remain source-specific unless proven otherwise;
- `Último presupuesto` is evidence only;
- `ADELANTO` is payment evidence only;
- clinical notes/allergies stay outside automatic commercial enrichment;
- every retry reconciles persisted state first;
- no competing HIGH/CRITICAL migrations/imports/canaries;
- no Review/Apply before REV-F5.6 governance authorization.

## Cross-domain boundary

- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- F6 consumes only certified facts;
- CIA/WA must not create a second canonical customer identity.

## Main-moving policy

Before each mutable gate, re-read `main`. If `main` moves, stop new F5 writes, inspect diff, revalidate compatibility, then continue from LIVE. Never infer persistence from an execution transcript.

## Exit / handback

Do not release the lock automatically. REV-F5 releases it only after REV-F5.10 is proven from exact GitHub/CI/deploy + LIVE Supabase invariants + rollback/recovery + final documentation, or after an explicit owner-approved recoverable pause.
