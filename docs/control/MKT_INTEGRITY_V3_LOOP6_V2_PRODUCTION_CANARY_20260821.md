# MKT-INTEGRITY-HOTFIX-V3 — Loop 6 V2 production canary — 2026-08-21

## Functional runtime

- Loop 6 base atomic runtime PR #335: merged.
- Credit/ownership V2 PR #337: merged at `521c013209702a7c26ddafed23799f9c36236481`.
- Retry/idempotency hotfix PR #338: merged at `7e5e7915b4c771649e50fd11e2af767819383052`.
- Railway status for exact functional runtime `7e5e7915b4c771649e50fd11e2af767819383052`: **SUCCESS** (`ASCENDA-OS - ascenda-os`).
- Loop 7: **NOT STARTED**.

## Expanded V2 rules now server-authoritative

1. Reactivation credit is eligible only when at least 15 full days have elapsed from the latest qualifying prior sale, clinical attention or ASISTIO/EFECTIVA appointment, using America/Lima.
2. Before 15 days, Reactivation is preserved as a real management action and Agenda may be created, but no new commercial `CITA CONFIRMADA` credit is awarded; beneficiary scope is CLINIC.
3. A prior NO ASISTIO protects the original commercial owner for 72 hours from the original appointment slot.
4. Another advisor may rescue/rebook inside that window, but the new call is non-conversion follow-up and Agenda remains under the original owner; executor is still audited.
5. After 72 hours, transfer is allowed only if the original owner has no registered post-no-show follow-up.
6. If the original owner did register follow-up, ownership remains with that advisor even after 72 hours.
7. The original owner rebooking their own NO ASISTIO does not create a second conversion.
8. An existing active PENDIENTE/CITA CONFIRMADA appointment blocks creation of another commercial conversion/Agenda.
9. `FOLLOWUP_CONVERSION` is distinct from `CALLBACK_INBOUND`.
10. `AGENDA_ONLY` creates Agenda only and awards zero commercial call/cita credit.
11. Browser selection is advisory; server policy is authoritative and may BLOCK or DOWNGRADE.
12. The action journal distinguishes executor (`asesor/id_asesor`) from `credited_advisor`, `commercial_owner`, `beneficiary_scope`, `eligibility_status`, `eligibility_reason` and `ownership_transfer`.

## Dedicated V2 rollback canaries

All requested policy canaries PASS and ended in ROLLBACK:

- Reactivation <15d -> DOWNGRADE / SEGUIMIENTO / beneficiary CLINIC / no commercial cita credit.
- Reactivation >=15d -> CITA CONFIRMADA + REACTIVACION / credited to executing advisor / no Marketing acquisition.
- NO ASISTIO <72h by different advisor -> RECUPERACION_APOYO / original owner retained.
- NO ASISTIO >72h without owner follow-up -> `NO_SHOW_RECOVERY_72H`, `CITA CONFIRMADA`, `FOLLOWUP_CONVERSION`, ownership transfer true and credit to recovering advisor.
- >72h with owner follow-up -> `ORIGINAL_OWNER_FOLLOWUP_EXISTS`, SEGUIMIENTO, no transfer.
- original owner rebook -> `ORIGINAL_OWNER_REBOOK`, SEGUIMIENTO, no second conversion.
- active appointment -> BLOCK / `ACTIVE_APPOINTMENT_EXISTS`, 0 new Call, 0 new Agenda, policy event only.
- real Seguimientos conversion -> CITA CONFIRMADA + FOLLOWUP_CONVERSION + direct links; follow-up becomes COMPLETADO inside transaction.
- AGENDA_ONLY -> Agenda 1 / Call 0 / creditedAdvisor null / beneficiary CLINIC.
- misuse commercial button on converted/non-eligible patient -> BLOCK `PATIENT_ACTION_REQUIRED`, 0 Call, 0 Agenda.
- retry/idempotency initially exposed an ordering defect; after hotfix, identical retry returns same callId/agendaId with `idempotent=true` and physical cardinality remains journal 1 / Call 1 / Agenda 1.

## Post-canary invariant readback

- `aos_callcenter_actions_v1`: 0 rows.
- `aos_callcenter_policy_events_v1`: 0 rows.
- synthetic Calls: 0.
- synthetic Agenda rows: 0.
- repaired Calls intact: `36701`, `37185`, `37813`, `38012`, `38168`, `38186`.
- repaired direct links intact for Carlos, Julia, Alberto, Lidia and Marco.
- removed duplicate Agenda rows for Alberto and Alan remain absent.
- REV-F5 exact: 6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events.
- F6 Identity/Lifecycle remain service-role-only.
- Acquisition remains V2 56 / V3 57 / V2-only 0 / sole V3-only `973438607 -> lead 2135`.
- August Attribution snapshot after rollback canaries: V2 22 rows / S/6,538; V3 35 rows / S/13,747.

## New genuine-operation baseline

Captured **after Railway SUCCESS for exact runtime `7e5e7915b4c771649e50fd11e2af767819383052`** at:

- UTC: `2026-08-22T00:23:02.593121+00:00`
- America/Lima: **2026-08-21 19:23:02**

Baseline:

- action journal rows = **0**;
- policy events = **0**;
- max `aos_llamadas.id` = **38343**;
- Agenda rows = **3148**.

Only genuine actions with `created_at > 2026-08-22T00:23:02.593121+00:00` qualify for the terminal Loop 6 V2 real-operation gate.

## Production gate

The first qualifying genuine action is the controlled V2 production canary. It must pass semantic decision, executor/credited-owner attribution, Call/Agenda cardinality, direct links, no duplicate/partial state, no false Marketing acquisition and protected/F5/F6 invariants.

If the first action fails: STOP and repair inside Loop 6.

If it passes: continue normal use until at least **5 genuine actions** exist after the V2 baseline. Do not fabricate customer operations.

Loop 6 remains **PRODUCTION CANARY ACTIVE / NOT YET CERTIFIED** until those >=5 real actions and terminal downstream checks pass. Loop 7 remains **NOT STARTED**.
