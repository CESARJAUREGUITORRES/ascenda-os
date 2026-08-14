# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Estado:** CURRENT / DYNAMIC SOURCE OF PHASE STATUS  
**Última actualización:** 2026-08-14 (America/Lima)  
**Staging funcional F15:** `4836d1ad6b25bc57d0f278f99b72db8b8919054d`  
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
| 15 | KronIA + Multiagent Orchestration | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | 100% |
| 16 | Email Integration | `READY` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CADENA CERTIFICADA F0–F15

`Identity → Commercial Facts → Segmentation → Audience Resolver → Panel → Audience Library → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Routing V3 → Advisor Work Views → Requests & Approval → Commercial Intelligence Shadow → Governed KronIA/Multiagent`

Separaciones no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- Recommendation ≠ Authority;
- Agent interpretation ≠ Authority;
- F13 gobierna decisiones/ejecución sensibles;
- F14 calcula intelligence SHADOW, no actúa;
- F15 permite tools tipadas/propuestas/audit, no autonomía operacional;
- F11 conserva fallback V2 y global OFF salvo rollout explícito.

---

## F14 — Commercial Intelligence Shadow

`100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.

Output:
- 451 recommendations SHADOW;
- evidence/confidence/sample-size/freshness/explainability;
- observed commercial affinity;
- `aos_cia_intelligence_f15_readiness_v1()` = `READY_SHADOW_ACTIVE`, true;
- functional merge `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`.

Documento:
`PHASE_14_VALIDATION_REPORT.md`.

---

## F15 — KronIA + Multiagent Orchestration

`100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.

Contrato:
`F14 SHADOW → typed Tool Registry → governed Agent Registry → Agent Run/Tool Call provenance → F13 Policy Gate → proposal/request boundary → F16 governed email context`.

Entregas:
- private `aos_cia_kronia_tool_registry`;
- private `aos_cia_kronia_agent_registry`;
- `aos_cia_kronia_agent_runs`;
- append-only `aos_cia_kronia_tool_calls`;
- append-only `aos_cia_kronia_proposals` + events;
- tools `intelligence.get`, `intelligence.explain`, policy probes, `proposal.release`, `f16.email.context.preview`;
- governed agents KronIA/Dante/Nico/Valentina/León/Sofía;
- ADMIN token-gated gateway;
- F16 readiness contract;
- legacy SQL compatibility hardening `F15_CONFIG_ALLOWLIST_V1`.

Governance:
- all agents SHADOW;
- agent tool allowlists;
- RAW_SQL is not a tool;
- RELEASE proposal → REQUIRE_APPROVAL;
- AUTO_ASSIGN → BLOCK;
- auto_execute=false;
- F16 email preview `send_allowed=false` / `clinical_features_used=false`;
- no proposal created without active F9 ownership.

Security:
- 6 F15 tables RLS=true, policy_count=0, direct anon/auth access=false;
- internal F15 RPCs anon/auth execute=false;
- ADMIN gateway validates CIA admin session server-side;
- legacy arbitrary SELECT replaced with exact active task-config allowlist;
- anon/auth cannot mutate legacy task definitions.

QA:
- 5 governed tool calls SUCCEEDED;
- 1 sensitive proposal correctly BLOCKED without F9 assignment;
- invalid agent/cross-agent/RAW_SQL/invalid-admin/arbitrary-query negatives PASS;
- append-only guard PASS;
- valid admin gateway PASS;
- assignments=0, requests=0, routing events=0, F15 proposals=0;
- auto_execute violations=0.

Performance:
- F16 readiness ~318.946 ms;
- target <1.5s PASS.

Replayability:
Five migrations `20260814184100`–`20260814184500` match Git/live ledger 1:1.

Integration:
- PR #100 MERGED;
- functional staging merge `4836d1ad6b25bc57d0f278f99b72db8b8919054d`;
- Ascenda CI #1085 / run `31831087119` created job `94866672539` but executed 0 steps due GitHub billing/spending block;
- equivalent changed-scope validation PASS;
- post-merge smoke PASS;
- live F16 readiness `READY_GOVERNED_ORCHESTRATION`, `ready_for_f16=true`.

Scope boundary:
CIA F15 complete does **not** declare the broader KronIA V2 K0–K8 program complete. KronIA V2 keeps its own auth/ACL/cutover hardening track.

Documento:
`docs/control/commercial-intelligence/PHASE_15_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## F16 — EMAIL INTEGRATION = READY

Input F15 → F16:
- `aos_cia_kronia_f16_readiness_v1()`;
- Audience/Activation central;
- F8 context/availability pattern;
- F14 Recommendation SHADOW when relevant;
- F15 governed tool/provenance context;
- legacy Email runtime to be inventoried before any cutover.

F16 debe construir:
- Email como channel adapter sobre Audience/Activation central;
- preview/eligibility/freshness;
- campaign/template versioning;
- idempotency/deduplication;
- request/queue ≠ provider delivery outcome;
- consent/suppression/bounce/unsubscribe semantics from authoritative sources;
- end-to-end audit;
- provider adapter/fallback;
- ADMIN controls;
- shadow/canary before rollout;
- reusable channel contract hacia F17.

F16 no debe:
- enviar desde F15 preview;
- crear Audience Engine paralelo;
- asumir consentimiento ausente;
- usar clinical notes/photos/diagnoses as ordinary commercial features;
- duplicar sends on retry;
- romper legacy Email before adapter/fallback certification.

---

# LOOP UNIVERSAL V2

`recovery → baseline → input handshake → scope/Impact → branch → implementation → guards → QA rollback-only → security → performance → write-path safety → frontend/control surface → output handshake → PR/CI → staging smoke → Validation Report → aos_memory → Notion`

---

# CONTINUIDAD / RECOVERY

En un nuevo chat/agente:
1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md`
5. `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md`
6. este Roadmap
7. `PHASE_15_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase15_*`, `cia_phase16_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. `aos_cia_kronia_f16_readiness_v1()`
11. verificar staging + Supabase live antes de cualquier cambio.
