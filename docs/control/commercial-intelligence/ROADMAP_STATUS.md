# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging actual tras Fase 1:** `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`  
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

Una fase solo puede pasar a `100_COMPLETE` cuando todos sus gates tienen evidencia y el checkpoint fue persistido en GitHub + `aos_memory`.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `100_COMPLETE` | 100% |
| 2 | Commercial Facts | `READY` | 0% |
| 3 | Segmentation Engine | `NOT_STARTED` | 0% |
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

**Fase 0 cerrada 100% el 2026-08-13.**

Entregables principales:

- Product Spec + Impact Report V3;
- Fact Registry V1;
- Frontend Contract V1;
- baseline reproducible;
- roadmap/gates/continuidad.

---

# FASE 1 — CIERRE

## Identity Resolver V1

P1-G01…P1-G11 = PASS.

**Fase 1 cerrada 100% el 2026-08-13.**

Evidencia:

- feature: `feature/commercial-intelligence-phase1-identity-20260813`;
- PR sync staging → feature: #49;
- PR feature → staging: #50;
- CI: Ascenda CI run 274 = SUCCESS;
- staging merge: `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`;
- producción verificada sin objetos `aos_cia_*` después de integración staging.

Contrato validado live:

- 11,473 `contact_key` válidos únicos;
- 7,041 `RESOLVED`;
- 23 `CONFLICT`;
- 10 `FUSED_ONLY`;
- 4,399 `NO_PATIENT_PROFILE`;
- resolver simulado ~148 ms;
- todos los invariantes PASS.

Migration versionada:

`supabase/migrations/20260813061200_cia_identity_resolver_v1.sql`

Reglas no negociables heredadas:

- no reescribir `numero_limpio`;
- no fusionar automáticamente;
- `CONFLICT` no recibe identidad canónica;
- email no es merge key V1;
- `FUSIONADO` no reaparece como perfil canónico;
- fases siguientes reutilizan este contrato y no crean deduplicación paralela.

---

# SIGUIENTE FASE

## FASE 2 — COMMERCIAL FACTS = READY

Objetivo:

Construir una capa 1:1 por `contact_key` que normalice actividad comercial sin mega-joins ni lógica duplicada.

Dominios iniciales:

- Lead Facts;
- Call Facts;
- Agenda Facts;
- Sales Facts;
- Product Facts;
- Service Facts;
- Follow-up Facts;
- Email Facts;
- freshness/provenance/UNKNOWN semantics.

Debe iniciar con su propio Impact Report y gates antes de agregar objetos nuevos.

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
