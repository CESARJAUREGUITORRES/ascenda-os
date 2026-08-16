# Sentinel F4 — Sentry Error Monitoring Core — Runbook

**Fecha:** 2026-08-16 (America/Lima)  
**Baseline:** `main@e3ff8914447c06a2b94b3be5cccbade73526ce0d`  
**Riesgo:** HIGH  
**Regla:** no compartir `SENTRY_DSN` en GitHub, Notion, chat ni screenshots.

## 1. Objetivo

Activar Sentry como sensor especializado de errores de alta señal sin convertirlo en dependencia de ASCENDA, sin tracing/logs/replay y con una primera conexión en modo canary sintético.

## 2. Loop F4 mejorado

`recovery → dependency pin → dormant preloader → adversarial privacy fixture → self-hosted CI → foundation merge → HUMAN BOUNDARY → synthetic-only canary → privacy/release verification → kill-switch proof → sanitized real-error activation → checkpoint → Notion → final certificate`

La mejora respecto de loops anteriores es explícita: lo automatizable se ejecuta sin intervención; las cuentas externas se detienen en un `HUMAN BOUNDARY` verificable. Ningún gate se marca PASS por una captura o afirmación no comprobada.

## 3. Estado dormido

El preloader `app/sentinel-sentry-init.cjs` queda inactivo salvo que se cumplan simultáneamente:

- `SENTINEL_ENABLED=true`
- `SENTINEL_SENTRY_ENABLED=true`
- `SENTRY_DSN` presente
- el runtime haya sido arrancado con `NODE_OPTIONS=--require ./sentinel-sentry-init.cjs`

Si falta cualquier condición, ASCENDA continúa sin export Sentry.

## 4. Privacy baseline

Configuración local obligatoria:

- `sendDefaultPii=false`
- `tracesSampleRate=0`
- logs OFF
- breadcrumbs = 0
- local variables OFF
- RequestData/ContextLines/Console/LocalVariables default integrations filtradas cuando estén presentes
- `beforeBreadcrumb` descarta todo
- `beforeSend` reconstruye un evento mínimo
- user/request/query/cookies/body/extra/contexts/transaction/modules/spans DROP
- exception message solo se preserva si es un código técnico uppercase seguro; cualquier texto libre se vuelve `[REDACTED_MESSAGE]`
- stack frame conserva únicamente basename, module/function sanitizados, line/column e `in_app`
- tags por allowlist Sentinel

Backend Sentry debe mantener una segunda capa de data scrubbing e IP scrubbing. La segunda capa nunca reemplaza la sanitización local.

## 5. Canary sintético

`SENTINEL_SENTRY_CANARY_MODE` tiene default `true`.

Mientras sea `true`, `beforeSend` devuelve `null` para todos los eventos excepto el código exacto:

`SENTINEL_F4_SYNTHETIC_ERROR`

Esto permite validar la conexión sin exportar errores reales del negocio.

`SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=true` genera una única captura controlada únicamente en `server-phase-s.js`; después del test debe volver a `false` o eliminarse.

## 6. HUMAN BOUNDARY — acciones en Sentry

1. Crear un proyecto **Node.js** para ASCENDA en el plan Developer/zero-cost vigente.
2. Mantener pay-as-you-go deshabilitado.
3. Activar server-side data scrubbing/default scrubbers.
4. Activar IP address scrubbing.
5. No habilitar Replay, logs, profiling ni tracing en esta fase.
6. Copiar el DSN únicamente hacia Railway como secreto; no pegarlo en conversaciones.

## 7. HUMAN BOUNDARY — variables Railway, primera conexión

Configurar en el servicio productivo, sin modificar `app/railway.json`:

```text
SENTINEL_ENABLED=true
SENTINEL_SENTRY_ENABLED=true
SENTINEL_SENTRY_CANARY_MODE=true
SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=true
SENTRY_DSN=<SECRET_IN_RAILWAY_ONLY>
SENTRY_ENVIRONMENT=production
NODE_OPTIONS=--require ./sentinel-sentry-init.cjs
```

No definir manualmente `SENTRY_RELEASE` salvo contingencia: el preloader deriva `ascenda-os@<sha>` desde `RAILWAY_GIT_COMMIT_SHA`.

## 8. Canary gate

Después del restart/deploy:

1. `/health` debe seguir respondiendo 200.
2. Sentry debe recibir `SENTINEL_F4_SYNTHETIC_ERROR`.
3. `environment` debe ser `production`.
4. `release` debe ser `ascenda-os@<RAILWAY_GIT_COMMIT_SHA>`.
5. tags mínimos: `system=ascenda-os`, `sentinel.phase=F4`, `service.name=server-phase-s.js`.
6. el evento no debe contener user, email, teléfono, DNI, IP de usuario, request body, cookies, Authorization, WhatsApp/email content, prompt/output IA, local variables ni source context.
7. mientras canary=true no debe exportarse un error real no sintético.

Luego poner `SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=false`.

## 9. Kill-switch proof

1. Poner `SENTINEL_SENTRY_ENABLED=false`.
2. Reiniciar/redeploy.
3. Confirmar `/health` 200 y uso normal de ASCENDA.
4. Confirmar que no aparece un nuevo synthetic event aunque el synthetic flag siga false.
5. Restaurar `SENTINEL_SENTRY_ENABLED=true` con canary=true.
6. Confirmar `/health` 200.

La caída/desactivación de Sentry nunca debe tumbar ASCENDA.

## 10. Activación real F4

Solo después del canary y kill-switch PASS:

```text
SENTINEL_SENTRY_SYNTHETIC_ON_BOOT=false
SENTINEL_SENTRY_CANARY_MODE=false
```

Mantener:

```text
SENTINEL_ENABLED=true
SENTINEL_SENTRY_ENABLED=true
SENTRY_ENVIRONMENT=production
NODE_OPTIONS=--require ./sentinel-sentry-init.cjs
```

Tracing/logging/replay continúan OFF.

## 11. Texto exacto para continuar después de la intervención humana

No incluir el DSN ni otros secretos. Enviar únicamente:

`LISTO F4-HUMAN-GATE: proyecto Sentry Node creado; data scrubbing e IP scrubbing activos; variables Railway cargadas sin compartir secretos; synthetic SENTINEL_F4_SYNTHETIC_ERROR visible con environment=production y release correcto; evento revisado sin PHI/PII/secrets; kill switch probado con /health=200. AUTORIZO cerrar canary y continuar el loop F4 hasta certificación.`

Si algún punto no está validado, no usar la palabra `LISTO`; enviar screenshot del punto donde quedó el proceso para continuar desde ahí.

## 12. Rollback

Rollback inmediato de observabilidad:

```text
SENTINEL_SENTRY_ENABLED=false
```

Rollback total Sentinel externo:

```text
SENTINEL_ENABLED=false
```

No es necesario modificar tablas, migraciones ni lógica de negocio.
