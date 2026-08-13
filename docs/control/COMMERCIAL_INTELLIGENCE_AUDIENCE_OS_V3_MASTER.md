# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS V3

**Documento:** Product Spec V3 definitivo + Impact Report técnico + Mapa Maestro de implementación  
**Estado:** CURRENT / READY FOR PHASE 0  
**Fecha:** 2026-08-13  
**Repositorio:** `CESARJAUREGUITORRES/ascenda-os`  
**Baseline GitHub:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Rama documental:** `audit/commercial-intelligence-audience-v3-20260813`  
**Supabase operativo:** `ituyqwstonmhnfshnaqz`  
**Ámbito:** CRM comercial, Call Center, Agenda, Ventas, Seguimientos, Email, futuros SMS/WhatsApp, agentes IA y administración de bases.  
**Clasificación global:** HIGH por lectura transversal de dominios críticos; CRITICAL únicamente en fases que modifiquen RLS/GRANT/SECURITY DEFINER/Auth/secretos o despliegue productivo.

---

## 0. AUTORIDAD DEL DOCUMENTO

Este documento es la especificación canónica del subproyecto **Commercial Intelligence & Audience OS** dentro de ASCENDA OS.

Reglas de precedencia:

1. `AGENTS.md` y `docs/control/ASCENDA_CONTROL_MASTER.md` gobiernan el desarrollo general de ASCENDA.
2. Este documento gobierna funcional y técnicamente Bases, Audiencias, Segmentación, Activaciones, Asignaciones, Inteligencia Comercial y su integración con KronIA/agentes.
3. El código real en `app/` y el esquema vivo de Supabase siguen siendo la fuente de verdad ejecutable.
4. Ningún cambio de este documento habilita por sí mismo escrituras en producción.
5. Toda modificación estructural de base de datos debe entrar mediante migration versionada y el flujo branch → checks → PR → staging → validación → main.

Este documento sustituye conceptualmente las versiones preliminares discutidas en sesiones anteriores sobre “Gestión de Bases”, “Audience Engine” y “Commercial Data Engine”.

---

# 1. VISIÓN

Construir un **centro de control comercial transversal** capaz de transformar los datos operativos vivos de ASCENDA en audiencias utilizables, asignaciones controladas, oportunidades comerciales explicables y recomendaciones asistidas por IA.

El sistema debe responder, de manera determinista y auditable, preguntas como:

- ¿Qué contactos cumplen una condición comercial determinada?
- ¿Cuántos están disponibles ahora para un uso concreto?
- ¿Quiénes nunca fueron llamados, nunca recibieron determinado canal o llevan X días sin contacto?
- ¿Quién compró productos, servicios o un elemento específico?
- ¿Quién asistió, no asistió, reagendó o tiene cita futura?
- ¿Qué clientes son Standard, Premium, Gold o Diamante bajo una política versionada?
- ¿Qué base está trabajando cada asesor y cuánto le queda?
- ¿Qué asesor obtiene mejores resultados para un segmento concreto?
- ¿Qué oportunidades comerciales están apareciendo automáticamente?
- ¿Qué recomendación propone la IA, con qué evidencia y qué confianza?
- ¿Qué acción necesita aprobación administrativa?
- ¿Qué resultado generó una base, activación o asignación?

La información debe actualizarse automáticamente conforme ASCENDA recibe llamadas, citas, ventas, seguimientos, emails y demás eventos operativos. El administrador no debe reconstruir bases manualmente cada día.

---

# 2. PRINCIPIOS NO NEGOCIABLES

## 2.1 Una sola verdad de audiencia

Una audiencia pertenece a ASCENDA, no a un canal.

La misma audiencia puede ser utilizada desde:

- Call Center;
- Email;
- SMS;
- WhatsApp;
- automatizaciones;
- agentes IA;
- análisis comercial.

Cada canal aplica su propia lectura de elegibilidad/disponibilidad sin duplicar la audiencia.

## 2.2 Separar conceptos

Nunca mezclar en un único objeto:

- **Audiencia:** quién cumple reglas.
- **Elegibilidad:** quién puede utilizarse para un contexto/canal.
- **Activación:** para qué se utilizará la audiencia.
- **Asignación:** quién trabajará cada contacto.
- **Vista de trabajo:** qué subconjunto autorizado ve/prioriza el asesor.

## 2.3 Datos fuente intactos

El motor no moverá contactos físicamente entre `aos_pacientes`, `aos_leads`, `aos_llamadas`, `aos_agenda_citas`, `aos_ventas` u otras tablas.

Las nuevas capas deben ser de resolución, agregación, persistencia de definiciones y snapshots.

## 2.4 `numero_limpio` como puente actual, no identidad eterna

V1 usa `numero_limpio` como identificador transversal porque así funciona hoy ASCENDA. La arquitectura queda preparada para evolucionar a `contact_id` + aliases sin reescribir inmediatamente el core existente.

## 2.5 IA no reemplaza reglas

SQL/RPC/reglas determinísticas calculan cantidades, elegibilidad, disponibilidad y resultados. La IA interpreta, explica, recomienda y prepara solicitudes.

## 2.6 Human-in-the-loop para cambios de propiedad/recursos

Un asesor no puede autoasignarse una base nueva. Las solicitudes que afecten recursos fuera de su universo autorizado requieren aprobación de rol autorizado.

## 2.7 Explicabilidad

Toda clasificación, recomendación, inclusión/exclusión y score importante debe poder responder “¿por qué?”.

## 2.8 Versionado

Audiencias, políticas de tiers, reglas de recomendación y configuraciones que afecten resultados deben ser versionables.

## 2.9 No big bang

Cada fase se construye aislada, se compara, se prueba, se audita y se activa gradualmente.

---

# 3. ALCANCE FUNCIONAL

## Incluido

- identidad comercial operacional;
- datos demográficos no clínicos necesarios para segmentación;
- leads/campañas/anuncios;
- llamadas y tipificaciones;
- agenda y estados de citas;
- ventas, productos y servicios;
- seguimientos;
- email y futuros canales de mensajería;
- clasificación de valor y lifecycle;
- audiencias dinámicas y snapshots;
- activaciones;
- distribución y asignación a asesores;
- leases, capacidad y top-up;
- vistas personales;
- aprobaciones;
- recomendaciones IA;
- alertas de agotamiento/oportunidad;
- métricas y atribución comercial;
- observabilidad y auditoría.

## Fuera de alcance del motor de audiencias

No utilizar como features comerciales ordinarias:

- fotografías clínicas;
- diagnósticos;
- evoluciones clínicas;
- notas clínicas libres;
- prescripciones;
- historias clínicas completas;
- documentos médicos;
- firmas clínicas.

La validación jurídica/comercial de uso de datos es un prerrequisito externo ya asumido por el proyecto y no forma parte de este Product Spec. El sistema se diseña bajo la premisa operativa de que los datos incorporados al CRM son datos propios de la operación y se gestionan conforme a los procesos internos autorizados de la organización.

---

# 4. BASELINE DE DATOS RELEVANTE

Valores observados en la auditoría read-only previa a V3:

| Fuente | Filas aprox. | Identidades/números distintos aprox. |
|---|---:|---:|
| `aos_pacientes` | 7,660 | 7,155 |
| `aos_leads` | 5,403 | 5,088 |
| `aos_llamadas` | 34,188 | 5,917 |
| `aos_agenda_citas` | 3,022 | 1,183 |
| `aos_ventas` | 1,275 | 300 |
| `aos_seguimientos` | 524 | 457 normalizados |
| `aos_base_etiquetas` | 6,547 | 6,547 |

En las cinco fuentes principales se observaron alrededor de 11,571 números únicos, de los cuales 11,472 siguen el patrón interno predominante de 9 dígitos.

`aos_pacientes` presenta números duplicados y casos `FUSIONADO`, por lo que el sistema debe resolver identidad sin asumir 1 fila = 1 persona.

Ventas verificadas por tipo:

- `SERVICIO`: 870;
- `PRODUCTO`: 405.

Catálogo observado:

- servicios: 167;
- productos: 54.

---

# 5. ARQUITECTURA LÓGICA V3

```text
ASCENDA SOURCE DATA
        │
        ▼
IDENTITY RESOLUTION
contact_key / future contact_id / aliases / conflicts
        │
        ▼
CONTACT EVENT LAYER
calls · appointments · sales · email · followups · messaging
        │
        ▼
COMMERCIAL FACTS ENGINE
latest / never / counts / recency / value / states
        │
   ┌────┼─────────────┐
   ▼    ▼             ▼
TIERS  ENGAGEMENT   ADVISOR FACTS
   └────┼─────────────┘
        ▼
AUDIENCE ENGINE
DSL · AND/OR · presets · versions · overrides
        │
        ▼
CONTEXT / ELIGIBILITY ENGINE
channel · purpose · availability · pressure · permissions
        │
        ▼
ACTIVATION ENGINE
        │
 ┌──────┼───────────┐
 ▼      ▼           ▼
CALL   EMAIL      SMS/WA/OTHER
 │
 ▼
ASSIGNMENT ENGINE
capacity · lease · top-up · pool · priority
 │
 ▼
ADVISOR WORK ENGINE
queues · personal views · followups · recalls
 │
 ▼
OUTCOMES / ATTRIBUTION
 │
 ▼
COMMERCIAL INTELLIGENCE
Dante · León · Sofía · Valentina · Nico
 │
 ▼
KRONIA ORCHESTRATOR
explain · propose · request
 │
 ▼
GOVERNANCE / APPROVAL GATE
ALLOW · REQUIRE_APPROVAL · BLOCK
```

---

# 6. DATA MODEL V3 — OBJETOS PROPUESTOS

**Nota:** son contratos de diseño. No crear DDL hasta la fase correspondiente y su migration/Impact Report específico.

## 6.1 Identidad

### `aos_contactos` — futuro canónico

- `id uuid PK`
- `estado`
- `identity_conflict boolean`
- `created_at`
- `updated_at`

No se exige crear en la primera fase. V1 puede exponer `contact_key = numero_limpio` mediante vista/RPC.

### `aos_contact_identidades`

- `id uuid`
- `contact_id`
- `tipo` (`PHONE`, `EMAIL`, `PATIENT_ID`, `LEAD_ID`, etc.)
- `valor_normalizado`
- `es_principal`
- `confidence`
- `source_table`
- `source_id`
- timestamps

## 6.2 Audiencias

### `aos_audiencias`

- `id uuid`
- `nombre`
- `descripcion`
- `tipo` (`DYNAMIC`, `SNAPSHOT_DEFINITION`)
- `estado` (`ACTIVE`, `ARCHIVED`)
- `schema_version`
- `current_version`
- `created_by_user_id`
- timestamps

### `aos_audiencia_versiones`

- `id uuid`
- `audiencia_id`
- `version integer`
- `filter_dsl jsonb`
- `reason`
- `count_cache`
- `resolved_at`
- `created_by_user_id`
- `created_at`
- UNIQUE (`audiencia_id`, `version`)

### `aos_audiencia_miembros`

Para snapshots/inmutabilidad:

- `audiencia_version_id`
- `contact_key` / future `contact_id`
- `identity_conflict`
- `eligibility_snapshot jsonb`
- `facts_snapshot jsonb` mínimo necesario
- `resolved_at`
- UNIQUE (`audiencia_version_id`, `contact_key`)

### `aos_audiencia_overrides`

- `audiencia_id`
- `contact_key`
- `tipo` (`INCLUDE`, `EXCLUDE`)
- `reason`
- `expires_at`
- `created_by_user_id`
- timestamps

## 6.3 Activaciones

### `aos_audiencia_activaciones`

- `id uuid`
- `audiencia_version_id`
- `nombre`
- `purpose`
- `channel`
- `mode` (`BATCH`, `DYNAMIC`)
- `estado` (`DRAFT`, `ACTIVE`, `PAUSED`, `COMPLETED`, `CANCELLED`)
- `snapshot_version_id` nullable
- `created_by_user_id`
- `started_at`
- `ended_at`
- metadata

## 6.4 Asignaciones

### `aos_audiencia_asignaciones`

- `id uuid`
- `activation_id`
- `contact_key`
- `advisor_user_id`
- `estado` (`RESERVED`, `ASSIGNED`, `IN_PROGRESS`, `COMPLETED`, `RELEASED`, `EXPIRED`)
- `priority`
- `assigned_at`
- `must_start_before`
- `expires_at`
- `released_at`
- `release_reason`
- `assigned_by_user_id`
- metadata

Constraint de anti-doble-propiedad según la política definida para la activación.

### `aos_assignment_policies`

- `id`
- `nombre`
- `mode` (`MANUAL`, `EQUAL`, `PERCENTAGE`, `QUANTITY`, `CAPACITY`, `AFFINITY_ASSISTED`)
- `topup_mode` (`NONE`, `MAINTAIN_QUOTA`, `CONTINUOUS`)
- `target_available`
- `lease_minutes`
- `config jsonb`
- `active`
- version/timestamps

## 6.5 Solicitudes y aprobaciones

### `aos_audiencia_solicitudes`

- `id uuid`
- `tipo`
- `requester_user_id`
- `advisor_user_id`
- `current_activation_id`
- `requested_audience_id`
- `requested_quantity`
- `propuesta jsonb`
- `estado` (`PENDING`, `APPROVED`, `REJECTED`, `EXPIRED`, `EXECUTED`, `CANCELLED`)
- `valid_until`
- `approved_by_user_id`
- `decision_reason`
- `resolved_at`
- `executed_at`
- timestamps

La transición PENDING → decisión debe ser atómica.

## 6.6 Segmentación y tiers

### `aos_customer_tier_policies`

- `id`
- `nombre`
- `version`
- `effective_from`
- `effective_to`
- `reglas jsonb`
- `active`
- audit fields

### `aos_customer_segments`

No reemplaza las audiencias. Registra clasificaciones materiales calculadas cuando sea útil:

- `contact_key`
- `value_tier` (`STANDARD`, `PREMIUM`, `GOLD`, `DIAMANTE`)
- `lifecycle`
- `engagement`
- `traits jsonb`
- `policy_version`
- `calculated_at`
- `explanation jsonb`

## 6.7 Recomendaciones IA

### `aos_audience_recommendations`

- `id uuid`
- `tipo`
- `advisor_user_id`
- `audience_id`
- `activation_id`
- `score`
- `confidence`
- `sample_size`
- `reason_codes jsonb`
- `evidence jsonb`
- `recommendation jsonb`
- `mode` (`SHADOW`, `VISIBLE`, `PREPARED`, `AUTO_POLICY`)
- `accepted`
- `edited`
- `rejected`
- `admin_reason`
- `outcome jsonb`
- `generated_at`
- `valid_until`
- timestamps

## 6.8 Jobs

### `aos_jobs` solo si se decide implementar cola propia.

Preferencia técnica: evaluar primero Graphile Worker o pg-boss sobre PostgreSQL antes de inventar una cola completa.

---

# 7. CONTACT EVENT MODEL

No sustituye inicialmente las tablas operativas. Es una capa normalizada de lectura/proyección.

Contrato lógico:

```text
contact_key
contact_id (future)
event_type
channel
direction
purpose
status
occurred_at
advisor_user_id
campaign_id
activation_id
assignment_id
source_table
source_id
metadata
```

Eventos iniciales:

- `LEAD_CREATED`
- `CALL_ATTEMPTED`
- `CALL_CONTACTED`
- `CALL_TYPED`
- `FOLLOWUP_CREATED`
- `FOLLOWUP_DUE`
- `APPOINTMENT_CREATED`
- `APPOINTMENT_CONFIRMED`
- `APPOINTMENT_ATTENDED`
- `APPOINTMENT_NO_SHOW`
- `APPOINTMENT_CANCELLED`
- `SALE_CREATED`
- `PRODUCT_PURCHASED`
- `SERVICE_PURCHASED`
- `EMAIL_SENT`
- `EMAIL_DELIVERED`
- `EMAIL_OPENED`
- `EMAIL_CLICKED`
- `EMAIL_BOUNCED`
- futuros `SMS_*`
- futuros `WHATSAPP_*`

---

# 8. FACT REGISTRY V1

El **Fact Registry** es obligatorio. Ningún filtro de Audience Engine se conecta a una columna cruda sin definición semántica.

Cada fact debe registrar:

- `key` estable;
- label visible;
- descripción;
- tipo de dato;
- fuente(s);
- semántica de agregación;
- `YES/NO/UNKNOWN` cuando aplique;
- freshness;
- sensibilidad operacional;
- roles que pueden consultarlo;
- operadores permitidos;
- ejemplos y tests.

## 8.1 Identity facts

- `contact.phone_valid`
- `contact.email_valid`
- `contact.identity_conflict`
- `contact.exists_as_patient`
- `contact.exists_as_lead`
- `contact.branch`
- `contact.department`
- `contact.city`
- `contact.district`

## 8.2 Lead facts

- `lead.exists`
- `lead.first_at`
- `lead.last_at`
- `lead.days_since_last`
- `lead.count`
- `lead.latest_treatment`
- `lead.latest_ad`
- `lead.campaign`
- `lead.commercial_type` (`PRODUCT`, `SERVICE`, `MIXED`, `UNKNOWN`)

## 8.3 Call facts

- `calls.total`
- `calls.never_called`
- `calls.last_at`
- `calls.days_since_last`
- `calls.called_today`
- `calls.latest_status`
- `calls.latest_substatus`
- `calls.ever_status[]`
- `calls.latest_advisor_id`
- `calls.attempts_total`
- `calls.contact_effective_count`

**Regla:** `ever_status` y `latest_status` son conceptos diferentes.

## 8.4 Appointment facts

- `appointments.total`
- `appointments.never_had`
- `appointments.last_at`
- `appointments.last_status`
- `appointments.next_at`
- `appointments.has_future`
- `appointments.no_show_count`
- `appointments.no_show_last_30d`
- `appointments.attended_count`
- `appointments.last_attended_at`
- `appointments.latest_treatment`
- `appointments.latest_branch`

## 8.5 Sales facts

- `sales.total`
- `sales.never_bought`
- `sales.last_at`
- `sales.days_since_last`
- `sales.revenue_lifetime`
- `sales.revenue_12m`
- `sales.average_ticket`
- `sales.product_count`
- `sales.service_count`
- `sales.has_product_purchase`
- `sales.has_service_purchase`
- `sales.has_purchased_item(item)`
- `sales.last_product`
- `sales.last_service`
- `sales.last_branch`
- `sales.latest_advisor_id`

## 8.6 Follow-up facts

- `followups.total`
- `followups.pending_count`
- `followups.overdue_count`
- `followups.next_at`
- `followups.latest_status`
- `followups.latest_treatment`
- `followups.latest_advisor_id`

## 8.7 Email facts

El resolver debe consolidar fuentes históricas fragmentadas (`aos_emails_enviados`, `aos_email_envios`, `aos_email_flujo_ejecuciones`, `aos_email_eventos`, `aos_email_cadencia`) y no asumir una sola tabla como verdad completa.

- `email.total_sent`
- `email.never_sent` (`YES/NO/UNKNOWN` cuando la vinculación histórica no sea confiable)
- `email.last_sent_at`
- `email.days_since_last`
- `email.delivered_count`
- `email.opened_count`
- `email.clicked_count`
- `email.bounced_count`
- `email.last_event_at`

## 8.8 Future SMS/WhatsApp facts

- `sms.total_sent`
- `sms.never_sent`
- `sms.last_sent_at`
- `sms.delivered_count`
- `sms.failed_count`
- `sms.replied_count`
- `wa.total_outbound`
- `wa.total_inbound`
- `wa.never_contacted`
- `wa.last_outbound_at`
- `wa.last_inbound_at`
- `wa.replied`

## 8.9 Segmentation facts

- `segment.value_tier`
- `segment.lifecycle`
- `segment.engagement`
- `segment.traits[]`
- `segment.calculated_at`
- `segment.policy_version`

## 8.10 Advisor facts

- `advisor.current_available_count`
- `advisor.assigned_pending_count`
- `advisor.followups_pending`
- `advisor.calls_per_hour`
- `advisor.contact_rate`
- `advisor.appointment_rate`
- `advisor.attendance_rate`
- `advisor.sale_rate`
- `advisor.average_ticket`
- `advisor.revenue`
- `advisor.affinity(segment)`
- `advisor.affinity_confidence(segment)`
- `advisor.affinity_sample_size(segment)`

---

# 9. AUDIENCE FILTER DSL

La IA y el frontend nunca envían SQL arbitrario.

Formato conceptual:

```json
{
  "version": 1,
  "root": {
    "op": "AND",
    "rules": [
      {"field":"lead.latest_treatment","operator":"contains","value":"ENZIMAS"},
      {"field":"sales.has_purchased_item","operator":"eq","value":{"item":"ENZIMAS","result":false}},
      {"op":"OR","rules":[
        {"field":"calls.never_called","operator":"eq","value":true},
        {"field":"calls.days_since_last","operator":"gt","value":30}
      ]},
      {"field":"appointments.has_future","operator":"eq","value":false}
    ]
  }
}
```

V1 visual limita anidamiento a dos niveles salvo necesidad demostrada.

Operadores registrados por tipo:

- texto: `eq`, `neq`, `contains`, `in`, `not_in`, `exists`, `not_exists`;
- número: `eq`, `gt`, `gte`, `lt`, `lte`, `between`;
- fecha: `before`, `after`, `between`, `within_last_days`, `older_than_days`;
- boolean/tri-state: `true`, `false`, `unknown`.

---

# 10. AUDIENCIAS DINÁMICAS, SNAPSHOTS Y OVERRIDES

## Dinámica

Guarda definición. Recalcula miembros según el estado vivo de los facts.

Usos:

- colas continuas;
- monitoreo;
- automatizaciones;
- oportunidades IA.

## Snapshot

Congela miembros y facts mínimos relevantes en un momento determinado.

Usos:

- campañas;
- lotes de llamadas;
- atribución;
- reproducibilidad;
- auditoría.

## Regla de campaña

Una ejecución masiva no opera directamente sobre una audiencia dinámica mutable. Debe resolver un snapshot de ejecución.

## Overrides

`INCLUDE` / `EXCLUDE` con motivo, autor y expiración opcional. No se modifica la regla global para resolver una excepción individual.

## Diff obligatorio

Antes de publicar una nueva versión de audiencia:

- miembros antes;
- miembros después;
- entradas;
- salidas;
- cambios relevantes por segmento.

---

# 11. CHANNEL CONTEXT / ELIGIBILITY

Una misma audiencia muestra tres cifras:

1. **Total:** cumplen la audiencia.
2. **Elegibles:** cumplen las reglas del contexto/canal.
3. **Disponibles ahora:** además no están bloqueados por estado operativo momentáneo.

Ejemplo Call Center:

- total 500;
- elegibles 440;
- disponibles 397.

Motivos de indisponibilidad pueden incluir:

- llamado hoy;
- asignado/en curso con otro asesor;
- cita futura según el purpose;
- lease vigente;
- estado de cola;
- regla de activación.

No se confunde una tipificación comercial con una preferencia/estado operacional global.

---

# 12. PROPÓSITOS OPERACIONALES

Toda activación declara `purpose` para evitar interpretar de la misma forma contactos con objetivos diferentes.

V1:

- `COMMERCIAL_PROSPECTING`
- `COMMERCIAL_REACTIVATION`
- `COMMERCIAL_CROSSSELL`
- `COMMERCIAL_REPURCHASE`
- `APPOINTMENT_RECOVERY`
- `FOLLOWUP_OPERATIONAL`
- `APPOINTMENT_OPERATIONAL`
- `PAYMENT_OPERATIONAL`

La validación jurídica de estos usos no forma parte del motor. El propósito existe para gobernar reglas operativas, cadencias, disponibilidad y análisis.

---

# 13. CONTACT PRESSURE / CADENCE

Evitar que un contacto reciba múltiples activaciones simultáneas sin coordinación.

El motor debe poder expresar, por purpose y canal:

- contacto comercial reciente;
- llamada reciente;
- email reciente;
- SMS reciente;
- WhatsApp reciente;
- conversación activa;
- compra/cita reciente que invalida una reactivación.

Los umbrales deben ser configurables, no hardcodeados en cada frontend.

---

# 14. ASSIGNMENT ENGINE

## 14.1 Modos

- manual;
- equitativo;
- porcentaje;
- cantidades;
- por capacidad;
- recomendado por afinidad con aprobación.

## 14.2 Lease

Los contactos no son propiedad perpetua del asesor.

Estados:

`RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED`

Salidas:

`RELEASED`, `EXPIRED`.

## 14.3 Top-up

- `NONE`: no agrega contactos.
- `MAINTAIN_QUOTA`: repone hasta un umbral.
- `CONTINUOUS`: nuevos contactos elegibles entran según política.

## 14.4 Agotamiento

La métrica correcta es **eligible unworked remaining**.

Estimación:

`remaining / recent_contacts_per_hour`.

Genera alerta antes de llegar a cero.

## 14.5 Advisor identity

Asignar por `aos_usuarios.id` / identidad verificable, no por nombre hardcodeado. `codigo_asesor` puede funcionar como alias operacional mientras se migra.

---

# 15. CUSTOMER SEGMENTATION ENGINE

No reutilizar `etiqueta_vip` como verdad futura única.

Dimensiones separadas:

## Value Tier

- STANDARD
- PREMIUM
- GOLD
- DIAMANTE

## Lifecycle

- PROSPECT
- NEW
- ACTIVE
- INACTIVE
- REACTIVATED

## Engagement

- HIGH
- MEDIUM
- LOW

## Traits

Ejemplos:

- PRODUCT_BUYER
- SERVICE_BUYER
- CROSSSELL_CANDIDATE
- FREQUENT
- HIGH_TICKET
- REPURCHASE_WINDOW
- NO_SHOW_HISTORY
- FOLLOWUP_OVERDUE

La política de tier debe ser versionada y explicable.

No fijar umbrales definitivos en este documento: deben definirse con análisis comercial de distribución y validación administrativa antes de Fase 3.

---

# 16. ADVISOR AFFINITY & INTELLIGENCE

El sistema puede recomendar asesor × segmento, pero no debe caer en el sesgo “mejor asesor recibe siempre los mejores leads”.

Features posibles:

- contact rate;
- appointment rate;
- attendance rate;
- sale rate;
- average ticket;
- revenue;
- response speed;
- follow-up completion;
- workload;
- sample size;
- recency;
- segment/tratamiento/producto/servicio.

Toda recomendación expone:

- score;
- confidence;
- sample size;
- reason codes;
- evidencia;
- timestamp.

Primera implementación: fórmula determinista + explicación IA.

No usar causalidad donde solo existe correlación histórica. Los campos recientes `lead_id_origen` / `llamada_id_origen` deben ir ganando cobertura antes de afirmar atribución exacta.

---

# 17. IA MULTIAGENTE

## Dante / Centinela

- vigilar leads sin contactar;
- detectar pools abandonados;
- detectar oportunidades urgentes.

## León / Monitor

- capacidad;
- agotamiento;
- carga;
- semáforo del equipo;
- continuidad operacional.

## Sofía / Analista

- métricas por asesor;
- afinidad;
- recompra;
- clientes inactivos;
- valor/LTV.

## Valentina / Marketing

- oportunidades por campaña;
- segmentos derivados de performance comercial.

## Nico / Clasificador

- futuro aporte a prioridad/potencial cuando `clasificacion_nico` sea normalizada y evaluada.

## KronIA / Coordinadora

KronIA no es el algoritmo único. Es la interfaz conversacional/orquestadora:

- consulta;
- explicación;
- construcción asistida de audiencias;
- propuesta;
- solicitud;
- notificación;
- seguimiento de aprobación.

---

# 18. KRONIA — MODOS DE OPERACIÓN

## Modo 1 — Consulta

Puede responder sobre el universo permitido al usuario.

## Modo 2 — Organización personal

Un asesor puede pedir reordenar **sus propios contactos autorizados** por seguimientos, clientes de mayor valor, rellamadas u otras vistas permitidas.

No cambia propiedad.

## Modo 3 — Solicitud de recurso

Si pide contactos fuera de su universo:

1. interpretar intención;
2. resolver audiencia;
3. calcular disponibilidad;
4. generar propuesta;
5. crear solicitud estructurada;
6. notificar administrador;
7. esperar decisión;
8. revalidar al aprobar;
9. ejecutar;
10. notificar resultado.

KronIA nunca recibe autorización por un rol enviado libremente desde el navegador.

---

# 19. POLICY / GOVERNANCE GATE

Toda acción estructurada clasifica en:

- `ALLOW`
- `REQUIRE_APPROVAL`
- `BLOCK`

La decisión proviene de reglas de servidor, identidad autenticada, rol/permisos y estado de datos, no del LLM.

La IA no ejecuta SQL de escritura arbitrario.

---

# 20. MATRIZ DE PERMISOS V1

Permisos funcionales propuestos:

- `audiences.view`
- `audiences.manage`
- `audiences.assign`
- `audiences.activate`
- `audiences.approve`
- `audiences.audit`
- `audiences.consume_own`
- `audiences.request_change`
- `audiences.view_team_metrics`
- `audiences.view_ai_recommendations`

## ADMIN / rol delegado de gestión

Puede recibir todos los permisos anteriores según configuración.

## ASESOR normal

Base inicial:

- `consume_own`
- `request_change`

Puede:

- ver su cola;
- ver sus métricas;
- reorganizar vistas de contactos propios permitidos;
- pedir ayuda a KronIA;
- solicitar otra base.

No puede:

- crear/modificar audiencias globales;
- autoasignarse contactos;
- quitar contactos a otro asesor;
- cambiar políticas de distribución;
- aprobar su propia solicitud.

## Agentes IA

No se modelan como usuarios omnipotentes. Cada tool/action tiene objetos y operaciones explícitamente permitidos.

---

# 21. APPROVAL WORKFLOW

Estados:

```text
PENDING
  ├─ APPROVED → revalidate → EXECUTED
  ├─ REJECTED
  ├─ EXPIRED
  └─ CANCELLED
```

La recomendación/solicitud guarda:

- generated_at;
- valid_until;
- count_at_generation;
- versión de audiencia;
- propuesta.

Al aprobar:

1. lock/transición atómica;
2. revalidar permisos;
3. volver a resolver disponibilidad;
4. detectar cambios materiales;
5. ejecutar o pedir reconfirmación si el contexto cambió significativamente;
6. auditar.

Dos administradores no pueden aprobar dos veces la misma solicitud.

---

# 22. SHADOW MODE Y MADUREZ DE IA

## Nivel 0

Manual.

## Nivel 1 — SHADOW

IA genera recomendación internamente y se compara con decisión humana/outcome. No altera trabajo.

## Nivel 2 — VISIBLE

IA recomienda y explica.

## Nivel 3 — PREPARED

IA prepara distribución/acción; administrador confirma.

## Nivel 4 — AUTO_POLICY

Solo bajo políticas preaprobadas y límites explícitos.

No comenzar en Nivel 4.

---

# 23. JOBS / BACKGROUND PROCESSING

Operaciones que no deben depender de una petición HTTP larga:

- resolución de snapshots grandes;
- recálculo de facts derivados;
- tiers;
- afinidad;
- recomendaciones IA;
- top-up;
- expiración de leases;
- reconciliaciones;
- futuros envíos masivos;
- métricas de outcome.

Candidato preferente para evaluación técnica: **Graphile Worker o pg-boss**, por usar PostgreSQL y encajar con Node/Railway/Supabase.

No introducir Redis, Kafka o Temporal sin necesidad demostrada.

---

# 24. FRESHNESS / ACTUALIZACIÓN AUTOMÁTICA

No recalcular todo constantemente.

## Tier 1 — realtime/on-read

- disponibilidad actual;
- llamadas de hoy;
- citas futuras;
- locks/asignaciones;
- estado de solicitudes.

## Tier 2 — incremental / event-driven job

- últimas interacciones;
- contadores;
- engagement por canal;
- facts agregados.

## Tier 3 — batch controlado

- tiering complejo;
- LTV;
- advisor affinity;
- recomendaciones IA;
- análisis de oportunidades.

Todo objeto derivado expone `calculated_at` / `resolved_at`.

---

# 25. OBSERVABILIDAD

El módulo debe exponer salud y comportamiento, no solo resultados comerciales.

## Métricas técnicas

- audience_resolve_count;
- audience_resolve_latency_p50/p95/p99;
- audience_resolve_errors;
- fact_refresh_latency;
- job_queue_depth;
- job_failures/retries;
- snapshot_build_duration;
- stale_fact_count;
- approval_latency;
- assignment_conflicts;
- expired_leases;
- topup_runs;
- AI recommendation latency/cost;
- AI recommendation acceptance rate.

## Métricas de negocio

- contactos por audiencia;
- total/elegible/disponible;
- trabajados;
- contacto efectivo;
- citas;
- asistencia;
- ventas;
- facturación;
- conversiones por base;
- conversiones por asesor/segmento;
- revenue por activación;
- agotamiento/capacidad;
- oportunidades detectadas y aprovechadas.

## Auditoría

Registrar cambios de:

- audiencia;
- versión;
- override;
- activación;
- assignment policy;
- asignación;
- solicitud;
- aprobación;
- tier policy;
- recomendación aplicada.

---

# 26. OBJETIVOS DE PERFORMANCE

Objetivos iniciales sujetos a benchmark real:

- count/preview de audiencia normal P95 < 1.5 s;
- audiencia compleja P95 < 2.5 s;
- preview inicial máximo 100 contactos;
- no descargar miles de registros al browser para filtrar en JS;
- evitar joins cartesianos entre llamadas × ventas × citas;
- resolver agregaciones por `contact_key` y unir 1:1.

Antes de índices nuevos: `EXPLAIN (ANALYZE, BUFFERS)` en staging/controlado.

---

# 27. FRONTEND / DESIGN SYSTEM OBLIGATORIO

El nuevo panel debe respetar la interfaz productiva actual de ASCENDA.

## Referencias reales

`app/public/admin-calls.html` y `app/public/admin-marketing.html` establecen actualmente:

- tipografía principal: `DM Sans`;
- títulos/KPI: `Exo 2`;
- navy: `#071D4A` / `#0D1B3E`;
- primary blue: `#0A4FBF`;
- cyan/teal: `#00C9A7`;
- border: `#DDE4F5`;
- surface soft: `#F0F4FC`, `#F8FAFF`;
- cards blancas;
- radios de cards 14 px;
- modales alrededor de 20 px;
- overlays navy semitransparent con `backdrop-filter: blur(6px)`;
- botones compactos y didácticos;
- chips/tags semánticos;
- responsive.

## Prohibiciones UI

No usar para interacción productiva normal:

- `window.alert()` como experiencia principal;
- `window.confirm()` como modal de negocio;
- prompts nativos;
- modales negros genéricos ajenos a ASCENDA;
- componentes visuales que rompan el shell;
- estilos importados que reemplacen globalmente el lenguaje existente sin revisión.

## Regla de desarrollo visual

Antes de crear una pantalla:

1. revisar paneles productivos equivalentes;
2. extraer/reutilizar tokens;
3. crear estados loading/empty/error;
4. validar desktop/tablet/mobile;
5. mantener jerarquía visual y densidad de ASCENDA.

Si se incorpora una librería CSS futura, debe ser compatible con el design system y no convertirse en una reescritura visual de todo el producto.

---

# 28. PANEL CENTRAL — INFORMATION ARCHITECTURE

Nombre funcional inicial: **Bases & Audiencias**.

Secciones previstas:

1. **Dashboard**
2. **Audiencias**
3. **Constructor**
4. **Distribución**
5. **Asesores**
6. **Oportunidades IA**
7. **Solicitudes**
8. **Segmentación**
9. **Activaciones**
10. **Historial / Auditoría**

## Dashboard

Debe poder mostrar automáticamente:

- contactos totales;
- bases dinámicas;
- snapshots;
- leads nunca llamados;
- seguimientos pendientes;
- no-show recuperables;
- clientes por tier;
- bases activas;
- carga por asesor;
- asesores próximos a quedarse sin contactos;
- oportunidades IA;
- outcomes recientes.

## Biblioteca de Audiencias

Cada audiencia muestra:

- nombre;
- tipo;
- versión;
- total;
- updated/resolved at;
- usos activos;
- owner/autor;
- acciones permitidas.

## Constructor

Tres áreas:

- fuentes/facts;
- reglas AND/OR;
- preview vivo y explicación.

## Distribución

- seleccionar audiencia/activación;
- elegir asesores elegibles;
- reparto manual/equitativo/%/cantidad;
- lease/top-up;
- preview de impacto;
- aplicar bajo permisos.

## Asesores

Por asesor:

- base actual;
- asignados;
- trabajados;
- pendientes;
- eligible remaining;
- estimación agotamiento;
- followups;
- citas;
- afinidades;
- recomendación IA.

## Oportunidades IA

Cards accionables:

- leads nuevos sin trabajar;
- clientes de alto valor inactivos;
- no-show sin nueva cita;
- ventana de recompra;
- base próxima a agotarse;
- segmentos con performance relevante.

---

# 29. INTEGRACIONES CONTEXTUALES CON OTROS PANELES

## Call Center

Botón: `Seleccionar / Administrar Base`.

Muestra la biblioteca central en contexto Call:

- total;
- elegibles;
- disponibles;
- nunca llamados;
- llamados hoy;
- asignación/capacidad.

El asesor normal solo ve su cola/vistas autorizadas.

## Email

Selector central de audiencia:

- total;
- con email;
- historial;
- elegibles/disponibles para la activación;
- snapshot antes de campaña.

## SMS / WhatsApp

Futuras vistas del mismo motor, sin tablas de audiencias específicas por canal.

## KronIA

Puede invocar el resolver y crear solicitudes/consultas según permissions gate.

---

# 30. MIGRACIÓN DE `aos_email_audiencias`

Estado observado: tabla existente sin uso histórico material y `aos_email_campanias` también sin campañas manuales registradas al momento de la auditoría.

Estrategia:

1. no eliminar ni renombrar inmediatamente;
2. crear modelo central nuevo cuando corresponda;
3. integrar Email al modelo central;
4. migrar FK de campañas en una fase específica;
5. deprecar tabla antigua después de comprobar consumidores;
6. eliminar solo mediante migration posterior explícita si se autoriza.

---

# 31. CALL CENTER — COMPATIBILIDAD

El flujo actual de siguiente lead tiene contratos productivos y exclusiones importantes.

No modificar `aos_siguiente_lead` ni sustituir de golpe la cola actual.

Estrategia:

- mantener V2 como fallback;
- crear una ruta V3 paralela cuando llegue la fase Call Center;
- feature flag;
- si `tipo_cola != audiencia`, preservar comportamiento vigente;
- si `tipo_cola = audiencia`, resolver miembros → disponibilidad → anti-duplicado → assignment → siguiente contacto;
- rollback inmediato a V2.

---

# 32. IMPACT REPORT GLOBAL

## Cambio propuesto

Introducir un módulo transversal de inteligencia comercial y audiencias con nuevas capas read-only iniciales, persistencia posterior de audiencias/activaciones/asignaciones y futuras integraciones controladas con Call Center, Email, mensajería y agentes.

## Riesgo

- **HIGH:** por lectura y eventual integración con `aos_pacientes`, `aos_leads`, `aos_llamadas`, `aos_agenda_citas`, `aos_ventas`, `aos_seguimientos`.
- **CRITICAL:** cualquier fase que cambie RLS, GRANT, `SECURITY DEFINER`, auth, secretos o infraestructura.

## Tablas críticas afectadas inicialmente

Fases 0–2: lectura únicamente de fuentes críticas.

No realizar UPDATE/DELETE masivo como parte del Audience Engine.

## Dependencias críticas

- `numero_limpio` transversal;
- `aos_siguiente_lead*`;
- `aos_cola_config`;
- email tables;
- `aos_usuarios` y permisos;
- KronIA/agentes;
- future channel providers.

## Blast radius si se implementa incorrectamente

- duplicar contactos;
- asignar un contacto a dos asesores;
- excluir erróneamente leads prioritarios;
- alterar cola productiva;
- campañas sobre población incorrecta;
- scores sesgados;
- sobrecarga de consultas Supabase;
- exposición de datos entre roles;
- acciones IA sin aprobación.

## Mitigaciones

- read-only first;
- versioned migrations;
- feature flags;
- V2 call queue intacta;
- snapshot reproducible;
- unique constraints de asignación;
- policy gate;
- approval workflow atómico;
- benchmarks;
- staging;
- rollback probado;
- observabilidad.

---

# 33. GATES DE CALIDAD POR FASE

Cada fase debe completar este loop:

1. baseline conocido;
2. alcance cerrado;
3. Impact Report específico si HIGH/CRITICAL;
4. implementación aislada;
5. sintaxis/checks;
6. tests unitarios/contrato;
7. comparación con datos reales;
8. pruebas edge cases;
9. prueba por rol;
10. prueba responsive si toca UI;
11. staging;
12. smoke/E2E relevante;
13. rollback probado;
14. activación gradual;
15. observación;
16. cierre documentado;
17. actualizar continuidad Supabase/GitHub.

Una fase no se declara DONE por “verse bien”. Debe pasar sus gates.

---

# 34. ROADMAP MAESTRO — 19 FASES

## FASE 0 — Baseline & Contracts

**Objetivo:** fijar contratos antes de código funcional.

Entregables:

- baseline GitHub/Supabase;
- mapa de fuentes;
- Fact Registry V1 formal;
- nomenclatura;
- catálogo de estados;
- permisos;
- métricas baseline;
- tests de referencia;
- wireframe inicial del panel;
- feature flag plan.

**Salida:** arquitectura implementable sin ambigüedad.

## FASE 1 — Identity Resolver Read-only

- `contact_key`;
- dedupe;
- FUSIONADO;
- phone/email validity;
- identity conflict;
- preview de conflictos;
- sin cambios a datos fuente.

## FASE 2 — Commercial Facts Read-only

- calls;
- appointments;
- sales;
- product/service;
- followups;
- email resolver;
- timestamps/freshness;
- tri-state.

## FASE 3 — Segmentation Engine

- value tier policy;
- lifecycle;
- engagement;
- traits;
- explicación;
- shadow against `etiqueta_vip` sin reemplazarla.

## FASE 4 — Audience Resolver Read-only

- DSL;
- AND/OR;
- presets;
- count;
- preview;
- explanation;
- performance benchmarks.

## FASE 5 — Panel Central Skeleton

- alta del panel en shell admin;
- dashboard read-only;
- navegación de secciones;
- design system;
- responsive;
- estados loading/error/empty;
- sin control operativo todavía.

## FASE 6 — Audience Library Persistence

- `aos_audiencias`;
- versiones;
- guardar/duplicar/archivar;
- overrides;
- diff;
- auditoría.

## FASE 7 — Snapshots & Activation Core

- snapshots inmutables;
- activaciones;
- purpose/channel/mode;
- historial de uso.

## FASE 8 — Channel Context & Availability

- total/elegible/disponible;
- cadencia/pressure operacional;
- Call context;
- Email context;
- arquitectura lista para futuros canales.

## FASE 9 — Assignment Engine

- assignment policies;
- manual/equal/%/quantity;
- leases;
- pool;
- top-up;
- anti-double-assignment;
- capacidad.

## FASE 10 — Advisor Control Center

- carga por asesor;
- remaining;
- ETA de agotamiento;
- followups/citas;
- afinidad shadow;
- admin actions.

## FASE 11 — Call Center Integration V3

- V3 paralela;
- feature flag;
- base → activación → assignment → next lead;
- fallback V2;
- rollout por usuarios.

## FASE 12 — Advisor Work Views

- propios seguimientos;
- rellamadas;
- mejores clientes propios;
- priorización temporal;
- sin cambio de propiedad;
- KronIA consulta sobre universo autorizado.

## FASE 13 — Requests & Approval Engine

- solicitudes;
- popups/notificaciones;
- approve/reject/edit;
- expiración;
- revalidación;
- ejecución atómica;
- auditoría.

## FASE 14 — Commercial Intelligence Shadow

- opportunities;
- advisor affinity;
- base exhaustion;
- recommended next audience;
- confidence/sample size;
- shadow evaluation.

## FASE 15 — KronIA + Multiagent Orchestration

- Dante/León/Sofía/Valentina/Nico;
- tool contracts;
- policy gate;
- structured actions;
- recommendation→request flow;
- no arbitrary write SQL.

## FASE 16 — Email Integration

- `Nueva Campaña` consume audience central;
- snapshot;
- recipient tracking;
- consolidación del modelo antiguo;
- mantener flows existentes.

## FASE 17 — SMS / WhatsApp / Future Channels

- provider/backend específico;
- mismo Audience Engine;
- channel facts;
- tracking;
- inbound/outbound cuando aplique;
- sin audiencias duplicadas por canal.

## FASE 18 — Attribution, Learning & Hardening

- activación → asesor/canal → cita → asistencia → venta → facturación;
- outcomes IA;
- recommendation lift;
- performance/load;
- job resilience;
- security hardening;
- full observability;
- documentación final;
- reusable architecture package.

---

# 35. PRESETS V1 PREVISTOS

## Leads

- Nuevos sin llamar — hoy;
- Nuevos sin llamar — 24h;
- Nuevos sin llamar — 3 días;
- Nuevos sin llamar — 7 días;
- Históricos nunca llamados;
- Recontacto;
- Sin compra;
- producto vs servicio.

## Agenda

- última cita NO ASISTIO;
- no-show últimos 30 días;
- no-show sin cita futura;
- asistieron;
- reagendados;
- cita futura;
- sin cita futura.

## Clientes

- compradores de productos;
- compradores de servicios;
- nunca compró X;
- compró X;
- ventana recompra;
- inactivos;
- Standard/Premium/Gold/Diamante.

## Comunicación

- nunca llamado;
- 30/60 días sin llamada;
- nunca email;
- 30/60 días sin email;
- futuros nunca SMS/WhatsApp.

---

# 36. FRONTEND — MODALES Y INTERACCIONES

Todos los modales del panel deben usar componentes propios de ASCENDA:

- overlay semitransparente;
- blur;
- surface blanca;
- radius ~20px;
- sticky header cuando la longitud lo amerite;
- footer con acciones;
- primary/secondary buttons;
- close control;
- focus/keyboard behavior;
- estado de confirmación visible;
- evitar modales anidados cuando sea posible.

Flujos críticos de aprobación deben mostrar:

- objeto afectado;
- cantidades;
- antes/después;
- asesor/es;
- reason/recommendation;
- action primaria;
- cancelar/rechazar;
- resultado.

---

# 37. SECURITY / ENGINEERING GUARDRAILS

Aunque la validación jurídica no forma parte del scope, la ingeniería mantiene:

- autorización basada en identidad real;
- mínimo privilegio;
- separación admin/asesor;
- no confiar en rol del browser;
- no secrets en frontend;
- no SQL arbitrario desde IA;
- no writes directos de LLM;
- audit trail;
- revalidación server-side;
- snapshots para acciones masivas;
- rollback/feature flags;
- limitar datos enviados a modelos IA a features necesarias.

Notas libres de usuario/paciente se consideran contenido no confiable y no instrucciones para herramientas.

---

# 38. TESTING MASTER MATRIX

## Identity

- duplicados;
- fusionados;
- teléfonos inválidos;
- múltiples pacientes activos mismo número;
- contacto solo lead;
- contacto solo paciente.

## Facts

- nunca vs unknown;
- última vs alguna vez;
- producto vs servicio;
- última cita vs cita histórica;
- futura vs pasada;
- email consolidado.

## Audiences

- AND;
- OR;
- nesting;
- override;
- versioning;
- snapshot immutability;
- diff.

## Assignments

- reparto;
- lease;
- expiry;
- top-up;
- double-claim;
- concurrent admins.

## Permissions

- admin;
- asesor;
- asesor sobre otro asesor;
- agent;
- approval self-request.

## AI

- recommendation with evidence;
- stale recommendation;
- prompt injection text;
- blocked action;
- approval required;
- shadow outcome.

## UI

- desktop;
- tablet;
- mobile;
- loading;
- empty;
- errors;
- modals;
- keyboard/focus básico.

---

# 39. ROLLBACK MASTER

- Fases read-only: deshabilitar panel/feature flag, sin tocar datos fuente.
- Persistencia: objetos nuevos backward-compatible; no borrar fuentes.
- Call integration: retornar a `aos_siguiente_lead_v2`.
- Email integration: conservar flows/backend existente durante transición.
- IA: `SHADOW`/feature flag OFF.
- Jobs: detener worker y permitir resolver on-read/fallback según fase.
- Cambios CRITICAL: backup/restore y rollback de migration probado antes de main.

---

# 40. CONTINUIDAD DEL PROYECTO

La continuidad debe existir en dos lugares:

## GitHub

Este documento + futuros anexos/ADRs/migrations/tests.

## Supabase `aos_memory`

Guardar un índice compacto y legible por claves estables que contenga:

- nombre del subproyecto;
- documento canónico;
- baseline;
- fase actual;
- roadmap;
- decisiones no negociables;
- frontend rules;
- siguiente acción;
- riesgos/guardrails.

Al cerrar cada fase actualizar `aos_memory` y este documento/status o un `CURRENT_STATUS` asociado.

Ningún chat nuevo debe depender únicamente de memoria conversacional: debe reconstruir estado leyendo GitHub + Supabase.

---

# 41. ESTADO DE EJECUCIÓN ACTUAL

| Fase | Estado |
|---|---|
| 0 Baseline & Contracts | **READY TO START** |
| 1 Identity Resolver | NOT STARTED |
| 2 Commercial Facts | NOT STARTED |
| 3 Segmentation | NOT STARTED |
| 4 Audience Resolver | NOT STARTED |
| 5 Panel Skeleton | NOT STARTED |
| 6 Audience Library | NOT STARTED |
| 7 Snapshots/Activation | NOT STARTED |
| 8 Channel Context | NOT STARTED |
| 9 Assignment | NOT STARTED |
| 10 Advisor Control Center | NOT STARTED |
| 11 Call Integration V3 | NOT STARTED |
| 12 Advisor Work Views | NOT STARTED |
| 13 Approvals | NOT STARTED |
| 14 Intelligence Shadow | NOT STARTED |
| 15 KronIA/Multiagent | NOT STARTED |
| 16 Email | NOT STARTED |
| 17 SMS/WhatsApp | NOT STARTED |
| 18 Attribution/Hardening | NOT STARTED |

---

# 42. PRIMERA ACCIÓN DESPUÉS DE APROBAR V3

Iniciar **FASE 0 — Baseline & Contracts** sin tocar producción funcional.

Orden exacto:

1. inventario actualizado de tablas/funciones/índices involucrados;
2. mapa UI/RPC/tablas consumidoras;
3. cerrar Fact Registry V1 en formato implementable;
4. definir estados y enums semánticos;
5. definir matriz permisos contra `aos_usuarios`/modelo real;
6. benchmark de consultas que sostendrán facts;
7. wireframe/esqueleto de panel acorde al design system;
8. definir feature flags;
9. diseñar migrations de Fases 1–3, sin aplicarlas todavía;
10. gate de aprobación de Fase 0.

---

# 43. DEFINICIÓN DE ÉXITO FINAL

El subproyecto se considera completo cuando:

- el administrador posee un panel central usable y consistente con ASCENDA;
- las audiencias se actualizan automáticamente conforme cambia la operación;
- una misma audiencia puede alimentar múltiples canales/contextos;
- producto/servicio/agenda/llamadas/ventas/seguimientos se interpretan con hechos consistentes;
- los asesores no pueden autoasignarse bases fuera de permiso;
- las asignaciones no quedan abandonadas indefinidamente;
- KronIA puede consultar, explicar y solicitar sin saltarse control administrativo;
- la IA demuestra valor medible antes de ganar autonomía;
- el sistema detecta agotamiento y oportunidades de forma anticipada;
- el administrador puede ver base → trabajo → cita → venta → facturación;
- existe auditoría, versionado, rollback y observabilidad;
- el módulo puede evolucionar a otros sistemas sin estar acoplado a una pantalla específica de Zi Vital.

---

**FIN — V3 CANÓNICA**
