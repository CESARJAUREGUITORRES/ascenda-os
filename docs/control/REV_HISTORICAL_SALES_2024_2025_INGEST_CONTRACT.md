# REV — HISTORICAL SALES 2024–2025 INGEST CONTRACT

**Status:** DESIGN CONTRACT / NO DATA MUTATION  
**Purpose:** prepare ASCENDA so future 2024–2025 sales Excel/CSV sources can be ingested without redesigning Revenue, Patient Identity, Product or Marketing attribution.

## 1. Principle

Historical sales are not a replacement for F5 patient history. They are a separate transaction evidence stream that must reuse existing canonical domains.

Target pipeline:

`SOURCE FILE → MANIFEST/SHA → ROW PROVENANCE → SALES STAGING → DEDUP/VALIDATION → aos_ventas-compatible canonical sale → F3 product resolution → F5 patient identity resolution → F4 payment/cartera reconciliation → F6 intelligence`.

Do not infer missing sales from patient `Último presupuesto`, Agenda, calls or treatment history.

## 2. Minimum source fields to preserve

The importer should preserve all original columns and map, where available, to current `aos_ventas` semantics:

- source row number / source transaction key;
- `venta_id` or equivalent source sale identifier;
- `fecha`;
- names / surnames;
- DNI/document;
- phone / `numero_limpio` derivation;
- treatment/service/product raw text;
- description/raw item detail;
- quantity when present;
- amount;
- currency;
- payment/status text;
- advisor;
- attended-by/professional;
- site/sede;
- type/category;
- fiscal document/comprobante identifiers where present;
- quote/cotización identifier where present;
- appointment/atención/plan identifiers where present;
- source file/year/site metadata.

Absence of one field must not be silently filled from another domain unless the derivation is explicit, auditable and reversible.

## 3. Source manifest and provenance

Every file must have:

- source filename;
- source year;
- source site;
- exact SHA-256;
- row count;
- column count/schema fingerprint;
- ingestion timestamp;
- source row number;
- normalized row hash;
- raw payload or equivalent immutable provenance representation.

A repeated import of the same SHA-bound file must be idempotent.

If the same source row key exists with different raw content, stop that row/range and raise a conflict; do not overwrite silently.

## 4. Canonical identity join

Historical sale-to-patient resolution must consume F5 identity logic, not create a second customer-matching engine.

Preferred evidence order:

1. exact certified canonical patient link carried by source/application;
2. DNI/document + compatible identity evidence;
3. email + compatible evidence;
4. phone + compatible name/context;
5. unresolved/review.

Name-only and phone-only joins are not canonical merge authority.

The sale may remain imported while its patient link is unresolved; transaction provenance must not be discarded.

## 5. Product join

Raw historical treatment/product text must reuse F3 product canonicalization:

- preserve `raw_description` / alias;
- resolve through current product alias / identity rules;
- store resolution status/source/confidence;
- route unknown/ambiguous descriptions to the existing product review pattern;
- never create a new product taxonomy just for historical years.

The current canonical sale-product bridge is based on `sale_id` and `aos_product_sale_fact_current_v1` / F3 identity.

## 6. Payment and cartera semantics

A sale row is not automatically equivalent to a settled payment.

Keep separate:

- sale amount;
- payment amount;
- payment method;
- payment date;
- quote/cotización;
- advance/adelanto;
- confirmed balance;
- expected purchase total;
- fiscal-document state;
- reconciliation confidence.

Reuse F4 evidence and `aos_cartera_reconciliacion` semantics. Do not derive debt from `Último presupuesto` or an isolated sale status string.

## 7. Marketing / acquisition join

Historical sales can improve acquisition intelligence only after patient/sale identity is resolved.

Preferred attribution chain:

`lead_id_origen → llamada_id_origen → Agenda → patient → sale`.

Fallback phone-based linkage must be time-bounded and evidence-scored. A phone match across years is not sufficient proof of campaign attribution.

Historical attribution should expose confidence/method and support `UNATTRIBUTED` as a valid state.

## 8. Temporal customer lifecycle facts enabled by the data

Once 2024–2025 sales are available and certified, F6 can safely derive:

- first purchase date;
- last purchase date;
- purchase frequency;
- interpurchase interval;
- historical reactivation;
- cohort by first purchase year/month;
- repeat purchase by product family;
- cross-sell sequence;
- advisor retention/conversion;
- site migration between Pueblo Libre / San Isidro;
- customer lifetime revenue for covered periods;
- time from lead → call → appointment → sale when evidence exists;
- marketing CAC/ROAS/LTV only where spend + attribution coverage supports it.

Every metric must carry a coverage denominator and source period.

## 9. Import gates when files arrive

For each future 2024/2025 file:

### Gate A — Intake

- file inventory;
- SHA;
- schema;
- row count;
- date range;
- site;
- duplicate-source detection.

### Gate B — Profiling

Measure:

- unique source sale IDs;
- duplicate sale candidates;
- phone/DNI coverage;
- treatment/product coverage;
- amount/currency coverage;
- payment fields;
- advisor/site coverage;
- invalid dates/amounts;
- source anomalies.

### Gate C — Staging

Chunked idempotent ingest with persistence triple-proof.

### Gate D — Canonical sale reconciliation

No duplicate sales; preserve source provenance and explicit unresolved cases.

### Gate E — F3 product resolution

Resolved / review / unknown counts.

### Gate F — F5 patient resolution

Matched / review / new/unresolved counts with evidence.

### Gate G — F4 payment/cartera reconciliation

Paid / partial / unresolved / unsupported counts without invented debt.

### Gate H — Cross-domain certification

Require exact numerators/denominators and replay/idempotency before exposing historical years to F6/CIA dashboards.

## 10. Recommended file template for future delivery

The importer should be schema-adaptive, but if historical exports can be prepared intentionally, the preferred columns are:

1. `source_sale_id`
2. `fecha`
3. `sede`
4. `nombres`
5. `apellidos`
6. `dni`
7. `celular`
8. `email` (if available)
9. `tratamiento`
10. `descripcion`
11. `cantidad`
12. `monto_venta`
13. `moneda`
14. `estado_pago`
15. `monto_pagado` (if known)
16. `fecha_pago` (if known)
17. `metodo_pago` (if known)
18. `asesor`
19. `atendio`
20. `tipo`
21. `comprobante_id`
22. `tipo_comprobante`
23. `cotizacion_id`
24. `atencion_id`
25. `plan_id`
26. `plan_item_id`
27. `observacion_origen`

This is a preferred contract, not a requirement to alter original evidence. Always preserve raw source columns as supplied.

## 11. What must NOT happen

- no direct mass insert into `aos_ventas` without staging/provenance;
- no separate historical patient table treated as canonical identity;
- no new product catalog for old years;
- no phone-only patient merge;
- no budget-as-sale or budget-as-debt inference;
- no attribution by unlimited-window phone equality;
- no YoY dashboard until both years have certified transactional coverage;
- no claim of 100% based on local/job output without live readback and independent invariant query.

## 12. Readiness state today

ASCENDA already has the canonical target domains needed for this future import:

- `aos_ventas` for sale facts;
- F3 sale-product facts (`aos_product_sale_fact_current_v1`);
- F5 source/identity model for patient resolution;
- `aos_pagos` and `aos_cartera_reconciliacion` for payment/revenue evidence;
- `aos_leads`, `aos_llamadas`, `aos_agenda_citas` for acquisition journey links.

Therefore future 2024–2025 sales should extend coverage, not trigger a new architecture.
