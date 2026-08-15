# ASCENDA Conversations — WA-3 Impact Report

**Fase:** WA-3 — Boxes, Routing & Human Handoff  
**Fecha:** 2026-08-15  
**Baseline:** WA-2 100% PRODUCTION CERTIFIED · `main@c5781f439a688b3df3937cc827f859b8fde834ae`  
**Riesgo:** HIGH  
**Estrategia:** additive + fail-closed + Zero-Cost certification

## Objetivo
Convertir el Live Inbox WA-2 en una cola operativa gobernada sin crear un segundo CRM ni reutilizar indebidamente la cola de llamadas. WA-3 introduce boxes, membership, ownership de conversación, takeover/release/reassign, `AI_COPILOT` y un sender humano que exige ownership exacto.

## Invariantes
1. Una conversación tiene como máximo un episodio current `QUEUED/ACTIVE`.
2. `HUMAN_ACTIVE` y `AI_COPILOT` requieren owner.
3. Un humano solo puede enviar si es el owner actual, posee panel+2FA, existe assignment ACTIVE y `human_send_enabled=true`.
4. `AI_ACTIVE` no puede ser activado por WA-3.
5. `ai_send_enabled` está físicamente restringido a `false` durante WA-3.
6. Release nunca devuelve control automático a IA: deja `HUMAN_REQUESTED`.
7. Routing automático inicia OFF.
8. Human send inicia OFF y conserva además el canary allowlist de WA-1.
9. No se auto-concede `whatsapp-agent` a usuarios.
10. Routing events son append-only.

## Reutilización sin duplicación
Se reutilizan patrones certificados de CIA F9–F11: ownership/claim, capacidad, fallback, readiness y auditoría. No se reutiliza `aos_siguiente_lead_v3`, ni `aos_cia_assignments` como store WhatsApp, ni se mezclan leads de call center con conversaciones WhatsApp.

## Nuevos objetos
- `aos_wa_routing_control_v1`
- `aos_wa_boxes_v1`
- `aos_wa_box_members_v1`
- `aos_wa_assignments_v1`
- `aos_wa_routing_events_v1`
- columnas WA-3 en `aos_wa_conversations_v1`: `box_id`, `owner_user_id`, `ownership_version`, `handoff_requested_at`, `human_takeover_at`
- panel `whatsapp-agent`, sin grants automáticos

## Routing
- `MANUAL`: conversación entra `QUEUED` y un miembro la reclama.
- `LEAST_ACTIVE`: selecciona miembro activo con menor carga, respetando `max_active`, prioridad y `last_assigned_at`.
- un box default puede recibir auto-routing cuando el kill switch global se habilite.
- claim usa `FOR UPDATE SKIP LOCKED`.

## Handoff / mode lock
- `HUMAN_REQUESTED`: IA no puede enviar; conversación en espera/cola.
- `HUMAN_ACTIVE`: solo owner humano puede enviar.
- `AI_COPILOT`: IA puede sugerir en una fase posterior, pero el envío sigue siendo humano/owner.
- `AI_ACTIVE`: rechazado por contrato WA-3.

## Sender humano
WA-3 no ensancha `/api/wa/send`. Crea un sender owned bajo `/api/wa3/conversations/:id/send` que reutiliza:
- payload oficial WA-1;
- idempotency ledger `aos_wa_outbound_requests_v1`;
- canary allowlist;
- `aos_wa_messages_v1`;
- `aos_wa_events_v1`.

Añade además evidencia `message.human_accepted` en `aos_wa_routing_events_v1`.

## Runtime
Cadena productiva prevista:

```text
Railway
  → server-wa3.js
     → server-wa2.js
        → server-f4.js
           → server-phase2.js
```

Los contratos F4/WA-2 se modifican únicamente para aceptar esta cadena explícita. No se permite un wrapper arbitrario.

## UI
`server-wa3.js` servirá `admin-whatsapp-wa3.html` en `/admin-whatsapp.html`.
- Admin: todas las conversaciones, boxes, membership, routing, reassign, control canary.
- Agente: solo owned conversations + “Tomar siguiente” de sus boxes.
- Browser sin Supabase/Graph/secrets directos.
- Composer bloqueado salvo ownership válido + human send ON.

## Seguridad
- exact panel + PASSWORD_2FA mediante `aos_app_actor_v3`;
- admin WA-3 requiere `admin-whatsapp` + nivel <=2;
- agente requiere `whatsapp-agent` explícito;
- FORCE RLS en todos los objetos nuevos;
- tablas service-only;
- mutations service-only;
- token RPCs security-definer de alcance mínimo;
- audit append-only;
- rate limit server-side;
- canary de destinatarios WA-1 sigue vigente.

## Recovery
Rollback operativo:
1. auto routing OFF;
2. human send OFF;
3. AI OFF;
4. elimina trigger auto-route;
5. current assignments → `RELEASED`;
6. owner se limpia y chats humanos → `HUMAN_REQUESTED`;
7. revoca panel `whatsapp-agent`;
8. elimina funciones activas WA-3;
9. conserva boxes/assignments/events para evidencia;
10. WA-2 y WA-1 permanecen intactos.

Rollback runtime: volver Railway de `server-wa3.js` a `server-wa2.js`.

## Gates de certificación
- syntax/runtime PASS;
- WA-1 regression PASS;
- WA-2 contract PASS;
- F4 contract PASS;
- exact WA-1 → WA-2 → WA-3 migrations en Supabase efímero;
- DB lint error-level PASS;
- >=60 assertions pgTAP y 0 `not ok`;
- routing/capacity/claim/release/reassign/mode/send-auth/audit PASS;
- rollback fail-closed PASS;
- PR exact-SHA green;
- post-merge CI green;
- production RLS/grants/control OFF verificados;
- Railway smoke: WA-3 page 200, unauth API 403, WA-1 signature boundary intact;
- canary administrativo sin enviar a pacientes reales.

## Cutover inicial
Al desplegar WA-3:
- `auto_routing_enabled=false`;
- `human_send_enabled=false`;
- `ai_send_enabled=false`;
- no boxes de negocio sembrados automáticamente;
- no agentes nuevos autorizados automáticamente.

La activación operativa de boxes y human send se hará después del smoke, con admin canary y sin usar pacientes reales como prueba.
