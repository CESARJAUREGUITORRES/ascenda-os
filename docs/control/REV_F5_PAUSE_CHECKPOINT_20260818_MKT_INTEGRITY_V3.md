# REV-F5 — Recoverable Pause Checkpoint for MKT-INTEGRITY-HOTFIX-V3

**Captured:** 2026-08-18 20:30:10 Lima  
**Source main:** `6ffdd18542d9636704e5b107e0692beb29405af9`  
**Supabase project:** `ituyqwstonmhnfshnaqz`  
**Purpose:** freeze a recoverable REV-F5 state before transferring the single mutable HIGH/CRITICAL lock to `MKT-INTEGRITY-HOTFIX-V3`.

## Live reconciliation

The live batch table is **`aos_f5_source_batches_v1`**. Older control text that refers to `aos_f5_patient_source_batches_v1` is stale documentation and must not be used as a physical table name.

| Invariant | Live checkpoint |
|---|---:|
| Source batches | 6 |
| Expected source rows | 15,498 |
| Persisted source rows | 7,064 |
| Remaining source rows | 8,434 |
| Identity clusters | 3,950 |
| Cluster members | 0 |
| Link preview rows | 0 |
| Canonical apply events | 0 |
| `aos_pacientes` observational count | 7,684 |

`aos_pacientes` is **not** a REV-F5 freeze invariant because normal production workflows can create/update patients while REV-F5 is paused. The F5-owned staging/identity counts and hashes below are the recovery invariants.

## Content hashes

- `aos_f5_source_batches_v1`: `807f03e96e5786203d867938c3938154`
- `aos_f5_patient_source_rows_v1`: `62b8fbedaa5da450a38c2471dd23b6b9`
- `aos_f5_identity_clusters_v1`: `2d39d9ac990fee61a7ecb6ffa52efb64`
- members/preview/apply counts: all `0`

## Resume contract

REV-F5 is recoverable from **7,064 / 15,498** persisted source rows and **3,950** clusters. On handback:

1. re-read live F5-owned tables;
2. compare the three hashes and counts above;
3. if equal, resume from 7,064 without replaying prior batches;
4. if a higher idempotent persisted state exists, reconcile it before continuing;
5. never restart from obsolete 1,000-row snapshots;
6. do not treat changes in `aos_pacientes` alone as REV-F5 drift.

## Pause scope

While `MKT-INTEGRITY-HOTFIX-V3` owns the lock, REV-F5 may be read/audited/documented only. No F5 staging, cluster membership, preview or canonical apply mutation is authorized.

**Checkpoint status:** `CERTIFIED_RECOVERABLE_PAUSE`.