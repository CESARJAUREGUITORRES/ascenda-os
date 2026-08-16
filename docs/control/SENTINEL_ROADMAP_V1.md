# Sentinel — Roadmap V1

**Estado:** CURRENT / CANONICAL  
**Fecha:** 2026-08-16 (America/Lima)  
**Control Maestro:** `docs/control/SENTINEL_CONTROL_MASTER.md`

---

## Regla de ejecución

Cada fase usa el loop ASCENDA:

`recovery → evidencia → branch → implementación → tests → Zero-Cost gate → preflight/canary si aplica → checkpoint → Notion`

Solo una fase puede estar `SIGUIENTE` o `EN CURSO` al mismo tiempo. Ninguna fase se marca cerrada por intención; solo por evidencia.

---

# FASE 1 — Governance, Privacy & Cost Guardrails

**Objetivo:** establecer límites técnicos, económicos y de privacidad antes de emitir telemetría real.

### Trabajos
- congelar nombre oficial `Sentinel`;
- aprobar arquitectura híbrida;
- definir anti-scope;
- definir Zero-PHI/PII telemetry policy;
- definir sensitive-field denylist y allowlist de atributos;
- definir ambientes (`development`, `zero-cost`, `production`);
- definir cuotas/budget por señal;
- establecer política `no pay-as-you-go automático`;
- definir cuándo Sentry, OTel, Kuma o GlitchTip pueden utilizarse;
- definir rollback/desactivación total de observabilidad;
- crear Control Maestro GitHub + Notion + bases de fases/hallazgos;
- añadir contrato machine-checkable y workflow self-hosted de certificación.

### Gate de salida
- arquitectura y políticas canónicas versionadas;
- costo inicial objetivo documentado;
- no existe telemetría productiva antes de completar privacy gate;
- exact-head F1 CI PASS;
- scope final sin cambios runtime/DB;
- Notion y GitHub reflejan la misma fase activa/cerrada.

---

# FASE 2 — System Registry & Topology Taxonomy

**Objetivo:** construir el mapa verificable de ASCENDA que Sentinel observará.

### Trabajos
- inventariar paneles productivos `app/public/`;
- mapear servidores/runtime Node actuales;
- mapear módulos y capacidades;
- mapear RPC/tablas relevantes por dominio;
- mapear dependencias externas;
- asignar `module/component/capability/dependency`;
- definir criticidad por capacidad;
- diferenciar capability observable vs `UNKNOWN`;
- generar registry canónico machine-readable;
- contratos para evitar nombres libres/inconsistentes.

### Gate de salida
- topología inicial crítica validada contra GitHub/runtime;
- registry versionado;
- ningún nodo crítico se marca HEALTHY sin señal asignada.

---

# FASE 3 — Telemetry Contract & OpenTelemetry Foundation

**Objetivo:** establecer contrato portable antes de profundizar en cualquier proveedor.

### Trabajos
- definir resource attributes canónicos;
- `service.name`, `service.version`, `deployment.environment` y equivalentes Sentinel;
- definir `request_id`, `trace_id` y propagation;
- instrumentación Node mínima compatible con arquitectura CommonJS actual;
- política de sampling;
- diseño del Collector sin obligación de desplegarlo todavía;
- processors previstos: filter/redaction/transform/batch/sampling;
- pruebas para impedir PHI/PII/secrets;
- exporter interface desacoplada.

### Gate de salida
- contrato OTel/Correlation estable;
- fixture local demuestra redaction y tags permitidos;
- runtime no depende de un backend concreto.

---

# FASE 4 — Sentry Error Monitoring Core

**Objetivo:** incorporar detección de errores de alto valor con volumen controlado.

### Trabajos
- crear proyecto Sentry Node;
- configurar privacy/data scrubbing;
- integrar `@sentry/node` en boundary seguro;
- `sendDefaultPii=false`;
- environment/release correctos;
- errores uncaught/unhandled controlados;
- tags solo de taxonomía Sentinel;
- tracing inicialmente OFF o con sampling mínimo aprobado;
- test sintético no sensible;
- kill switch por variable de entorno;
- validar cuota/volumen inicial.

### Gate de salida
- un error sintético aparece con release/environment correctos;
- cero datos sensibles detectados;
- desactivar Sentry no rompe ASCENDA;
- Sentry permanece sensor, no dependencia de Sentinel Core.

---

# FASE 5 — Availability Layer / Uptime Kuma

**Objetivo:** detectar caídas externas que no requieren una excepción interna.

### Trabajos
- identificar endpoints/probes seguros;
- `/health` outer runtime;
- probes selectivos por dependencias;
- diseñar deployment Uptime Kuma;
- verificar costo marginal 24/7 antes de desplegar;
- configurar retries y anti-flapping;
- definir status `UP/DOWN/UNKNOWN` traducible a Sentinel;
- evitar endpoints que expongan métricas sensibles;
- baseline de disponibilidad.

### Gate de salida
- disponibilidad externa puede detectarse independientemente del runtime observado;
- hosting aprobado y documentado o fase queda técnicamente lista sin gasto no autorizado;
- outage sintético produce señal deduplicada.

---

# FASE 6 — Business Health & Silent Failure Invariants

**Objetivo:** detectar fallos donde HTTP/JS parecen sanos pero el negocio está roto.

### Trabajos
- identificar invariantes por dominio;
- freshness de datos;
- cardinalidades mínimas/máximas razonables;
- sincronizaciones estancadas;
- colas/backlogs;
- respuestas vacías anómalas;
- reconciliaciones críticas;
- estados imposibles;
- probes read-only y mínimo privilegio;
- baselines por sede cuando sea seguro;
- suppressions/maintenance windows.

### Gate de salida
- al menos Call Center, Ventas, WhatsApp y Email tienen una regla de silent failure validada;
- una anomalía funcional sintética cambia el nodo correspondiente a DEGRADED/INCIDENT sin depender de Sentry.

---

# FASE 7 — Release, Deploy & Correlation Layer

**Objetivo:** poder responder “qué versión estaba corriendo cuando falló”.

### Trabajos
- release = SHA/versión verificable;
- correlación GitHub commit/PR;
- Railway deployment metadata disponible sin secretos;
- `request_id` extremo a extremo donde aplique;
- `trace_id` y breadcrumbs sanitizados;
- timeline deploy→incident;
- detección de regression window;
- política de suspect change como inferencia, no certeza.

### Gate de salida
- incidente sintético identifica SHA exacto y ambiente;
- rollback target puede determinarse sin adivinanzas.

---

# FASE 8 — Sentinel Incident Engine (`SEN-*`)

**Objetivo:** unificar señales en incidentes interpretables y persistentes.

### Trabajos
- schema versionado de incidentes;
- generador `SEN-YYYY-NNNN`;
- deduplicación/fingerprints;
- severidades P0/P1/P2/P3;
- estados OPEN/ACK/INVESTIGATING/MITIGATED/RESOLVED;
- vínculo a módulos/capacidades;
- evidence references, no payload sensible;
- timeline del incidente;
- reopen rules;
- postmortem fields;
- retención y archival.

### Gate de salida
- señales múltiples pueden converger en un mismo incidente;
- incident ID es estable y consultable;
- replay no duplica incidentes indebidamente.

---

# FASE 9 — Alert Routing, Telegram & Noise Control

**Objetivo:** avisar lo correcto, a la persona correcta, sin fatiga de alertas.

### Trabajos
- Telegram bot/canal owner;
- P0/P1 inmediato;
- P2 agrupado;
- P3 solo panel/log;
- cooldown/dedup;
- flapping suppression;
- recovery notification;
- maintenance window;
- plantilla sanitizada;
- links/IDs a Sentinel/GitHub/Sentry cuando sean accesibles;
- pruebas de rate/noise.

### Gate de salida
- incidentes críticos notifican;
- repetición masiva no genera spam;
- Telegram nunca incluye PHI/PII/secrets.

---

# FASE 10 — Diagnostic Runner

**Objetivo:** automatizar investigación reproducible sin mutar producción.

### Trabajos
- trigger controlado desde `SEN-*`;
- `repository_dispatch`/workflow equivalente solo cuando sea seguro;
- runner self-hosted dedicado/ruteado según estándar;
- checkout SHA afectado;
- contracts/tests del dominio;
- reproducción con fixtures sintéticos;
- diff/recent commits;
- health evidence;
- root-cause hypothesis report;
- timeout/cancel/concurrency;
- cero secretos innecesarios;
- runner no escribe producción.

### Gate de salida
- un incidente sintético dispara diagnóstico y genera evidencia reproducible;
- no existe ruta de mutación productiva desde el job diagnóstico.

---

# FASE 11 — MCP / AI-Assisted Triage

**Objetivo:** permitir que ChatGPT/Codex/agentes investiguen Sentinel con contexto suficiente y mínimo privilegio.

### Trabajos
- definir herramientas read-only;
- acceso a incident metadata;
- acceso controlado a Sentry/MCP cuando el plan/capacidad lo permita;
- acceso GitHub por SHA/PR;
- sanitización previa a LLM;
- prompts/system contract para no inventar causalidad;
- evidence citations;
- confidence labels;
- human-readable diagnosis;
- audit trail de consultas.

### Gate de salida
- agente puede investigar `SEN-*` sin copiar manualmente stack traces sensibles;
- toda conclusión material cita evidencia técnica;
- no se otorgan herramientas de escritura innecesarias.

---

# FASE 12 — Safe Remediation Loop

**Objetivo:** pasar de diagnóstico a propuesta de fix sin permitir auto-deploy inseguro.

### Trabajos
- diagnosis → candidate patch;
- branch aislada;
- tests específicos;
- Zero-Cost CI;
- security gate según riesgo;
- PR automático opcional;
- Impact Report;
- rollback;
- canary;
- aprobación humana obligatoria para producción;
- medir false fixes/reverts;
- kill switch completo.

### Gate de salida
- incidente sintético puede llegar hasta PR validado;
- ninguna ruta puede fusionar/desplegar HIGH/CRITICAL sin gates y autorización;
- rollback probado.

---

# FASE 13 — Sentinel Hub, System Map & Certification

**Objetivo:** entregar el panel interno final dentro de ASCENDA y certificar Sentinel transversalmente.

### Trabajos
- panel `Sentinel` visible solo a owner/admin autorizado;
- System Topology Map;
- drill-down dominio → componente → capability;
- estados HEALTHY/DEGRADED/INCIDENT/CRITICAL/UNKNOWN;
- incident list y `SEN-*`;
- evidencia sanitizada;
- release/commit/deploy;
- último health check;
- impacto y severidad;
- acciones seguras: ver, reconocer, diagnosticar, abrir GitHub;
- nunca exponer secretos/PII/PHI;
- responsive/mobile owner view;
- history/postmortem;
- smoke por módulos críticos;
- resilience test: Sentry down, Kuma down, Collector down, Sentinel Core down;
- portability test hacia backend alternativo/fixture;
- cost audit final;
- seguridad/roles/2FA;
- documentación y Notion final;
- SaaS boundary: cliente no ve stack traces ni infraestructura interna.

### Gate de salida
- panel productivo y protegido;
- puede localizar una falla a nivel de zona/capability, no solo “módulo caído”;
- todos los dominios críticos tienen señal o estado UNKNOWN explícito;
- incident flow detect→notify→diagnose→PR está certificado;
- costo y cuotas dentro del presupuesto aprobado;
- GitHub/runtime/Notion alineados;
- Sentinel puede declararse `100_COMPLETE` para la baseline.

---

## Índice ejecutivo de fases

| # | Fase | Resultado principal |
|---|---|---|
| 1 | Governance, Privacy & Cost | límites seguros y económicos |
| 2 | Registry & Topology | mapa verificable de ASCENDA |
| 3 | OTel Foundation | contrato portable |
| 4 | Sentry Core | errores y debugging |
| 5 | Availability | caídas externas |
| 6 | Business Health | fallos silenciosos |
| 7 | Correlation | error→release→deploy |
| 8 | Incident Engine | IDs `SEN-*` |
| 9 | Alert Routing | Telegram sin ruido |
| 10 | Diagnostic Runner | investigación automatizada |
| 11 | MCP/AI Triage | análisis asistido |
| 12 | Safe Remediation | fix→PR con gates |
| 13 | Sentinel Hub | mapa interno + certificación 100% |

## Estado actual

- Fase 1: `CERRADA / 100_COMPLETE`.
- Fase 2: `CERRADA / 100_COMPLETE`.
- Fase 3: `CERRADA / 100_COMPLETE`.
- Fase 4: `CERRADA / 100_COMPLETE / 18/18 PASS`.
- Fase 5: `EN CURSO — Availability Foundation`.
- Fases 6–13: `PENDIENTE`.
- F5 no autoriza gasto automático ni despliegue 24/7 hasta resolver `F5-HOST-01`; la foundation puede certificarse íntegramente en CI Zero-Cost.
