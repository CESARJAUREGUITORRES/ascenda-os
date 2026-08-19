# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Source main before transfer:** `6ffdd18542d9636704e5b107e0692beb29405af9`  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` after MKT Integrity production certification and handback.

## Authorized scope

The user explicitly authorized the 13-loop Marketing Integrity & Call Center Semantics V3 roadmap. **Only Loop 1 is complete/authorized as executed at this checkpoint. Loop 2 has not started.**

Loop 1 authorizes governance/control writes only:

- revalidate exact `main`;
- reconcile live REV-F5;
- create recoverable F5 checkpoint;
- capture BEFORE/rollback baselines;
- transfer the single global mutable HIGH/CRITICAL lock.

No Marketing rule, RPC, frontend, call, Agenda, lead, sale, attribution, LTV or F5 functional data was mutated by Loop 1.

## REV-F5 recoverable pause

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Live F5-owned state captured 2026-08-18 20:30:10 Lima:

- live batch table: **`aos_f5_source_batches_v1`** (older references to `aos_f5_patient_source_batches_v1` are stale documentation);
- source batches: **6**;
- expected source rows: **15,498**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- remaining source rows: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950**;
- `aos_f5_identity_cluster_members_v1`: **0**;
- `aos_f5_patient_link_preview_v1`: **0**;
- `aos_f5_canonical_apply_events_v1`: **0**;
- observational `aos_pacientes`: **7,684** at capture, **not an F5 invariant** because normal production can continue creating/updating patients.

F5 recovery hashes:

- batches: `807f03e96e5786203d867938c3938154`
- source rows: `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters: `2d39d9ac990fee61a7ecb6ffa52efb64`

Resume REV-F5 from **7,064 / 15,498** only after re-reading live state at handback. If the F5-owned hashes/counts are unchanged, continue from this checkpoint. If a higher idempotent state exists, reconcile before resuming. Never restart from obsolete snapshots.

## MKT-INTEGRITY-HOTFIX-V3 BEFORE package

Canonical manifest: `docs/control/MKT_INTEGRITY_V3_LOOP1_BEFORE_MANIFEST_20260818.md`.

It contains timestamped counts/hashes for:

- `aos_llamadas`, `aos_agenda_citas`, `aos_leads`, `aos_ventas`;
- Attribution V2 and Acquisition V2;
- LTV and Marketing Histórico 2026;
- Modal Leads summary;
- Home/Monitoreo explicit Lima-date snapshot;
- Mireya callback/inbound cases;
- late-lead candidate reconciliation;
- pending buyer attribution cases;
- relevant function definition hashes.

## Reconciliation findings from Loop 1

1. The previous control file was stale: it still referenced Hotfix-2/PR #284 and patient count 7,679 while `main` had already advanced to Hotfix-3B.
2. `aos_pacientes` is operationally live and must not be used as the sole REV-F5 freeze invariant.
3. The planning shorthand `19 strong / 17 compatible / 2 mismatches` for late leads is not canonical. In particular, `961780427` has a prior CAPILAR lead (`4650`) before its CAPILAR call/Agenda and must not be grouped with the true CAPILAR↔BIO mismatch `957549186` without re-derivation.
4. Audit records prove Mireya calls `37108` and `37110` were inserted as `CITA CONFIRMADA / MARKETING` and then deleted; restoration is deferred to Loop 5.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `MKT-INTEGRITY-HOTFIX-V3` owns the lock:

- REV-F5 is read/audit/documentation only;
- CIA, Sentinel, WhatsApp and other mutable HIGH/CRITICAL workstreams remain paused/regression-only;
- open stale/draft PRs do not acquire ownership by existing;
- any `main` advance requires exact-head revalidation before the next hotfix loop.

## Exit / handback gate

The lock returns to `REV-F5-CLOSEOUT` only after the Marketing Integrity work is production-certified, all required canaries/read-backs pass, GitHub/Notion control is reconciled, and REV-F5 hashes/counts are re-read.
