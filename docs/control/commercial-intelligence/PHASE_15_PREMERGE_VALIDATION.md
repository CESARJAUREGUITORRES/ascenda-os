# ASCENDA OS — FASE 15 PRE-MERGE VALIDATION

**Fase:** F15 — KronIA + Multiagent Orchestration  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `f1febeecd6706d172cbb6a5f2d35e35119fa9004`  
**Branch:** `feature/commercial-intelligence-phase15-kronia-governed-20260814`

## Resultado pre-merge

**PASS para PR/staging.**

F15 introduce un plano canónico `GOVERNED_SHADOW` para KronIA/CIA sin otorgar autoridad operacional a la IA.

Contrato:

`F14 SHADOW → typed Tool Registry → Agent Registry → Agent Run/Tool Call provenance → F13 Policy Gate → governed proposal boundary → F16 readiness`

## Input F14 → F15

Live:
- `aos_cia_intelligence_f15_readiness_v1().ok=true`;
- `status=READY_SHADOW_ACTIVE`;
- `ready_for_f15=true`;
- 451 recomendaciones;
- 0 non-shadow state;
- 0 auto_execute;
- 0 missing GENERATED event;
- F13 `RELEASE_ASSIGNMENT` → `REQUIRE_APPROVAL`;
- F13 `AUTO_ASSIGN` → `BLOCK`.

**PASS.**

## Registry

Active tools = 6:
- `intelligence.get`;
- `intelligence.explain`;
- `policy.release.probe`;
- `policy.auto_assign.probe`;
- `proposal.release`;
- `f16.email.context.preview`.

Active governed agents = 6:
- KronIA;
- Dante;
- Nico;
- Valentina;
- León;
- Sofía.

All registered agents use `execution_mode=SHADOW`; all tools are `READ|PROPOSE`. Registry constraints reject RAW_SQL/AUTO_APPROVE/AUTO_ASSIGN/TRANSFER as tool authority.

## Security

All six F15 tables:
- RLS enabled;
- 0 browser policies;
- anon SELECT/INSERT/UPDATE/DELETE = false;
- authenticated SELECT/INSERT/UPDATE/DELETE = false.

Internal F15 RPCs are private from anon/auth. The only browser callable F15 RPC is `aos_cia_kronia_admin_gateway_v1`, which validates the existing CIA ADMIN session token server-side. Invalid token → `UNAUTHORIZED`; controlled valid-token QA → PASS.

Append-only guard test on tool-call audit → `PASS_APPEND_ONLY`.

### Legacy raw SQL finding/remediation

Baseline `aos_execute_agent_query(text)` was a broad SECURITY DEFINER dynamic SELECT surface consumed by active legacy agents. Disabling it immediately would break production cron.

F15 replaced arbitrary query acceptance with `F15_CONFIG_ALLOWLIST_V1`:
- exact-match against an active `aos_agente_tareas` `sql_query`;
- SELECT-only;
- no semicolon/comments;
- meta schemas blocked;
- result capped at 100 rows;
- statement timeout 3s;
- anon/auth cannot INSERT/UPDATE/DELETE task definitions.

Negative arbitrary query → `QUERY_NOT_ALLOWLISTED`. Existing exact configured query → PASS.

This is a compatibility hardening boundary, not a claim that all legacy KronIA K1/K2/K7/K8 security debt is closed.

## Governed orchestration smoke

Recommendation used: `cc1e9462-8d53-452a-9229-27a48ec1dbb9` (`FOLLOWUP_RECOVERY`, score 93, HIGH, sample 14, AGING), with no active assignment.

Controlled calls:
1. KronIA `intelligence.get` → SUCCEEDED, 321.359 ms;
2. Nico `intelligence.explain` → SUCCEEDED, 42.791 ms;
3. Sofía `policy.release.probe` → SUCCEEDED, REQUIRE_APPROVAL, executed=false;
4. KronIA `policy.auto_assign.probe` → SUCCEEDED, BLOCK, executed=false;
5. Valentina `f16.email.context.preview` → SUCCEEDED, `send_allowed=false`, `clinical_features_used=false`;
6. KronIA `proposal.release` → correctly BLOCKED `NO_ACTIVE_ASSIGNMENT_CONTEXT`.

Operational residue after smoke:
- assignments = 0;
- requests = 0;
- routing events = 0;
- F15 runs = 6;
- F15 tool calls = 6;
- F15 proposals = 0;
- auto_execute calls/proposals = 0.

The six F15 audit rows are intentional evidence, not operational residue.

## Negative tests

PASS:
- invalid agent → `AGENT_NOT_FOUND`;
- Nico → `proposal.release` → `TOOL_NOT_ALLOWED_FOR_AGENT`;
- RAW SQL tool → `TOOL_NOT_FOUND`;
- invalid ADMIN token → `UNAUTHORIZED`;
- arbitrary legacy query → `QUERY_NOT_ALLOWLISTED`;
- proposal without current F9 ownership → BLOCK;
- AUTO_ASSIGN policy → BLOCK.

## Performance

`EXPLAIN (ANALYZE, BUFFERS)` of `aos_cia_kronia_f16_readiness_v1()`:
- execution ≈ **318.946 ms**;
- shared hit blocks 3,568;
- shared reads 0;
- target interactive <1.5 s → PASS.

Controlled tool calls: ~40.9–321.4 ms observed. PASS.

## Replayability

Live migration ledger expected and verified:
- `20260814184100_cia_phase15_kronia_governed_schema_v1.sql`;
- `20260814184200_cia_phase15_kronia_registry_seed_v1.sql`;
- `20260814184300_cia_phase15_kronia_orchestration_contracts_v1.sql`;
- `20260814184400_cia_phase15_legacy_agent_query_guard_v1.sql`;
- `20260814184500_cia_phase15_admin_readiness_v1.sql`.

Git filenames match the live ledger versions/names 1:1.

## Output F15 → F16

Live `aos_cia_kronia_f16_readiness_v1()` after smoke:
- `ok=true`;
- `ready_for_f16=true`;
- `status=READY_GOVERNED_ORCHESTRATION`;
- 6 tools / 6 agents;
- 0 bad tools / agents / missing tool references;
- 5 successful tool calls;
- 0 auto_execute calls;
- 0 auto_execute proposals;
- browser direct F15 table access false;
- legacy compatibility allowlist active;
- `RELEASE_ASSIGNMENT=REQUIRE_APPROVAL`;
- `AUTO_ASSIGN=BLOCK`.

**PASS. F15 is ready to enter PR/CI/staging gate.**
