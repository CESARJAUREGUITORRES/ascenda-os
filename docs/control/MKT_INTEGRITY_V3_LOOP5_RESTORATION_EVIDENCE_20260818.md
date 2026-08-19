# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 Restoration Evidence

**Business date:** 2026-08-18 Lima  
**Entry main:** `488eb8d703f25e46d330161bdc8cf8c695bed5e9`  
**Scope:** `37108` and `37110` only  
**Result:** `STOPPED_PRE_PRODUCT`  
**Productive DML:** 0

## Historical evidence

### 37108

- phone: `991144656`
- advisor: `MIREYA`
- state: `CITA CONFIRMADA`
- origin: `MARKETING`
- lead: `5664`
- treatment: `CAPILAR`
- ad: `CAPILAR- INJERTO REEL4`
- audit INSERT: `51949`
- audit DELETE: `51948`
- existing Agenda: `6b1c4962-a597-45d8-8b72-d721d71c20f4`
- Agenda `ts_creado`: `2026-08-19T00:16:08.933Z`
- preserved prior call: `37062` MIREYA / SIN CONTACTO / duration 635.

### 37110

- phone: `980547287`
- advisor: `MIREYA`
- state: `CITA CONFIRMADA`
- origin: `MARKETING`
- lead: `5599`
- treatment: `CAPILAR`
- ad: `CAPILAR- INJERTO REEL4`
- audit INSERT: `51954`
- audit DELETE: `51953`
- existing Agenda: `d80a4d17-5f2e-4169-8814-c5d5c50eac5c`
- Agenda `ts_creado`: `2026-08-19T00:23:27.821Z`
- preserved prior call: `36912` WILMER / SIN CONTACTO / duration 51.

## Payload reconstruction evidence

The productive `app/public/calls.js::guardarCitaManual()` uses one `now = new Date()` to build both:

1. `Agenda.ts_creado = now.toISOString()`; and
2. `aos_llamadas.created_at = now.toISOString()` plus `hora_llamada` from that same local `now`.

This permits reconstruction without inventing timestamps:

| Call | created_at | hora_llamada Lima | Agenda ts_creado |
|---:|---|---|---|
| 37108 | 2026-08-19T00:16:08.933Z | 19:16:08 | 2026-08-19T00:16:08.933Z |
| 37110 | 2026-08-19T00:23:27.821Z | 19:23:27 | 2026-08-19T00:23:27.821Z |

Current `aos_llamada_event_ts` prioritizes `fecha + hora_llamada` and converts them with `America/Lima`. Therefore the event timestamps are:

- 37108 → `2026-08-19T00:16:08Z`;
- 37110 → `2026-08-19T00:23:27Z`.

Distance to the existing CITA_MANUAL Agenda timestamps:

- 37108: **0.933 seconds**;
- 37110: **0.821 seconds**.

Both are far inside the cleanup window of ±10 seconds.

## Prior-patient gate

Before the historical successful events, each phone had:

- 0 prior sales;
- 0 prior clinical attentions;
- 0 prior ASISTIO/EFECTIVA appointments;
- 0 Acquisition V2 rows;
- 0 Acquisition V3 rows.

Thus `aos_hotfix_call_guard_v1` does not classify either event as patient continuity. The transaction simulation also produced **0** `aos_gestiones_no_comerciales` rows for the targets.

## Transaction-only simulation

The exact reconstructed rows were inserted inside one transaction with all normal triggers enabled.

After the INSERT statement completed and all AFTER INSERT triggers ran:

- `37108_exists = 0`;
- `37110_exists = 0`;
- target call rows = `[]`;
- noncommercial archive = `[]`;
- Agenda direct links remained NULL.

Transaction-local audit evidence showed:

- 37108: INSERT + DELETE;
- 37110: INSERT + DELETE.

The transaction was then rolled back. Those transaction-local audit rows did not persist.

## Exact blocker

Active trigger:

`trg_aos_hotfix_manual_agenda_cleanup_call_v1`

Function:

`aos_hotfix_manual_agenda_cleanup_v1()`

The call-side branch deletes a newly inserted `CITA CONFIRMADA` when all are true:

- same normalized phone;
- same advisor;
- existing `CITA_MANUAL` Agenda;
- absolute difference between Agenda `ts_creado` and call event timestamp ≤ 10 seconds.

Both historical target rows satisfy the condition by design of the old UI flow.

## Safety conclusion

Loop 5 is prohibited from:

- disabling triggers;
- changing `session_replication_role`;
- modifying the cleanup function;
- modifying the general call guard.

Therefore restoration cannot be completed safely inside Loop 5 under the frozen rules.

**Result: `LOOP 5 = STOPPED / BLOCKED BY ACTIVE CLEANUP SEMANTICS`.**

This defect must be resolved in the guard/cleanup semantics workstream (Loop 7) before these two historical calls can be restored without bypassing production protections.