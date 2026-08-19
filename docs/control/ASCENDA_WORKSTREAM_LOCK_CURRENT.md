# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 PAUSED RECOVERABLY / MKT-INTEGRITY-HOTFIX-V3 ACTIVE  
**Owner assignment:** 2026-08-18 Lima — Marketing Integrity & Call Center Semantics V3  
**Certified main before Loop 5:** `488eb8d703f25e46d330161bdc8cf8c695bed5e9`  
**Previous lock:** `REV-F5-CLOSEOUT` — `PAUSED_RECOVERABLY`  
**ACTIVE LOCK:** `MKT-INTEGRITY-HOTFIX-V3`  
**NEXT LOCK:** `REV-F5-CLOSEOUT` only after MKT Integrity production certification and handback.

## Roadmap execution state

- LOOP 1 — Control / freeze / BEFORE package: **PASS**.
- LOOP 2 — Marketing V3 Shadow: **PASS**.
- LOOP 3 — Acquisition V2↔V3 parity: **PASS**.
- LOOP 4 — Deterministic late-lead backfill: **PASS**.
- LOOP 5 — Mireya repair / inbound-manual semantics: **BLOCKED / STOPPED_PRE_PRODUCT**.
- LOOP 6 — Semántica Call Center + modal paciente existente: **NOT STARTED**.

Loop 5 did not perform productive DML. Do not begin Loop 6 automatically.

## REV-F5 recoverable pause

Canonical checkpoint: `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_MKT_INTEGRITY_V3.md`.

Current certified frozen state remains:

- `aos_f5_source_batches_v1`: **6 batches / 15,498 expected rows**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- remaining: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950**;
- members: **0**;
- preview: **0**;
- apply events: **0**.

High-water timestamps remain:

- batch/source: `2026-08-18T20:13:13.549661Z`;
- cluster update: `2026-08-15T22:23:56.291622Z`.

Loop-1 canonical hashes remain the recovery contract:

- batches: `807f03e96e5786203d867938c3938154`
- source rows: `62b8fbedaa5da450a38c2471dd23b6b9`
- clusters: `2d39d9ac990fee61a7ecb6ffa52efb64`

## Marketing V3 baseline preserved

Acquisition:

- V2 = **54**;
- V3 = **55**;
- V3-only = exactly `973438607 → lead 2135`;
- deterministic V3 hash = `3223caf0ec5d1b264c4494775c6f7d58`;
- duplicate acquisitions = **0**;
- post-sale lead attribution = **0**.

Attribution remains shadow-only:

- V2 = **126 ops / S/45,158.70**;
- V3 = **173 ops / S/66,644.10**;
- delta = **+47 ops / +S/21,485.40**.

The Attribution delta remains reserved for Loop 9; no cutover occurred.

## Loop 4 — certified state preserved

Loop 4 remains PASS with:

- 24 exact call direct links;
- 6 exact Agenda lead+call links;
- 30 NO-ACTION candidates unchanged;
- `35858` remains prior-lead territory;
- `961780427` remains prior-lead 4650;
- `957549186` remains NO_MATCH.

No Loop-4 repair was touched by Loop 5.

## Loop 5 — stopped restoration attempt

Canonical artifacts:

- `docs/control/MKT_INTEGRITY_V3_LOOP5_IMPACT_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5_RESTORATION_EVIDENCE_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5_EXECUTION_REPORT_20260818.md`
- `docs/control/MKT_INTEGRITY_V3_LOOP5_ROLLBACK_20260818.sql`

Targets:

- historical call `37108` / phone `991144656` / lead `5664` / MIREYA;
- historical call `37110` / phone `980547287` / lead `5599` / MIREYA.

Mandatory transaction simulation used exact evidence-supported historical timestamps with all production triggers enabled.

Result after AFTER INSERT triggers:

- `37108` surviving rows = **0**;
- `37110` surviving rows = **0**;
- noncommercial archive rows = **0**;
- target Agenda links remained NULL.

Exact blocker:

`trg_aos_hotfix_manual_agenda_cleanup_call_v1` → `aos_hotfix_manual_agenda_cleanup_v1()`.

The cleanup deletes same-phone/same-advisor `CITA CONFIRMADA` rows when a `CITA_MANUAL` Agenda exists within ±10 seconds. Reconstructed target deltas are:

- 37108 ↔ Agenda `6b1c4962-a597-45d8-8b72-d721d71c20f4`: **0.933s**;
- 37110 ↔ Agenda `d80a4d17-5f2e-4169-8814-c5d5c50eac5c`: **0.821s**.

The Loop-5 contract forbids disabling or changing this guard/cleanup as a workaround. Therefore the transaction was rolled back and productive restore was not attempted.

Post-rollback certified target state:

- 37108 absent;
- 37110 absent;
- Agenda `6b1c...`: lead/call NULL; row hash unchanged `94283cb5aa386ae270579da7436d2dbe`;
- Agenda `d80a...`: lead/call NULL; row hash unchanged `2f79f71ca0d8764c1d77007bff75eae4`;
- call `37062`: preserved; hash `d0c795e583e1890d61236ef822c04d2e`;
- call `36912`: preserved; hash `b76540d9a065e6e21c99a8575d813469`;
- transaction-local test audit rows persisted: 0.

Mireya baseline/readback remained **51 calls / 4 citas** on business date 2026-08-18; productive delta = **0 / 0** because no product DML was authorized.

## Blocker ownership

The blocking defect belongs to:

`LOOP 7 — Guards, cleanup e idempotencia`.

A future fix must distinguish a real commercial callback/inbound/manual conversion from a fabricated call that exists only as the technical side effect of creating a `CITA_MANUAL` Agenda. The two historical restorations may only be retried after that guard/cleanup correction is independently certified.

## Concurrency rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. `MKT-INTEGRITY-HOTFIX-V3` continues to own the global mutable lock. REV-F5 and all other HIGH/CRITICAL workstreams remain read/audit/documentation or regression-only.

## Next action

Do **not** start Loop 6 automatically. Loop 5 is blocked, not passed. Resolve sequencing/governance explicitly before any next functional loop.

## Exit / handback

The global lock remains `MKT-INTEGRITY-HOTFIX-V3`. No handback to REV-F5 occurred.