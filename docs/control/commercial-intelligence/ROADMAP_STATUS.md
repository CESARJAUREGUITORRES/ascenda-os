# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Estado:** CURRENT / DYNAMIC SOURCE OF PHASE STATUS  
**Última actualización:** 2026-08-14 (America/Lima)  
**Staging funcional F13:** `594c2c77dae8513ff73a300e60f4caed1996efad`  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Bootstrap actual:** `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`

---

## Regla de estado

Estados válidos:
`NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`

Una fase se declara `100_COMPLETE` cuando input handshake, funcionalidad, seguridad, performance, no-regresión, replayability, output contract, integración/staging smoke y cierre documental quedan sustentados.

Si una dependencia externa impide ejecutar CI sin llegar a checkout/tests, puede existir una `CI_INFRA_EXCEPTION_DOCUMENTED` únicamente cuando:
- el bloqueo externo está probado por la plataforma;
- no se representa falsamente como SUCCESS;
- el scope cambiado pasa validación equivalente aislada;
- smoke post-merge y gates funcionales permanecen PASS;
- la deuda de infraestructura queda registrada.

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
| 14 | Commercial Intelligence Shadow | `READY` | 0% |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CADENA CERTIFICADA F0–F13

`Identity → Commercial Facts → Segmentation → Audience Resolver → Panel → Audience Library → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Routing V3 → Advisor Work Views → Requests & Approval`

Separaciones no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- ownership = advisor UUID;
- F12 solo organiza work, nunca ownership;
- F13 gobierna requests, decisión humana y ejecución explícita;
- IA no decide ownership;
- F11 conserva fallback V2 y kill switch global OFF salvo rollout explícito.

---

## F9 — Assignment Engine

`100_COMPLETE`.

Autoridad de ownership y lifecycle de lease:
`RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`.

---

## F11 — Call Center Integration V3

`100_COMPLETE`.

Routing V3 paralelo/canary, global OFF por defecto, fallback V2 obligatorio, claim/consume gobernados por F9 ownership.

Output:
`aos_cia_call_routing_f12_readiness_v1()`.

---

## F12 — Advisor Work Views

`100_COMPLETE`.

Contrato:
`F9 ownership + F11 routing evidence → F12 personal work universe → F13 requestable context`.

Garantías:
- Work View deriva solo de F9 ownership;
- pin/snooze/priority no cambian owner;
- `requestable=true` solo en own ASSIGNED/IN_PROGRESS no expirado;
- output `aos_cia_advisor_work_f13_readiness_v1()`.

Functional merge:
`dedbc80de9967a70c4cd7a1195a534496b245a2d`.

---

## F13 — Requests & Approval Engine

`100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.

Contrato certificado:
`F12 own work-item → Request PENDING → ADMIN decision → atomic revalidation → explicit execution → F14 governed proposal context`.

Entregas:
- `aos_cia_requests`;
- `aos_cia_request_events` append-only;
- request `RELEASE_ASSIGNMENT`;
- advisor create/list/summary/detail;
- ADMIN gateway SUMMARY/LIST/GET/APPROVE/REJECT/EXECUTE;
- APPROVE ≠ EXECUTE;
- stale ownership/state/expiry → EXPIRED fail-closed;
- release execution reuses F9 lifecycle;
- Policy Gate para F14/KronIA;
- AUTO_ASSIGN/TRANSFER/AUTO_APPROVE/RAW_SQL BLOCK;
- `auto_execute=false`;
- advisor + ADMIN frontend;
- F14 readiness.

Security:
- F13 tables RLS enabled, 0 policies;
- anon/auth sin acceso directo;
- admin authority resuelta server-side;
- extension calls schema-qualified.

QA:
- rollback-only E2E PASS;
- cross-advisor/duplicate/invalid-admin/stale negative tests PASS;
- approve/execute idempotency PASS;
- zero residue PASS.

Performance:
- advisor list ~21.7 ms;
- advisor summary ~4.5 ms;
- F14 readiness ~250.2 ms;
- 1,000 request query-shape/page100 ~5.4 ms;
- target <1.5s PASS.

Integration:
- PR #95 MERGED;
- functional staging merge `594c2c77dae8513ff73a300e60f4caed1996efad`;
- GitHub Actions #997 no ejecutó steps por billing/spending del runner;
- manual scope-equivalent validation PASS;
- post-merge smoke PASS;
- live `aos_cia_request_f14_readiness_v1()` = `READY_NO_REQUESTS`, `ready_for_f14=true`.

Documento:
`docs/control/commercial-intelligence/PHASE_13_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## F14 — COMMERCIAL INTELLIGENCE SHADOW = READY

Objetivo:
convertir facts/segments/audiences/ownership/work/request outcomes en inteligencia comercial explicable **sin autoacciones**.

Input contract F13 → F14:
- `aos_cia_request_f14_readiness_v1()`;
- request lifecycle/state;
- `advisor_user_id` + `assignment_id`;
- F13 Policy Gate;
- facts/segments/audience/activation/ownership/work context certificado.

F14 debe construir:
- opportunities determinísticas;
- affinity/recompra/priorización;
- evidence + confidence + sample size + freshness;
- explainability;
- recommendation SHADOW;
- read-models ADMIN/advisor según roles;
- propuesta gobernada de acciones mediante F13 Policy Gate;
- outcome/audit link recommendation → proposed request → human decision.

F14 no debe:
- autoaprobar;
- autoejecutar;
- autoasignar;
- escribir SQL arbitrario;
- usar datos clínicos sensibles como features comerciales ordinarias;
- confundir score IA con regla determinística;
- saltarse F13.

Output esperado para F15:
**Intelligence Shadow explainable + governed tools/contracts, lista para KronIA/Multiagent sin autonomía de escritura.**

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
7. `PHASE_13_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase13_*`, `cia_phase14_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. `aos_cia_request_f14_readiness_v1()`
11. verificar staging + Supabase live antes de cualquier cambio.
