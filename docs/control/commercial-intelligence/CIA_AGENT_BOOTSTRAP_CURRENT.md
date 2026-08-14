# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** F0–F14 `100_COMPLETE`  
**Fase actual:** F15 — KronIA + Multiagent Orchestration `READY`  
**Último merge funcional certificado:** F14 `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`  
**CI F14:** GitHub Actions run #1067 no ejecutó steps por billing/spending del runner; `CI_INFRA_EXCEPTION_DOCUMENTED` + validación equivalente + post-merge smoke PASS.  
**Checkpoint de control/documentación actual:** consultar `aos_memory.cia_v3_control_checkpoint` + `staging` HEAD live.

---

# 1. MISIÓN

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval → Intelligence Shadow → KronIA → Channels → Attribution`

Misión global ASCENDA:
`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

Principios no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- Recommendation ≠ authority;
- ownership = `aos_usuarios.id` UUID;
- `assignment_id` es referencia estable de work-item;
- UNKNOWN/freshness incompleta falla cerrado;
- SQL/RPC determinístico calcula; IA interpreta/recomienda;
- IA no aprueba, ejecuta ni asigna ownership automáticamente;
- no big-bang;
- no romper producción para completar una fase.

---

# 2. RECOVERY OBLIGATORIO

Antes de cualquier cambio F15:
1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. este Bootstrap;
4. `CIA_EXECUTION_PLAYBOOK_V1.md`;
5. `CIA_MASTER_ALIGNMENT_CURRENT.md`;
6. `ROADMAP_STATUS.md`;
7. `PHASE_14_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase14_*`, `cia_phase15_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. ejecutar `aos_cia_intelligence_f15_readiness_v1()`;
13. recién entonces iniciar F15.

GitHub + Supabase/runtime prevalecen sobre Notion.

---

# 3. ROADMAP F0–F18

| # | Fase | Estado |
|---:|---|---|
| 0 | Baseline & Contracts | `100_COMPLETE` |
| 1 | Identity Resolver | `100_COMPLETE` |
| 2 | Commercial Facts | `100_COMPLETE` |
| 3 | Segmentation Engine | `100_COMPLETE` |
| 4 | Audience Resolver | `100_COMPLETE` |
| 5 | Panel Central Skeleton | `100_COMPLETE` |
| 6 | Audience Library Persistence | `100_COMPLETE` |
| 7 | Snapshots & Activation | `100_COMPLETE` |
| 8 | Channel Context & Availability | `100_COMPLETE` |
| 9 | Assignment Engine | `100_COMPLETE` |
| 10 | Advisor Control Center | `100_COMPLETE` |
| 11 | Call Center Integration V3 | `100_COMPLETE` |
| 12 | Advisor Work Views | `100_COMPLETE` |
| 13 | Requests & Approval Engine | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` |
| 14 | Commercial Intelligence Shadow | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` |
| 15 | KronIA + Multiagent Orchestration | `READY` |
| 16 | Email Integration | `NOT_STARTED` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 4. CONTRATOS CERTIFICADOS CLAVE

## F9 Assignment
- ownership por advisor UUID;
- lease lifecycle `RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED|RELEASED|EXPIRED`;
- concurrency/idempotency/audit.

## F11 Call Center V3
- routing paralelo/canary;
- global kill switch default OFF;
- V2 fallback obligatorio;
- output `aos_cia_call_routing_f12_readiness_v1()`.

## F12 Advisor Work
- work universe deriva solo de F9 ownership;
- pin/snooze/priority nunca cambian owner;
- requestable solo own ASSIGNED/IN_PROGRESS no expirado;
- output `aos_cia_advisor_work_f13_readiness_v1()`.

## F13 Requests & Approval
- `aos_cia_requests` + append-only events;
- Request ≠ Approval ≠ Execution;
- EXECUTE revalida ownership/state/expiry;
- F14/KronIA `RELEASE_ASSIGNMENT` proposal → REQUIRE_APPROVAL;
- AUTO_ASSIGN/TRANSFER/AUTO_APPROVE/RAW_SQL → BLOCK;
- `auto_execute=false`;
- output `aos_cia_request_f14_readiness_v1()`.

## F14 Commercial Intelligence Shadow
Persistencia derivada:
- `aos_cia_intelligence_shadow_runs`;
- `aos_cia_intelligence_recommendations`;
- `aos_cia_intelligence_events`.

Motor:
- `aos_cia_intelligence_shadow_refresh_v1(...)`;
- deterministic Opportunity types;
- evidence + confidence + sample_size + freshness + explainability;
- observed commercial affinity;
- identity conflicts excluded;
- segment cache refresh + exact coverage gate;
- state siempre SHADOW;
- no autoactions.

Read/governance:
- `aos_cia_intelligence_admin_gateway_v1(...)`;
- `aos_cia_intelligence_advisor_list_v1(...)` limitado a ownership F9 actual;
- Policy Gate F13 intacto;
- `aos_cia_intelligence_f15_readiness_v1()`.

Live certified run:
- 451 recommendations;
- 291 HIGH confidence / 156 MEDIUM / 4 LOW;
- 111 FRESH / 45 AGING / 295 STALE / 0 UNKNOWN;
- latest-run top100 ~66.9 ms;
- F15 readiness ~54.1 ms;
- batch ~4.21 s vs rejected ~44.4 s live mega-join.

Output F15:
- `READY_SHADOW_ACTIVE`;
- `ready_for_f15=true`;
- non_shadow_state=0;
- auto_execute=0;
- missing_generated_event=0;
- direct browser table access=false.

Functional integration F14:
- PR #98 MERGED;
- staging merge `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`;
- security/performance/static/replayability/post-merge smoke PASS;
- GitHub Actions run #1067 blocked before executing steps by account billing/spending; validation equivalent documented, never called SUCCESS.

---

# 5. FASE 15 — MISIÓN EXACTA

Construir **KronIA + Multiagent Orchestration** sobre los contracts estructurados F13/F14 sin entregar autonomía de escritura arbitraria.

## Input autoritativo
- F14 Shadow Recommendation objects;
- deterministic evidence/confidence/sample-size/freshness;
- observed commercial affinity;
- F9 advisor/assignment context;
- F13 request lifecycle + Policy Gate;
- `aos_cia_intelligence_f15_readiness_v1()`.

## Debe construir
- Tool Registry estructurado y versionado;
- Policy Gate como mandatory preflight de toda acción sensible;
- agente/orquestador que consulta facts y recommendations sin SQL arbitrario;
- separación `OBSERVE → INTERPRET → PROPOSE → REQUEST → HUMAN DECISION → EXECUTE`;
- tool inputs/outputs tipados;
- provenance/evidence por respuesta;
- agent run/audit trace;
- rate/timeout/error boundaries;
- roles y scopes por agente;
- shadow-first rollout;
- output contract hacia F16 Email Integration.

## No debe
- autoaprobar;
- autoejecutar ownership;
- autoasignar;
- escribir SQL arbitrario;
- leer datos clínicos sensibles como features comerciales ordinarias;
- saltarse F13 Policy Gate;
- usar una recommendation F14 como verdad o permiso de acción;
- eliminar fallback/compatibilidad existente.

Output esperado F15 → F16:
**KronIA/Multiagent gobernado por tools + Policy Gate + audit, capaz de consultar/interpretar/proponer sin autonomía de escritura, listo para consumir Email como canal central.**

---

# 6. GUARDRAILS PERMANENTES

- recovery + handshake antes de escribir;
- Impact Report si HIGH/CRITICAL;
- QA mutante rollback-only;
- benchmarks mutantes rollback-only;
- zero operational residue;
- migrations Git ↔ live 1:1;
- ACL reales post-DDL;
- performance por cardinalidad realista;
- freshness explícita;
- una sola fuente autoritativa de audit events por dominio;
- verificar source real cargado por shell;
- sincronizar staging concurrente;
- output handshake antes de `100_COMPLETE`;
- GitHub/staging → `aos_memory` → Notion.

---

# 7. LECCIONES VIGENTES F0–F14

1. Mega-views lentas → resolver por dominios/snapshots, no timeout.
2. Índices CIA pueden romper write-path → probar paths operativos.
3. ACL defaults inesperados → auditar grants reales.
4. Auth heredada no se reutiliza sin auditoría.
5. Migration filenames deben reconciliar con ledger live.
6. Cache sin coverage/freshness → UNKNOWN fail-closed.
7. SECURITY DEFINER + search_path restringido → schema-qualify extensiones.
8. Audit events → productor autoritativo por dominio.
9. “Hoy” operacional = `America/Lima`.
10. Assignment → probar lifecycle completo.
11. Evitar N+1; snapshot/list + live drill-down.
12. Verificar runtime cargado realmente por shell.
13. Benchmark mutante → rollback-only.
14. F8 gobierna nuevo ASSIGNED; F9 ownership gobierna IN_PROGRESS.
15. Work View nunca muta ownership.
16. Request/Approval/Execution son estados separados.
17. Retry terminal idempotente antes de revalidar recurso ya mutado por ejecución previa.
18. CI bloqueado antes de checkout no es SUCCESS ni fallo de producto; documentar excepción.
19. F14 confirmó que una join live facts+segments podía costar ~44.4 s; el patrón correcto es refresh/coverage + SHADOW persistence + interactive read-model.
20. Freshness stale se etiqueta; nunca se maquilla como fresh ni se usa como autoridad.
21. Recommendation es evidencia para interpretación, no permiso para actuar.

---

# 8. SIGUIENTE ACCIÓN

**F15 — KronIA + Multiagent Orchestration.**

Primer loop:
1. recovery completo;
2. `aos_cia_intelligence_f15_readiness_v1()` = true;
3. baseline KronIA/agent/tool objects existentes;
4. Impact Report CRITICAL antes de ampliar agent write surface;
5. definir Tool Registry + Agent Run/Audit contracts;
6. Policy Gate F13 obligatorio para proposed actions;
7. iniciar en SHADOW/READ-only donde sea posible;
8. no habilitar autonomía general durante F15.
