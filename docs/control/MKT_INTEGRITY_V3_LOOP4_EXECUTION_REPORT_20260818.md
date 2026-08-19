# MKT-INTEGRITY-HOTFIX-V3 — LOOP 4 Execution Report

**Loop:** Deterministic late-lead backfill  
**Business date:** 2026-08-18 Lima  
**Entry main:** `e6649515afa2e7aa3854d91a6594624cb084e0e2`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Loop 5:** NOT STARTED

## Result before final GitHub merge/readback

`PASS_PENDING_FINAL_MERGE_READBACK`

## G0 — Pre-flight

PASS.

- exact main matched Loop-3 closeout SHA;
- CURRENT/Notion showed Loop 3 PASS / Loop 4 NOT STARTED;
- REV-F5 remained 7,064 / 15,498 and 3,950 clusters, members/preview/apply all zero;
- Acquisition V2/V3 = 54/55;
- V3 acquisition hash = `3223caf0ec5d1b264c4494775c6f7d58`;
- V3-only remained `973438607 → lead 2135`;
- `37108` / `37110` remained absent;
- productive Marketing frontend remained on `aos_marketing_leads_detalle`.

## G1 — Live late-lead universe

PASS.

Universe re-derived from Supabase live without using the old 19/17/2 shorthand:

- total candidates = **54**
- initial `LATE_SAME_DAY_COMPATIBLE` = 44
- initial prior-lead resolution = 9
- initial `NO_MATCH` = 1

Strict Loop-4 classification:

- AUTO_BACKFILL_STRONG = **24**
- REVIEW_BLANK_TREATMENT = **20**
- PRIOR_LEAD_ALREADY_EXPLAINS = **9**
- REVIEW_TREATMENT_MISMATCH = **1**
- REVIEW_MULTIPLE_CANDIDATES = **0**

Canonical candidate table: `docs/control/MKT_INTEGRITY_V3_LOOP4_BACKFILL_EVIDENCE_20260818.md`.

## G2 — Target batch

PASS.

24 calls selected:

`14546,14547,14548,14828,15076,15468,15800,15801,17043,17818,18130,18131,18132,18133,18134,18135,18304,21692,21693,21722,23096,30320,33358,36025`.

Lead mapping:

- 14546→2799
- 14547→2802
- 14548→2798
- 14828→2819
- 15076→2847
- 15468→2875
- 15800→2881
- 15801→2883
- 17043→2922
- 17818→3005
- 18130→3019
- 18131→3018
- 18132→3020
- 18133→3023
- 18134→3021
- 18135→3022
- 18304→3047
- 21692→3321
- 21693→3320
- 21722→3322
- 23096→3420
- 30320→4045
- 33358→5001
- 36025→5444

Six deterministic Agenda links selected:

- `1c3467c9-0536-4c71-86e1-561638e9401c` → lead 2819 / call 14828
- `f5b8243b-f21f-4a8c-804a-641b888c1e2e` → lead 2847 / call 15076
- `2830674b-66bc-4104-a920-62f2f313aaab` → lead 2875 / call 15468
- `33dc643c-78e8-4ef2-a235-7e174c98bbb5` → lead 4045 / call 30320
- `883962de-e15b-42b8-89da-6db8a6b12704` → lead 5001 / call 33358
- `df37e522-ce4b-4edc-aa79-0b7bf4e1517d` → lead 5444 / call 36025

## G3 — Blank-treatment safety

PASS.

No blank-treatment call was approved from phone + temporal proximity alone.

Blank-treatment calls admitted only when a unique near Agenda supplied a compatible treatment family:

- 14828
- 15076
- 15468
- 36025

All other blank-treatment late candidates stayed REVIEW.

## G4 — Existing-patient context

PASS.

All 24 applied calls had before-call:

- prior sales = 0
- prior clinical attentions = 0
- prior attended/EFECTIVA appointments = 0

`30320 / 998564399` is an eventual Acquisition customer but was not converted before the 2026-07-06 call; it therefore remained a valid deterministic late-lead target.

## G5 — Mandatory rollback simulation

PASS.

The exact 24-call + 6-Agenda overlay was executed inside a deliberately failing PL/pgSQL statement (`LOOP4_SIMULATION_ROLLBACK`). PostgreSQL rolled it back.

Simulation:

- call updates = 24
- Agenda updates = 6
- call matcher after overlay = 24 `DIRECT_LEAD_ID`
- Agenda matcher after overlay = 6 `DIRECT_LEAD_ID`
- Acquisition V2 = 54
- Acquisition V3 = 55
- sole V3-only = `973438607 → lead 2135`
- duplicate acquisitions = 0
- post-sale lead attribution = 0
- V3 acquisition hash = `3223caf0ec5d1b264c4494775c6f7d58`
- Attribution V2 = 126 / S/45,158.70
- Attribution V3 = 173 / S/66,644.10

A subsequent rollback probe returned 0 persisted calls, 0 Agenda leads and 0 Agenda calls.

## G6 — Concurrency revalidation

PASS.

Immediately before apply:

- main still `e6649515afa2e7aa3854d91a6594624cb084e0e2`;
- all 24 call rows found;
- call violations = 0;
- all 6 Agenda rows found;
- Agenda violations = 0;
- all 24 still matched the exact expected V3 lead and family/temporal criteria;
- all 24 still had `lead_id_origen IS NULL`;
- all 6 Agenda rows still had both trace-link fields NULL;
- REV-F5 remained intact.

## G7 — Productive apply

PASS.

A single atomic PL/pgSQL statement applied the exact batch with row-count guards:

- required call updates = 24;
- required Agenda updates = 6;
- any mismatch would raise and rollback the entire statement.

The statement completed without exception.

No rows were created or deleted. No state/date/advisor/treatment/revenue field was changed.

## G8 — Post-apply readback

PASS.

At 2026-08-18 21:41:28 Lima:

- exact call mappings = **24/24**;
- mismatched calls = **0**;
- exact Agenda mappings = **6/6**;
- mismatched Agenda = **0**;
- target call matcher = `DIRECT_LEAD_ID` × 24;
- target Agenda matcher = `DIRECT_LEAD_ID` × 6;
- NO-ACTION candidate rows still NULL = **30/30**;
- NO-ACTION candidate rows changed = **0**.

Core row counts remained calls 35,309 / Agenda 3,126 / leads 5,679 / sales 1,299 because Loop 4 only changed trace-link columns.

## G9 — Acquisition / Attribution invariants

PASS.

Acquisition after apply:

- V2 = **54**
- V3 = **55**
- V3-only = exactly `973438607 → lead 2135`
- duplicates = **0**
- post-sale lead attribution = **0**
- deterministic hash = `3223caf0ec5d1b264c4494775c6f7d58`

Attribution after apply:

- V2 = **126 ops / S/45,158.70**
- V3 = **173 ops / S/66,644.10**

No revenue-attribution output changed. The Loop-9 barrier remains unchanged and no cutover occurred.

## G10 — Controls

PASS.

Known control calls after apply:

- 14828 → lead 2819
- 15076 → lead 2847
- 15468 → lead 2875
- 30320 → lead 4045
- 33358 → lead 5001
- 36025 → lead 5444
- 35858 → still NULL; prior lead 5353 remains the V3 resolution

Additional controls:

- `961780427`: latest call still NULL direct-link; V3 resolves prior lead 4650 via `TIMELINE_NEAREST_PRIOR_FAMILY`.
- `957549186`: call 35976 remains NULL / `NO_MATCH / NO_MARKETING_TOUCHPOINT`.
- `992829013`: V2=1 / V3=1 Acquisition customer.
- `998564399`: V2=1 / V3=1 Acquisition customer.
- `37108` / `37110`: still absent.

## G11 — Function / F5 integrity

PASS.

Function hashes remained exactly:

- Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`
- Acquisition V3 `07762236ceb159ec29c34cc2eb1c5b3a`
- Agenda matcher V3 `49c13d3f034b059871b2dc7aa0c7c981`
- Call matcher V3 `8d9ff10aaee45542e6bb527142cea178`
- Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`
- Attribution V3 `ef613afdbf9175c27ebc34bb0763961e`

REV-F5 remained:

- batches 6 / expected 15,498
- source rows 7,064
- clusters 3,950
- members 0
- preview 0
- apply 0
- F5 max-write timestamps unchanged

## G12 — Idempotency

PASS.

A second exact dry-run was executed in a rollback-only PL/pgSQL probe:

- call updates = **0**
- Agenda updates = **0**
- `expected_zero = true`

## Rollback

Exact rollback exists at:

`docs/control/MKT_INTEGRITY_V3_LOOP4_ROLLBACK_20260818.sql`

It only reverts rows whose current AFTER lead/call IDs exactly match this Loop-4 package.

## Versioned forward SQL

`supabase/backfills/20260818_mkt_integrity_v3_loop4_late_lead_backfill.sql`

The file is explicitly not an automatic migration.

## Pre-merge conclusion

Functional Loop 4 has passed every live database gate.

Final PASS requires:

1. exact-head revalidation;
2. branch blast-radius verification;
3. PR merge using `expected_head_sha`;
4. post-merge Supabase/GitHub/REV-F5 readback;
5. CURRENT finalization;
6. Notion synchronization.

Do not start Loop 5.
