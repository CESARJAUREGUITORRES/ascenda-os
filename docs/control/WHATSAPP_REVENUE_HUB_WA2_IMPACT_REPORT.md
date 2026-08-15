# ASCENDA Conversations — WA-2 Conversation Store & Live Inbox — Impact Report

**Fecha:** 2026-08-15 (America/Lima)  
**Riesgo:** CRITICAL (RLS/GRANT, permisos de panel y cambio de entrypoint Railway)  
**Base inicial de desarrollo:** `main@843be04aaac304ed049ac5d2f8efe4a7c76ae0f8`  
**Branch:** `feature/wa2-conversation-live-inbox`  
**Dependencia:** WA-1 Secure WhatsApp Gateway desplegado y fail-closed. El canary Meta real de WA-1 continúa como gate externo separado.

## 1. Objetivo

Convertir el ledger seguro WA-1 en un store conversacional consultable y en un Live Inbox administrativo, sin mezclar pacientes externos con el chat interno `aos_canales/aos_mensajes`, sin exponer service-role al navegador y sin habilitar todavía respuesta humana/IA.

WA-2 V1 es deliberadamente **read-mostly**:

- proyecta mensajes WA-1 a conversaciones;
- muestra lista, mensajes, estado y provenance;
- permite únicamente `mark read` como escritura de UI;
- no envía WhatsApp;
- no asigna asesores;
- no cambia estado comercial;
- no ejecuta IA;
- no toca agenda, leads, pacientes, ventas ni Call Center.

Esas capacidades pertenecen a WA-3+.

## 2. Decisión de arquitectura

### No reutilizar chat interno

`aos_canales` y `aos_mensajes` ya son la fuente operativa de Coordinación entre personal. Reutilizarlos para pacientes WhatsApp mezclaría identidades, ACL y semánticas incompatibles.

WA-2 agrega:

- `aos_wa_conversations_v1` — proyección canónica de conversación;
- `aos_wa_conversation_events_v1` — auditoría/actividad interna append-only;
- `aos_wa_messages_v1.conversation_id` — enlace determinístico del ledger WA-1;
- `aos_wa2_bind_conversation_v1()` — bind idempotente sin efectos sobre contadores;
- `aos_wa2_project_message_v1()` — proyección post-insert/backfill que actualiza métricas una sola vez.

El ledger `aos_wa_messages_v1` continúa siendo evidencia de mensaje; la conversación es una proyección operativa, no una copia de mensajes.

### Preservación de idempotencia WA-1

PostgreSQL ejecuta triggers `BEFORE INSERT` incluso cuando un `INSERT ... ON CONFLICT` termina resolviéndose como update. Por eso WA-2 separa deliberadamente **bind** de **projection**:

1. el trigger BEFORE solo obtiene/crea la conversación y asigna `conversation_id`;
2. no toca `message_count`, `unread_count` ni latest state;
3. la proyección se ejecuta AFTER INSERT únicamente para filas realmente nuevas;
4. el backfill se proyecta únicamente en transición real `conversation_id NULL → UUID`.

Resultado: un retry del mismo `provider_message_id` puede actualizar el ledger WA-1 sin inflar métricas conversacionales.

## 3. Conversation key V1

`conversation_key = phone_number_id + ':' + contact_number_normalizado`

Ventajas:

- una conversación por número/contacto y número WABA receptor;
- evita mezclar futuras líneas WhatsApp distintas;
- no necesita inferencia por nombre;
- conserva `lead_id`, `campaign_source` y `ad_id` si existen, sin fabricar atribución.

WA-2 no altera `numero_limpio` en tablas core. La resolución avanzada persona/touchpoint sigue en WA-6/WA-7.

## 4. Estado, orden temporal y contadores

Estados permitidos V1:

`NEW`, `AI_ACTIVE`, `HUMAN_REQUESTED`, `HUMAN_ACTIVE`, `AI_COPILOT`, `WAITING_CUSTOMER`, `APPOINTMENT_PENDING`, `APPOINTMENT_BOOKED`, `WON`, `LOST`, `CLOSED`.

En WA-2 solamente se inicializa/reabre `NEW`; WA-3/WA-4 introducirán las transiciones gobernadas.

La proyección mantiene:

- `message_count` una vez por fila real del ledger;
- `unread_count` solo para inbound posterior a `last_read_at`;
- first inbound/outbound como mínimos por provider timestamp;
- last inbound/outbound como máximos por provider timestamp;
- último mensaje/preview/status únicamente si el evento es temporalmente igual o más nuevo;
- contacto y provenance inicial;
- reapertura `CLOSED → NEW` solo si el inbound es posterior al `closed_at`.

Esto evita que entregas retrasadas o reordenadas por proveedor retrocedan el inbox, reabran chats antiguos o creen falsos no-leídos.

No se incrementan contadores por delivery/read status updates de un mensaje ya existente.

## 5. Seguridad

### Base de datos

Las dos tablas WA-2:

- `ENABLE RLS`;
- `FORCE RLS`;
- `PUBLIC`, `anon`, `authenticated` sin acceso directo;
- acceso server-side exclusivamente mediante `service_role`.

Las funciones trigger:

- no son `SECURITY DEFINER`;
- tienen `search_path` fijado;
- no tienen EXECUTE para `PUBLIC/anon/authenticated`.

### API

`app/server-wa2.js` envuelve a `server-f4.js`; no sustituye WA-1.

Endpoints:

- `GET /api/wa/inbox`;
- `GET /api/wa/inbox/health`;
- `GET /api/wa/conversations/:id/messages`;
- `POST /api/wa/conversations/:id/read`.

Cada endpoint exige:

1. token fuerte server-verificado;
2. `aos_app_actor_v3(... p_required_panel='admin-whatsapp', p_require_2fa=true)`;
3. segunda verificación server-side: usuario activo y `nivel_jerarquia <= 2`.

Esto evita que una asignación accidental del panel convierta a un asesor no-admin en lector del inbox.

Se agregan límites de resultados y rate guard in-memory; autorización nunca depende del navegador.

### Frontend

`app/public/admin-whatsapp.html`:

- no contiene Supabase URL/keys;
- no llama PostgREST directamente;
- solo consume same-origin `/api/wa/*`;
- utiliza token fuerte ya emitido por ASCENDA;
- muestra gate si no existe sesión válida;
- escapa contenido antes de renderizarlo;
- no posee composer operativo en WA-2.

## 6. Acceso canary

Se registra `admin-whatsapp` en `aos_paneles_disponibles` para que el control futuro use el mismo sistema de permisos de ASCENDA.

El cutover WA-2 asigna automáticamente el panel **solo a administradores nivel 1, activos y con 2FA**. Administradores nivel 2 no se activan automáticamente; podrán recibirlo después mediante el panel de Equipo y autorización explícita.

El Live Inbox V1 es shadow page `/admin-whatsapp.html`; no se modifica todavía el shell masivo `app.html`. Esto reduce superficie de regresión. La integración visual/sidebar y distribución a asesores pertenece a WA-3.

## 7. Performance / costo

No se introduce infraestructura nueva ni Realtime pagado.

V1 usa polling adaptativo:

- 2.5 s con pestaña visible;
- 12 s cuando está oculta;
- mensajes de conversación solo se refrescan activamente cuando la pestaña está visible;
- búsqueda con debounce;
- resultados server-side acotados.

Esto permite medir tráfico real antes de decidir si Supabase Realtime aporta suficiente valor para justificar complejidad/costo operacional.

## 8. Zero-Cost certification

Workflow: `.github/workflows/wa2-conversation-live-inbox.yml`.

Debe demostrar:

- runner self-hosted Zero-Cost;
- sintaxis Node;
- WA-1 unit/regression;
- compatibilidad F4, incluida composición certificada `server-wa2 → server-f4`;
- contratos UI/server;
- Supabase efímero aislado;
- prerequisite schema sintético sin PII;
- migración WA-1 exacta;
- mensaje sintético creado antes de WA-2 para probar backfill;
- migración WA-2 exacta;
- DB lint;
- **51 contratos pgTAP** de RLS, proyección, idempotencia, contadores, orden temporal, reapertura, provenance y canary permission;
- recovery fail-closed de los tres triggers y dos funciones;
- preservación de evidencia tras recovery;
- destrucción del entorno.

## 9. Cutover productivo

Solo después de Zero-Cost verde y preflight live read-only:

1. confirmar `main` CURRENT y ausencia de colisión con workstreams paralelos;
2. fusionar PR WA-2;
3. aplicar migración WA-2 exacta a Supabase productivo;
4. esperar deploy Railway `node server-wa2.js`;
5. smoke negativo: `/api/wa/inbox` sin token → `403` con header WA2;
6. regresión WA-1: `/webhook` inválido → `403`, unsigned POST → `401`;
7. smoke autorizado nivel-1 2FA de shadow page;
8. verificar empty state legítimo si aún no existe tráfico Meta;
9. verificar que no haya acceso directo `anon/authenticated` a store;
10. documentar checkpoint/rollback.

## 10. Recovery / rollback

### Runtime inmediato

Revertir Railway a `node server-f4.js`. WA-1 continúa operativo; WhatsApp inbound/outbound no depende de WA-2.

### DB fail-closed

`supabase/rollbacks/20260815175500_wa2_conversation_live_inbox_v1.rollback.sql`:

- desactiva bind + proyección insert + proyección backfill;
- elimina las dos funciones WA-2;
- elimina acceso `admin-whatsapp` de usuarios y catálogo;
- **no borra** conversaciones/mensajes ya capturados;
- mantiene tablas con FORCE RLS y client roles revocados.

No se usa `DROP TABLE` como recovery productivo: preservar evidencia es preferible a perder contexto.

## 11. Gate de salida WA-2

WA-2 solo puede declararse `100% PRODUCTION CERTIFIED` cuando:

- CI/Zero-Cost exact-SHA esté verde;
- migración live esté aplicada y verificada;
- Railway sirva el wrapper WA-2;
- regresión WA-1 siga verde;
- usuario admin nivel-1 con 2FA pueda abrir el inbox y un no autorizado no pueda leer datos;
- recovery esté probado/documentado;
- Notion y CURRENT reflejen el estado real.

Un inbox vacío por ausencia de mensajes Meta no es un fallo WA-2; el evento firmado Meta sigue siendo gate operativo de WA-1 y permitirá poblar WA-2 automáticamente cuando ocurra.
