# ASCENDA OS — FASE 9
## Assignment Engine — Product/Impact Contract

**Estado:** IN_PROGRESS  
**Entrada certificada:** Fase 8 `100_COMPLETE`  
**Baseline staging:** `5fecc6d9a70f61ba0b437db0c00f2a97c44f15fb`  
**Fecha:** 2026-08-13 (America/Lima)

## 1. Objetivo

Construir el motor transaccional de distribución y ownership temporal que consume **exclusivamente** el conjunto autoritativo de Fase 8:

`aos_cia_activation_available_keys_v1(activation_id)`

Fase 9 no redefine Audience, membership, eligibility ni availability. Tampoco modifica la cola Call Center V2.

Cadena canónica:

`Audience → Activation → Context/Availability → available_keys → Assignment Plan → Assignment Lease → Phase 10 read models`

## 2. No objetivos

- no modificar `aos_siguiente_lead` ni `aos_siguiente_lead_v2`;
- no reemplazar `aos_cola_config` ni `aos_leads_en_curso`;
- no entregar todavía automáticamente asignaciones al panel del asesor;
- no construir Advisor Control Center (Fase 10);
- no construir Advisor Work Views (Fase 12);
- no ejecutar Email/SMS/WhatsApp;
- no asignar mediante IA/affinity;
- no hardcodear nombres de asesores.

## 3. Identidad de target

Todo ownership usa `aos_usuarios.id` UUID.

Un target V1 debe:
- existir en `aos_usuarios`;
- estar `activo=true`;
- tener `rol='asesor'`.

Nombre, código, área, sede y paneles son metadata de presentación; nunca clave de ownership.

## 4. Modelo lógico

### Assignment Plan

Configura una distribución para una Activation.

Campos conceptuales:
- `id` UUID;
- `activation_id` UUID;
- `strategy`: `ONE | EQUAL | PERCENTAGE | FIXED`;
- `ownership_scope`: `ACTIVATION | GLOBAL`;
- `source_limit` nullable;
- `lease_minutes`;
- `must_start_minutes`;
- `topup_policy`: `NONE | MAINTAIN_TARGET | CONTINUOUS`;
- `topup_target_per_advisor` nullable;
- `allow_reassign_released`;
- `allow_reassign_expired`;
- `state`: `DRAFT | ACTIVE | PAUSED | CLOSED | CANCELLED`;
- actor/timestamps/idempotency metadata.

La configuración queda inmutable tras `ACTIVE`.

### Assignment Targets

Por plan:
- `advisor_user_id`;
- `priority`;
- `weight_percent` para PERCENTAGE;
- `fixed_quantity` para FIXED;
- `capacity_limit` nullable;
- `enabled`.

### Assignment Lease

Una fila por contacto asignado:
- `assignment_id`;
- `plan_id`;
- `activation_id`;
- `contact_key`;
- `advisor_user_id`;
- `state`;
- `assigned_at`;
- `must_start_before`;
- `expires_at`;
- `started_at`;
- `completed_at`;
- `released_at`;
- `expired_at`;
- `terminal_reason`;
- metadata/audit timestamps.

Lifecycle:

`RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`

`COMPLETED` nunca vuelve al pool de esa Activation.
`RELEASED/EXPIRED` pueden volver al pool únicamente según política del plan.

## 5. Estrategias V1

### ONE
Exactamente un target. Recibe todo el lote hasta `source_limit`/capacidad.

### EQUAL
Reparto entero equitativo. El residuo por división se asigna determinísticamente por `priority`, luego UUID para desempate.

### PERCENTAGE
Los pesos deben sumar 100. Se calcula `floor(total * pct / 100)` y el residuo de redondeo se asigna determinísticamente por prioridad.

### FIXED
Cada target recibe `fixed_quantity`. Si `source_limit` es menor, se aplica por prioridad. No se inventa remainder adicional fuera de las cantidades fijas.

## 6. Top-up

### NONE
Solo la activación inicial del plan distribuye.

### MAINTAIN_TARGET
Cada ejecución de top-up intenta llevar a cada target hasta `topup_target_per_advisor` leases activos (`ASSIGNED|IN_PROGRESS`), respetando source availability, ownership y capacity.

### CONTINUOUS
Cada ejecución de top-up distribuye todos los candidatos actualmente disponibles, respetando la estrategia y capacidades.

Fase 9 implementa top-up como operación idempotente invocable; no crea scheduler todavía.

## 7. Candidate Set

El motor interno obtiene candidatos desde Fase 8 y excluye:
- contactos ya `COMPLETED` en la misma Activation;
- leases activos de la misma Activation;
- `RELEASED` si el plan no permite re-asignación;
- `EXPIRED` si el plan no permite re-asignación;
- ownership activo externo cuando `ownership_scope='GLOBAL'`;
- targets sin capacidad restante.

No se construye un segundo resolver de eligibility/availability.

## 8. Anti-duplicación / concurrency

- máximo un lease activo por `(activation_id, contact_key)`;
- con `GLOBAL`, ningún contacto puede tener ownership activo simultáneo en otra Activation;
- ejecución del plan serializada con advisory transaction lock por `plan_id`;
- `idempotency_key` evita aplicar dos veces la misma operación;
- toda inserción de leases se hace en una transacción.

## 9. Lease expiry / reconciliation

`must_start_before` evita que un contacto quede atrapado sin iniciar.
`expires_at` limita el lease total.

Reconcile V1:
- ASSIGNED vencido por `must_start_before` → EXPIRED;
- ASSIGNED/IN_PROGRESS vencido por `expires_at` → EXPIRED;
- operación idempotente, invocable antes de summary/top-up.

No habrá worker/scheduler persistente en Fase 9; Fase 10/18 podrá decidir automatización durable si los benchmarks lo requieren.

## 10. Audit

- eventos append-only para CREATE_PLAN, ACTIVATE_PLAN, PAUSE_PLAN, RESUME_PLAN, CLOSE_PLAN, CANCEL_PLAN, ASSIGN, START, COMPLETE, RELEASE, EXPIRE y TOPUP;
- state guards DB validan transiciones;
- navegador no escribe tablas directamente.

## 11. Seguridad

- RLS deny-by-default en todos los nuevos objetos persistentes;
- browser mutators requieren CIA admin token;
- direct anon/authenticated reads = 0;
- frontend nunca recibe una función de arbitrary assignment write;
- `available_keys` permanece contrato server-side.

## 12. Handoff a Fase 10

Fase 9 debe exponer read contracts estables para:
- plan summary;
- carga activa por advisor;
- assigned / in_progress / completed / released / expired;
- candidate remaining;
- source available now;
- plan depletion;
- lease aging / deadlines.

Fase 10 consume estos read models y no reconstruye ownership desde tablas source.

## 13. Impact Report

**Riesgo global:** HIGH.

Impacta:
- nuevas tablas CIA de planes/targets/leases/eventos;
- nuevos RPCs SECURITY DEFINER con CIA token;
- nueva UI admin de Distribución;
- lectura de `aos_usuarios`;
- lectura exclusiva de `aos_cia_activation_available_keys_v1` como fuente de candidatos.

No impacta:
- source tables pacientes/leads/llamadas/agenda/ventas;
- `aos_siguiente_lead*`;
- Email legacy;
- auth/RLS existentes fuera de objetos Phase 9;
- producción operativa Call Center.

### Rollback

- deshabilitar/ocultar módulo Phase 9;
- pausar/cerrar planes Phase 9;
- nuevos objetos pueden permanecer inactivos;
- ningún rollback requiere reconstruir source data;
- no se elimina/modifica data operativa legacy.

## 14. Gates de certificación

- P9-G01 baseline + continuidad F8: PENDING
- P9-G02 Impact Report pre-DDL: PASS
- P9-G03 schema + RLS deny-by-default: PENDING
- P9-G04 plan/target validation + UUID ownership: PENDING
- P9-G05 candidate set = Phase 8 available_keys: PENDING
- P9-G06 strategies ONE/EQUAL/PERCENTAGE/FIXED: PENDING
- P9-G07 anti-duplication + GLOBAL ownership: PENDING
- P9-G08 lease lifecycle + expiry: PENDING
- P9-G09 top-up NONE/MAINTAIN_TARGET/CONTINUOUS: PENDING
- P9-G10 audit append-only/state guards: PENDING
- P9-G11 CIA gateway/auth/limits: PENDING
- P9-G12 Phase 10 read contracts: PENDING
- P9-G13 frontend Distribución/responsive/no native dialogs: PENDING
- P9-G14 performance + concurrency/idempotency: PENDING
- P9-G15 rollback-only E2E + zero residue: PENDING
- P9-G16 Call Center/Email compatibility + replayability: PENDING
- P9-G17 PR + CI + staging smoke: PENDING
- P9-G18 roadmap + Validation Report + `aos_memory`: PENDING

Fase 9 solo será `100_COMPLETE` con P9-G01…P9-G18 PASS.
