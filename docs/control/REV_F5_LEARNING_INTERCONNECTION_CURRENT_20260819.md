# REV-F5 — LEARNING, INTERCONNECTION & CERTIFICATION CURRENT

**Captured:** 2026-08-19 America/Lima  
**Source of truth:** `main@40b2cbf50a9ffc2d9ca1ee3fedbf457c133c4a21` + Supabase LIVE  
**Workstream:** `REV-F5-CLOSEOUT`  
**Status:** IN PROGRESS — this document explicitly supersedes any chat/document claim that REV-F5 is already production-certified.

## 1. Live truth at this capture

Supabase LIVE proves:

- source batches: **6**;
- expected source rows: **15,498**;
- persisted staging rows: **8,264**;
- batches with `metadata.staging_complete=true`: **1 / 6**;
- structural duplicate `(batch_id, source_row_num)` keys: **0**;
- orphan source rows: **0**;
- provisional identity clusters: **3,950**;
- identity cluster members: **0**;
- patient link previews: **0**;
- canonical apply events: **0**;
- observational `aos_pacientes` count: **7,685**.

Per-source persisted state:

| Source | Expected | Staged | Missing |
|---|---:|---:|---:|
| PUEBLO LIBRE 2024 | 4,192 | 3,949 | 243 |
| PUEBLO LIBRE 2025 | 3,053 | 1,801 | 1,252 |
| PUEBLO LIBRE 2026 | 993 | 993 | 0 |
| SAN ISIDRO 2024 | 3,190 | 1,521 | 1,669 |
| SAN ISIDRO 2025 | 3,066 | 0 | 3,066 |
| SAN ISIDRO 2026 | 1,004 | 0 | 1,004 |

Exact missing ranges at capture:

- PL2024: Excel **3951–4193**;
- PL2025: Excel **1703–1802** and **1903–3054**;
- SI2024: Excel **1523–3191**;
- SI2025: Excel **2–3067**;
- SI2026: Excel **2–1005**.

## 2. Critical incident: false certification / persistence gap

A previous execution narrative claimed:

- 15,498/15,498 staging;
- 15,498 identity members;
- Review/Apply completed;
- REV-F5 production-certified;
- REV-F6 unblocked.

Those claims are **not supported by production state** and are therefore invalid.

GitHub has no merged REV-F5 production-closeout PR after PR #298, while Supabase LIVE remains at 8,264/15,498 with members/previews/apply all zero.

### Root lesson

**A tool invocation, generated payload, returned response, local loop completion or assistant statement is never equivalent to persisted production truth.**

For data pipelines, certification requires the post-condition to be independently visible in the authoritative store.

## 3. Mandatory Persistence Triple-Proof

Every HIGH/CRITICAL data mutation must satisfy all three layers before it can close a checkpoint:

1. **Execution receipt** — RPC/job/transaction reports success for the intended chunk.
2. **Direct live readback** — authoritative production tables show the expected persisted delta.
3. **Independent invariant query** — a separate query proves continuity, uniqueness, range, orphan/conflict and protected-table invariants.

If any layer is absent, the correct state is `IN_PROGRESS` or `UNKNOWN`, never `PASS`.

For source ingestion, a fourth proof is mandatory at batch closure:

4. **Full idempotent replay** — re-submit the complete SHA-bound source; require every row to resolve as existing and zero new inserts/conflicts.

## 4. Recovery pattern that worked

The resilient loop is:

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY THAT GAP → READ BACK → VERIFY INVARIANTS → CHECKPOINT → CONTINUE`

Never:

`ERROR/TIMEOUT → ASSUME → SKIP → CERTIFY`.

When a persisted range is suspected of corruption:

`source SHA → row-level comparison → isolate exact range → repair only that range → replay → continue`.

Do not restart the full dataset unless the entire batch is demonstrably invalid.

## 5. Identity architecture learned from F5

The historical XLSX rows are **evidence**, not canonical patients.

The durable architecture is:

`SOURCE ROW → PROVENANCE → HISTORICAL IDENTITY CLUSTER → MATCH/REVIEW/NEW → CANONICAL PATIENT`

Rules:

- source patient ID is source-specific;
- HC is not a guaranteed global identity key;
- name alone never authorizes merge;
- phone alone never authorizes merge;
- DNI + compatible name is strong evidence;
- email is strong evidence but should be accompanied by compatible context where possible;
- phone + name and name + DOB are supporting evidence;
- conflicting strong identifiers route to human review;
- canonical enrichment is fill-only unless separately reviewed;
- clinical notes/allergies never auto-apply through the commercial identity pipeline;
- `Último presupuesto` remains `EVIDENCE_ONLY`;
- `ADELANTO` is payment evidence, never automatic debt.

## 6. Interconnection map — use one identity truth

F5 must become the canonical identity/provenance layer consumed by the rest of ASCENDA. Other workstreams must not create competing patient/customer identity truth.

### Marketing / CIA

Existing bridges:

- `aos_leads.id`;
- `aos_leads.numero_limpio`;
- `aos_llamadas.lead_id_origen`;
- `aos_llamadas.numero_limpio`;
- `aos_agenda_citas.lead_id_origen`;
- `aos_agenda_citas.llamada_id_origen`.

Target chain:

`campaign/ad → lead → call/WhatsApp/agenda → canonical patient identity → sale → canonical product → payment/revenue`.

Never attribute a sale to a campaign merely because phone numbers match across an unlimited time window. Attribution must remain time-aware and evidence-aware.

### WhatsApp Revenue Hub

`numero_limpio` is a useful transversal contact bridge, but it is not sufficient merge authority.

Once F5 identity is certified, WhatsApp should resolve an incoming contact to:

- canonical patient when evidence is sufficient;
- unresolved/ambiguous identity when it is not;
- historical-commercial context only according to role/privacy policy.

Do not expose clinical staging data to commercial chat agents.

### Agenda / Calls

Existing explicit links should be preferred over inference:

- `lead_id_origen`;
- `llamada_id_origen`;
- `venta_id_match`;
- `plan_item_id`;
- `cotizacion_item_id`.

`numero_limpio` is fallback evidence, not proof.

### Revenue / Product / Payments

Existing canonical chain already supports:

- `aos_ventas.id` → `aos_product_sale_fact_current_v1.sale_id`;
- `aos_cartera_reconciliacion.venta_row_id` → sale;
- `aos_pagos.cotizacion_id` / `item_id` → payment evidence;
- product fact → `product_key` / `catalog_service_id`.

F5 should add patient identity to this chain; it should not replace F3 product truth or F4 financial/reconciliation truth.

Canonical responsibility remains:

- **F3:** what product/service was sold;
- **F4:** what money/payment/cartera state is supported;
- **F5:** who the historical/canonical patient is and why;
- **F6:** derive intelligence from those certified facts.

## 7. Bias / failure-mode audit

### Identity collision bias

Families may share phones; patients may change numbers; assistants may register a relative's phone. Mitigation: never merge on phone alone; retain evidence and review queues.

### Recency bias

The latest record is not automatically the most correct record. A newer typo must not overwrite an older verified DNI/DOB. Mitigation: field-level provenance + fill-only + conflict review.

### Source authority bias

A source-specific ID, HC or one spreadsheet must not be assumed globally authoritative. Mitigation: source namespace + SHA + row provenance.

### Availability bias

Because current `aos_ventas` is easier to query than missing historical sales, there is a risk of treating 2026 as the whole business history. Mitigation: explicit coverage period metadata and no unsupported 2024/2025 YoY.

### Survivorship bias

Patients present in later years are overrepresented in current operational tables. Historical cohorts must not be judged only through surviving/current patients.

### Attribution bias

Phone/date proximity can create false campaign attribution. Prefer explicit lead/call/agenda links and bounded temporal evidence.

### Revenue semantics bias

`presupuesto`, `adelanto`, `pago`, `monto`, `saldo`, `facturado` are different business concepts. Do not coerce them into one metric.

### Completion bias

Large loops create pressure to interpret progress output as completion. Mitigation: persistence triple-proof + final independent certification query.

### Documentation drift bias

CURRENT docs can lag live production. Mitigation: GitHub docs record the latest proven state but never outrank exact live DB/runtime evidence.

## 8. Data-contract implications for future 2024–2025 sales

Historical sales must enter through an idempotent source/provenance contract and then reuse existing canonical layers:

`SALES SOURCE → sales staging/provenance → canonical aos_ventas-compatible fact → F3 product resolution → F5 patient resolution → F4 payment/cartera reconciliation → F6 intelligence`.

Do not import 2024–2025 sales directly as trusted revenue without:

- source manifest/SHA;
- row-level source key/hash;
- duplicate protection;
- patient identity evidence;
- product canonicalization;
- payment semantics separation;
- coverage report.

See `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

## 9. What can be optimized after F5 is truly certified

Once F5 reaches actual production certification, improvements should be additive/read-first:

1. materialize a governed patient-identity bridge for consumers so each module does not rerun fuzzy matching;
2. expose identity confidence/provenance, not only a patient ID;
3. add temporal customer lifecycle facts: first seen, first lead, first call, first appointment, first sale, last sale, reactivation;
4. distinguish `new_patient`, `returning_patient`, `historical_reactivated`, `unresolved_identity`;
5. create bounded attribution facts from explicit lead/call/agenda links;
6. calculate cohort/LTV only where transaction coverage supports it;
7. build data-quality monitors for identity collisions and field drift;
8. integrate Sentinel checks for broken provenance/member coverage, not only application errors;
9. let WA/CIA consume a read-only commercial identity profile while keeping clinical detail access separated;
10. add historical sales years without changing F5 identity semantics.

## 10. Current gate

REV-F5 remains **ACTIVE / NOT CERTIFIED**.

Next correct execution point:

1. preserve `REV-F5-CLOSEOUT` lock;
2. complete exact missing source ranges from LIVE;
3. certify each batch with full replay;
4. require 15,498/15,498 before identity rebuild;
5. only then execute F5.3–F5.10;
6. do not unblock REV-F6 until a fresh independent final query proves every declared gate.
