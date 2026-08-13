# ASCENDA OS — COMMERCIAL INTELLIGENCE
## PHASE 05 VALIDATION REPORT — PANEL CENTRAL

**Fecha de validación:** 2026-08-13  
**Proyecto Supabase:** `ituyqwstonmhnfshnaqz`  
**Rama:** `feature/commercial-intelligence-phase5-panel-20260813`

---

# 1. RESULTADO

Fase 5 es certificable cuando este reporte, CI, staging y checkpoint final estén persistidos.

El loop cerró además deuda física heredada de Fases 1–4 y un incidente operacional detectado durante el deployment.

---

# 2. FOUNDATION DEPLOYMENT GATE — FASES 1–4

Los contratos que anteriormente estaban versionados/read-only fueron desplegados y verificados físicamente en el proyecto live.

## Identity Resolver

- contactos lógicos: **11,473**
- RESOLVED: **7,041**
- CONFLICT: **23**
- FUSED_ONLY: **10**
- NO_PATIENT_PROFILE: **4,399**

## Commercial Facts

1:1 por `contact_key`, **11,473** filas.

## Segmentation

- STANDARD **11,344**
- PREMIUM **95**
- GOLD **21**
- DIAMANTE **13**

## Audience baselines

Baselines históricos del gate inicial:

- LEADS_UNWORKED **1,287**
- LEADS_UNWORKED_7D **115**
- NO_SHOW_NO_FUTURE **826**
- FOLLOWUP_OVERDUE **442**

Última lectura final:

- LEADS_UNWORKED **1,287**
- LEADS_UNWORKED_7D **115**
- NO_SHOW_NO_FUTURE **824**
- FOLLOWUP_OVERDUE **442**

`NO_SHOW_NO_FUTURE` cambió por actividad real. La consulta directa actual sobre `aos_cia_appointment_facts_v1` también devuelve **824**, por lo que existe paridad exacta y no regresión.

---

# 3. RUNTIME RESOLVER V2

## Problema detectado

El RPC V1 físicamente desplegado llegó a ~**30.4 s** para un count representativo porque serializaba una mega-vista transversal a JSON y evaluaba PL/pgSQL fila por fila.

No se incrementó `statement_timeout` como workaround.

## Corrección

V2:

- resuelve leaves por dominio;
- combina `contact_key[]` con INTERSECT/UNION;
- preserva defaults de dominios ausentes;
- conserva `MATCH / MISS / UNKNOWN`;
- no usa raw SQL generado;
- Preview enriquece únicamente la página resuelta.

## Defaults verificados

- `lead.count = 0` → **6,397**
- `calls.total = 0` → **5,588**
- `appointments.total = 0` → **10,316**
- `sales.total = 0` → **11,177**
- llamada inexistente / fecha desconocida → **5,588**
- `calls.ever_statuses NOT_CONTAINS NO LE INTERESA` → **8,941**

---

# 4. PRODUCT / SERVICE TRI-STATE

Beauty Maker Explain:

- comprador probado → **MISS** para `never_contains`
- evidencia de producto no resuelta → **UNKNOWN**
- ausencia probada → **MATCH**

Conteos certificados previamente:

- BEAUTY MAKER: 26 bought / 11,387 never-safe / 60 UNKNOWN
- ISDIN: 20 / 11,392 / 61
- ENZIMAS: 21 / 11,404 / 48

No se convierte UNKNOWN en falso negativo seguro.

---

# 5. VALIDATOR / SAFETY

Último gate:

- field no permitido → `FIELD_NOT_ALLOWED` PASS
- operador incompatible → `OPERATOR_NOT_ALLOWED` PASS
- max rules declarado → **25**
- max group depth declarado → **2**
- gateway con token inválido → `UNAUTHORIZED` PASS
- Preview solicitado con 500 → backend fuerza **100**
- respuesta → `limit=100`, `items_count=100`, total de audiencia 1,287

---

# 6. PERFORMANCE FINAL — POST HOTFIX

Mediciones `EXPLAIN (ANALYZE, TIMING OFF)` sobre live:

- `LEADS_UNWORKED` COUNT V2: **231.808 ms** warm
- `LEADS_UNWORKED` PREVIEW 50: **402.314 ms** warm
- Explain representativo `calls.never_called`: **1,063.353 ms**

Objetivos:

- normal P95 < 1.5 s → PASS
- complex/preview P95 < 2.5 s → PASS en escenarios probados
- preview ≤100 → PASS

---

# 7. INCIDENTE CALL CENTER — RCA Y CIERRE

## Síntoma

Asesores podían obtener leads, pero `Guardar resultado` fallaba.

API:

`POST /rest/v1/aos_llamadas → 401`

Postgres:

`permission denied for function aos_cia_normalize_contact_key_v1`

## Causa

Índices funcionales experimentales en tablas operativas dependían de una función CIA privada. Después de cerrar EXECUTE a `anon/authenticated`, Postgres necesitaba igualmente ejecutar la función para mantener esos índices durante INSERT.

## Reparación

1. retirar los siete índices inseguros;
2. validar INSERT rollback-only con `SET ROLE anon`;
3. crear índices funcionalmente equivalentes con **expresiones SQL built-in nativas**, sin depender de EXECUTE CIA;
4. repetir INSERT rollback-only con safe indexes activos;
5. verificar uso de índice por planner;
6. observar tráfico real.

## Evidencia operativa

Después del hotfix y después de las correcciones finales:

- `POST /rest/v1/aos_llamadas → 201`
- `POST /rpc/aos_siguiente_lead → 200`

Ejemplo final observado:

**2026-08-13 17:45:50 UTC / 12:45:50 Lima** → llamada guardada `201` por navegador real de Call Center.

**Estado: INCIDENT CLOSED.**

El 401 periódico de `aos_studio_contenido` es un incidente distinto/preexistente y no forma parte del flujo Call Center ni de Fase 5.

---

# 8. CACHES / FRESHNESS

Operational Facts: **LIVE**.

Caches explícitos:

- `aos_cia_segment_runtime_cache_v2`
- `aos_cia_email_runtime_cache_v2`

Último refresh físico del gate:

- Segment: **11,473 rows** PASS
- Email: **11,473 rows** PASS

Se corrigió un bug detectado en aceptación: el source field real es `calculated_at`; el target cache usa `segment_calculated_at`.

No se declara scheduler automático: `pg_cron/pg_net` no están instalados. El panel expone refresco administrativo explícito y timestamp de frescura.

---

# 9. ACL / AUTHORIZATION

Direct resolver RPCs:

- `aos_cia_audience_count_v2` → service_role only
- `aos_cia_audience_preview_v2` → service_role only
- `aos_cia_audience_explain_v2` → service_role only
- `aos_cia_verify_admin_session_v1` → service_role only

Browser-visible controlled RPCs:

- `aos_cia_claim_admin_session_v1`
- `aos_cia_admin_gateway_v1`

Gateway verifica una sesión CIA cuyo `user_id` debe corresponder en runtime a `aos_usuarios.activo=true` y `rol=admin`.

KronIA legacy token RPCs fueron endurecidos live a `service_role` only. `aos_kronia_tokens` tenía **0 sesiones activas** al aplicar el cambio. Estas funciones son objetos legacy live y no son dependencia del panel CIA; el repositorio actual no contiene su DDL original, por lo que el control de cierre es ACL live verificado, no replay de creación.

Limitación heredada global: `aos_login_v2` entrega el challenge 2FA al frontend porque el flujo existente usa el navegador para solicitar su envío. Fase 5 no se declara como sustitución del sistema de autenticación global. La autorización CIA sí agrega verificación server-side de ADMIN y token hashado separado.

---

# 10. UI / INTEGRATION

PASS:

- nueva página `app/public/admin-audiencias.html`
- Dashboard
- Presets
- Constructor DSL
- Segmentación
- Count / Preview / Explain
- freshness visible
- future areas locked
- Guardar audiencia locked until Phase 6
- responsive layout
- no native `alert/confirm/prompt` para operaciones críticas del constructor; errores no destructivos usan UI/alert legacy only
- no direct read de source tables para datos CIA: panel usa gateway

Marketing:

- original JS preservado como `admin-marketing-v2-original.js`
- wrapper carga el original
- ADMIN recibe acceso `Bases & Audiencias`
- `app.html` no fue modificado durante jornada activa

---

# 11. ROLLBACK

Frontend rollback:

- restaurar `admin-marketing-v2.js` desde original
- retirar `admin-audiencias.html`

DB rollback:

- objetos Phase 5 son aditivos/read-only respecto a fuentes operativas;
- safe native indexes pueden eliminarse sin data rewrite;
- retirar gateway/session/cache objects no modifica `aos_llamadas`, leads, agenda, ventas, pacientes ni seguimientos.

---

# 12. CIERRE

Gates funcionales y técnicos: **PASS**.

Para marcar oficialmente `100_COMPLETE` deben existir, además:

1. PR a staging;
2. CI success;
3. staging validation;
4. roadmap actualizado;
5. `aos_memory` checkpoint final.

Siguiente fase: **Fase 6 — Audience Library Persistence**.
