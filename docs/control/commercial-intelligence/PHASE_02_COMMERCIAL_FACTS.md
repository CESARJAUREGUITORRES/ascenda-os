# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 2 — COMMERCIAL FACTS ENGINE

**Estado:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Base:** staging `58bae8c4c44e9325ebbfdd0b9db1782fd1610bec`  
**Rama:** `feature/commercial-intelligence-phase2-facts-20260813`  
**Supabase live de validación:** `ituyqwstonmhnfshnaqz`  
**Dependencia obligatoria:** Identity Resolver V1 de Fase 1.

---

# 1. OBJETIVO

Convertir la actividad comercial diaria de ASCENDA en hechos semánticos estables y reutilizables por contacto, evitando que Audience Engine, KronIA, Call Center o Email tengan que reinterpretar tablas operativas.

Grano contractual:

- una fila por `contact_key` en el consolidado;
- cero duplicación por joins multi-evento;
- cada dominio agrega antes de unirse;
- todas las claves telefónicas usan `aos_cia_normalize_contact_key_v1`;
- ninguna fuente modifica datos históricos.

Dominios V1:

1. Leads / Acquisition;
2. Calls;
3. Appointments;
4. Sales + Product + Service;
5. Follow-ups;
6. Email engagement;
7. Consolidated Commercial Facts.

---

# 2. GATES FASE 2

| Gate | Criterio | Estado inicial |
|---|---|---|
| P2-G01 | Impact Report + invariantes | PASS |
| P2-G02 | Lead facts + oportunidad actual | IN_PROGRESS |
| P2-G03 | Call facts + contact policy V1 | IN_PROGRESS |
| P2-G04 | Agenda facts + upcoming/attendance policy | IN_PROGRESS |
| P2-G05 | Sales/Product/Service facts | IN_PROGRESS |
| P2-G06 | Follow-up facts | IN_PROGRESS |
| P2-G07 | Email reconciliation + UNKNOWN semantics | IN_PROGRESS |
| P2-G08 | Consolidated 1:1 por `contact_key` | PENDING |
| P2-G09 | Provenance/freshness versionados | PENDING |
| P2-G10 | Tests/invariantes contra Supabase vivo | PENDING |
| P2-G11 | Performance baseline | PENDING |
| P2-G12 | Seguridad: objetos privados por defecto | PENDING |
| P2-G13 | CI + integración staging | PENDING |
| P2-G14 | Continuidad GitHub + `aos_memory` | PENDING |

La fase solo pasa a `100_COMPLETE` cuando P2-G01…P2-G14 estén en PASS.

---

# 3. PRINCIPIO CLAVE: CONTACTO ≠ OPORTUNIDAD ACTUAL

La auditoría detectó una distinción crítica:

- `calls.never_called` responde si el contacto nunca tuvo ninguna llamada histórica;
- `lead.unworked_since_latest_entry` responde si el ingreso lead más reciente todavía no tiene una llamada posterior.

Snapshot live:

- contactos lead válidos: 5,076;
- contactos lead sin ninguna llamada histórica: 0;
- contactos cuyo ingreso lead más reciente está posterior a su última llamada: **1,287**;
- contactos con llamada posterior o igual al último ingreso lead: 3,789.

Por tanto, para priorizar “leads nuevos sin trabajar” se debe usar `lead.unworked_since_latest_entry`, no `calls.never_called`.

---

# 4. LEAD FACTS V1

Campos principales:

- `lead_count`;
- `first_lead_at`;
- `last_lead_at`;
- `days_since_last_lead`;
- `latest_lead_id`;
- `latest_interest`;
- `latest_interest_type`;
- `interests[]`;
- `interest_types[]`;
- `latest_ad`;
- `ads[]`.

Orden canónico del lead más reciente:

`event_at DESC, id DESC`

`event_at = COALESCE(hora_ingreso, created_at, fecha)`.

## Taxonomía producto/servicio de interés

Ventas ya poseen `tipo=PRODUCTO|SERVICIO` y no necesitan inferencia.

Leads usan etiquetas de campaña/tratamiento que no coinciden 1:1 con el catálogo. En el baseline solo 2 de 10 etiquetas hacen match exacto con `aos_catalogo_servicios`.

Por ello V1 usa una taxonomía explícita/versionada para las etiquetas activas actuales. No se utiliza fuzzy matching automático. Nuevas etiquetas no reconocidas quedan `UNKNOWN` hasta ser mapeadas de forma controlada.

---

# 5. CALL FACTS V1

Campos principales:

- `call_count`;
- `first_call_at`;
- `last_call_at`;
- `days_since_last_call`;
- `latest_call_id`;
- `latest_status`;
- `latest_substatus`;
- `latest_advisor_id`;
- `latest_advisor_label`;
- `latest_treatment`;
- `ever_statuses[]`;
- `called_today`;
- `max_attempt`;
- `effective_contact_count`;
- `non_contact_count`.

## Call Contact Policy V1

Normalización:

- `PROVINCIAS` → `PROVINCIA`;
- blanks → UNKNOWN.

No contacto:

- `SIN CONTACTO`;
- `NO CONTESTA`.

Contacto efectivo para métrica operacional:

cualquier estado no vacío distinto de los dos anteriores, incluyendo `CITA CONFIRMADA`, `SEGUIMIENTO`, `NO LE INTERESA`, `SACAR DE LA BASE` y `PROVINCIA`.

Esta clasificación mide existencia de interacción/resolución operativa; no reemplaza el significado comercial del estado.

Orden latest call:

`created_at DESC, fecha DESC, id DESC`.

---

# 6. APPOINTMENT FACTS V1

Campos:

- `appointment_count`;
- `last_appointment_at`;
- `last_appointment_status`;
- `last_treatment`;
- `last_branch`;
- `next_appointment_at`;
- `next_appointment_status`;
- `next_treatment`;
- `next_branch`;
- `has_future_appointment`;
- `no_show_count`;
- `attended_count`;
- `last_attended_at`;
- `appointment_statuses[]`.

Políticas:

- próximo/upcoming = `fecha_cita >= fecha local de Lima`;
- estados activos V1 para future/upcoming: `PENDIENTE`, `CITA CONFIRMADA`;
- `attended_count`: `ASISTIO` + `EFECTIVA`;
- `no_show_count`: `NO ASISTIO`.

No se considera `REAGENDADA` como cita futura activa por sí sola, porque representa un estado de transición/histórico.

---

# 7. SALES / PRODUCT / SERVICE FACTS V1

Fuente autoritativa: `aos_ventas`.

Baseline observado:

- 1,275 filas;
- `SERVICIO`: 871;
- `PRODUCTO`: 404;
- estados de pago: `PAGO COMPLETO` 1,153; `ADELANTO` 122.

Campos:

- `sale_count`;
- `revenue_lifetime`;
- `first_sale_at`;
- `last_sale_at`;
- `days_since_last_sale`;
- `product_count`;
- `service_count`;
- `product_revenue`;
- `service_revenue`;
- `products[]`;
- `services[]`;
- `latest_item_type`;
- `latest_item`;
- `latest_branch`;
- `latest_advisor_id` nullable;
- `latest_advisor_label`;
- `payment_states[]`;
- `payment_methods[]`.

Asesor de venta se resuelve a `aos_usuarios.id` solo cuando el label/código mapea unívocamente. Si no, el ID queda NULL y se conserva el label.

---

# 8. FOLLOW-UP FACTS V1

`aos_seguimientos` usa `NUMERO` y fechas legacy en texto.

Auditoría:

- 524 filas;
- 456 contact keys distintos válidos en lectura actual;
- 0 contact keys de seguimiento fuera del universo Identity V1;
- `FECHA_PROGRAMADA`: 524/524 en formato ISO `YYYY-MM-DD`;
- estados: VENCIDO 507, PENDIENTE 15, COMPLETADO 2.

Campos:

- `followup_count`;
- `pending_count`;
- `overdue_count`;
- `completed_count`;
- `next_followup_at`;
- `oldest_overdue_at`;
- `latest_advisor_id`;
- `latest_advisor_label`;
- `treatments[]`.

`overdue_count` V1 = estado `VENCIDO` OR (`PENDIENTE` y fecha programada < hoy).

---

# 9. EMAIL FACTS V1

Email requiere reconciliación y no puede deducirse de una sola tabla.

## Fuentes de envío

- `aos_emails_enviados`;
- `aos_email_envios` con `estado='enviado'`.

`aos_email_flujo_ejecuciones` NO suma envíos: representa estado de workflow.

## Dedupe

Clave de envío preferida: `resend_id`.

Si no existe, se genera una clave técnica `source:id`. Actualmente:

- `aos_emails_enviados`: 1,925 resend IDs distintos;
- `aos_email_envios`: 17 resend IDs enviados;
- overlap actual: 0;
- total de envíos únicos observados: 1,942.

## Reconciliación de identidad

Prioridad:

1. teléfono directo normalizable y existente en Identity V1 → `HIGH`;
2. email canónico que mapea de forma unívoca a un solo `contact_key` → `MEDIUM`;
3. sin evidencia segura → `UNKNOWN`.

No se usa `paciente_id` de email como join V1: la auditoría confirmó que no corresponde al `ID_PACIENTE` actual.

Baseline de alias email seguro:

- 1,501 contactos con email canónico utilizable y unívoco;
- 334 contactos con al menos un envío reconciliado;
- 1,167 contactos con email seguro y cero envíos → `email.never_sent=TRUE`;
- 9,972 contactos sin evidencia suficiente para afirmar “nunca enviado” → `UNKNOWN`;
- 1,619 de 1,942 envíos únicos pueden reconciliarse a contacto hoy;
- 323 permanecen no resueltos y no se atribuyen artificialmente.

Provider events observados:

- delivered 968;
- bounced 54;
- opened 1.

Los eventos se vinculan por `resend_id` cuando existe un envío reconciliado; en ausencia, por email unívoco. Eventos sin identidad segura no contaminan facts de contacto.

---

# 10. CONSOLIDATED COMMERCIAL FACTS V1

Vista objetivo:

`aos_cia_commercial_facts_v1`

Base: `aos_cia_contact_identity_v1`.

Invariantes:

1. exactamente una fila por `contact_key` Identity V1;
2. misma cantidad de filas que Identity V1;
3. ningún dominio puede agregar contactos fuera de Identity V1;
4. ausencia de evento en un contacto válido produce 0/FALSE cuando semánticamente comprobable;
5. `UNKNOWN` se conserva cuando falta evidencia de identidad o canal;
6. arrays/set vacíos se devuelven como `[]`, no NULL, salvo que la semántica requiera UNKNOWN.

Facts derivados transversales:

- `calls_never_called`;
- `lead_never_called`;
- `lead_called_since_latest_entry`;
- `lead_unworked_since_latest_entry`;
- `appointments_never_had`;
- `sales_never_bought`;
- `email_never_sent` boolean3.

---

# 11. FRESHNESS Y PROVENANCE

Cada vista incluye:

- `facts_version = 1`;
- `source_rows` / counts cuando aplique;
- ID del último registro cuando aplique;
- `source_last_at` o fecha de actividad más reciente;
- `provenance JSONB` en el consolidado.

V1 son vistas calculadas en lectura, por lo que sus hechos son live/realtime respecto a las tablas fuente. Materialización/caché solo se introducirá si benchmarks posteriores lo justifican.

---

# 12. SEGURIDAD

Todos los objetos `aos_cia_*_facts_v1`:

- `security_invoker=true`;
- sin `SECURITY DEFINER`;
- sin escritura;
- sin acceso `PUBLIC`, `anon`, `authenticated`;
- acceso inicial solo `service_role`;
- ninguna policy/RLS de fuente se modifica.

El browser no consulta estas vistas directamente. Audience Engine/Backend las expondrá mediante contratos autorizados en fases posteriores.

---

# 13. IMPACT REPORT

**Riesgo:** MEDIUM.  
**Motivo:** nuevas vistas analíticas sobre fuentes operativas; sin mutación de datos ni cambio de contratos actuales.

## Fuentes leídas

- `aos_pacientes` indirectamente por Identity V1;
- `aos_leads`;
- `aos_llamadas`;
- `aos_agenda_citas`;
- `aos_ventas`;
- `aos_seguimientos`;
- `aos_usuarios` para resolución segura de asesor;
- `aos_emails_enviados`;
- `aos_email_envios`;
- `aos_email_eventos`.

## No se modifica

- filas fuente;
- `numero_limpio`;
- Call Center V2;
- Email runtime;
- RLS existente;
- `main`/producción durante validación.

## Rollback

Drop de las vistas V1 de Fase 2. No requiere restaurar datos.

---

# 14. CRITERIO DE SALIDA

Fase 2 podrá cerrar cuando:

- todos los facts tengan definición estable;
- los tests 1:1 y sumatorias pasen sobre datos vivos;
- `lead_unworked_since_latest_entry` quede validado;
- Email preserve UNKNOWN correctamente;
- benchmark consolidado esté dentro del presupuesto o exista decisión de optimización explícita;
- CI sea SUCCESS;
- integración se haga únicamente a staging;
- Supabase productivo permanezca sin despliegue CIA hasta el gate correspondiente;
- `aos_memory` marque `cia_phase2_progress=100` y Fase 3 READY.
