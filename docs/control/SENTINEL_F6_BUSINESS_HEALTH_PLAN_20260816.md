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

Se contrastó GitHub con metadata de schema live y consultas agregadas, sin devolver filas identificables.

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
- función agregada `STABLE` `aos_sales_intelligence_summary`;
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

## 4. Hallazgos de false-positive resueltos

### 4.1 Warning Email del child

El warning `EMAIL_SERVICE_ROLE_NOT_CONFIGURED` **no puede clasificarse solo como caída del email**.

`server-f4.js` elimina intencionalmente `SUPABASE_SERVICE_ROLE_KEY` del entorno del child antes de lanzar `server-phase2.js`, mientras el `EMAIL_GATEWAY` gobernado vive en F4 y conserva el secreto en su boundary. Por tanto:

- warning del child sin evidencia adicional = contexto, no incidente;
- `CONFIG_HEALTH` gobernado explícitamente no listo = incidente de configuración;
- config no verificada = `UNKNOWN`, no se infiere `HEALTHY` ni `INCIDENT`.

### 4.2 Historial Email no equivale a salud actual

El preflight agregado encontró 12 envíos históricos sin evento proveedor asociado. El registro más antiguo supera ampliamente la ventana operativa actual; si Sentinel leyera todo el historial sin horizonte, produciría un incidente falso.

La regla F6 v1.1 fija un **horizonte actual de 1,440 minutos (24 h)**:

- registros no emparejados fuera de la ventana no afectan el health live;
- quedan como deuda histórica/evidencia, no como alarma actual;
- dentro de la ventana, el pipeline solo puede declararse `HEALTHY` si `CONFIG_HEALTH` está verificado y existe actividad reciente que progresa correctamente;
- sin actividad reciente suficiente, o sin evidencia de configuración, el estado es `UNKNOWN`.

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
- resultado agregado de Sales Intelligence.

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

Usa exclusivamente agregados de una ventana reciente de 24 h y evidencia de configuración gobernada:

- feature no esperada → `UNKNOWN`;
- config gobernada no comprobada → `UNKNOWN`;
- config gobernada explícitamente incompleta mientras feature es esperada → `INCIDENT`;
- config sana pero cero sends recientes → `UNKNOWN` (`NO_RECENT_EMAIL_ACTIVITY`);
- al menos un send reciente y cero unmatched → `HEALTHY`;
- send reciente sin evento >=15 min → `DEGRADED`;
- >=60 min → `INCIDENT`;
- muestra fuera del horizonte → `UNKNOWN`;
- warning del child por privilegio reducido no cambia un health sano.

## 6. Preflight agregado live — 2026-08-16

Todas las consultas fueron read-only y devolvieron solo conteos/edades/booleanos.

### Call Center

- usuarios activos con código asesor: 10;
- leads del día: 0;
- llamadas del día: 0;
- no existe evidencia de backlog elegible que justifique declarar falla.

**Resultado Sentinel:** `UNKNOWN / NO_ELIGIBLE_BACKLOG`, no incidente.

### Sales

- conteo fuente 2026: `1299`;
- Sales Intelligence agregado 2026: `1299`;
- `hasData=true`;
- data through: `2026-08-15`;
- same-scope match: `true`.

**Resultado Sentinel:** `HEALTHY` para la consistencia evaluada.

### WhatsApp

- outbound `ACCEPTED` sin progresión: `0`;
- stalled >=15m: `0`;
- stalled >=60m: `0`.

**Resultado Sentinel:** `HEALTHY` para la progresión evaluada.

### Email

- envíos históricos sin evento: `12` — excluidos del health live por horizonte;
- sends dentro de 24 h: `1`;
- sends recientes sin evento: `1`;
- edad aproximada del unmatched reciente: ~20 h;
- `CONFIG_HEALTH` gobernado no fue verificado por esta consulta agregada.

**Resultado Sentinel:** `UNKNOWN / EMAIL_CONFIG_EVIDENCE_INCOMPLETE`. No se declara incidente sin la evidencia de configuración requerida.

## 7. Motor

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

## 8. Gates F6

| Gate | Criterio | Estado |
|---|---|---|
| F6-G01 Recovery | fuentes de los 4 dominios verificadas contra GitHub/schema metadata | PASS |
| F6-G02 Privacy | allowlist aggregate-only y negative test contra campo sensible | IMPLEMENTADO / CI |
| F6-G03 Call Center | anomalía sintética cambia solo Call Center a DEGRADED/INCIDENT | IMPLEMENTADO / CI |
| F6-G04 Sales | source-present/gateway-empty produce INCIDENT | IMPLEMENTADO / CI |
| F6-G05 WhatsApp | accepted-without-progress produce DEGRADED/INCIDENT por edad | IMPLEMENTADO / CI |
| F6-G06 Email | config/pipeline stall; horizonte reciente; legacy warning aislado no dispara incidente | IMPLEMENTADO / CI |
| F6-G07 Valid empty | cero actividad legítima no se convierte automáticamente en incidente | IMPLEMENTADO / CI |
| F6-G08 Cross-platform | Windows FAST + Linux Zero-Cost ejecutan contrato/fixtures | PENDIENTE EXACT-HEAD |
| F6-G09 Live aggregate preflight | consultas agregadas/read-only sin PII | PASS |
| F6-G10 Exact-head CI | workflow F6 exact-head PASS | PENDIENTE |
| F6-G11 Scope | diff sin DB DDL, sin runtime mutation, sin secrets | PENDIENTE FINAL |
| F6-G12 Closure | certificado final + merge + post-merge PASS + Notion | PENDIENTE |

## 9. Próximo tramo

1. ejecutar CI v1.1 en los tres runners;
2. corregir cualquier divergencia;
3. abrir PR F6;
4. revisar scope exacto;
5. exact-head PASS;
6. certificado terminal;
7. merge y post-merge PASS;
8. Notion F6 = `Cerrada / 100%`; F7 = única siguiente.
