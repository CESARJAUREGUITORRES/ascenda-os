# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 Execution Report

**Loop:** Reparación Mireya y llamadas inbound/manuales  
**Business date:** 2026-08-18 Lima  
**Entry main:** `488eb8d703f25e46d330161bdc8cf8c695bed5e9`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Branch:** `feat/mkt-integrity-v3-loop5-mireya-restore`  
**Result:** `STOPPED_PRE_PRODUCT / FAIL_BY_STOP_CONDITION`  
**Productive Supabase DML:** **0**  
**Loop 6:** NOT STARTED

## Why Loop 5 did not proceed to production

The mandatory restoration simulation reproduced the historical cleanup defect exactly.

Both reconstructed calls were inserted inside a transaction with all production triggers active:

- `37108` — 991144656 — MIREYA — CITA CONFIRMADA — CAPILAR;
- `37110` — 980547287 — MIREYA — CITA CONFIRMADA — CAPILAR.

After all AFTER INSERT triggers ran, a table read returned:

- 37108 exists: **0**;
- 37110 exists: **0**;
- surviving target rows: **0**.

Transaction-local audit showed INSERT + DELETE for each call. The transaction was rolled back, so these test audit rows did not persist.

The Loop-5 contract explicitly requires STOP if a trigger deletes a restored call and forbids disabling or altering that trigger as a workaround. Therefore no productive restoration is authorized in this loop.

## Gate 0

PASS before simulation:

- exact main `488eb8d703f25e46d330161bdc8cf8c695bed5e9`;
- CURRENT Loop 1–4 PASS / Loop 5 NOT STARTED;
- active lock `MKT-INTEGRITY-HOTFIX-V3`;
- REV-F5 7,064 / 15,498 and 3,950 clusters, 0 members/preview/apply;
- F5 write high-water unchanged;
- Acquisition 54 / 55;
- V3-only exactly `973438607 → 2135`;
- deterministic hash `3223caf0ec5d1b264c4494775c6f7d58`;
- duplicates 0;
- post-sale 0;
- Attribution V2 126 / S/45,158.70;
- Attribution V3 173 / S/66,644.10;
- 37108/37110 absent;
- leads 5664/5599 exact;
- target Agendas exact and unlinked;
- calls 37062/36912 exact and preserved;
- audit 51948/51949/51953/51954 consistent with Loop-1 BEFORE.

## Prior-patient gate

PASS:

Both people had zero prior sales, clinical attentions, attended appointments and Acquisition rows before the historical successful event.

This also explains why `aos_hotfix_call_guard_v1` did not archive/suppress the simulated rows. `aos_gestiones_no_comerciales` remained empty for 37108/37110 during the simulation.

## Sequence / uniqueness gate

PASS:

- sequence: `aos_llamadas_id_seq`;
- last value: 37198;
- max call id: 37198;
- target ids 37108 and 37110 free;
- expected sync keys free;
- no sequence rewind required.

## Exact trigger blocker

Trigger:

`trg_aos_hotfix_manual_agenda_cleanup_call_v1`

Function:

`aos_hotfix_manual_agenda_cleanup_v1()`

The active function deletes a newly inserted CITA CONFIRMADA when it finds a same-phone/same-advisor Agenda with `origen_cita='CITA_MANUAL'` and an event-time distance ≤10 seconds.

Reconstructed event distance to the historical Agenda:

- 37108: 0.933 s;
- 37110: 0.821 s.

Thus both valid historical calls match the current technical-delete signature.

## Simulation result

### Insert stage

Attempted exactly 2 rows using evidence-supported fields. No trigger was disabled, no function was modified and no session-level bypass was used.

### After-trigger probe

- target rows surviving: 0;
- 37108: deleted;
- 37110: deleted;
- noncommercial archive: 0;
- Agenda direct links: unchanged NULL/NULL.

Because the calls did not survive, the simulation intentionally did **not** proceed to Agenda linking. Doing so would create dangling call references and violate the gate contract.

### Rollback

The entire simulation was rolled back.

Post-rollback readback:

- 37108 absent;
- 37110 absent;
- Agenda 6b1c... link NULL/NULL and row hash unchanged `94283cb5aa386ae270579da7436d2dbe`;
- Agenda d80a... link NULL/NULL and row hash unchanged `2f79f71ca0d8764c1d77007bff75eae4`;
- call 36912 hash unchanged `b76540d9a065e6e21c99a8575d813469`;
- call 37062 hash unchanged `d0c795e583e1890d61236ef822c04d2e`;
- transaction-local audit rows persisted: 0.

## Mireya KPI

Baseline immediately before simulation:

- calls on 2026-08-18: 51;
- CITA CONFIRMADA: 4;
- panel: 51 / 4;
- monitoreo: 51 / 4;
- Agenda total: 3,126.

After rollback:

- calls: 51;
- CITA CONFIRMADA: 4;
- Agenda total: 3,126.

Targeted productive delta: **0 calls / 0 citas**, because no productive apply was allowed.

The required PASS delta +2/+2 was therefore not reached, by design of the STOP rule.

## Marketing invariants after rollback

Unchanged:

- Acquisition V2 = 54;
- Acquisition V3 = 55;
- hash = `3223caf0ec5d1b264c4494775c6f7d58`;
- duplicates = 0;
- post-sale = 0;
- Attribution V2 = 126 / S/45,158.70;
- Attribution V3 = 173 / S/66,644.10.

## REV-F5 after rollback

Unchanged:

- batches 6;
- expected 15,498;
- source rows 7,064;
- clusters 3,950;
- members 0;
- preview 0;
- apply 0;
- high-water timestamps unchanged.

## Function / frontend safety

No changes made to:

- `aos_hotfix_call_guard_v1`;
- `aos_hotfix_manual_agenda_cleanup_v1`;
- Acquisition V2/V3 functions;
- Attribution V2/V3 functions;
- Marketing frontend;
- Calls frontend;
- Home/Monitoreo;
- any migration or production application file.

## Productive apply

**NOT EXECUTED.**

No `supabase/backfills/20260818_mkt_integrity_v3_loop5_mireya_restore.sql` was created because productive DML is blocked.

## Idempotency

Productive idempotency gate is **not applicable** because the productive restore never occurred. The database remains in the same target state as entry: both historical IDs absent and both Agenda links NULL.

## Rollback artifact

`docs/control/MKT_INTEGRITY_V3_LOOP5_ROLLBACK_20260818.sql`

It is an exact guarded contract retained for a later authorized restoration; it was not required against production in this stopped loop because no productive write occurred.

## Governance conclusion

**LOOP 5 ≠ PASS.**

Status:

`LOOP 5 = BLOCKED / STOPPED_PRE_PRODUCT`

Blocker ownership:

`LOOP 7 — Guards, cleanup e idempotencia`

The current cleanup semantics must be made capable of distinguishing a real commercial callback/inbound/manual CITA from an artificial call created only as a side effect of Agenda creation. Only after that correction is certified may 37108/37110 be restored without bypassing protections.

**LOOP 6 = NOT STARTED.**