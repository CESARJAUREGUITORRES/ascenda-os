# ASCENDA CONVERSATIONS — CONV-L0 READINESS CURRENT

**Program:** #502  
**Immediate loop:** #504  
**State:** PREPARED / AWAITING EXECUTION CONFIRMATION  
**Production:** legacy autonomy SAFE-OFF

## Purpose

This file is the execution launchpad for CONV-L0. It prevents another cycle of patching before the target architecture and migration boundaries are proven.

## L0 work packages

### A — Runtime graph

Inventory:
- server entrypoint and wrapper/import chain;
- all WhatsApp routes;
- all providers/senders;
- all webhook/status handlers;
- current browser scripts;
- timers/polling/MutationObservers;
- current background jobs;
- current ownership/state authorities.

Output: exact graph + file/route references.

### B — Data and pressure graph

Inventory per endpoint/turn:
- RPC/REST calls;
- tables/views/functions;
- p50/p95/max latency where evidence exists;
- call count;
- cold vs warm behavior;
- pg_stat_statements hotspots;
- EXPLAIN ANALYZE/BUFFERS for safe representative reads;
- fan-out or repeated authorization/summary reads.

Output: `critical | acceptable | cold-path | retire` classification.

### C — Legacy extraction matrix

For every WA component record:
`component | responsibility | callers | authority | target owner | KEEP/PORT/REPLACE/RETIRE | dependency | deletion gate`.

No DELETE classification is executed during L0.

### D — Blueprint parity review

Compare only the relevant engineering contracts:
- Chatwoot: Meta Cloud provider, media, template sync, status normalization, inbox/handoff;
- Fazer clinical seller: debounce, per-conversation locking, memory, tool boundary, follow-up/handoff;
- LangGraph pattern: state -> decide -> tool -> observe -> respond;
- Meta official sample/contracts: webhook security, provider payloads, templates/media/status.

For each pattern record: `adopt | adapt | reject` and why.

### E — Frozen benchmark

Create 30 commercial scenarios + 10 failure/adversarial/provider scenarios before L3 implementation.

Each case defines:
- starting state;
- inbound sequence;
- expected tool calls;
- forbidden tool calls;
- facts that must be preserved;
- handoff/STOP expectations;
- output-quality rubric;
- latency target;
- state mutation expectation.

### F — Contract freeze

Before L1 code, freeze interfaces for:
- `ChannelAdapter`;
- normalized inbound/status envelope;
- `ConversationCore`;
- ownership/handoff;
- `ToolGateway`;
- model adapter;
- job/outbox;
- panel event stream.

## Prepared skill/tool stack

### Required for execution
- GitHub connector — source truth, PRs, issues, exact-head evidence.
- Supabase skill + connector — schema/runtime truth and safe SQL readbacks.
- Supabase Postgres Best Practices — query/index/concurrency review.
- Railway skill + connector — exact deployment/config/logs/health.
- Notion Research Documentation — synthesize historical decisions without allowing Notion to override runtime truth.
- Notion Spec-to-Implementation — keep roadmap/tasks synchronized.

### Optional later
- OpenAI Agents SDK — only as an isolated L3 prototype/eval harness if selected after L0; not a required runtime dependency.
- Sentry — only if ASCENDA adopts it as production observability; do not add merely for this program.

### Not required
- Chatwoot runtime;
- n8n;
- Dify;
- Typebot;
- Evolution API;
- external orchestration swarm.

## Agent/reviewer model

Use specialist review roles, not a distributed runtime swarm:
- Architecture;
- Meta;
- DB/Performance;
- Conversation/Sales;
- Booking/Tools;
- Security/Privacy;
- Evals/QA;
- Release/Reliability.

Every material design decision needs:
1. owner of the decision;
2. evidence/source;
3. performance impact;
4. migration impact;
5. rollback/compatibility statement.

## L0 exit checklist

- [ ] exact runtime graph complete;
- [ ] exact UI/API call graph complete;
- [ ] exact DB pressure graph complete;
- [ ] all current state/authority owners identified;
- [ ] KEEP/PORT/REPLACE/RETIRE matrix complete;
- [ ] no destructive delete performed;
- [ ] blueprint parity review complete;
- [ ] 40-case benchmark frozen;
- [ ] target contracts frozen;
- [ ] protected-module regression baseline captured;
- [ ] owner receives L0 closeout and explicitly authorizes L1 implementation.

## Stop conditions

Stop and return to owner if:
- a second canonical authority is discovered for identity/pricing/booking/conversation state;
- safe migration requires data destruction;
- a blueprint license/contract would create unacceptable product dependency;
- proposed hot path exceeds the performance budget by design;
- change would require bypassing Auth/2FA/RLS/consent;
- exact-current main or runtime drifts during certification.

## Performance target carried forward

Routine conversational semantic turn:
- 1 inbound;
- 1 reasoning cycle;
- 0–2 business tools;
- 1 outbound by default;
- p50 useful response target <= 2.5 s;
- p95 useful response target <= 5 s under benchmark load;
- zero duplicate/unauthorized sends.
