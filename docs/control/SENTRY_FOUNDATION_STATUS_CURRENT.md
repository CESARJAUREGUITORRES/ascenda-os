# ASCENDA OS — SENTRY FOUNDATION STATUS

**Estado:** CONNECTED_EXTERNAL / RUNTIME_NOT_INSTRUMENTED  
**Fecha:** 2026-08-14 (America/Lima)

## Evidencia confirmada

1. Usuario confirma Sentry activo en ChatGPT mediante `@Sentry` / `https://mcp.sentry.dev/mcp`.
2. Captura de ChatGPT muestra plugin Sentry disponible para inspección read-only de issues/events.
3. Captura de Sentry muestra integración GitHub configurada para la cuenta/organización `CESARJAUREGUITORRES`.
4. Repo `CESARJAUREGUITORRES/ascenda-os` fue revisado y actualmente no contiene referencias a `@sentry` ni `SENTRY_DSN`.
5. El runtime de herramientas de esta conversación todavía no expone un tool Sentry invocable; por tanto no se certifica todavía lectura real de issues/events desde este chat.

## Estado por capa

### Capa 1 — ChatGPT ↔ Sentry
**Conexión visual confirmada por usuario.**
Pendiente smoke técnico desde una sesión donde el tool Sentry esté realmente expuesto.

### Capa 2 — Sentry ↔ GitHub
**Conexión confirmada por usuario/captura** para `CESARJAUREGUITORRES`.
Esto no implica por sí solo que ASCENDA envíe eventos a Sentry.

### Capa 3 — ASCENDA runtime ↔ Sentry
**NO INSTRUMENTADO todavía.**
Faltan SDK/DSN, environments, releases/source maps, PII scrubbing, tracing y smoke real desde staging.

## Regla de certificación

No declarar Sentry `OPERATIVO` para ASCENDA hasta demostrar:

- proyecto Sentry correcto para ASCENDA;
- DSN configurado mediante secretos/variables de entorno, nunca hardcodeado;
- SDK server-side en `app/server.js` o wrapper equivalente;
- SDK/browser instrumentation en `app/public/` cuando corresponda;
- environment tags (`staging`, `production`);
- release asociado a commit Git;
- PII/data scrubbing revisado;
- source maps/release artifacts según aplique;
- error controlado de staging recibido en Sentry;
- trace/performance smoke cuando se habilite;
- rollback/desactivación conocidos;
- GitHub/Notion/`aos_memory` sincronizados.

## Riesgo y privacidad

ASCENDA contiene datos clínicos/comerciales. Antes de instrumentar:

- no enviar historia clínica, notas, fotos, tokens, passwords, service-role keys ni payloads sensibles;
- revisar `sendDefaultPii`/user context antes de habilitar;
- sanear headers, query strings, request bodies y breadcrumbs;
- aplicar mínimo privilegio;
- separar staging/production;
- definir sampling de traces antes de activarlo ampliamente.

## Integración con roadmap CIA

Sentry es una capacidad transversal de observabilidad. Su hardening completo pertenece a F18, pero una **Sentry Foundation** básica puede ejecutarse antes de F10 si se quiere obtener telemetría durante F10–F17, siempre como mini-loop independiente y sin alterar el scope funcional de esas fases.

Estado CIA actual permanece:

- F0–F9 `100_COMPLETE`
- F10 Advisor Control Center `READY`
- no modificar `aos_siguiente_lead` antes de F11.
