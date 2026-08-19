# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Loop-3 merge:** `483c720cdb3b7e70dca8effeb80c16963e1da069` / PR #290  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS**.
- LOOP 2 — Marketing V3 Shadow: **PASS**.
- LOOP 3 — Acquisition V2↔V3 parity: **PASS**.
- LOOP 4 — Deterministic late-lead backfill: **NOT STARTED**.

Loops execute sequentially. Do not begin Loop 4 automatically.

## REV-F5 recoverable pause

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Current certified frozen state:

- `aos_f5_source_batches_v1`: **6 batches / 15,498 expected rows**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- remaining: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950**;
- members: **0**;
- preview: **0**;
- apply events: **0**.

Loop-1 canonical recovery hashes:

- batches: `807f03e96e5786203d867938c3938154`
- source rows: `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters: `2d39d9ac990fee61a7ecb6ffa52efb64`

The exact Loop-1 hash serialization SQL was not persisted. Counts + high-water/write timestamps are the drift gate; the original hashes remain canonical references.

## Loop 2 shadow baseline preserved

Acquisition:

- V2 = 54
- V3 shadow = 55
- V3-only expected = `973438607 → lead 2135`

Attribution remains shadow-only:

- V2 = 126 ops / S/45,158.70
- V3 = 173 ops / S/66,644.10
- delta = +47 ops / +S/21,485.40

This Attribution delta is **not approved for production cutover**.

## Loop 3 — Acquisition parity certification

Canonical artifacts:

- `docs/control/MKT_INTEGRITY_V3_LOOP3_ACQUISITION_PARITY_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP3_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP3_FINAL_READBACK_20260818.md`

Final parity result:

- V2 = **54**;
- V3 = **55**;
- shared V2∩V3 = **54**;
- V2-only = **0**;
- V3-only = exactly **1**, `973438607 → lead 2135`;
- duplicate acquisitions = **0**;
- post-sale-date lead attribution = **0**;
- nearest-prior cases = exactly **1**, the expected `973438607` case;
- all 54 shared rows have identical lead_id, lead date, treatment, ad, first-sale date, method and confidence;
- V3 deterministic ordered hash = `3223caf0ec5d1b264c4494775c6f7d58`.

Cohort parity by selected Marketing lead month:

- JAN 9→9
- FEB 5→5
- MAR 9→10
- APR 3→3
- MAY 8→8
- JUN 8→8
- JUL 8→8
- AUG 4→4

Only delta = **March +1**, exactly `973438607`.

## Additional acquisition `973438607`

Chronology:

1. lead 1150 — 2026-02-05 — HIFU;
2. lead 2135 — 2026-03-11 — HIFU;
3. first sale — 2026-03-12 — 2 ops / S/588.

Before lead 2135 there are:

- 0 prior sales;
- 0 prior clinical attentions;
- 0 attended/EFECTIVA appointments;
- 0 prior Acquisition V2 rows.

It is certified as a true acquisition, not reactivation/follow-up.

## Control cases

- `992829013`: remains exactly one acquisition in V2/V3; 2 first-sale-day ops / S/1,018, 5 total sales / S/2,467.
- `998564399`: remains exactly one acquisition in V2/V3; 4 first-sale-day ops / S/1,567.
- `961780427`: 0 acquisitions in both V2 and V3.
- `957549186`: 0 acquisitions in both V2 and V3; no automatic acquisition inference.
- Mireya calls `37108` / `37110`: still not restored; restoration remains Loop 5.

## Loop 3 safety certification

Loop 3 used read-only Supabase SELECT statements only and performed:

- **0** business-table DML;
- **0** Supabase DDL/migrations;
- **0** late-lead backfills;
- **0** Mireya restorations;
- **0** V2 function changes;
- **0** V3 function changes;
- **0** frontend/Home/Monitoreo/Call Center changes;
- **0** REV-F5 mutations.

Productive Marketing frontend remains on its current non-V3 RPC path.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `MKT-INTEGRITY-HOTFIX-V3` owns the lock, REV-F5 and all other HIGH/CRITICAL workstreams remain read/audit/documentation or regression-only.

## Next sequential loop

`LOOP 4 — BACKFILL LATE-LEAD DETERMINÍSTICO`

Loop 4 has **NOT STARTED** and requires explicit invocation.

## Exit / handback

The global lock returns to `REV-F5-CLOSEOUT` only after MKT-INTEGRITY-HOTFIX-V3 reaches full production certification at Loop 13 and REV-F5 is revalidated against its recoverable checkpoint.
