# REV-F5.9 — COVERAGE & DATA QUALITY REPORT CERTIFICATE

**Status:** PASS / CERTIFIED (LIVE evidence; merge gated by exact-head CI)  
**Captured:** 2026-08-19 America/Lima  
**Entry baseline:** `main@83015824f8aa744f35f4a470bc8684110132c07b`  
**Workstream lock:** `REV-F5-CLOSEOUT`  
**Mode:** read-only measurement / no patient, sale, F3, F4, identity or financial mutation  
**Report contract:** `REV-F5.9_COVERAGE_DQ_V1`  
**Deterministic report fingerprint:** `5070c701d216eb839572bd70f530c2e6`

## 1. Entry revalidation

Exact GitHub and LIVE rebaseline passed before report generation.

Protected domains:

| Domain | Rows | Fingerprint / certified semantic fingerprint | Result |
|---|---:|---|---|
| `aos_pacientes` | 7,688 | `eee5a57717937a4f77049b3aebd8c525` | PASS |
| `aos_ventas` | 1,299 | `20104fd91fbf427e39566e7b84d7ec4f` | PASS |
| F3 current facts | 406 | `e3c8499026d13401c4a733b4da16b6c8` | PASS |
| F4 reconciliation | 162 | `5524a2280442224ec4e9a7cfdfffa008` | PASS |
| F5.7 Historical JOIN | 1,299 / 1,299 sales | `5af139243f6aed37020048af292587fe` | PASS |
| F5.8 historical-transaction evidence | — | `4ce1695532a57655179558ed2b5f78aa` | PASS |

REV-F5.1 through REV-F5.8 therefore remained compatible with CURRENT before F5.9 measurement.

## 2. Source / staging coverage

All six historical sources remain exact and fully persisted. Their production batch state is `MATCHED` (not the assumed literal `COMPLETE` label); integrity is proved by exact persisted row parity.

| Source | Sede | Año | Expected | Persisted | State |
|---|---|---:|---:|---:|---|
| PUEBLO LIBRE 2024.xlsx | PUEBLO LIBRE | 2024 | 4,192 | 4,192 | MATCHED |
| SAN ISIDRO 2024.xlsx | SAN ISIDRO | 2024 | 3,190 | 3,190 | MATCHED |
| PUEBLO LIBRE 2025.xlsx | PUEBLO LIBRE | 2025 | 3,053 | 3,053 | MATCHED |
| SAN ISIDRO 2025.xlsx | SAN ISIDRO | 2025 | 3,066 | 3,066 | MATCHED |
| PUEBLO LIBRE 2026.xlsx | PUEBLO LIBRE | 2026 | 993 | 993 | MATCHED |
| SAN ISIDRO 2026.xlsx | SAN ISIDRO | 2026 | 1,004 | 1,004 | MATCHED |
| **TOTAL** | — | — | **15,498** | **15,498** | **PASS** |

Structural staging invariants:

- source rows = **15,498**;
- identity memberships = **15,498**;
- clusters = **8,716**;
- missing memberships = **0**;
- orphan memberships = **0**;
- invalid source-row membership multiplicity = **0**;
- duplicate `(batch_id, source_row_num)` keys = **0**;
- required provenance gaps (`batch_id`, row number, row hash, identity-seed hash) = **0**.

## 3. Identity coverage

Cluster-level canonical classification:

- MATCH = **296 / 8,716 = 3.40%**;
- REVIEW = **6,984 / 8,716 = 80.13%**;
- NEW = **1,436 / 8,716 = 16.48%**;
- source strong conflicts = **111**;
- target collisions = **1,740**;
- clusters carrying at least one blocking/conflict indicator = **4,050**;
- distinct canonical patients safely linked by MATCH = **296**;
- unsafe MATCH clusters under independent invariant query = **0**.

The low automatic MATCH rate is intentionally conservative. It is a **coverage characteristic**, not evidence that 96.60% of patient history is wrong. Name-only and phone-only authority remain prohibited.

Source-row-weighted classification by year:

| Año | Source rows | MATCH | REVIEW | NEW | MATCH % |
|---|---:|---:|---:|---:|---:|
| 2024 | 7,382 | 116 | 6,801 | 465 | 1.57% |
| 2025 | 6,119 | 145 | 4,997 | 977 | 2.37% |
| 2026 | 1,997 | 297 | 1,289 | 411 | 14.87% |

By source sede:

| Sede | Source rows | MATCH | REVIEW | NEW | MATCH % |
|---|---:|---:|---:|---:|---:|
| PUEBLO LIBRE | 8,238 | 304 | 7,096 | 838 | 3.69% |
| SAN ISIDRO | 7,260 | 254 | 5,991 | 1,015 | 3.50% |

These year/sede rows are membership-weighted observations; the same identity cluster may span multiple source periods/sedes and is counted in each source-row context. They must not be summed as unique clusters.

## 4. Canonical patient data quality

Canonical denominator = **7,688 patients**.

| Field | Populated | Empty | Coverage | Valid format when applicable |
|---|---:|---:|---:|---:|
| Nombres | 7,641 | 47 | 99.39% | — |
| Apellidos | 7,639 | 49 | 99.36% | — |
| Teléfono | 7,629 | 59 | 99.23% | 7,524 / 7,629 = 98.62% Peru-9 format |
| Email | 1,809 | 5,879 | 23.53% | 1,744 / 1,809 = 96.41% syntactic format |
| N° documento | 3,843 | 3,845 | 49.99% | 2,932 / 3,843 = 76.29% DNI8 format |
| Sexo | 7,147 | 541 | 92.96% | — |
| Fecha de nacimiento | 1,244 | 6,444 | 16.18% | 1,244 / 1,244 parsed by certified F5 date parser |
| Dirección | 1,098 | 6,590 | 14.28% | — |
| distrito | 110 | 7,578 | 1.43% | — |
| ciudad | 7,688 | 0 | 100.00% | — |
| departamento | 7,688 | 0 | 100.00% | — |
| Ocupación | 1,019 | 6,669 | 13.25% | — |
| SEDE_PRINCIPAL | 269 | 7,419 | 3.50% | — |
| ULTIMA_VISITA | 587 | 7,101 | 7.64% | 586 / 587 = 99.83% parsed by certified F5 date parser |

The **Canonical Patient DQ Score = 51.48%** is a transparent 14-field cell-completeness index only. It is **not** a global correctness score and must not hide low-coverage fields.

Historical source provenance remains strong for some identity anchors but sparse for optional demographics: source name/surname/sexo 100%, phone 99.66%, document 38.69%, email 16.16%, birth date 15.38%, address 13.28%, district/department 12.92%, occupation 12.75%, last appointment 54.32%.

Clinical notes and allergies are excluded from automatic commercial enrichment.

## 5. Enrichment / Apply coverage

- previews = **455**;
- distinct preview patients = **202**;
- APPLY_ALLOWED = **229**;
- POLICY_BLOCKED = **226**;
- POLICY_UNDEFINED = **0**;
- applied = **229**;
- remaining allowed pending = **0**;
- blocked and unapplied = **226**;
- Apply events = **230 total / 229 active / 1 rolled back canary**;
- active distribution = **Sexo 121 / distrito 108**;
- policy violations = **0**;
- applied without review = **0**;
- applied without event = **0**;
- event ↔ preview mismatch = **0**;
- current canonical ↔ active event after-patch mismatch = **0**;
- invalid before/after hash events = **0**;
- active events outside allowlist = **0**;
- exact canary rollback preserved = **1 / 1**.

## 6. Sales linkage coverage

Canonical sale universe = **1,299** rows, current certified date range **2026-01-05 → 2026-08-15**.

Identity linkage:

- MATCH = **208 / 1,299 = 16.01%**;
- REVIEW = **940 / 1,299 = 72.36%**;
- UNRESOLVED = **151 / 1,299 = 11.62%**;
- with canonical patient target = **208**;
- without canonical patient target = **1,091**;
- safely linked to an F5 historical MATCH cluster = **102 / 1,299 = 7.85%**;
- unsafe sale MATCH = **0**;
- bridge rows / distinct sale IDs = **1,299 / 1,299**;
- missing sale in bridge = **0**;
- orphan bridge rows = **0**.

By sede:

| Sede | Sales | MATCH | REVIEW | UNRESOLVED | F4 linked |
|---|---:|---:|---:|---:|---:|
| PUEBLO LIBRE | 593 | 90 | 404 | 99 | 53 |
| SAN ISIDRO | 706 | 118 | 536 | 52 | 70 |

By month:

| Month | Sales | MATCH | REVIEW | UNRESOLVED | F4 linked |
|---|---:|---:|---:|---:|---:|
| 2026-01 | 191 | 8 | 146 | 37 | 17 |
| 2026-02 | 166 | 15 | 137 | 14 | 23 |
| 2026-03 | 156 | 9 | 122 | 25 | 11 |
| 2026-04 | 152 | 38 | 105 | 9 | 11 |
| 2026-05 | 179 | 34 | 126 | 19 | 18 |
| 2026-06 | 159 | 36 | 103 | 20 | 16 |
| 2026-07 | 189 | 36 | 134 | 19 | 16 |
| 2026-08 | 107 | 32 | 67 | 8 | 11 |

## 7. F3 product coverage

F3 remains the sole product-truth layer.

- product-applicable sales = **406**;
- RESOLVED = **397 / 406 = 97.78%**;
- REVIEW_REQUIRED = **3 / 406 = 0.74%**;
- EXCLUDED = **6 / 406 = 1.48%**;
- MISSING_F3_FACT = **0**;
- NOT_APPLICABLE = **893** sales;
- F3 rows / distinct sale IDs = **406 / 406**;
- duplicate sale facts = **0**;
- F3 orphans = **0**;
- product-key leakage outside RESOLVED = **0** in the certified bridge.

## 8. F4 payment / revenue / cartera evidence coverage

F4 remains the sole payment/revenue/cartera evidence layer.

- F4 reconciliation rows = **162**;
- distinct sales physically covered = **123**;
- bridge sales with F4 evidence = **123 / 1,299 = 9.47%**;
- bridge sales without F4 reconciliation evidence = **1,176 / 1,299 = 90.53%**;
- payment-linked reconciliation rows = **0**;
- confirmed-balance rows = **0**;
- bridge payment-evidence rows = **0**;
- bridge confirmed-balance evidence rows = **0**;
- F4 orphans = **0**;
- sales with more than one F4 row = **0**.

This is a **HIGH financial coverage gap**, not proof that unlinked sales are unpaid. `ADELANTO` remains payment evidence only and never an automatic debt/balance. `Último presupuesto` remains non-financial evidence only.

## 9. Historical period coverage

- patient-history 2024 = **AVAILABLE**;
- patient-history 2025 = **AVAILABLE**;
- patient-history 2026 = **AVAILABLE**;
- transactional sales 2024 = **NO CERTIFIED SOURCE**;
- transactional sales 2025 = **NO CERTIFIED SOURCE**;
- transactional sales 2026 = **AVAILABLE only for certified current range 2026-01-05 → 2026-08-15**.

Historical Transaction Coverage = **1 / 3 target years = 33.33% source availability**. This is an availability indicator, not a revenue ratio.

**NO CERTIFIED SOURCE ≠ SALES = 0.** Unsupported 2024↔2025↔2026 YoY, revenue or LTV must remain disabled/coverage-labeled.

## 10. Coverage scores — separate dimensions only

No global average is produced.

| Dimension | Score | Exact denominator / meaning |
|---|---:|---|
| Identity Coverage Score | **3.40%** | 296 safe MATCH clusters / 8,716 clusters |
| Canonical Patient DQ Score | **51.48%** | populated cells across 14 measured fields / all possible cells |
| Sales Linkage Coverage | **16.01%** | 208 safely patient-linked sales / 1,299 sales |
| F3 Product Coverage | **97.78%** | 397 RESOLVED / 406 product-applicable sales |
| F4 Financial Evidence Coverage | **9.47%** | 123 sales with F4 reconciliation evidence / 1,299 sales |
| Historical Transaction Coverage | **33.33%** | 1 certified transaction year / 3 requested years |

## 11. Data-quality severity matrix

| Severity | Category | Finding |
|---|---|---|
| PASS | provenance | source staging exact and structurally clean |
| MEDIUM | coverage gap | safe identity MATCH coverage is conservative/low |
| MEDIUM | coverage gap | canonical field completeness varies materially by field |
| PASS | policy | governed Apply has zero policy/review/event/hash violations |
| PASS | product truth | F3 has zero missing applicable facts, duplicates or orphans |
| HIGH | financial coverage gap | F4 covers 123/1,299 sales and payment evidence is 0 |
| INFO | legitimate source absence | 2024–2025 transactional sales source is not certified |
| PASS | financial safety | unsupported YoY and budget/adelanto inference remain prohibited |
| PASS | critical | no CRITICAL invariant failure detected |

Null/empty values are not automatically defects. The matrix distinguishes coverage gaps, legitimate source absence and policy-blocked data from actual structural errors.

## 12. Determinism and independent invariants

The canonical read-only report was generated twice from the same exact-head/LIVE state.

- run 1 fingerprint = `5070c701d216eb839572bd70f530c2e6`;
- replay fingerprint = `5070c701d216eb839572bd70f530c2e6`;
- result = **DETERMINISTIC REPLAY PASS**.

A second, structurally different invariant query returned **PASS** and independently proved:

- 6/6 exact batches;
- 15,498 source rows / 15,498 memberships;
- zero missing/orphan/multi memberships;
- 8,716 classified clusters;
- zero unsafe MATCH clusters;
- zero invalid applied previews;
- zero event/preview and current/after mismatches;
- 1,299/1,299 bridge sale coverage;
- zero bridge orphans and unsafe sale MATCHes;
- zero missing applicable F3 facts;
- 406/406 F3 unique sale facts, zero orphans;
- 162 F4 rows / 123 distinct sales, zero multiplicity and orphans;
- all four protected-domain fingerprints unchanged.

F5.9 itself executed **no production mutation**.

## 13. Semantic safety contract

The report fingerprint includes these non-negotiable booleans:

- missing transactional source means zero sales = **false**;
- `Último presupuesto` is a financial fact = **false**;
- `ADELANTO` automatically establishes balance/debt = **false**;
- phone alone authorizes identity = **false**;
- name alone authorizes identity = **false**.

## 14. Gate result

`REV-F5.9 — COVERAGE & DATA QUALITY REPORT = PASS / CERTIFIED` once this exact certificate/report/test set passes exact-head CI, merges with expected head SHA, survives post-merge LIVE readback and is persisted in Notion.

Next gate after that merge/readback:

`REV-F5.10 — FINAL CERTIFICATION = NEXT / UNBLOCKED / NOT STARTED`.

REV-F5 remains **EN CURSO / NOT YET PRODUCTION CERTIFIED** and REV-F6 remains **BLOCKED** until F5.10 independently closes the entire phase.
