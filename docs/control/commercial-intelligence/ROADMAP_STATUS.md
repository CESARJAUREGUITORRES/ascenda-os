# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 3:** `cd00090ad7a949f15d6b90422ec2bedf775a26dd`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

# REGLA DE ESTADO

Estados permitidos:

- `NOT_STARTED`
- `READY`
- `IN_PROGRESS`
- `BLOCKED`
- `VALIDATING`
- `100_COMPLETE`

Una fase solo pasa a `100_COMPLETE` cuando todos sus gates tienen evidencia y el checkpoint final existe en GitHub + `aos_memory`.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `100_COMPLETE` | 100% |
| 2 | Commercial Facts | `100_COMPLETE` | 100% |
| 3 | Segmentation Engine | `100_COMPLETE` | 100% |
| 4 | Audience Resolver | `READY` | 0% |
| 5 | Panel Central Skeleton | `NOT_STARTED` | 0% |
| 6 | Audience Library Persistence | `NOT_STARTED` | 0% |
| 7 | Snapshots & Activation | `NOT_STARTED` | 0% |
| 8 | Channel Context & Availability | `NOT_STARTED` | 0% |
| 9 | Assignment Engine | `NOT_STARTED` | 0% |
| 10 | Advisor Control Center | `NOT_STARTED` | 0% |
| 11 | Call Center Integration V3 | `NOT_STARTED` | 0% |
| 12 | Advisor Work Views | `NOT_STARTED` | 0% |
| 13 | Requests & Approvals | `NOT_STARTED` | 0% |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | 0% |
| 15 | KronIA + Multiagent | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# FASE 0 — CIERRE

P0-G01…P0-G09 = PASS.  
**Fase 0 = 100_COMPLETE.**

Entregables: Product Spec/Impact Report V3, Fact Registry V1, Frontend Contract, baseline, roadmap y continuidad.

---

# FASE 1 — CIERRE

P1-G01…P1-G11 = PASS.  
**Fase 1 = 100_COMPLETE.**

Identity V1 validado:

- 11,473 contact keys;
- 7,041 RESOLVED;
- 23 CONFLICT;
- 10 FUSED_ONLY;
- 4,399 NO_PATIENT_PROFILE.

PR feature → staging: #50.  
CI run 274: SUCCESS.  
Merge funcional: `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`.

---

# FASE 2 — CIERRE

P2-G01…P2-G14 = PASS.  
**Fase 2 = 100_COMPLETE.**

Entregables principales:

- Commercial Facts por dominio;
- `aos_cia_commercial_facts_v1` 1:1 por contact_key;
- Fact Registry V1.1;
- auditor/tests;
- Email resolver con BOOLEAN3.

Evidencia live read-only:

- Leads: 5,391 filas válidas / 5,076 contactos;
- Calls: 33,999 / 5,885;
- Appointments: 2,918 / 1,157;
- Sales: 1,268 / 296;
- Follow-ups: 523 / 456;
- todos los dominios: 0 claves fuera de Identity V1;
- lead unworked since latest entry: 1,287;
- email: 1,942 sends / 1,623 mapped / 319 unresolved;
- composición representativa ~474 ms.

PR feature → staging: #55.  
CI run 293 = SUCCESS.  
Merge funcional: `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`.

---

# FASE 3 — CIERRE

P3-G01…P3-G14 = PASS al persistir checkpoint final.  
**Fase 3 = 100_COMPLETE.**

## Entregables

- `PHASE_03_SEGMENTATION_ENGINE.md`
- `PHASE_03_VALIDATION_REPORT.md`
- `FACT_REGISTRY_V1_2_PHASE3.md`
- `20260813070000_cia_segmentation_engine_v1.sql`
- auditor y tests SQL.

## Contratos

- `aos_segmentation_policies` — registry versionado;
- `aos_cia_current_segmentation_policy_v1`;
- `aos_cia_customer_segments_v1`;
- policy `COMMERCIAL_SEGMENTATION` v1 SHADOW;
- Value Tier + Lifecycle + Engagement + Commercial Traits;
- explicación/provenance por contacto.

## Value Tier live read-only

Universo: 11,473.

- STANDARD: 11,344;
- PREMIUM: 95;
- GOLD: 21;
- DIAMANTE: 13.

296 compradores válidos fueron usados para calibración empírica de revenue/frequency/recency.

## Lifecycle live read-only

- PROFILE_ONLY: 5,480;
- WARM_PROSPECT: 1,849;
- COLD_PROSPECT: 1,534;
- DISQUALIFIED_PROSPECT: 1,313;
- ACTIVE_PROSPECT: 965;
- ACTIVE_CUSTOMER: 110;
- COOLING_CUSTOMER: 89;
- INACTIVE_CUSTOMER: 56;
- NEW_CUSTOMER: 41;
- APPOINTMENT_READY_PROSPECT: 36.

La regla temporal evitó veto eterno: **794 contactos** con tipificación terminal histórica tienen un lead posterior y fueron rescatados del estado terminal.

`REACTIVATED` no se inventa en V1; requiere nueva evidencia histórica en Commercial Facts.

## Engagement live read-only

- LOW: 11,220;
- MEDIUM: 176;
- HIGH: 77.

Revenue no participa en Engagement.

## Traits destacados

- NO_SHOW_HISTORY: 854;
- FOLLOWUP_OVERDUE: 442;
- REPEAT_NO_SHOW: 351;
- SERVICE_BUYER: 251;
- REPEAT_BUYER: 178;
- PRODUCT_BUYER: 146;
- PRODUCT_AND_SERVICE_BUYER: 101;
- FREQUENT_BUYER: 75;
- HIGH_VALUE_BUYER: 31.

## Shadow vs legacy

La etiqueta legacy se conserva intacta. La policy nueva no depende solo de lifetime revenue y detectó múltiples perfiles NORMAL legacy con valor shadow PREMIUM/GOLD/DIAMANTE.

## Performance

Composición representativa + score: **~404.553 ms**.  
PASS contra presupuesto P95 <1.5 s.  
Sin materialización/cache/índices nuevos.

## Integración

- PR feature → staging: #57;
- Ascenda CI run 308 = SUCCESS;
- merge funcional staging: `cd00090ad7a949f15d6b90422ec2bedf775a26dd`;
- producción verificada con 0 objetos Phase 3.

Nota de certificación: reglas y semánticas fueron validadas con equivalentes read-only sobre datos vivos. La migration está versionada/integrada a staging; no se afirma despliegue físico de DDL en Supabase productivo.

---

# SIGUIENTE FASE

## FASE 4 — AUDIENCE RESOLVER = READY

Objetivo:

Convertir Identity V1 + Commercial Facts V1 + Segmentation V1 en un motor universal de resolución de audiencias mediante **Filter Registry whitelisted + DSL declarativo**, sin SQL libre.

Debe entregar como mínimo:

- DSL versionada;
- AND / OR con profundidad controlada;
- whitelisted fields/operators de Fact Registry V1.2;
- resolver determinista;
- count;
- preview paginado;
- explain inclusion/exclusion;
- presets oficiales;
- filtro por Product/Service;
- filtros latest/ever/window diferenciados;
- filtros `segment.value_tier`, `segment.lifecycle`, `segment.engagement`, `segment.traits`;
- `UNKNOWN` tratado explícitamente;
- seguridad backend/service_role;
- tests de equivalencia e invariantes;
- benchmark contra datos vivos;
- sin persistir todavía biblioteca de audiencias (eso corresponde a Fase 6).

Reglas de inicio:

- no SQL libre desde frontend/IA;
- no duplicar reglas de Facts/Segmentation dentro del resolver;
- una audiencia selecciona contactos, no asigna asesores;
- total audiencia ≠ eligible ≠ available now;
- Fase 4 resuelve pertenencia; elegibilidad contextual llega después.

---

# LOOP UNIVERSAL

Cada fase:

`baseline → alcance → impacto → branch → implementación aislada → checks → tests → comparación real → edge cases → roles → staging → E2E → rollback → rollout → observación → cierre docs → checkpoint memory`

---

# PRINCIPIO DE CONTINUIDAD

Cualquier nueva conversación debe recuperar en este orden:

1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`;
4. `docs/control/commercial-intelligence/ROADMAP_STATUS.md`;
5. documento de la fase actual;
6. claves `cia_v3_*` / `cia_phase_*` en `aos_memory`;
7. staging/GitHub y Supabase vivos antes de ejecutar cambios.
