# MKT-INTEGRITY-HOTFIX-V3 — LOOP 1 Execution Report

**Scope:** Control, freeze and rollback package only  
**Business date:** 2026-08-18 Lima  
**Source main:** `6ffdd18542d9636704e5b107e0692beb29405af9`  
**Functional changes:** **NONE**

## Gate results

### G1 — Exact HEAD
**PASS.** `main` was revalidated immediately before control writes and remained `6ffdd18542d9636704e5b107e0692beb29405af9`.

### G2 — Global lock reconciliation
**PASS WITH DOCUMENTATION DRIFT CORRECTED.** The previous CURRENT file still claimed the Hotfix-2/PR #284 era. Live GitHub had advanced through Hotfix-3/3B. The active owner before this Loop remained `REV-F5-CLOSEOUT`; stale references were reconciled in CURRENT without changing functional systems.

### G3 — REV-F5 live checkpoint
**PASS.** F5-owned state remains 7,064 / 15,498 source rows, 3,950 clusters, 0 members, 0 preview and 0 apply events. Recovery hashes were captured. The physical batch table is `aos_f5_source_batches_v1`.

### G4 — BEFORE package
**PASS.** The manifest captures core table hashes/counts, function definition hashes, Acquisition/Attribution/LTV/Historical outputs, Modal summary, explicit Lima-date advisor KPIs and targeted cases.

### G5 — Mireya evidence
**PASS.** Audit log IDs 51948/51949 and 51953/51954 prove calls 37108/37110 were inserted as Marketing CITA CONFIRMADA and then deleted. Restoration is explicitly deferred to Loop 5.

### G6 — Late-lead reconciliation
**PASS / PLAN CORRECTION RECORDED.** The previous 19/17/2 shorthand is not safe as a canonical mutation list. `961780427` has prior CAPILAR lead 4650 and is not equivalent to the true CAPILAR↔BIO mismatch `957549186`. Loop 4 must re-derive candidates from live evidence.

### G7 — Zero functional mutation
**PASS.** No SQL INSERT/UPDATE/DELETE/DDL was executed; Supabase activity in Loop 1 was SELECT-only. No RPC, trigger, frontend, migration, calls, Agenda, leads, sales, Attribution, Acquisition, LTV or REV-F5 data was changed by this Loop.

## Read-only query errors encountered

Two reconciliation queries initially referenced stale/wrong column/table names and failed before execution of any mutation:

- stale documented batch table name `aos_f5_patient_source_batches_v1` → corrected to live `aos_f5_source_batches_v1`;
- `aos_atenciones.telefono` → corrected to live `aos_atenciones.numero_limpio`;
- one ambiguous SQL alias (`anuncio`) was corrected.

These failures were read-only and had zero side effects.

## Portfolio concurrency

Open PRs observed include Sentinel #271, CIA-F17 #277 and legacy #126/#122. None owns the global mutable lock. They remain isolated while `MKT-INTEGRITY-HOTFIX-V3` is active.

## Control artifacts

- `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP1_BEFORE_MANIFEST_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP1_EXECUTION_REPORT_20260818.md`
- `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md` updated to active owner `MKT-INTEGRITY-HOTFIX-V3`.

## Loop result before merge/read-back

`PASS_PENDING_CONTROL_MERGE_READBACK`.

Loop 2 must **not** start until the docs-only control diff is merged to `main`, CURRENT is read back from the merged head, F5-owned hashes are rechecked, and Notion is updated with the resulting main SHA.