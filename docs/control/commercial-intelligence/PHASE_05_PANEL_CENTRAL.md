# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## FASE 5 — PANEL CENTRAL `BASES & AUDIENCIAS`

**Fecha:** 2026-08-13  
**Estado objetivo:** `100_COMPLETE` tras PR + CI + staging + checkpoint.  
**Scope:** ADMIN-only, read-only. La persistencia de audiencias pertenece a Fase 6.

---

## 1. OBJETIVO

Introducir una interfaz central para explorar, validar y previsualizar audiencias universales sin modificar fuentes operativas, sin duplicar lógica de filtros en frontend y sin alterar Call Center, Email o Marketing.

La audiencia pertenece a ASCENDA, no a un canal.

---

## 2. CONTRATO DE EJECUCIÓN

El navegador no consulta tablas CIA privadas ni ejecuta SQL.

Flujo:

`ADMIN → reautenticación → CIA session → aos_cia_admin_gateway_v1 → Resolver V2`

Acciones permitidas por gateway en Fase 5:

- `BOOTSTRAP`
- `VALIDATE`
- `COUNT`
- `PREVIEW`
- `EXPLAIN`
- `REFRESH_SEGMENTS`
- `REFRESH_EMAIL`

Todo lo demás devuelve `ACTION_NOT_ALLOWED`.

Los RPC internos `count / preview / explain` permanecen `service_role` only.

---

## 3. RUNTIME RESOLVER V2

V1 era semánticamente correcto pero físicamente ineficiente por construir una mega-vista transversal para cada audiencia.

V2 resuelve por dominios:

- cada leaf del DSL produce `contact_key[]`;
- `AND` = intersección;
- `OR` = unión;
- defaults de dominios ausentes se preservan;
- no existe SQL arbitrario generado desde frontend/IA;
- `never_contains` conserva `MATCH / MISS / UNKNOWN`;
- Preview primero resuelve claves y luego enriquece máximo 100 contactos.

Operational facts permanecen LIVE. Segmentación y Email Engagement usan caches explícitos con `cache_refreshed_at`.

---

## 4. INTERFAZ

Archivo principal:

`app/public/admin-audiencias.html`

Secciones habilitadas:

1. Dashboard
2. Presets
3. Constructor
4. Segmentación

Secciones visibles pero bloqueadas por fase:

- Distribución
- Activaciones
- Solicitudes / Gobernanza

El Constructor:

- consume `aos_audience_filter_registry` vía `BOOTSTRAP`;
- genera DSL, nunca SQL;
- soporta root `AND / OR`;
- máximo 25 reglas;
- valida antes de resolver;
- permite Count + Preview;
- Preview máximo 100 por contrato backend;
- Explain muestra `MATCH / MISS / UNKNOWN`;
- **Guardar audiencia está bloqueado** hasta Fase 6.

---

## 5. INTEGRACIÓN CON MARKETING

Para minimizar blast radius durante operación activa no se modificó el shell monolítico `app.html`.

Se preservó el JS Marketing original byte-identical como:

`app/public/admin-marketing-v2-original.js`

`app/public/admin-marketing-v2.js` se convierte en adapter que carga el original y agrega exclusivamente para ADMIN el acceso:

**🧠 Bases & Audiencias**

El módulo central abre en una página independiente. Call Center no comparte código con esta integración.

---

## 6. AUTORIZACIÓN

La sesión normal del frontend solo sirve como gate UX. No autoriza el gateway.

El gateway exige una CIA Admin Session:

- token aleatorio;
- solo hash SHA-256 almacenado en DB;
- expiración 8h;
- `user_id` debe seguir activo;
- `aos_usuarios.rol = admin` verificado server-side;
- reautenticación del módulo requiere credenciales + flujo 2FA existente;
- token CIA se guarda en `sessionStorage`, no `localStorage`.

Limitación heredada registrada: el login global actual entrega el challenge 2FA al frontend para que este invoque el envío por email. Fase 5 no amplía ese patrón fuera de la reautenticación del módulo; su reemplazo global corresponde al hardening transversal de autenticación, no al motor de audiencias.

---

## 7. PERFORMANCE

Objetivos de diseño:

- Count normal P95 < 1.5 s
- Preview complejo P95 < 2.5 s
- Preview máximo 100

Último benchmark físico warm sobre live, 2026-08-13:

- `LEADS_UNWORKED` COUNT: ~231.808 ms
- `LEADS_UNWORKED` PREVIEW 50: ~402.314 ms
- Explain `calls.never_called`: ~1.063 s

---

## 8. WRITE-SAFETY

Durante el loop se detectó que índices funcionales iniciales sobre tablas operativas llamaban una función CIA privada. Al revocar EXECUTE, Postgres no podía mantener el índice durante INSERT y Call Center recibió 401.

Corrección final:

- se retiraron los índices inseguros;
- se introdujeron índices de expresión equivalentes usando únicamente built-ins PostgreSQL;
- no requieren permisos CIA durante INSERT/UPDATE;
- pruebas `SET ROLE anon` pasan;
- tráfico real de asesores volvió a `POST /aos_llamadas → 201`.

Regla permanente:

> Nunca introducir en índices de tablas operativas una función privada cuyo EXECUTE no forme parte del contrato de escritura de esos roles.

---

## 9. ROLLBACK

Rollback frontend:

1. restaurar `admin-marketing-v2.js` desde `admin-marketing-v2-original.js`;
2. retirar `admin-audiencias.html`.

Esto no afecta Call Center ni source tables.

Rollback runtime:

- gateway y panel son aditivos;
- direct resolver RPCs siguen privados;
- eliminar gateway/session objects no modifica datos operativos;
- safe native indexes pueden retirarse sin modificar datos.

---

## 10. OUT OF SCOPE — FASE 6+

No implementar en Fase 5:

- guardar/editar audiencias persistentes;
- snapshots;
- activaciones;
- asignaciones a asesores;
- ownership;
- advisor work views;
- solicitudes/aprobaciones;
- channel availability;
- auto-recommendation/IA operacional.

La siguiente fase es **Fase 6 — Audience Library Persistence**.
