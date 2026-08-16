# Sentinel F4 — Sentry Error Monitoring Core — Runbook

**Fecha:** 2026-08-16 (America/Lima)  
**Riesgo:** HIGH  
**Regla:** no compartir `SENTRY_DSN` en GitHub, Notion, chat ni screenshots.

## 1. Objetivo

Activar Sentry como sensor especializado de errores de alta señal sin convertirlo en dependencia de ASCENDA, sin tracing/logs/replay y con una primera conexión en modo canary sintético.

## 2. Loop F4 mejorado

`recovery → dependency pin → dormant preloader → privacy fixture → self-hosted CI → foundation merge → HUMAN BOUNDARY → runtime-only preload → synthetic-only canary → privacy/release verification → kill-switch proof → sanitized real-error activation → checkpoint → Notion → final certificate`

Las acciones de cuenta externa se detienen en un `HUMAN BOUNDARY`. Ningún gate se marca PASS por una captura o afirmación no comprobada.

## 3. Regla nueva: build-time ≠ runtime-time

**NO configurar `NODE_OPTIONS` como variable global de Railway.**

Motivo: una variable global alcanza también Nixpacks/npm durante el build. Si contiene `--require ./sentinel-sentry-init.cjs`, Node intenta cargar el preloader antes de que el contexto runtime exista y puede bloquear `npm install` con `MODULE_NOT_FOUND` / `internal/preload`.

La única forma canónica F4 es runtime-only mediante `app/railway.json`:

```text
env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js
```

Esto aplica el preloader solo al runtime productivo. `server-phase-s.js` propaga `process.env` a sus procesos hijos, por lo que la cadena Node hereda `NODE_OPTIONS` sin contaminar el build.

## 4. Estado dormido

El preloader `app/sentinel-sentry-init.cjs` solo exporta si se cumplen simultáneamente:

- `SENTINEL_ENABLED=true`
- `SENTINEL_SENTRY_ENABLED=true`
- `SENTRY_DSN` presente
- runtime iniciado mediante el Start Command canónico anterior.

Si falta cualquier condición, ASCENDA continúa operativa sin export Sentry.

## 5. Privacy baseline

Configuración local obligatoria:

- `sendDefaultPii=false`
- `tracesSampleRate=0`
- logs OFF
- breadcrumbs = 0
- local variables OFF
- `beforeBreadcrumb` descarta todo
- `beforeSend` reconstruye un evento mínimo
- user/request/query/cookies/body/extra/contexts/transaction/modules/spans DROP
- free-text exception message → `[REDACTED_MESSAGE]`
- tags solo por allowlist Sentinel

Backend Sentry mantiene segunda capa: Data Scrubber ON, Default Scrubbers ON, IP scrubbing ON y Safe Fields vacío.

## 6. Canary sintético

`SENTINEL_SENTRY_CANARY_MODE=true` permite exportar únicamente:

`SENTINEL_F4_SYNTHETIC_ERROR`

`SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=true` genera una captura controlada en `server-phase-s.js`; después del test vuelve a `false`.

## 7. HUMAN BOUNDARY — Sentry

1. Proyecto Node.js `ascenda-os`.
2. Plan zero-cost vigente; pay-as-you-go OFF.
3. Data Scrubber ON.
4. Default Scrubbers ON.
5. Prevent Storing of IP Address ON.
6. Additional Sensitive Fields definidos.
7. Safe Fields vacío.
8. Replay/logs/profiling/tracing no activados.
9. DSN solo en Railway.

## 8. HUMAN BOUNDARY — variables Railway

Configurar únicamente:

```text
SENTINEL_ENABLED=true
SENTINEL_SENTRY_ENABLED=true
SENTINEL_SENTRY_CANARY_MODE=true
SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=true
SENTRY_DSN=<SECRET_IN_RAILWAY_ONLY>
SENTRY_ENVIRONMENT=production
```

**No crear `NODE_OPTIONS` como variable Railway.** El runtime-only preload viene versionado en `app/railway.json`.

No definir manualmente `SENTRY_RELEASE`: se deriva `ascenda-os@<sha>` desde `RAILWAY_GIT_COMMIT_SHA`.

## 9. Canary gate

Después del deploy:

1. build debe completar sin `internal/preload`/`MODULE_NOT_FOUND`;
2. `/health` debe responder 200;
3. Sentry recibe `SENTINEL_F4_SYNTHETIC_ERROR`;
4. `environment=production`;
5. `release=ascenda-os@<RAILWAY_GIT_COMMIT_SHA>`;
6. tags mínimos: `system=ascenda-os`, `sentinel.phase=F4`, `service.name=server-phase-s.js`;
7. evento sin user/email/teléfono/DNI/IP/request body/cookies/Authorization/mensajes/prompts/local vars/source context;
8. canary=true no exporta errores reales.

Luego poner `SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=false`.

## 10. Kill-switch proof

1. `SENTINEL_SENTRY_ENABLED=false`.
2. Redeploy.
3. `/health` = 200.
4. No nuevo synthetic event.
5. Restaurar `SENTINEL_SENTRY_ENABLED=true` con canary=true.
6. Redeploy y `/health` = 200.

La caída/desactivación de Sentry nunca debe tumbar ASCENDA.

## 11. Activación real F4

Solo después de canary + kill-switch PASS:

```text
SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=false
SENTINEL_SENTRY_CANARY_MODE=false
SENTINEL_ENABLED=true
SENTINEL_SENTRY_ENABLED=true
SENTRY_ENVIRONMENT=production
```

Tracing/logging/replay continúan OFF.

## 12. Rollback

Observabilidad Sentry OFF:

```text
SENTINEL_SENTRY_ENABLED=false
```

Sentinel externo OFF:

```text
SENTINEL_ENABLED=false
```

No requiere tocar tablas, migraciones ni lógica de negocio.
