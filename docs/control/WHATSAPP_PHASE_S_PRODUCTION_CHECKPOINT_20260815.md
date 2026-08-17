# ASCENDA Conversations — PHASE S Production Checkpoint

**Fecha:** 2026-08-15 (America/Lima)  
**Estado:** S1 DEPLOYED / S4 LIVE / S2-S3 PENDING AUTHENTICATED CANARY  
**Merge:** `e2d0b292e033dd71f1508ce265de5e9551064766`

## 1. Cutover ejecutado

PR #176 `PHASE S — WA-3 native stabilization + human outbound gate` fue fusionado a `main` sobre el `main` actualizado que ya incluía F17.

Runtime productivo declarado:

`Railway → server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`

`app/railway.json`:

- start: `node server-phase-s.js`;
- healthcheck: `/health`;
- restart: `ON_FAILURE`.

Phase S no introduce migración ni objetos DB nuevos. Rollback runtime inmediato: volver a `node server-f5.js`.

## 2. Production smoke externo — PASS

Se ejecutó un probe desde runner self-hosted FAST contra `ascenda-os-production.up.railway.app`.

Contratos certificados:

1. `/health` respondió con:
   - `ok=true`;
   - `service=ascenda-phase-s`;
   - `child_alive=true`;
   - `inner_ready=true`.
2. `/app` respondió HTTP `200`.
3. `/api/phase-s/status` sin sesión respondió `403`.

Conclusión: el nuevo outer boundary está desplegado, la cadena interna está disponible y el diagnóstico Phase S mantiene el gate de autenticación.

## 3. S1 — Native WA-3 bootstrap

Implementado:

- `control`, `boxes`, `members` y `users` se leen como componentes independientes;
- una dependencia auxiliar degradada no debe ocultar el inbox;
- si `control` falla, todos los writes degradan OFF;
- respuesta incluye `stability.mode=NATIVE|DEGRADED` y componentes degradados;
- recovery WA-3→WA-2 se conserva temporalmente solo como safety net.

Pendiente de exit gate S1/S5:

- validar desde una sesión administrativa 2FA que el Hub carga nativamente;
- confirmar que ya no aparece `Recuperación automática` en operación normal;
- confirmar que `Routing & Handoff` renderiza normalmente;
- completar 20+ cargas/reloads sin fallback.

## 4. S4 — First Business Box — LIVE

Estado productivo verificado:

- box `VENTAS_GENERAL` / `Ventas General WhatsApp`;
- estrategia `MANUAL`;
- activo;
- default;
- CESAR como miembro canary;
- `max_active=10`;
- conversación `zi vital` / `51960618468` en `VENTAS_GENERAL`;
- conversación `HUMAN_ACTIVE`;
- owner CESAR;
- ownership version `2`;
- exactamente 1 assignment activo para owner actual.

`WA_TEST` se conserva para auditoría/rollback.

## 5. Safety state antes de S2

Verificado en producción:

- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- WA-4 Copilot permanece OFF;
- WA-4 auto-reply permanece OFF;
- outbound request ledger = `0` antes de la primera prueba humana.

Esto deja preparado un único camino de escritura: humano autorizado + owner exacto + assignment activo + 2FA + recipient canary allowlisted.

## 6. NEXT — S2

Requiere deliberadamente la sesión 2FA del propietario; no se debe bypassar desde CI ni service-role.

Canary:

1. entrar a ASCENDA → WhatsApp Hub;
2. abrir `zi vital`;
3. verificar composer habilitado y `VENTAS_GENERAL`;
4. enviar un único texto controlado: `Prueba PHASE S — respuesta humana desde ASCENDA.`;
5. inmediatamente reconciliar DB:
   - `aos_wa_outbound_requests_v1`;
   - `aos_wa_messages_v1`;
   - `aos_wa_routing_events_v1`;
6. verificar `provider_message_id`, `ACCEPTED`, timeline OUTBOUND e idempotencia.

Si Meta/canary rechaza el destinatario, mantener fail-closed y corregir configuración; no ampliar allowlist a terceros como workaround.

## 7. NEXT — S3

Después de S2:

- observar `sent` / `delivered` / `read` / `failed` para el mismo provider message id;
- verificar que se actualiza la misma fila;
- reconciliar timestamps;
- confirmar visualización en timeline;
- documentar highest achieved status si `read` no llega dentro de la ventana de prueba.

## 8. PHASE S completion rule

No declarar `100_COMPLETE` todavía.

Faltan:

- authenticated native reload gate S5;
- primer outbound humano real S2;
- idempotency/canary block;
- delivery receipt S3;
- checkpoint final y retiro del recovery como dependencia normal.

## 9. Revalidación PRE-S2 — 2026-08-17

Antes de iniciar el primer outbound humano se revalidó producción contra Supabase real y `main` actual.

Estado medido:

- `aos_wa_outbound_requests_v1`: `0`;
- mensajes `OUTBOUND`: `0`;
- mensajes `INBOUND`: `2`;
- routing events: `7`;
- AI runs: `0`;
- `VENTAS_GENERAL` sigue activo;
- `zi vital` / `51960618468` sigue `HUMAN_ACTIVE`;
- owner sigue siendo CESAR;
- `ownership_version=2`;
- exactamente `1` assignment `ACTIVE`.

Los routing events 5–7 son esperados y corresponden únicamente a:

1. creación/actualización de `VENTAS_GENERAL`;
2. membership canary de CESAR;
3. promoción manual de la conversación canary al business box.

Safety vigente:

- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- WA-4 `copilot_enabled=false`;
- WA-4 `auto_reply_enabled=false`.

El sender humano actual fue auditado antes de S2 y exige acumulativamente:

- token fuerte de panel / sesión 2FA;
- autorización `aos_wa3_human_send_authorize_v1`;
- owner exacto;
- conversación en `HUMAN_ACTIVE` o `AI_COPILOT`;
- assignment `ACTIVE` del mismo owner;
- `human_send_enabled=true`;
- recipient dentro de la canary allowlist;
- idempotency key válida;
- configuración Meta outbound completa.

La persistencia exitosa debe producir:

- outbound request `ACCEPTED`;
- `provider_message_id` Meta;
- mensaje `OUTBOUND` ligado a la conversación;
- evento `message.accepted`;
- routing event `message.human_accepted`.

La idempotencia está respaldada además por índices únicos sobre `aos_wa_outbound_requests_v1.idempotency_key`, `aos_wa_messages_v1.idempotency_key` y `aos_wa_messages_v1.provider_message_id`.

Observabilidad actual:

Railway mantiene PHASE S como outer runtime y `main` ahora precarga Sentinel/Sentry antes de `server-phase-s.js` mediante `NODE_OPTIONS='--require ./sentinel-sentry-init.cjs'`. Esto agrega observabilidad sin cambiar el contrato WA-3 de envío.

**NEXT sigue siendo S2 autenticado.** No existe evidencia de un outbound parcial previo que deba limpiarse o reconciliarse antes de la prueba.