# WA-4A.1C — Treatment & Pricing Architecture — Evidence

Date: 2026-08-28 America/Lima  
Parent: WA-4A.1B certified commercial knowledge graph  
Baseline main: `510d66bd4b63b1c26b457c0d80e2ca5b960465c7`

## Objective
Build a governed, read-only architecture that combines current Zi Vital price facts with the certified Domain / Approach / Commercial Phase / Clinical Lifecycle semantics, while preserving professional clinical authority and existing quotation/payment systems.

## Necessity gate

`BUILD = YES`  
`NEW PRICE MASTER = NO`  
`NEW QUOTE MASTER = NO`  
`NEW PAYMENT MASTER = NO`  
`NEW PATIENT PLAN MASTER = NO`  
`MINIMAL PRIVATE READ MODEL + STRUCTURAL PROCESS TEMPLATES + READ-ONLY PREVIEW = YES`

Reason: PROD already contains the necessary operational authorities:

- `aos_catalogo_servicios` — active service/product catalog and current price fields;
- `aos_catalogo_toppings` — topping/add-on prices and category linkage;
- `aos_cotizaciones` + `aos_cotizacion_items` — historical/current quote snapshots;
- `aos_pagos` — payments;
- `aos_planes_trabajo` + `aos_plan_trabajo_items` — patient-specific work-plan model;
- `aos_sesiones_tratamiento` — session execution/payment state;
- `aos_catalogo_variantes` and `aos_catalogo_servicio_producto` exist but currently have no rows;
- `aos_promociones` exists but currently has no rows.

Therefore 1C must reuse these sources and must not create parallel business truth.

## PROD discovery readback

### Catalog price shape

Active catalog = 217 rows:

- services = 167;
- service `precio_oferta` present = 167/167;
- service `precio_base` present = 132/167;
- products = 50;
- product `precio_oferta` present = 50/50;
- product `precio_base` present = 26/50;
- active rows with nonpositive offer = 0;
- duplicate active names = 0;
- rows with `precio_oferta > precio_base` = 7;
- current discovery fingerprint including catalog+toppings = `4f2bdff1a36dc1c621c237a8da655155`.

The seven offer-above-base rows are review debt, not silently auto-corrected:

- MESO CAPILAR VIT x1 — base 290 / offer 299;
- MESO CAPILAR VIT x3 — base 850 / offer 899;
- MESOTERAPIA CORPORAL 2 AMP x1 — base 350 / offer 399;
- ENZIMAS FACIAL MCCM x1 — base 550 / offer 599;
- ENZIMAS FACIAL PBSERUM x1 — base 550 / offer 699;
- DESCONGESTIVO PÁRPADOS — base 39 / offer 49;
- PEPTOPLUS x5 — base 350 / offer 599.

1C policy: these values fail closed for automated quote preview until the price semantics are reviewed. The architecture does not rewrite them.

### Toppings / variants / links / promotions

- active toppings = 20/20;
- one topping (`DRENAJE LINFÁTICO`) has explicit price 0 and must be represented as `ZERO_PRICE_BENEFIT_CANDIDATE`, not as a hidden discount;
- active variants = 0;
- service→product links = 0;
- active promotions = 0.

The absence of relations/promotions is not filled with invented associations.

### Existing quotations

- quotes = 284;
- `PAGADO_COMPLETO` = 229;
- `PAGADO_PARCIAL` = 39;
- `ANULADO` = 12;
- `CREADO` = 3;
- `POR_PAGAR` = 1;
- quote items = 623: 449 SERVICIO + 174 PRODUCTO;
- missing/nonpositive quote-item price = 0;
- quantity <= 0 = 0;
- subtotal math mismatch = 0;
- quote items linked to plan items = 0;
- `sesiones_programadas` field is present on all 623 rows but currently equals 0 for all 623.

Historical quote item prices are snapshots and are not rewritten when catalog prices change.

### Existing patient-plan layer

- `aos_planes_trabajo` exists but currently has 0 rows;
- `aos_plan_trabajo_items` exists but currently has 0 rows;
- the schema already supports service/product, session count, frequency, price, dose, timing, alternatives, selected state, phase, priority, quote link, sale link and appointment link.

This is the correct future patient-specific authority; WA-4A.1C process templates must remain structural and must not replace it.

### Existing RPC risk boundary

`aos_crear_cotizacion(jsonb)` and `aos_plan_a_cotizacion(...)` accept caller-provided prices. They remain legacy/operational functions and are NOT promoted to WA4 price authority.

WA-4A.1C therefore introduces a private read-only preview that resolves prices from the canonical catalog/topping sources and fails closed on stale/anomalous values. It does not replace or mutate legacy quote RPCs in this phase.

## 1C architecture

### Price authority

`aos_wa4_price_authority_v1`:

- reads only active `aos_catalogo_servicios`;
- exposes base + offer + canonical quote candidate;
- classifies missing/nonpositive/offer-above-base price;
- applies 180-day freshness guard;
- generates evidence reference;
- never writes price.

`aos_wa4_topping_authority_v1`:

- reads active `aos_catalogo_toppings`;
- separates `PAID_ADDON` from `ZERO_PRICE_BENEFIT_CANDIDATE`;
- topping is candidate-only and never auto-added.

### Process templates

Eight structural templates mirror the certified approaches:

- Facial / Skin Signature;
- Facial / Harmony Design;
- Facial / BioRegen Face;
- Corporal / Body Reset;
- Corporal / Sculpt Body;
- Corporal / Sculpt Booty;
- Capilar / Activación & Regeneración;
- Capilar / Mantenimiento & Prevención.

All templates are `STRUCTURAL_NOT_PRESCRIPTIVE`; they contain no hardcoded current prices and no patient-specific dose/session prescription.

### Component roles

- `REQUIRED_BY_PLAN`;
- `OPTIONAL_SUPPORT`;
- `ALTERNATIVE`;
- `DEPENDENT`;
- `CONTROL`;
- `MAINTENANCE`;
- `PRODUCT_SUPPORT`;
- `TOPPING_ELIGIBLE`.

No role is auto-assignable. `REQUIRED_BY_PLAN`, `ALTERNATIVE`, `DEPENDENT` and `CONTROL` require authorized-plan context where applicable.

### Read-only quote preview

`aos_wa4_quote_preview_v1(jsonb,text,boolean)`:

- private/service-role only;
- no patient input;
- no quote/payment/plan write;
- requires explicit component role + commercial phase;
- validates phase against WA-4A.1B entity mapping;
- obtains current prices only from governed read models;
- fails closed on stale/anomalous price;
- `COMPLETE` vs `PROGRESSIVE` changes presentation only, never canonical scope/total;
- progressive view groups the same total by F1/F2/F3;
- no discount math;
- topping requires explicit TOPPING_ELIGIBLE role and context approval;
- returns price fingerprint/evidence refs for later copilot use.

## Safety boundary

- no `aos_pacientes`, lead, sale or REV mutation;
- no catalog price mutation;
- no quote/payment/plan mutation;
- no price copied from PDF/document examples;
- no margin/cost exposed publicly;
- no autonomous discount;
- no autonomous clinical selection;
- no AI send/auto-reply/auto-routing activation;
- WA-4B remains blocked until exact-head 1C certification and closeout.

## PROD boundary

WA-4A.1C feature DDL remains TEST-first / PROD-ready while the existing promotion hold remains. PROD is used only for read-only inventory/fingerprint in this phase; no 1C feature migration is applied during TEST certification.
