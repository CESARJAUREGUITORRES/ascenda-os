# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT YET PRODUCTION CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**REV-F5.6 entry baseline:** `main@3c208712e136b4618b6618b7044096811b273f74`  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**REV-F5.6 STATUS:** `PASS — GOVERNED LOW-RISK REVIEW & APPLY`  
**NEXT MUTABLE GATE:** `REV-F5.7 — HISTORICAL JOIN`  

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 LIVE checkpoint after REV-F5.6

- REV-F5.1 ingest = **PASS**;
- REV-F5.2 staging = **PASS**;
- REV-F5.3 identity rebuild/preview = **PASS**;
- REV-F5.4 canonical matching = **PASS**;
- REV-F5.5 enrichment preview = **PASS**;
- REV-F5.6 governed Review & Apply = **PASS**;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- enrichment previews = **455** across **202** MATCH patients;
- final REV-F5.6 policy = **229 APPLY_ALLOWED / 226 POLICY_BLOCKED / 0 POLICY_UNDEFINED**;
- applied LOW-risk fields = **229 / 229**;
- blocked fields applied = **0 / 226**;
- applied distribution = **Sexo 121 / distrito 108 / departamento 0 / ciudad 0**;
- F5 Apply events = **230 total / 229 active / 1 exact canary rollback**;
- event ↔ canonical mismatches = **0**;
- event ↔ preview mismatches = **0**;
- invalid before/after hash events = **0**;
- active events outside allowlist = **0**;
- canonical patients = **7,688**;
- final canonical fingerprint = `eee5a57717937a4f77049b3aebd8c525`.

The canonical patient count moved externally from 7,687 to 7,688 before the first F5.6 canary while F5 still had zero reviews and zero Apply events. F5.6 stopped, rebuilt/revalidated F5.3→F5.5 against CURRENT and proved the external row did not change the 296/6,984/1,436 classification or the 455 enrichment proposals.

## REV-F5.6 governance boundary

F5.6 uses a field-level v2 path on top of the existing F5 classification, enrichment preview and Apply-event ledger.

Every mutation requires:

- service-role transport only;
- active hierarchy-1 admin;
- `two_factor=true`;
- live non-revoked `PASSWORD_2FA` app session;
- REV-F5.4 `MATCH` with no blocking canonical/source conflict or collision;
- one-value F5.5 provenance;
- explicit field review;
- LOW-risk live policy;
- canonical field still empty;
- optimistic review snapshot hash;
- locked target row;
- before/after canonical row hashes;
- private audit event.

Only these fields are Apply-allowed in REV-F5.6:

- `Sexo`;
- `distrito`;
- `departamento`;
- `ciudad`.

Identity anchors, birth date, potentially stale address/occupation, unresolved acquisition/latest-visit mappings and clinical/free-text data remain blocked.

## Canary and rollback proof

A single `Sexo` canary passed DRY_RUN, APPLY and exact ROLLBACK before expansion.

- pre-canary global fingerprint = `7ee00cb855f253c52c464b1d49eec289`;
- target before hash = `7ccfca60d309dfdd5936e0d98fae43924947b06384327979ac08737448d99df4`;
- target after hash = `90521400b8c1598e3a21f073ea78f43838e8471fbaef82a8b034e8ba37b5a103`;
- rollback hash = exact before hash;
- post-rollback global fingerprint = exact pre-canary fingerprint;
- active events after rollback = 0;
- rolled-back canary event retained in ledger = 1.

Two implementation defects were caught fail-closed before unsafe expansion:

1. dynamic SQL quoting in the first canary call — transaction aborted before mutation and canonical fingerprint stayed unchanged;
2. legacy one-active-event-per-cluster index during the first 50-field expansion attempt — whole attempted batch rolled back; uniqueness was split into legacy cluster scope and v2 `(cluster,field)` scope without weakening idempotency.

## Progressive expansion proof

Successful batch sizes: **10 + 50 + 50 + 50 + 50 + 19 = 229**.

Every successful checkpoint preserved patient count and produced exact event/preview deltas. Final replay processed **0** additional fields and preserved fingerprint `eee5a57717937a4f77049b3aebd8c525`.

## Mandatory persistence proof

Every data checkpoint requires all three:

1. execution receipt;
2. direct LIVE persisted readback;
3. independent invariant query.

REV-F5.6 additionally requires active-session 2FA proof, dry-run proof, exact canary rollback and field-level event/hash consistency.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock ownership — maintained.
2. REV-F5.1 exact source ingestion — **PASS**.
3. REV-F5.2 staging/manifests/replay — **PASS**.
4. REV-F5.3 identity memberships and preview — **PASS**.
5. REV-F5.4 MATCH / REVIEW / NEW — **PASS**.
6. REV-F5.5 fill-only enrichment preview — **PASS**.
7. REV-F5.6 governed Review & Apply — **PASS**.
8. REV-F5.7 patient → sale → F3 product → F4 payment/revenue/cartera linkage — **NEXT / UNBLOCKED**.
9. REV-F5.8 real transaction coverage for 2024–2025; prohibit unsupported YoY.
10. REV-F5.9 numeric Coverage & Data Quality Report.
11. REV-F5.10 independent exact-head/live final certification; only then can REV-F6 be unblocked.

## Safety invariants

- no merge by name alone;
- phone alone does not authorize merge;
- canonical strong-field contradiction blocks MATCH;
- target collision blocks MATCH;
- no overwrite of populated canonical fields;
- no Apply to identity anchors or blocked fields in F5.6;
- clinical notes/allergies stay outside commercial enrichment;
- `Último presupuesto` remains evidence only;
- `ADELANTO` remains payment evidence only;
- every retry reconciles persisted state first;
- no competing HIGH/CRITICAL mutable workstream.

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
