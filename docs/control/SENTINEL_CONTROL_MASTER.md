# Sentinel — Control Maestro

**Estado:** `CERRADA / 100_COMPLETE / CANONICAL BASELINE V1`  
**Fecha:** 2026-08-16/17 (America/Lima)  
**Repositorio:** `CESARJAUREGUITORRES/ascenda-os`  
**Workstream:** `SENTINEL`  
**Rama fundacional:** `docs/sentinel-control-v1`  
**Ámbito:** observabilidad, detección, correlación, triage, incidentes y respuesta segura para ASCENDA OS.  
**Roadmap terminal:** `docs/control/SENTINEL_ROADMAP_V1.md`  
**Certificado F13:** `docs/control/SENTINEL_F13_FINAL_CERTIFICATE_20260817.md`

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
6. **No false-green.** Si Sentinel no puede observar una capacidad devuelve `UNKNOWN`, no `HEALTHY`.
7. **No duplicar fuentes de verdad.** Sentinel guarda evidencia operacional y metadatos de incidentes, no copias de datos clínicos/comerciales.
8. **Toda remediación sigue branch → CI → staging/fixture → PR → canary → autorización → producción cuando corresponda.**

## 3. Decisión de arquitectura: híbrida

### 3.1 Por qué no Sentry-only

Sentry es un sensor de alto valor para excepciones, stack traces, issues agrupados, tracing, releases y debugging, pero no detecta por sí solo todos los fallos funcionales. Un endpoint puede responder HTTP 200 y, aun así, devolver cero leads, una cola vacía o una regla de negocio rota.

Sentinel no diseña su panel ni su Incident Engine dependiendo de una API/feature propietaria concreta.

### 3.2 Por qué no open-source-only desde el día 1

Es técnicamente viable reemplazar Sentry por una combinación self-hosted, pero añade infraestructura, mantenimiento, backups, upgrades y otra superficie de fallo. La baseline prioriza alta señal con costo marginal mínimo y mantiene una ruta portable.

### 3.3 Estrategia adoptada

- **Sentry Cloud Developer:** sensor especializado de errores/traces de alto valor; no es la base de datos de Sentinel.
- **OpenTelemetry:** contrato portable de telemetría y futura capa de routing/filter/redaction/sampling.
- **UptimeRobot Free:** cobertura cloud continua del endpoint público `/health` sin costo incremental.
- **Uptime Kuma:** observador local/intermitente en CREACTIVE con persistencia, autoarranque Docker y coverage gaps explícitos.
- **Sentinel Core:** topología, reglas de negocio, estados, incidentes `SEN-*`, severidad, evidencias y correlación.
- **Supabase:** persistencia mínima versionada de incidentes/alertas; F8/F9/F13 usan boundaries gobernados.
- **GitHub + self-hosted CI:** código, releases, commits, PR, diagnóstico, candidate remediation y evidencia reproducible.
- **Railway:** runtime/deploy actual; se correlaciona y observa, no se reemplaza.
- **ASCENDA in-app:** canal owner/admin canónico para alertas Sentinel, con dedup/noise-control y read receipts separados de delivery.
- **Telegram `F9-T`:** transporte externo opcional y `DEFERRED / NON-BLOCKING`; no es dependencia estructural ni gate de la baseline.
- **GlitchTip u otro backend compatible:** ruta futura de portabilidad/self-hosting si costo, control o residencia de datos lo justifican.

## 4. Modelo de observación

Sentinel combina cuatro tipos de señal:

1. **Technical Errors** — excepciones, crashes, rejects y fallos runtime.
2. **Availability** — HTTP/health checks y disponibilidad externa.
3. **Business Health** — invariantes funcionales, freshness, cardinalidades, colas, sincronizaciones y contratos operativos.
4. **Dependencies** — Supabase, Railway, Meta/WhatsApp, Resend/email, IA/providers y otras integraciones.

Ninguna señal individual puede declarar salud global por sí sola.

## 5. Estados canónicos

- `HEALTHY` — evidencia suficiente de operación normal.
- `DEGRADED` — opera parcialmente o fuera de baseline.
- `INCIDENT` — impacto funcional confirmado o altamente probable.
- `CRITICAL` — capacidad crítica caída, seguridad o integridad materialmente afectada.
- `UNKNOWN` — falta telemetría suficiente o existe inconsistencia entre sensores.

## 6. Taxonomía mínima obligatoria

Toda señal/incidente debe poder correlacionarse, cuando aplique, con:

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

No se usan identificadores de pacientes/personas como tags de observabilidad.

## 7. Incident ID

Formato canónico:

`SEN-YYYY-NNNN`

F8 certificó generación transaccional anual, replay idempotente, convergencia por fingerprint, escalamiento de severidad, lifecycle y reopen del mismo ID dentro de la ventana gobernada.

Un incidente puede enlazar evidencia de Sentinel, Sentry, GitHub, Railway, CI y postmortem sin copiar secretos ni payloads sensibles.

## 8. Mapa de dominios

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

El registry machine-readable definitivo es `SENTINEL_SYSTEM_REGISTRY_V1.json`; F13 proyecta de él 34 capabilities owner-safe y no expone relaciones internas/paths/RPCs al browser.

## 9. Arquitectura terminal V1

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
        ┌────────────┼────────────────┐
        ▼            ▼                ▼
   Sentinel Hub   ASCENDA In-App   Diagnostic Runner
        │        Owner Alerts            │
        │          │                      ▼
        │          └───────┐         MCP/AI Triage
        │                  │              │
        └──────────────────┴──────┬───────┘
                                  ▼
                       candidate remediation
                                  ▼
                         GitHub branch / PR
                                  ▼
                            Zero-Cost CI
                                  ▼
                         human approval gate
                                  ▼
                              production

Telegram F9-T = optional/deferred external adapter
```

## 10. Sentinel Hub final

Sentinel Hub es un panel **owner/admin técnico**, no un panel SaaS de cliente. Muestra topología y degradación por zona/capability, no solo mensajes genéricos.

Ejemplo de profundidad esperada:

```text
WHATSAPP
└── Outbound Messaging [INCIDENT]
    ├── ASCENDA API [HEALTHY]
    ├── 2FA/auth [HEALTHY]
    ├── routing [HEALTHY]
    ├── provider send [INCIDENT]
    └── delivery receipts [DEGRADED]
```

El Hub permite localizar la capability, revisar `SEN-*`, severidad, estado, evidence refs/timeline sanitizados y correlación release/commit; desde UI solo se habilitan acciones seguras como copiar SEN o abrir GitHub. Diagnóstico/remediación continúan bajo sus boundaries propios.

## 11. Seguridad y privacidad

- `sendDefaultPii=false` o equivalente.
- scrub/redaction antes de exportar cuando sea técnicamente posible.
- no request bodies sensibles.
- no Session Replay sobre flujos clínicos/privados en la baseline.
- no contenidos WhatsApp/email.
- no headers de auth/cookies/tokens.
- no service role en browser/logs.
- no PHI/PII en fixtures.
- toda nueva tabla/RPC Sentinel pasa migration versionada, RLS/ACL y Zero-Cost validation según riesgo.
- F8 persiste metadata técnica sanitizada/evidence refs tipados; tablas sin acceso directo de app roles y RPC operativas service-role-only.
- F9 persiste ledger/outbox técnico, delivery, digest/maintenance/read state; no mensaje renderizado externo, bot token, chat target, PHI/PII.
- F13 RPC owner `aos_sentinel_owner_hub_v1(text,integer)` reutiliza Auth V3 + `PASSWORD_2FA`, es read-only y fail-closed.
- topología pública F13 usa allowlist owner-safe y `UNKNOWN` como estado por defecto cuando falta evidencia.

## 12. Política económica

- objetivo inicial Sentry: costo base US$0 mientras plan/volumen lo permitan;
- no activar pay-as-you-go automáticamente;
- sampling/filtering obligatorios antes de ampliar tracing/logging;
- no duplicar telemetría en múltiples backends sin razón demostrable;
- UptimeRobot Free mantiene cobertura cloud continua de F5 mientras cumpla el baseline;
- Uptime Kuma usa recursos CREACTIVE existentes y su ausencia se representa como `UNKNOWN`;
- no se crea infraestructura pagada por inercia;
- cualquier upgrade Sentry o servicio adicional exige Impact Report económico y autorización expresa.

## 13. Fuentes canónicas

Precedencia Sentinel:

1. GitHub/docs canónicos y SHA exacto.
2. Runtime/deploy/schema live verificado.
3. Evidencia de sensores y CI.
4. Estado/incidentes Sentinel.
5. Notion para continuidad visual.

Notion nunca puede cerrar una fase que GitHub/runtime no prueben. Tras cierre técnico, Notion se sincroniza como mirror operativo.

## 14. Definition of Done global

La baseline Sentinel V1 está `100_COMPLETE` porque:

- las 13 fases del roadmap están cerradas con evidencia;
- Sentinel Hub está activo y protegido para owner/admin autorizado;
- los dominios/capabilities críticos tienen estado o `UNKNOWN` explícito;
- se detectan fallos técnicos, disponibilidad y fallos funcionales silenciosos seleccionados;
- incidentes usan IDs `SEN-*` y correlación release/commit;
- owner alerts `ascenda-in-app` aplican severidad, dedup, cooldown, digest, flapping, maintenance y recovery; Telegram es opcional;
- Diagnostic Runner investiga read-only sin mutar producción;
- MCP/AI triage respeta privacidad, evidence refs, confidence y mínimo privilegio;
- Safe Remediation produce candidate patches/PR bajo sandbox/security/CI/human gate, sin auto-merge/auto-deploy;
- Hub soporta no-false-green y pruebas de resilience/portability;
- Railway/production assets tienen smoke terminal;
- costos/cuotas están limitados por la política Zero-Cost/cost-bounded;
- paridad específica F13 Git/live está corregida en `20260817203504`;
- Notion se alinea después del closeout GitHub como espejo del estado técnico real.

## 15. Roadmap

El roadmap operativo y su estado terminal están en `docs/control/SENTINEL_ROADMAP_V1.md`.

## 16. Checkpoint terminal

- F1–F4: `CERRADA / 100_COMPLETE` — governance/privacy/cost, registry/topology, OTel portable y Sentry core certificados.
- F5: `CERRADA / 100_COMPLETE` — UptimeRobot Free + Kuma/CREACTIVE, gaps UNKNOWN, outage/recovery deterministic.
- F6: `CERRADA / 100_COMPLETE` — business-health/silent failures aggregate-only.
- F7: `CERRADA / 100_COMPLETE` — release/deploy/request/trace correlation y causalidad guarded.
- F8: `CERRADA / 100_COMPLETE` — `SEN-*` Incident Engine; live `20260817000618`; canary `SEN-2026-0001 RESOLVED`.
- F9: `CERRADA / 100_COMPLETE` — routing/noise + durable outbox + `ascenda-in-app`; live `20260817174233`; canaries `SEN-2026-0002/0003 RESOLVED`; Telegram `F9-T DEFERRED / NON-BLOCKING`.
- F10: `CERRADA / 100_COMPLETE` — PR #235; Diagnostic Runner read-only, affected SHA EXACT, replay byte-for-byte.
- F11: `CERRADA / 100_COMPLETE` — PR #240; seis MCP tools read-only, evidence/confidence, anti-hallucination/no-write boundaries.
- F12: `CERRADA / 100_COMPLETE` — PR #244 merge `a82089b3cf40bbc8546b6c98bb8f6b48512933c5`; candidate PR #243 pasó CI y fue CLOSED/NOT MERGED; post-merge F12 `32064580020` + Ascenda CI `32064579939` PASS; `production_mutation=false`, `auto_merge=false`, `auto_deploy=false`.
- F13: `CERRADA / 100_COMPLETE` — PR #252 Hub funcional; PR #255 paridad Git/live `203504`; PR #254 terminal smoke sobre CURRENT S15; exact-current F13 `32082197260` + Ascenda CI `32082197300` PASS; merge técnico `aacd92148a2a15f12bed7d0e014fb7424bc25415`; Railway SUCCESS; production Hub assets/privacy smoke PASS; Supabase read-back `20260817203504 sentinel_f13_owner_hub` + owner RPC presente.
- CURRENT posterior: S15.1 `043b4e454682e13cc0b84e860b90e0a15e8ed0cc` endurece notificaciones generales/F17 y no modifica archivos Sentinel/F13; closeout #263 se rebasa sobre ese SHA y usa regresiones F9/F13 para compatibilidad final.

### Baseline

**`SENTINEL BASELINE F1–F13 = 100_COMPLETE`**

Flujo transversal certificado:

`detect → SEN-* → notify owner → diagnose → MCP/AI triage → candidate fix → PR/CI → human gate`

### Deudas separadas que no reabren la baseline

- Telegram `F9-T`: transporte externo opcional/deferred.
- Auditoría global de migration-history del repositorio (#238 y sucesores): deuda transversal multi-owner. La paridad específica F13 ya está resuelta en `203504`; cualquier hallazgo externo solo reabre Sentinel si demuestra impacto Sentinel real.
- Nuevos sensores, backends o mayor autonomía de remediación requieren nuevo versionado/Impact Report.

## 17. Certificados terminales

- `docs/control/SENTINEL_F5_FINAL_CERTIFICATE_20260816.md`
- `docs/control/SENTINEL_F6_FINAL_CERTIFICATE_20260816.md`
- `docs/control/SENTINEL_F7_FINAL_CERTIFICATE_20260816.md`
- `docs/control/SENTINEL_F8_FINAL_CERTIFICATE_20260817.md`
- `docs/control/SENTINEL_F9_DURABLE_PRODUCTION_CERTIFICATE_20260817.md`
- `docs/control/SENTINEL_F10_FINAL_CERTIFICATE_20260817.md`
- `docs/control/SENTINEL_F11_FINAL_CERTIFICATE_20260817.md`
- `docs/control/SENTINEL_F12_FINAL_CERTIFICATE_20260817.md`
- `docs/control/SENTINEL_F13_FINAL_CERTIFICATE_20260817.md`
