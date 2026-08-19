# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 Impact Report

**Scope:** Mireya restoration of calls `37108` / `37110` only  
**Business date:** 2026-08-18 Lima  
**Entry main:** `488eb8d703f25e46d330161bdc8cf8c695bed5e9`  
**Branch:** `feat/mkt-integrity-v3-loop5-mireya-restore`  
**Active lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**REV-F5:** paused recoverably; no mutation authorized  
**Status:** `PRE_SIMULATION`

## Gate 0

PASS for all read-only entry gates.

- CURRENT: Loop 1–4 PASS; Loop 5 NOT STARTED.
- REV-F5: 6 batches / 15,498 expected / 7,064 source rows / 3,950 clusters / 0 members / 0 preview / 0 apply.
- F5 high-water: batch/source `2026-08-18T20:13:13.549661Z`; clusters `2026-08-15T22:23:56.291622Z`.
- Acquisition V2/V3: 54 / 55.
- V3-only: `973438607 → lead 2135`.
- V3 deterministic hash: `3223caf0ec5d1b264c4494775c6f7d58`.
- duplicate acquisitions: 0.
- post-sale lead attribution: 0.
- Attribution V2: 126 ops / S/45,158.70.
- Attribution V3: 173 ops / S/66,644.10.
- `37108` absent; `37110` absent.

## Target evidence

### 37108 / 991144656

- Lead `5664`, CAPILAR, `CAPILAR- INJERTO REEL4`.
- Preserved prior call `37062`: MIREYA / SIN CONTACTO / 17:55:05 / duration 635 / hash `d0c795e583e1890d61236ef822c04d2e`.
- Agenda `6b1c4962-a597-45d8-8b72-d721d71c20f4`: PENDIENTE, 2026-08-20 15:00, CAPILAR, MIREYA, `CITA_MANUAL`, direct lead/call NULL; BEFORE row hash `94283cb5aa386ae270579da7436d2dbe`.
- Audit `51949` INSERT + `51948` DELETE proves historical call id 37108, date 2026-08-18, MIREYA, CITA CONFIRMADA, MARKETING, ad `CAPILAR- INJERTO REEL4`, intento 1.
- Agenda `ts_creado = 2026-08-19T00:16:08.933Z`.

### 37110 / 980547287

- Lead `5599`, CAPILAR, `CAPILAR- INJERTO REEL4`.
- Preserved prior call `36912`: WILMER / SIN CONTACTO / 11:16:06 / duration 51 / hash `b76540d9a065e6e21c99a8575d813469`.
- Agenda `d80a4d17-5f2e-4169-8814-c5d5c50eac5c`: PENDIENTE, 2026-08-22 16:00, CAPILAR, MIREYA, `CITA_MANUAL`, direct lead/call NULL; BEFORE row hash `2f79f71ca0d8764c1d77007bff75eae4`.
- Audit `51954` INSERT + `51953` DELETE proves historical call id 37110, date 2026-08-18, MIREYA, CITA CONFIRMADA, MARKETING, ad `CAPILAR- INJERTO REEL4`, intento 1.
- Agenda `ts_creado = 2026-08-19T00:23:27.821Z`.

## Prior-patient gate

Both targets have, before the historical successful event:

- 0 prior sales;
- 0 prior clinical attentions;
- 0 prior ASISTIO/EFECTIVA appointments;
- 0 Acquisition V2 rows;
- 0 Acquisition V3 rows.

Therefore neither target is blocked as a pre-existing converted patient.

## Productive code reconstruction

`app/public/calls.js::guardarCitaManual()` constructs one `now = new Date()` and writes it to both:

- `rowC.ts_creado = now.toISOString()`;
- `rowLM.created_at = now.toISOString()`;

The call payload emitted by that flow is:

`fecha, numero, numero_limpio, tratamiento, estado='CITA CONFIRMADA', hora_llamada, asesor, id_asesor, intento=1, created_at`.

The current BEFORE trigger then resolves Marketing attribution; `fn_set_sync_key()` derives the sync key.

Therefore the evidence-supported reconstruction inputs are:

### Proposed input 37108

- id 37108
- fecha 2026-08-18
- numero / numero_limpio 991144656
- tratamiento CAPILAR
- estado CITA CONFIRMADA
- hora_llamada 19:16:08 Lima
- asesor MIREYA
- id_asesor ZIV-003
- intento 1
- created_at 2026-08-19T00:16:08.933Z

Expected trigger-enriched fields:

- lead_id_origen 5664
- origen MARKETING
- anuncio `CAPILAR- INJERTO REEL4`
- sync_key `991144656_2026-08-18_19:16:08_MIREYA`
- duracion_seg default 0
- tipo_gestion default LLAMADA
- desde_dispositivo default web

### Proposed input 37110

- id 37110
- fecha 2026-08-18
- numero / numero_limpio 980547287
- tratamiento CAPILAR
- estado CITA CONFIRMADA
- hora_llamada 19:23:27 Lima
- asesor MIREYA
- id_asesor ZIV-003
- intento 1
- created_at 2026-08-19T00:23:27.821Z

Expected trigger-enriched fields:

- lead_id_origen 5599
- origen MARKETING
- anuncio `CAPILAR- INJERTO REEL4`
- sync_key `980547287_2026-08-18_19:23:27_MIREYA`
- duracion_seg default 0
- tipo_gestion default LLAMADA
- desde_dispositivo default web

No duration, observation, session/device, result or other nullable field is invented.

## Sequence / uniqueness safety

- `aos_llamadas_id_seq` last_value = 37198, max(id)=37198.
- Explicit restoration ids 37108/37110 are below the sequence high-water.
- Neither PK exists.
- Neither expected sync_key exists.
- No sequence rewind/setval is required or allowed.

## Trigger risk identified before simulation

Active trigger:

`trg_aos_hotfix_manual_agenda_cleanup_call_v1 AFTER INSERT ON aos_llamadas`

Current function deletes a CITA CONFIRMADA when a same-phone/same-advisor `CITA_MANUAL` Agenda exists within ±10 seconds of the call event timestamp.

Because the productive JS uses the same `now` for Agenda `ts_creado` and call `created_at`/local `hora_llamada`, both historical restorations are expected to match that ±10s condition.

Per Loop-5 stop contract, triggers will not be disabled, bypassed or modified. The next action is a transaction-only restoration simulation. If either row is deleted by the active cleanup trigger, Loop 5 must STOP and transfer this defect to Loop 7.

## Live Mireya baseline before simulation

Captured 2026-08-18 22:02:41 Lima:

- calls 2026-08-18: 51
- CITA CONFIRMADA 2026-08-18: 4
- `aos_panel_asesor`: llamHoy 51 / citasHoy 4
- `aos_monitoreo_equipo`: llamadas 51 / citas 4
- total Agenda rows: 3,126

Production is live; a fresh baseline would be mandatory immediately before a productive apply.

## Planned simulation

BEGIN → insert exact 37108 + 37110 → verify rows survive AFTER triggers → only if both survive, link the two existing Agenda rows and run all downstream gates → ROLLBACK.

No productive DML is authorized unless the simulation passes every required gate.