# SENTINEL F4 — Sentry Error Monitoring Core — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `VALIDATING / HUMAN_BOUNDARY_PENDING`  
**F1:** `100_COMPLETE`  
**F2:** `100_COMPLETE`  
**F3:** `100_COMPLETE`  
**Baseline F4:** `main@e3ff8914447c06a2b94b3be5cccbade73526ce0d`  
**Branch:** `feat/sentinel-f4-sentry-core`  
**Riesgo:** HIGH — first external telemetry sensor.

## 1. Objetivo

Añadir Sentry como sensor especializado de errores de alta señal, manteniendo Zero PHI/PII, costo incremental autorizado US$0, tracing/logs/replay OFF, kill switches independientes y Sentry aislado del funcionamiento de ASCENDA.

## 2. Mejora del loop

F4 incorpora un `HUMAN BOUNDARY` formal. El loop ejecuta autónomamente recuperación, dependency pin, preloader dormido, fixture adversarial, contrato CI, scope/secret gates y PR. Solo se detiene cuando una acción exige cuenta externa Sentry/Railway.

También añade `synthetic-only canary`: al conectar Sentry por primera vez, todos los eventos reales se descartan y únicamente puede salir `SENTINEL_F4_SYNTHETIC_ERROR`.

## 3. Foundation implementada

- `@sentry/node` pin exacto `10.70.0`.
- `app/sentinel-sentry-init.cjs` dormido por defecto.
- doble kill switch: `SENTINEL_ENABLED` + `SENTINEL_SENTRY_ENABLED`.
- DSN requerido pero nunca hardcoded/logged.
- `SENTINEL_SENTRY_CANARY_MODE` default true.
- one-shot `SENTINEL_SENTRY_SYNTHETIC_ON_BOOT` restringido a outer runtime.
- `sendDefaultPii=false`.
- `tracesSampleRate=0`.
- logs OFF, breadcrumbs 0, local variables OFF.
- event minimizer/allowlist antes de exporter.
- exception free text redacted; solo códigos técnicos uppercase se preservan.
- fixture sintético con señuelos de PII/PHI/secrets.
- no cambios Railway/DB/Supabase/proveedores en foundation.

## 4. Gates F4

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F4-G01 | F1-F3 `100_COMPLETE`; F4 única fase activa | PASS |
| F4-G02 | baseline `main@e3ff8914` y branch aislada | PASS |
| F4-G03 | SDK Sentry Node stable pin exacto y reproducible | PASS by implementation; CI pending |
| F4-G04 | F1 privacy/cost material invariants preservados | PASS by implementation; CI pending |
| F4-G05 | F2 topology/UNKNOWN material invariants preservados | PASS by implementation; CI pending |
| F4-G06 | F3 zero-PHI/PII, allowlist, baggage-off, production tracing=0 preservados | PASS by implementation; CI pending |
| F4-G07 | preloader default OFF y dual kill-switch | PASS by implementation; CI pending |
| F4-G08 | missing DSN fail-closed para telemetría y no rompe ASCENDA | PASS by implementation; CI pending |
| F4-G09 | adversarial fixture demuestra 0 leaks antes de exporter | PENDING CI |
| F4-G10 | breadcrumbs/logs/local vars/request/body/user/source context bloqueados | PENDING CI |
| F4-G11 | synthetic-only canary default=true | PENDING CI |
| F4-G12 | package/API/syntax + self-hosted foundation contract PASS | PENDING CI |
| F4-G13 | final foundation diff sin Railway/DB/providers/secrets | PENDING |
| F4-G14 | Sentry Node project zero-cost + server-side scrub + IP scrub verificados | HUMAN_BOUNDARY_PENDING |
| F4-G15 | Railway canary variables/preloader configurados sin exponer DSN | HUMAN_BOUNDARY_PENDING |
| F4-G16 | synthetic event visible con environment/release/tags correctos y cero PHI/PII | HUMAN_BOUNDARY_PENDING |
| F4-G17 | kill switch probado; `/health` permanece 200; sanitized real-error mode activado | HUMAN_BOUNDARY_PENDING |
| F4-G18 | checkpoint, merge(s), Notion F4=100/Cerrada y F5 única Siguiente | PENDING |

## 5. Estado actual

`HUMAN_BOUNDARY_PENDING` no significa bloqueo prematuro. Primero deben completarse F4-G03–G13 mediante self-hosted CI y PR foundation. Después, y solo después, se solicita intervención humana para G14–G17.

F4 no puede declararse `100_COMPLETE` mientras el human boundary no tenga evidencia verificable.

## 6. No autorizaciones implícitas

F4 no autoriza:

- tracing productivo >0;
- Sentry logs;
- Replay;
- profiling;
- attachments;
- pay-as-you-go;
- Seer/AI autofix;
- source-map upload con token;
- cambio de plan;
- DB/migrations Sentinel;
- Telegram;
- auto-remediation.

## 7. Handoff humano

Ver `docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md`.

Texto canónico posterior a la intervención:

`LISTO F4-HUMAN-GATE: proyecto Sentry Node creado; data scrubbing e IP scrubbing activos; variables Railway cargadas sin compartir secretos; synthetic SENTINEL_F4_SYNTHETIC_ERROR visible con environment=production y release correcto; evento revisado sin PHI/PII/secrets; kill switch probado con /health=200. AUTORIZO cerrar canary y continuar el loop F4 hasta certificación.`
