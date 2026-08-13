# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 2 — COMMERCIAL FACTS ENGINE

**Estado:** `100_COMPLETE`  
**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase2-facts-20260813`  
**PR feature → staging:** #55  
**CI:** Ascenda CI run 293 = SUCCESS  
**Merge funcional staging:** `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`  
**Supabase live usado para validación read-only:** `ituyqwstonmhnfshnaqz`  
**Dependencia:** Identity Resolver V1.

---

# 1. OBJETIVO CERRADO

Fase 2 establece una capa semántica reutilizable 1:1 por `contact_key` para que Audience Engine, Segmentation, KronIA, Call Center, Email y futuros canales no tengan que reinterpretar las tablas operativas.

Principios cerrados:

- identidad proviene únicamente de Identity Resolver V1;
- cada dominio agrega antes del join final;
- el consolidado tiene grano contractual de un contacto;
- `latest`, `ever`, `count`, `days_since`, freshness y provenance poseen semántica documentada;
- `UNKNOWN` no se convierte silenciosamente en FALSE;
- producto y servicio son dimensiones separadas;
- la oportunidad lead actual es distinta del historial lifetime del contacto;
- no se modifica ninguna fila fuente.

---

# 2. GATES — CIERRE

| Gate | Criterio | Estado |
|---|---|---|
| P2-G01 | Impact Report + invariantes | PASS |
| P2-G02 | Lead facts + oportunidad actual | PASS |
| P2-G03 | Call facts + contact policy V1 | PASS |
| P2-G04 | Agenda facts + upcoming/attendance policy | PASS |
| P2-G05 | Sales/Product/Service facts | PASS |
| P2-G06 | Follow-up facts | PASS |
| P2-G07 | Email reconciliation + UNKNOWN semantics | PASS |
| P2-G08 | Consolidated 1:1 por `contact_key` | PASS |
| P2-G09 | Provenance/freshness versionados | PASS |
| P2-G10 | Tests/invariantes contra Supabase vivo | PASS |
| P2-G11 | Performance baseline | PASS |
| P2-G12 | Seguridad: objetos privados por defecto | PASS |
| P2-G13 | CI + integración staging | PASS |
| P2-G14 | Continuidad GitHub + `aos_memory` | PASS al persistir checkpoint final |

**Regla:** Fase 2 solo se considera formalmente 100% al persistir P2-G14 en `aos_memory`.

---

# 3. OBJETOS VERSIONADOS

Migrations:

- `supabase/migrations/20260813063500_cia_commercial_facts_v1.sql`
- `supabase/migrations/20260813063600_cia_commercial_facts_v1_1_email_fix.sql`

Objetos de contrato:

- `aos_cia_interest_taxonomy_v1`
- `aos_cia_lead_facts_v1`
- `aos_cia_call_facts_v1`
- `aos_cia_appointment_facts_v1`
- `aos_cia_sales_facts_v1`
- `aos_cia_followup_facts_v1`
- `aos_cia_email_facts_v1`
- `aos_cia_commercial_facts_v1`

Artefactos de control:

- `FACT_REGISTRY_V1_1_PHASE2.md`
- `scripts/audit_cia_commercial_facts_phase2_readonly.sql`
- `scripts/test_cia_commercial_facts_phase2.sql`
- `PHASE_02_VALIDATION_REPORT.md`

---

# 4. SNAPSHOT VALIDADO

| Dominio | Filas fuente | Válidas por contact_key | Contactos |
|---|---:|---:|---:|
| Leads | 5,403 | 5,391 | 5,076 |
| Calls | 34,188 | 33,999 | 5,885 |
| Appointments | 3,047 | 2,918 | 1,157 |
| Sales | 1,275 | 1,268 | 296 |
| Follow-ups | 524 | 523 | 456 |

Todos los dominios: **0 contact keys fuera de Identity V1**.

Los datos son vivos; estas cifras son evidencia de cierre, no constantes hardcoded.

---

# 5. LEAD FACTS / OPORTUNIDAD ACTUAL

Hecho clave descubierto y cerrado:

`calls.never_called` NO equivale a “nuevo ingreso lead todavía sin trabajar”.

Facts separados:

- `calls.never_called`
- `lead.never_called`
- `lead.called_since_latest_entry`
- `lead.unworked_since_latest_entry`

Validación:

- contactos lead: 5,076;
- `lead.unworked_since_latest_entry`: **1,287**;
- `lead.called_since_latest_entry`: **3,789**;
- suma = 5,076: PASS.

Este contrato será la base de presets como **Leads nuevos sin trabajar**.

Taxonomía de interés V1 es explícita/versionada. No existe fuzzy mapping automático producto/servicio.

---

# 6. CALL FACTS

Call Contact Policy V1:

- `PROVINCIAS` → `PROVINCIA`;
- SIN CONTACTO / NO CONTESTA = no-contact operativo;
- otros estados no vacíos = interacción/resolución operativa.

Validación sobre 33,999 filas normalizadas:

- effective-contact rows: 6,651;
- no-contact rows: 27,348;
- max intento observado: 77.

Latest order:

`created_at DESC, fecha DESC, id DESC`.

---

# 7. AGENDA FACTS

Política V1:

- cita futura activa: `fecha_cita >= hoy Lima` y estado `PENDIENTE|CITA CONFIRMADA`;
- attendance: `ASISTIO|EFECTIVA`;
- no-show: `NO ASISTIO`;
- `REAGENDADA` no es future-active por sí sola.

Validación normalizada:

- NO ASISTIO: 1,583;
- ASISTIO/EFECTIVA: 780;
- contactos con cita activa futura: 54.

---

# 8. SALES / PRODUCT / SERVICE FACTS

Fuente autoritativa de tipo: `aos_ventas.tipo`.

Filas normalizadas:

- PRODUCTO: 403;
- SERVICIO: 865;
- mismatch de partición: 0;
- revenue: S/ 551,046.27;
- product revenue: S/ 60,286.50;
- service revenue: S/ 490,759.77.

`never_bought_product(X)` y `never_bought_service(X)` deberán consultarse contra dimensiones separadas; nunca contra el boolean global `sales_never_bought`.

---

# 9. FOLLOW-UP FACTS

Validación:

- 524 filas fuente;
- 523 normalizables;
- 456 contactos;
- 524/524 FECHA_PROGRAMADA en ISO;
- pending: 15;
- overdue V1: 509;
- completed: 2.

Overdue V1:

`VENCIDO OR (PENDIENTE AND fecha_programada < hoy Lima)`.

---

# 10. EMAIL FACTS

Fuentes canónicas de envío:

- `aos_emails_enviados`;
- `aos_email_envios` con estado enviado.

No cuentan como envío por sí mismos:

- `aos_email_flujo_ejecuciones`;
- `aos_email_cadencia`.

Identidad:

- HIGH = teléfono directo seguro;
- MEDIUM = email canónico unívoco;
- UNKNOWN = evidencia insuficiente.

No se usa `paciente_id` legacy de email como join V1.

Corrección V1.1 descubierta en validación:

- 56 filas tenían `email_destino=''` pero `destinatario` útil;
- resolver corregido con `COALESCE(NULLIF(TRIM(email_destino),''), NULLIF(TRIM(destinatario),''))`.

Baseline final:

- unique sends: 1,942;
- safely mapped sends: **1,623**;
- unresolved sends: **319**;
- contacts with send evidence: 334;
- safe-email contacts: 1,501;
- `never_sent=TRUE`: 1,167;
- `never_sent=UNKNOWN`: 9,972.

Los 319 envíos no resueltos permanecen sin atribución.

---

# 11. CONSOLIDATED COMMERCIAL FACTS

`aos_cia_commercial_facts_v1` se define sobre Identity V1 y joins 1:1 de facts agregados.

Invariantes:

- una fila por contact_key;
- ningún dominio amplía identidad;
- counts ausentes comprobables → 0;
- sets ausentes → `[]`;
- channel uncertainty → UNKNOWN/NULL cuando corresponda;
- identity conflicts continúan sin paciente canónico;
- provenance JSONB conserva filas/IDs y versión.

---

# 12. PERFORMANCE

Benchmarks live read-only:

- Call heavy ranking/aggregation: ~260 ms.
- Email reconciliation aislada: ~78 ms.
- Composición representativa de los dominios sobre 11,473 contactos: **~474 ms**.

Presupuesto inicial: P95 normal < 1.5 s.

**Decisión:** no materializar, no agregar cache y no crear índices nuevos en Fase 2. La arquitectura live preserva actualización automática y tiene margen de rendimiento suficiente.

---

# 13. SEGURIDAD / ROLLOUT

Objetos nuevos:

- `security_invoker=true`;
- no SECURITY DEFINER;
- no escritura;
- sin acceso PUBLIC/anon/authenticated;
- select inicial solo service_role.

No se cambian:

- RLS fuente;
- datos operativos;
- `numero_limpio`;
- Call Center V2;
- Email runtime;
- frontend/backend productivo.

Después del merge a staging se verificó Supabase live:

- `aos_cia_*` views = 0;
- `aos_cia_*` functions = 0.

Producción continúa intacta.

---

# 14. CERTIFICACIÓN Y LÍMITE EXPLÍCITO

Ascenda CI run 293 = SUCCESS.

El CI actual no ejecuta migrations SQL contra una base temporal. No existe una development branch Supabase reutilizable en este momento; crear una nueva requiere un flujo separado de costo/confirmación.

Por ello el 100% de esta fase certifica:

1. contratos cerrados;
2. semántica SQL ejecutada mediante equivalentes read-only contra datos vivos;
3. sumatorias/invariantes reconciliadas;
4. migrations aditivas versionadas y revisadas;
5. CI del repositorio exitoso;
6. integración a staging;
7. producción no modificada.

No se afirma que las migrations hayan sido físicamente aplicadas al Supabase productivo. Ese despliegue continúa sujeto al gate de deployment correspondiente.

---

# 15. SALIDA

Fase 2 = `100_COMPLETE` al persistirse P2-G14.

**Siguiente fase:** FASE 3 — SEGMENTATION ENGINE = READY.

Fase 3 debe consumir Identity V1 + Commercial Facts V1 / Fact Registry V1.1. No debe reconstruir hechos directamente desde las tablas operativas salvo extensión formal del registry.
