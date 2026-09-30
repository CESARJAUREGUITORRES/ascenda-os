# EXECUTION PROMPT — LOOP 6 REBASED — 2026-08-21

## Scope
Execute only `MKT-INTEGRITY-HOTFIX-V3 — LOOP 6: Call Center semantics + existing-patient modal + atomic call/Agenda persistence`.

Do not auto-start Loop 7.

## Mandatory entry gate
1. Re-read `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md` and current `main` HEAD.
2. STOP if another HIGH/CRITICAL lane still owns the portfolio lock. Functional mutation starts only after explicit handback/reassignment to `MKT-INTEGRITY-HOTFIX-V3`.
3. Re-read Supabase LIVE target canaries and all invariants below before creating a functional branch.
4. Advisors may be actively using ASCENDA. Audit/design/tests can run read-only; production frontend/RPC cutover requires a controlled canary window and exact concurrency gate.

Latest main observed while preparing this prompt: `b48d46ed3d69370326e5a5a094322c6f04ffa527`. Treat this only as a reentry reference; exact-head must be revalidated at execution time.

## Certified reentry repair baseline
The following business-data repair is already applied and MUST NOT be recreated:

### MIREYA
- `37185` Marco Antonio Salcedo Soto `977555153` -> lead `5687` -> 2026-08-18 -> `LLAMADA_MANUAL_COMERCIAL` -> `CITA CONFIRMADA`.
- `37813` Julia Vera Condezo `943980019` -> lead `5829` -> 2026-08-20 -> `LLAMADA_MANUAL_COMERCIAL` -> `CITA CONFIRMADA`.
- `38012` Carlos Eduardo Hernández Franchi `924706580` -> lead `5830` -> 2026-08-21 -> `LLAMADA_MANUAL_COMERCIAL` -> `CITA CONFIRMADA`.

### RUVILA
- `38186` Lidia Edith Fernandez Salguero `964197925` -> lead `5876` -> 2026-08-21 -> `LLAMADA_MANUAL_COMERCIAL` -> `CITA CONFIRMADA`.
- `38168` Alberto Miguel Machuca Bonilla `948903052` -> lead `5018` -> 2026-08-21 -> `LLAMADA_MANUAL_COMERCIAL` -> `CITA CONFIRMADA`.

### Deduplication
- Alberto keeps Agenda `c9397f9c-f7ae-489a-bbcf-b1806a65bd51`; duplicate `89490590-77ef-46f8-a304-bb73096e89f0` was removed.
- Alan Valencia keeps Agenda `3e21556f-e46e-409e-95ab-37c00413fbe6` + call `36701`; duplicate `2120d8fb-0fb2-474c-9fc8-b4d522c71e25` was removed.

Direct Agenda links MUST remain:
- Marco -> lead 5687 / call 37185.
- Julia -> lead 5829 / call 37813.
- Carlos -> lead 5830 / call 38012.
- Alberto -> lead 5018 / call 38168.
- Lidia -> lead 5876 / call 38186.

Idempotency reentry gate: 0 missing repaired calls, 0 missing direct links, 0 removed duplicate IDs present.

## Dynamic KPI reference immediately after repair
At 2026-08-21 16:30:41 America/Lima:
- MIREYA 98 calls / 2 citas.
- RUVILA 92 calls / 2 citas.
- WILMER 33 calls / 2 citas.

These daily totals are dynamic because advisors continue working. Do not hard-code them as future equality gates. Use the specific repaired call IDs/direct links as immutable regression gates and compute future KPI deltas relative to a fresh immediate baseline.

## Marketing / REV invariants at reentry
- Acquisition V2 = 56.
- Acquisition V3 = 57.
- V2-only = 0.
- V3-only remains `973438607 -> lead 2135`.
- Repaired target phones have no sales and no Attribution rows at reentry.
- REV-F5: 6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events.
- `aos_hotfix_call_guard_v1` hash = `d05de50205e7c716cc048c4a5e6923a2`.
- `aos_hotfix_manual_agenda_cleanup_v1` hash = `a6f918f64ac56f587a75ed0aebde0e09`.

## Existing architecture to reuse
### REV-F6.1 Identity Bridge
Use the certified canonical identity resolution to resolve phone/document/email safely. Fail closed on identity conflict/shared-phone ambiguity. Do not build a second fuzzy patient resolver.

### REV-F6.2 Lifecycle
Reuse lifecycle evidence as context, but DO NOT equate every historical lifecycle event with a converted patient.

For this Loop, **patient converted before the current event** requires strong evidence before the event:
- prior sale; OR
- prior clinical attention; OR
- prior Agenda `ASISTIO` / `ASISTIÓ` / `EFECTIVA`.

The following alone do NOT prove converted-patient status:
- existence in `aos_pacientes`;
- historical source row;
- old appointment/last-appointment field with no attendance proof;
- prior lead;
- prior `NO ASISTIO` / `CANCELADA` / pending appointment;
- failed call attempts.

This distinction is mandatory because César Bravo `984294456` is present in F5 historical source (created 2024-10-01, last appointment 2024-10-09) but has no demonstrated sale/clinical attendance; he also received new Marketing leads in August 2026. Treat that pattern as historical prospect / reactivation-recovery context, not automatically as converted-patient acquisition suppression.

## Current Call Center problems to eliminate
1. `guardarCitaManual()` / current call flow can write call + Agenda as independent browser operations rather than one atomic transaction.
2. A CALL_CENTER Agenda can persist while its call never inserts (real canary: Lidia).
3. A CITA_MANUAL call can INSERT and then be removed by timing cleanup despite being a valid new prospect (real canaries: Marco, Julia, Carlos, Alberto).
4. Direct `llamada_id_origen` / `lead_id_origen` links are not guaranteed at creation.
5. Duplicate retry/click can create a second Agenda (Alberto; Alan historical duplicate).
6. Backend CC-Q1/contact-debt logic exists but the audited frontend path has still used `aos_siguiente_lead_v2`; reconcile the actual current code before cutover.

## Business semantics to implement
### A. Prospect not previously converted
If no strong converted-patient evidence exists:
- Marketing lead valid -> normal Marketing prospect/recovery flow.
- No Marketing lead -> organic prospect.
- Real phone conversation + appointment -> call KPI + commercial appointment KPI + Agenda.
- Explicit real manual call -> `LLAMADA_MANUAL_COMERCIAL`.
- Explicit inbound/callback -> `CALLBACK_INBOUND`.
- A prior NO ASISTIO/CANCELADA does not block a new legitimate acquisition conversion if the person never converted.

### B. Converted patient detected
Show an explicit ASCENDA modal with evidence summary and three choices:

1. `♻️ Reactivación comercial`
   - preserve a real call/management event;
   - allow Agenda;
   - no new acquisition / no new Marketing customer;
   - auditable user-confirmed semantic classification.

2. `📞 Seguimiento de paciente`
   - preserve the real follow-up management event;
   - allow Agenda if applicable;
   - no acquisition / no new commercial conversion.

3. `📅 Solo agendar cita`
   - create Agenda only;
   - zero commercial call KPI;
   - zero commercial appointment KPI;
   - zero acquisition.

Do not force advisors to leave Call Center to use `Solo agendar`; semantics depend on explicit intent, not only module location.

### C. Historical prospect / old appointment but no proven conversion
Do not silently classify as converted patient. Examples include César Bravo-type cases. Surface historical context if useful and allow a reactivation/recovery semantic decision, but never fabricate a new acquisition or suppress a valid call solely because an old appointment exists.

## Atomic persistence requirement
Replace browser-side independent call/Agenda writes for the affected flow with one governed server-side transaction/RPC (or equivalent atomic contract) that:
1. validates semantic action;
2. resolves identity and patient-conversion evidence;
3. resolves Marketing lead/origin deterministically;
4. inserts/preserves the call when required;
5. inserts Agenda when required;
6. writes `llamada_id_origen` + `lead_id_origen` before commit;
7. returns both IDs;
8. commits both or neither;
9. is idempotent for retries/double-clicks.

Do not use timing proximity (`±10s`) as business truth. Timing may remain only as a legacy diagnostic signal.

Audit existing fields before adding schema. Reuse safe existing fields where possible. Any new idempotency/action key must be minimal, justified and rollbackable.

## CC-Q1 / Contact Debt integration
Before enabling any new contact-debt priority in the live frontend:
- reconcile current `aos_siguiente_lead` vs `aos_siguiente_lead_v2` consumption;
- resolve canonical identity;
- distinguish unconverted prospect from converted patient;
- do not present a converted patient as a new acquisition simply because a new lead/touchpoint exists;
- if reactivation work should enter the queue, route/classify it as reactivation, not acquisition.

## Mandatory real canaries
### Canary 1 — Marco
`977555153`, lead 5687. New prospect. Must produce one atomic call+Agenda and preserve direct links. No cleanup deletion.

### Canary 2 — Julia
`943980019`, lead 5829 nearest valid current touchpoint. Prior failed leads/calls but no conversion. Must remain recoverable and count as commercial call+cita.

### Canary 3 — Carlos
`924706580`, lead 5830 entered minutes before conversion. Must count call+cita and remain Marketing.

### Canary 4 — Lidia
`964197925`, lead 5876. Demonstrate that a CALL_CENTER save cannot leave Agenda without call. Atomic all-or-nothing required.

### Canary 5 — Alberto
`948903052`, lead 5018. Prior SIN CONTACTO then successful recovery. One click/retry must yield exactly one call + one Agenda, never duplicates.

### Canary 6 — Alan
`949173236`. Prior ASISTIO/clinical evidence. Must trigger converted-patient semantics. No new acquisition. Retry must not duplicate Agenda.

### Canary 7 — César Bravo
`984294456`. Historical row + old appointment, no demonstrated conversion, plus new Marketing leads. Must not be incorrectly treated as converted merely because historical registration/appointment exists. Exercise reactivation/recovery semantics without manufacturing new acquisition.

### Canary 8 — Agenda-only
Create a synthetic/controlled existing-patient `Solo agendar` transaction: Agenda +1, commercial calls +0, commercial citas +0, acquisition +0.

### Canary 9 — Shared phone
Use a safe synthetic/shared-phone case; identity conflict must fail closed and require review instead of auto-attribution.

### Canary 10 — Legacy cleanup
A truly artificial legacy duplicate side-effect may still be cleaned, but a semantically explicit real commercial call must never be removed solely due to same-second Agenda creation.

## Regression gates after every canary
- Calls 37185, 37813, 38012, 38168, 38186 and 36701 remain intact.
- Five repaired Agenda direct links remain intact.
- Alberto target Agenda count remains exactly 1.
- Alan target Agenda count remains exactly 1.
- Acquisition relationship V2/V3 remains structurally valid; any natural live-data delta must be explained by new sales/leads, not canary writes.
- V3-only delta must be explicitly reconciled if it changes.
- REV-F5 protected counts remain unchanged.
- No target canary creates an unexpected sale/Attribution row.
- F6 identity/lifecycle contracts remain certified.

## Frontend audit targets
Re-read current versions before mutation:
- `app/public/calls.js`
- `app/public/calls.html`
- Agenda code used for direct Agenda creation
- current Call Center queue/next-lead consumer

Specifically re-audit current implementations of:
- `guardarCitaManual()`
- `usarNumManual()`
- `ccConfirmarCita()`
- manual/inbound/callback flows
- the actual RPC name consumed for next lead.

## Safety / execution sequence
1. exact-head + lock + Supabase readback;
2. Impact Report;
3. branch dedicated to Loop 6;
4. schema/consumer audit;
5. design atomic RPC and semantic contract;
6. rollback package before production mutation;
7. transaction/synthetic canaries first;
8. shadow/canary frontend path;
9. controlled production cutover;
10. immediate readback while advisors may still be active;
11. idempotency second-run;
12. GitHub PR + CI;
13. Notion synchronization;
14. final certification.

## STOP conditions
STOP if:
- portfolio lock is not available for MKT Loop 6;
- main changes incompatibly after exact-head;
- any repaired target call/link disappears;
- Alan/Alberto duplicate counts return >1;
- new patient is classified converted solely because a patient row or old appointment exists;
- converted patient becomes a new acquisition;
- `Solo agendar` creates a commercial call;
- CALL_CENTER can still partially commit Agenda without call;
- retry can produce duplicate Agenda/call;
- explicit manual/inbound commercial call is deleted by cleanup;
- shared-phone conflict auto-resolves incorrectly;
- REV-F5/F6 protected contracts drift;
- rollback cannot be demonstrated.

## PASS definition
LOOP 6 = PASS only if atomic persistence, explicit semantics, converted-patient modal, reactivation/follow-up/Agenda-only behaviors, contact-debt compatibility, direct links, idempotency and all real canaries pass without regression.

If and only if Loop 6 = PASS:
- update CURRENT/Notion after reconciling portfolio lock;
- STOP;
- do not start Loop 7;
- produce the complete self-contained prompt for Loop 7 — Guards, Cleanup & Idempotency hardening.
