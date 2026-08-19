# MKT-INTEGRITY-HOTFIX-V3 — LOOP 4 Impact Report

**Loop:** Deterministic late-lead backfill  
**Business date:** 2026-08-18 Lima  
**Entry main:** `e6649515afa2e7aa3854d91a6594624cb084e0e2`  
**Branch:** `feat/mkt-integrity-v3-loop4-late-lead-backfill`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Loop 5:** NOT STARTED

## Gate 0

PASS.

- main exact-head matched the Loop-3 closeout SHA.
- CURRENT: Loop 1 PASS / Loop 2 PASS / Loop 3 PASS / Loop 4 NOT STARTED.
- REV-F5 remained 6 batches / 15,498 expected / 7,064 source rows / 3,950 clusters / 0 members / 0 preview / 0 apply.
- F5 max batch/source write remained `2026-08-18T20:13:13.549661+00:00`; cluster max update remained `2026-08-15T22:23:56.291622+00:00`.
- Acquisition V2 = 54.
- Acquisition V3 = 55.
- deterministic V3 acquisition hash = `3223caf0ec5d1b264c4494775c6f7d58`.
- V3-only = exactly `973438607 → lead 2135`.
- `37108` / `37110` remained absent.
- productive Marketing frontend still calls `aos_marketing_leads_detalle`, not a V3 browser RPC.
- operational counts at preflight: calls 35,309 / agenda 3,126 / leads 5,679 / sales 1,299. Operational counts are not frozen invariants.

Function-definition hashes at entry:

- Acquisition V2: `7851ca8c9163625bda8fcf987a1def87`
- Acquisition V3: `07762236ceb159ec29c34cc2eb1c5b3a`
- Agenda matcher V3: `49c13d3f034b059871b2dc7aa0c7c981`
- Call matcher V3: `8d9ff10aaee45542e6bb527142cea178`
- Attribution V2: `630c46e0425e6941283f1b200d3a5ce2`
- Attribution V3: `ef613afdbf9175c27ebc34bb0763961e`

## Live universe re-derived from scratch

The historical planning shorthand `19/17/2` was not used as truth.

Live derivation criteria:

- `aos_llamadas.lead_id_origen IS NULL`;
- same normalized phone has a later Marketing touchpoint;
- later touchpoint is within 12 hours;
- same business date in `America/Lima`;
- V3 call matcher used to resolve prior-vs-late semantics;
- treatment-family compatibility enforced when the call contains treatment.

Result: **54 calls**.

Initial V3 methods:

- `LATE_SAME_DAY_COMPATIBLE`: 44
- `TIMELINE_NEAREST_PRIOR_FAMILY`: 9
- `NO_MATCH`: 1

Strict Loop-4 classification after applying blank-treatment and prior-patient gates:

- `AUTO_BACKFILL_STRONG`: **24**
- `REVIEW_BLANK_TREATMENT`: **20**
- `PRIOR_LEAD_ALREADY_EXPLAINS`: **9**
- `REVIEW_TREATMENT_MISMATCH`: **1**
- ambiguous multiple compatible candidates: **0**

Full 54-row evidence is frozen in `docs/control/MKT_INTEGRITY_V3_LOOP4_BACKFILL_EVIDENCE_20260818.md`.

## Proposed calls — exact 24-row batch

| Call | Phone | Lead | Evidence |
|---:|---|---:|---|
| 14546 | 916513439 | 2799 | ENZIMAS↔ENZIMAS, unique late same-day |
| 14547 | 923257247 | 2802 | ENZIMAS↔ENZIMAS, unique late same-day |
| 14548 | 935029366 | 2798 | ENZIMAS↔ENZIMAS, unique late same-day |
| 14828 | 983410783 | 2819 | blank call treatment + exactly one near CALL_CENTER Agenda, CAPILAR-compatible |
| 15076 | 947317449 | 2847 | blank call treatment + exactly one near CALL_CENTER Agenda, ENZIMAS-compatible |
| 15468 | 999739700 | 2875 | blank call treatment + exactly one near CALL_CENTER Agenda, CAPILAR-compatible |
| 15800 | 928948639 | 2881 | HIFU↔HIFU, unique late same-day |
| 15801 | 987638905 | 2883 | CAPILAR↔CAPILAR, unique late same-day |
| 17043 | 941493755 | 2922 | CAPILAR↔CAPILAR, unique late same-day |
| 17818 | 945801377 | 3005 | CAPILAR↔CAPILAR, unique late same-day |
| 18130 | 924338503 | 3019 | ENZIMAS↔ENZIMAS, unique late same-day |
| 18131 | 924440067 | 3018 | ENZIMAS↔ENZIMAS, unique late same-day |
| 18132 | 974425602 | 3020 | CAPILAR↔CAPILAR, unique late same-day |
| 18133 | 977451681 | 3023 | HIFU↔HIFU, unique late same-day |
| 18134 | 981054793 | 3021 | CAPILAR↔CAPILAR, unique late same-day |
| 18135 | 994455417 | 3022 | CAPILAR↔CAPILAR, unique late same-day |
| 18304 | 915085545 | 3047 | ENZIMAS↔ENZIMAS, unique late same-day |
| 21692 | 920753965 | 3321 | ENZIMAS↔ENZIMAS, unique late same-day |
| 21693 | 958760138 | 3320 | CAPILAR↔CAPILAR, unique late same-day |
| 21722 | 932762393 | 3322 | HIDROFACIAL↔HIDROFACIAL, unique late same-day |
| 23096 | 963501507 | 3420 | HIFU↔HIFU, unique late same-day |
| 30320 | 998564399 | 4045 | CAPILAR↔CAPILAR, unique late same-day; no prior sale/attention/attended appointment before call |
| 33358 | 994885960 | 5001 | ENZIMAS↔ENZIMAS, unique late same-day; prior HIFU touchpoint is family-mismatched |
| 36025 | 968094272 | 5444 | blank call treatment + exactly one near CALL_CENTER Agenda, CAPILAR-compatible |

Expected call updates: **24**.

All 24 had `lead_id_origen IS NULL` at the BEFORE snapshot and had zero prior sales, zero prior clinical attentions, and zero prior attended/EFECTIVA appointments before the call business date.

`30320 / 998564399` is an eventual Acquisition customer, but was **not** a converted patient at the time of the 2026-07-06 call. Its first-sale semantics occur later; therefore it is not excluded as `EXISTING_PATIENT_CONTEXT`.

## Proposed Agenda links — exact 6-row batch

| Agenda id | Call | Lead | BEFORE |
|---|---:|---:|---|
| `1c3467c9-0536-4c71-86e1-561638e9401c` | 14828 | 2819 | lead NULL / call NULL |
| `f5b8243b-f21f-4a8c-804a-641b888c1e2e` | 15076 | 2847 | lead NULL / call NULL |
| `2830674b-66bc-4104-a920-62f2f313aaab` | 15468 | 2875 | lead NULL / call NULL |
| `33dc643c-78e8-4ef2-a235-7e174c98bbb5` | 30320 | 4045 | lead NULL / call NULL |
| `883962de-e15b-42b8-89da-6db8a6b12704` | 33358 | 5001 | lead NULL / call NULL |
| `df37e522-ce4b-4edc-aa79-0b7bf4e1517d` | 36025 | 5444 | lead NULL / call NULL |

Expected Agenda updates: **6**.

Each is the unique near Agenda for the selected call, same phone + same advisor, within ten minutes, treatment-family compatible. No `llamada_id_origen` is invented without an existing real call.

## BEFORE row hashes

Calls:

- 14546 `0269a5e935847e3abd9c0265fe550676`
- 14547 `6b73e55604f20db5fd36ea7862f4bae2`
- 14548 `8bbd457f7909809fa22a1e5c53405fdf`
- 14828 `e4ef32d4984964ef30e5ba1a8573784e`
- 15076 `5f1e62b400db1ad974a082322c43ac0a`
- 15468 `e81d65d66b333e09bde04d0cf6e21bc5`
- 15800 `e7e49fcf800b39ca4dbbe5045f3de6aa`
- 15801 `192fa42023e9888fda5b37e7494e0385`
- 17043 `cd031c2d41dd33b65da5400d31452d21`
- 17818 `6e910e2372ca46e885214c5f8b7df200`
- 18130 `0ab842a0c29a6ef9d6275aa6ba7258c3`
- 18131 `2fd4718f22a8dc69f08ef17e84f4f5f7`
- 18132 `3783203e021bf7e9ff3f43bc22f341ad`
- 18133 `91977dd2dd1f88e1133d2b90ff8bf620`
- 18134 `ffc627227a07c3f7b4c1888e176f576a`
- 18135 `39267ee3b944091fdf37d86d4bcefefe`
- 18304 `3c8fc0fc9355e3836777d0ca8f2594da`
- 21692 `557fa0035a75e8d0d1fdb07fb232736d`
- 21693 `42399222a114153aa52a38f03f2616fa`
- 21722 `449203b981d9239eb136d5671d7d72f7`
- 23096 `24524eeff0b8fdb877d075781b6fb28c`
- 30320 `8fd92ddf7df2f7a6e9a9d536d4cfa41c`
- 33358 `e43e38c295ea9a10a11956c5264af340`
- 36025 `db59fe76b2a5def0e63572139ec65a63`

Agendas:

- `1c3467c9-0536-4c71-86e1-561638e9401c` `db780bab9ad694d9f1da48fb9147de9e`
- `f5b8243b-f21f-4a8c-804a-641b888c1e2e` `c78ed8fc6ab4afefc5acad4060ff6d41`
- `2830674b-66bc-4104-a920-62f2f313aaab` `0b6116d2f943f9778143d42dbbb69f73`
- `33dc643c-78e8-4ef2-a235-7e174c98bbb5` `2bb555d9a6f1c2c6f7c07b38553e15e9`
- `883962de-e15b-42b8-89da-6db8a6b12704` `d6311ea150a6af408efe17077e0e5b5d`
- `df37e522-ce4b-4edc-aa79-0b7bf4e1517d` `e03bd3dd96d8f4d97f0defbf02293ee5`

## Mandatory downstream simulation

A PL/pgSQL exception subtransaction applied the exact 24 call + 6 Agenda overlays and then deliberately raised `LOOP4_SIMULATION_ROLLBACK`. PostgreSQL rolled the statement back. A subsequent probe confirmed:

- target calls with non-null lead after simulation: 0
- target Agenda with non-null lead after simulation: 0
- target Agenda with non-null call after simulation: 0

Simulation output before rollback:

- updated calls = 24
- updated Agenda = 6
- all 24 call matcher rows → `DIRECT_LEAD_ID`
- all 6 Agenda matcher rows → `DIRECT_LEAD_ID`
- Acquisition V2 = 54
- Acquisition V3 = 55
- V3-only = exactly `973438607 → lead 2135`
- duplicate acquisitions = 0
- post-sale lead attribution = 0
- Acquisition V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`
- `992829013`: V2=1 / V3=1
- `998564399`: V2=1 / V3=1
- `973438607`: V2=0 / V3=1
- `961780427`: V2=0 / V3=0
- `957549186`: V2=0 / V3=0

Attribution simulation:

- V2 BEFORE = 126 ops / S/45,158.70
- V2 AFTER overlay = 126 ops / S/45,158.70
- V3 BEFORE = 173 ops / S/66,644.10
- V3 AFTER overlay = 173 ops / S/66,644.10

Target-attribution footprint also remained identical:

- V2 target rows = none before and after.
- V3 target rows = only the four `998564399` sale rows, still lead 4045 / `ACQUISITION_HISTORICAL_UNIQUE_MATCH`, total S/1,567.

Therefore the backfill does not promote or otherwise change the open Loop-9 revenue delta.

## Control cases

- `14828`: proposed UPDATE → lead 2819 + unique Agenda link.
- `15076`: proposed UPDATE → lead 2847 + unique Agenda link.
- `15468`: proposed UPDATE → lead 2875 + unique Agenda link.
- `33358`: proposed UPDATE → lead 5001 + unique Agenda link.
- `30320`: proposed UPDATE → lead 4045 + unique Agenda link; not a prior patient at call time.
- `36025`: proposed UPDATE → lead 5444 + unique Agenda link.
- `35858`: NO ACTION; V3 resolves an existing prior CAPILAR lead 5353 (`TIMELINE_NEAREST_PRIOR_FAMILY`).
- `961780427`: NO ACTION; calls resolve to prior lead 4650, not late-lead semantics.
- `957549186`: NO ACTION; current live matcher returns `NO_MATCH / NO_MARKETING_TOUCHPOINT` for call 35976. No CAPILAR↔BIO inference is permitted.

## Rollback and apply package

Exact rollback is stored in:

`docs/control/MKT_INTEGRITY_V3_LOOP4_ROLLBACK_20260818.sql`

Versioned idempotent forward DML is stored in:

`supabase/backfills/20260818_mkt_integrity_v3_loop4_late_lead_backfill.sql`

The forward package updates only IDs of traceability on existing rows. It does not create calls, appointments, leads or sales and does not change business state/date/advisor/treatment.

## Pre-apply decision

All simulation gates pass. Persistent apply is authorized only after an immediate concurrency revalidation of exact `main`, all 24 calls, all 6 Agenda rows, candidate lead IDs, family compatibility and live V3 match state.
