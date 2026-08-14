# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13 (America/Lima)  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 9:** `57445a0863350c1989d8398157308783bdaf3905`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

## Regla de estado

Estados:
`NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`

Una fase solo es `100_COMPLETE` cuando:
- todos sus gates están sustentados;
- implementación está integrada en `staging`;
- CI pasa;
- smoke post-merge pasa;
- Validation Report final existe;
- GitHub y `aos_memory` guardan el checkpoint.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `100_COMPLETE` | 100% |
| 2 | Commercial Facts | `100_COMPLETE` | 100% |
| 3 | Segmentation Engine | `100_COMPLETE` | 100% |
| 4 | Audience Resolver | `100_COMPLETE` | 100% |
| 5 | Panel Central Skeleton | `100_COMPLETE` | 100% |
| 6 | Audience Library Persistence | `100_COMPLETE` | 100% |
| 7 | Snapshots & Activation | `100_COMPLETE` | 100% |
| 8 | Channel Context & Availability | `100_COMPLETE` | 100% |
| 9 | Assignment Engine | `100_COMPLETE` | 100% |
| 10 | Advisor Control Center | `READY` | 0% |
| 11 | Call Center Integration V3 | `NOT_STARTED` | 0% |
| 12 | Advisor Work Views | `NOT_STARTED` | 0% |
| 13 | Requests & Approvals | `NOT_STARTED` | 0% |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | 0% |
| 15 | KronIA + Multiagent | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CIERRES CERTIFICADOS

## Fase 0 — Baseline & Contracts
P0 gates PASS. Product Spec/Impact, baseline, Fact Registry, frontend contract y protocolo de continuidad establecidos.

## Fase 1 — Identity Resolver
`100_COMPLETE`. Resolver transversal de identidad/contact key; conflictos explícitos; no rewrite destructivo de `numero_limpio`.

## Fase 2 — Commercial Facts
`100_COMPLETE`. Facts 1:1 por contacto para Leads, Calls, Agenda, Sales, Followups y Email con freshness/provenance.

## Fase 3 — Segmentation Engine
`100_COMPLETE`. Value Tier / Lifecycle / Engagement / Traits separados de legacy `etiqueta_vip`.

## Fase 4 — Audience Resolver
`100_COMPLETE`. DSL whitelisted, AND/OR, Validate/Count/Preview/Explain, MATCH/MISS/UNKNOWN y presets.

## Fase 5 — Panel Central Skeleton
`100_COMPLETE`. Panel ADMIN Bases & Audiencias, CIA admin session/gateway y frontend productivo.

## Fase 6 — Audience Library Persistence
`100_COMPLETE`. Biblioteca universal, versiones inmutables, optimistic concurrency, archive/restore/duplicate y audit.

## Fase 7 — Snapshots & Activation
`100_COMPLETE`. Snapshots SHA-256, BATCH `FROZEN_SNAPSHOT`, DYNAMIC `DYNAMIC_LIVE`, Activation lifecycle y event audit DB.

## Fase 8 — Channel Context & Availability
`100_COMPLETE`. Contrato determinístico:

`Audience Total → Eligible → Available Now`

UNKNOWN nunca es assignable.

Input canónico para Fase 9:
`aos_cia_activation_available_keys_v1(activation_id)`

Functional PR #72 / CI #553 SUCCESS. Closure PR #73 / CI #558 SUCCESS.

## Fase 9 — Assignment Engine
`100_COMPLETE`.

### Contrato

`available_keys F8 → Assignment Plan → Assignment Lease → F10 read-models`

### Entrega
- plans / targets / runs / leases / events;
- ownership por `aos_usuarios.id` UUID;
- ONE / EQUAL / PERCENTAGE / FIXED;
- ownership scopes GLOBAL / ACTIVATION;
- lifecycle `RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`;
- lease/must-start deadlines;
- reconcile de expiración;
- capacity hard cap;
- top-up NONE / MAINTAIN_TARGET / CONTINUOUS;
- CONTINUOUS balance-aware acumulado;
- advisory transaction lock;
- idempotency;
- one initial run;
- global active-ownership conflict guard;
- plan/target/lease state guards;
- append-only audit;
- CIA Phase 9 gateway;
- panel `Distribución` dentro de Activaciones;
- read-models preparados para Fase 10.

### QA certificado

DYNAMIC:
- F8 available 103 = F9 candidates 103.

BATCH:
- snapshot 116;
- F8 available 103;
- F9 candidates 103;
- equality exacta PASS.

Strategies:
- EQUAL 10/3 → 4/3/3;
- PERCENTAGE 50/30/20 → 5/3/2;
- FIXED 2/3/4 → 9 total;
- ONE → lote completo a un target.

MAINTAIN_TARGET:
- 3/3/3 → release 1 → top-up 1 → 3/3/3;
- idempotent replay PASS.

CONTINUOUS:
- QA detectó sesgo original;
- se corrigió antes de certificar;
- re-QA 52/50 → top-up al target deficitario → 52/51;
- balanced=true.

GLOBAL ownership:
- conflicto simultáneo bloqueado;
- release devuelve candidato al pool según policy.

Lifecycle:
- RESERVE/ASSIGN/START/COMPLETE = 1 cada uno;
- stale ASSIGNED → EXPIRED;
- terminal plan CLOSED no reabre.

Performance:
- source F8 1,169 sobre audiencia 1,277;
- candidates ~617 ms;
- allocation 1,000 leases ~1.77 s;
- summary ~903 ms;
- advisor workload ~4 ms.

Security:
- 5 objetos RLS / 0 policies;
- anon/authenticated direct visibility = 0;
- anon direct INSERT rechazado;
- internal candidates/allocation no ejecutables desde browser;
- gateway token inválido → UNAUTHORIZED.

Compatibility:
- `aos_siguiente_lead` hash intacto `76412bac81e20ec6cfdc4f8c0db89e8c`;
- `aos_siguiente_lead_v2` hash intacto `cb69781d1457ed73de8f8d52f0f83a00`;
- 349 llamadas en smoke;
- Email legacy/FK intactos;
- 0 Phase 9 data residual.

Integración:
- Functional PR #75 MERGED;
- Ascenda CI #576 SUCCESS;
- merge funcional staging `57445a0863350c1989d8398157308783bdaf3905`;
- post-merge smoke PASS.

Documento de evidencia:
`docs/control/commercial-intelligence/PHASE_09_VALIDATION_REPORT.md`

---

# SIGUIENTE FASE

## FASE 10 — ADVISOR CONTROL CENTER = READY

Objetivo:
crear el centro administrativo de control por asesor sobre ownership ya producido por Fase 9.

### Entradas canónicas

Fase 10 debe consumir principalmente:

`aos_cia_assignment_advisor_workload_v1()`

`aos_cia_assignment_plan_summary_v1(plan_id)`

Complementarios:
- `aos_cia_assignment_list_v1(...)`;
- `aos_cia_assignment_events_v1(...)`.

### Fase 10 debe mostrar
- carga activa por asesor;
- ASSIGNED / IN_PROGRESS / COMPLETED / RELEASED / EXPIRED;
- active plans;
- overdue-to-start;
- expiring leases;
- candidate remaining;
- source available now;
- depletion por plan;
- capacidad/utilización;
- drill-down de ownership y deadlines.

### Reglas de entrada
- no reconstruir ownership desde `aos_llamadas`, leads u otras tablas source;
- no crear un segundo Assignment Engine;
- no modificar `aos_siguiente_lead` todavía;
- no entregar todavía work views al asesor (Fase 12);
- no hacer routing Call Center V3 (Fase 11);
- advisor identity = `aos_usuarios.id`;
- Impact Report antes de DDL si Fase 10 requiere nuevos objetos persistentes.

### Conexión futura

Fase 10 debe dejar un read/control plane limpio para:

**Fase 11 — Call Center Integration V3**

sin acoplar todavía Assignment al runtime V2.

---

# LOOP UNIVERSAL

`baseline → scope → Impact Report → branch → isolated implementation → DB guards → contracts → tests → real-data comparison → edge cases → security/roles → performance → responsive → PR/CI → staging → smoke/E2E → rollback → closure docs → aos_memory checkpoint`

No se habilita la siguiente fase hasta tener la fase actual en `100_COMPLETE`.

---

# CONTINUIDAD / RECOVERY

En un nuevo chat, recuperar en este orden:

1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`
4. `docs/control/commercial-intelligence/ROADMAP_STATUS.md`
5. `docs/control/commercial-intelligence/PHASE_09_VALIDATION_REPORT.md`
6. `aos_memory` keys `cia_v3_*`, `cia_phase9_*`, `cia_phase10_status`
7. verificar live `staging` + Supabase antes de cualquier cambio.

Checkpoint funcional de entrada a Fase 10:
`57445a0863350c1989d8398157308783bdaf3905`
