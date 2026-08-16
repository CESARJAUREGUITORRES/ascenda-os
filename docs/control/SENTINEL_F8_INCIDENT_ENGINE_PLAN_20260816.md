# Sentinel F8 — Incident Engine (`SEN-*`)

**Estado:** EN CURSO  
**Fecha:** 2026-08-16 (America/Lima)  
**Baseline:** `main@01958565af1a5ffe426ffb0ac9e0588c77341175`  
**Branch:** `feature/sentinel-f8-incident-engine`  
**Riesgo:** HIGH cuando se incorpore persistencia; core inicial = local/in-memory/read-only respecto a producción.

## 1. Objetivo

Unificar señales de error, disponibilidad, salud de negocio, dependencias y cambios en incidentes estables `SEN-*`, sin duplicación por replay y sin mezclar fallas no relacionadas.

F8 es la primera fase donde Sentinel necesita persistencia canónica. Por seguridad, el loop se divide en dos tramos:

1. **Core determinista** — engine + repository interface + fixtures + CI, sin DDL productivo.
2. **Persistence gate** — migración versionada PostgreSQL, RLS/ACL, transacciones, concurrencia y rollback; solo se aplica a producción después de Zero-Cost validation y autorización explícita.

Notion no será el runtime store de incidentes.

## 2. Modelo de identidad

### `event_id`

Idempotency key global del evento normalizado. El mismo `event_id` reinyectado debe ser un no-op y devolver el mismo incidente.

### `signal_fingerprint`

Identifica una señal/patrón concreto, por ejemplo una invariante Business Health o una fuente Availability.

### `incident_fingerprint`

Clave explícita de convergencia de una familia coherente de fallo/impacto. Distintas signal classes pueden converger solo si comparten este fingerprint y el mismo scope:

- environment;
- domain;
- component;
- capability;
- failure_family.

Mismo módulo por sí solo **no** autoriza merge.

### `incident_id`

Formato:

`SEN-YYYY-NNNN`

La secuencia es anual y debe asignarse transaccionalmente por el repository. El cliente nunca inventa el siguiente número.

## 3. Signal classes

- `ERROR`
- `AVAILABILITY`
- `BUSINESS_HEALTH`
- `DEPENDENCY`
- `DEPLOYMENT_CHANGE`
- `SECURITY`
- `USER_REPORTED`

## 4. Severidad

Orden de mayor a menor:

`P0 → P1 → P2 → P3`

Una nueva señal solo puede mantener o escalar automáticamente la severidad del incidente. No existe auto-deescalation en F8.

## 5. Lifecycle

Estados canónicos:

`OPEN → ACK → INVESTIGATING → MITIGATED → RESOLVED`

Transiciones permitidas se validan por contrato. Un cambio hacia atrás no documentado se rechaza.

### Reopen

- ventana baseline: 60 minutos;
- requiere mismo `incident_fingerprint`;
- requiere un `event_id` nuevo;
- si ocurre dentro de la ventana tras `RESOLVED`, reabre el **mismo SEN id** en `OPEN`;
- replay de un evento viejo no reabre;
- fuera de ventana se crea un **nuevo SEN id**.

## 6. Timeline

Eventos técnicos permitidos:

- `INCIDENT_OPENED`
- `SIGNAL_ATTACHED`
- `SEVERITY_ESCALATED`
- `STATUS_CHANGED`
- `INCIDENT_REOPENED`

No se guardan notas libres ni payloads clínicos/comerciales.

## 7. Evidence references

Solo referencias técnicas tipadas:

- `sentinel-signal`
- `sentry-issue`
- `github-commit`
- `github-pr`
- `railway-deployment`
- `uptime-monitor`
- `ci-run`
- `trace`

Cada referencia tiene solo `kind + id`. Query strings, credenciales y raw payloads están prohibidos.

## 8. Correlation handoff F7

F8 puede guardar únicamente los campos F7 sanitizados:

- release;
- commit SHA;
- deployment ID;
- request ID;
- trace ID;
- confidence.

F8 no transforma correlación en causalidad. La causalidad sigue no establecida salvo evidencia posterior independiente.

## 9. Persistence design — NO APLICADO

Contrato: `sentinel/incidents/persistence-design-v1.json`.

Tablas propuestas:

- `aos_sentinel_incidents_v1`
- `aos_sentinel_incident_signals_v1`
- `aos_sentinel_incident_timeline_v1`
- `aos_sentinel_incident_counters_v1`

Reglas críticas futuras:

- partial unique por `(environment, incident_fingerprint)` mientras status != RESOLVED;
- `event_id` PK/unique para replay idempotente;
- counter anual bloqueado transaccionalmente;
- ingest completo en una sola transacción/RPC;
- RLS habilitado;
- anon/authenticated direct access = NONE;
- service role solo server-side;
- security-definer con `search_path` fijo si se utiliza RPC;
- sin columna de raw payload.

**Estado actual:** `DESIGN_ONLY_NOT_APPLIED`.

## 10. Gates F8

| Gate | Criterio | Estado inicial |
|---|---|---|
| F8-G01 Contract | schema/IDs/classes/severity/lifecycle versionados | IMPLEMENTADO |
| F8-G02 Privacy | refs tipadas; raw payload/free text/credentials rechazados | IMPLEMENTADO / CI |
| F8-G03 Stable ID | primera apertura entrega `SEN-YYYY-NNNN` estable | IMPLEMENTADO / CI |
| F8-G04 Replay | mismo event_id no duplica incidente/timeline/signal_count | IMPLEMENTADO / CI |
| F8-G05 Convergence | ERROR/AVAILABILITY/BUSINESS_HEALTH pueden converger con fingerprint explícito | IMPLEMENTADO / CI |
| F8-G06 No over-merge | failure families distintas crean incidentes distintos | IMPLEMENTADO / CI |
| F8-G07 Severity | P2→P1 escala y queda en timeline | IMPLEMENTADO / CI |
| F8-G08 Lifecycle | transiciones válidas; backwards invalidado | IMPLEMENTADO / CI |
| F8-G09 Reopen | dentro 60m mismo ID; fuera 60m nuevo ID | IMPLEMENTADO / CI |
| F8-G10 Cross-platform | Windows FAST + Linux Zero-Cost PASS | PENDIENTE |
| F8-G11 Persistence design | constraints/transacción/RLS/rollback definidos | IMPLEMENTADO |
| F8-G12 Zero-Cost DB | migration local + concurrency + replay + ACL fixtures | PENDIENTE, sin producción |
| F8-G13 Production persistence | migration aplicada y verificada | BLOQUEADA por gate explícito |
| F8-G14 Closure | exact-head + persistence + post-merge + Notion | PENDIENTE |

## 11. Próximo tramo

1. ejecutar core CI en Windows/Linux;
2. corregir cualquier fallo de lifecycle/idempotencia;
3. diseñar migración SQL versionada y rollback sin aplicarlos;
4. probar migración con Supabase local/Zero-Cost;
5. presentar Impact Report del cambio persistente;
6. solicitar gate productivo para aplicar la migración;
7. canary/replay/concurrency/RLS post-aplicación;
8. certificado F8 y merge;
9. Notion F8 cerrada y F9 siguiente.
