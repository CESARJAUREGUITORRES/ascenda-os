# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 0 — BASELINE & CONTRACTS

**Estado:** `100_COMPLETE` — 100% cerrado y verificado  
**Fecha:** 2026-08-13  
**Baseline GitHub:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Rama:** `audit/commercial-intelligence-phase0-20260813`  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Documento maestro:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Regla:** esta fase NO modificó runtime, DDL, RLS, datos operativos ni colas productivas.

---

# 1. OBJETIVO

Cerrar todos los contratos necesarios para empezar Fase 1 sin ambigüedad:

1. fuentes de datos y sus claves;
2. semántica de facts;
3. enums/normalización;
4. permisos y ownership;
5. mapa de integración UI → RPC/API → tablas;
6. baseline de rendimiento;
7. contrato frontend;
8. feature flags / rollout / rollback;
9. continuidad persistente de fase.

La salida de Fase 0 permite que otro chat/agente continúe el proyecto leyendo GitHub + `aos_memory`, sin reconstruir decisiones históricas.

---

# 2. GATES DE FASE 0

| Gate | Criterio | Evidencia requerida | Estado |
|---|---|---|---|
| P0-G01 | Baseline y fuentes canónicas fijadas | Git SHA + Supabase project + docs canónicos | PASS |
| P0-G02 | Inventario vivo de datos y calidad | counts, claves, nulls, duplicados y estados | PASS |
| P0-G03 | Mapa productivo de integración | `app/public` + RPC/endpoints/fuentes afectadas | PASS |
| P0-G04 | Fact Registry V1 implementable | catálogo tipado con semántica/null/freshness | PASS |
| P0-G05 | Estados y normalización | enums observados + reglas derived/canonical | PASS |
| P0-G06 | Permisos y ownership | matriz ADMIN/ASESOR y gap actual | PASS |
| P0-G07 | Performance baseline | EXPLAIN ANALYZE de consultas representativas | PASS |
| P0-G08 | Frontend contract | design tokens + estados + navegación + modales | PASS |
| P0-G09 | Rollout/continuidad | flags, phase gate, rollback y `aos_memory` | PASS |

**Cierre:** P0-G01…P0-G09 verificados. Checkpoint persistido en `aos_memory` el 2026-08-13. Fase 1 autorizada como `READY`.

---

# 3. FUENTES PRODUCTIVAS V1

## 3.1 Núcleo de identidad/comercial

| Fuente | Uso V1 | Clave transversal | Mutación por Audience OS |
|---|---|---|---|
| `aos_pacientes` | identidad/CRM/demografía/tier legacy | `numero_limpio` | NO |
| `aos_leads` | interés/campaña/origen | `numero_limpio` | NO |
| `aos_llamadas` | actividad/tipificación/intentos | `numero_limpio` | NO |
| `aos_agenda_citas` | asistencia/no-show/próxima cita | `numero_limpio` | NO |
| `aos_ventas` | compra/producto/servicio/revenue | `numero_limpio` | NO |
| `aos_seguimientos` | seguimiento/fecha/asesor | `NUMERO` normalizado read-only | NO |
| `aos_base_etiquetas` | etiqueta/campaña histórica | `numero` | NO |

## 3.2 Comunicación

| Fuente | Uso |
|---|---|
| `aos_email_flujo_ejecuciones` | ejecuciones de flujos email; identidad parcial |
| `aos_email_envios` | envíos de campañas/flujos |
| `aos_email_eventos` | eventos proveedor |
| `aos_emails_enviados` | historial general por email |
| `aos_email_cadencia` | cadencia actual |
| `aos_whatsapp_mensajes` | infraestructura WA; actualmente sin histórico útil para outbound completo |
| futuras tablas SMS | no existen en baseline; se diseñarán sobre contratos comunes |

## 3.3 Usuarios/agentes

- `aos_usuarios`
- `aos_agentes`
- `aos_agente_tareas`
- `aos_agente_acciones`
- `aos_kronia_conversaciones`
- `aos_kronia_acciones`
- `aos_notificaciones`
- `aos_mensajes`

---

# 4. SNAPSHOT DE DATOS — 2026-08-13

| Tabla | Filas | contactos/claves distintas | sin clave |
|---|---:|---:|---:|
| `aos_pacientes` | 7,660 | 7,155 | 58 |
| `aos_leads` | 5,403 | 5,088 | 0 |
| `aos_llamadas` | 34,188 | 5,917 | 0 |
| `aos_agenda_citas` | 3,034 | 1,182 | 69 |
| `aos_ventas` | 1,275 | 299 | 1 |
| `aos_seguimientos` | 524 | 457 normalizados | 0 |
| `aos_base_etiquetas` | 6,547 | 6,547 | 0 |
| `aos_email_flujo_ejecuciones` | 13,952 | 297 con `numero_limpio` | 13,654 sin `numero_limpio` |
| `aos_emails_enviados` | 1,925 | 381 emails | 56 sin email destino |

Universo de las cinco fuentes principales (`pacientes/leads/llamadas/agenda/ventas`): **11,571 números distintos**.

La variación de `aos_agenda_citas` respecto a lecturas anteriores prueba que los datos están vivos; las audiencias dinámicas no pueden materializarse manualmente como fuente de verdad.

---

# 5. CALIDAD / IDENTIDAD

Hechos ya validados:

- `aos_pacientes` contiene duplicidad por `numero_limpio`;
- existen filas `FUSIONADO` que no deben aparecer como contactos independientes;
- existen conflictos donde varios pacientes no fusionados comparten número;
- `numero_limpio` permanece como contrato V1, pero el diseño nuevo debe aceptar evolución a `contact_id + aliases`;
- `aos_seguimientos.NUMERO` requiere normalización read-only;
- email histórico no tiene una identidad de contacto uniforme: no se puede inferir `never_emailed` desde una sola tabla.

**Regla V1:** ausencia de evidencia puede producir `UNKNOWN`; nunca convertir automáticamente `UNKNOWN` en `NO`.

---

# 6. ESTADOS OBSERVADOS Y NORMALIZACIÓN

## 6.1 Llamadas

Valores productivos principales:

- `SIN CONTACTO`
- `NO LE INTERESA`
- `CITA CONFIRMADA`
- `SEGUIMIENTO`
- `SACAR DE LA BASE`
- `PROVINCIA`
- `PROVINCIAS`
- `NO CONTESTA`

Fact Registry debe distinguir:

- `latest_status`
- `ever_status`
- `contacted_effectively`
- `never_called`

No usar `estado` bruto como única semántica.

## 6.2 Agenda

- `NO ASISTIO`
- `ASISTIO`
- `CANCELADA`
- `PENDIENTE`
- `EFECTIVA`
- `REAGENDADA`
- `CITA CONFIRMADA`

Se deben separar `latest_appointment_status`, `ever_no_show`, `no_show_count`, `has_future_appointment` y `next_appointment_at`.

## 6.3 Ventas

`aos_ventas.tipo` está estructurado:

- `SERVICIO`: 870
- `PRODUCTO`: 405

Producto y servicio son dimensiones independientes en todos los facts/segmentos.

## 6.4 Paciente

`ESTADO_PACIENTE` observado:

- PROSPECTO
- NUEVO
- FUSIONADO
- ACTIVO
- PACIENTE

`SCORE_ESTADO` mezcla categorías y valores legacy (`LEAD`, `CONTACTADO`, `PACIENTE`, `ACTIVO`, `RECOMPRA`, `40`, `60`, `80`, null). **No exponer crudo como score canónico.**

`etiqueta_vip` actual: `NORMAL`, `PREMIUM`, `DIAMANTE`; será legacy hasta que Segmentation Engine calcule tiers versionados.

## 6.5 Seguimientos

- VENCIDO
- PENDIENTE
- COMPLETADO

---

# 7. PERMISOS — BASELINE REAL

Usuarios activos observados:

- 1 `admin`;
- 6 `asesor`;
- 3 `doctora`.

La autorización funcional actual se apoya principalmente en `paneles_acceso`.

`aos_usuarios.permisos` existe como JSONB, pero **ningún usuario activo tiene actualmente claves configuradas**.

Esto permite usar `permisos` como espacio de evolución, pero no se asumirá que ya protege acciones.

## 7.1 Permisos objetivo

ADMIN / rol delegado según autorización:

- `audiences.view`
- `audiences.manage`
- `audiences.assign`
- `audiences.activate`
- `audiences.approve`
- `audiences.audit`
- `audiences.segment.manage`
- `audiences.intelligence.manage`

ASESOR normal:

- `audiences.consume_own`
- `audiences.request_change`
- `audiences.workview.manage_own`

Un asesor NO puede:

- crear/modificar audiencia global;
- autoasignarse nuevos contactos;
- reasignar contactos de terceros;
- aprobar su propia solicitud;
- cambiar políticas de tiers/asignación.

## 7.2 Estrategia de autorización

No confiar únicamente en UI ni en `rol` enviado por browser.

Backend/RPC futuro debe resolver identidad autenticada + permisos verificables. Hasta esa fase, todo objeto nuevo permanece detrás de feature flags y no expone escritura.

---

# 8. MAPA DE INTEGRACIÓN PRODUCTIVA

Fuente frontend real: `app/public/`.

| Módulo | Archivo productivo | Función en arquitectura futura |
|---|---|---|
| Shell | `app/public/app.html` | registrar nuevo panel ADMIN y navegación |
| Admin Calls | `app/public/admin-calls.html` | consumir audiencias en contexto CALL; gestionar activaciones/asignaciones contextualizadas |
| Advisor Calls | `app/public/calls.js` + pantalla asociada | consumir únicamente Work Queue autorizada |
| Admin Email | `app/public/admin-email.html` | seleccionar audiencia/snapshot en contexto EMAIL |
| Admin Marketing | `app/public/admin-marketing.html` | performance existente; enlazar al centro de control comercial |
| Agents | `app/public/agents.html` | observabilidad de agentes, no sustituye panel de audiencias |
| Node backend | `app/server.js` | integrations/jobs/actions controladas cuando corresponda |

Contrato Call Center actual relevante:

- `aos_admin_calls_v2` alimenta agregaciones/administración de llamadas;
- `aos_siguiente_lead_v2` es consumida por `app/public/calls.js`;
- `aos_siguiente_lead_v2` envuelve la lógica existente de `aos_siguiente_lead`;
- Fase 11 deberá crear una ruta V3 paralela con fallback a V2; no modificar V2 como primer paso.

---

# 9. PERFORMANCE BASELINE

Mediciones `EXPLAIN (ANALYZE, BUFFERS)` realizadas read-only en producción:

| Caso | Resultado | Tiempo observado |
|---|---|---:|
| universo de contactos 5 fuentes | 11,571 contactos | ~376 ms |
| última llamada por número | 5,917 contactos | ~667 ms |
| audiencia compleja Enzimas + sin venta + sin cita futura + 30d/nunca | 690 contactos resultantes | ~147 ms |

Observaciones:

1. índices existentes en `numero_limpio` ayudan considerablemente;
2. `latest_call` requiere ordenar por `numero_limpio, created_at DESC, fecha DESC, id DESC` y hoy usa incremental sort;
3. no existe todavía un índice compuesto específico para ese acceso;
4. `UPPER(tratamiento) LIKE '%ENZIM%'` hace seq scan en leads; el futuro catálogo/normalización debe reducir filtros textuales difusos;
5. ningún índice se crea en Fase 0; toda optimización se somete a benchmark antes/después y migration versionada.

Presupuesto objetivo inicial del resolver:

- count/preview simple P95 < 1.5 s;
- audiencia compleja P95 < 2.5 s;
- preview máximo inicial 100 contactos;
- browser no debe descargar datasets completos para filtrarlos localmente.

---

# 10. FEATURE FLAGS CONTRACT

Nombres reservados:

- `AOS_CIA_PANEL_ENABLED`
- `AOS_CIA_IDENTITY_ENABLED`
- `AOS_CIA_FACTS_ENABLED`
- `AOS_CIA_AUDIENCE_READ_ENABLED`
- `AOS_CIA_AUDIENCE_WRITE_ENABLED`
- `AOS_CIA_ASSIGNMENT_ENABLED`
- `AOS_CIA_CALL_QUEUE_V3_ENABLED`
- `AOS_CIA_APPROVALS_ENABLED`
- `AOS_CIA_AI_RECOMMENDATIONS_ENABLED`
- `AOS_CIA_AI_EXECUTION_ENABLED`
- `AOS_CIA_EMAIL_ENABLED`
- `AOS_CIA_SMS_ENABLED`
- `AOS_CIA_WHATSAPP_ENABLED`

Los flags se activarán por fase; no es necesario que todos sean variables de entorno a largo plazo, pero el contrato de rollout debe conservar equivalentes funcionales y kill switch.

---

# 11. LOOP OBLIGATORIO DE CADA FASE

1. baseline verificable;
2. alcance y invariantes;
3. Impact Report cuando corresponda;
4. branch aislada;
5. implementación backward-compatible;
6. checks de sintaxis/diff;
7. tests unitarios/contrato;
8. comparación contra datos reales;
9. edge cases;
10. pruebas de roles;
11. responsive/accessibility si hay UI;
12. staging;
13. smoke/E2E;
14. rollback probado;
15. rollout gradual;
16. observación;
17. cierre documentado;
18. actualización `aos_memory` con porcentaje y siguiente fase.

**No se marca 100% porque “se escribió código”; se marca 100% cuando todos los gates de la fase tienen evidencia.**

---

# 12. CHECKPOINT DE CONTINUIDAD

Checkpoint verificado en `aos_memory`:

- `cia_phase0_status = 100_COMPLETE`;
- `cia_phase0_progress = 100`;
- `cia_phase0_gates = P0-G01..P0-G09 PASS`;
- `cia_phase0_branch = audit/commercial-intelligence-phase0-20260813`;
- artefactos y baseline medido registrados;
- `cia_phase1_status = READY`;
- `cia_v3_current_phase = FASE 0 100_COMPLETE / FASE 1 READY`.

---

# 13. IMPACT REPORT DE FASE 0

**Riesgo:** LOW/MEDIUM documental y lectura.  
**Writes productivos:** únicamente checkpoint de continuidad en `aos_memory`, explícitamente solicitado; ningún dato comercial/operativo alterado.  
**DDL:** ninguno.  
**RLS/Auth:** ninguno.  
**Runtime:** ninguno.  
**Rollback:** revertir documentación/checkpoint; producción funcional no cambia.  
**Blast radius:** cero sobre operación clínica/comercial.

---

# 14. ARTEFACTOS CERRADOS

- `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`
- `docs/control/commercial-intelligence/PHASE_00_BASELINE_CONTRACTS.md`
- `docs/control/commercial-intelligence/FACT_REGISTRY_V1.md`
- `docs/control/commercial-intelligence/FRONTEND_CONTRACT_V1.md`
- `docs/control/commercial-intelligence/ROADMAP_STATUS.md`
- `scripts/audit_commercial_intelligence_phase0.sql`
- checkpoint `ASCENDA_CIA_PHASES` / `ASCENDA_CIA_V3` en `aos_memory`

---

# 15. RESULTADO DE FASE

## `FASE 0 = 100% COMPLETE`

No hay gates pendientes.

## Siguiente fase autorizada

`FASE 1 — Identity Resolver = READY`

Objetivo inicial de Fase 1: resolver identidad read-only con `contact_key`, paciente canónico, `FUSIONADO`, conflictos, source flags y preparación para aliases/contact_id; sin reescribir `numero_limpio` ni fusionar datos existentes.
