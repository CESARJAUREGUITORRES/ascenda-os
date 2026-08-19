# MKT-INTEGRITY-HOTFIX-V3 — LOOP 3 Execution Report

**Loop:** PARITY ACQUISITION V2 ↔ V3  
**Business date:** 2026-08-18 Lima  
**Entry main:** `3f42a8cdce3f45b32b641874bdfe8f1155a7c05c`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Branch:** `audit/mkt-integrity-v3-loop3-acquisition-parity`  
**Loop 4:** NOT STARTED

## Result before final GitHub merge/readback

`PASS_PENDING_FINAL_MERGE_READBACK`

## G0 — Pre-flight

PASS.

- exact `main` matched the certified Loop-2 closeout SHA;
- CURRENT confirmed `MKT-INTEGRITY-HOTFIX-V3`;
- REV-F5 remained 7,064 / 15,498 and 3,950 clusters, with 0 members/preview/apply and no newer F5-owned writes;
- V2/V3 function definition hashes matched Loop 2;
- `37108`/`37110` remained absent;
- known unresolved late-call controls remained unlinked;
- productive frontend remained on `aos_marketing_leads_detalle`, not V3.

Normal production inserted 10 new leads and 1 Agenda row after the Loop-2 readback, before Loop-3 parity began. Calls and sales counts did not move. This operational activity did not alter Acquisition parity and is not a Loop-3 mutation.

## G1 — Acquisition set parity

PASS.

- V2 = 54
- V3 = 55
- intersection = 54
- V2-only = 0
- V3-only = exactly 1 (`973438607`)
- V3 distinct phones = 55
- duplicate acquisitions = 0

## G2 — 54 shared persons

PASS.

Every required business field was compared for all 54 shared persons.

Difference counts:

- lead id: 0
- lead date: 0
- treatment: 0
- ad: 0
- first sale date: 0
- attribution method: 0
- confidence: 0

All 54 shared rows are `MISMO LEAD`.

## G3 — Additional V3 acquisition

PASS.

Only:

`973438607 → lead 2135 → 2026-03-11 → first sale 2026-03-12 → NEAREST_PRIOR_FIRST_SALE`.

No prior sale, clinical attention, attended appointment or prior acquisition exists before the selected lead. This is certified as Acquisition, not Reactivation or Historical Follow-up.

## G4 — Cohort parity

PASS.

V2 by lead cohort month:

- Jan 9
- Feb 5
- Mar 9
- Apr 3
- May 8
- Jun 8
- Jul 8
- Aug 4

V3:

- Jan 9
- Feb 5
- Mar 10
- Apr 3
- May 8
- Jun 8
- Jul 8
- Aug 4

Only delta: March +1.

## G5 — Temporal safety

PASS.

`lead_fecha > first_sale_date = 0`.

Five rows share the same calendar date for lead and first sale. In all five, the recorded `lead_ts` precedes every technical sale `created_at`; historical technical timestamps are not treated as canonical business timestamps, so the authoritative gate remains the allowed date-granularity rule. No date inversion exists.

## G6 — Nearest-prior safety

PASS.

Exactly one V3 row uses `NEAREST_PRIOR_FIRST_SALE`, and it is the expected `973438607 → lead 2135` case. No unexpected nearest-prior row exists.

## G7 — Control cases

PASS.

- `992829013`: remains exactly one acquisition in V2 and V3; 2 first-sale-day ops / S/1,018, 5 total sales / S/2,467.
- `998564399`: remains exactly one acquisition in V2 and V3; 4 first-sale-day ops / S/1,567, 4 total sales / S/1,567.
- `961780427`: 0 acquisitions in both V2 and V3.
- `957549186`: 0 acquisitions in both V2 and V3.
- `37108`/`37110`: not restored.

## G8 — First-sale-day evidence

PASS as read-only evidence.

Across all 55 V3 acquisitions:

- persons = 55
- first-sale-day operations = 133
- first-sale-day revenue = S/50,856.10

This evidence is not a revenue cutover decision.

## G9 — Attribution barrier

PASS as isolation gate.

Attribution remains:

- V2 = 126 ops / S/45,158.70
- V3 = 173 ops / S/66,644.10
- delta = +47 ops / +S/21,485.40

The delta remains `OPEN FOR LOOP 9 / REVENUE ATTRIBUTION`. Loop 3 does not promote it.

## G10 — Determinism

PASS.

Independent ordered V3 reads produced the same hash:

`3223caf0ec5d1b264c4494775c6f7d58`

## G11 — No-write / no-cutover

PASS.

Loop 3 used only Supabase SELECT statements. No migration, DDL, DML, backfill, restoration, frontend change or V2/V3 function change was performed.

## Pre-merge conclusion

Functional Loop-3 scope is complete and passes every specified parity gate.

Final PASS requires:

1. exact-head revalidation;
2. docs-only branch diff verification;
3. PR merge using expected head SHA;
4. post-merge Supabase/GitHub/REV-F5 readback;
5. CURRENT finalization;
6. Notion synchronization.

Do not start Loop 4.
