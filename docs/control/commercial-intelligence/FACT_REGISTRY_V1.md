# ASCENDA OS — COMMERCIAL INTELLIGENCE FACT REGISTRY V1

**Estado:** CURRENT CONTRACT / Phase 0  
**Fecha:** 2026-08-13  
**Ámbito:** hechos comerciales/operativos permitidos para Audience Engine V1.  
**Regla:** el frontend y la IA trabajan contra estas claves semánticas; no contra SQL libre ni nombres de columnas arbitrarios.

---

# 1. CONTRATO DE UN FACT

Cada fact debe declarar:

- `key`: identificador estable;
- `type`: `text | enum | boolean3 | integer | numeric | date | timestamp | set`;
- `source`: fuente/s de verdad;
- `grain`: siempre `contact` en V1 salvo indicación;
- `semantics`: definición exacta;
- `freshness`: `realtime | incremental | batch`;
- `null_semantics`: significado de ausencia;
- `operators`: operadores permitidos por Audience DSL;
- `explain`: razón legible que puede mostrar UI/KronIA.

`boolean3` admite: `TRUE`, `FALSE`, `UNKNOWN`.

---

# 2. IDENTITY / CONTACT

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `contact.key` | text | derived | `numero_limpio` V1 normalizado read-only | realtime | contacto no resoluble |
| `contact.phone_valid` | boolean3 | derived | clave compatible con patrón telefónico V1 | realtime | UNKNOWN si no resoluble |
| `contact.email` | text | pacientes + reconciliation email | email canónico de contacto | incremental | sin email conocido |
| `contact.email_valid` | boolean3 | derived | email presente y formato aceptable | incremental | UNKNOWN si no existe email canónico |
| `contact.identity_conflict` | boolean | pacientes | >1 registro canónico no fusionado para la misma clave | realtime | FALSE |
| `contact.is_fused_only` | boolean | pacientes | no existe perfil no-FUSIONADO utilizable | realtime | FALSE |
| `contact.exists_as_patient` | boolean | pacientes | existe paciente canónico | realtime | FALSE |
| `contact.exists_as_lead` | boolean | leads | existe al menos un lead | realtime | FALSE |
| `contact.source_flags` | set | multi-source | fuentes donde aparece la clave | incremental | set vacío |

Operadores estándar: `eq`, `neq`, `exists`, `not_exists`; para `source_flags`: `contains`, `contains_any`, `contains_all`.

---

# 3. CRM / PATIENT

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `crm.patient_state` | enum | `aos_pacientes.ESTADO_PACIENTE` canónico | estado del perfil canónico | realtime | UNKNOWN |
| `crm.base_label` | text/set | pacientes + base_etiquetas | etiqueta/s operativas conocidas | incremental | vacío |
| `crm.branch` | enum/text | paciente + eventos recientes | sede principal derivada; no asumir campo raw si está vacío | incremental | UNKNOWN |
| `crm.department` | text | pacientes | departamento | incremental | UNKNOWN |
| `crm.city` | text | pacientes | ciudad/provincia normalizada | incremental | UNKNOWN |
| `crm.district` | text | pacientes | distrito | incremental | UNKNOWN |
| `crm.legacy_score_state` | text | pacientes | valor legacy solo para explicación/migración; NO score canónico | batch | UNKNOWN |

`crm.legacy_score_state` no será filtro visible general por defecto hasta completar normalización.

---

# 4. LEADS / ACQUISITION

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `lead.count` | integer | leads | nº registros lead del contacto | realtime | 0 |
| `lead.first_at` | date/timestamp | leads | primer ingreso conocido | realtime | UNKNOWN |
| `lead.last_at` | date/timestamp | leads | último ingreso conocido | realtime | UNKNOWN |
| `lead.days_since_last` | integer | derived | días desde último ingreso | realtime | UNKNOWN |
| `lead.latest_interest` | text | leads | tratamiento/interés del lead más reciente | realtime | UNKNOWN |
| `lead.interests` | set | leads | conjunto de intereses históricos | incremental | vacío |
| `lead.latest_ad` | text | leads | anuncio más reciente | realtime | UNKNOWN |
| `lead.ads` | set | leads | anuncios históricos | incremental | vacío |
| `lead.latest_campaign` | text | lead/base labels | campaña/tratamiento comercial derivado | incremental | UNKNOWN |
| `lead.never_called` | boolean3 | leads + calls | existe como lead y no existe evidencia de llamada | realtime | UNKNOWN si identidad no resoluble |

V1 no expondrá `clasificacion_nico` cruda; futura versión usará facts normalizados.

---

# 5. CALL FACTS

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `calls.total` | integer | llamadas | nº llamadas registradas | realtime | 0 |
| `calls.never_called` | boolean3 | llamadas | cero llamadas conocidas | realtime | UNKNOWN si identidad no resoluble |
| `calls.first_at` | timestamp/date | llamadas | primera llamada | realtime | UNKNOWN |
| `calls.last_at` | timestamp/date | llamadas | última llamada por orden canónico | realtime | UNKNOWN |
| `calls.days_since_last` | integer | derived | días desde última llamada | realtime | UNKNOWN |
| `calls.latest_status` | enum | llamadas | estado de la última llamada | realtime | UNKNOWN |
| `calls.ever_statuses` | set | llamadas | conjunto de estados históricos | incremental | vacío |
| `calls.latest_substatus` | text | llamadas | subestado más reciente cuando exista | realtime | UNKNOWN |
| `calls.latest_advisor_id` | text | llamadas/usuarios | asesor más reciente resoluble | realtime | UNKNOWN |
| `calls.called_today` | boolean | llamadas | existe llamada en fecha local actual | realtime | FALSE |
| `calls.max_attempt` | integer | llamadas | máximo intento registrado | realtime | 0 |
| `calls.effective_contact_count` | integer | derived policy | nº llamadas que cumplen definición versionada de contacto efectivo | incremental | 0 |

**Orden canónico latest call:** `created_at DESC NULLS LAST, fecha DESC, id DESC` dentro de `numero_limpio`.

`latest_status` y `ever_statuses` son conceptos distintos y nunca intercambiables.

---

# 6. AGENDA FACTS

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `appointments.total` | integer | agenda | nº citas conocidas | realtime | 0 |
| `appointments.never_had` | boolean3 | agenda | cero citas conocidas | realtime | UNKNOWN si identidad no resoluble |
| `appointments.last_at` | date/timestamp | agenda | última cita cronológica pasada/presente | realtime | UNKNOWN |
| `appointments.last_status` | enum | agenda | estado correspondiente a última cita | realtime | UNKNOWN |
| `appointments.next_at` | date/timestamp | agenda | próxima cita futura válida | realtime | UNKNOWN |
| `appointments.next_status` | enum | agenda | estado de próxima cita | realtime | UNKNOWN |
| `appointments.has_future` | boolean | agenda | existe cita futura en estado utilizable | realtime | FALSE |
| `appointments.no_show_count` | integer | agenda | cantidad `NO ASISTIO` | realtime | 0 |
| `appointments.ever_no_show` | boolean | agenda | `no_show_count > 0` | realtime | FALSE |
| `appointments.attended_count` | integer | agenda | ASISTIO/EFECTIVA según policy versionada | realtime | 0 |
| `appointments.last_attended_at` | date | agenda | última asistencia efectiva | realtime | UNKNOWN |
| `appointments.latest_treatment` | text | agenda | tratamiento de cita más reciente | realtime | UNKNOWN |
| `appointments.latest_branch` | text | agenda | sede de cita más reciente | realtime | UNKNOWN |

`has_future` V1 considera al menos `PENDIENTE` y `CITA CONFIRMADA`; cambios posteriores se versionan.

---

# 7. SALES / PRODUCT / SERVICE FACTS

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `sales.total` | integer | ventas | nº ventas | realtime | 0 |
| `sales.has_any` | boolean | ventas | total > 0 | realtime | FALSE |
| `sales.never_bought` | boolean3 | ventas | cero ventas conocidas | realtime | UNKNOWN si identidad no resoluble |
| `sales.revenue_lifetime` | numeric | ventas | suma de monto comercial canónico | realtime/incremental | 0 |
| `sales.first_at` | date | ventas | primera venta | realtime | UNKNOWN |
| `sales.last_at` | date | ventas | última venta | realtime | UNKNOWN |
| `sales.days_since_last` | integer | derived | días desde última venta | realtime | UNKNOWN |
| `sales.product_count` | integer | ventas `tipo=PRODUCTO` | nº compras producto | realtime | 0 |
| `sales.service_count` | integer | ventas `tipo=SERVICIO` | nº compras servicio | realtime | 0 |
| `sales.has_product` | boolean | derived | product_count > 0 | realtime | FALSE |
| `sales.has_service` | boolean | derived | service_count > 0 | realtime | FALSE |
| `sales.products` | set | ventas/catalogo | productos comprados | incremental | vacío |
| `sales.services` | set | ventas/catalogo | servicios comprados | incremental | vacío |
| `sales.latest_item_type` | enum | ventas | PRODUCTO/SERVICIO de última venta | realtime | UNKNOWN |
| `sales.latest_item` | text | ventas | item/tratamiento último | realtime | UNKNOWN |
| `sales.latest_branch` | text | ventas | sede última venta | realtime | UNKNOWN |
| `sales.latest_advisor_id` | text | ventas/usuarios | asesor última venta | realtime | UNKNOWN |
| `sales.payment_states` | set | ventas | estados de pago observados | incremental | vacío |
| `sales.payment_methods` | set | ventas | métodos observados | incremental | vacío |

Filtros específicos deben soportar:

- `bought_product(product_id/name)`;
- `never_bought_product(product_id/name)`;
- `bought_service(service_id/name)`;
- `never_bought_service(service_id/name)`.

Nunca sustituir estos por `sales.never_bought` global.

---

# 8. FOLLOW-UP FACTS

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `followups.total` | integer | seguimientos | nº seguimientos | realtime | 0 |
| `followups.pending_count` | integer | seguimientos | estado PENDIENTE | realtime | 0 |
| `followups.overdue_count` | integer | seguimientos | estado VENCIDO o fecha vencida según policy | realtime | 0 |
| `followups.completed_count` | integer | seguimientos | COMPLETADO | realtime | 0 |
| `followups.next_at` | date | seguimientos | próxima fecha programada pendiente | realtime | UNKNOWN |
| `followups.oldest_overdue_at` | date | seguimientos | vencido más antiguo | realtime | UNKNOWN |
| `followups.latest_advisor_id` | text | seguimientos/usuarios | asesor último seguimiento | realtime | UNKNOWN |
| `followups.treatments` | set | seguimientos | tratamientos relacionados | incremental | vacío |

---

# 9. EMAIL ENGAGEMENT FACTS

Email requiere reconciliación de múltiples fuentes; ningún fact `never_*` puede depender de una sola tabla.

| key | type | source | semantics | freshness | null |
|---|---|---|---|---|---|
| `email.identity_confidence` | enum | reconciliation | HIGH/MEDIUM/LOW/UNKNOWN | incremental | UNKNOWN |
| `email.sent_count` | integer | emails_enviados + email_envios + flow executions reconciliadas | envíos únicos deduplicados | incremental | 0/UNKNOWN según identidad |
| `email.never_sent` | boolean3 | multi-source | no existe envío reconciliado | incremental | UNKNOWN si identidad insuficiente |
| `email.last_sent_at` | timestamp | multi-source | último envío reconciliado | incremental | UNKNOWN |
| `email.days_since_last` | integer | derived | días desde último envío | incremental | UNKNOWN |
| `email.delivered_count` | integer | eventos/envíos | entregados conocidos | incremental | 0 |
| `email.opened_count` | integer | eventos/emails_enviados | aperturas conocidas | incremental | 0 |
| `email.clicked_count` | integer | eventos/emails_enviados | clicks conocidos | incremental | 0 |
| `email.bounced_count` | integer | eventos/emails_enviados | rebotes conocidos | incremental | 0 |
| `email.last_event_at` | timestamp | eventos | último evento proveedor | incremental | UNKNOWN |

V1 debe documentar deduplicación por provider ID cuando exista; email destino es alias de identidad, no persona por sí mismo.

---

# 10. CHANNEL CONTEXT FACTS

Estos facts no definen pertenencia a audiencia; definen uso contextual.

## Call context

- `channel.call.eligible`
- `channel.call.available_now`
- `channel.call.exclusion_reasons`
- `channel.call.assigned_to`
- `channel.call.lease_expires_at`
- `channel.call.in_progress`

## Email context

- `channel.email.eligible`
- `channel.email.available_now`
- `channel.email.exclusion_reasons`

## Future SMS / WhatsApp

Se reservará el mismo contrato:

- `channel.sms.*`
- `channel.whatsapp.*`

**Total audiencia ≠ elegibles ≠ disponibles ahora.**

---

# 11. CUSTOMER SEGMENTATION FACTS

No usar `etiqueta_vip` como verdad futura.

| key | type | semantics |
|---|---|---|
| `segment.value_tier` | enum | STANDARD/PREMIUM/GOLD/DIAMANTE calculado por policy versionada |
| `segment.lifecycle` | enum | PROSPECT/NEW/ACTIVE/INACTIVE/REACTIVATED u otros versionados |
| `segment.engagement` | enum | HIGH/MEDIUM/LOW calculado |
| `segment.traits` | set | PRODUCT_BUYER, SERVICE_BUYER, FREQUENT, HIGH_TICKET, etc. |
| `segment.policy_version` | text | versión exacta que produjo clasificación |
| `segment.calculated_at` | timestamp | timestamp de cálculo |

Fase 3 define umbrales/configuración; Fase 0 solo fija contrato.

---

# 12. ADVISOR FACTS / INTELLIGENCE INPUTS

Facts autorizados para análisis; no son asignación automática.

- `advisor.active_assignment_count`
- `advisor.available_work_count`
- `advisor.pending_followups`
- `advisor.today_calls`
- `advisor.today_appointments`
- `advisor.contacts_per_hour`
- `advisor.estimated_exhaustion_at`
- `advisor.segment_contact_rate`
- `advisor.segment_appointment_rate`
- `advisor.segment_attendance_rate`
- `advisor.segment_sale_rate`
- `advisor.segment_revenue`
- `advisor.segment_sample_size`
- `advisor.segment_affinity_score`
- `advisor.segment_affinity_confidence`

`affinity_score` debe ser explicable y mostrar `sample_size`; no es atribución causal si la trazabilidad histórica no la soporta.

---

# 13. OPERADORES AUDIENCE DSL V1

## Texto/enum/set

- `eq`
- `neq`
- `in`
- `not_in`
- `contains`
- `contains_any`
- `contains_all`
- `exists`
- `not_exists`

## Numérico

- `eq`
- `neq`
- `gt`
- `gte`
- `lt`
- `lte`
- `between`

## Fecha/timestamp

- `before`
- `after`
- `between`
- `within_last_days`
- `older_than_days`

## Boolean3

- `is_true`
- `is_false`
- `is_unknown`

Frontend no envía SQL. IA no envía SQL. Ambos envían `{field, operator, value}` validado contra este registry.

---

# 14. FRESHNESS POLICY

## Realtime / request-time

- llamadas recientes;
- citas futuras;
- ventas;
- asignaciones;
- disponibilidad actual;
- seguimientos.

## Incremental/cache corto

- email engagement;
- sets históricos;
- facts agregados costosos;
- identidad reconciliada.

## Batch

- tiers complejos;
- advisor affinity;
- recomendaciones IA;
- scoring analítico.

Todos los facts cacheados deben exponer `calculated_at`/`freshness_at` cuando sea relevante.

---

# 15. EXPLAINABILITY CONTRACT

Todo resultado usado para administración debe poder producir reason codes.

Ejemplo contacto incluido:

- `MATCH_LEAD_INTEREST_ENZIMAS`
- `MATCH_NO_SALE_ENZIMAS`
- `MATCH_LAST_CALL_47_DAYS`
- `MATCH_NO_FUTURE_APPOINTMENT`

Ejemplo no disponible para llamada:

- `CALLED_TODAY`
- `FUTURE_APPOINTMENT`
- `ASSIGNED_OTHER_ADVISOR`
- `LEASE_ACTIVE`
- `INVALID_PHONE`

KronIA traduce reason codes a lenguaje humano; no inventa la causa.

---

# 16. VERSIONADO

Cambiar la semántica de un fact crítico exige:

1. bump de registry/version;
2. documentación before/after;
3. tests de regresión;
4. impacto sobre audiencias guardadas;
5. mantener reproducibilidad de snapshots históricos.

**Versión inicial:** `fact_registry_version = 1`.
