# MKT-INTEGRITY-HOTFIX-V3 — LOOP 3 Acquisition Parity

**Scope:** Acquisition V2 ↔ V3 parity only  
**Business date:** 2026-08-18 Lima  
**Entry main:** `3f42a8cdce3f45b32b641874bdfe8f1155a7c05c`  
**Branch:** `audit/mkt-integrity-v3-loop3-acquisition-parity`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Loop 4:** NOT STARTED

## Result

`PASS`

No V3 code correction was required. Loop 3 remained read-only against Supabase and docs-only in GitHub.

## Gate 0 — pre-flight

PASS.

- `main` exact-head at entry: `3f42a8cdce3f45b32b641874bdfe8f1155a7c05c`.
- CURRENT: `MKT-INTEGRITY-HOTFIX-V3` active.
- REV-F5: 6 batches / 15,498 expected / 7,064 source rows / 3,950 clusters / 0 members / 0 preview / 0 apply.
- F5 max batch/source write timestamp: `2026-08-18T20:13:13.549661+00:00`; cluster max update: `2026-08-15T22:23:56.291622+00:00`; all predate the Marketing freeze.
- Function definition hashes remained:
  - Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`
  - Acquisition V3 `07762236ceb159ec29c34cc2eb1c5b3a`
  - Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`
  - Attribution V3 `ef613afdbf9175c27ebc34bb0763961e`
- `37108` and `37110`: absent.
- Known unresolved late-call control ids `14828,15076,15468,30320,33358,35858,36025` remained `lead_id_origen IS NULL`; no late-lead backfill was executed.
- Productive Marketing modal still calls `aos_marketing_leads_detalle`; V3 is not a browser path.

Normal production activity occurred after the Loop-2 readback: at Loop-3 preflight core counts were calls 35,296 / agenda 3,126 / leads 5,679 / sales 1,299. This is external operational activity; Loop 3 itself issued SELECT/read-only SQL only.

## Set parity

| Metric | Result | Gate |
|---|---:|---|
| Acquisition V2 | 54 | PASS |
| Acquisition V3 | 55 | PASS |
| Shared V2 ∩ V3 | 54 | PASS |
| V2-only | 0 | PASS |
| V3-only | 1 | PASS |
| V2 distinct persons | 54 | PASS |
| V3 distinct persons | 55 | PASS |
| Duplicate V3 acquisitions | 0 | PASS |
| Post-sale-date lead attribution | 0 | PASS |
| Nearest-prior cases | 1 | PASS |

The only V3-only row is:

- `973438607 → lead 2135`
- lead date `2026-03-11`
- first sale `2026-03-12`
- `NEAREST_PRIOR_FIRST_SALE`
- confidence 55

There are no V2-only customers.

## 54 shared customers — field-by-field parity

The parity query joined V2 and V3 by `numero_limpio` and compared every required field for all 54 shared persons.

| Field | Differences |
|---|---:|
| `lead_id` | 0 |
| `lead_fecha` | 0 |
| `lead_tratamiento` | 0 |
| `lead_anuncio` | 0 |
| `first_sale_date` | 0 |
| `attribution_method` | 0 |
| `confidence` | 0 |

Therefore all **54/54 shared acquisition rows are byte-semantically equivalent on the audited business fields**. Lead classification for every shared row: `MISMO LEAD`.

Shared persons audited:

`954848810, 989519020, 980749071, 960381839, 930260184, 964633863, 974634132, 989920925, 997086663, 964701041, 992068099, 993594413, 940255774, 927566056, 969558271, 944910048, 923236071, 980960292, 985955149, 920006559, 956459519, 964828622, 993445662, 901147623, 987188705, 912133194, 926342759, 959907978, 952646533, 993212670, 916774777, 976603385, 955684794, 958458750, 923265344, 947497340, 991685745, 930812057, 990504211, 998232349, 978957729, 992829013, 944290839, 998564399, 990980264, 987733390, 917081574, 993039075, 977450609, 969733149, 965324625, 955438173, 963731937, 962962953`.

## Cohort parity

Cohort is the selected Marketing lead month (`lead_fecha`), matching the existing acquisition cohort baseline.

| Month | V2 | V3 | Delta |
|---|---:|---:|---:|
| JAN | 9 | 9 | 0 |
| FEB | 5 | 5 | 0 |
| MAR | 9 | 10 | **+1** |
| APR | 3 | 3 | 0 |
| MAY | 8 | 8 | 0 |
| JUN | 8 | 8 | 0 |
| JUL | 8 | 8 | 0 |
| AUG | 4 | 4 | 0 |
| **TOTAL** | **54** | **55** | **+1** |

The only cohort delta is the expected March +1 from `973438607 → lead 2135`.

For completeness, grouping by first-sale month also differs by exactly one row in March; no other first-sale month changes.

## Temporal safety

- `lead_fecha > first_sale_date`: **0**.
- same-calendar-day lead + first sale: **5**.
- all five same-day cases have `lead_ts <= sale.created_at` for every sale row recorded on the first-sale date.
- several historical sale `created_at` values are technical import/write timestamps, not guaranteed business-event timestamps; therefore the canonical gate remains the date-level rule authorized by the roadmap. There is no date inversion.

Same-day cases:

| Phone | Lead | Lead date | First sale | Ops | Result |
|---|---:|---|---|---:|---|
| 901147623 | 2893 | 2026-04-22 | 2026-04-22 | 1 | temporal PASS |
| 956459519 | 2523 | 2026-03-28 | 2026-03-28 | 1 | temporal PASS |
| 958458750 | 3518 | 2026-05-30 | 2026-05-30 | 1 | temporal PASS |
| 959907978 | 3262 | 2026-05-15 | 2026-05-15 | 2 | temporal PASS |
| 998232349 | 3789 | 2026-06-17 | 2026-06-17 | 1 | temporal PASS |

`POST_SALE_LEAD_ATTRIBUTION = 0`.

## Audit — `973438607`

Chronology:

1. Lead `1150` — 2026-02-05 — HIFU — `HIFU - Resultado sin pinchazo`.
2. Lead `2135` — 2026-03-11 — HIFU — `HIFU - No te gustan las agujas? 06/10/25`.
3. First-sale date — 2026-03-12 — 2 operations / S/588 total (`TOXINA` + `COMPRA DE PRODUCTO`).

Pre-existing-customer checks before selected lead 2135:

- sales before 2026-03-11: **0**;
- clinical attentions before 2026-03-11: **0**;
- attended/EFECTIVA appointments before 2026-03-11: **0**;
- prior valid Acquisition V2 row: **0**.

The February lead 1150 is a prior non-winning Marketing touchpoint. Lead 2135 is the nearest prior touchpoint before first sale. No later lead is selected. Therefore this row is certified as a genuine new acquisition rather than reactivation/seguimiento.

**Certification:** `973438607 → lead 2135` is the sole new Acquisition V3 customer.

## Nearest-prior safety

All V3 `NEAREST_PRIOR_FIRST_SALE` rows were audited.

Count: **1**.

Only case: `973438607 → lead 2135`.

No unexpected nearest-prior case exists.

## First-sale-day operation evidence

All 55 acquisition persons were joined to every `aos_ventas` row on their `first_sale_date`.

Aggregate evidence:

- acquisition persons: **55**;
- first-sale-day operations: **133**;
- first-sale-day revenue: **S/50,856.10**.

This is evidence only. It does not authorize the larger Attribution V3 operation universe.

Reference controls:

- `992829013`: Acquisition V2=1 / V3=1; 5 sales total S/2,467; first-sale day 2 ops S/1,018.
- `998564399`: Acquisition V2=1 / V3=1; 4 sales total S/1,567; first-sale day 4 ops S/1,567.
- `961780427`: Acquisition V2=0 / V3=0; prior CAPILAR lead evidence does not create an acquisition without a sale.
- `957549186`: Acquisition V2=0 / V3=0; remains non-acquisition/review territory and is not inferred automatically.

## Attribution V3 barrier

The Loop-2 attribution delta remains unchanged and is explicitly **not approved for cutover**:

- V2: **126 ops / S/45,158.70**.
- V3 shadow: **173 ops / S/66,644.10**.
- delta: **+47 ops / +S/21,485.40**.

Status: `OPEN FOR LOOP 9 / REVENUE ATTRIBUTION`.

Loop 3 certifies acquisition persons only.

## Determinism

Canonical ordered V3 output hash:

`3223caf0ec5d1b264c4494775c6f7d58`

It was generated in separate V3 reads and remained identical.

## Safety / no-write certification

Loop 3 made no Supabase DDL or DML call. All database work in this loop used read-only SELECT statements.

Therefore Loop 3 performed:

- 0 writes to `aos_llamadas`;
- 0 writes to `aos_agenda_citas`;
- 0 writes to `aos_leads`;
- 0 writes to `aos_ventas`;
- 0 late-lead backfills;
- 0 Mireya restorations;
- 0 V2 changes;
- 0 V3 functional changes;
- 0 frontend changes;
- 0 REV-F5 changes.

## Loop-3 certification

All Loop-3 acceptance gates pass:

- V2 = 54;
- V3 = 55;
- shared = 54;
- V2-only = 0;
- V3-only = exactly `973438607`;
- `973438607 → lead 2135` certified;
- only cohort delta = March +1;
- post-sale-date attribution = 0;
- duplicate acquisition = 0;
- lead-id differences = 0;
- nearest-prior cases = exactly 1 expected case;
- deterministic V3 hash stable;
- V2 intact;
- business data untouched by Loop 3;
- frontend remains productive/non-V3;
- REV-F5 intact.

**LOOP 3 = PASS.**

**LOOP 4 = NOT STARTED.**
