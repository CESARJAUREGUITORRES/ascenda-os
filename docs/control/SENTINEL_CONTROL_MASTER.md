# Sentinel — Control Maestro

**Estado:** CURRENT / CANONICAL / DESIGN BASELINE  
**Fecha:** 2026-08-16 (America/Lima)  
**Repositorio:** `CESARJAUREGUITORRES/ascenda-os`  
**Workstream:** `SENTINEL`  
**Rama fundacional:** `docs/sentinel-control-v1`  
**Ámbito:** observabilidad, detección, correlación, triage, incidentes y respuesta segura para ASCENDA OS.

---

## 1. Misión

Sentinel es la capa transversal de observabilidad y respuesta a incidentes de ASCENDA OS. Su función es detectar, localizar, explicar y correlacionar fallas técnicas y operativas antes o durante su impacto, sin convertirse en fuente de verdad de negocio ni introducir dependencia obligatoria de un proveedor externo.

Sentinel observa; los dominios funcionales continúan gobernando sus propios datos y contratos.

## 2. Principios no negociables

1. **GitHub + runtime + schema live siguen siendo la verdad técnica.** Notion es continuidad visual y gestión.
2. **Zero PHI/PII telemetry.** Ninguna historia clínica, nombre de paciente, DNI, teléfono, contenido WhatsApp/email, token, cookie, secreto o payload sensible se envía como telemetría.
3. **Vendor-neutral by design.** Sentinel no depende estructuralmente de Sentry. OpenTelemetry y contratos propios de Sentinel definen la capa portable.
4. **Cost-bounded observability.** Ningún sensor puede generar gasto cloud adicional sin gate económico y autorización expresa según `ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`.
5. **Fail-closed para automatización.** La detección puede ser automática; la mutación de producción nunca lo será por defecto.
6. **No false-green.** Si Sentinel no puede observar una capacidad debe devolver `UNKNOWN`, no `HEALTHY`.
7. **No duplicar fuentes de verdad.** Sentinel guarda evidencia operacional y metadatos de incidentes, no copias de datos clínicos/comerciales.
8. **Toda remediación sigue branch → CI → staging/fixture → PR → canary → autorización → producción cuando corresponda.**

## 3. Decisión de arquitectura: híbrida

### 3.1 Por qué no Sentry-only

Sentry es excelente para excepciones, stack traces, issues agrupados, tracing, releases y debugging, pero no detecta por sí solo todos los fallos funcionales. Un endpoint puede responder HTTP 200 y, aun así, devolver cero leads, una cola vacía o una regla de negocio rota.

Además, el plan Developer es suficiente para una primera capa humana de debugging, pero Sentinel no debe diseñar su panel o incident engine dependiendo de una API/feature que pueda requerir un plan superior.

### 3.2 Por qué no open-source-only desde el día 1

Es técnicamente viable reemplazar Sentry por una combinación self-hosted, pero añade infraestructura, mantenimiento, backups, upgrades y otra superficie de fallo antes de que exista necesidad real. El objetivo inicial es obtener alta señal con costo marginal mínimo.

### 3.3 Estrategia adoptada

- **Sentry Cloud Developer:** sensor especializado de errores/traces de alto valor; no es la base de datos de Sentinel.
- **OpenTelemetry:** contrato portable de telemetría y futura capa de routing/filter/redaction/sampling.
- **UptimeRobot Free:** cobertura cloud continua del endpoint público `/health` para disponibilidad externa sin costo incremental.
- **Uptime Kuma:** observador local/intermitente en CREACTIVE con persistencia, autoarranque Docker y reconciliación de coverage gaps.
- **Sentinel Core:** topología, reglas de negocio, estados, incidentes `SEN-*`, severidad, evidencias y correlación.
- **Supabase:** almacenamiento mínimo de estado/incidentes de Sentinel cuando se aprueben sus objetos versionados.
- **GitHub:** código, releases, commits, PR, CI y evidencia reproducible.
- **Railway:** runtime/deploy actual; se correlaciona, no se reemplaza.
- **Telegram:** canal owner para incidentes relevantes; nunca se usa como fuente canónica.
- **GlitchTip:** ruta de portabilidad/self-hosting compatible con SDK Sentry si en el futuro costo, control o residencia de datos lo justifican.

## 4. Modelo de observación

Sentinel combina cuatro tipos de señal:

1. **Technical Errors** — excepciones, crashes, stack traces, rejects y fallos runtime.
2. **Availability** — HTTP/TCP/health checks y disponibilidad externa.
3. **Business Health** — invariantes funcionales, freshness, cardinalidades esperadas, colas, sincronizaciones y contratos operativos.
4. **Dependencies** — Supabase, Railway, Meta/WhatsApp, Resend/email, IA/providers y otras integraciones.

Ninguna señal individual puede declarar salud global por sí sola.

## 5. Estados canónicos

- `HEALTHY` — evidencia suficiente de operación normal.
- `DEGRADED` — opera parcialmente o fuera de baseline.
- `INCIDENT` — impacto funcional confirmado o altamente probable.
- `CRITICAL` — capacidad crítica caída, seguridad o integridad materialmente afectada.
- `UNKNOWN` — falta telemetría suficiente o existe inconsistencia entre sensores.

## 6. Taxonomía mínima obligatoria

Toda señal/incident debe poder correlacionarse, cuando aplique, con:

- `system=ascenda-os`
- `environment`
- `module`
- `component`
- `capability`
- `dependency`
- `severity`
- `release`
- `commit_sha`
- `deployment_id` cuando esté disponible
- `request_id`
- `trace_id`
- `incident_id`
- `sede` solo si puede representarse sin PII/PHI y aporta diagnóstico

No se usarán identificadores de pacientes/personas como tags de observabilidad.

## 7. Incident ID

Formato canónico inicial:

`SEN-YYYY-NNNN`

Un incidente puede relacionar múltiples eventos y sensores, pero debe representar una causa/impacto coherente. El mismo incidente debe poder enlazar evidencia de Sentinel, Sentry, GitHub, Railway, CI y postmortem sin copiar secretos.

## 8. Mapa inicial de dominios

```text
ASCENDA OS
├── AUTH
│   ├── login
│   ├── session
│   ├── roles
│   └── 2FA
├── SALES
│   ├── ventas
│   ├── metas
│   ├── cartera
│   └── revenue
├── CALL CENTER
│   ├── leads
│   ├── llamadas
│   ├── agenda
│   └── routing
├── WHATSAPP
│   ├── inbound
│   ├── inbox
│   ├── boxes
│   ├── routing
│   ├── human-outbound
│   ├── ai
│   └── receipts
├── EMAIL
│   ├── provider
│   ├── campaigns
│   └── delivery
├── KRONIA
│   ├── router
│   ├── models
│   ├── tools
│   └── actions
├── CLINICAL
├── INVENTORY
└── INFRASTRUCTURE
    ├── supabase
    ├── railway
    ├── github
    └── ci-runners
```

El registry definitivo debe derivarse del repositorio/runtime real, no de esta lista preliminar.

## 9. Arquitectura objetivo

```text
ASCENDA runtime / browser / dependencies
               │
      ┌────────┼───────────┐
      │        │           │
  Sentry    OTel       Availability/Business probes
      │        │           │
      └────────┴─────┬─────┘
                     ▼
                Sentinel Core
          topology + state + incidents
                     │
        ┌────────────┼─────────────┐
        ▼            ▼             ▼
   Sentinel Hub   Telegram     Diagnostic Runner
        │                          │
        └────────────┬─────────────┘
                     ▼
              GitHub branch / PR
                     ▼
                 Zero-Cost CI
                     ▼
                  canary
                     ▼
                 production
```

## 10. Panel final

Sentinel Hub será un panel **owner/admin técnico**, no un panel SaaS de cliente. Debe mostrar topología y degradación por zona, no solo mensajes genéricos.

Ejemplo esperado:

```text
WHATSAPP
└── Outbound Messaging [INCIDENT]
    ├── ASCENDA API [HEALTHY]
    ├── 2FA/auth [HEALTHY]
    ├── routing [HEALTHY]
    ├── provider send [INCIDENT]
    └── delivery receipts [DEGRADED]
```

El panel final debe permitir abrir el incidente, ver evidencia sanitizada, release/commit correlacionado, impacto, estado y siguiente acción.

## 11. Seguridad y privacidad

- `sendDefaultPii=false` o equivalente.
- scrub/redaction antes de exportar cuando sea técnicamente posible.
- no request bodies sensibles.
- no Session Replay sobre flujos clínicos/privados durante la baseline.
- no contenidos WhatsApp/email.
- no headers de auth/cookies/tokens.
- no service role en logs.
- no PHI/PII en fixtures.
- toda nueva tabla/RPC de Sentinel pasa migration versionada, RLS/ACL y Zero-Cost validation según riesgo.

## 12. Política económica

- objetivo inicial Sentry: plan Developer / costo base US$0 mientras el volumen y capacidades lo permitan;
- no activar pay-as-you-go automáticamente;
- sampling y filtering obligatorios antes de ampliar tracing/logging;
- no duplicar la misma telemetría en múltiples backends sin una razón demostrable;
- UptimeRobot Free mantiene la cobertura cloud continua de F5 mientras siga cumpliendo el baseline aprobado;
- Uptime Kuma corre localmente en CREACTIVE y su ausencia se representa como `UNKNOWN`, no como caída de ASCENDA;
- no se crea infraestructura pagada por inercia;
- cualquier upgrade Sentry o servicio adicional requiere Impact Report económico y autorización expresa.

## 13. Fuentes canónicas

Precedencia Sentinel:

1. GitHub/docs canónicos y SHA exacto.
2. Runtime/deploy/schema live verificado.
3. Evidencia de sensores y CI.
4. Estado/incidentes Sentinel.
5. Notion para continuidad visual.

Notion nunca puede cerrar una fase que GitHub/runtime no prueben.

## 14. Definition of Done global

Sentinel puede declararse `100_COMPLETE` para una baseline solo cuando:

- las 13 fases del roadmap están cerradas con evidencia;
- el panel Sentinel está activo y protegido para owner/admin autorizado;
- los dominios críticos tienen estado y profundidad diagnóstica suficiente;
- se detectan tanto fallos técnicos como fallos funcionales silenciosos seleccionados;
- los incidentes tienen IDs `SEN-*` y correlación release/commit;
- alertas Telegram aplican deduplicación/severidad;
- Diagnostic Runner funciona sin mutar producción;
- MCP/AI triage respeta privacidad y mínimo privilegio;
- remediation mantiene aprobación humana y gates de ASCENDA;
- un backend puede ser reemplazado sin reescribir el modelo de Sentinel;
- costos y cuotas están medidos, limitados y documentados;
- Notion refleja el estado técnico real.

## 15. Roadmap

El roadmap operativo detallado está en `docs/control/SENTINEL_ROADMAP_V1.md`.

## 16. Checkpoint actual

- F1–F6: `100_COMPLETE` y fusionadas a `main` con post-merge CI.
- F7: `100_COMPLETE` candidate; PR #207 requiere terminal exact-head PASS, merge y post-merge PASS para que el cierre sea autoritativo.
- F7 baseline: correlation envelope vendor-neutral con release/SHA/deployment/request/trace, confidence `EXACT/STRONG/WEAK/UNKNOWN`, temporal candidate sin causalidad asumida y rollback target known-good sin ejecución.
- F8: siguiente fase canónica tras cierre autoritativo F7 — `Sentinel Incident Engine (SEN-*)`.
- Certificados terminales: `docs/control/SENTINEL_F5_FINAL_CERTIFICATE_20260816.md`, `docs/control/SENTINEL_F6_FINAL_CERTIFICATE_20260816.md`, `docs/control/SENTINEL_F7_FINAL_CERTIFICATE_20260816.md`.
