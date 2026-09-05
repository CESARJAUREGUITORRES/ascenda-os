# MKT-INTEGRITY-V3 — Loop 6 reentry data repair — 2026-08-21

## Scope
Owner-authorized business-data repair only. No DDL, no frontend deploy, no RPC/function mutation, no lock release, and no change to `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.

GitHub main observed immediately before documentation: `b48d46ed3d69370326e5a5a094322c6f04ffa527`.

CURRENT still declares `REV-RUNTIME-BRIDGE-HOTFIX` active; this repair intentionally did not modify that control file or runtime code.

## Root causes confirmed
Two independent defects were observed in live production data:

1. `CITA_MANUAL` cleanup could remove a real `CITA CONFIRMADA` call after the Agenda was persisted. This affected validated new/recovered prospects.
2. Call + Agenda writes are not atomic; an Agenda can persist while the corresponding call never inserts.

The repair did not infer patient-old status from mere registration. Cases were validated against sales, clinical attention, attended/effective appointments, Marketing leads, historical F5 data, and audit evidence.

## Applied corrections

### MIREYA
- Marco Antonio Salcedo Soto `977555153`: restored call `37185`, business date 2026-08-18, lead `5687`, `MARKETING`, `LLAMADA_MANUAL_COMERCIAL`.
- Julia Vera Condezo `943980019`: restored call `37813`, business date 2026-08-20, lead `5829`, `MARKETING`, `LLAMADA_MANUAL_COMERCIAL`.
- Carlos Eduardo Hernández Franchi `924706580`: restored call `38012`, business date 2026-08-21, lead `5830`, `MARKETING`, `LLAMADA_MANUAL_COMERCIAL`.

All three had zero prior sale, zero prior clinical attention and zero prior ASISTIO/EFECTIVA before their conversion event. They are not patient-continuity cases.

### RUVILA
- Lidia Edith Fernandez Salguero `964197925`: created repair call `38186`, business date 2026-08-21, lead `5876`, `MARKETING`, `LLAMADA_MANUAL_COMERCIAL`. Her Agenda had persisted from CALL_CENTER but there was no original call INSERT, DELETE or noncommercial archive.
- Alberto Miguel Machuca Bonilla `948903052`: restored call `38168`, business date 2026-08-21, lead `5018`, `MARKETING`, `LLAMADA_MANUAL_COMERCIAL`. One duplicate Agenda from the first failed retry was removed; one Agenda remains linked to call `38168`.
- Alan Teodoro Valencia Alave `949173236`: retained call `36701` and the first Agenda; removed only the second near-simultaneous duplicate Agenda. Alan already had ASISTIO/clinical evidence before Ruvila's later management and remains a Loop 6 Reactivation/Follow-up semantic case rather than a new acquisition.

### WILMER / César Bravo
No data mutation was performed. F5 historical source confirms César Bravo `984294456` was created 2024-10-01 with last appointment 2024-10-09, but no sale/clinical attendance evidence was found. New Marketing leads also entered on 2026-08-10. This is preserved as a Loop 6 reactivation/recovery case; it must not be turned into a new acquisition by this repair.

## Direct trace links after repair
- Marco Agenda `8fd61e56-60a6-4d68-96c9-20a98a3d3c9e` -> lead `5687` -> call `37185`.
- Julia Agenda `eae7f420-73f7-4dee-9c55-0a06cbbb7a00` -> lead `5829` -> call `37813`.
- Carlos Agenda `5f8f317d-31af-4f5d-8642-5955a77014ec` -> lead `5830` -> call `38012`.
- Alberto Agenda `c9397f9c-f7ae-489a-bbcf-b1806a65bd51` -> lead `5018` -> call `38168`.
- Lidia Agenda `87bf92b1-b10b-4986-9bff-75304d7868da` -> lead `5876` -> call `38186`.

## KPI readback
Pre-apply gate at 2026-08-21 16:29:07 America/Lima:
- MIREYA 97 calls / 1 cita.
- RUVILA 90 calls / 0 citas.
- WILMER 33 calls / 2 citas.

Post-apply readback at 16:30:41:
- MIREYA 98 calls / 2 citas.
- RUVILA 92 calls / 2 citas.
- WILMER 33 calls / 2 citas.

Historical corrected CITA CONFIRMADA counts:
- MIREYA 2026-08-18: +1 Marco.
- MIREYA 2026-08-20: +1 Julia.
- MIREYA 2026-08-21: +1 Carlos.
- RUVILA 2026-08-21: +2 Lidia + Alberto.

## Deduplication readback
- Alberto 2026-08-25 16:00 RUVILA: exactly 1 Agenda remains.
- Alan 2026-08-27 15:00 RUVILA: exactly 1 Agenda remains.
- Removed duplicate IDs: `89490590-77ef-46f8-a304-bb73096e89f0` (Alberto first failed retry) and `2120d8fb-0fb2-474c-9fc8-b4d522c71e25` (Alan second duplicate).

## Idempotency
Second-run checks:
- missing target calls: 0.
- missing direct trace links: 0.
- duplicate target Agenda IDs remaining: 0.

## Marketing / Revenue invariants after repair
- Acquisition V2: 56.
- Acquisition V3: 57.
- V2-only: 0.
- V3-only remains `973438607 -> lead 2135`.
- Target repaired phones have no sales and no Attribution rows, so this repair did not create revenue attribution.
- Live Attribution later read 135 ops / S47,273.70 V2 and 183 ops / S69,159.10 V3; the +1/S10 advance versus an earlier live read is unrelated concurrent activity, not any repaired target.

REV-F5 remains:
- batches 6.
- source rows 15,498.
- clusters 8,716.
- members 15,498.
- previews 8,716.
- canonical apply events 230.

Function fingerprints remain:
- `aos_hotfix_call_guard_v1`: `d05de50205e7c716cc048c4a5e6923a2`.
- `aos_hotfix_manual_agenda_cleanup_v1`: `a6f918f64ac56f587a75ed0aebde0e09`.

## Rollback evidence captured before apply
Original retained Agenda link state for Marco, Julia, Carlos, Lidia and Alberto was `lead_id_origen = NULL` / `llamada_id_origen = NULL`; exact pre-repair `ts_actualizado` values were captured.

Full original rows were captured for both removed duplicate Agendas, including IDs, patient fields, appointment slot, `obs`, timestamps, advisor, origin and all nullable linkage columns.

A controlled rollback consists of:
1. removing only repair calls `37185`, `37813`, `38012`, `38168`, `38186` when they still carry `tipo_gestion=LLAMADA_MANUAL_COMERCIAL` and the explicit `REPAIR VALIDADO 2026-08-21` marker;
2. restoring the five retained Agenda direct-link fields to NULL and their captured timestamps;
3. reinserting exact duplicate Agenda row `2120d8fb-0fb2-474c-9fc8-b4d522c71e25` for Alan if a rollback truly intends to restore the pre-repair duplicate state;
4. reinserting exact duplicate Agenda row `89490590-77ef-46f8-a304-bb73096e89f0` for Alberto if a rollback truly intends to restore the pre-repair duplicate state;
5. preserving Alan call `36701` throughout.

The connector safety layer blocked committing an executable destructive rollback SQL file; the complete source rows and values were nevertheless captured before mutation and are preserved in the execution trace.

## Loop 6 reentry canaries now frozen
Loop 6 must use these real cases:
- New Marketing + CITA_MANUAL cleanup bug: Marco, Julia, Carlos.
- New Marketing + CALL_CENTER partial persistence: Lidia.
- Recovered lead + retry duplicate + cleanup: Alberto.
- Existing patient / ASISTIO + duplicate Agenda: Alan.
- Historical appointment + new lead, no demonstrated prior conversion: César Bravo -> Reactivation/Recovery decision, not new acquisition.

## Next gate
Do not start Loop 6 functional mutation until the active portfolio lock is intentionally handed back to `MKT-INTEGRITY-HOTFIX-V3` (or otherwise explicitly released/reassigned). The functional Loop 6 must then implement atomic call+Agenda persistence, explicit semantic buttons and F6 patient-state reuse, while preserving this repaired dataset as regression canaries.
