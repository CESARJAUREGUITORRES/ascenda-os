# ASCENDA OS — FASE 9 VALIDATION REPORT

**Fase:** Assignment Engine  
**Estado:** `VALIDATING`  
**Fecha:** 2026-08-13 (America/Lima)  
**Baseline de entrada:** `5fecc6d9a70f61ba0b437db0c00f2a97c44f15fb`

## Resultado técnico pre-PR

Fase 9 implementa:

`Audience → Activation → Context/Availability → available_keys → Assignment Plan → Assignment Lease`

La fuente autoritativa de candidatos es exclusivamente:

`aos_cia_activation_available_keys_v1(activation_id)`

Fase 9 no reinterpreta elegibilidad/disponibilidad y no modifica el routing del Call Center.

## Objetos persistentes

- `aos_cia_assignment_plans`
- `aos_cia_assignment_targets`
- `aos_cia_assignment_runs`
- `aos_cia_assignments`
- `aos_cia_assignment_events`

Todos con RLS activo y 0 policies permisivas.

## Ownership

- clave de ownership: `aos_usuarios.id` UUID;
- target debe existir, estar `activo=true` y tener `rol='asesor'`;
- nombre/código/área son solo metadata de presentación;
- `GLOBAL` impide ownership activo simultáneo entre Activations;
- `ACTIVATION` mantiene ownership local salvo conflicto con un lease GLOBAL.

## Plan lifecycle

Estados:
- DRAFT
- ACTIVE
- PAUSED
- CLOSED
- CANCELLED

Transiciones DB protegidas.

Hardening:
- configuración del plan inmutable;
- targets inmutables;
- DRAFT→ACTIVE revalida que existan targets;
- revalida que los targets sigan siendo asesores activos;
- ONE exige 1 target;
- PERCENTAGE exige suma 100 al momento de activar;
- CLOSE/CANCEL se bloquea físicamente mientras existan leases activos;
- CLOSED/CANCELLED no pueden reabrirse.

QA terminal rollback-only:
- assigned: 2
- release: 2
- final state: CLOSED
- CLOSE_PLAN events: 1
- reopen blocked: PASS.

## Lease lifecycle

`RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`

Protecciones:
- identidad del lease inmutable;
- delete prohibido;
- assignment debe apuntar a target del plan;
- activation debe coincidir con plan;
- deadlines obligatorios;
- estados terminales no reabribles;
- GLOBAL ownership validado también por trigger DB.

QA lifecycle por lease:
- RESERVE = 1
- ASSIGN = 1
- START = 1
- COMPLETE = 1
- cardinalidad exacta: PASS.

Expiry QA:
- ASSIGNED vencido por `must_start_before` → EXPIRED;
- reconcile expired = 1;
- final state EXPIRED: PASS.

## Candidate contract Fase 8 → Fase 9

`aos_cia_assignment_candidate_keys_v1(plan_id)` parte únicamente de `aos_cia_activation_available_keys_v1(activation_id)`.

Además excluye:
- COMPLETED en la misma Activation;
- active ownership de la misma Activation;
- RELEASED/EXPIRED si la policy no permite reassign;
- ownership externo cuando scope GLOBAL;
- conflicto con cualquier plan GLOBAL cuando scope ACTIVATION.

### DYNAMIC QA

Preset `LEADS_UNWORKED_7D` durante QA:
- F8 available = 103;
- F9 candidates antes de distribuir = 103.

PASS.

### BATCH QA real

Se creó dentro de rollback un snapshot Fase 7 real y se selló con SHA-256:
- snapshot members = 116;
- membership hash length = 64;
- Phase 8 audience total = 116;
- Phase 8 assignable now = 103;
- Phase 9 candidates = 103;
- equality F8 available == F9 candidate: PASS;
- EQUAL 10 / 2 advisors = 5/5.

Esto certifica F7 BATCH → F8 Availability → F9 Assignment.

## Distribution strategies

### ONE
QA source_limit 10:
- assigned = 10;
- un único target recibe el lote.

### EQUAL
Canary 10 / 3 advisors:
- priority 1 = 4
- priority 2 = 3
- priority 3 = 3
- total = 10.

Determinismo: priority y UUID como desempate.

### PERCENTAGE
10 contactos con 50/30/20:
- 5 / 3 / 2
- assigned = 10.

La suma !=100 fue bloqueada físicamente en DRAFT→ACTIVE durante QA adversarial.

### FIXED
Cantidades 2/3/4:
- 2 / 3 / 4
- assigned = 9.

El motor no inventa remainder fuera de las cantidades fijas.

## Capacity

EQUAL 10 / 3 advisors, primer advisor capacity=2:
- 2 / 3 / 3
- assigned = 8.

Capacity es hard cap V1. El overflow permanece candidato; no se redistribuye silenciosamente en la misma ejecución.

## Top-up

### NONE
TOPUP devuelve `TOPUP_DISABLED`.

### MAINTAIN_TARGET
Target = 3 por asesor, 3 asesores:
- initial = 9;
- estado inicial = 3/3/3;
- se libera 1 de RUVILA;
- top-up asigna exactamente 1;
- vuelve a 3/3/3;
- replay con mismo idempotency key = `idempotent=true`;
- filas totales = 10 (9 activas + 1 RELEASED).

PASS.

### CONTINUOUS — defecto descubierto y corregido

QA detectó antes de certificar que la primera implementación reiniciaba el reparto por prioridad en cada top-up.

Caso:
- EQUAL inicial 103 → 52/51;
- release de 1 del segundo target → 52/50;
- implementación original proponía 1 al primer target → 53/50.

No fue aceptado.

Fix canónico:
- migration `20260814040059_cia_phase9_continuous_balance_fix_v2.sql`;
- CONTINUOUS calcula déficit contra la distribución acumulada objetivo.

Re-QA:
- inicial 52/51;
- release segundo → 52/50;
- top-up quotas → primero 0 / segundo 1;
- final 52/51;
- balanced=true.

Para FIXED, CONTINUOUS actúa como refill hasta las cantidades fijas activas; para PERCENTAGE conserva la mezcla acumulada por peso.

## Anti-duplicación / concurrency

- unique parcial por `(activation_id, contact_key)` para RESERVED/ASSIGNED/IN_PROGRESS;
- GLOBAL conflict guard DB;
- allocation serializada mediante `pg_advisory_xact_lock(hashtextextended('aos_cia_assignment_engine_v1',0))`;
- `idempotency_key` en runs;
- un solo INITIAL run por plan mediante unique parcial;
- inserts de run + leases viven en una transacción; fallo revierte el run completo.

QA GLOBAL:
- lease GLOBAL activo creado;
- intento de mismo contact_key en otro plan ACTIVATION = bloqueado;
- después de RELEASE del lease GLOBAL, el segundo plan vuelve a ver los 103 candidatos de F8.

PASS.

## Audit

Eventos append-only:
- CREATE_PLAN
- ACTIVATE_PLAN
- PAUSE_PLAN
- RESUME_PLAN
- CLOSE_PLAN
- CANCEL_PLAN
- RESERVE
- ASSIGN
- START
- COMPLETE
- RELEASE
- EXPIRE
- INITIAL_RUN
- TOPUP

Canary EQUAL 10:
- CREATE_PLAN = 1
- ACTIVATE_PLAN = 1
- INITIAL_RUN = 1
- RESERVE = 10
- ASSIGN = 10.

QA adversarial:
- UPDATE de events rechazado: PASS;
- UPDATE de targets rechazado: PASS;
- CLOSE con active leases rechazado: PASS.

## Fase 10 read contracts

Fase 10 debe consumir:

- `aos_cia_assignment_advisor_workload_v1()`
- `aos_cia_assignment_plan_summary_v1(plan_id)`

Complementarios:
- `aos_cia_assignment_list_v1(...)`
- `aos_cia_assignment_events_v1(...)`

QA 10 leases 4/3/3:
- workload active sum = 10;
- Mireya active = 4;
- assignment list rows = 10;
- event rows = 23;
- todos los workloads contienen `advisor_user_id` UUID: PASS.

Fase 10 no debe reconstruir ownership desde llamadas/leads/source tables.

## Performance

Preset `LEADS_UNWORKED`:
- audience count = 1,277;
- Phase 8 available = 1,169;
- Phase 9 candidate before = 1,169.

Benchmark warm rollback-only con EQUAL / GLOBAL / source_limit=1,000 / 3 advisors:
- candidate count: ~617 ms;
- allocation de 1,000 leases: ~1,774 ms;
- plan summary con 1,000 leases: ~903 ms;
- advisor workload: ~4 ms;
- quotas: 334 / 333 / 333;
- candidate remaining: 169.

PASS. No se añadieron índices sobre tablas operativas pacientes/leads/llamadas/agenda/ventas.

## Seguridad

RLS:
- 5/5 objetos Phase 9: `relrowsecurity=true`;
- policies: 0.

`anon`:
- planes visibles 0;
- assignments visibles 0;
- eventos visibles 0;
- INSERT directo a plan → `new row violates row-level security policy`.

`authenticated`:
- planes 0;
- targets 0;
- runs 0;
- assignments 0;
- events 0.

ACL:
- Phase 9 gateway EXECUTE para anon/authenticated: true;
- candidate_keys direct anon/authenticated: false;
- allocation internal direct anon/authenticated: false.

Gateway token inválido → `UNAUTHORIZED`.

Todos los SECURITY DEFINER Phase 9 verificados con `search_path=public`.

La prueba positiva de lógica se ejecuta sobre core/guards dentro de rollback. La cadena positiva de CIA admin token reutiliza el mecanismo ya certificado en Fases 5–8; no se fabricaron credenciales para QA.

## Frontend

Integrado en `admin-activaciones.html` como cuarta pestaña:

**Distribución**

Nuevos archivos:
- `admin-activaciones-assignment.css`
- `admin-activaciones-assignment.js`

Capacidades:
- lista de planes;
- creación DRAFT;
- selección de Activation ACTIVE con contexto F8;
- estrategia ONE/EQUAL/PERCENTAGE/FIXED;
- ownership GLOBAL/ACTIVATION;
- lease y must-start;
- top-up policy;
- target advisor UUID + priority/weight/fixed/capacity;
- Activate/Pause/Resume/Close/Cancel;
- Reconcile;
- Top-up;
- detail con source available/candidate remaining/depletion;
- carga por asesor;
- leases;
- release administrativo;
- auditoría.

Normal admin UI no expone START/COMPLETE; esos estados quedan preparados para Advisor Work Views futuros.

Audit controller:
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 direct `/rest/v1/aos_*` table reads.

Responsive contract:
- desktop grid;
- tablet responsive targets/forms;
- mobile single-column + table overflow control.

## Legacy compatibility

No se modificaron:
- `aos_siguiente_lead`;
- `aos_siguiente_lead_v2`;
- `aos_cola_config`;
- `aos_leads_en_curso` write path;
- `calls.js`.

Hashes registrados pre-PR:
- `aos_siguiente_lead`: `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2`: `cb69781d1457ed73de8f8d52f0f83a00`

Call Center smoke pre-PR:
- 349 llamadas guardadas en el día Lima;
- última escritura observada: 2026-08-14 01:42:48.301+00.

Email legacy:
- `aos_email_audiencias` = 0;
- `aos_email_campanias` = 0;
- FK `aos_email_campanias.audiencia_id → aos_email_audiencias.id` intacta.

## Zero residue

Estado live pre-PR:
- assignment plans = 0
- targets = 0
- runs = 0
- assignments = 0
- assignment events = 0
- QA audiences = 0
- QA activations = 0.

Todos los E2E fueron rollback-only.

## Replayability

Migrations live Phase 9 y archivos Git alineados:
- `20260814034824_cia_phase9_assignment_schema_v1.sql`
- `20260814034938_cia_phase9_assignment_guards_audit_v1.sql`
- `20260814035139_cia_phase9_candidate_plan_contracts_v1.sql`
- `20260814035241_cia_phase9_allocation_core_v1.sql`
- `20260814035530_cia_phase9_lifecycle_read_contracts_v1.sql`
- `20260814040059_cia_phase9_continuous_balance_fix_v2.sql`
- `20260814040229_cia_phase9_admin_gateway_v1.sql`
- `20260814040509_cia_phase9_plan_activation_hardening_v2.sql`

## Gates pre-PR

- P9-G01 baseline + continuidad F8: PASS
- P9-G02 Impact Report pre-DDL: PASS
- P9-G03 schema + RLS deny-by-default: PASS
- P9-G04 plan/target validation + UUID ownership: PASS
- P9-G05 candidate set = Phase 8 available_keys: PASS
- P9-G06 ONE/EQUAL/PERCENTAGE/FIXED: PASS
- P9-G07 anti-duplication + GLOBAL ownership: PASS
- P9-G08 lease lifecycle + expiry: PASS
- P9-G09 NONE/MAINTAIN_TARGET/CONTINUOUS: PASS
- P9-G10 audit append-only/state guards: PASS
- P9-G11 CIA gateway/auth/limits: PASS
- P9-G12 Phase 10 read contracts: PASS
- P9-G13 frontend/responsive/no native dialogs: PASS pending CI syntax gate
- P9-G14 performance + concurrency/idempotency: PASS
- P9-G15 rollback-only E2E + zero residue: PASS
- P9-G16 Call Center/Email compatibility + replayability: PASS
- P9-G17 PR + CI + staging smoke: PENDING
- P9-G18 roadmap + Validation Report final + `aos_memory`: PENDING

Fase 9 permanece `VALIDATING` hasta cerrar G17–G18.
