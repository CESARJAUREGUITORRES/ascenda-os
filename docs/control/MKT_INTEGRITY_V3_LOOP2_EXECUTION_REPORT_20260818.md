# MKT-INTEGRITY-HOTFIX-V3 — LOOP 2 Execution Report

**Scope:** Marketing V3 Shadow only  
**Business date:** 2026-08-18 Lima  
**Entry main:** `d2113e6e5be91210e111a33813f6d8167b1eb54e`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Loop 3:** NOT STARTED

## Result before GitHub merge/read-back

`PASS_PENDING_GITHUB_MERGE_AND_FINAL_READBACK`

## G1 — Exact-head / lock / REV-F5

PASS.

- main remained `d2113e6e5be91210e111a33813f6d8167b1eb54e` through pre-flight and branch creation.
- CURRENT lock confirmed `MKT-INTEGRITY-HOTFIX-V3` as the sole mutable HIGH/CRITICAL owner.
- REV-F5 counts remain 6 batches / 15,498 expected / 7,064 source rows / 3,950 clusters / 0 members / 0 preview / 0 apply.
- F5 max write timestamps precede the Loop 1 freeze; no F5 write occurred during Loop 2.
- A pre-flight hash recalculation used a different JSON serialization from Loop 1 and therefore produced different ad-hoc MD5s. Since Loop 1 did not persist its hash SQL formula, this is recorded as **hash-method mismatch, not data drift**. Frozen counts plus write timestamps establish no F5 mutation; original Loop 1 hashes remain canonical handback references.

## G2 — Impact Report before DDL

PASS.

`docs/control/MKT_INTEGRITY_V3_LOOP2_IMPACT_REPORT_20260818.md` was committed on the Loop-2 branch before any persistent DDL was applied.

## G3 — Transactional compile/rollback

PASS.

A complete create-function transaction was executed and ended with `ROLLBACK_OK` before the real migration. An initial read/compile attempt failed on an ambiguous `fecha_cita` reference; because it was inside the transaction, no object persisted. The qualified column was corrected before the successful rollback test.

## G4 — Shadow migration

PASS.

Applied Supabase migration:

- version: `20260819015951`
- name: `mkt_integrity_v3_shadow_loop2_20260818`

Repository source:

- `supabase/migrations/20260819015100_mkt_integrity_v3_shadow_loop2.sql`

The migration contains CREATE/REPLACE FUNCTION, ACL and COMMENT statements only. It contains no INSERT/UPDATE/DELETE against business tables.

## G5 — V3 objects

Created eight exact Loop-2 shadow objects:

1. `aos_marketing_treatment_family_v3(text)`
2. `aos_marketing_call_lead_match_v3_preview(date,date)`
3. `aos_marketing_agenda_lead_match_v3_preview(date,date)`
4. `aos_marketing_acquisition_customers_v3_preview()`
5. `aos_marketing_attribution_v3_preview(date,date)`
6. `aos_marketing_touchpoint_rollup_v3_preview(date,date)`
7. `aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer)`
8. `aos_marketing_leads_detalle_v3_summary(date,date,text,text)`

All exact objects are executable only by postgres/service_role in Loop 2. No anon/authenticated/public grant exists.

Definition hashes are frozen in `MKT_INTEGRITY_V3_LOOP2_SHADOW_BASELINE_20260818.md`.

## G6 — V2 intact

PASS.

Every certified V2 function-definition hash remained byte-for-byte identical after the V3 migration. Operational V2 remained Acquisition 54 and Attribution 126 operations / S/45,158.70 during the shadow comparison.

## G7 — 0 business-data writes / 0 backfills / 0 Mireya restoration

PASS.

Core business row counts immediately before persistent DDL:

- `aos_llamadas`: 35,296
- `aos_agenda_citas`: 3,125
- `aos_leads`: 5,669
- `aos_ventas`: 1,299

Post-migration/pre-merge counts remain exactly the same:

- `aos_llamadas`: 35,296
- `aos_agenda_citas`: 3,125
- `aos_leads`: 5,669
- `aos_ventas`: 1,299

Calls `37108` and `37110` remain absent (`count=0`). No late-lead backfill was performed.

## G8 — Frontend remains production path

PASS.

No frontend file was changed on the Loop-2 branch. The existing Marketing modal still calls its current productive RPC `aos_marketing_leads_detalle`; no V3 shadow RPC is referenced or granted to anon/authenticated. V3 cannot be an accidental browser cutover in Loop 2.

## G9 — Shadow Acquisition result

PASS for Loop-2 objective; parity decision deferred to Loop 3.

- V2 = 54 customers.
- V3 = 55 customers.
- V2-only = 0.
- V3-only = exactly `973438607 → lead 2135`, `NEAREST_PRIOR_FIRST_SALE`, confidence 55.

This is the single approved delta expected for Loop 3.

## G10 — Shadow Attribution result

PASS as an inspectable shadow delta; NOT approved for production cutover.

2026-01-01..2026-08-18:

- V2 = 126 operations / S/45,158.70.
- V3 = 173 operations / S/66,644.10.
- Delta = +47 operations / +S/21,485.40.

V3-only:

- 45 ops / 18 persons / S/20,897.40 via `ACQUISITION_HISTORICAL_UNIQUE_MATCH`;
- 2 ops / 1 person / S/588 via `ACQUISITION_NEAREST_PRIOR_FIRST_SALE`.

This expansion is caused by V3 including all operations on a recognized first-sale date. It requires semantic review in later parity/revenue loops and is one reason V3 remains service-role shadow only.

## G11 — Reference cases

PASS.

- `973438607` → lead 2135, acquisition shadow candidate.
- `961780427`, call 32014 → lead 4650 CAPILAR, confidence 80.
- `957549186`, call 35976 → no automatic lead, confidence 0; remains REVIEW/unresolved.
- `992829013`: V3 exposes 2 acquisition-day ops / S1,018; actual 5 / S2,467, so later revenue semantics still required.
- `998564399`: V3 exposes all 4 recorded ops / S1,567 without creating another acquisition customer.
- `37108`/`37110`: not restored.

## G12 — Server-side pagination and dimensional filters

PASS.

- annual V3 effective universe = 5,628 touchpoints / 5,338 unique persons;
- offset 0 and offset 1,000 both return valid 100-row pages with `total_rows=5,628`;
- `CON CITA` is non-exclusive and contains sold touchpoints;
- `VENDIDO` is independently filterable;
- phone `998719392` is split into separate touchpoints instead of copying the same phone-level metrics to every lead.

## G13 — Determinism

PASS.

Two independent Acquisition V3 reads produced identical MD5:

`71fd02f5cf3b913675269f4c71f9f09d`

Two independent annual summary reads also produced identical JSON.

## G14 — Rollback

PASS / CERTIFIED REVERSIBLE.

A create→read→ROLLBACK test passed before persistent application. The permanent rollback artifact is:

`docs/control/MKT_INTEGRITY_V3_LOOP2_ROLLBACK_20260818.sql`

It drops only the eight Loop-2 objects in reverse dependency order and never touches V2 or business tables.

## G15 — Risks carried into Loop 3

1. Attribution V3 adds +47 operations / +S21,485.40; do not promote automatically.
2. Annual V3 cita count (480 touchpoints / 478 persons) is much lower than V2's 746 touchpoint rows because V3 resolves appointments to one touchpoint instead of copying phone-window appointments. This requires parity explanation by cohort/person.
3. August V3 sold/amount is 4 acquisitions / S2,352 vs V2 modal 5 / S2,402. V3 matches current M0 acquisition/LTV amount; the extra V2 S50 must be classified rather than silently dropped or adopted.
4. `957549186` remains unresolved.
5. F5 original MD5 formula is not reproducible from docs; future handback should use frozen counts/write timestamps plus original hashes unless the canonical hash SQL is recovered.

## Certification before merge

Loop 2 has achieved its functional scope:

- Marketing V3 shadow functional;
- V2 intact;
- no business-data writes;
- no backfills;
- no Mireya restoration;
- no frontend cutover;
- reversible rollback available;
- REV-F5 untouched.

Final PASS requires the expected branch diff, atomic PR merge, final `main` exact-head/read-back, CURRENT and Notion reconciliation. Loop 3 must not start automatically.
