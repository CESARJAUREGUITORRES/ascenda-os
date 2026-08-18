# REV-F5 — TEMPORARY PAUSE CHECKPOINT FOR CALLS / AGENDA / MARKETING HOTFIX

**Status:** RECOVERABLE PAUSE / owner-authorized  
**Date:** 2026-08-18 America/Lima  
**Source main before pause:** `a9e77cdf81cb32d9d2a7b23fbf610820c298b814`  
**Reason:** owner explicitly ordered a temporary pause of `REV-F5-CLOSEOUT` to execute and certify the Calls–Agenda–Marketing hotfix, then immediately restore the REV-F5 lock.

## Live REV-F5 checkpoint captured immediately before pause

Production Supabase project `ituyqwstonmhnfshnaqz`:

- source manifests: **6**;
- expected source rows: **15,498**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- rows still pending ingestion: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950** provisional;
- `aos_f5_identity_cluster_members_v1`: **0**;
- `aos_f5_patient_link_preview_v1`: **0**;
- `aos_f5_canonical_apply_events_v1`: **0**;
- `aos_pacientes`: **7,679**;
- temporary F5 private transport rows: **0**;
- temporary chat gzip rows: **0**;
- temporary chat PGP rows: **0**;
- temporary chat credential rows: **0**.

This snapshot supersedes the earlier lock-acquisition snapshot that had only 1,000 source rows ingested. No claim of F5 completion is made.

## Hotfix isolation contract

During the temporary handoff, the hotfix may mutate only the Calls / Agenda / Marketing surfaces required to restore correct business semantics and traceability. It must not mutate F5 source manifests, F5 source rows, identity clusters/members, F5 preview/apply tables, or historical source workbooks.

The hotfix must preserve the F5 checkpoint above. Any change to F5-owned tables blocks automatic lock restoration and requires explicit investigation.

## Resume contract

After the hotfix is production-certified:

1. re-read current `main` and the hotfix diff;
2. verify F5-owned table counts remain exactly at this checkpoint unless a previously running F5 job is proven to have persisted additional idempotent rows before the pause;
3. verify no F5 preview/apply action was executed during the pause;
4. restore `ACTIVE LOCK: REV-F5-CLOSEOUT`;
5. resume F5.1 from persisted source-row state, never from the obsolete 1,000-row snapshot;
6. reconcile before retrying any ingestion chunk so persisted rows are not duplicated.

## Owner directive

The owner explicitly authorized: pause REV-F5 at a recoverable checkpoint, transfer the global mutable lock to the Calls–Agenda–Marketing hotfix, execute/certify it, then reactivate REV-F5 immediately so the Revenue closeout continues.
