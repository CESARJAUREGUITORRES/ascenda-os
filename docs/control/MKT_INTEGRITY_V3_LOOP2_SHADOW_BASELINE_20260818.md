# MKT-INTEGRITY-HOTFIX-V3 — LOOP 2 Shadow Baseline

**Business date:** 2026-08-18 Lima  
**Pre-flight main:** `d2113e6e5be91210e111a33813f6d8167b1eb54e`  
**Supabase migration:** `20260819015951_mkt_integrity_v3_shadow_loop2_20260818`  
**Mode:** SHADOW / service_role only / frontend unchanged

## V3 objects and definition hashes

| Object | Args | Definition MD5 |
|---|---|---|
| `aos_marketing_acquisition_customers_v3_preview` | `()` | `07762236ceb159ec29c34cc2eb1c5b3a` |
| `aos_marketing_agenda_lead_match_v3_preview` | `(date,date)` | `49c13d3f034b059871b2dc7aa0c7c981` |
| `aos_marketing_attribution_v3_preview` | `(date,date)` | `ef613afdbf9175c27ebc34bb0763961e` |
| `aos_marketing_call_lead_match_v3_preview` | `(date,date)` | `8d9ff10aaee45542e6bb527142cea178` |
| `aos_marketing_leads_detalle_v3_paged` | `(date,date,text,text,integer,integer)` | `5ef19386a24f069a69675e096b96249f` |
| `aos_marketing_leads_detalle_v3_summary` | `(date,date,text,text)` | `c4cfc9ae3fb4f1aa57e5b9ee76383429` |
| `aos_marketing_touchpoint_rollup_v3_preview` | `(date,date)` | `c9c735e3d8416f8b27fc7053a0579fdc` |
| `aos_marketing_treatment_family_v3` | `(text)` | `3aceda874d6a8fb6e787ab51a5abc9fc` |

ACL for every exact Loop-2 object is restricted to `postgres` + `service_role`; no anon/authenticated/public execution is granted in Loop 2.

## V2 definition hashes after V3 migration

All are identical to Loop 1 BEFORE:

- Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`
- Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`
- Call→Lead V2 `bcdfc95ac762bfc10dfa0a60c5a9a354`
- Cohort LTV V2 `b6d2035a3420c6956e3b0248d56e86f6`
- Histórico V2 `8147cc91935da68ab550435cf7016556`
- Leads detalle V2 `f25d7c4f052f70e3a3aa901b0afdcf18`
- Leads paged V2 `9b1d34f0230f4a4870bfba7185a73402`
- Leads summary V2 `cbd625a744f312bb6e44b28d3b586da4`
- Period summary V2 `eef10aee61e44898864e355f6197bc1f`
- Panel asesor `3dc5f2275c84af5efbaf19b337174ea9`
- Monitoreo `a961d4a99dd35435fe1cf681d7ca8ee9`

## Acquisition shadow parity seed

- V2: **54 customers**.
- V3 shadow: **55 customers**.
- V2-only: **0**.
- V3-only: exactly **1**.

V3-only row:

- phone `973438607`;
- selected touchpoint `lead 2135`;
- lead date `2026-03-11`;
- first sale date `2026-03-12`;
- method `NEAREST_PRIOR_FIRST_SALE`;
- confidence `55`.

This is the user-approved expected candidate for Loop 3 parity. Loop 2 does not modify V2 or LTV.

## Attribution shadow delta

2026-01-01 through 2026-08-18:

| Metric | V2 | V3 shadow | Delta |
|---|---:|---:|---:|
| Operations | 126 | 173 | +47 |
| Attributed amount | S/45,158.70 | S/66,644.10 | +S/21,485.40 |

V3-only breakdown:

- `ACQUISITION_HISTORICAL_UNIQUE_MATCH`: **45 ops / 18 persons / S/20,897.40**.
- `ACQUISITION_NEAREST_PRIOR_FIRST_SALE`: **2 ops / 1 person / S/588** (`973438607`).

Interpretation: Loop-2 V3 attribution adds all operations occurring on the already-recognized first-sale date when an acquisition touchpoint is known. This is intentionally shadow and is **not approved for production cutover** yet. Loop 3/9 must decide whether the operation-level expansion is semantically correct before any reporting migration.

## Buyer reference cases

### `992829013`

- Acquisition customer remains lead `3963` HIFU.
- V2 attributed operations: **0 / S0**.
- V3 shadow: **2 / S1,018** on first-sale day.
- Actual sales recorded: **5 / S2,467**.
- Remaining S/1,449 is not auto-promoted by Loop 2 and requires later acquisition-vs-followup semantics.

### `998564399`

- Acquisition customer remains lead `4045` CAPILAR.
- V2 attributed operations: **0 / S0**.
- V3 shadow: **4 / S1,567**.
- Actual sales: **4 / S1,567**.
- Later patient continuities are not turned into new acquisition events by this shadow acquisition function.

## Call→Lead shadow methods, 2026 through 18 Aug

- DIRECT_LEAD_ID: **33**
- LATE_SAME_DAY_COMPATIBLE: **44**
- TIMELINE_NEAREST_PRIOR: **647**
- TIMELINE_NEAREST_PRIOR_FAMILY: **29,970**
- NO_MATCH: **4,602**

Review/unresolved reasons:

- NO_MARKETING_TOUCHPOINT: **4,164**
- PRIOR_TREATMENT_MISMATCH: **438**

These are diagnostic shadow classifications, not a backfill list.

Reference gates:

- call `32014` / `961780427` → lead **4650 CAPILAR**, `TIMELINE_NEAREST_PRIOR_FAMILY`, confidence 80, no review.
- call `35976` / `957549186` → **no automatic lead**, `NO_MATCH`, confidence 0. It remains review-only.
- Mireya calls `37108` and `37110`: still **absent** from `aos_llamadas` in Loop 2; restoration remains Loop 5.

## Leads modal shadow summary

### Annual 2026 through 18 Aug

V2 current summary:

- total 5,669;
- llamados 5,460;
- con cita 746;
- vendidos 56;
- sin contacto 207;
- monto S/101,959.85.

V3 shadow:

- effective touchpoints **5,628**;
- unique persons **5,338**;
- called touchpoints **5,444** / unique called persons **5,331**;
- touchpoints with attributed cita **480** / unique persons **478**;
- sold/attributed touchpoints **55** / unique sold persons **55**;
- no-contact touchpoints **184** / unique persons **163**;
- acquisitions **55**;
- attributed sales operations **173**;
- attributed amount **S/66,644.10**.

The large cita/revenue difference is expected at this shadow stage because V2 copies phone-window events across touchpoints while V3 resolves events to one touchpoint. It is a parity subject, not a production replacement decision in Loop 2.

### August 2026 through 18 Aug

V2: 658 total / 612 called / 44 con cita / 5 sold / 44 sin contacto / S/2,402.

V3 shadow: 651 effective touchpoints / 643 persons / 610 called / 43 con cita / 4 sold / 41 sin contacto / **4 acquisitions / 10 sale operations / S/2,352**.

The V3 amount matches the current August M0 acquisition/LTV amount S/2,352; V2 modal includes a broader phone-window amount. Keep both visible for Loop 3/9 analysis.

## Non-exclusive filters proven

V3 `CON CITA` annual filter returns 480 touchpoints and includes **42 sold touchpoints**. Therefore sold leads no longer disappear from the `CON CITA` dimension in the shadow contract.

V3 `VENDIDO` annual filter returns 55 sold touchpoints/persons, with 42 also having an attributed cita.

## Pagination proven beyond 1,000

- offset 0 / limit 100 → 100 rows, `total_rows=5,628`.
- offset 1,000 / limit 100 → 100 rows, `total_rows=5,628`.

Thus the V3 paged contract has no 1,000-row universe ceiling.

## Duplicate-phone reference `998719392`

V3 returns two separate touchpoints without repeating the old phone-level aggregate onto both:

- lead `4681` (2026-07-22): **1 call / 0 citas / 0 attributed sales**;
- lead `5203` (2026-08-07): **5 calls / 2 citas / 0 attributed sales**.

Its old-customer/re-activation revenue is intentionally not forced into acquisition V3; reactivation attribution belongs to later loops.

## Determinism / cutover status

The functions are SQL STABLE/IMMUTABLE shadow functions. Loop 2 only reads them. They are not frontend-addressable by anon/authenticated roles, and production frontend was not changed.

**Shadow baseline status:** `CAPTURED_FOR_LOOP3_PARITY`.
