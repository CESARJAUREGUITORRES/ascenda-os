# MKT-INTEGRITY-V3 — LOOP 6 Impact Report — 2026-08-21

## Entry gate
- exact main HEAD: `b16e0445301047ec13b0b0aaed8970037127b513`
- active lock: `MKT-INTEGRITY-HOTFIX-V3`
- functional branch: `feat/mkt-integrity-v3-loop6-call-semantics-atomic`
- `REV-RUNTIME-BRIDGE-HOTFIX`: CLOSED / RELEASED after owner smoke PASS
- Loop 7: NOT STARTED

## Objective
Replace ambiguous browser-side Call Center appointment persistence with explicit semantics + F6 identity/patient-state + governed atomic Call↔Agenda persistence + durable idempotency.

## Protected invariants
### REV-F5
Must remain stable:
- 6 batches
- 15,498 source rows
- 8,716 clusters
- 15,498 members
- 8,716 previews
- 230 canonical apply events

### Repaired Call Center dataset
Must remain present/intact:
- 36701 Alan Valencia
- 37185 Marco Antonio Salcedo Soto
- 37813 Julia Vera Condezo
- 38012 Carlos Eduardo Hernández Franchi
- 38168 Alberto Miguel Machuca Bonilla
- 38186 Lidia Edith Fernandez Salguero

Direct links must remain intact for Marco/Julia/Carlos/Alberto/Lidia. Deleted duplicate Agenda rows for Alberto and Alan must not reappear.

## Current defects in blast radius
1. `ccConfirmarCita()` writes `aos_llamadas` and `aos_agenda_citas` independently with browser-side `Promise.all`.
2. `guardarCitaManual()` repeats the same non-atomic pattern.
3. current patient autocomplete proves a record exists, not that a patient was converted before the event.
4. `aos_siguiente_lead` implements CC-Q1 Contact Debt but LIVE frontend still consumes `aos_siguiente_lead_v2`.
5. legacy cleanup still has timing-based semantics for non-explicit call types.
6. `sync_key` is not action idempotency: it depends on current call time and cannot protect Agenda-only actions.

## Architecture — 3 layers
### Layer 1 — Identity + patient state
Reuse existing certified F6 contracts:
- `aos_rev_resolve_patient_identity_v2`
- `aos_rev_customer_lifecycle_v1`

Do not expose either private F6 function to browser roles. The governed Loop 6 function calls them under SECURITY DEFINER after validating the existing ASCENDA app session.

Strong converted-patient evidence before the business event:
- prior sale; OR
- prior clinical attention; OR
- prior Agenda `ASISTIO` / `ASISTIÓ` / `EFECTIVA`.

A patient registry row, old F5 history, old no-show/cancelled appointment, old lead or failed call is not sufficient by itself.

Identity conflict => fail closed / REVIEW.

### Layer 2 — explicit semantic action
Canonical action values:
- `COMMERCIAL_CALL_APPOINTMENT`
- `CALLBACK_INBOUND_APPOINTMENT`
- `REACTIVATION`
- `PATIENT_FOLLOWUP`
- `AGENDA_ONLY`

Call `tipo_gestion` values:
- `LLAMADA_MANUAL_COMERCIAL`
- `CALLBACK_INBOUND`
- `REACTIVACION`
- `SEGUIMIENTO_PACIENTE`

### Layer 3 — atomic persistence
One governed SQL function writes all required rows in one PostgreSQL transaction. No partial Call/Agenda success is allowed.

## Minimal schema impact
Create one narrow action journal:
`aos_callcenter_actions_v1`

Purpose:
- durable `idempotency_key` UNIQUE;
- request input fingerprint;
- actor/advisor/action audit;
- call/Agenda result IDs;
- deterministic retry result.

No new semantic/direct-link columns are required in `aos_llamadas` or `aos_agenda_citas`.

## Security
The browser must send the current ASCENDA app token. The governed function validates actor access through existing `aos_app_actor_v3` against `advisor-calls` or `admin-calls`.

No service-role key in browser.
No grant expansion of private F6 functions.
New governed public RPC may be executable by browser roles only because it enforces the app token internally and returns `UNAUTHORIZED` on invalid authority.

## KPI behavior
Current KPI functions count every `aos_llamadas` row as a call and only `estado='CITA CONFIRMADA'` as a Call Center commercial appointment.

Therefore:
- commercial/callback appointment => `CITA CONFIRMADA` and increments Call + Cita;
- reactivation/follow-up => real call-management row but non-acquisition state; does not increment new commercial Cita;
- Agenda-only => no call row and zero Call/Cita KPI.

## Lead / origin resolution
For a prospect action, preserve explicit `lead_id_origen` when valid and prior to event. Otherwise resolve a deterministic prior Marketing lead using phone + event time and treatment compatibility / nearest-prior rules already established by the Marketing lane.

Never use a lead after the business event.
Converted patient actions never create a new acquisition solely because a later/new Meta lead exists.

## CC-Q1
Do not cut `calls.js` directly from `aos_siguiente_lead_v2` to `aos_siguiente_lead` until the returned candidate is evaluated through F6 patient-state. Prospect may enter Contact Debt; converted patient must route to Reactivation/Follow-up rather than new acquisition; identity conflict fails closed.

## Frontend impact
Primary affected runtime:
- `app/public/calls.js`
- optionally a narrow Loop 6 runtime module loaded by the current Call Center panel
- Call Center modal/selector UI

No changes to Sales Intelligence, Patient360 or revenue UI unless required for a shared security helper.

## Concurrency / idempotency
- caller generates one action idempotency key and reuses it on retry;
- same key + same canonical input => same call/Agenda IDs;
- same key + different input hash => `IDEMPOTENCY_CONFLICT`;
- DB row locking/unique constraint prevents concurrent double-click duplication;
- controlled exception after call insert but before Agenda insert must roll back both.

## Cleanup impact
Explicit semantic calls `LLAMADA_MANUAL_COMERCIAL`, `CALLBACK_INBOUND`, `REACTIVACION`, `SEGUIMIENTO_PACIENTE` must never be deleted solely by Agenda timestamp proximity.

Legacy synthetic side-effect cleanup remains allowed for truly ambiguous legacy `LLAMADA` rows.

## Canary plan
Execute the 15 canaries frozen in the rebased Loop 6 prompt:
1. Marco
2. Julia
3. Carlos
4. Lidia atomic failure
5. Alberto double click
6. Alan existing-patient Reactivation + Agenda-only
7. César Bravo historical prospect
8. synthetic Agenda-only
9. callback/inbound
10. organic new
11. shared phone conflict
12. legacy cleanup
13. retry after timeout
14. old lead/no-show unconverted
15. converted patient + new lead

Synthetic canaries must be transaction-scoped/rollback or uniquely tagged and cleaned without polluting acquisition.

## Production cutover
Shadow → controlled admin/advisor canary → readback → expansion.

Before cutover, revalidate exact-head and active production activity. Deployment must be backward-compatible and short. Do not require advisors to stop ASCENDA for hours.

## Post-cutover watch
PASS requires at least 5 new real operations from Call Center after deployment with verified:
- Agenda
- call semantics
- KPI
- direct links
- no unexpected DELETE
- no duplicate

## Rollback
Before cutover, version a rollback that:
- restores prior `calls.js` behavior/runtime entry point;
- removes/revokes new governed RPC and journal only when safe;
- restores prior guard/cleanup definitions if modified;
- never deletes or alters repaired calls/agendas;
- never restores previously removed Alberto/Alan duplicates.

## STOP conditions
Use all STOP conditions from `MKT_INTEGRITY_V3_LOOP6_EXECUTION_PROMPT_REBASED_20260821.md`, especially protected-row drift, partial atomicity, duplicate action, false acquisition, identity auto-merge, wrong advisor, later-lead attribution, F5/F6 drift, rollback failure or post-cutover inconsistency.
