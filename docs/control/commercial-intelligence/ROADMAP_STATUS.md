# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Estado:** CURRENT / DYNAMIC SOURCE OF PHASE STATUS  
**Última actualización:** 2026-08-14 (America/Lima)  
**Staging funcional F14:** `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Bootstrap actual:** `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`

---

## Regla de estado

Estados válidos:
`NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`

Una fase se declara `100_COMPLETE` cuando input handshake, funcionalidad, seguridad, performance, no-regresión, replayability, output contract, integración/staging smoke y cierre documental quedan sustentados.

Si CI queda bloqueado por infraestructura externa antes de checkout/tests, `CI_INFRA_EXCEPTION_DOCUMENTED` solo es válido cuando el bloqueo está probado, no se falsifica SUCCESS, el scope cambiado pasa validación equivalente y el post-merge smoke permanece PASS.

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
| 10 | Advisor Control Center | `100_COMPLETE` | 100% |
| 11 | Call Center Integration V3 | `100_COMPLETE` | 100% |
| 12 | Advisor Work Views | `100_COMPLETE` | 100% |
| 13 | Requests & Approval Engine | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | 100% |
| 14 | Commercial Intelligence Shadow | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | 100% |
| 15 | KronIA + Multiagent Orchestration | `READY` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CADENA CERTIFICADA F0–F14

`Identity → Commercial Facts → Segmentation → Audience Resolver → Panel → Audience Library → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Routing V3 → Advisor Work Views → Requests & Approval → Commercial Intelligence Shadow`

Separaciones no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- Recommendation ≠ authority;
- ownership = advisor UUID;
- F12 organiza work, nunca ownership;
- F13 gobierna requests/decisión/ejecución;
- F14 calcula y explica SHADOW intelligence, no actúa;
- IA no decide ownership;
- F11 conserva fallback V2 y kill switch global OFF salvo rollout explícito.

---

## F13 — Requests & Approval Engine

`100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.

Contrato:
`F12 own work-item → Request PENDING → ADMIN decision → atomic revalidation → explicit execution → F14 governed proposal context`.

Policy Gate:
- F14/KronIA `RELEASE_ASSIGNMENT` proposal → REQUIRE_APPROVAL;
- AUTO_ASSIGN/TRANSFER/AUTO_APPROVE/RAW_SQL → BLOCK;
- `auto_execute=false`.

Functional merge:
`594c2c77dae8513ff73a300e60f4caed1996efad`.

---

## F14 — Commercial Intelligence Shadow

`100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.

Contrato:
`Commercial Facts + Segmentation cache + Purchase Detail + F9 ownership + F13 Policy Gate → explainable SHADOW recommendations → F15 governed agent context`.

Entregas:
- `aos_cia_intelligence_shadow_runs`;
- `aos_cia_intelligence_recommendations`;
- `aos_cia_intelligence_events`;
- deterministic `aos_cia_intelligence_shadow_refresh_v1(...)`;
- Opportunity types UNWORKED_LEAD/FOLLOWUP_RECOVERY/REACTIVATION/REPURCHASE_SIGNAL/HIGH_VALUE_ATTENTION;
- evidence/confidence/sample-size/freshness/explainability;
- observed commercial affinity;
- ADMIN gateway;
- advisor-owned read contract;
- F13 Policy Gate integration;
- F15 readiness;
- ADMIN Intelligence F14 tab.

Performance architecture:
- naïve facts+segments live path rejected at ~44.4 s;
- snapshot/cache architecture adopted;
- latest-run top100 ~66.9 ms;
- F15 readiness ~54.1 ms;
- batch refresh ~4.21 s over 11,546 contacts.

Live run:
- 451 recommendations;
- 291 HIGH / 156 MEDIUM / 4 LOW confidence;
- 111 FRESH / 45 AGING / 295 STALE / 0 UNKNOWN;
- state violations=0;
- auto_execute violations=0;
- missing GENERATED event=0.

Security:
- F14 tables RLS=true, direct anon/auth access=false;
- internal refresh/readiness/link RPCs private;
- ADMIN surface validates CIA session;
- advisor surface revalidates active F9 ownership;
- RELEASE proposal REQUIRE_APPROVAL;
- AUTO_ASSIGN BLOCK.

Integration:
- PR #98 MERGED;
- functional staging merge `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`;
- Ascenda CI run #1067 did not execute steps due GitHub billing/spending block;
- manual changed-scope validation PASS;
- post-merge smoke PASS;
- live F15 readiness `READY_SHADOW_ACTIVE`, `ready_for_f15=true`.

Documento:
`docs/control/commercial-intelligence/PHASE_14_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## F15 — KRONIA + MULTIAGENT ORCHESTRATION = READY

Input F14 → F15:
- `aos_cia_intelligence_f15_readiness_v1()`;
- Recommendation SHADOW objects;
- deterministic evidence/confidence/sample-size/freshness;
- observed commercial affinity;
- advisor/assignment context cuando existe F9 ownership;
- F13 Request lifecycle + Policy Gate;
- recommendation/request audit linkage.

F15 debe construir:
- Tool Registry versionado;
- agent roles/scopes;
- structured tool I/O;
- provenance/evidence;
- agent run/audit trace;
- `OBSERVE → INTERPRET → PROPOSE → REQUEST → HUMAN DECISION → EXECUTE`;
- Policy Gate preflight obligatorio;
- shadow-first rollout;
- rate/timeout/error boundaries;
- output hacia F16 Email Integration.

F15 no debe:
- arbitrary SQL write;
- autoaprobar;
- autoejecutar;
- autoasignar;
- saltarse F13;
- usar Recommendation F14 como permiso de acción;
- usar datos clínicos sensibles como features comerciales ordinarias.

---

# LOOP UNIVERSAL V2

`recovery → baseline → input handshake → scope/Impact → branch → implementation → guards → QA rollback-only → security → performance → write-path safety → frontend → output handshake → PR/CI → staging smoke → Validation Report → aos_memory → Notion`

---

# CONTINUIDAD / RECOVERY

En un nuevo chat/agente:
1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md`
5. `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md`
6. este Roadmap
7. `PHASE_14_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase14_*`, `cia_phase15_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. `aos_cia_intelligence_f15_readiness_v1()`
11. verificar staging + Supabase live antes de cualquier cambio.
