# SENTINEL F4 — Sentry Error Monitoring Core — Final Certificate

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `100_COMPLETE / CERTIFIED`  
**F1:** `100_COMPLETE`  
**F2:** `100_COMPLETE`  
**F3:** `100_COMPLETE`  
**F4:** `100_COMPLETE`  
**Foundation:** PR `#189` → `main@39695d154be7099d8363896af09b1d70ced12126`  
**Runtime hotfix:** PR `#191` → `main@2a989d9f1ddc9f10c64f49b3be475c4dfa89ab9d`  
**Auth/Resend continuity hotfix:** PR `#192` → `main@1077ef9b3ad95619683c50602dba55958e9a445f`  
**Riesgo:** HIGH — primer sensor externo de telemetría productiva.

## 1. Objetivo certificado

Sentry queda incorporado como sensor especializado de errores de alta señal con Zero PHI/PII, costo incremental autorizado US$0, tracing/logs/replay OFF, kill switches independientes y sin convertirse en dependencia de disponibilidad de ASCENDA ni de Sentinel Core.

## 2. Configuración final

- `@sentry/node@10.70.0` pin exacto durante F4;
- `sendDefaultPii=false`;
- traces=0;
- logs OFF;
- Session Replay OFF;
- breadcrumbs=0;
- local variables OFF;
- request/query/body/user/source context eliminados antes de exportar;
- allowlist/minimizer antes de exportar;
- synthetic-only canary validado;
- release = `ascenda-os@<commit_sha>`;
- environment = `production`;
- dual kill switch `SENTINEL_ENABLED` + `SENTINEL_SENTRY_ENABLED`;
- ausencia de DSN falla cerrada para telemetría y abierta para ASCENDA;
- `NODE_OPTIONS` prohibido como variable global Railway;
- preload Sentry limitado al Start Command runtime.

## 3. Hallazgo y corrección permanente

El primer canary falló durante build porque `NODE_OPTIONS=--require ./sentinel-sentry-init.cjs` había sido configurado como variable global Railway y contaminó Nixpacks/npm antes del runtime.

La corrección permanente quedó fusionada en PR #191:

```text
env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js
```

El build queda libre de preload y la cadena Node productiva hereda la instrumentación únicamente desde runtime.

## 4. Evidencia productiva final

### Runtime

Después del merge `2a989d9f…`, `server-phase-s.js` arrancó y ejecutó su reconciliación privada de Resend a las `2026-08-16 18:02:46 UTC`, demostrando llegada a runtime después del build.

### Sentry synthetic canary

Sentry recibió `SENTINEL_F4_SYNTHETIC_ERROR` con:

- `environment=production`;
- `release=ascenda-os@2a989d9f1ddc9f10c64f49b3be475c4dfa89ab9d`;
- `sentinel.phase=F4`;
- `service.name=server-phase-s.js`;
- `system=ascenda-os`;
- nivel `error`;
- sin usuario asociado.

### Health post-deploy

Evidencia humana del owner el 2026-08-16:

```json
{"ok":true,"service":"ascenda-phase-s","child_alive":true,"inner_ready":true}
```

### Login/2FA post-deploy

El owner confirmó ingreso exitoso a ASCENDA después del hotfix de Resend y del runtime Sentinel. La API key Resend existente no fue rotada; Railway permanece fuente operativa y el vault privado se reconcilia automáticamente.

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
| F4-G14 | Sentry project + server-side scrub + IP scrub | PASS |
| F4-G15 | Railway runtime-only preload + canary deploy | PASS |
| F4-G16 | synthetic event + release/env/tags + cero PHI/PII | PASS |
| F4-G17 | kill switch contract + `/health` 200 + runtime real sano | PASS |
| F4-G18 | merge final + GitHub/Notion checkpoint + F5 handoff | PASS |

**Resultado:** `18/18 PASS`.

## 6. Límites que permanecen vigentes

Siguen OFF/no autorizados por F4: tracing >0, logs Sentry, Replay, profiling, attachments, pay-as-you-go, Seer/AI autofix, source-map token upload, Telegram y auto-remediation.

La siguiente fase puede añadir disponibilidad externa, pero no amplía automáticamente el volumen de Sentry ni modifica las reglas de privacidad F1.

## 7. Handoff

`F4 = CLOSED / 100_COMPLETE`.

Siguiente fase canónica: `F5 — Availability Layer / Uptime Kuma`.

F4-G01 F4-G02 F4-G03 F4-G04 F4-G05 F4-G06 F4-G07 F4-G08 F4-G09 F4-G10 F4-G11 F4-G12 F4-G13 F4-G14 F4-G15 F4-G16 F4-G17 F4-G18
