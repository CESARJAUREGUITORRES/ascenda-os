# MKT-INTEGRITY-HOTFIX-V3 — LOOP 3 Final Readback

**Loop:** Acquisition V2 ↔ V3 parity  
**Functional/control PR:** #290  
**Merged main:** `483c720cdb3b7e70dca8effeb80c16963e1da069`  
**Business date:** 2026-08-18 Lima  
**Loop 4:** NOT STARTED

## Post-merge certification

Supabase final readback at 2026-08-18 21:23:11 Lima:

- Acquisition V2: **54**.
- Acquisition V3: **55**.
- shared: **54**.
- V2-only: **0**.
- V3-only: **1**, exactly `973438607 → lead 2135`.
- duplicate acquisitions: **0**.
- post-sale-date lead attribution: **0**.
- nearest-prior cases: **1**, exactly the expected `973438607` case.
- deterministic ordered V3 hash: `3223caf0ec5d1b264c4494775c6f7d58`.

## Cohort readback

V3 by selected Marketing lead month:

- Jan 9
- Feb 5
- Mar 10
- Apr 3
- May 8
- Jun 8
- Jul 8
- Aug 4

Against V2, only March differs: **9 → 10**.

## Function integrity

Post-merge definition hashes remain unchanged:

- Acquisition V2 `7851ca8c9163625bda8fcf987a1def87`
- Acquisition V3 `07762236ceb159ec29c34cc2eb1c5b3a`
- Attribution V2 `630c46e0425e6941283f1b200d3a5ce2`
- Attribution V3 `ef613afdbf9175c27ebc34bb0763961e`

## Attribution barrier

Still shadow-only and unchanged:

- V2 = 126 ops / S/45,158.70
- V3 = 173 ops / S/66,644.10

No cutover was performed.

## REV-F5 final gate

Still:

- batches 6;
- expected 15,498;
- source rows 7,064;
- clusters 3,950;
- members 0;
- preview 0;
- apply 0.

Maximum F5-owned write timestamps remain older than the Marketing freeze. Loop 3 caused no REV-F5 mutation.

## Late-lead / Mireya safety

- calls `37108` and `37110`: still absent.
- known unresolved late-call controls `14828,15076,15468,30320,33358,35858,36025`: still `lead_id_origen IS NULL`.
- no late-lead backfill occurred.

## Business-data safety

Loop 3 executed no Supabase DML or DDL. Final operational counts were:

- calls 35,296
- agenda 3,126
- leads 5,679
- sales 1,299

The 10-lead / 1-agenda increase relative to the prior Loop-2 readback occurred before Loop-3 parity and is normal production activity. Loop 3 itself only issued SELECTs.

## Frontend gate

PR #290 changed only `docs/control/**`; no `app/**` or migration file was changed. Productive Marketing remains on its existing non-V3 RPC path.

## Final result

`LOOP 3 = PASS`

Next sequential loop, only when explicitly invoked:

`LOOP 4 — BACKFILL LATE-LEAD DETERMINÍSTICO`

**LOOP 4 = NOT STARTED.**
