# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** F0–F13 `100_COMPLETE`  
**Fase actual:** F14 — Commercial Intelligence Shadow `READY`  
**Último merge funcional certificado:** F13 `594c2c77dae8513ff73a300e60f4caed1996efad`  
**CI F13:** GitHub Actions #997 no ejecutó por billing/spending del runner; `CI_INFRA_EXCEPTION_DOCUMENTED` + validación equivalente aislada PASS.  
**Checkpoint de control/documentación actual:** consultar `aos_memory.cia_v3_control_checkpoint` + `staging` HEAD live.

---

# 1. MISIÓN

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval → Intelligence Shadow → KronIA → Channels → Attribution`

Misión global ASCENDA:
`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

Principios no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- ownership = `aos_usuarios.id` UUID;
- `assignment_id` es referencia estable de work-item;
- UNKNOWN/freshness incompleta falla cerrado;
- SQL/RPC determinístico calcula; IA interpreta/recomienda;
- IA no aprueba ni ejecuta ownership automáticamente;
- no big-bang;
- no romper producción para completar una fase.

---

# 2. RECOVERY OBLIGATORIO

Antes de cualquier cambio F14:
1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. este Bootstrap;
4. `CIA_EXECUTION_PLAYBOOK_V1.md`;
5. `CIA_MASTER_ALIGNMENT_CURRENT.md`;
6. `ROADMAP_STATUS.md`;
7. `PHASE_13_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase13_*`, `cia_phase14_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. ejecutar `aos_cia_request_f14_readiness_v1()`;
13. recién entonces iniciar F14.

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
| 14 | Commercial Intelligence Shadow | `READY` |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` |
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
- kill switch global default OFF;
- V2 fallback obligatorio;
- F12 readiness `aos_cia_call_routing_f12_readiness_v1()`.

## F12 Advisor Work
- work universe deriva solo de F9 ownership;
- pin/snooze/prioridad nunca mutan ownership;
- `requestable=true` solo para own ASSIGNED/IN_PROGRESS no expirado;
- output `aos_cia_advisor_work_f13_readiness_v1()`.

## F13 Requests & Approval
Persistencia:
- `aos_cia_requests`;
- `aos_cia_request_events` append-only.

Advisor:
- `aos_cia_request_create_v1(...)`;
- `aos_cia_request_advisor_summary_v1(...)`;
- `aos_cia_request_list_advisor_v1(...)`;
- `aos_cia_request_detail_advisor_v1(...)`.

ADMIN:
- `aos_cia_request_admin_gateway_v1(...)`;
- APPROVE ≠ EXECUTE;
- EXECUTE revalida ownership/state/expiry bajo lock;
- RELEASE usa lifecycle F9.

Policy Gate:
- `aos_cia_request_policy_gate_v1(...)`;
- F14/KronIA `RELEASE_ASSIGNMENT` proposal → `REQUIRE_APPROVAL`;
- AUTO_ASSIGN / TRANSFER / AUTO_APPROVE / RAW_SQL → `BLOCK`;
- `auto_execute=false`.

Output F14:
- `aos_cia_request_f14_readiness_v1()`;
- post-merge `READY_NO_REQUESTS`, `ready_for_f14=true`.

Functional integration F13:
- PR #95 MERGED;
- staging merge `594c2c77dae8513ff73a300e60f4caed1996efad`;
- rollback-only QA PASS;
- zero residue;
- RLS/ACL PASS;
- performance PASS;
- post-merge smoke PASS;
- GitHub Actions #997 blocked before checkout by account billing; manual scope-equivalent validation documented, not falsely marked SUCCESS.

---

# 5. FASE 14 — MISIÓN EXACTA

Construir **Commercial Intelligence Shadow** sobre facts/segmentation/audiences/ownership/work/requests ya certificados.

F14 debe producir recomendaciones explicables sin convertirse todavía en actor autónomo.

## Input autoritativo
- Commercial Facts/segments existentes;
- Audience/Activation context;
- F9 ownership;
- F12 work-item context;
- F13 request lifecycle + Policy Gate;
- `aos_cia_request_f14_readiness_v1()`.

## Debe construir
- oportunidad comercial determinística;
- afinidad/recompra/priorización con evidence;
- confidence + sample size + freshness;
- explainability por oportunidad;
- shadow recommendations sin write-path operativo;
- read models ADMIN/advisor según roles;
- propuesta gobernada de acciones vía F13 Policy Gate;
- observabilidad de recommendation → proposed request → human decision;
- output contract para F15 KronIA + Multiagent.

## No debe
- autoaprobar;
- autoejecutar;
- autoasignar;
- usar historia clínica/fotos/diagnósticos/notas como feature comercial ordinaria;
- escribir SQL arbitrario;
- saltarse F13;
- confundir score IA con verdad determinística.

Output esperado F14 → F15:
**Intelligence Shadow explainable + tools/contracts gobernados por Policy Gate, listo para orquestación KronIA sin autonomía de escritura.**

---

# 6. GUARDRAILS PERMANENTES

- recovery + handshake antes de escribir;
- Impact Report si HIGH/CRITICAL;
- QA mutante rollback-only;
- `EXPLAIN ANALYZE` mutante dentro de rollback;
- zero residue;
- migrations Git ↔ live 1:1 para cambios del frente;
- ACL reales post-DDL;
- performance por cardinalidad realista;
- freshness explícita;
- una sola fuente autoritativa de audit events;
- verificar source real cargado por shell;
- sincronizar staging concurrente;
- output handshake antes de `100_COMPLETE`;
- GitHub/staging → `aos_memory` → Notion.

---

# 7. LECCIONES VIGENTES F0–F13

1. Mega-views lentas → resolver por dominios/keys.
2. Índices CIA pueden romper write-path → probar INSERT/UPDATE críticos.
3. ACL defaults inesperados → auditar grants reales.
4. Auth heredada no se reutiliza sin auditoría.
5. Migration filenames deben reconciliar con ledger live.
6. Cache sin coverage/freshness → UNKNOWN fail-closed.
7. SECURITY DEFINER + search_path restringido → schema-qualify extensiones (`extensions.digest`).
8. Audit events → un productor autoritativo.
9. “Hoy” operacional = `America/Lima`.
10. Assignment → probar assign/release/expire/top-up.
11. Evitar N+1; list/snapshot + live drill-down.
12. Verificar runtime realmente cargado por shell.
13. Benchmark mutante → rollback-only.
14. F8 gobierna nuevo ASSIGNED; F9 ownership gobierna IN_PROGRESS.
15. Work View jamás muta ownership.
16. Request/Approval/Execution son estados separados.
17. Retry idempotente terminal debe reconocerse antes de revalidar un recurso que la primera ejecución mutó intencionalmente.
18. Fallo de infraestructura CI no se debe falsificar como test fallido ni como SUCCESS: documentar excepción y validación equivalente.

---

# 8. SIGUIENTE ACCIÓN

**F14 — Commercial Intelligence Shadow.**

Primer loop:
1. recovery completo;
2. `aos_cia_request_f14_readiness_v1()` = true;
3. baseline de intelligence/recommendation objects ya existentes;
4. Impact Report HIGH/CRITICAL según write surface;
5. definir Opportunity/Recommendation contracts, evidence/confidence/freshness;
6. mantener todo SHADOW/read-only al inicio;
7. cualquier acción propuesta debe cruzar F13 Policy Gate.
