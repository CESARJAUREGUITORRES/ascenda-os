# ASCENDA OS — CIA MASTER ALIGNMENT CURRENT

**Estado:** CURRENT  
**Fecha:** 2026-08-14 (America/Lima)  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Estado dinámico:** `docs/control/commercial-intelligence/ROADMAP_STATUS.md`  
**Último merge funcional:** F15 `4836d1ad6b25bc57d0f278f99b72db8b8919054d`  
**Checkpoint de control actual:** consultar `staging` HEAD + `aos_memory.cia_v3_control_checkpoint`.

---

# 1. OBJETIVO

El Master V3 original continúa como arquitectura madre. Este documento alinea esa arquitectura con el estado real alcanzado después de cerrar F0–F15.

Para estado actual prevalecen:
1. `CIA_AGENT_BOOTSTRAP_CURRENT.md`;
2. `ROADMAP_STATUS.md`;
3. último `PHASE_XX_VALIDATION_REPORT.md`;
4. `aos_memory`;
5. `staging` + Supabase live.

---

# 2. ROADMAP MAESTRO 0–18 — ALINEACIÓN ACTUAL

| # | Fase | Estado actual | Dependencia principal |
|---:|---|---|---|
| 0 | Baseline & Contracts | `100_COMPLETE` | inicio |
| 1 | Identity Resolver | `100_COMPLETE` | F0 |
| 2 | Commercial Facts | `100_COMPLETE` | F1 |
| 3 | Segmentation Engine | `100_COMPLETE` | F2 |
| 4 | Audience Resolver | `100_COMPLETE` | F1–F3 |
| 5 | Panel Central Skeleton | `100_COMPLETE` | F4 |
| 6 | Audience Library Persistence | `100_COMPLETE` | F4–F5 |
| 7 | Snapshots & Activation | `100_COMPLETE` | F6 |
| 8 | Channel Context & Availability | `100_COMPLETE` | F7 |
| 9 | Assignment Engine | `100_COMPLETE` | F8 |
| 10 | Advisor Control Center | `100_COMPLETE` | F9 |
| 11 | Call Center Integration V3 | `100_COMPLETE` | F9+F10 |
| 12 | Advisor Work Views | `100_COMPLETE` | F9+F11 |
| 13 | Requests & Approval Engine | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | F12 |
| 14 | Commercial Intelligence Shadow | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | F13 + facts/segments |
| 15 | KronIA + Multiagent | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | F13/F14 |
| 16 | Email Integration | `READY` | Audience/Activation central + F15 |
| 17 | SMS/WhatsApp/Future Channels | `NOT_STARTED` | F8/F16 patterns |
| 18 | Attribution/Learning/Hardening | `NOT_STARTED` | todas las anteriores |

---

# 3. CADENA IMPLEMENTADA Y CERTIFICADA

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval → Intelligence Shadow → Governed KronIA/Multiagent`

Decisiones demostradas:
- `aos_usuarios.id` UUID = authority de ownership;
- `assignment_id` = referencia estable de work-item;
- F8 availability gobierna nuevas asignaciones;
- F9 lease/ownership gobierna trabajo activo;
- F11 routing consume ownership con fallback V2;
- F12 organiza work sin mutar owner;
- F13 separa Request/Approval/Execution;
- F14 Recommendation SHADOW explica evidencia, no actúa;
- F15 Agent/Tool orchestration interpreta/proporciona propuestas, no adquiere autoridad operacional;
- F13 Policy Gate permanece autoridad para acciones sensibles;
- F16 debe tratar Email como canal consumidor, no como Audience Engine paralelo.

---

# 4. REFINAMIENTOS INSTITUCIONALIZADOS

## Datos / freshness
UNKNOWN falla cerrado. STALE permanece explícito. Channel preview no equivale a eligibility/consent/send permission.

## Performance
No elevar timeouts para ocultar N+1/mega-views. F14 reemplazó ~44.4s live recomputation por persisted SHADOW; F15 readiness opera ~318.946ms.

## Seguridad
RLS teórico no basta: auditar grants. SECURITY DEFINER requiere autorización server-side real. F15 demostró que un RPC llamado “query” puede ser un bypass incluso si filtra a SELECT: arbitrary SQL no pertenece al Tool Registry.

## Tool governance
Tool Registry = allowlist explícita, versionada y tipada. `RAW_SQL`, `AUTO_ASSIGN`, `AUTO_APPROVE`, `TRANSFER` no son herramientas válidas de negocio para agentes.

## Agent governance
`Recommendation ≠ Agent Interpretation ≠ Proposal ≠ Request ≠ Human Decision ≠ Execution`.

Agent Run/Tool Call provenance se conserva tanto en success como en blocked outcomes. `auto_execute=false` es invariant.

## Legacy migration
No big-bang. Cuando una superficie legacy activa no puede apagarse sin romper producción, se endurece con un compatibility bridge medible y se mantiene su deuda en el programa propietario. F15 reemplazó arbitrary `aos_execute_agent_query` por exact active task-config allowlist sin romper cron.

## Replayability
Migration versionada debe reconciliar Git filename ↔ live ledger 1:1 antes de cierre.

## CI
Un runner bloqueado por billing antes de checkout no es fallo de código ni SUCCESS. F13–F15 usan `CI_INFRA_EXCEPTION_DOCUMENTED` solo con evidencia externa + validación equivalente + post-merge smoke.

---

# 5. F14 — CONTRATO CERRADO

F14 entrega Commercial Intelligence SHADOW:
- 451 recommendations;
- evidence/confidence/sample-size/freshness;
- explainability + observed affinity;
- F13 Policy Gate intacto;
- `aos_cia_intelligence_f15_readiness_v1()` = `READY_SHADOW_ACTIVE`, true.

Functional merge:
`ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`.

---

# 6. F15 — CONTRATO CERRADO

F15 entrega la capa canónica de orquestación gobernada para CIA V3:

### Tool plane
- `aos_cia_kronia_tool_registry`;
- 6 tools activas;
- READ/PROPOSE only;
- no RAW_SQL authority;
- F16 email preview no envía.

### Agent plane
- `aos_cia_kronia_agent_registry`;
- KronIA/Dante/Nico/Valentina/León/Sofía;
- execution mode SHADOW;
- allowlist por agente.

### Provenance/audit
- `aos_cia_kronia_agent_runs`;
- append-only tool calls;
- append-only governed proposals/events;
- proposal/request/outcome trace.

### Governance
- `RELEASE_ASSIGNMENT` → REQUIRE_APPROVAL;
- AUTO_ASSIGN → BLOCK;
- no autoapprove/autoexecute/autoassign;
- `proposal.release` exige active F9 ownership;
- ADMIN gateway verifica sesión CIA;
- direct F15 table access anon/auth=false.

### Legacy compatibility hardening
`aos_execute_agent_query` = `F15_CONFIG_ALLOWLIST_V1`: exact active configured SELECT only; arbitrary query bloqueada; task definitions no mutables por anon/auth.

### QA/performance
- 5 tools succeeded;
- 1 proposal blocked correctamente sin assignment;
- 0 assignments/requests/routing changes;
- 0 F15 proposals;
- 0 auto_execute;
- F16 readiness ~318.946ms.

### Output
`aos_cia_kronia_f16_readiness_v1()`:
- `READY_GOVERNED_ORCHESTRATION`;
- `ready_for_f16=true`.

Functional merge:
`4836d1ad6b25bc57d0f278f99b72db8b8919054d`.

**Scope boundary:** CIA F15 no reemplaza ni cierra automáticamente KronIA V2 K0–K8. Ese programa mantiene su propio hardening de auth/session/secrets/legacy endpoints/cutover.

---

# 7. F16 — CAMINO EXACTO

**Email Integration** es la siguiente fase correcta.

Input:
- Audience/Activation central;
- F8 channel context/availability pattern;
- F14 Recommendation SHADOW;
- F15 governed context/provenance;
- `aos_cia_kronia_f16_readiness_v1()`;
- inventario real de Email legacy antes de modificar delivery.

Debe construir:
- Email channel adapter sobre Audience/Activation central;
- eligibility/preview/freshness;
- campaign/template versioning;
- idempotency/deduplication;
- send request/queue separada de provider outcome;
- provider adapter/fallback;
- consent/suppression/bounce/unsubscribe desde fuentes autoritativas;
- end-to-end audit;
- ADMIN control surface;
- shadow/canary rollout;
- output reusable para F17.

No debe:
- enviar desde F15 preview;
- crear Audience Engine paralelo;
- inferir consentimiento ausente como TRUE;
- usar datos clínicos sensibles como ordinary commercial features;
- duplicar envíos por retry;
- romper email legacy antes de certificar adapter/fallback.

Output F16 → F17:
**Email integrado como channel adapter gobernado, reusable como patrón para SMS/WhatsApp/futuros canales.**

---

# 8. ESTADO ACTUAL DE LA MISIÓN

F0–F15 constituyen el núcleo gobernado de datos → audiencias → activación → ownership → trabajo → aprobación → inteligencia → orquestación IA gobernada.

**Siguiente fase: F16 — Email Integration.**
