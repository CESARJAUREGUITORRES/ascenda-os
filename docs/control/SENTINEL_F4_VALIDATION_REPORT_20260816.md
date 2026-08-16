# SENTINEL F4 — Sentry Error Monitoring Core — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `TECHNICAL_FOUNDATION_CERTIFIED / HUMAN_BOUNDARY_RETRY`  
**F1:** `100_COMPLETE`  
**F2:** `100_COMPLETE`  
**F3:** `100_COMPLETE`  
**Foundation:** PR `#189` → `main@39695d154be7099d8363896af09b1d70ced12126`  
**Riesgo:** HIGH — first external telemetry sensor.

## 1. Objetivo

Añadir Sentry como sensor especializado de errores de alta señal con Zero PHI/PII, costo incremental autorizado US$0, tracing/logs/replay OFF, kill switches independientes y Sentry aislado del funcionamiento de ASCENDA.

## 2. Foundation autónoma certificada

PR #189 dejó integrados:

- `@sentry/node@10.70.0` pin exacto;
- preloader CommonJS default OFF;
- `sendDefaultPii=false`;
- traces=0, logs OFF, breadcrumbs=0, local vars OFF;
- allowlist/minimizer antes de exportar;
- synthetic-only canary default=true;
- fixture adversarial con `fixture_leaks=0`;
- material regressions F1/F2/F3;
- Ascenda CI PASS.

G01–G13 permanecen PASS.

## 3. Hallazgo durante HUMAN BOUNDARY

El primer deploy canary falló durante **build**, antes de iniciar el runtime.

Evidencia Railway mostrada el 2026-08-16:

```text
MODULE_NOT_FOUND
requireStack: ['internal/preload']
Node.js v18.20.5
"npm install" did not complete successfully: exit code: 1
```

### Root cause

`NODE_OPTIONS=--require ./sentinel-sentry-init.cjs` fue configurado como variable global de Railway. Las variables globales también alcanzan Nixpacks/npm durante build. `npm install` ejecutó Node con el preload antes de que el contexto runtime estuviera disponible y falló.

**Producción no cayó:** Railway mantuvo el deployment anterior `Active/Online`; el candidate falló cerrado antes de Deploy/Network/Post-deploy.

## 4. Mejora permanente del loop

F4 adopta una separación obligatoria:

`build-time variables ≠ runtime-only instrumentation`

Se prohíbe `NODE_OPTIONS` como variable global Railway.

El preload canónico queda versionado en `app/railway.json` como:

```text
env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js
```

Beneficios:

1. Nixpacks/npm no reciben el preload durante build;
2. `server-phase-s.js` sí lo recibe al iniciar producción;
3. sus procesos hijos heredan `process.env`, por lo que la cadena Node completa recibe el preload;
4. el contrato CI verifica esta separación y falla si vuelve a contaminar build.

## 5. Gates F4

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F4-G01 | F1-F3 `100_COMPLETE`; F4 única fase activa | PASS |
| F4-G02 | baseline y branch aislada | PASS |
| F4-G03 | SDK Sentry Node pin exacto | PASS |
| F4-G04 | F1 privacy/cost invariants | PASS |
| F4-G05 | F2 topology/UNKNOWN invariants | PASS |
| F4-G06 | F3 Zero-PHI/PII + production tracing=0 | PASS |
| F4-G07 | preloader default OFF + dual kill switch | PASS |
| F4-G08 | missing DSN fail-closed | PASS |
| F4-G09 | adversarial fixture 0 leaks | PASS |
| F4-G10 | logs/breadcrumbs/local vars/request/body/user blocked | PASS |
| F4-G11 | synthetic-only canary | PASS |
| F4-G12 | self-hosted contract + Ascenda CI | PASS |
| F4-G13 | foundation scope/secrets | PASS |
| F4-G14 | Sentry project + server-side scrub + IP scrub | PASS by human evidence; final consolidated checkpoint pending |
| F4-G15 | Railway runtime-only preload + canary deploy | RETRY_REQUIRED after build-time contamination finding |
| F4-G16 | synthetic event + release/env/tags + zero PHI/PII | PENDING |
| F4-G17 | kill switch + `/health` 200 + real sanitized mode | PENDING |
| F4-G18 | final merge(s) + Notion F4=100/Cerrada + F5 Siguiente | PENDING |

**Estado operativo:** `13/18 PASS`; G14 evidenciado pero se consolida con G15–G17 antes del cierre.

## 6. Human retry exacto

Después de integrar el hotfix runtime-only:

1. eliminar la variable global Railway `NODE_OPTIONS`;
2. mantener `SENTINEL_ENABLED=true`;
3. mantener `SENTINEL_SENTRY_ENABLED=true`;
4. mantener `SENTINEL_SENTRY_CANARY_MODE=true`;
5. mantener `SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=true`;
6. mantener `SENTRY_ENVIRONMENT=production`;
7. mantener `SENTRY_DSN` secreto;
8. redeploy;
9. verificar build PASS y `/health` 200;
10. verificar `SENTINEL_F4_SYNTHETIC_ERROR` en Sentry.

## 7. No autorizaciones implícitas

Siguen OFF/no autorizados: tracing >0, logs Sentry, Replay, profiling, attachments, pay-as-you-go, Seer/AI autofix, source-map token upload, DB/migrations Sentinel, Telegram y auto-remediation.

## 8. HUMAN_BOUNDARY_PENDING

F4 no puede declararse `100_COMPLETE` hasta G15–G18.

F4-G01 F4-G02 F4-G03 F4-G04 F4-G05 F4-G06 F4-G07 F4-G08 F4-G09 F4-G10 F4-G11 F4-G12 F4-G13 F4-G14 F4-G15 F4-G16 F4-G17 F4-G18
