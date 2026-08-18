# Sentinel — Roadmap V1

**Estado:** `CERRADA / 100_COMPLETE / CANONICAL BASELINE`  
**Fecha:** 2026-08-16/17 (America/Lima)  
**Control Maestro:** `docs/control/SENTINEL_CONTROL_MASTER.md`  
**Terminal F13:** `docs/control/SENTINEL_F13_FINAL_CERTIFICATE_20260817.md`

---

## Regla de ejecución

Cada fase usa el loop ASCENDA:

`recovery → evidencia → branch → implementación → tests → Zero-Cost gate → preflight/canary si aplica → checkpoint → Notion`

Ninguna fase se marca cerrada por intención; solo por evidencia. La baseline V1 ya no tiene una fase `SIGUIENTE` o `EN CURSO`: las trece fases están cerradas. Cualquier ampliación futura debe entrar como mejora/versionado posterior y no reescribir retrospectivamente la evidencia V1.

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
- inventar paneles productivos `app/public/`;
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

# FASE 5 — Availability Layer / Hybrid Observer

**Objetivo:** detectar caídas externas que no requieren una excepción interna.

### Trabajos
- identificar endpoints/probes seguros;
- `/health` outer runtime;
- probes selectivos por dependencias;
- cobertura cloud continua sin costo incremental;
- Uptime Kuma local/intermitente en CREACTIVE;
- persistencia y reconciliación de coverage gaps;
- configurar retries y anti-flapping;
- definir status `UP/DOWN/UNKNOWN` traducible a Sentinel;
- evitar endpoints que expongan métricas sensibles;
- baseline de disponibilidad.

### Gate de salida
- disponibilidad externa puede detectarse independientemente del runtime observado;
- cobertura cloud continua verificada sin gasto incremental;
- observador local reiniciable/persistente y su ausencia se traduce a `UNKNOWN`, no false green;
- outage/recovery sintético produce estados deterministas y deduplicables.

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

# FASE 9 — Alert Routing, Owner Notifications & Noise Control

**Objetivo:** avisar lo correcto al owner/admin dentro de ASCENDA sin fatiga de alertas ni exposición sensible.

### Trabajos
- transporte owner canónico `ascenda-in-app`;
- Telegram como adapter externo opcional `F9-T`;
- P0/P1 inmediato;
- P2 agrupado/durable;
- P3 solo panel/log;
- cooldown/dedup ACK-based;
- flapping suppression;
- recovery notification;
- maintenance window + P0 bypass;
- UI sanitizada sobre el shell ASCENDA;
- Auth V3 + `PASSWORD_2FA` + jerarquía owner/admin;
- read receipts independientes de delivery ACK;
- kill switch service-only;
- F9 fail-open respecto de F8;
- pruebas de rate/noise/rollback.

### Gate de salida
- incidentes críticos notifican por el canal owner canónico;
- replay y repetición masiva no generan spam;
- recovery se emite una sola vez cuando corresponde;
- deshabilitar F9 no rompe F8;
- canal owner nunca incluye PHI/PII/secrets;
- producción, CI, deployment y shell in-app certificados.

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

| # | Fase | Resultado principal | Estado |
|---|---|---|---|
| 1 | Governance, Privacy & Cost | límites seguros y económicos | `100_COMPLETE` |
| 2 | Registry & Topology | mapa verificable de ASCENDA | `100_COMPLETE` |
| 3 | OTel Foundation | contrato portable | `100_COMPLETE` |
| 4 | Sentry Core | errores y debugging | `100_COMPLETE` |
| 5 | Availability | caídas externas | `100_COMPLETE` |
| 6 | Business Health | fallos silenciosos | `100_COMPLETE` |
| 7 | Correlation | error→release→deploy | `100_COMPLETE` |
| 8 | Incident Engine | IDs `SEN-*` persistentes | `100_COMPLETE` |
| 9 | Alert Routing | owner in-app sin ruido; Telegram opcional | `100_COMPLETE` |
| 10 | Diagnostic Runner | investigación automatizada read-only | `100_COMPLETE` |
| 11 | MCP/AI Triage | análisis asistido | `100_COMPLETE` |
| 12 | Safe Remediation | fix→PR con gates | `100_COMPLETE` |
| 13 | Sentinel Hub | mapa interno + certificación | `100_COMPLETE` |

## Estado terminal

- Fase 1: `CERRADA / 100_COMPLETE`.
- Fase 2: `CERRADA / 100_COMPLETE`.
- Fase 3: `CERRADA / 100_COMPLETE`.
- Fase 4: `CERRADA / 100_COMPLETE / 18/18 PASS`.
- Fase 5: `CERRADA / 100_COMPLETE` — hybrid availability: UptimeRobot Free cloud + Uptime Kuma/CREACTIVE local; G01–G12 PASS.
- Fase 6: `CERRADA / 100_COMPLETE` — cuatro invariantes silent-failure, aggregate-only, Zero-PHI/PII, preflight live y CI cross-platform; PR #206 fusionado y post-merge certificado.
- Fase 7: `CERRADA / 100_COMPLETE` — PR #207 fusionado; correlation envelope vendor-neutral con release/SHA/deployment/request/trace, confidence `EXACT/STRONG/WEAK/UNKNOWN`, causalidad no asumida y rollback target known-good sin ejecución.
- Fase 8: `CERRADA / 100_COMPLETE` — Incident Engine y persistencia productiva certificados; Supabase live `20260817000618 sentinel_f8_incident_engine`; canary `SEN-2026-0001` final `RESOLVED`; PR #208 fusionado.
- Fase 9: `CERRADA / 100_COMPLETE` — F9-A routing/noise + F9-B durable outbox + F9-C `ascenda-in-app`; PR #214; live `20260817174233 sentinel_f9_inapp_owner_alerts`; canaries `SEN-2026-0002`/`0003` final `RESOLVED`. Telegram queda `F9-T DEFERRED / NON-BLOCKING`.
- Fase 10: `CERRADA / 100_COMPLETE` — PR #235; Diagnostic Runner read-only; synthetic `SEN-2099-9001`; affected SHA `EXACT`; replay byte-for-byte; FAST/Linux + Ascenda CI PASS; cero producción writable.
- Fase 11: `CERRADA / 100_COMPLETE` — PR #240; seis tools MCP stdio read-only; evidence refs/confidence obligatorios; causalidad inventada bloqueada; negatives PII PASS; replay y no-write boundary PASS.
- Fase 12: `CERRADA / 100_COMPLETE` — certificado `docs/control/SENTINEL_F12_FINAL_CERTIFICATE_20260817.md`; PR #244 → merge `a82089b3cf40bbc8546b6c98bb8f6b48512933c5`; candidate PR sintético #243 pasó CI y fue `CLOSED / NOT MERGED`; post-merge F12 `32064580020` + Ascenda CI `32064579939` PASS; sin auto-merge/auto-deploy.
- Fase 13: `CERRADA / 100_COMPLETE` — Hub/System Map owner-safe; PR #252 funcional; PR #255 paridad `203504`; PR #254 terminal smoke/current; exact-current run F13 `32082197260` + Ascenda CI `32082197300` PASS; merge técnico `aacd92148a2a15f12bed7d0e014fb7424bc25415`; Railway SUCCESS; production Hub asset/privacy smoke PASS; Supabase read-back `20260817203504 sentinel_f13_owner_hub`. Closeout #263 se rebasa sobre CURRENT S15.1 `043b4e454682e13cc0b84e860b90e0a15e8ed0cc` para compatibilidad final de F9/F13 sin cambios funcionales Sentinel.

## Decisión de baseline

**`SENTINEL BASELINE F1–F13 = 100_COMPLETE`**.

El flujo transversal certificado es:

`detect → SEN-* → owner notification → diagnostic runner → MCP/AI triage → candidate remediation → PR/CI/human gate`

No existe auto-remediation productiva en la baseline. F12 permite candidate fixes bajo límites y gates; HIGH/CRITICAL conserva aprobación humana explícita.

## Deudas y extensiones no bloqueantes

- `F9-T Telegram`: `DEFERRED / NON-BLOCKING`; el canal owner canónico es `ascenda-in-app`.
- La auditoría global de migration-history del repositorio (#238 y sucesores) es una deuda transversal separada. **La paridad específica F13 sí quedó corregida** en PR #255 (`203504` Git = `203504` live); problemas de otros owners no reabren Sentinel F13 salvo evidencia de impacto Sentinel real.
- Cualquier backend nuevo, sensor adicional, panel cliente o remediación más autónoma debe entrar mediante nueva versión/Impact Report; no modifica retrospectivamente el cierre V1.

## Certificados terminales

- F5: `docs/control/SENTINEL_F5_FINAL_CERTIFICATE_20260816.md`.
- F6: `docs/control/SENTINEL_F6_FINAL_CERTIFICATE_20260816.md`.
- F7: `docs/control/SENTINEL_F7_FINAL_CERTIFICATE_20260816.md`.
- F8: `docs/control/SENTINEL_F8_FINAL_CERTIFICATE_20260817.md`.
- F9: `docs/control/SENTINEL_F9_DURABLE_PRODUCTION_CERTIFICATE_20260817.md`.
- F10: `docs/control/SENTINEL_F10_FINAL_CERTIFICATE_20260817.md`.
- F11: `docs/control/SENTINEL_F11_FINAL_CERTIFICATE_20260817.md`.
- F12: `docs/control/SENTINEL_F12_FINAL_CERTIFICATE_20260817.md`.
- F13: `docs/control/SENTINEL_F13_FINAL_CERTIFICATE_20260817.md`.
