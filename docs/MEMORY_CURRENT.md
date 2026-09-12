# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-09-11 America/Lima  
**ACTIVE PROGRAM:** `CONV-001 — ASCENDA CONVERSATIONS CORE V1`  
**MAIN AT L0 TECHNICAL CLOSEOUT:** `60b987f75e5efe8906c2eed0d8c560ff449de3b7`  
**ACTIVE HIGH/CRITICAL GATE:** `NONE`  
**LAST CLOSED:** `CONV-L0 #504`  
**NEXT ELIGIBLE:** `CONV-L1 #505 · NOT STARTED · NOT AUTHORIZED`  
**PARENT:** `#502`  
**LEGACY WA-L10 #456:** `FROZEN · SAFE-OFF · EVIDENCE ONLY`  
**AUTONOMOUS CANARY:** `NOT AUTHORIZED`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
7. `docs/control/ASCENDA_CONVERSATIONS_CORE_V1_ROADMAP_CURRENT.md`;
8. `docs/control/ASCENDA_CONVERSATIONS_L0_READINESS_CURRENT.md`;
9. `docs/control/ASCENDA_CONVERSATIONS_BLUEPRINT_REGISTRY_CURRENT.md`;
10. `docs/control/ASCENDA_CONVERSATIONS_BENCHMARK_V1.md`;
11. `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`;
12. exact GitHub + Supabase + Railway/runtime evidence;
13. Notion Control Maestro / CONV execution Skill.

Historical WA docs/chats remain evidence only.

## Why the pivot happened

Real WA canary work proved that the existing stack had accumulated too many coupled wrappers, repeated authorization/data reads and UI/provider/runtime compensation layers before the core commercial conversation experience was consistently reliable.

The owner approved a consolidation architecture:
- preserve good ASCENDA assets;
- stop feature-patching the legacy hot path;
- use mature external projects as blueprints;
- rebuild one small native Conversations Core behind the existing ASCENDA panel;
- prove product quality before general autonomous production.

## Target product

A reusable multi-company conversational sales engine that supports:
- WhatsApp first, future channels through adapters;
- natural context-aware sales conversation;
- governed prices/promotions/locations/payment facts;
- media;
- real availability + BOOK/REBOOK;
- human takeover;
- hot-lead signals;
- native follow-up and approved-template campaigns;
- attribution/revenue continuity;
- safe failure and observability.

## Target architecture

`Panel -> Conversation API/Event Stream -> Conversations Core -> {Sales Agent, ChannelAdapter, ToolGateway, Job/Outbox}`.

Routine turn:
`1 inbound -> 1 reasoning cycle -> 0–2 tools -> 1 outbound`.

No global preload. No direct LLM->Meta. No direct LLM->SQL.

## Preserved canonical authorities

- Patient/identity: existing Revenue/Patients.
- Catalog/pricing: existing canonical catalog/price authority.
- Agenda/availability/booking: existing Agenda/booking.
- Sales/revenue/commissions: existing Sales/Revenue.
- Attribution: existing governed attribution.
- Consent/STOP/privacy/audit: existing WA/security foundation.
- Auth/2FA: existing Auth V3 boundaries.

## Migration rule

Each legacy component -> `KEEP | PORT | REPLACE | RETIRE | DELETE`.

DELETE is forbidden during build. It becomes eligible only after replacement parity, zero runtime callers/imports, CI migration, telemetry and rollback evidence.

## Current loop map

- #504 L0 Freeze/Inventory/Extraction/Benchmark — **CLOSED**
- #505 L1 Meta Channel Gateway
- #506 L2 Conversation Core + Panel
- #507 L3 Sales Agent Runtime
- #508 L4 Business Tools + bounded RAG
- #509 L5 Booking/Media/Templates
- #510 L6 Follow-up/Hot Leads/Campaigns
- #511 L7 Benchmark + separately authorized CANARY
- #512 L8 Cutover/Legacy Retirement/Replication

## Skills/tooling prepared

- GitHub connector as code/governance truth.
- Supabase skill/connector.
- Supabase Postgres Best Practices.
- Railway skill/connector.
- Notion Research Documentation.
- Notion Spec-to-Implementation.
- Notion Skill: `ASCENDA CONV-001 — Execution Protocol`.
- OpenAI Agents SDK is optional for isolated L3 prototyping/evals only; not an approved production dependency.

## Blueprint registry

Primary references:
- Chatwoot -> Meta transport/media/templates/inbox/handoff patterns.
- Fazer clinical seller -> burst/debounce/lock/tools/follow-up patterns.
- LangGraph -> state/decision/tool/observe/respond pattern.
- Meta official samples/docs -> provider contract authority.
- KronIA -> internal proof of selective on-demand context.

No external runtime dependency is approved merely because it is a blueprint.

## Reliability / security

Keep global doctrine:
`CODE PASS != DEPLOY PASS != PROD PASS`.

No timeout inflation, heavy global analytics on hot paths, duplicate legacy+new execution, unsafe identity shortcuts, unbounded browser fan-out or secret exposure.

Cross-module regressions always cover Agenda, Call Center, Marketing, Sales/Commissions, Patients/Identity and shared Supabase/background pressure.

## Production safety

Legacy autonomous WA remains:
`AUTO_OFF · KILL ON · AI SEND OFF · AUTO ROUTING OFF · ALLOWLIST 0`.

No real autonomous CANARY before L7 PASS and a fresh explicit owner authorization.

## L0 closeout findings

L0 established that current WhatsApp instability/latency is primarily architectural:
- deep proxy/process chain;
- duplicate provider-send boundaries;
- webhook re-processing across layers;
- 2.5s inbox polling plus compensatory cache;
- high-frequency actor/presence DB work;
- generic knowledge search unsuitable as a routine prerequisite.

Preserved assets include the ASCENDA panel UX, conversation/message ledgers, canonical identity/pricing/Agenda/booking/sales/attribution/consent authorities and key safety/idempotency invariants.

## Immediate next action

Present L0 closeout to the owner. **Do not begin CONV-L1 #505 until separate explicit owner authorization.**
