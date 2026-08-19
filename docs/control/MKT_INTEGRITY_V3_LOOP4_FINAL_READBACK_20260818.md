# MKT-INTEGRITY-HOTFIX-V3 — LOOP 4 Final Readback

**Loop:** Deterministic late-lead backfill  
**Functional/control PR:** #292  
**Merged main:** `8151b82cb2a3f339db80af86aa16e49e63f067af`  
**Business date:** 2026-08-18 Lima  
**Loop 5:** NOT STARTED

## Final production readback

Post-merge Supabase readback at **2026-08-18 21:45:44 Lima**:

- exact call mappings: **24/24**;
- bad call mappings: **0**;
- exact Agenda mappings: **6/6**;
- bad Agenda mappings: **0**;
- target call matcher: **24 × `DIRECT_LEAD_ID`**;
- target Agenda matcher: **6 × `DIRECT_LEAD_ID`**;
- NO-ACTION candidates still NULL: **30/30**;
- NO-ACTION candidates changed: **0**.

## Acquisition invariants

- V2 = **54**;
- V3 = **55**;
- V3-only = exactly `973438607 → lead 2135`;
- duplicate acquisitions = **0**;
- post-sale lead attribution = **0**;
- deterministic V3 acquisition hash = `3223caf0ec5d1b264c4494775c6f7d58`.

## Attribution barrier

Unchanged:

- V2 = **126 ops / S/45,158.70**;
- V3 = **173 ops / S/66,644.10**.

No Loop-9 revenue cutover occurred.

## Control calls

- `14828 → lead 2819`
- `15076 → lead 2847`
- `15468 → lead 2875`
- `30320 → lead 4045`
- `33358 → lead 5001`
- `36025 → lead 5444`
- `35858` remains NULL; V3 resolves prior lead 5353.
- `961780427`: latest call remains direct-link NULL; V3 resolves prior lead 4650 via `TIMELINE_NEAREST_PRIOR_FAMILY`.
- `957549186`: call 35976 remains NULL / `NO_MATCH / NO_MARKETING_TOUCHPOINT`.
- `992829013`: Acquisition V2=1 / V3=1.
- `998564399`: Acquisition V2=1 / V3=1.

## Mireya safety

- call `37108`: absent;
- call `37110`: absent.

Loop 5 restoration was not executed.

## REV-F5 final gate

Unchanged:

- batches 6;
- expected rows 15,498;
- source rows 7,064;
- clusters 3,950;
- members 0;
- preview 0;
- apply 0.

F5 high-water timestamps remained unchanged from the Marketing freeze checkpoint.

## Function integrity

Definition hashes remained:

- Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`
- Acquisition V3 `07762236ceb159ec29c34cc2eb1c5b3a`
- Agenda matcher V3 `49c13d3f034b059871b2dc7aa0c7c981`
- Call matcher V3 `8d9ff10aaee45542e6bb527142cea178`
- Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`
- Attribution V3 `ef613afdbf9175c27ebc34bb0763961e`

## Idempotency

The second exact dry-run returned:

- calls affected: **0**;
- Agenda affected: **0**.

## Business-data footprint

Core row counts remained:

- calls 35,309;
- Agenda 3,126;
- leads 5,679;
- sales 1,299.

Loop 4 only changed approved trace-link columns on existing rows.

## GitHub blast radius

PR #292 contained only:

- `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_BACKFILL_EVIDENCE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_ROLLBACK_20260818.sql`
- `supabase/backfills/20260818_mkt_integrity_v3_loop4_late_lead_backfill.sql`

No `app/**`, migration, function definition or other workstream file was changed.

## Final result

**LOOP 4 = PASS.**

Next sequential loop, only when explicitly invoked:

`LOOP 5 — REPARACIÓN MIREYA Y LLAMADAS INBOUND/MANUALES`

**LOOP 5 = NOT STARTED.**
