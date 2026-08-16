# ASCENDA Conversations — PHASE S — WA-3 Stabilization & Human Outbound Certification

**Fecha:** 2026-08-15 (America/Lima)  
**Branch:** `phase-s/wa3-stabilization-human-outbound`  
**Base:** `main@047188a215aab15aac7991f640595e287880500e`  
**Objetivo:** convertir el éxito visible del Live Inbox en una operación bidireccional estable, nativa y certificable antes de habilitar WA-4 Copilot.

## 1. Scope

PHASE S se ejecuta entre WA-3 y WA-4 como gate de estabilización. No reemplaza WA-3; endurece su operación productiva.

Bloques:

- **S1 — Native WA-3 Bootstrap Stabilization**
- **S2 — Human Outbound Canary Certification**
- **S3 — Delivery / Read / Failure Receipts**
- **S4 — First Business Box & Canary Membership**
- **S5 — Repeated Reload / Recovery Exit Gate**

Kill-switches durante Phase S:

- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- WA-4 `copilot_enabled=false`;
- WA-4 `auto_reply_enabled=false`.

`human_send_enabled=true` permanece habilitado únicamente detrás de ownership + 2FA + canary allowlist.

## 2. S1 — Native bootstrap stabilization

### Problema

El WA-3 original ejecuta un bootstrap monolítico de control + boxes + members + users. Una falla transitoria de cualquier dependencia podía abortar la promesa y evitar que el inbox cargara, obligando al safety recovery WA-3→WA-2.

### Implementación Phase S

Se agrega `app/server-phase-s.js` como boundary externa:

`Railway → server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js`

La capa S intercepta únicamente:

- `GET /api/wa3/bootstrap`;
- `GET /api/phase-s/status`;
- `GET /health`.

El resto se proxifica sin modificación.

### Comportamiento

- reutiliza `aos_wa3_actor_v1` para autorización real;
- lee control/boxes/members/users de forma independiente;
- cada dependencia puede degradar sin tumbar las demás;
- si `control` falla, los tres controles de escritura degradan **OFF**;
- devuelve `stability.mode=NATIVE|DEGRADED` y componentes degradados;
- no habilita permisos ni bypass de ownership;
- recovery del shell permanece temporalmente como airbag.

`app/railway.json` cambia el start command a `node server-phase-s.js` y agrega healthcheck `/health`.

## 3. S2 — Human outbound certification

El sender ya existe en WA-3:

`POST /api/wa3/conversations/:id/send`

Requisitos acumulativos:

1. 2FA/panel válido;
2. owner exacto;
3. assignment `ACTIVE`;
4. estado `HUMAN_ACTIVE` o `AI_COPILOT`;
5. `human_send_enabled=true`;
6. recipient dentro de `WA_CANARY_ALLOW_TO` mientras canary esté ON;
7. `idempotency_key` válida;
8. Meta config completa.

### Exit evidence requerida

- mensaje enviado desde composer ASCENDA;
- HTTP/operación aceptada por Meta;
- `provider_message_id` persistido;
- fila `aos_wa_outbound_requests_v1` en `ACCEPTED`;
- fila `aos_wa_messages_v1` `OUTBOUND` ligada a la conversación;
- `message.human_accepted` en routing audit;
- retry con misma idempotency key no duplica.

**Estado actual:** preparado, requiere acción canary desde la sesión 2FA del propietario una vez desplegada Phase S.

## 4. S3 — Delivery receipts

WA-1/F4 ya procesa `statuses` Meta firmados:

- `sent` → `sent_at`;
- `delivered` → `delivered_at`;
- `read` → `read_at`;
- `failed` → `failed_at` + error.

El timeline WA-3 ya consulta `status`, `sent_at`, `delivered_at`, `read_at`, `failed_at`.

### Exit evidence requerida

Después de S2:

1. observar status webhook firmado para el mismo provider id;
2. verificar transición de la misma fila, no inserción duplicada;
3. confirmar timeline/status visible;
4. documentar latencia send→delivered→read cuando exista;
5. probar al menos un fail-closed/no-allowlist sin llamada válida a Meta.

## 5. S4 — First Business Box

### Ejecutado en producción

Se creó:

- `VENTAS_GENERAL` — **Ventas General WhatsApp**;
- estrategia: `MANUAL`;
- estado: `ACTIVE`;
- default: `true`;
- prioridad: `100`.

Miembro canary inicial:

- `CESAR`;
- capacidad `max_active=10`;
- prioridad `100`.

La conversación canary `zi vital` (`51960618468`) fue promovida desde `WA_TEST` a `VENTAS_GENERAL`, conservando owner CESAR y quedando `HUMAN_ACTIVE` con nueva versión de ownership.

`WA_TEST` no se borra: se conserva como evidencia/rollback hasta cierre de Phase S.

No se concedió `whatsapp-agent` a ningún trabajador adicional sin selección explícita.

## 6. S5 — Native reload exit gate

Después del deploy:

- 20 cargas/reloads consecutivos del WhatsApp Hub;
- inbox visible sin activation del recovery;
- `Routing & Handoff` renderizado en carga normal;
- `stability.mode=NATIVE` en `/api/phase-s/status`;
- ninguna degradación repetitiva;
- recovery permanece únicamente como safety net.

Si un componente aparece `DEGRADED`, diagnosticar ese componente sin ocultar el inbox.

## 7. CI

Workflow nuevo:

`.github/workflows/phase-s-wa3-stabilization.yml`

Valida en runner self-hosted Zero-Cost:

- syntax completa de la runtime chain;
- contratos Phase S;
- WA-1 gateway regression;
- WA-2 UI contract;
- WA-3 UI contract;
- fail-closed control defaults;
- ausencia de secretos hardcoded;
- Railway start/health contract.

## 8. Definition of Done Phase S

Phase S = `100_COMPLETE` únicamente cuando:

- CI exact-SHA PASS;
- deploy Railway healthy;
- bootstrap native repetido PASS;
- `VENTAS_GENERAL` visible y operativo;
- inbound real sigue visible;
- outbound humano real aceptado;
- provider id/timeline outbound persistidos;
- idempotency retry PASS;
- canary block PASS;
- delivery/read o, si Meta no entrega read en la ventana, delivery + evidencia documentada del estado alcanzado;
- ningún envío AI automático;
- checkpoint CURRENT actualizado.

## 9. Rollback

Runtime inmediato:

- restaurar Railway start command a `node server-f5.js`.

La capa S no añade schema ni altera contratos WA-1..WA-4.

Business box rollback operativo:

- mantener `VENTAS_GENERAL` PAUSED o conservarlo sin auto-routing;
- re-rutear la conversación canary si fuera necesario;
- no borrar routing events ni assignments históricos.

Nunca revertir a webhook unsigned ni borrar evidencia de mensajes.
