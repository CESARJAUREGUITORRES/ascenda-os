# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 3 — SEGMENTATION ENGINE

**Estado:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Base:** staging `6246e07253ac030c52f1cbc637620b4e1decbea5`  
**Rama:** `feature/commercial-intelligence-phase3-segmentation-20260813`  
**Dependencias obligatorias:** Identity Resolver V1 + Commercial Facts V1 / Fact Registry V1.1.  
**Modo:** SHADOW; no modifica `etiqueta_vip`, `SCORE_ESTADO`, `ESTADO_PACIENTE` ni colas productivas.

---

# 1. OBJETIVO

Construir una clasificación comercial multidimensional, versionada y explicable por `contact_key` para que Audience Engine y futuras capas de inteligencia consuman segmentos estables sin reconstruir reglas sobre tablas operativas.

Dimensiones V1:

1. `value_tier`: STANDARD / PREMIUM / GOLD / DIAMANTE;
2. `lifecycle`: ciclo de vida comercial;
3. `engagement`: HIGH / MEDIUM / LOW;
4. `traits[]`: etiquetas no excluyentes derivadas de facts.

Toda clasificación debe incluir policy version, componentes de score y explicación legible/machine-readable.

---

# 2. GATES FASE 3

| Gate | Criterio | Estado inicial |
|---|---|---|
| P3-G01 | Impact Report + sesgos/invariantes | PASS |
| P3-G02 | Baseline legacy + distribución comercial | PASS |
| P3-G03 | Policy registry versionado | IN_PROGRESS |
| P3-G04 | Value Tier V1 calibrado y explicable | IN_PROGRESS |
| P3-G05 | Lifecycle V1 calibrado y explicable | IN_PROGRESS |
| P3-G06 | Engagement V1 calibrado y explicable | IN_PROGRESS |
| P3-G07 | Commercial Traits V1 | IN_PROGRESS |
| P3-G08 | Segment resolver 1:1 por contact_key | PENDING |
| P3-G09 | Shadow comparison vs legacy | PENDING |
| P3-G10 | Tests/invariantes live read-only | PENDING |
| P3-G11 | Performance baseline | PENDING |
| P3-G12 | Seguridad/privilegios privados | PENDING |
| P3-G13 | CI + integración staging | PENDING |
| P3-G14 | Continuidad GitHub + aos_memory | PENDING |

La fase solo pasa a `100_COMPLETE` con P3-G01…P3-G14 PASS.

---

# 3. HALLAZGOS DEL BASELINE

## Legacy VIP

Distribución física actual en `aos_pacientes`:

- NORMAL: 7,637;
- PREMIUM: 22;
- DIAMANTE: 1.

La lógica legacy encontrada en RPCs usa principalmente lifetime revenue:

- NORMAL < S/ 5,000;
- PREMIUM S/ 5,000–14,999;
- VIP S/ 15,000–19,999;
- DIAMANTE >= S/ 20,000.

Esto no será reutilizado como verdad de Fase 3 porque:

- depende casi exclusivamente de facturación acumulada;
- favorece antigüedad;
- no incorpora frecuencia ni recencia;
- la etiqueta física puede estar desactualizada;
- no contiene GOLD, requerido por el modelo nuevo.

## Distribución real de compradores válidos

296 contactos compradores con Identity V1 válida.

Revenue quantiles:

- P25 ≈ S/189;
- P50 ≈ S/509;
- P75 ≈ S/1,809;
- P90 ≈ S/5,172;
- P95 ≈ S/7,657;
- P98 ≈ S/10,578.

Frequency quantiles:

- P25 = 1;
- P50 = 2;
- P75 = 5;
- P90 ≈ 9;
- P95 ≈ 14.

Recencia de última compra:

- P25 ≈ 36 días;
- mediana ≈ 88 días;
- P75 ≈ 172 días.

Estos datos justifican los cortes V1 y quedan congelados en la policy versionada; futuros cambios requieren nueva policy version.

---

# 4. VALUE TIER POLICY V1

Value Tier usa tres componentes independientes para no confundir una compra grande aislada con lealtad sostenida.

## Revenue points

- < 500 → 0;
- >= 500 → 1;
- >= 1,800 → 2;
- >= 5,000 → 3;
- >= 8,000 → 4.

## Frequency points

- < 2 ventas → 0;
- >= 2 → 1;
- >= 5 → 2;
- >= 9 → 3.

## Recency points

- última compra <=30 días → 2;
- <=90 días → 1;
- >90 días / no compra → 0.

`value_score = revenue + frequency + recency`, rango 0–9.

Tiers:

- DIAMANTE: score >=8 + revenue >=5,000 + >=5 ventas;
- GOLD: score >=6;
- PREMIUM: score >=3;
- STANDARD: resto y no compradores.

Baseline compradores:

- DIAMANTE: 13;
- GOLD: 21;
- PREMIUM: 95;
- STANDARD: 167.

El tier mide valor comercial; recencia de valor usa compra, no asistencia.

---

# 5. LIFECYCLE POLICY V1

Lifecycle NO es Value Tier.

Para clientes, `customer_last_activity_at = max(last_sale_at, last_attended_at)` para no clasificar como inactivo a un paciente que compró un plan previamente pero sigue asistiendo.

Clientes:

- NEW_CUSTOMER: primera compra <=30 días;
- ACTIVE_CUSTOMER: actividad cliente <=90 días;
- COOLING_CUSTOMER: 91–180 días;
- INACTIVE_CUSTOMER: >180 días.

Prospectos sin venta, en orden:

- APPOINTMENT_READY_PROSPECT: cita futura activa;
- DISQUALIFIED_PROSPECT: latest call en NO LE INTERESA/SACAR DE LA BASE y esa llamada no fue superada por un lead posterior;
- ACTIVE_PROSPECT: lead <=30d, llamada positiva <=30d o seguimiento pendiente;
- WARM_PROSPECT: lead <=90d o gestión reciente no terminal <=90d;
- COLD_PROSPECT: existe historia de lead/call/cita/seguimiento pero no cumple condiciones anteriores;
- PROFILE_ONLY: identidad sin actividad comercial suficiente.

`REACTIVATED` NO se inventa en V1. Requiere evidencia de un periodo previo de inactividad seguida de nueva conversión; Commercial Facts V1 aún no conserva second-last sale/max-gap. Se añadirá únicamente mediante extensión formal del Fact Registry.

---

# 6. ENGAGEMENT POLICY V1

Engagement mide intensidad de interacción reciente y es independiente de revenue/tier.

Puntos:

- cita futura: +4;
- asistencia efectiva <=90d: +3;
- latest call positiva (`CITA CONFIRMADA|SEGUIMIENTO`) <=30d: +2;
- lead <=30d: +1;
- seguimiento pendiente: +2;
- evidencia de open/click email: +1.

Clasificación:

- HIGH >=5;
- MEDIUM >=2;
- LOW 0–1.

No se premia `NO LE INTERESA`, `SACAR DE LA BASE`, `SIN CONTACTO` ni `NO CONTESTA` como engagement positivo.

Baseline read-only inicial:

- HIGH: 91;
- MEDIUM: 454;
- LOW: 10,928.

---

# 7. COMMERCIAL TRAITS V1

Traits son multivalor, no categorías excluyentes:

- HAS_LEAD;
- UNWORKED_LEAD;
- NEVER_CALLED;
- PRODUCT_BUYER;
- SERVICE_BUYER;
- PRODUCT_AND_SERVICE_BUYER;
- REPEAT_BUYER;
- FREQUENT_BUYER;
- HIGH_VALUE_BUYER;
- RECENT_BUYER;
- LAPSED_BUYER;
- FUTURE_APPOINTMENT;
- NO_SHOW_HISTORY;
- REPEAT_NO_SHOW;
- FOLLOWUP_PENDING;
- FOLLOWUP_OVERDUE.

Baseline destacado:

- NO_SHOW_HISTORY 854;
- FOLLOWUP_OVERDUE 442;
- REPEAT_NO_SHOW 351;
- SERVICE_BUYER 251;
- REPEAT_BUYER 178;
- PRODUCT_BUYER 146;
- PRODUCT_AND_SERVICE_BUYER 101;
- FREQUENT_BUYER 75;
- RECENT_BUYER 64;
- LAPSED_BUYER 60;
- FUTURE_APPOINTMENT 54;
- HIGH_VALUE_BUYER 31;
- FOLLOWUP_PENDING 15.

---

# 8. DATA MODEL / CONTRATOS

## `aos_segmentation_policies`

Registro persistente de políticas versionadas:

- UUID;
- policy_key;
- version;
- status SHADOW/ACTIVE/RETIRED;
- effective_from/effective_to;
- rules JSONB;
- audit timestamps.

Este nombre generaliza y sustituye el nombre preliminar `aos_customer_tier_policies`, porque una misma policy gobierna Value Tier, Lifecycle, Engagement y Traits.

## `aos_cia_current_segmentation_policy_v1`

Resolver de policy vigente. Prefiere ACTIVE; si no existe, usa SHADOW.

## `aos_cia_customer_segments_v1`

Grano: exactamente una fila por `aos_cia_commercial_facts_v1.contact_key`.

Campos contractuales:

- policy id/key/version/status;
- contact_key;
- identity_status/conflict;
- value_tier + score + component points;
- lifecycle + customer_last_activity_at;
- engagement + score;
- traits[];
- calculated_at;
- explanation JSONB;
- facts_provenance.

No materializa ni sobrescribe etiquetas legacy.

---

# 9. IMPACT REPORT

**Riesgo:** MEDIUM en migration propuesta; sin impacto productivo mientras no se despliegue DDL.

Lee:

- `aos_cia_commercial_facts_v1`;
- indirectamente Identity V1 y fuentes comerciales de Fases 1–2.

Añade:

- una tabla de policy pequeña;
- dos vistas read-only;
- una policy SHADOW seed.

No modifica:

- `aos_pacientes.etiqueta_vip`;
- `SCORE_ESTADO`;
- `ESTADO_PACIENTE`;
- llamadas/citas/ventas/seguimientos;
- Call Center;
- Email runtime;
- colas/asignaciones;
- RLS de tablas existentes.

Rollback: drop de vistas/tabla de policy V1. No requiere restauración de datos fuente.

---

# 10. SESGOS PREVENIDOS

1. Lifetime revenue ≠ valor completo.
2. Venta reciente ≠ paciente activo si ignoramos asistencia; lifecycle usa ambas.
3. Contacto efectivo ≠ interés comercial positivo.
4. Último NO LE INTERESA no bloquea eternamente si existe un lead posterior.
5. Tier ≠ lifecycle ≠ engagement.
6. Traits no son mutuamente excluyentes.
7. Legacy VIP se compara, no se copia.
8. REACTIVATED no se infiere sin historial suficiente.
9. Identity conflict no se oculta; viaja al resultado.
10. Policy changes requieren versión nueva, no edición silenciosa del significado histórico.

---

# 11. CRITERIO DE SALIDA

Fase 3 cierra solo cuando:

- policy V1 y resolver sean reproducibles;
- 1:1/uniqueness pase;
- todas las clases estén en enums autorizados;
- Value Tier reconcilie con componentes;
- Lifecycle preserve orden/prioridad;
- traits sean deterministas;
- explicación/provenance exista en 100% de filas;
- shadow comparison esté documentada;
- benchmark esté dentro del presupuesto;
- nuevos objetos permanezcan privados;
- CI sea SUCCESS;
- feature se integre únicamente a staging;
- producción permanezca intacta;
- checkpoint GitHub + `aos_memory` marque Fase 3 100% y Fase 4 READY.
