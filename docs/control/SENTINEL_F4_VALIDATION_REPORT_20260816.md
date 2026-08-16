# SENTINEL F4 — Sentry Error Monitoring Core — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `TECHNICAL_FOUNDATION_CERTIFIED / HUMAN_BOUNDARY_PENDING`  
**F1:** `100_COMPLETE`  
**F2:** `100_COMPLETE`  
**F3:** `100_COMPLETE`  
**Baseline F4:** `main@e3ff8914447c06a2b94b3be5cccbade73526ce0d`  
**Branch:** `feat/sentinel-f4-sentry-core`  
**Foundation PR:** `#189`  
**Riesgo:** HIGH — first external telemetry sensor.

## 1. Objetivo

Añadir Sentry como sensor especializado de errores de alta señal, manteniendo Zero PHI/PII, costo incremental autorizado US$0, tracing/logs/replay OFF, kill switches independientes y Sentry aislado del funcionamiento de ASCENDA.

## 2. Mejora del loop

F4 incorpora un `HUMAN BOUNDARY` formal. El loop ejecuta autónomamente recovery, dependency pin, preloader dormido, fixture adversarial, contrato CI, scope/secret gates y PR. Solo se detiene cuando una acción exige cuenta externa Sentry/Railway.

También añade `synthetic-only canary`: al conectar Sentry por primera vez, todos los eventos reales se descartan y únicamente puede salir `SENTINEL_F4_SYNTHETIC_ERROR`.

Durante el primer candidate apareció un falso rojo del workflow histórico F1: `F1_SCOPE_RUNTIME_OR_DB_CHANGE:app/package.json`. La causa no era una regresión de privacidad; F1 había sido diseñado para demostrar que **F1** no modificó runtime y su trigger amplio se ejecutaba indebidamente en fases posteriores. Se corrigió el trigger F1 para observar solo artefactos F1. Cada fase posterior debe ejecutar su propio certificate y las regresiones **materiales** F1/F2/F3 pertinentes. El candidate siguiente dejó de disparar el falso gate y el contrato F4 certificó `f1_privacy_material_regression=true`.

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

## 4. Evidencia autónoma exact-head

Candidate técnico: `ccf78aa71d5dd4b09e5b732364e1c8d66365d5e3`.

### Sentinel F4 Sentry Foundation Certificate

Run `31956828802` — **PASS**.

El contrato emitió:

```text
SENTINEL_F4_FOUNDATION_CONTRACT_PASS
sdk = @sentry/node@10.70.0
f1_privacy_material_regression = true
f1_cross_phase_false_red_fixed = true
f2_topology_material_regression = true
f3_telemetry_material_regression = true
default_active = false
canary_default = true
canary_only_synthetic = true
missing_dsn_fail_closed = true
zero_phi_pii_fixture = true
fixture_leaks = 0
traces_sample_rate = 0
logs = false
breadcrumbs = 0
pay_as_you_go = false
human_boundary = PENDING
```

### Runtime regression

Ascenda CI — run `31956828795` — **PASS** sobre el mismo candidate.

Un workflow funcional histórico adicional (`ASCENDA Phase 5 Historical Patient Identity`) también había pasado sobre el candidate anterior de la misma foundation; no es gate de Sentinel F4 y no se utiliza para inflar su certificación.

## 5. Scope proof

PR #189 contiene nueve superficies exactas:

1. `.github/workflows/sentinel-phase1-governance.yml` — narrow trigger fix para eliminar falso cross-phase gate.
2. `.github/workflows/sentinel-phase4-sentry.yml`.
3. `app/package.json`.
4. `app/sentinel-sentry-init.cjs`.
5. `ci/sentinel/fixtures/f4_sentry_sensitive_event.json`.
6. `ci/sentinel/phase4_sentry_contract.js`.
7. `docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md`.
8. `docs/control/SENTINEL_F4_VALIDATION_REPORT_20260816.md`.
9. `sentinel/sentry/f4-contract.json`.

Resultado: **0 `app/railway.json`, 0 migrations/DB, 0 Supabase functions, 0 DSN, 0 provider credentials, 0 product telemetry activation**.

## 6. Gates F4

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F4-G01 | F1-F3 `100_COMPLETE`; F4 única fase activa | PASS |
| F4-G02 | baseline `main@e3ff8914` y branch aislada | PASS |
| F4-G03 | SDK Sentry Node stable pin exacto y reproducible | PASS |
| F4-G04 | F1 privacy/cost material invariants preservados | PASS |
| F4-G05 | F2 topology/UNKNOWN material invariants preservados | PASS |
| F4-G06 | F3 zero-PHI/PII, allowlist, baggage-off, production tracing=0 preservados | PASS |
| F4-G07 | preloader default OFF y dual kill-switch | PASS |
| F4-G08 | missing DSN fail-closed para telemetría y no rompe bootstrap | PASS |
| F4-G09 | adversarial fixture demuestra 0 leaks antes de exporter | PASS |
| F4-G10 | breadcrumbs/logs/local vars/request/body/user/source context bloqueados | PASS |
| F4-G11 | synthetic-only canary default=true | PASS |
| F4-G12 | package/API/syntax + self-hosted foundation contract PASS | PASS |
| F4-G13 | foundation diff sin Railway/DB/providers/secrets | PASS |
| F4-G14 | Sentry Node project zero-cost + server-side scrub + IP scrub verificados | HUMAN_BOUNDARY_PENDING |
| F4-G15 | Railway canary variables/preloader configurados sin exponer DSN | HUMAN_BOUNDARY_PENDING |
| F4-G16 | synthetic event visible con environment/release/tags correctos y cero PHI/PII | HUMAN_BOUNDARY_PENDING |
| F4-G17 | kill switch probado; `/health` permanece 200; sanitized real-error mode activado | HUMAN_BOUNDARY_PENDING |
| F4-G18 | checkpoint, merge(s), Notion F4=100/Cerrada y F5 única Siguiente | PENDING |

**Estado técnico:** `13/18 PASS`.

## 7. Estado actual

La parte autónoma F4 está técnicamente certificada. La foundation permanece sin cableado Railway: tener el package/preloader en `main` no activa Sentry mientras no existan `NODE_OPTIONS`, switches y DSN en el runtime.

F4 no puede declararse `100_COMPLETE` mientras G14–G17 no tengan evidencia real de Sentry/Railway y G18 no cierre continuidad/Notion.

## 8. No autorizaciones implícitas

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

## 9. Handoff humano

Ver `docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md`.

Texto canónico posterior a la intervención:

`LISTO F4-HUMAN-GATE: proyecto Sentry Node creado; data scrubbing e IP scrubbing activos; variables Railway cargadas sin compartir secretos; synthetic SENTINEL_F4_SYNTHETIC_ERROR visible con environment=production y release correcto; evento revisado sin PHI/PII/secrets; kill switch probado con /health=200. AUTORIZO cerrar canary y continuar el loop F4 hasta certificación.`
