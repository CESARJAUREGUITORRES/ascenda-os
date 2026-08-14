# ASCENDA OS — FASE 9 VALIDATION REPORT

**Fase:** Assignment Engine  
**Estado:** `100_COMPLETE`  
**Fecha:** 2026-08-13 (America/Lima)  
**Baseline de entrada:** `5fecc6d9a70f61ba0b437db0c00f2a97c44f15fb`  
**Functional PR:** #75  
**Ascenda CI:** #576 `SUCCESS`  
**Merge funcional staging:** `57445a0863350c1989d8398157308783bdaf3905`

---

## 1. Resultado certificado

Fase 9 implementa y certifica:

`Audience → Activation → Context/Availability → available_keys → Assignment Plan → Assignment Lease → Fase 10 read-models`

Regla estructural:

> Fase 9 consume exclusivamente `aos_cia_activation_available_keys_v1(activation_id)` de Fase 8. No reconstruye ni reinterpreta elegibilidad/disponibilidad.

Fase 9 **no** modifica ni alimenta todavía la cola operativa del Call Center. Esa integración permanece reservada para Fase 11 detrás de feature flag.

---

## 2. Persistencia

Objetos nuevos:

- `aos_cia_assignment_plans`
- `aos_cia_assignment_targets`
- `aos_cia_assignment_runs`
- `aos_cia_assignments`
- `aos_cia_assignment_events`

RLS:
- 5/5 objetos con `relrowsecurity=true`;
- 0 policies permisivas.

Estado live al cierre:
- plans = 0;
- targets = 0;
- runs = 0;
- assignments = 0;
- events = 0.

No existe data QA residual.

---

## 3. Ownership

Ownership canónico:

`aos_usuarios.id` UUID

Un target debe:
- existir;
- tener `activo=true`;
- tener `rol='asesor'`.

Nombre, código, sede y área son metadata; nunca identificador de ownership.

Scopes:
- `GLOBAL`: un contacto no puede tener ownership activo simultáneo en otra Activation;
- `ACTIVATION`: ownership local a la Activation, salvo conflicto con un lease GLOBAL.

QA GLOBAL:
- lease GLOBAL activo creado dentro de rollback;
- mismo `contact_key` en otro plan ACTIVATION → `ASSIGNMENT_GLOBAL_OWNERSHIP_CONFLICT`;
- tras RELEASE del GLOBAL, el segundo plan vuelve a ver el contacto en candidatos.

PASS.

---

## 4. Assignment Plan lifecycle

Estados:

`DRAFT → ACTIVE ↔ PAUSED → CLOSED | CANCELLED`

Controles DB:
- configuración inmutable;
- targets inmutables;
- delete prohibido;
- DRAFT→ACTIVE revalida targets;
- ONE exige exactamente un target;
- PERCENTAGE exige suma 100;
- asesores se revalidan como activos al activar;
- CLOSE/CANCEL directo se bloquea mientras existan leases activos;
- CLOSED/CANCELLED no se reabren.

QA adversarial:
- percentage 90% → activación bloqueada;
- target UPDATE → bloqueado;
- CLOSE con active leases → bloqueado;
- event UPDATE → bloqueado.

QA terminal:
- 2 leases asignados;
- 2 liberados;
- plan → CLOSED;
- `CLOSE_PLAN` = 1;
- intento CLOSED→ACTIVE → bloqueado.

PASS.

---

## 5. Lease lifecycle

Estados:

`RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`

Controles:
- identidad del lease inmutable;
- plan/activation/target deben coincidir;
- deadlines válidos obligatorios;
- estados terminales irreversibles;
- ownership conflict validado por trigger.

Cardinalidad lifecycle QA:
- RESERVE = 1;
- ASSIGN = 1;
- START = 1;
- COMPLETE = 1.

Expiry:
- ASSIGNED vencido por `must_start_before` → EXPIRED;
- reconcile expired = 1.

PASS.

---

## 6. Fase 8 → Fase 9

### DYNAMIC

Preset `LEADS_UNWORKED_7D` durante QA:
- Fase 8 available = 103;
- Fase 9 candidates = 103.

PASS exacto.

### BATCH

Snapshot Fase 7 real dentro de rollback:
- snapshot members = 116;
- SHA-256 membership hash length = 64;
- Fase 8 audience total = 116;
- Fase 8 assignable now = 103;
- Fase 9 candidate before = 103;
- igualdad `F8 available == F9 candidates` = true;
- EQUAL 10 / 2 advisors → 5/5.

PASS F7 BATCH → F8 Availability → F9 Assignment.

---

## 7. Estrategias certificadas

### ONE
- source_limit 10;
- assigned = 10 a un único target.

### EQUAL
Canary 10 / 3 advisors:
- 4 / 3 / 3.

### PERCENTAGE
10 con pesos 50/30/20:
- 5 / 3 / 2.

### FIXED
Cantidades 2/3/4:
- assigned = 9;
- distribución 2 / 3 / 4.

PASS.

---

## 8. Capacity

EQUAL 10 / 3 asesores; primer asesor `capacity_limit=2`:
- 2 / 3 / 3;
- assigned = 8.

V1 usa capacity como hard cap. El overflow permanece candidato; no se redistribuye silenciosamente en la misma ejecución.

PASS.

---

## 9. Top-up

### NONE
TOPUP → `TOPUP_DISABLED`.

### MAINTAIN_TARGET
Meta 3 por asesor:
- initial = 9;
- 3/3/3;
- release 1 de RUVILA;
- top-up = 1;
- vuelve a 3/3/3;
- replay mismo idempotency key → `idempotent=true`.

### CONTINUOUS
QA descubrió un sesgo antes de certificar:
- inicial EQUAL 103 = 52/51;
- release segundo → 52/50;
- implementación original proponía top-up al primero → 53/50.

No se aceptó.

Fix:
`20260814040059_cia_phase9_continuous_balance_fix_v2.sql`

Semántica corregida: CONTINUOUS calcula déficit contra la distribución acumulada objetivo.

Re-QA:
- inicial 52/51;
- release segundo → 52/50;
- top-up quotas: primero 0 / segundo 1;
- final 52/51;
- balanced = true.

Para PERCENTAGE mantiene mezcla acumulada; FIXED funciona como refill hasta cantidades activas configuradas.

PASS.

---

## 10. Concurrency / idempotency

- advisory transaction lock global del Assignment Engine;
- unique active `(activation_id, contact_key)`;
- unique INITIAL run por plan;
- run idempotency key;
- run + leases en una sola transacción;
- ningún partial assignment sobre error.

PASS.

---

## 11. Auditoría

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
- CREATE_PLAN = 1;
- ACTIVATE_PLAN = 1;
- INITIAL_RUN = 1;
- RESERVE = 10;
- ASSIGN = 10.

PASS.

---

## 12. Seguridad

`anon`:
- plans visible = 0;
- assignments visible = 0;
- events visible = 0;
- INSERT directo → rechazado por RLS.

`authenticated`:
- plans = 0;
- targets = 0;
- runs = 0;
- assignments = 0;
- events = 0.

ACL:
- Phase 9 gateway ejecutable por anon/authenticated;
- candidate_keys directo = no;
- allocation internal directo = no.

Gateway con token inválido:
`UNAUTHORIZED`.

Todos los SECURITY DEFINER Phase 9:
`search_path=public`.

La lógica positiva se probó sobre core/guards rollback-only. No se fabricaron credenciales CIA; la cadena de sesión administrativa reutiliza el mecanismo ya certificado en Fases 5–8.

PASS.

---

## 13. Performance

Audiencia `LEADS_UNWORKED` durante benchmark:
- audience = 1,277;
- Fase 8 available = 1,169;
- Fase 9 candidates = 1,169.

EQUAL / GLOBAL / source_limit=1,000 / 3 advisors:
- candidate count ~617 ms;
- allocation 1,000 leases ~1,774 ms;
- plan summary ~903 ms;
- advisor workload ~4 ms;
- quotas 334/333/333;
- candidate remaining 169.

No se añadieron índices sobre pacientes/leads/llamadas/agenda/ventas.

PASS.

---

## 14. Fase 9 → Fase 10

Read contracts canónicos:

`aos_cia_assignment_advisor_workload_v1()`

`aos_cia_assignment_plan_summary_v1(plan_id)`

Complementarios:
- `aos_cia_assignment_list_v1(...)`
- `aos_cia_assignment_events_v1(...)`

QA 10 leases 4/3/3:
- workload active sum = 10;
- Mireya active = 4;
- list rows = 10;
- event rows = 23;
- `advisor_user_id` UUID presente en todas las filas.

Post-merge smoke sin planes reales:
- 6 asesores activos retornados;
- carga active = 0 para todos;
- UUID estable presente.

**Fase 10 debe consumir estos read-models y no reconstruir ownership desde calls/leads/source tables.**

---

## 15. Frontend

Activaciones incorpora cuarta pestaña:

**Distribución**

Archivos:
- `admin-activaciones-assignment.css`
- `admin-activaciones-assignment.js`

Funciones:
- crear plan DRAFT;
- estrategia y ownership;
- advisor targets;
- priority/percentage/fixed/capacity;
- Activate/Pause/Resume/Close/Cancel;
- top-up;
- reconcile;
- plan detail;
- load by advisor;
- leases;
- release administrativo;
- audit.

Controller audit:
- 0 alert();
- 0 confirm();
- 0 prompt();
- 0 direct `/rest/v1/aos_*` table reads.

Responsive desktop/tablet/mobile cubierto por CSS breakpoints y table overflow.

Ascenda CI #576 pasó el controller público y archivos productivos.

PASS.

---

## 16. Legacy compatibility

No se modificaron:
- `aos_siguiente_lead`;
- `aos_siguiente_lead_v2`;
- `aos_cola_config`;
- `aos_leads_en_curso` write path;
- `calls.js`;
- Email legacy.

Hashes pre/post merge:
- `aos_siguiente_lead`: `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2`: `cb69781d1457ed73de8f8d52f0f83a00`

Call Center post-merge:
- 349 llamadas en el día Lima.

Email:
- `aos_email_audiencias` = 0;
- `aos_email_campanias` = 0;
- FK legacy intacta.

PASS.

---

## 17. Replayability

Migrations Git = migrations live:

1. `20260814034824_cia_phase9_assignment_schema_v1.sql`
2. `20260814034938_cia_phase9_assignment_guards_audit_v1.sql`
3. `20260814035139_cia_phase9_candidate_plan_contracts_v1.sql`
4. `20260814035241_cia_phase9_allocation_core_v1.sql`
5. `20260814035530_cia_phase9_lifecycle_read_contracts_v1.sql`
6. `20260814040059_cia_phase9_continuous_balance_fix_v2.sql`
7. `20260814040229_cia_phase9_admin_gateway_v1.sql`
8. `20260814040509_cia_phase9_plan_activation_hardening_v2.sql`

PASS.

---

## 18. Integración GitHub / staging

Functional PR #75: MERGED.

Ascenda CI #576: SUCCESS.

Merge funcional:
`57445a0863350c1989d8398157308783bdaf3905`

Post-merge smoke:
- frontend F9 presente en staging;
- 0 datos Phase 9 persistentes;
- 0 QA residue;
- RLS/gateway intactos;
- Call Center hashes intactos;
- Call Center operativo;
- F10 read-model operativo.

PASS.

---

# GATES

- P9-G01 baseline + continuidad F8: PASS
- P9-G02 Impact Report pre-DDL: PASS
- P9-G03 schema + RLS deny-by-default: PASS
- P9-G04 plan/target validation + UUID ownership: PASS
- P9-G05 candidates = Phase 8 available_keys: PASS
- P9-G06 ONE/EQUAL/PERCENTAGE/FIXED: PASS
- P9-G07 anti-duplication + GLOBAL ownership: PASS
- P9-G08 lease lifecycle + expiry: PASS
- P9-G09 NONE/MAINTAIN_TARGET/CONTINUOUS: PASS
- P9-G10 audit append-only/state guards: PASS
- P9-G11 CIA gateway/auth/limits: PASS
- P9-G12 Phase 10 read contracts: PASS
- P9-G13 frontend/responsive/no native dialogs: PASS
- P9-G14 performance + concurrency/idempotency: PASS
- P9-G15 rollback-only E2E + zero residue: PASS
- P9-G16 Call Center/Email compatibility + replayability: PASS
- P9-G17 PR + CI + staging smoke: PASS
- P9-G18 roadmap + final checkpoint + `aos_memory`: PASS al fusionar el cierre y sincronizar memoria.

## Veredicto

**FASE 9 — ASSIGNMENT ENGINE = `100_COMPLETE`**

**FASE 10 — ADVISOR CONTROL CENTER = `READY`**
