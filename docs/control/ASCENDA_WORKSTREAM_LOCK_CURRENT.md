# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT YET PRODUCTION CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**CURRENT baseline before REV-F5.8 merge:** `main@d1f165fa436165ad6b7b60b2b7bdf007939b9166`  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**REV-F5.7 STATUS:** `PASS — HISTORICAL JOIN`  
**REV-F5.8 STATUS:** `PASS — NO CERTIFIED 2024/2025 TRANSACTIONAL SALES SOURCE`  
**NEXT GATE:** `REV-F5.9 — COVERAGE & DATA QUALITY REPORT`  

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## REV-F5 LIVE checkpoint after REV-F5.8

- REV-F5.1 ingest = **PASS**;
- REV-F5.2 staging = **PASS**;
- REV-F5.3 identity rebuild/preview = **PASS**;
- REV-F5.4 canonical matching = **PASS**;
- REV-F5.5 enrichment preview = **PASS**;
- REV-F5.6 governed Review & Apply = **PASS**;
- REV-F5.7 historical commercial JOIN = **PASS**;
- REV-F5.8 historical sales 2024–2025 source audit = **PASS**;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- canonical patients = **7,688**;
- final canonical fingerprint after F5.6 = `eee5a57717937a4f77049b3aebd8c525`;
- F5.7 bridge = **1,299 / 1,299 sales**;
- F5.7 sale identity = **208 MATCH / 940 REVIEW / 151 UNRESOLVED**;
- F5.7 bridge fingerprint = `5af139243f6aed37020048af292587fe`;
- F5.7 F3 = **397 RESOLVED / 3 REVIEW_REQUIRED / 6 EXCLUDED / 0 MISSING_F3_FACT / 893 NOT_APPLICABLE**;
- F5.7 F4 = **123 LINKED / 1,176 NO_F4_RECONCILIATION_EVIDENCE**;
- F5.8 canonical `aos_ventas` 2024–2025 rows = **0**;
- F5.8 reconciled sales months 2024–2025 = **0**;
- F5 patient-history rows 2024–2025 = **13,501 across 4 certified batches**;
- F5 patient exports contain no transaction keys = **true**;
- F5.8 evidence fingerprint = `4ce1695532a57655179558ed2b5f78aa`;
- 2024 sales coverage = **NO CERTIFIED TRANSACTIONAL SOURCE**;
- 2025 sales coverage = **NO CERTIFIED TRANSACTIONAL SOURCE**;
- unsupported historical YoY/revenue must not be exposed as factual.

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

## REV-F5.7 JOIN proof

The private F5.7 bridge consumes existing domains instead of creating parallel truth:

- F5 owns patient identity;
- F3 owns product resolution;
- F4 owns payment/revenue/cartera evidence.

Builder initial run + replay x2 returned identical fingerprint `5af139243f6aed37020048af292587fe`. Independent invariants proved one row per sale, no unsafe identity MATCH, no phone-only authority, no review target leakage, private access boundary and no mutation of pacientes / ventas / F3 / F4.

## REV-F5.8 coverage boundary

The six already-certified historical Excel sources are patient exports, not transaction ledgers. They are valid for identity/provenance but do not contain canonical sale id/date/amount/currency/payment/product transaction fields.

REV-F5.8 independently profiled the persisted transactional candidates. All auditable sale/payment/reconciliation coverage currently begins in 2026. No real 2024 or 2025 sales ledger was found in the persisted production domains or repository evidence.

Therefore:

- do not reinterpret absence as business `sales = 0`;
- do not derive sales from `Último presupuesto`, appointments, calls or patient history;
- do not expose factual 2024/2025 revenue, LTV or YoY until a real source is ingested through the existing historical-sales ingest contract;
- if such a source appears later, reopen F5.8 intake and rebaseline instead of silently changing this contract.

## Mandatory persistence proof

Every data checkpoint requires all three:

1. execution receipt;
2. direct LIVE persisted readback;
3. independent invariant query.

REV-F5.6 additionally requires active-session 2FA proof, dry-run proof, exact canary rollback and field-level event/hash consistency.

REV-F5.7 additionally requires deterministic bridge replay and protected-domain fingerprints.

REV-F5.8 is a read-only coverage certification: its PASS requires independent LIVE year profiling plus repository/source-contract verification and a deterministic evidence fingerprint. It performs no patient/sale/financial mutation.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 exact-current rebaseline and lock ownership — maintained.
2. REV-F5.1 exact source ingestion — **PASS**.
3. REV-F5.2 staging/manifests/replay — **PASS**.
4. REV-F5.3 identity memberships and preview — **PASS**.
5. REV-F5.4 MATCH / REVIEW / NEW — **PASS**.
6. REV-F5.5 fill-only enrichment preview — **PASS**.
7. REV-F5.6 governed Review & Apply — **PASS**.
8. REV-F5.7 patient → sale → F3 product → F4 payment/revenue/cartera linkage — **PASS**.
9. REV-F5.8 real transaction coverage for 2024–2025; prohibit unsupported YoY — **PASS: NO CERTIFIED SOURCE**.
10. REV-F5.9 numeric Coverage & Data Quality Report — **NEXT / UNBLOCKED**.
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
- missing 2024/2025 transaction coverage is not equivalent to zero revenue;
- every retry reconciles persisted state first;
- no competing HIGH/CRITICAL mutable workstream.

## Cross-domain boundary

- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- F6 consumes only certified facts and explicit coverage state;
- CIA/WA must not create a second canonical customer identity.

## Main-moving policy

Before each mutable gate, re-read `main`. If `main` moves, stop new F5 writes, inspect diff, revalidate compatibility, then continue from LIVE. Never infer persistence from an execution transcript.

## Exit / handback

Do not release the lock automatically. REV-F5 releases it only after REV-F5.10 is proven from exact GitHub/CI/deploy + LIVE Supabase invariants + rollback/recovery + final documentation, or after an explicit owner-approved recoverable pause.
