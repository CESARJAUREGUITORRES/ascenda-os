# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** F0–F15 `100_COMPLETE`  
**Fase actual:** F16 — Email Integration `READY`  
**Último merge funcional certificado:** F15 `4836d1ad6b25bc57d0f278f99b72db8b8919054d`  
**CI F15:** GitHub Actions #1085 no ejecutó steps por billing/spending del runner; `CI_INFRA_EXCEPTION_DOCUMENTED` + validación equivalente + post-merge smoke PASS.  
**Checkpoint de control/documentación:** consultar `aos_memory.cia_v3_control_checkpoint` + `staging` HEAD live.

---

# 1. MISIÓN

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval → Intelligence Shadow → KronIA/Multiagent → Email → Channels → Attribution`

Misión global ASCENDA:
`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

Principios no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View ≠ Request ≠ Approval ≠ Execution;
- Recommendation ≠ Authority;
- Agent interpretation ≠ Authority;
- ownership = `aos_usuarios.id` UUID;
- UNKNOWN/freshness incompleta falla cerrado;
- SQL/RPC determinístico calcula; IA interpreta/recomienda;
- IA no autoasigna, autoaprueba ni autoejecuta;
- no arbitrary SQL tool;
- no big-bang;
- no romper producción para completar una fase.

---

# 2. RECOVERY OBLIGATORIO

Antes de cualquier cambio F16:
1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. este Bootstrap;
4. `CIA_EXECUTION_PLAYBOOK_V1.md`;
5. `CIA_MASTER_ALIGNMENT_CURRENT.md`;
6. `ROADMAP_STATUS.md`;
7. `PHASE_15_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase15_*`, `cia_phase16_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. ejecutar `aos_cia_kronia_f16_readiness_v1()`;
13. recién entonces iniciar F16.

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
| 15 | KronIA + Multiagent Orchestration | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` |
| 16 | Email Integration | `READY` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 4. CONTRATOS CERTIFICADOS CLAVE

## F9 — Assignment
Ownership por advisor UUID; lifecycle `RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED|RELEASED|EXPIRED`.

## F13 — Requests & Approval
`Request ≠ Approval ≠ Execution`; EXECUTE revalida ownership/state/expiry. Policy Gate:
- KronIA/F14 `RELEASE_ASSIGNMENT` proposal → `REQUIRE_APPROVAL`;
- AUTO_ASSIGN/TRANSFER/AUTO_APPROVE/RAW_SQL → `BLOCK`;
- `auto_execute=false`.

## F14 — Commercial Intelligence Shadow
451 recomendaciones SHADOW explicables con evidence/confidence/sample-size/freshness/affinity. `aos_cia_intelligence_f15_readiness_v1()` = `READY_SHADOW_ACTIVE`, true. Recommendation nunca es autoridad.

## F15 — KronIA + Multiagent Orchestration
Persistencia/control:
- `aos_cia_kronia_tool_registry`;
- `aos_cia_kronia_agent_registry`;
- `aos_cia_kronia_agent_runs`;
- `aos_cia_kronia_tool_calls`;
- `aos_cia_kronia_proposals`;
- `aos_cia_kronia_proposal_events`.

Tools certificadas:
- `intelligence.get`;
- `intelligence.explain`;
- `policy.release.probe`;
- `policy.auto_assign.probe`;
- `proposal.release`;
- `f16.email.context.preview`.

Agentes gobernados iniciales:
- KronIA;
- Dante;
- Nico;
- Valentina;
- León;
- Sofía.

Gobierno:
- execution mode siempre SHADOW;
- tool allowlist por agente;
- provenance + Agent Run/Tool Call audit;
- proposal RELEASE exige F9 ownership requestable + F13 Policy Gate;
- no autoapprove/autoexecute/autoassign;
- `f16.email.context.preview` no envía correo y no usa features clínicas;
- internal F15 RPCs privadas; ADMIN gateway con sesión CIA server-side.

Legacy compatibility hardening:
- `aos_execute_agent_query` ya no acepta arbitrary caller SQL;
- exact active task-config allowlist `F15_CONFIG_ALLOWLIST_V1`;
- SELECT-only + 100 row cap + 3s timeout;
- anon/auth no pueden mutar `aos_agente_tareas`.

Live F15 smoke:
- 5 governed tool calls SUCCEEDED;
- 1 proposal correctamente BLOCKED por no existir F9 ownership;
- assignments/requests/routing = 0;
- proposals = 0;
- auto_execute = 0;
- F16 readiness ≈318.946 ms.

Output F16:
- `aos_cia_kronia_f16_readiness_v1()`;
- `status=READY_GOVERNED_ORCHESTRATION`;
- `ready_for_f16=true`.

Functional integration F15:
- PR #100 MERGED;
- staging merge `4836d1ad6b25bc57d0f278f99b72db8b8919054d`;
- GitHub Actions #1085: 0 steps por billing/spending;
- equivalent validation + post-merge smoke PASS.

**Scope boundary:** CIA F15 cerrado no equivale a cerrar KronIA V2 K0–K8. El programa hermano conserva su propio hardening/cutover.

---

# 5. FASE 16 — MISIÓN EXACTA

Integrar **Email** como canal consumidor de la arquitectura central, sin crear un Audience Engine paralelo ni permitir que una recomendación/IA envíe automáticamente por sí sola.

## Input autoritativo
- Audience/Activation central ya certificado;
- F8 channel context/availability cuando aplique;
- F14 Recommendation SHADOW;
- F15 governed context/tool provenance;
- `aos_cia_kronia_f16_readiness_v1()`.

## Debe construir
- contrato Email sobre Audience/Activation central;
- preview/eligibility/freshness antes de envío;
- template/campaign identity versionada;
- idempotency/deduplication;
- send request/queue separada de delivery outcome;
- provider adapter/fallback sin acoplar Audience a proveedor;
- consent/suppression/bounce/unsubscribe cuando exista dato autoritativo;
- audit end-to-end activation → email request → provider/delivery outcome;
- roles/ADMIN control surface;
- gradual rollout/canary;
- output hacia F17 canales futuros.

## No debe
- enviar desde F15 preview;
- crear una base de audiencia paralela;
- inferir consentimiento inexistente como TRUE;
- usar historia clínica/fotos/diagnósticos/notas como features comerciales ordinarias;
- duplicar envíos por retry;
- autoejecutar acciones sensibles por score IA;
- romper el email legacy antes de tener adapter/fallback probado.

Output esperado F16 → F17:
**Email como primer channel adapter gobernado sobre Audience/Activation central, con trazabilidad y delivery semantics reutilizables por SMS/WhatsApp/futuros canales.**

---

# 6. GUARDRAILS PERMANENTES

- recovery + handshake antes de escribir;
- Impact Report si HIGH/CRITICAL;
- QA mutante rollback-only;
- zero operational residue;
- migrations Git ↔ live 1:1;
- ACL/RLS reales post-DDL;
- performance por cardinalidad realista;
- freshness explícita;
- typed tools y provenance;
- Policy Gate para acciones sensibles;
- una sola fuente autoritativa de audit events por dominio;
- verificar runtime real cargado por shell/server;
- staging smoke antes de cierre;
- GitHub/staging → `aos_memory` → Notion.

---

# 7. LECCIONES VIGENTES F0–F15

1. Mega-views lentas → dominios/snapshots, no timeout.
2. Índices CIA pueden romper write-path → probar paths operativos.
3. ACL defaults inesperados → auditar grants reales.
4. Auth heredada no se reutiliza sin auditoría.
5. Migrations deben reconciliar 1:1 con ledger live.
6. UNKNOWN/freshness incompleta → fail-closed.
7. SECURITY DEFINER requiere hardening real, no confianza en nombre de RPC.
8. Una Recommendation es evidencia, no autoridad.
9. Un Agent interpreta/proporciona propuestas, no adquiere autoridad.
10. Tool Registry debe ser allowlist tipada; RAW_SQL no es una tool de negocio.
11. Un compatibility bridge puede endurecer legacy sin big-bang: exact config allowlist permitió neutralizar arbitrary SQL sin romper cron activo.
12. Proposal ≠ Request ≠ Human Decision ≠ Execute.
13. Audit/provenance deben persistir incluso cuando una acción es BLOCKED.
14. F16 channel context preview ≠ permiso de envío.
15. CI bloqueado antes de checkout se documenta como infraestructura, nunca SUCCESS.

---

# 8. SIGUIENTE ACCIÓN

**F16 — Email Integration.**

Primer loop:
1. recovery completo;
2. `aos_cia_kronia_f16_readiness_v1()` = true;
3. inventariar Email legacy real: tablas/RPCs/server/provider/cron/templates/sends/alerts;
4. identificar qué flujo envía hoy y qué source carga el runtime;
5. Impact Report antes de tocar delivery;
6. diseñar adapter sobre Audience/Activation central;
7. comenzar shadow/read-only + preview;
8. mantener fallback legacy hasta canary certificado.
