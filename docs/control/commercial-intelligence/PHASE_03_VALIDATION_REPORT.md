# ASCENDA OS — CIA PHASE 3 VALIDATION REPORT
## Segmentation Engine V1

**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase3-segmentation-20260813`  
**PR feature → staging:** #57  
**CI:** Ascenda CI run 308 = SUCCESS  
**Merge funcional staging:** `cd00090ad7a949f15d6b90422ec2bedf775a26dd`

---

# 1. RESULTADO

Fase 3 implementa en Git/staging el contrato V1 de segmentación comercial sobre Identity V1 + Commercial Facts V1.

Objetos versionados:

- `aos_segmentation_policies`;
- `aos_cia_current_segmentation_policy_v1`;
- `aos_cia_customer_segments_v1`.

Migration:

- `supabase/migrations/20260813070000_cia_segmentation_engine_v1.sql`.

Modo inicial: `SHADOW`.

No se modifica `etiqueta_vip`, `SCORE_ESTADO`, `ESTADO_PACIENTE` ni ningún dato fuente.

---

# 2. POLICY REGISTRY V1

Policy family: `COMMERCIAL_SEGMENTATION`.

Policy version: 1.

Status inicial: `SHADOW`.

La policy contiene en JSONB:

- thresholds de Value Tier;
- ventanas de Lifecycle;
- estados terminales/positivos de llamadas;
- pesos de Engagement;
- thresholds de Commercial Traits.

Cambiar el significado comercial requiere nueva versión. No se silencian cambios de thresholds.

El resolver vigente prefiere una policy `ACTIVE`; si no existe, usa `SHADOW`.

---

# 3. VALUE TIER — VALIDACIÓN

Baseline real de compradores válidos: 296 contactos.

Cuantiles usados para calibración:

- revenue P25 ≈ S/189;
- P50 ≈ S/509;
- P75 ≈ S/1,809;
- P90 ≈ S/5,172;
- P95 ≈ S/7,657;
- frequency mediana 2;
- P75 = 5;
- P90 ≈ 9;
- recency mediana ≈88 días.

Policy V1 usa score revenue + frequency + recency, rango 0–9.

Resultado sobre compradores:

- DIAMANTE: 13;
- GOLD: 21;
- PREMIUM: 95;
- STANDARD: 167.

Resultado sobre universo completo de 11,473 contactos:

- STANDARD: 11,344;
- PREMIUM: 95;
- GOLD: 21;
- DIAMANTE: 13.

Los 31 contactos con lifetime revenue >= S/5,000 se distribuyen en:

- DIAMANTE 13;
- GOLD 10;
- PREMIUM 8.

Esto confirma que una compra grande aislada no fuerza automáticamente Gold/Diamante: frecuencia y recencia siguen influyendo.

---

# 4. SHADOW VS LEGACY VIP

Legacy observado físicamente:

- NORMAL: 7,637;
- PREMIUM: 22;
- DIAMANTE: 1.

RPC legacy encontrada:

- NORMAL <5k;
- PREMIUM 5k–15k;
- VIP 15k–20k;
- DIAMANTE >=20k;

Comparación entre compradores con paciente canónico RESOLVED:

| Legacy | Shadow | N |
|---|---|---:|
| DIAMANTE | DIAMANTE | 1 |
| NORMAL | DIAMANTE | 7 |
| NORMAL | GOLD | 11 |
| NORMAL | PREMIUM | 77 |
| NORMAL | STANDARD | 142 |
| PREMIUM | DIAMANTE | 1 |
| PREMIUM | GOLD | 6 |
| PREMIUM | PREMIUM | 7 |

El shadow detecta perfiles de valor que la etiqueta física legacy no refleja actualmente. No se sobrescribe el legacy; se conserva para comparación/auditoría.

---

# 5. LIFECYCLE — VALIDACIÓN

Para compradores, `customer_last_activity_at = max(last_sale_at,last_attended_at)`.

Este ajuste evita marcar como inactivo a un paciente con compra antigua pero sesiones/asistencias recientes.

Resultado final:

- NEW_CUSTOMER: 41;
- ACTIVE_CUSTOMER: 110;
- COOLING_CUSTOMER: 89;
- INACTIVE_CUSTOMER: 56;
- APPOINTMENT_READY_PROSPECT: 36;
- ACTIVE_PROSPECT: 965;
- WARM_PROSPECT: 1,849;
- COLD_PROSPECT: 1,534;
- DISQUALIFIED_PROSPECT: 1,313;
- PROFILE_ONLY: 5,480.

Total: 11,473.

## Terminal status is not permanent

Latest terminal calls (`NO LE INTERESA` / `SACAR DE LA BASE`) evaluadas:

- 1,353 contactos conservan terminal latest después/no antes que el último lead;
- 794 contactos tienen un lead más nuevo que la llamada terminal y son rescatados del estado terminal.

Por tanto una negativa histórica no se convierte en veto eterno.

`REACTIVATED` no se emite en V1 porque falta fact histórico suficiente para demostrar un periodo de inactividad previo y una posterior reactivación. No se inventa esa semántica.

---

# 6. ENGAGEMENT — VALIDACIÓN

Engagement no usa revenue.

Solo suma señales positivas/recentes definidas por policy:

- cita futura;
- asistencia reciente;
- llamada positiva reciente;
- lead reciente;
- seguimiento pendiente;
- evidencia email open/click cuando exista.

Resultado final live read-only:

- HIGH: 77;
- MEDIUM: 176;
- LOW: 11,220.

Total: 11,473.

No se consideran `SIN CONTACTO`, `NO CONTESTA`, `NO LE INTERESA` ni `SACAR DE LA BASE` como engagement positivo.

---

# 7. COMMERCIAL TRAITS — VALIDACIÓN

Traits destacados:

- NO_SHOW_HISTORY: 854;
- FOLLOWUP_OVERDUE: 442;
- REPEAT_NO_SHOW: 351;
- SERVICE_BUYER: 251;
- REPEAT_BUYER: 178;
- PRODUCT_BUYER: 146;
- PRODUCT_AND_SERVICE_BUYER: 101;
- FREQUENT_BUYER: 75;
- RECENT_BUYER: 64;
- LAPSED_BUYER: 60;
- FUTURE_APPOINTMENT: 54;
- HIGH_VALUE_BUYER: 31;
- FOLLOWUP_PENDING: 15.

Los traits son multivalor y no compiten entre sí.

---

# 8. INVARIANTES

Validación semántica read-only:

- universo evaluado: 11,473;
- Value Tier suma 11,473;
- Lifecycle suma 11,473;
- Engagement suma 11,473;
- buyers no caen en lifecycle de prospecto;
- no-buyers no caen en lifecycle de cliente;
- score de valor = revenue points + frequency points + recency points;
- DIAMANTE requiere score/revenue/frequency guardrails;
- terminal status solo descalifica si no fue superado por lead posterior;
- `REACTIVATED` V1 = 0 por contrato;
- policy thresholds se leen desde registry versionado;
- Identity conflict permanece visible.

Tests versionados:

`scripts/test_cia_segmentation_phase3.sql`.

Auditor:

`scripts/audit_cia_segmentation_phase3_readonly.sql`.

---

# 9. PERFORMANCE

Benchmark read-only representativo de Identity/event aggregation + segment scoring:

**Execution Time ≈ 404.553 ms**.

Presupuesto del producto: preview/count normal P95 <1.5 s.

Resultado: PASS.

No se justifica materialización, cache ni índices nuevos en Fase 3.

---

# 10. SEGURIDAD / BLAST RADIUS

Migration propuesta:

- tabla de policy nueva con RLS habilitado;
- sin policies públicas;
- `PUBLIC`, `anon`, `authenticated` revocados;
- acceso inicial `service_role`;
- vistas `security_invoker=true`;
- sin `SECURITY DEFINER`;
- sin modificación de RLS fuente;
- sin cambios en Call Center, Email o runtime frontend/backend.

Después del merge a staging se verificó Supabase productivo:

- `aos_segmentation_policies`: 0;
- vistas Phase 3 CIA: 0.

Producción permanece intacta.

---

# 11. ALCANCE DE CERTIFICACIÓN

Igual que en Fase 2, las migrations SQL no fueron aplicadas físicamente a Supabase productivo ni a una development branch de costo separado.

La certificación significa:

1. reglas calibradas con datos vivos;
2. semántica ejecutada read-only contra el universo productivo;
3. invariantes y distribuciones reconciliadas;
4. migration aditiva revisada/versionada;
5. CI del repositorio SUCCESS;
6. integración a staging;
7. producción sin cambios.

La ejecución física del DDL pertenece al gate de despliegue futuro.

---

# 12. DECISIÓN

Segmentation Engine V1 queda aprobado como dependencia de Fase 4 — Audience Resolver.

Fase 4 debe consumir exclusivamente Fact Registry V1.2 / Segmentation V1 para campos de tier/lifecycle/engagement/traits y no recrear estas reglas dentro del Audience DSL.
