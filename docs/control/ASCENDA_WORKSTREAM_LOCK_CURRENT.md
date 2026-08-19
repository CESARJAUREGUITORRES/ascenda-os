# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Loop-4 entry main:** `e6649515afa2e7aa3854d91a6594624cb084e0e2`  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS**.
- LOOP 2 — Marketing V3 Shadow: **PASS**.
- LOOP 3 — Acquisition V2↔V3 parity: **PASS**.
- LOOP 4 — Deterministic late-lead backfill: **PASS_PENDING_FINAL_MERGE_READBACK**.
- LOOP 5 — Mireya repair / inbound-manual semantics: **NOT STARTED**.

Loops execute sequentially. Do not begin Loop 5 automatically.

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

Counts + high-water/write timestamps remain the operational drift gate.

## Marketing V3 baseline preserved

Acquisition:

- V2 = 54
- V3 = 55
- V3-only = exactly `973438607 → lead 2135`
- deterministic V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`

Attribution remains shadow-only:

- V2 = 126 ops / S/45,158.70
- V3 = 173 ops / S/66,644.10
- delta = +47 ops / +S/21,485.40

This Attribution delta is **not approved for production cutover** and remains a Loop-9 subject.

## Loop 4 — Deterministic late-lead backfill

Canonical artifacts:

- `docs/control/MKT_INTEGRITY_V3_LOOP4_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_BACKFILL_EVIDENCE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP4_ROLLBACK_20260818.sql`
- `supabase/backfills/20260818_mkt_integrity_v3_loop4_late_lead_backfill.sql`

Live universe was re-derived from Supabase and did not use the old 19/17/2 shorthand:

- total candidates: **54**;
- AUTO_BACKFILL_STRONG: **24**;
- REVIEW_BLANK_TREATMENT: **20**;
- PRIOR_LEAD_ALREADY_EXPLAINS: **9**;
- REVIEW_TREATMENT_MISMATCH: **1**;
- multiple-candidate reviews: **0**.

Productive backfill applied exactly:

- **24** `aos_llamadas.lead_id_origen` links;
- **6** Agenda `lead_id_origen + llamada_id_origen` links.

Target calls:

`14546,14547,14548,14828,15076,15468,15800,15801,17043,17818,18130,18131,18132,18133,18134,18135,18304,21692,21693,21722,23096,30320,33358,36025`.

Agenda-linked calls:

`14828,15076,15468,30320,33358,36025`.

Post-apply readback:

- exact calls = 24/24;
- exact Agenda = 6/6;
- call matcher = 24 × `DIRECT_LEAD_ID`;
- Agenda matcher = 6 × `DIRECT_LEAD_ID`;
- all 30 NO-ACTION candidates remained NULL;
- Acquisition V2/V3 = 54/55;
- V3-only unchanged;
- duplicates = 0;
- post-sale = 0;
- V3 hash unchanged;
- Attribution V2/V3 unchanged;
- `37108` / `37110` still absent;
- second dry-run = 0 call updates / 0 Agenda updates;
- REV-F5 unchanged;
- V2/V3 function definitions unchanged.

Known controls:

- 14828 → lead 2819
- 15076 → lead 2847
- 15468 → lead 2875
- 30320 → lead 4045
- 33358 → lead 5001
- 36025 → lead 5444
- 35858 remains NULL; prior lead 5353 already explains it
- `961780427` remains prior-lead territory (lead 4650)
- `957549186` remains unresolved / no automatic Marketing match

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `MKT-INTEGRITY-HOTFIX-V3` owns the lock, REV-F5 and all other HIGH/CRITICAL workstreams remain read/audit/documentation or regression-only.

## Next sequential loop

`LOOP 5 — REPARACIÓN MIREYA Y LLAMADAS INBOUND/MANUALES`

Loop 5 is **NOT STARTED** and requires explicit invocation after Loop-4 final merge/readback.

## Exit / handback

The global lock returns to `REV-F5-CLOSEOUT` only after MKT-INTEGRITY-HOTFIX-V3 reaches full production certification at Loop 13 and REV-F5 is revalidated against its recoverable checkpoint.
