# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 2:** `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`  
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
| 3 | Segmentation Engine | `READY` | 0% |
| 4 | Audience Resolver | `NOT_STARTED` | 0% |
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

P2-G01…P2-G14 = PASS al persistir checkpoint final.  
**Fase 2 = 100_COMPLETE.**

## Entregables

- `PHASE_02_COMMERCIAL_FACTS.md`
- `PHASE_02_VALIDATION_REPORT.md`
- `FACT_REGISTRY_V1_1_PHASE2.md`
- `20260813063500_cia_commercial_facts_v1.sql`
- `20260813063600_cia_commercial_facts_v1_1_email_fix.sql`
- auditor y tests SQL read-only.

## Contratos

- Lead Facts;
- Call Facts;
- Appointment Facts;
- Sales/Product/Service Facts;
- Follow-up Facts;
- Email Facts con BOOLEAN3;
- `aos_cia_commercial_facts_v1` 1:1 por contact_key.

## Evidencia live read-only

- Leads: 5,391 filas válidas / 5,076 contactos;
- Calls: 33,999 / 5,885;
- Appointments: 2,918 / 1,157;
- Sales: 1,268 / 296;
- Follow-ups: 523 / 456;
- todos los dominios: 0 claves fuera de Identity V1.

Oportunidad lead:

- 1,287 `unworked_since_latest_entry`;
- 3,789 `called_since_latest_entry`.

Email final:

- 1,942 unique sends;
- 1,623 mapped;
- 319 unresolved;
- 1,167 never-sent TRUE;
- 9,972 UNKNOWN.

Performance:

- Call-heavy ~260 ms;
- Email reconciliation ~78 ms;
- composición representativa completa ~474 ms;
- sin necesidad de materialización/cache/índices nuevos en Fase 2.

Integración:

- PR sync staging → feature: #54;
- PR feature → staging: #55;
- Ascenda CI run 293 = SUCCESS;
- merge funcional staging: `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`;
- producción verificada con 0 vistas/funciones `aos_cia_*`.

Nota de certificación: las migrations están versionadas en staging y sus semánticas fueron validadas read-only sobre datos vivos. No se afirma despliegue físico de DDL en Supabase productivo.

---

# SIGUIENTE FASE

## FASE 3 — SEGMENTATION ENGINE = READY

Objetivo:

Construir clasificación multidimensional, versionada y explicable sobre Identity V1 + Commercial Facts V1:

- Value Tier: STANDARD / PREMIUM / GOLD / DIAMANTE;
- Lifecycle;
- Engagement;
- Commercial Traits;
- futuras señales de riesgo cuando tengan definición determinista suficiente;
- policy versioning + `effective_from/effective_to`;
- provenance: “por qué este contacto tiene esta clasificación”.

Reglas de inicio:

- no usar `etiqueta_vip` legacy como fuente maestra;
- no depender únicamente de lifetime revenue;
- no hardcodear thresholds irreversibles dentro del frontend;
- primero shadow/derived; no sobrescribir clasificaciones históricas actuales;
- preservar una fila/clasificación reproducible por policy version.

---

# LOOP UNIVERSAL

Cada fase:

`baseline → alcance → impacto → branch → implementación aislada → checks → tests → comparación real → edge cases → roles → responsive → staging → E2E → rollback → rollout → observación → cierre docs → checkpoint memory`

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
