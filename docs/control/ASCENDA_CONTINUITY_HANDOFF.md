# ASCENDA OS — CANONICAL CONTINUITY HANDOFF

**Updated:** 2026-08-12 (America/Lima)

This document is the canonical handoff for continuing ASCENDA OS work from another ChatGPT/Codex session. Read it together with `AGENTS.md`, `SECURITY.md` and the rest of `docs/control/` before changing code or production data.

## 1. Project anchors

- GitHub repository: `CESARJAUREGUITORRES/ascenda-os` (private)
- Production code: primarily `app/`
- Production frontend: `app/public/*.html` + JS
- Production Node server: `app/server.js`
- Supabase production project: `ituyqwstonmhnfshnaqz`
- Runtime architecture: static frontend + Node/Railway + Supabase/Postgres with substantial business logic in RPC/functions/triggers
- `main` = production baseline
- `staging` = integration branch; it is NOT a separate production-like database/runtime
- No paid Supabase development branch is desired at this stage

## 2. Mandatory operating rules

1. Read `AGENTS.md`, `SECURITY.md` and `docs/control/` before modifying anything.
2. Do not expose credentials, service-role keys, passwords, OTPs, API tokens or secrets.
3. Do not make broad refactors while reconciling historical sales.
4. For production data corrections use: read-only audit -> Impact Report -> dependency check -> guarded transaction -> post-check -> rollback evidence.
5. Do not mass-delete duplicate-looking sales. Legitimate repeated purchases exist.
6. Code changes should normally branch from `staging`, pass CI, then be reviewed/promoted.
7. Historical sales reconciliation is being done ONE MONTH AT A TIME, January through July.

## 3. Source-of-truth matrix for sales reconciliation

### Financial / transactional truth
The monthly source CSV is authoritative for:
- sale date
- treatment/category
- raw description
- payment method
- amount
- payment status
- sales adviser
- attended-by/professional
- location/site
- number of financial transaction rows
- monthly and daily totals

### Identity truth
ASCENDA is the priority source for:
- DNI
- phone/cell number
- normalized phone
- already-consolidated patient identity

Reason: the source sales spreadsheets contain known Google Sheets autofill artifacts in some DNI/phone cells. Never overwrite a cleaner ASCENDA identity blindly from the CSV.

When identity is uncertain, resolve with the combined evidence of `aos_pacientes`, existing sales, leads, calls, appointments and historical frequency. Put unresolved cases into review; do not guess.

## 4. Persistent source files

The seven original monthly CSVs are stored in the user's private ChatGPT Library at:

`/ASCENDA OS/Auditorias/Ventas 2026/`

Files:
- `VENTAS_2026_01_ENERO.csv`
- `VENTAS_2026_02_FEBRERO.csv`
- `VENTAS_2026_03_MARZO.csv`
- `VENTAS_2026_04_ABRIL.csv`
- `VENTAS_2026_05_MAYO.csv`
- `VENTAS_2026_06_JUNIO.csv`
- `VENTAS_2026_07_JULIO.csv`

Do not copy these raw files into GitHub because they contain PII. In a new ChatGPT session, use the Files/Library connector to retrieve them from the exact folder above.

Each CSV has 13 operational columns: date, names, surnames, DNI/CE, cell, treatment, description, payment, amount/caja, payment status, appointment/adviser field, attended-by, site.

## 5. Reconciliation baseline — January through July

Source total January-July:
- **1,192 transactions**
- **S/498,424.47**

Supabase baseline before month-by-month remediation:
- **1,203 transactions**
- **S/503,994.07**

Difference at baseline:
- **+11 transactions** in ASCENDA
- **+S/5,569.60** in ASCENDA

Monthly source targets:

| Month | Source rows | Source total |
|---|---:|---:|
| Jan 2026 | 191 | S/91,029.60 |
| Feb 2026 | 166 | S/78,734.62 |
| Mar 2026 | 156 | S/63,681.65 |
| Apr 2026 | 152 | S/59,496.95 |
| May 2026 | 179 | S/79,225.85 |
| Jun 2026 | 159 | S/61,140.75 |
| Jul 2026 | 189 | S/65,115.05 |

Baseline differences found:
- January: same row count, **S/99 short** in ASCENDA
- February: **+13 rows / +S/5,751.60** in ASCENDA
- March: **-1 row / -S/161** in ASCENDA
- April: rows and total reconcile; field-level audit still required
- May: **+2 rows / +S/79** in ASCENDA
- June: **-3 rows / -S/1** in ASCENDA
- July: rows and total reconcile; field-level audit still required

## 6. Known systematic failure modes discovered

- whole import batches assigned the wrong date
- one logical sale split into multiple artificial sale rows
- multiple logical sale rows fused into one row
- duplicate imports / extra rows
- missing rows
- source spreadsheet phone/DNI autofill artifacts
- historical loss of `ATENDIO`
- inconsistent treatment labels
- product names hidden inside free-text `descripcion`
- payment/adviser/professional fields sometimes changed or omitted by older import paths

## 7. Current production fixes already completed before this handoff

### August sales
A recent August reconciliation found two extra sales totaling S/300 and a date-shifted batch. Production August was corrected atomically from **73 / S/53,574.80** to the source total **71 / S/53,274.80** at that point in the audit. Ten rows originally sourced as 2026-08-08 had been stored as 2026-08-09 and were corrected. Newer sales may have been imported after that reconciliation, so always query current August before comparing.

### Sales import hardening
- backend lot-level idempotency was introduced to reduce exact-batch duplicate reimports
- the import UI received a safety confirmation showing date/site/rows/total before import
- the current native browser confirmation is considered temporary UX debt and should later be replaced by a professional ASCENDA blue/white modal
- do not use fuzzy transaction deduplication because legitimate same-patient/same-product/same-amount purchases exist

### Marketing
Marketing Attribution/Traceability work has been developed in parallel. The current architecture uses a reinitalizable controller (V4 line) to avoid SPA remount races. Historically, `Historico` and `LTV` suffered `57014 statement timeout` because expensive annual RPCs were fired concurrently under the public role. The mitigation serializes heavy requests and adds safe query/index improvements. Marketing M0 revenue is cohort-attributed revenue and must NOT be compared as if it were total monthly sales revenue.

Historical monthly Marketing must remain year-scoped rather than shrink when a past month is selected.

## 8. Product-data rule

When `TRATAMIENTO = COMPRA DE PRODUCTO`, the real sold item is usually encoded in `DESCRIPCION`.

Do NOT erase or normalize the raw description in-place. Preserve it as raw evidence.

Future target model:
- raw treatment: `COMPRA DE PRODUCTO`
- raw description preserved
- canonical product reference
- canonical product name
- quantity
- payment semantics (total/advance/balance where inferable)
- alias dictionary for historical spelling variants

Examples of historical aliases include Beauty Maker / Beautymaker / promo variants, Lifting B variants, Zinc variants, etc.

ASCENDA's existing product/inventory catalog should be the primary canonical naming reference. The user will later provide/approve a product mapping sheet including quantity semantics such as `2 BEAUTY MAKER`, and cases where multiple payment rows represent one product.

Do not perform aggressive product canonicalization during January financial reconciliation. Capture evidence first; normalize products in a later dedicated pass.

## 9. Identity-data rule

The user explicitly confirmed:
- for sales/facturation/transaction facts -> monthly CSV is the source of truth
- for DNI/cell -> prefer the already-corrected values in ASCENDA

Known source issue: some spreadsheet sequences contain progressively altered phone numbers or DNI values from spreadsheet autofill. Therefore a sales reconciliation must not propagate suspicious source identity values into `aos_pacientes`.

## 10. JANUARY — exact current continuation point

**Status: AUDITED, NOT YET REMEDIATED in the January month-by-month process.**

Target after reconciliation:
- **191 sales**
- **S/91,029.60**

Supabase baseline observed for January before remediation:
- **191 sales**
- **S/90,930.60**

Important January findings already established:
- at least one batch has a one-day date displacement around 08/01 and 09/01
- one logical high-value transaction was represented as split rows and must be reconciled to the source representation
- one S/99 source sale near month-end is missing from ASCENDA
- January's `ATENDIO` field is empty across the historical sales table even though the source contains attended-by data
- several treatment/adviser values differ from source even when the amount matches
- some source phones/DNI are visibly autofill-corrupted; retain ASCENDA identity unless independent evidence proves ASCENDA wrong

A read-only query immediately before this handoff showed January rows around IDs `660` onward and confirmed the historical `ATENDIO` blanks. Do NOT assume row ordinal = CSV ordinal for the whole month; the prior quick ordinal test showed poor ordinal matching because inserted/split/date-shifted rows break positional alignment. Matching must be semantic, not row-number-based.

### January matching strategy
Use a scored deterministic matching process, prioritizing:
1. ASCENDA identity evidence (normalized phone/DNI/name) without overwriting it from suspect source cells
2. amount
3. treatment
4. description
5. payment method
6. date with tolerance for known +/- 1 day batch shifts
7. site/adviser/professional

Repeated legitimate purchases require one-to-one assignment, not de-duplication.

### January remediation loop
1. Load `VENTAS_2026_01_ENERO.csv` from Library.
2. Query current January from `aos_ventas` and any dependent tables/triggers.
3. Build an explicit source-row <-> sale-id reconciliation table.
4. Classify every row: exact / update / split-merge / missing / extra / identity-review.
5. Present/record an Impact Report.
6. Snapshot all affected production rows and dependency state.
7. Apply guarded transaction only to unambiguous changes.
8. Abort unless post-state is exactly **191 sales / S/91,029.60**.
9. Reconcile daily row counts and daily totals to the CSV, not only monthly total.
10. Verify service/product totals, advisers, sites, payment methods, payment states and `ATENDIO`.
11. Validate downstream effects in Sales, Commissions and Marketing; do not assume UI correctness from DB totals alone.
12. Keep unresolved DNI/phone cases unchanged and list them for later identity-resolution.
13. Update this handoff with January = VALIDATED only after all gates pass.

## 11. Required monthly loop after January

For February -> July repeat independently:

`snapshot -> source vs DB reconciliation -> Impact Report -> dependency check -> guarded correction -> exact monthly total -> exact daily totals -> field audit -> downstream validation -> documentation -> next month`

Never remediate all seven months in one transaction. Each month needs its own rollback boundary.

## 12. Definition of VALIDATED for a month

A month is not validated merely because monthly revenue matches.

All of these must pass:
- source row count = DB row count
- source monthly total = DB monthly total
- daily row counts match
- daily totals match
- every source transaction has one assigned DB transaction or an explicitly approved representation rule
- no unexplained extra DB rows
- treatment/description/payment/amount/status/adviser/professional/site reconciled for unambiguous rows
- identity anomalies do not overwrite cleaner ASCENDA identity
- downstream Sales/Commissions/Marketing checked for regressions
- rollback evidence retained

## 13. Next recommended action

Continue **January only**. Do not start February until January is validated and this file is updated accordingly.

The next session should retrieve the January CSV from Library, re-query production because data may have changed since this handoff, and continue the semantic reconciliation. Do not rely on cached totals if new imports have occurred.
