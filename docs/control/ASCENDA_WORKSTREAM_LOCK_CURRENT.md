# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Loop-2 functional merge:** `63e7cefe4c0845aa87f0da59419aea0cee5afe0b` / PR #288  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS** (PR #287 / `d2113e6e5be91210e111a33813f6d8167b1eb54e`).
- LOOP 2 — Marketing V3 Shadow: **PASS** (functional PR #288 / `63e7cefe4c0845aa87f0da59419aea0cee5afe0b`; final post-merge readback certified).
- LOOP 3 — Acquisition V2↔V3 parity: **NOT STARTED**.

Loops execute sequentially. Do not begin Loop 3 until explicitly invoked.

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

Loop 2 verified unchanged F5 counts and write timestamps older than the Loop-1 freeze. The exact Loop-1 hash serialization SQL was not persisted, so differently serialized ad-hoc hashes are not treated as drift. The original hashes above remain the canonical handback references.

## Loop 2 canonical artifacts

- `docs/control/MKT_INTEGRITY_V3_LOOP2_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_SHADOW_BASELINE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_FINAL_READBACK_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_ROLLBACK_20260818.sql`
- `supabase/migrations/20260819015100_mkt_integrity_v3_shadow_loop2.sql`
- live migration `20260819015951_mkt_integrity_v3_shadow_loop2_20260818`.

## V3 shadow objects

Loop 2 created only read-path/service-role shadow functions:

1. `aos_marketing_treatment_family_v3(text)`
2. `aos_marketing_call_lead_match_v3_preview(date,date)`
3. `aos_marketing_agenda_lead_match_v3_preview(date,date)`
4. `aos_marketing_acquisition_customers_v3_preview()`
5. `aos_marketing_attribution_v3_preview(date,date)`
6. `aos_marketing_touchpoint_rollup_v3_preview(date,date)`
7. `aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer)`
8. `aos_marketing_leads_detalle_v3_summary(date,date,text,text)`

All exact Loop-2 objects are restricted to `postgres` + `service_role`; no productive frontend was redirected.

## Certified shadow baseline

Acquisition:

- V2 = **54** customers.
- V3 shadow = **55** customers.
- V3-only = exactly `973438607 → lead 2135`, method `NEAREST_PRIOR_FIRST_SALE`, confidence 55.
- V2-only = 0.

Attribution 2026-01-01..2026-08-18:

- V2 = **126 ops / S/45,158.70**.
- V3 shadow = **173 ops / S/66,644.10**.
- delta = **+47 ops / +S/21,485.40**.

This Attribution delta is **not approved for production cutover**. It remains a parity/revenue subject for later loops.

Reference cases:

- `961780427`, call 32014 → prior CAPILAR lead `4650`, confidence 80.
- `957549186`, call 35976 → no automatic lead; REVIEW/unresolved.
- `992829013` → V3 exposes 2 first-sale-day ops / S1,018; remaining later sales require revenue semantics.
- `998564399` → V3 exposes 4 ops / S1,567 without duplicate acquisition.
- Mireya calls `37108` / `37110` remain deleted; restoration remains Loop 5.

## Loop 2 safety certification

Loop 2 performed:

- **0** INSERT/UPDATE/DELETE on `aos_llamadas`, `aos_agenda_citas`, `aos_leads`, `aos_ventas`;
- **0** backfills;
- **0** Mireya restorations;
- **0** V2 function-definition changes;
- **0** frontend/Home/Monitoreo/Call Center changes;
- **0** REV-F5 mutations.

Business-table counts were identical immediately before DDL and at final readback: calls 35,296 / agenda 3,125 / leads 5,669 / sales 1,299.

Rollback was compiled and executed transactionally before persistent application (`ROLLBACK_OK`); the permanent reverse-order schema-only rollback is stored in the Loop-2 rollback artifact.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `MKT-INTEGRITY-HOTFIX-V3` owns the lock, REV-F5 and all other HIGH/CRITICAL workstreams are read/audit/documentation or regression-only.

## Next sequential loop

`LOOP 3 — PARITY ACQUISITION V2 ↔ V3`

Loop 3 has **not** started and requires explicit invocation.

## Exit / handback

The global lock returns to `REV-F5-CLOSEOUT` only after MKT-INTEGRITY-HOTFIX-V3 reaches full production certification at Loop 13 and REV-F5 is revalidated against its recoverable checkpoint.
