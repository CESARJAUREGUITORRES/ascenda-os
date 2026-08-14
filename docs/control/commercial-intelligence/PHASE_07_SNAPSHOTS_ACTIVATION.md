# ASCENDA OS — FASE 7
## Snapshots & Activation Core

**Estado:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Baseline staging:** `d17eaa8cabfeae88c9442246f542b2e18b2a1691`  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Rama:** `feature/cia-phase7-snapshots-activation`

---

# 1. OBJETIVO

Construir la capa que convierte una definición persistente de audiencia en un uso comercial trazable, manteniendo separadas cuatro nociones:

1. **Audience Definition** — regla dinámica versionada.
2. **Snapshot** — membresía exacta congelada en un instante.
3. **Activation** — registro de que una versión de audiencia será utilizada para un propósito/contexto.
4. **Assignment** — distribución/ownership por asesor; permanece fuera de Fase 7.

Fase 7 no ejecuta campañas, no envía mensajes, no asigna leads y no reemplaza Call Center.

---

# 2. BASELINE LIVE

- Staging canónico: `d17eaa8cabfeae88c9442246f542b2e18b2a1691`.
- Fase 6: `100_COMPLETE`.
- Contactos lógicos observados al inicio: **11,491**.
- `aos_audiencias`: 0 filas al iniciar Fase 7.
- No existen objetos `aos_audiencia_*activacion*` ni snapshots específicos del Audience OS.
- Existe `aos_snapshot_global`, pero es un snapshot analítico legacy (`id`, `datos`, `generado_at`, `generado_por`) y **no debe reutilizarse ni modificarse**.
- Resolver disponible: `aos_cia_audience_resolve_node_v2` + Filter DSL V1 certificado.
- Biblioteca Fase 6 disponible: `aos_audiencias` + `aos_audiencia_versiones` + audit.

---

# 3. DECISIONES DE ARQUITECTURA

## 3.1 Snapshot como objeto propio

No se reutiliza `aos_audiencia_versiones` como snapshot. Una misma versión dinámica puede congelarse varias veces y producir membresías distintas por evolución de datos.

Se propone:

- `aos_audiencia_snapshots`
- `aos_audiencia_snapshot_miembros`

Cada snapshot queda ligado a una versión exacta de audiencia.

## 3.2 Snapshot sellado e inmutable

Construcción transaccional:

`resolve keys → insert BUILDING header → insert members → verify count/hash → seal READY`

Una vez `READY`:

- no nuevos miembros;
- no UPDATE;
- no DELETE;
- hash SHA-256 de miembros ordenados;
- conteo físico validado contra header.

La reproducibilidad de Fase 7 significa: **membresía exacta + versión exacta + filter hash + membership hash**.

Los hechos comerciales mostrados al revisar un snapshot pueden seguir siendo LIVE; la UI debe distinguir **frozen membership** de **live facts**. No se duplicará un mega `facts_snapshot` de todos los dominios en esta fase.

## 3.3 Activation

Objeto propuesto:

`aos_audiencia_activaciones`

Campos fundamentales:

- audience/version;
- optional snapshot;
- nombre;
- purpose;
- channel/context;
- mode;
- state;
- baseline count/time;
- created/updated by;
- start/end timestamps;
- metadata controlada.

### Modes

**BATCH**
- crea un snapshot al crear la activación;
- membership queda congelada;
- requiere `snapshot_id`.

**DYNAMIC**
- fija la versión de reglas;
- membership se resuelve live al consultar/usar;
- `snapshot_id = null`.

## 3.4 Estados

Estados:

- `DRAFT`
- `ACTIVE`
- `PAUSED`
- `COMPLETED`
- `CANCELLED`

Transiciones permitidas:

- DRAFT → ACTIVE | CANCELLED
- ACTIVE → PAUSED | COMPLETED | CANCELLED
- PAUSED → ACTIVE | COMPLETED | CANCELLED
- COMPLETED/CANCELLED → terminal

No existe hard delete funcional.

## 3.5 Historial de uso

Objeto:

`aos_audiencia_activacion_eventos`

Audit append-only automático para CREATE / START / PAUSE / RESUME / COMPLETE / CANCEL.

---

# 4. FRONTERAS DE FASE

## Incluye

- snapshots inmutables;
- snapshot membership;
- checksum/integridad;
- activaciones BATCH/DYNAMIC;
- lifecycle de activación;
- historial de estados;
- list/get/preview;
- panel ADMIN de Activaciones;
- gateway CIA ADMIN;
- auditoría y RLS.

## No incluye

- channel eligibility real;
- suppressions/consentimientos;
- `eligible` / `available now`;
- envío Email/SMS/WhatsApp;
- assignment/distribution;
- leases/top-up;
- Advisor Work Views;
- approvals;
- recomendaciones IA;
- atribución de resultados;
- cambios a `aos_siguiente_lead`.

La presencia de `channel` en Fase 7 es **contexto declarado**, no autorización ni ejecución del canal.

---

# 5. IMPACT REPORT PRE-DDL

## Clasificación

**HIGH** por nueva persistencia comercial transversal.  
**CRITICAL security surface** únicamente por creación de RLS/GRANT/SECURITY DEFINER; mitigado con diseño deny-by-default.

## Tablas nuevas

1. `aos_audiencia_snapshots`
2. `aos_audiencia_snapshot_miembros`
3. `aos_audiencia_activaciones`
4. `aos_audiencia_activacion_eventos`

## Objetos existentes tocados

- `aos_audiencia_versiones`: únicamente constraint UNIQUE adicional para FK compuesta segura.
- `aos_cia_admin_gateway_v1`: extensión additive de acciones.
- `admin-audiencias.html`: desbloqueo/navegación a Activaciones.

## Objetos explícitamente NO tocados

- `aos_pacientes`
- `aos_leads`
- `aos_llamadas`
- `aos_agenda_citas`
- `aos_ventas`
- `aos_seguimientos`
- `aos_email_audiencias`
- `aos_email_campanias`
- `aos_cola_config`
- `aos_siguiente_lead`
- `calls.js`

## Riesgos y mitigaciones

### R1 — confundir snapshot con audiencia
Mitigación: tablas separadas y semántica explícita en UI/API.

### R2 — modificar miembros después del congelamiento
Mitigación: BUILDING transaccional + seal READY + triggers de inmutabilidad.

### R3 — header y miembros inconsistentes
Mitigación: count/hash verificados por trigger al sellar.

### R4 — activation apuntando a versión ajena
Mitigación: FK compuesta audience/version + validación RPC.

### R5 — BATCH sin snapshot o DYNAMIC con snapshot
Mitigación: CHECK constraint.

### R6 — saltos ilegales de estado
Mitigación: trigger de transición + RPC action-based.

### R7 — perder historial
Mitigación: eventos automáticos append-only; no hard delete.

### R8 — creer que `channel` habilita envío
Mitigación: UI y contrato marcan `context_only=true`; execution/eligibility queda para Fase 8+.

### R9 — snapshot masivo degrada producción
Mitigación: resolver set-based ya certificado; máximo técnico de 100,000 miembros; medición real antes de cierre.

### R10 — drift Git/Supabase
Mitigación: SQL versionado antes del DDL y filenames reconciliados con `schema_migrations` antes del PR.

---

# 6. SEGURIDAD

- RLS enabled en las cuatro tablas.
- 0 policies permisivas para anon/authenticated.
- 0 acceso directo de browser a tablas.
- service_role: SELECT directo solamente.
- mutation RPCs internas: service_role/postgres únicamente.
- única superficie browser: `aos_cia_admin_gateway_v1` con sesión CIA ADMIN.
- payloads y paginación limitados.
- metadata JSONB limitada.
- snapshot/event audit inmutables.

---

# 7. CONTRATOS DE UI

Nuevo panel **Activaciones** dentro del ecosistema Bases & Audiencias:

- lista de activaciones;
- crear desde una audiencia activa;
- escoger versión;
- nombre/propósito/contexto;
- BATCH vs DYNAMIC;
- iniciar ahora o DRAFT;
- ver conteo baseline;
- ver snapshot hash/member count en BATCH;
- preview paginado;
- historial de estados;
- acciones de transición válidas;
- aviso explícito: Fase 7 no ejecuta canal ni asigna asesores.

No usar `alert`, `confirm` ni `prompt`.

---

# 8. GATES DE CERTIFICACIÓN

- P7-G01 baseline Git/Supabase = PASS
- P7-G02 Impact Report pre-DDL = PASS
- P7-G03 schema/FKs/checks = PENDING
- P7-G04 snapshot build/seal = PENDING
- P7-G05 snapshot immutability/hash = PENDING
- P7-G06 activation BATCH = PENDING
- P7-G07 activation DYNAMIC = PENDING
- P7-G08 state machine/history = PENDING
- P7-G09 list/get/preview = PENDING
- P7-G10 security/RLS/GRANT = PENDING
- P7-G11 gateway authorization = PENDING
- P7-G12 frontend contract/responsive = PENDING
- P7-G13 performance = PENDING
- P7-G14 Call Center/Email compatibility = PENDING
- P7-G15 QA rollback/no residue = PENDING
- P7-G16 replayability/diff/CI/PR = PENDING
- P7-G17 staging post-merge = PENDING
- P7-G18 roadmap + `aos_memory` checkpoint = PENDING

Fase 7 solo puede pasar a `100_COMPLETE` cuando P7-G01…P7-G18 estén PASS.

---

# 9. ROLLBACK

Fase 7 es aditiva. Antes de uso real, rollback funcional consiste en:

- retirar navegación/UI de Activaciones;
- retirar acciones Phase 7 del gateway;
- mantener objetos físicos sin consumo si fuese necesario.

No se contempla DROP destructivo de snapshots/activaciones con datos reales como rollback ordinario.

---

# 10. HABILITACIÓN DE FASE 8

Fase 8 podrá iniciar únicamente cuando Fase 7 certifique:

- definición dinámica ≠ snapshot;
- snapshot inmutable reproducible;
- activation BATCH/DYNAMIC trazable;
- state machine + historial confiables;
- cero regresión operativa;
- continuidad Git + `aos_memory` sincronizada.
