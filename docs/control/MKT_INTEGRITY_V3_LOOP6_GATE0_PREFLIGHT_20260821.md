# MKT-INTEGRITY-V3 — LOOP 6 Gate 0 / preflight — 2026-08-21

## Result
**Functional status: STOPPED AT GATE 0.**

No functional branch, DDL, RPC, frontend mutation, deploy, trigger change or production canary was executed by this Loop 6 attempt.

The prompt requires STOP if another HIGH/CRITICAL lane owns the portfolio lock. `main` was observed at `b48d46ed3d69370326e5a5a094322c6f04ffa527`, while `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md` still declares `REV-RUNTIME-BRIDGE-HOTFIX` ACTIVE and says Patient 360 + Sales Import owner smoke is still required before release.

Git history proves the REV runtime bridge work is already merged into main and later Patient 360/runtime fixes were deployed successfully, but no recoverable owner-smoke/certification evidence was found that satisfies the explicit lock-release condition. Therefore the lock may be stale, but it is not safe to release it by inference.

## Read-only findings completed despite the STOP

### Current frontend
`app/public/calls.js` still calls `aos_siguiente_lead_v2`, not `aos_siguiente_lead` (CC-Q1 contact-debt function).

`ccConfirmarCita()` still performs independent browser writes using `Promise.all`:
- INSERT `aos_llamadas`
- INSERT `aos_agenda_citas`

`guardarCitaManual()` does the same in the inverse order.

This remains non-atomic and explains the certified Lidia partial-write canary and the historical/manual cleanup races.

Current patient autocomplete (`aos_search_pacientes`) only proves that a record exists; it does not distinguish registered/historical prospect from converted patient.

### Current DB structures that can be reused
`aos_llamadas` already contains:
- `tipo_gestion text default 'LLAMADA'`
- `lead_id_origen bigint`
- `sync_key text` with UNIQUE index

`aos_agenda_citas` already contains:
- `lead_id_origen bigint`
- `llamada_id_origen bigint`

No new columns are required merely for semantic type or direct links.

### `tipo_gestion` compatibility
Live values at preflight:
- `LLAMADA`: 36,108
- `LLAMADA_MANUAL_COMERCIAL`: 7
- `INFERIDA_HISTORICA`: 4

The only public function whose definition directly consumes `tipo_gestion` is `aos_hotfix_manual_agenda_cleanup_v1`. Therefore adding explicit values such as `REACTIVACION` and `SEGUIMIENTO_PACIENTE` is low-blast-radius, provided guard/cleanup and KPI semantics are explicitly updated.

### Current guard behavior
`aos_hotfix_call_guard_v1` currently suppresses a new `CITA CONFIRMADA` before INSERT when it detects:
- prior sale;
- prior clinical attention;
- prior ASISTIO/ASISTIÓ/EFECTIVA;
- or operational text matching ANTIGUO/SESION/CONTROL/DEUDA/APLICACION.

Suppressed rows are archived to `aos_gestiones_no_comerciales` as `PACIENTE_CONTINUIDAD`.

This guard must remain a fail-safe, but Loop 6 needs an explicit semantic bypass/route for user-confirmed `REACTIVACION` and `SEGUIMIENTO_PACIENTE`; otherwise valid existing-patient management would still be swallowed before persistence.

### Current cleanup behavior
`aos_hotfix_manual_agenda_cleanup_v1` protects:
- `LLAMADA_MANUAL_COMERCIAL`
- `CALLBACK_INBOUND`
- `INFERIDA_HISTORICA`

It does not yet protect future:
- `REACTIVACION`
- `SEGUIMIENTO_PACIENTE`

Loop 6 must add those explicit semantics or otherwise make the timing cleanup irrelevant to the governed atomic path.

### Current Agenda dedupe
`aos_hotfix_agenda_dedupe_v1` rejects a same phone/advisor/date/time/treatment insert only when it occurs within 30 seconds.

This is a useful legacy safety net but is not durable idempotency. A retry after a timeout or >30 seconds can still duplicate an action.

### Existing `sync_key` is not a sufficient action idempotency key
`fn_set_sync_key` always derives:
`numero_limpio + fecha + hora_llamada + asesor`.

A browser retry can generate a new current time and therefore a different `sync_key`. `SOLO_AGENDAR` also has no call row and therefore no `sync_key` at all.

Conclusion: Loop 6 requires one minimal durable action journal (or an equivalent single unique request ledger) with a caller-generated `idempotency_key` UNIQUE and result IDs. Reusing `sync_key` alone would not satisfy retry-after-timeout or Agenda-only idempotency.

## F6 reuse and security
Certified functions exist:
- `aos_rev_resolve_patient_identity_v2(p_lookup_type,p_lookup_value)`
- `aos_rev_customer_lifecycle_v1(p_lookup_type,p_lookup_value,p_as_of)`

Both are service-role-only. They MUST NOT be granted to browser roles for Loop 6.

Identity behavior is already correct for this project:
- zero candidates => UNRESOLVED
- one candidate => MATCH
- multiple candidates => IDENTITY_CONFLICT / fail closed

This directly supports the shared-phone canary.

Current ASCENDA app sessions provide a safe pattern through `aos_app_actor_v3(p_token,p_required_panel,p_require_2fa)`.
Relevant panel names are:
- admin: `admin-calls`, `admin-agenda`
- advisor: `advisor-calls`, `advisor-agenda`

The atomic Call Center function should be SECURITY DEFINER and validate `p_token`/actor/panel internally; F6 remains private. Do not put service_role in the browser.

## Proposed Loop 6 governed contract after lock release

### Minimal journal
Create a narrow table such as `aos_callcenter_actions_v1` with at minimum:
- `idempotency_key text primary key`
- `actor_user_id uuid`
- `asesor text`
- `id_asesor text`
- `numero_limpio text`
- `action_type text`
- `input_hash text`
- `lead_id_origen bigint`
- `llamada_id bigint`
- `agenda_id text`
- `status text`
- `result jsonb`
- timestamps

The unique idempotency key is generated once by the client and reused on retry. If the same key arrives with a different input hash, fail closed with `IDEMPOTENCY_CONFLICT`.

### Atomic RPC
A single governed function, provisionally `aos_callcenter_commit_action_v1`, should:
1. validate app token + `advisor-calls` or `admin-calls` authority;
2. normalize the phone;
3. resolve F6 identity;
4. evaluate strong converted-patient evidence before the business event;
5. fail closed on identity conflict;
6. resolve/validate explicit semantic action;
7. resolve nearest valid prior Marketing lead deterministically when relevant;
8. create the call only when semantics require one;
9. create Agenda only when semantics require it;
10. set `llamada_id_origen` and `lead_id_origen` inside the same transaction;
11. close/update any source follow-up only inside the same transaction when applicable;
12. persist journal result;
13. return the same IDs on retry;
14. commit all-or-nothing.

### Proposed semantic mapping
- `COMMERCIAL_CALL_APPOINTMENT` -> call `estado='CITA CONFIRMADA'`, `tipo_gestion='LLAMADA_MANUAL_COMERCIAL'`, Agenda, commercial call + cita KPI.
- `CALLBACK_INBOUND_APPOINTMENT` -> call `estado='CITA CONFIRMADA'`, `tipo_gestion='CALLBACK_INBOUND'`, Agenda, commercial call + cita KPI, conversion to actual handling advisor.
- `REACTIVATION` -> call preserved with `tipo_gestion='REACTIVACION'`; use a non-acquisition state such as `SEGUIMIENTO`/reactivation sub-state so `aos_panel_asesor` does not count it as new commercial `CITA CONFIRMADA`; Agenda may be created.
- `PATIENT_FOLLOWUP` -> call preserved with `tipo_gestion='SEGUIMIENTO_PACIENTE'`, non-acquisition state; Agenda optional.
- `AGENDA_ONLY` -> no call row, Agenda only, zero commercial call/cita KPI.

This keeps the existing general call count meaningful while preventing Reactivation/Follow-up appointments from inflating `citasHoy`, which currently counts only `estado='CITA CONFIRMADA'`.

## CC-Q1 reconciliation
LIVE contains both:
- `aos_siguiente_lead` hash `26d84c3a39bf584bd94cf56a63fb68d8`
- `aos_siguiente_lead_v2` hash `e3a6ccf6bdf450b9c61e29a5ba1c5c47`

`aos_siguiente_lead` implements contact-debt TODAY/MONTH/YEAR/HISTORICAL and falls back to V2.

However current `calls.js` still invokes `aos_siguiente_lead_v2`. Loop 6 must not simply switch to `aos_siguiente_lead` until patient/identity classification is available in the governed path, because contact debt currently does not itself exclude converted patients by F6 identity/lifecycle.

## KPI functions
Current:
- `aos_panel_asesor`: all call rows count as `llamHoy`; only `estado='CITA CONFIRMADA'` counts `citasHoy`.
- `aos_monitoreo_equipo`: same call/cita principle.

This allows a clean Loop 6 mapping:
- real Reactivation/Follow-up remains a real call-management event;
- it must not use `CITA CONFIRMADA` when it should not count as a new commercial appointment.

## Regression state verified
All repaired calls remain present:
- 36701 Alan
- 37185 Marco
- 37813 Julia
- 38012 Carlos
- 38168 Alberto
- 38186 Lidia

All five repaired Agenda direct links remain present.
Removed duplicate Agenda IDs remain absent.

Guard fingerprint remains `d05de50205e7c716cc048c4a5e6923a2`.
Cleanup fingerprint remains `a6f918f64ac56f587a75ed0aebde0e09`.

## Exact blocker to functional execution
The only Gate 0 blocker is portfolio governance: there is no recoverable evidence that the mandatory owner smoke for the active `REV-RUNTIME-BRIDGE-HOTFIX` was completed and the lock formally released.

Before functional Loop 6 mutation, obtain/record successful owner smoke for both originally reported REV flows:
1. Patient 360: search/select a patient and verify the record opens instead of `No encontrado`.
2. Importar ventas: open the import panel and verify the governed import flow no longer fails on the legacy/runtime bridge.

After successful smoke, perform a CONTROL-only CURRENT reconciliation, release `REV-RUNTIME-BRIDGE-HOTFIX`, acquire `MKT-INTEGRITY-HOTFIX-V3`, re-read exact main HEAD, then create the functional branch `feat/mkt-integrity-v3-loop6-call-semantics-atomic` and execute the already-defined canaries/cutover.

**LOOP 6 remains NOT STARTED functionally. LOOP 7 remains NOT STARTED.**
