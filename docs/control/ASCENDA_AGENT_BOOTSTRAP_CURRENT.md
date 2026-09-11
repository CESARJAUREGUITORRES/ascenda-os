# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured:** 2026-09-11 America/Lima  
**Canonical baseline at pivot:** `main@60fd6b260c8abb4d71c8375f490ee05ef63252c3`  
**ACTIVE PROGRAM:** `CONV-001 — ASCENDA CONVERSATIONS CORE V1`  
**ACTIVE HIGH/CRITICAL LOCK:** `CONV-L0 #504` after governance merge  
**PARENT:** `#502`  
**LEGACY WA-L10 #456:** `FROZEN · SAFE-OFF · EVIDENCE ONLY`  
**AUTONOMOUS CANARY:** `NOT AUTHORIZED`

## Mandatory bootstrap before any write

Read in this order:

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/MEMORY_CURRENT.md`;
6. `docs/control/ASCENDA_CONVERSATIONS_CORE_V1_ROADMAP_CURRENT.md`;
7. `docs/control/ASCENDA_CONVERSATIONS_L0_READINESS_CURRENT.md`;
8. `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`;
9. exact GitHub `main` + active CONV PR/head;
10. Railway exact deploy state if runtime is involved;
11. live Supabase safety/performance readbacks if DB/runtime is involved;
12. Notion WhatsApp Control Maestro CURRENT callout.

Historical WA docs remain evidence/reference only and never override these CURRENT files + live runtime evidence.

## Binding architecture decision

ASCENDA Conversations Core V1 is a native ASCENDA product. Chatwoot, Fazer clinical-agent implementations, LangGraph and Meta examples are engineering blueprints, not mandatory runtime dependencies. n8n, Dify, Typebot and Evolution are not required components.

Preserve existing canonical business authorities:
- patient/identity;
- catalog/pricing;
- agenda/availability/booking;
- sales/revenue/commissions;
- attribution;
- consent/STOP/privacy/audit;
- Auth V3 / 2FA.

The panel remains ASCENDA-owned and is progressively rewired to the new core.

## Target hot path

`1 inbound -> load bounded conversation state -> 1 reasoning cycle -> 0–2 tools -> 1 outbound`.

No wrapper-chain expansion. No global data preload. No browser fan-out. No direct LLM->Meta authority. No direct LLM->SQL authority.

## Migration vocabulary

Every legacy component is exactly one of:
- `KEEP`
- `PORT`
- `REPLACE`
- `RETIRE`
- `DELETE`

Nothing is deleted until replacement parity + no runtime references/callers + CI migration + production telemetry + rollback evidence.

## Loop order

- `CONV-L0 #504` — Freeze / inventory / extraction map / benchmark freeze.
- `CONV-L1 #505` — Native Meta Channel Gateway.
- `CONV-L2 #506` — Conversation Core + panel transport.
- `CONV-L3 #507` — Sales Agent Runtime.
- `CONV-L4 #508` — Business Tools + bounded RAG.
- `CONV-L5 #509` — Booking + media + templates.
- `CONV-L6 #510` — Follow-up + hot leads + campaign worker.
- `CONV-L7 #511` — Quality benchmark + separately authorized real canary.
- `CONV-L8 #512` — Cutover + legacy retirement + replication.

Do not implement a later loop because an earlier issue exists. Each loop must close its exit gate and owner/governance boundaries remain binding.

## Specialist operating roles

These are review/execution roles, not extra production agents:

1. **Architecture / Extraction** — maps dependencies, authorities and migration classification.
2. **Meta Channel** — provider contracts, webhook/media/template/status behavior.
3. **Database / Performance** — Supabase/Postgres query plans, RLS, indexes, hot-path budget.
4. **Conversation / Sales UX** — naturalness, memory, objection handling, next-best action.
5. **Booking / Business Tools** — canonical tools and transactional correctness.
6. **Security / Privacy** — consent, STOP, identity, clinical escalation, secrets.
7. **Quality / Evals** — benchmark corpus, trace/tool grading, regression evidence.
8. **Release / Reliability** — exact-head, Railway, canary, rollback, cross-module regression.

No multi-agent runtime swarm is assumed. Start with one conversational agent + deterministic tools; add specialist runtime agents only if benchmark evidence proves a need.

## Available execution skills

Use when relevant:
- Supabase skill for any Supabase/Auth/RLS/schema work; check current docs/changelog before implementation.
- Supabase Postgres Best Practices for query/schema/performance design.
- Railway skill for deployment/configuration/logs/health.
- Notion Research Documentation for multi-source synthesis.
- Notion Spec-to-Implementation for plan/task synchronization.
- OpenAI Agents SDK skill only for an isolated prototype/eval if explicitly selected later; it is not a current production architecture dependency.

## Reliability gates

Preserve the global doctrine:
- `CODE PASS != DEPLOY PASS != PROD PASS`;
- no timeout inflation;
- no heavy analytics on critical reads/writes;
- scoped/indexed reads;
- no duplicate legacy+new execution;
- cold-path measurements matter;
- background jobs retreat under degradation;
- cross-module checks include Agenda, Call Center, Marketing, Sales/Commissions, Patients/Identity and shared Supabase pressure.

## Legacy production safety

Until CONV-L7 and a fresh owner authorization:
- `mode=AUTO_OFF`;
- kill switch engaged;
- autonomous reply/send/routing disabled;
- human send remains available;
- active autonomous allowlist = 0;
- WA-L10 #456 is frozen except P0 security/privacy/data-loss/production-break fixes.

## Product Definition of Done

CI green is necessary, not sufficient.

The product closes only when the real panel supports fast natural conversation, governed prices/promotions/media/booking, immediate human takeover, safe follow-up/campaign behavior, no material ASCENDA performance regression, and a second company can be onboarded through configuration/adapters without a source fork.
