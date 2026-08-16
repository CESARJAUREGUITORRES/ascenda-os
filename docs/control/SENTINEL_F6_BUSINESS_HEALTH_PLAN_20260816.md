# Sentinel F6 — Business Health & Silent Failure Invariants

**Estado:** EN CURSO  
**Fecha:** 2026-08-16 (America/Lima)  
**Baseline:** `main@81da6ceb18ed35cca8acb0ac68b90dc6e9ed8aae`  
**Branch:** `feature/sentinel-f6-business-health`  
**Riesgo:** HIGH por proximidad a datos operativos; implementación baseline = read-only/aggregate-only.

## 1. Objetivo

Detectar fallos funcionales silenciosos donde HTTP, Railway o Sentry podrían seguir verdes. F6 no crea todavía incidentes persistentes ni alertas: produce **señales sanitizadas y deterministas** que F8 convertirá en `SEN-*` y F9 notificará.

## 2. Límite de seguridad

F6 baseline:

- no modifica producción;
- no crea tablas/RPC nuevas;
- no almacena pacientes, contactos ni contenidos;
- no recibe nombres, DNI, teléfonos, emails, mensajes, prompts, headers auth, cookies o secretos;
- no interpreta `0 ventas` o `0 llamadas` como falla por sí solo;
- requiere correlación/contexto para evitar falsos positivos;
- todo estado sin evidencia suficiente es `UNKNOWN`.

## 3. Recovery técnico realizado

Se contrastó GitHub con metadata de schema live, sin leer filas identificables.

### Call Center

Fuentes existentes verificadas:

- tablas `aos_leads`, `aos_llamadas`;
- RPC `aos_panel_admin`;
- RPC `aos_panel_asesor`;
- RPC `aos_monitoreo_equipo`;
- RPC `aos_siguiente_lead_v2`;
- UI productiva `app/public/calls.js` consume esos contratos.

### Sales

Fuentes existentes verificadas:

- tabla `aos_ventas`;
- endpoint seguro F4 `POST /api/f4/sales-intelligence-read`;
- RPC gobernada `aos_sales_intelligence_gateway`;
- panel `admin-sales-intelligence.html` es solo lectura.

### WhatsApp

Fuentes existentes verificadas:

- `aos_wa_conversations_v1` con `last_message_at`, `last_inbound_at`, `last_outbound_at`, `unread_count`, `message_count`;
- `aos_wa_outbound_requests_v1` con `state`, `provider_message_id`, `created_at`, `updated_at`;
- `aos_wa_messages_v1` con `status`, `sent_at`, `delivered_at`, `read_at`, `failed_at`;
- WA3 reserva `PENDING`, avanza a `ACCEPTED` y guarda provider message id;
- F4 procesa statuses Meta y materializa sent/delivered/read/failed.

### Email

Fuentes existentes verificadas:

- `aos_email_envios` con `estado`, `resend_id`, `enviado_at`, `created_at`;
- `aos_email_eventos` con `resend_id`, `tipo_evento`, `created_at`;
- `aos_email_flujo_ejecuciones` con estado/freshness;
- `email-gateway.js` expone `CONFIG_HEALTH` bajo sesión gobernada y usa Resend con idempotencia;
- `server-f4.js` maneja `/api/email-gateway`, `/api/send-email` y `/api/resend-webhook` en el boundary que conserva secretos.

## 4. Hallazgo importante: warning Email del child

El warning observado anteriormente `EMAIL_SERVICE_ROLE_NOT_CONFIGURED` **no puede clasificarse solo como caída del email**.

Razón: `server-f4.js` elimina intencionalmente `SUPABASE_SERVICE_ROLE_KEY` del entorno de su child antes de lanzar `server-phase2.js`, mientras el `EMAIL_GATEWAY` gobernado vive en F4 y conserva el secreto en su boundary. Por tanto:

- warning del child sin evidencia adicional = ruido/contexto, no incidente;
- `CONFIG_HEALTH` gobernado no listo = incidente real de configuración;
- envíos aceptados sin eventos de proveedor durante umbral = degradación/incidente de pipeline.

Esto evita un false-positive que Sentinel habría podido introducir si trataba logs de forma aislada.

## 5. Invariantes baseline

### F6-I01 — `callcenter.activity_stall`

No se activa por `0 llamadas` aislado. Requiere simultáneamente:

- ventana operativa activa;
- asesores activos > 0;
- backlog de leads elegibles > 0;
- ausencia o stale age de actividad.

Umbrales iniciales:

- >=30 min → `DEGRADED`;
- >=60 min → `INCIDENT`;
- sin contexto suficiente → `UNKNOWN`.

### F6-I02 — `sales.pipeline_consistency`

Compara dos superficies con el **mismo scope**:

- conteo fuente de ventas;
- resultado del gateway Sales Intelligence.

Reglas:

- fuente >0 pero gateway `hasData=false` → `INCIDENT`;
- ambos tienen data pero same-scope count diverge → `DEGRADED`;
- scope no probado equivalente → `UNKNOWN`;
- scope válido realmente vacío → `HEALTHY`, no false alarm.

### F6-I03 — `whatsapp.outbound_receipt_stall`

Correlaciona sends aceptados con progresión posterior de status:

- `ACCEPTED` sin progreso >=15 min → `DEGRADED`;
- >=60 min → `INCIDENT`;
- cero sends estancados → `HEALTHY`.

No lee cuerpo del mensaje ni números.

### F6-I04 — `email.provider_pipeline_health`

Requiere evidencia del gateway gobernado y del pipeline:

- feature intencionalmente deshabilitada/no esperada → `UNKNOWN`;
- service/provider/webhook config no listos mientras feature es esperada → `INCIDENT`;
- enviado con `resend_id` sin evento proveedor >=15 min → `DEGRADED`;
- >=60 min → `INCIDENT`;
- warning del child por privilegio reducido, con gateway sano → no altera `HEALTHY`.

## 6. Motor

`sentinel/business-health/invariant-engine.cjs`

Propiedades:

- input estricto por allowlist;
- solo boolean/number/null por dominio;
- rechaza keys no aprobadas y keys sensibles;
- evidencia emitida solo contiene agregados;
- fingerprints estables `business-health:<domain>:<invariant>`;
- estado global prioriza `INCIDENT > DEGRADED > UNKNOWN > HEALTHY`;
- no depende de Sentry;
- no persiste ni notifica.

## 7. Gates F6

| Gate | Criterio |
|---|---|
| F6-G01 Recovery | fuentes de los 4 dominios verificadas contra GitHub/schema metadata |
| F6-G02 Privacy | allowlist aggregate-only y negative test contra campo sensible |
| F6-G03 Call Center | anomalía sintética cambia solo Call Center a DEGRADED/INCIDENT |
| F6-G04 Sales | source-present/gateway-empty produce INCIDENT |
| F6-G05 WhatsApp | accepted-without-progress produce DEGRADED/INCIDENT por edad |
| F6-G06 Email | config/pipeline stall detectado; legacy child warning solo no dispara incidente |
| F6-G07 Valid empty | cero actividad legítima no se convierte automáticamente en incidente |
| F6-G08 Cross-platform | Windows FAST + Linux Zero-Cost ejecutan contrato/fixtures |
| F6-G09 Live aggregate preflight | consultas agregadas/read-only sin PII confirman que fuentes pueden calcularse |
| F6-G10 Exact-head CI | workflow F6 exact-head PASS |
| F6-G11 Scope | diff sin DB DDL, sin runtime mutation, sin secrets |
| F6-G12 Closure | certificado final + merge + post-merge PASS + Notion |

## 8. Próximo tramo

1. ejecutar CI F6;
2. correr preflight agregado live sin persistencia;
3. corregir cualquier false-positive detectado;
4. abrir PR F6;
5. exact-head PASS;
6. certificado y cierre solo si G01–G12 pasan.
