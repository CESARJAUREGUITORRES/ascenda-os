# ASCENDA OS — FASE 15 VALIDATION REPORT

**Fase:** F15 — KronIA + Multiagent Orchestration  
**Estado:** `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `f1febeecd6706d172cbb6a5f2d35e35119fa9004`  
**PR funcional:** #100  
**Merge funcional staging:** `4836d1ad6b25bc57d0f278f99b72db8b8919054d`  
**Ascenda CI:** run #1085 (`31831087119`) — `NOT_EXECUTED`; job `94866672539` tuvo 0 steps porque GitHub bloqueó el runner antes de iniciar por billing/spending.  
**Validación equivalente del scope cambiado:** PASS.

---

## 1. Resultado ejecutivo

F15 queda certificada como la capa canónica **GOVERNED_SHADOW** de KronIA + Multiagent dentro de Commercial Intelligence & Audience OS V3.

Contrato certificado:

`F14 SHADOW → typed Tool Registry → Agent Registry → Agent Run/Tool Call provenance → F13 Policy Gate → governed proposal/request boundary → F16 Email context`

Separación obligatoria:

**Recommendation ≠ Agent interpretation ≠ Proposal ≠ Request ≠ Approval ≠ Execution.**

F15 permite a KronIA/agentes observar, interpretar y proponer mediante herramientas tipadas. No autoasigna, no autoaprueba, no autoejecuta, no usa RAW_SQL como herramienta y no convierte una recomendación F14 en autoridad operacional.

---

## 2. Input handshake F14 → F15

Live `aos_cia_intelligence_f15_readiness_v1()`:
- `ok=true`;
- `status=READY_SHADOW_ACTIVE`;
- `ready_for_f15=true`;
- 451 recomendaciones SHADOW;
- 0 `non_shadow_state`;
- 0 `auto_execute`;
- 0 `missing_generated_event`;
- F13 `RELEASE_ASSIGNMENT` → `REQUIRE_APPROVAL`;
- F13 `AUTO_ASSIGN` → `BLOCK`;
- `auto_execute=false`;
- F11 V3 permanece global OFF.

**PASS.**

---

## 3. Impact Report CRITICAL

El baseline detectó un riesgo real preexistente: `aos_execute_agent_query(p_query text)` aceptaba SELECT dinámico caller-supplied y era consumido por agentes legacy activos desde `app/server.js`.

Apagarlo de forma inmediata habría roto cron en producción. F15 aplicó una migración compatible, no big-bang:
- exact-match de query contra un `sql_query` activo de `aos_agente_tareas`;
- SELECT-only;
- sin `;` ni comentarios SQL;
- meta-schemas bloqueados;
- máximo 100 filas;
- `statement_timeout=3000ms`;
- arbitrary caller query → `QUERY_NOT_ALLOWLISTED`;
- anon/auth no pueden INSERT/UPDATE/DELETE definiciones de tareas.

Marcador live:
`F15_CONFIG_ALLOWLIST_V1`.

Esto neutraliza el bypass de SQL arbitrario para el consumidor legacy migrado sin fingir que todo el programa KronIA V2/K1–K8 quedó resuelto.

---

## 4. Persistencia F15

Tablas canónicas privadas:
- `aos_cia_kronia_tool_registry`;
- `aos_cia_kronia_agent_registry`;
- `aos_cia_kronia_agent_runs`;
- `aos_cia_kronia_tool_calls`;
- `aos_cia_kronia_proposals`;
- `aos_cia_kronia_proposal_events`.

Garantías:
- RLS enabled en las seis tablas;
- 0 browser policies;
- anon/auth sin SELECT/INSERT/UPDATE/DELETE;
- tool calls/proposals/events protegidos como append-only;
- `auto_execute=false` por constraint en calls/proposals.

---

## 5. Tool Registry certificado

6 tools activas:
1. `intelligence.get` — READ / LOW;
2. `intelligence.explain` — READ / LOW;
3. `policy.release.probe` — READ / MEDIUM;
4. `policy.auto_assign.probe` — READ / HIGH;
5. `proposal.release` — PROPOSE / HIGH;
6. `f16.email.context.preview` — READ / MEDIUM.

Reglas:
- no existe tool RAW_SQL;
- registry bloquea request types `RAW_SQL`, `AUTO_APPROVE`, `AUTO_ASSIGN`, `TRANSFER_ASSIGNMENT` como autoridad;
- F16 preview nunca envía correo (`send_allowed=false`);
- F16 preview indica `clinical_features_used=false`.

---

## 6. Agent Registry certificado

6 agentes iniciales, todos `execution_mode=SHADOW`:
- `kronia` — KronIA / ORCHESTRATOR;
- `centinela` — Dante / OBSERVER;
- `clasificador` — Nico / INTERPRETER;
- `analista_mkt` — Valentina / ANALYST;
- `monitor` — León / MONITOR;
- `analista` — Sofía / ANALYST.

Cada agente tiene allowlist explícita de tools. Cross-agent access no autorizado falla cerrado.

---

## 7. Contracts de orquestación

### `aos_cia_kronia_tool_invoke_v1(...)`
Privada para browser. Verifica:
- readiness F14;
- agente activo + SHADOW;
- tool activa;
- tool permitida al agente;
- recomendación F14 válida cuando aplica;
- Policy Gate F13 para propuestas sensibles.

Genera provenance + Agent Run + Tool Call audit.

### Proposal RELEASE
`proposal.release`:
- consulta `KRONIA + PROPOSE + RELEASE_ASSIGNMENT`;
- exige `REQUIRE_APPROVAL` y `auto_execute=false`;
- exige assignment F9 real, activo, no vencido, consistente con advisor;
- si no existe ownership requestable → BLOCK;
- si existe → crea solo propuesta `REQUIRES_APPROVAL`;
- no crea aprobación;
- no ejecuta release;
- el request F13 se enlaza solo si coincide assignment/requester/type.

### Outcome observation
F15 puede observar state del request enlazado para auditoría, pero no toma la decisión ni ejecuta.

---

## 8. ADMIN control surface

`aos_cia_kronia_admin_gateway_v1(token,action,payload)` es el único RPC F15 browser-callable.

Valida `aos_cia_verify_admin_session_v1()` server-side y soporta:
- READINESS;
- SUMMARY;
- TOOLS;
- AGENTS;
- RUNS;
- PROPOSALS;
- DRY_RUN.

DRY_RUN reutiliza las tools gobernadas y declara `operational_execution=false`.

QA:
- invalid token → `UNAUTHORIZED`;
- sesión ADMIN temporal controlada → SUMMARY PASS;
- sesión de QA eliminada inmediatamente.

---

## 9. Governed smoke

Recommendation de prueba:
`cc1e9462-8d53-452a-9229-27a48ec1dbb9`

Contexto:
- FOLLOWUP_RECOVERY;
- score 93;
- confidence HIGH;
- sample size 14;
- freshness AGING;
- sin assignment/advisor F9 activo.

Resultados:
1. KronIA `intelligence.get` → SUCCEEDED, 321.359 ms;
2. Nico `intelligence.explain` → SUCCEEDED, 42.791 ms;
3. Sofía `policy.release.probe` → SUCCEEDED, REQUIRE_APPROVAL, executed=false;
4. KronIA `policy.auto_assign.probe` → SUCCEEDED, BLOCK, executed=false;
5. Valentina `f16.email.context.preview` → SUCCEEDED, send_allowed=false, clinical_features_used=false;
6. KronIA `proposal.release` → BLOCKED `NO_ACTIVE_ASSIGNMENT_CONTEXT`.

Post-smoke:
- assignments = 0;
- F13 requests = 0;
- routing events = 0;
- F15 runs = 6;
- F15 tool calls = 6;
- successful calls = 5;
- F15 proposals = 0;
- auto_execute calls = 0;
- auto_execute proposals = 0.

Las seis filas F15 son evidencia de audit/provenance intencional, no efectos operativos.

---

## 10. Negative / security tests

PASS:
- invalid agent → `AGENT_NOT_FOUND`;
- Nico + `proposal.release` → `TOOL_NOT_ALLOWED_FOR_AGENT`;
- `raw_sql` → `TOOL_NOT_FOUND`;
- invalid ADMIN token → `UNAUTHORIZED`;
- arbitrary legacy SQL → `QUERY_NOT_ALLOWLISTED`;
- exact configured legacy query → PASS con guard F15;
- proposal sin F9 ownership → BLOCK;
- AUTO_ASSIGN → BLOCK;
- append-only UPDATE attempt → `PASS_APPEND_ONLY`;
- direct anon/auth F15 table access → false.

Internal F15 RPCs:
- anon execute=false;
- authenticated execute=false.

ADMIN gateway:
- anon/auth EXECUTE=true únicamente para llegar al server-side token gate;
- invalid token no obtiene datos.

Legacy `aos_execute_agent_query` continúa executable por anon/auth por compatibilidad de runtime, pero el payload ya no es arbitrary SQL: solo exact configured active task query y las task definitions no son mutables por dichos roles.

---

## 11. Performance

`EXPLAIN (ANALYZE,BUFFERS)`:

`select aos_cia_kronia_f16_readiness_v1()`
- execution time: **318.946 ms**;
- shared hit blocks: 3,568;
- shared read blocks: 0;
- target <1.5s → PASS.

Tool smoke observado: ~40.9–321.4 ms.

No se incrementaron timeouts para ocultar diseño lento.

---

## 12. Replayability

Live ledger = Git 1:1:
- `20260814184100_cia_phase15_kronia_governed_schema_v1.sql`;
- `20260814184200_cia_phase15_kronia_registry_seed_v1.sql`;
- `20260814184300_cia_phase15_kronia_orchestration_contracts_v1.sql`;
- `20260814184400_cia_phase15_legacy_agent_query_guard_v1.sql`;
- `20260814184500_cia_phase15_admin_readiness_v1.sql`.

Read-only audit:
`scripts/audit_cia_kronia_phase15_readonly.sql`.

**PASS.**

---

## 13. PR / CI / staging

Functional PR #100:
- 8 changed files;
- 866 additions;
- 0 deletions;
- merge to `staging`: `4836d1ad6b25bc57d0f278f99b72db8b8919054d`.

Ascenda CI #1085:
- workflow run `31831087119`;
- job `94866672539`;
- status failure;
- steps executed = 0;
- GitHub annotation: runner did not start because account payments failed or spending limit must be increased.

Clasificación correcta:
**`CI_INFRA_EXCEPTION_DOCUMENTED`**.

No se representa como CI SUCCESS ni como fallo de código. La validación equivalente de alcance + smoke post-merge PASS permite cerrar según la excepción institucionalizada usada en fases anteriores.

---

## 14. Post-merge smoke

Después de merge funcional:
- staging HEAD = `4836d1ad6b25bc57d0f278f99b72db8b8919054d`;
- live F16 readiness = `READY_GOVERNED_ORCHESTRATION`;
- `ready_for_f16=true`;
- active tools = 6;
- active agents = 6;
- bad tools = 0;
- bad agents = 0;
- missing allowed tools = 0;
- browser direct F15 table access anon/auth=false;
- legacy allowlist=true;
- assignments/requests/routing remain 0;
- proposals remain 0;
- auto_execute remains 0.

**PASS.**

---

## 15. Output F15 → F16

`aos_cia_kronia_f16_readiness_v1()`:

- `ok=true`;
- `ready_for_f16=true`;
- `status=READY_GOVERNED_ORCHESTRATION`;
- mode `GOVERNED_SHADOW`.

F16 puede integrar Email sobre Audience/Activation central + contexto gobernado F15. F15 solo entrega preview/contexto; no envía emails.

---

## 16. Scope boundary KronIA V2

Esta certificación significa:

**CIA F15 = 100_COMPLETE.**

No significa:

**KronIA V2 K0–K8 = 100_COMPLETE.**

El programa KronIA V2 conserva deuda separada de auth/session/secrets, ACL/cutover, endpoints legacy y hardening específico. La capa CIA F15 queda aislada y gobernada para que Commercial Intelligence pueda avanzar a F16 sin falsear el estado del programa hermano.

---

# CERTIFICACIÓN

**FASE 15 — KronIA + Multiagent Orchestration = `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.**

**FASE 16 — Email Integration = `READY`.**
