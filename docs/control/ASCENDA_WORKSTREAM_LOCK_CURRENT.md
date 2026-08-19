# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Loop-2 entry main:** `d2113e6e5be91210e111a33813f6d8167b1eb54e`  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS** (PR #287 / main `d2113e6e5be91210e111a33813f6d8167b1eb54e`).
- LOOP 2 — Marketing V3 Shadow: **PASS_PENDING_FINAL_MERGE_READBACK** on branch `feat/mkt-integrity-v3-loop2-shadow`.
- LOOP 3 — Acquisition V2↔V3 parity: **NOT STARTED**.

The user authorized the 13-loop roadmap, but loops must execute sequentially and each loop must stop after certification. Do not infer permission to skip gates or begin the next loop automatically.

## REV-F5 recoverable pause

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Frozen F5-owned state:

- live batch table: `aos_f5_source_batches_v1`;
- source batches: **6**;
- expected source rows: **15,498**;
- persisted source rows: **7,064**;
- remaining: **8,434**;
- identity clusters: **3,950**;
- cluster members: **0**;
- link preview: **0**;
- canonical apply events: **0**.

Loop-1 canonical recovery hashes:

- batches: `807f03e96e5786203d867938c3938154`
- source rows: `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters: `2d39d9ac990fee61a7ecb6ffa52efb64`

Loop 2 verified that the maximum F5 write timestamps predate the Loop-1 freeze and all F5 counts remain unchanged. A separately recomputed ad-hoc JSON hash differed because the exact Loop-1 hash serialization SQL was not persisted; treat this as hash-method mismatch, not F5 data drift. Original hashes above remain the canonical handback references.

## Loop 2 — Marketing V3 Shadow

Canonical artifacts:

- `docs/control/MKT_INTEGRITY_V3_LOOP2_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_SHADOW_BASELINE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP2_ROLLBACK_20260818.sql`
- migration source `supabase/migrations/20260819015100_mkt_integrity_v3_shadow_loop2.sql`
- live migration `20260819015951_mkt_integrity_v3_shadow_loop2_20260818`.

Loop 2 created only V3 shadow/read-path objects:

1. `aos_marketing_treatment_family_v3(text)`
2. `aos_marketing_call_lead_match_v3_preview(date,date)`
3. `aos_marketing_agenda_lead_match_v3_preview(date,date)`
4. `aos_marketing_acquisition_customers_v3_preview()`
5. `aos_marketing_attribution_v3_preview(date,date)`
6. `aos_marketing_touchpoint_rollup_v3_preview(date,date)`
7. `aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer)`
8. `aos_marketing_leads_detalle_v3_summary(date,date,text,text)`

Exact Loop-2 objects are restricted to postgres/service_role. No production frontend was redirected to them.

## Loop 2 shadow baseline

Acquisition:

- V2 = **54** customers.
- V3 shadow = **55** customers.
- V3-only = exactly `973438607 → lead 2135`, method `NEAREST_PRIOR_FIRST_SALE`.
- V2-only = 0.

Attribution 2026-01-01..2026-08-18:

- V2 = **126 ops / S/45,158.70**.
- V3 shadow = **173 ops / S/66,644.10**.
- Delta = **+47 ops / +S/21,485.40**.

This operation-level delta is **not approved for cutover**. It is an explicit Loop-3/Loop-9 parity subject. V3 remains shadow.

Reference cases:

- `961780427`, call 32014 → prior CAPILAR lead `4650`, confidence 80.
- `957549186`, call 35976 → no automatic lead; remains REVIEW/unresolved.
- `992829013` → V3 exposes 2 first-sale-day operations / S1,018; later sales remain outside shadow acquisition attribution.
- `998564399` → V3 exposes 4 operations / S1,567 without creating a duplicate acquisition customer.
- Mireya calls `37108` / `37110` remain deleted; restoration is still Loop 5.

## Safety status

Loop 2 did **not**:

- update/insert/delete `aos_llamadas`, `aos_agenda_citas`, `aos_leads` or `aos_ventas`;
- perform late-lead backfills;
- restore Mireya calls;
- modify any certified V2 function definition;
- modify frontend, Home, Monitoreo or Call Center;
- modify REV-F5.

The shadow migration was first compiled inside a transaction and rolled back successfully. A reverse-order schema-only rollback artifact is stored in `docs/control/MKT_INTEGRITY_V3_LOOP2_ROLLBACK_20260818.sql`.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `MKT-INTEGRITY-HOTFIX-V3` owns the lock:

- REV-F5 is read/audit/documentation only;
- CIA, Sentinel, WhatsApp and other mutable HIGH/CRITICAL workstreams remain paused/regression-only;
- open stale/draft PRs do not acquire ownership by existing;
- every future `main` advance requires exact-head revalidation before another mutable loop.

## Next authorized step after Loop-2 final merge/readback

If and only if Loop 2 receives final PASS after merge + Supabase/GitHub/Notion readback, the next loop is:

`LOOP 3 — PARITY ACQUISITION V2 ↔ V3`

Do not start it automatically.

## Exit / handback

The global lock returns to `REV-F5-CLOSEOUT` only after MKT-INTEGRITY-HOTFIX-V3 reaches full production certification at Loop 13 and REV-F5 is revalidated against its recoverable checkpoint.
