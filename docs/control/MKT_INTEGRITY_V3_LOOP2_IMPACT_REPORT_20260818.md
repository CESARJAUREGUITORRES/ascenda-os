# MKT-INTEGRITY-HOTFIX-V3 — LOOP 2 Impact Report

**Loop:** 2 — Marketing V3 Shadow  
**Business date:** 2026-08-18 Lima  
**Pre-flight main:** `d2113e6e5be91210e111a33813f6d8167b1eb54e`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**REV-F5:** `PAUSED_RECOVERABLY` at 7,064 / 15,498 source rows, 3,950 clusters, 0 members/preview/apply.  
**Supabase:** `ituyqwstonmhnfshnaqz`

## Purpose

Create a **shadow/read-only Marketing V3 layer** beside V2. V2 remains the production source of truth for all current consumers. Loop 2 does not backfill business data, restore Mireya calls, redirect frontend, or alter V2 definitions.

## Pre-flight evidence

- `main` revalidated at `d2113e6e5be91210e111a33813f6d8167b1eb54e`.
- `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md` confirms `MKT-INTEGRITY-HOTFIX-V3` as the sole mutable HIGH/CRITICAL owner.
- F5 counts remain 6 batches / 15,498 expected / 7,064 persisted / 3,950 clusters / 0 members / 0 preview / 0 apply.
- No F5 write timestamp is later than the Loop 1 freeze. The recomputed ad-hoc hashes used during this Loop differ because the Loop 1 hash serialization SQL was not persisted; therefore F5 immutability is verified through frozen counts plus max write timestamps, while the original Loop 1 recovery hashes remain the canonical handback values.
- All V2 **function-definition hashes** match the Loop 1 manifest exactly:
  - `aos_marketing_acquisition_customers_v2`: `7851ca8c9163625bda8fcf987a1def87`
  - `aos_marketing_attribution_v2_preview`: `630c46e0425e6941283f1b200d3a5ce2`
  - `aos_marketing_call_lead_match_v2`: `bcdfc95ac762bfc10dfa0a60c5a9a354`
  - `aos_marketing_cohortes_ltv_v2_preview`: `b6d2035a3420c6956e3b0248d56e86f6`
  - `aos_marketing_historico_v2_preview`: `8147cc91935da68ab550435cf7016556`
  - `aos_marketing_leads_detalle_v2`: `f25d7c4f052f70e3a3aa901b0afdcf18`
  - `aos_marketing_leads_detalle_v2_paged`: `9b1d34f0230f4a4870bfba7185a73402`
  - `aos_marketing_leads_detalle_v2_summary`: `cbd625a744f312bb6e44b28d3b586da4`
  - `aos_marketing_period_summary_v2`: `eef10aee61e44898864e355f6197bc1f`
  - `aos_panel_asesor`: `3dc5f2275c84af5efbaf19b337174ea9`
  - `aos_monitoreo_equipo`: `a961d4a99dd35435fe1cf681d7ca8ee9`

Operational V2 baseline remains Acquisition 54 and Attribution 126 operations / S/45,158.70 at the pre-flight read.

## New objects permitted in Loop 2

Required:

1. `aos_marketing_acquisition_customers_v3_preview()`
2. `aos_marketing_attribution_v3_preview(date,date)`
3. `aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer)`
4. `aos_marketing_leads_detalle_v3_summary(date,date,text,text)`

Auxiliary shadow/read-path objects are allowed when V3-namespaced and fully reversible. Planned auxiliaries:

- `aos_marketing_treatment_family_v3(text)` — deterministic normalization helper.
- `aos_marketing_call_lead_match_v3_preview(date,date)` — shadow call→touchpoint resolver with explicit/prior/late compatible methods.
- `aos_marketing_agenda_lead_match_v3_preview(date,date)` — shadow Agenda→touchpoint resolver using explicit links, call links, prior touchpoint and controlled late-lead matching.
- `aos_marketing_touchpoint_rollup_v3_preview(date,date)` — one-row-per-touchpoint rollup used by paged/summary functions so calls/citas/sales do not multiply across multiple leads of one phone.

## Production objects explicitly NOT modified

- every `*_v2*` function;
- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_leads`;
- `aos_ventas`;
- Home/Monitoreo RPCs;
- Call Center frontend (`app/public/calls.js`);
- Agenda frontend;
- Marketing frontend/modal;
- LTV/Historical productive functions;
- REV-F5 tables/functions.

## Shadow semantics

V3 is prepared to distinguish:

- ADQUISICION;
- RECUPERACION_LEAD;
- ORGANICO;
- REACTIVACION;
- SEGUIMIENTO;
- AGENDA_NORMAL / CONTINUIDAD;
- REVIEW / AMBIGUOUS.

Attribution precedence:

1. explicit `lead_id_origen`;
2. explicit/strong call+cita chain;
3. compatible late lead, same phone and controlled temporal window;
4. unique prior touchpoint before first sale;
5. nearest prior touchpoint before first sale as final fallback;
6. real treatment mismatch remains REVIEW.

No sale may be attributed to a touchpoint after that sale. A prior NO ASISTIO/CANCELADA alone is not evidence of a converted patient.

## Cases that must remain read-only in Loop 2

- `973438607` may appear as the single shadow nearest-prior acquisition candidate (`lead 2135`), but V2 is not changed.
- `992829013` and `998564399` must remain existing Acquisition V2 customers; operation-level gaps may be surfaced but not backfilled.
- `37108` / `37110` remain deleted in business data; restoration is Loop 5.
- `961780427` must prefer its prior CAPILAR lead `4650` when evidence supports it.
- `957549186` remains REVIEW for CAPILAR↔BIO mismatch unless new evidence appears.

## Business-data no-write invariant

Before and after the DDL migration, record row counts/high-water marks for:

- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_leads`;
- `aos_ventas`.

Ordinary production traffic may increase counts while the loop runs; therefore the gate is **no writes attributable to this migration**, not frozen global totals. The migration itself contains CREATE FUNCTION / COMMENT / GRANT only and no DML against business tables.

## Rollback

Rollback is schema-only and may DROP only the V3 objects created by Loop 2. It must not touch V2 or business tables. After rollback simulation/inspection:

- V2 definition hashes must remain identical;
- frontend must still reference V2;
- REV-F5 counts/write timestamps must remain unchanged by this workstream.

## Validation plan

1. apply one DDL migration containing V3 shadow objects only;
2. inspect `pg_get_functiondef` and hashes for all V3 objects;
3. execute SELECT-only shadow comparisons V2↔V3 by month and reference case;
4. verify no V2 definition hash changed;
5. inspect repository frontend references to confirm V2 remains wired;
6. re-read REV-F5 counts/write timestamps;
7. revalidate exact `main` before PR merge;
8. merge only migrations + `docs/control/**` expected for Loop 2;
9. read back Supabase and Notion; stop before Loop 3.

## Stop conditions

STOP if V3 requires modifying V2, writing business data, redirecting frontend, modifying REV-F5, or if any unexplained V2 definition change appears.

**Impact gate status:** `APPROVED_FOR_SHADOW_DDL_ONLY`.
