# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 ACTIVE / NOT YET PRODUCTION CERTIFIED  
**Captured:** 2026-08-19 America/Lima  
**Owner assignment:** explicit owner directive to continue REV-F5 closeout  
**REV-F5.9 entry baseline:** `main@83015824f8aa744f35f4a470bc8684110132c07b`  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**REV-F5.7 STATUS:** `PASS — HISTORICAL JOIN`  
**REV-F5.8 STATUS:** `PASS — NO CERTIFIED 2024/2025 TRANSACTIONAL SALES SOURCE`  
**REV-F5.9 STATUS:** `PASS — COVERAGE & DATA QUALITY REPORT`  
**NEXT GATE:** `REV-F5.10 — FINAL CERTIFICATION / UNBLOCKED / NOT STARTED`  
**REV-F6:** `BLOCKED until REV-F5.10 PASS`

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, other HIGH/CRITICAL feature/data workstreams remain read-only/documentation/regression-only unless explicitly required for REV-F5 validation.

## CURRENT REV-F5 checkpoint after REV-F5.9

- REV-F5.1 ingest = **PASS**;
- REV-F5.2 staging = **PASS**;
- REV-F5.3 identity rebuild/preview = **PASS**;
- REV-F5.4 canonical matching = **PASS**;
- REV-F5.5 enrichment preview = **PASS**;
- REV-F5.6 governed Review & Apply = **PASS**;
- REV-F5.7 historical commercial JOIN = **PASS**;
- REV-F5.8 historical sales 2024–2025 source audit = **PASS**;
- REV-F5.9 Coverage & Data Quality Report = **PASS**;
- REV-F5.10 final certification = **NEXT / UNBLOCKED / NOT STARTED**;
- REV-F5 global = **EN CURSO / NOT YET PRODUCTION CERTIFIED**;
- REV-F6 = **BLOCKED**.

## Protected CURRENT fingerprints

- canonical patients = **7,688** / `eee5a57717937a4f77049b3aebd8c525`;
- canonical sales = **1,299** / `20104fd91fbf427e39566e7b84d7ec4f`;
- F3 current facts = **406** / `e3c8499026d13401c4a733b4da16b6c8`;
- F4 reconciliation = **162** / `5524a2280442224ec4e9a7cfdfffa008`;
- F5.7 bridge = **1,299 / 1,299 sales** / semantic fp `5af139243f6aed37020048af292587fe`;
- F5.8 historical-transaction evidence fp = `4ce1695532a57655179558ed2b5f78aa`;
- F5.9 Coverage & DQ report fp = `5070c701d216eb839572bd70f530c2e6`.

## REV-F5.9 coverage snapshot

### Source / provenance

- sources = **6 / 6 MATCHED**;
- source rows = **15,498 / 15,498**;
- identity memberships = **15,498 / 15,498**;
- identity clusters = **8,716**;
- missing/orphan/multiple memberships = **0 / 0 / 0**;
- duplicate source keys = **0**;
- required provenance gaps = **0**.

### Identity

- MATCH / REVIEW / NEW = **296 / 6,984 / 1,436**;
- Identity Coverage Score = **3.40%** safe MATCH clusters / all clusters;
- strong source conflicts = **111**;
- target collisions = **1,740**;
- clusters with at least one conflict/blocking indicator = **4,050**;
- unsafe MATCH = **0**.

Low MATCH coverage is intentionally conservative and is not interpreted as incorrect history. Name alone and phone alone remain non-authoritative.

### Canonical patient DQ

Canonical Patient DQ Score = **51.48%**, defined only as 14-field cell completeness; it is not a correctness score and no global F5 average is permitted.

Major field coverage:

- Nombres **99.39%**;
- Apellidos **99.36%**;
- Teléfono **99.23%** (98.62% of populated values match Peru-9 format);
- Email **23.53%** (96.41% syntactically valid among populated);
- N° documento **49.99%** (76.29% DNI8 among populated);
- Sexo **92.96%**;
- Fecha de nacimiento **16.18%**;
- Dirección **14.28%**;
- distrito **1.43%**;
- ciudad **100.00%**;
- departamento **100.00%**;
- Ocupación **13.25%**;
- SEDE_PRINCIPAL **3.50%**;
- ULTIMA_VISITA **7.64%**.

Null/empty fields are coverage observations, not automatic defects.

### Governed Apply

- previews = **455 across 202 patients**;
- APPLY_ALLOWED / POLICY_BLOCKED / POLICY_UNDEFINED = **229 / 226 / 0**;
- applied = **229 / 229 allowed**;
- blocked applied = **0 / 226**;
- events = **230 total / 229 active / 1 exact rolled-back canary**;
- active field distribution = **Sexo 121 / distrito 108**;
- policy violations / applied-without-review / applied-without-event / event-preview mismatch / current-after mismatch / invalid hashes / active outside allowlist = **0 / 0 / 0 / 0 / 0 / 0 / 0**.

### Sales / patient linkage

- sales = **1,299**, certified current range **2026-01-05 → 2026-08-15**;
- MATCH / REVIEW / UNRESOLVED = **208 / 940 / 151**;
- Sales Linkage Coverage = **16.01%**;
- with canonical patient = **208**;
- without canonical patient = **1,091**;
- safely linked to an F5 historical MATCH cluster = **102 / 1,299 = 7.85%**;
- unsafe sale MATCH / missing bridge sale / bridge orphan = **0 / 0 / 0**.

### F3 product truth

- applicable = **406**;
- RESOLVED = **397 / 406 = 97.78%**;
- REVIEW_REQUIRED = **3**;
- EXCLUDED = **6**;
- MISSING_F3_FACT = **0**;
- NOT_APPLICABLE = **893**;
- duplicate fact / orphan = **0 / 0**.

### F4 financial evidence

- reconciliation rows = **162**;
- distinct physically linked sales = **123**;
- F4 Financial Evidence Coverage = **123 / 1,299 = 9.47%**;
- no F4 reconciliation evidence = **1,176 sales**;
- payment-linked rows = **0**;
- confirmed-balance rows = **0**;
- multiplicity / orphan = **0 / 0**.

This is a **HIGH financial coverage gap**, not proof of non-payment. F4 remains the only payment/revenue/cartera truth layer.

### Historical period coverage

- patient history 2024 / 2025 / 2026 = **AVAILABLE / AVAILABLE / AVAILABLE**;
- transaction sales 2024 = **NO CERTIFIED SOURCE**;
- transaction sales 2025 = **NO CERTIFIED SOURCE**;
- transaction sales 2026 = **AVAILABLE only inside certified current range**;
- Historical Transaction Coverage = **1 / 3 years = 33.33% source availability**.

Missing transaction coverage is never interpreted as zero revenue. Unsupported 2024↔2025↔2026 YoY/LTV/revenue remains prohibited.

## REV-F5.9 severity matrix

- **PASS / provenance:** staging exact and structurally clean;
- **MEDIUM / coverage gap:** conservative identity MATCH coverage;
- **MEDIUM / coverage gap:** canonical-field completeness variance;
- **PASS / policy:** governed Apply has zero violations;
- **PASS / product truth:** F3 has no missing applicable fact/orphan;
- **HIGH / financial coverage gap:** F4 covers 123/1,299 sales and payment evidence is zero;
- **INFO / legitimate source absence:** 2024–2025 transaction source not certified;
- **PASS / financial safety:** unsupported YoY and budget/adelanto inference remain prohibited;
- **PASS / critical:** no CRITICAL invariant failure detected.

## REV-F5.9 deterministic proof

Canonical report generation:

- first run fp = `5070c701d216eb839572bd70f530c2e6`;
- replay fp = `5070c701d216eb839572bd70f530c2e6`;
- deterministic replay = **PASS**.

Independent, structurally different invariants = **PASS**.

REV-F5.9 performed **zero production mutation**. It is a read-only certification/reporting gate.

## Safety invariants

- no merge by name alone;
- phone alone does not authorize merge;
- canonical strong-field contradiction blocks MATCH;
- target collision blocks MATCH;
- no overwrite of populated canonical fields;
- no Apply to identity anchors or blocked fields in F5.6;
- clinical notes/allergies stay outside commercial auto-enrichment;
- `Último presupuesto` remains evidence only;
- `ADELANTO` remains payment evidence only;
- missing 2024/2025 transaction coverage is not equivalent to zero revenue;
- F3 owns product truth;
- F4 owns payment/revenue/cartera truth;
- F5 owns patient identity/provenance;
- F6 consumes only certified facts and explicit coverage state;
- every retry reconciles persisted state first;
- no competing HIGH/CRITICAL mutable workstream.

## Mandatory persistence proof

Every consequential checkpoint requires:

1. execution receipt;
2. direct LIVE persisted readback;
3. independent invariant query.

REV-F5.9 additionally requires deterministic report fingerprint replay, separate dimension scores with explicit denominators and zero production mutation.

## Mandatory REV-F5 closeout sequence

1. REV-F5.0 rebaseline / lock — maintained.
2. REV-F5.1 exact source ingestion — **PASS**.
3. REV-F5.2 staging/manifests/replay — **PASS**.
4. REV-F5.3 identity memberships and preview — **PASS**.
5. REV-F5.4 MATCH / REVIEW / NEW — **PASS**.
6. REV-F5.5 fill-only enrichment preview — **PASS**.
7. REV-F5.6 governed Review & Apply — **PASS**.
8. REV-F5.7 patient → sale → F3 → F4 bridge — **PASS**.
9. REV-F5.8 historical transaction source coverage — **PASS: 2024/2025 NO CERTIFIED SOURCE**.
10. REV-F5.9 numeric Coverage & Data Quality Report — **PASS**.
11. REV-F5.10 independent exact-head/LIVE final certification — **NEXT / UNBLOCKED / NOT STARTED**.

## Main-moving policy

Before REV-F5.10 or any new mutable action, re-read `main`. If `main` moves, inspect the diff and revalidate LIVE compatibility before continuing. Never infer persistence from an execution transcript.

## Exit / handback

Do not release `REV-F5-CLOSEOUT` yet. The lock is released only after REV-F5.10 independently proves the final exact-head/LIVE state and records the final certification. Until then REV-F6 remains blocked.
