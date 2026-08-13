# ASCENDA OS — COMMERCIAL INTELLIGENCE FACT REGISTRY V1.1
## Phase 2 overrides / additions

**Estado:** CURRENT OVERRIDE CONTRACT  
**Fecha:** 2026-08-13  
**Base:** `FACT_REGISTRY_V1.md`  
**Regla:** este documento no reemplaza las claves no mencionadas de V1; únicamente agrega o precisa semánticas descubiertas durante Fase 2.

---

# 1. BOOLEAN3

Se mantiene:

- `TRUE` = existe evidencia suficiente para afirmar verdadero;
- `FALSE` = existe evidencia suficiente para afirmar falso;
- `UNKNOWN` = evidencia insuficiente / identidad insuficiente / hecho no aplicable.

En SQL V1.1:

- TRUE/FALSE se representan boolean;
- UNKNOWN se representa `NULL`;
- frontend/DSL nunca debe convertir NULL automáticamente a FALSE.

---

# 2. LEAD / OPPORTUNITY

| key | type | semantics | null |
|---|---|---|---|
| `lead.count` | integer | cantidad de ingresos lead del contacto | 0 |
| `lead.first_at` | timestamp | primer ingreso conocido | UNKNOWN |
| `lead.last_at` | timestamp | ingreso más reciente | UNKNOWN |
| `lead.days_since_last` | integer | días locales Lima desde `lead.last_at` | UNKNOWN |
| `lead.latest_interest` | text | interés del ingreso más reciente | UNKNOWN |
| `lead.latest_interest_type` | enum | PRODUCTO/SERVICIO/UNKNOWN según taxonomía V1 | UNKNOWN |
| `lead.interests` | set | intereses históricos normalizados | vacío |
| `lead.interest_types` | set | tipos históricos reconocidos | vacío |
| `lead.latest_ad` | text | anuncio del ingreso más reciente | UNKNOWN |
| `lead.ads` | set | anuncios históricos | vacío |
| `lead.never_called` | boolean3 | contacto lead sin ninguna llamada histórica | UNKNOWN si no es lead |
| `lead.called_since_latest_entry` | boolean3 | existe llamada con timestamp >= ingreso lead más reciente | UNKNOWN si no es lead |
| `lead.unworked_since_latest_entry` | boolean3 | ingreso lead más reciente sin llamada posterior | UNKNOWN si no es lead |

**Regla de uso:** “lead nuevo/sin trabajar” usa `lead.unworked_since_latest_entry`, no `lead.never_called`.

---

# 3. CALLS

| key | type | semantics | null |
|---|---|---|---|
| `calls.total` | integer | filas de llamada válidas del contacto | 0 |
| `calls.never_called` | boolean | total = 0 para contact_key válido | FALSE/TRUE |
| `calls.first_at` | timestamp | primera llamada | UNKNOWN |
| `calls.last_at` | timestamp | última llamada por orden canónico | UNKNOWN |
| `calls.days_since_last` | integer | días locales desde última llamada | UNKNOWN |
| `calls.latest_status` | enum/text | estado normalizado más reciente | UNKNOWN |
| `calls.latest_substatus` | text | subestado más reciente | UNKNOWN |
| `calls.latest_advisor_id` | text | id asesor raw/resoluble del último registro | UNKNOWN |
| `calls.latest_advisor_label` | text | label del asesor último | UNKNOWN |
| `calls.latest_treatment` | text | tratamiento de última llamada | UNKNOWN |
| `calls.ever_statuses` | set | estados normalizados históricos | vacío |
| `calls.called_today` | boolean | existe llamada hoy Lima | FALSE |
| `calls.max_attempt` | integer | máximo `intento` | 0 |
| `calls.effective_contact_count` | integer | estados distintos de SIN CONTACTO/NO CONTESTA | 0 |
| `calls.non_contact_count` | integer | SIN CONTACTO + NO CONTESTA | 0 |

Normalización V1:

- `PROVINCIAS` → `PROVINCIA`;
- trim + uppercase;
- blank → UNKNOWN.

---

# 4. APPOINTMENTS

| key | type | semantics | null |
|---|---|---|---|
| `appointments.total` | integer | citas conocidas | 0 |
| `appointments.never_had` | boolean | total=0 para contact_key válido | FALSE/TRUE |
| `appointments.last_at` | date | cita pasada/presente cronológicamente más reciente | UNKNOWN |
| `appointments.last_status` | enum | estado de `last_at` | UNKNOWN |
| `appointments.last_treatment` | text | tratamiento de `last_at` | UNKNOWN |
| `appointments.last_branch` | text | sede de `last_at` | UNKNOWN |
| `appointments.next_at` | date | próxima cita activa con fecha >= hoy Lima | UNKNOWN |
| `appointments.next_status` | enum | estado de `next_at` | UNKNOWN |
| `appointments.next_treatment` | text | tratamiento de próxima cita | UNKNOWN |
| `appointments.next_branch` | text | sede próxima cita | UNKNOWN |
| `appointments.has_future` | boolean | existe próxima cita activa | FALSE |
| `appointments.no_show_count` | integer | estado NO ASISTIO | 0 |
| `appointments.ever_no_show` | boolean | no_show_count > 0 | FALSE |
| `appointments.attended_count` | integer | ASISTIO + EFECTIVA | 0 |
| `appointments.last_attended_at` | date | última ASISTIO/EFECTIVA | UNKNOWN |
| `appointments.statuses` | set | estados históricos | vacío |

Estados upcoming V1: `PENDIENTE`, `CITA CONFIRMADA`.

---

# 5. SALES / PRODUCTS / SERVICES

| key | type | semantics | null |
|---|---|---|---|
| `sales.total` | integer | ventas conocidas | 0 |
| `sales.never_bought` | boolean | total=0 | FALSE/TRUE |
| `sales.revenue_lifetime` | numeric | suma `monto` | 0 |
| `sales.first_at` | date | primera venta | UNKNOWN |
| `sales.last_at` | date | última venta | UNKNOWN |
| `sales.days_since_last` | integer | días locales desde última venta | UNKNOWN |
| `sales.product_count` | integer | tipo PRODUCTO | 0 |
| `sales.service_count` | integer | tipo SERVICIO | 0 |
| `sales.product_revenue` | numeric | monto de PRODUCTO | 0 |
| `sales.service_revenue` | numeric | monto de SERVICIO | 0 |
| `sales.products` | set | items tipo PRODUCTO | vacío |
| `sales.services` | set | items tipo SERVICIO | vacío |
| `sales.latest_item_type` | enum | tipo de última venta | UNKNOWN |
| `sales.latest_item` | text | tratamiento/item última venta | UNKNOWN |
| `sales.latest_branch` | text | sede última venta | UNKNOWN |
| `sales.latest_advisor_id` | text | user id solo si label/código resuelve unívocamente | UNKNOWN |
| `sales.latest_advisor_label` | text | label histórico preservado | UNKNOWN |
| `sales.payment_states` | set | estados de pago observados | vacío |
| `sales.payment_methods` | set | valores `pago` observados | vacío |

`never_bought_product(X)` y `never_bought_service(X)` se evalúan contra `products[]`/`services[]`, nunca contra `sales.never_bought` global.

---

# 6. FOLLOW-UPS

| key | type | semantics | null |
|---|---|---|---|
| `followups.total` | integer | seguimientos válidos | 0 |
| `followups.pending_count` | integer | estado PENDIENTE | 0 |
| `followups.overdue_count` | integer | VENCIDO o PENDIENTE con fecha < hoy | 0 |
| `followups.completed_count` | integer | COMPLETADO | 0 |
| `followups.next_at` | date | próxima fecha PENDIENTE >= hoy | UNKNOWN |
| `followups.oldest_overdue_at` | date | vencido más antiguo | UNKNOWN |
| `followups.latest_advisor_id` | text | ID_ASESOR último registro | UNKNOWN |
| `followups.latest_advisor_label` | text | ASESOR último registro | UNKNOWN |
| `followups.treatments` | set | tratamientos históricos | vacío |

---

# 7. EMAIL

| key | type | semantics | null |
|---|---|---|---|
| `email.identity_confidence` | enum | HIGH direct phone; MEDIUM email unívoco; UNKNOWN sin resolución | UNKNOWN |
| `email.sent_count` | integer | envíos únicos reconciliados por provider/source ID | 0 |
| `email.never_sent` | boolean3 | FALSE si hay envío; TRUE si alias email seguro y cero envío; UNKNOWN sin alias/evidencia | UNKNOWN |
| `email.last_sent_at` | timestamp | último envío reconciliado | UNKNOWN |
| `email.days_since_last` | integer | días desde último envío | UNKNOWN |
| `email.delivered_count` | integer | provider delivery events reconciliados | 0 |
| `email.opened_count` | integer | provider/legacy open evidence deduplicada por provider ID | 0 |
| `email.clicked_count` | integer | click evidence conocida | 0 |
| `email.bounced_count` | integer | provider/legacy bounce evidence deduplicada | 0 |
| `email.last_event_at` | timestamp | último provider event reconciliado | UNKNOWN |

Fuentes que NO cuentan como envío por sí mismas:

- `aos_email_flujo_ejecuciones`;
- `aos_email_cadencia`.

`paciente_id` legacy de email no es identidad V1 mientras no exista reconciliación comprobada.

---

# 8. CONSOLIDATED CONTRACT

`aos_cia_commercial_facts_v1` debe devolver una fila exacta por `aos_cia_contact_identity_v1.contact_key`.

Defaults comprobables:

- counts → 0;
- sets → array vacío;
- `calls.never_called`, `appointments.never_had`, `sales.never_bought` → boolean definitivo porque `contact_key` ya es válido;
- facts lead específicos → NULL si el contacto no es lead;
- `email.never_sent` conserva NULL/UNKNOWN cuando no existe alias seguro.

El Audience DSL y KronIA deben consumir estas claves semánticas, no reconstruir SQL contra tablas operativas.