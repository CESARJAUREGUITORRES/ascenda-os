# ASCENDA CONVERSATIONS — CONV-L0 BLUEPRINT PARITY CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L0 #504  
**Purpose:** compare mature patterns against current ASCENDA and decide `ADOPT | ADAPT | REJECT`.

External projects are references, not runtime dependencies.

## Decision rubric

A pattern is accepted only if it improves at least one:
- correctness;
- latency;
- provider compatibility;
- failure isolation;
- observability;
- testability;
- tenant reuse;
- operator UX;

without introducing unacceptable:
- runtime dependency;
- license restriction;
- duplicate authority;
- DB pressure;
- security/privacy risk;
- operational surface.

## 1. Chatwoot

Repository: `chatwoot/chatwoot`  
Observed current branch: `develop`  
Observed activity: active in 2026.  
License finding: core content outside separately licensed enterprise/third-party areas is MIT Expat according to root LICENSE; file-level review remains required before any direct code reuse.

### Relevant provider implementation

`app/services/whatsapp/providers/whatsapp_cloud_service.rb` concentrates:
- `send_message`;
- `send_template`;
- template sync/fetch;
- provider config validation;
- media URL/attachment handling;
- text send;
- attachment send;
- interactive text send;
- provider error handling.

Other relevant boundaries:
- incoming WhatsApp cloud message service;
- one-off WhatsApp campaign service;
- WhatsApp webhook controller;
- inbox/assignment/message APIs.

### Parity table

| Pattern | ASCENDA today | Decision | Target |
|---|---|---|---|
| one WhatsApp Cloud provider service | Meta send duplicated in WA3/F4 plus F17 legacy surfaces | **ADOPT** | single MetaCloudAdapter |
| provider config validation | WA3 provider health + F4 config checks split | **ADOPT** | one health/freshness contract |
| text/media/template/interactive behind same provider | current human send mostly text/interactive; media/template fragmented | **ADOPT** | adapter methods in L1 |
| webhook controller separate from business agent | webhook crosses many wrappers and triggers several concerns | **ADOPT** | gateway accepts once, emits event |
| campaign service separate from live conversation send | campaign/follow-up vision not yet consolidated | **ADOPT** | JobOutbox/Campaign worker L6 |
| generic Chatwoot inbox as product UI | ASCENDA already has integrated Revenue Inbox and business context | **REJECT runtime** | keep ASCENDA panel |
| Chatwoot database/contact model as CRM master | would duplicate ASCENDA patient/CRM truth | **REJECT** | canonical ASCENDA authorities remain |

**Conclusion:** Chatwoot is the strongest blueprint for **provider/channel engineering**, not for replacing ASCENDA.

## 2. Fazer clinical seller

Repository: `fazer-ai/ia-vendedora-clinica-langgraph`  
Observed structure: TypeScript clinical sales agent over Chatwoot/LangGraph.  
License finding: no root LICENSE was observed during L0. Therefore **do not copy source code**. Architectural ideas only unless licensing is clarified separately.

### Relevant graph pattern

Its main agent graph visibly separates:
- enqueue inbound;
- debounce wait;
- stale-message check;
- per-inbox/conversation lock;
- message-burst collection;
- referenced-message retrieval;
- agent invocation with tools;
- persistent history;
- check for newer messages before send;
- text/audio send;
- failure fallback;
- lock release.

Follow-up runs in a separate graph, not inside the live reply path.

### Parity table

| Pattern | ASCENDA today | Decision | Target |
|---|---|---|---|
| burst collection before reasoning | each inbound can independently drive bridge work | **ADAPT** | measured semantic-turn debounce |
| stale-turn rejection | legacy bridge mostly idempotency/provider based | **ADOPT** | cancel superseded agent turn |
| per-conversation lock | current L10 job/claim controls exist but tied to legacy canary | **ADAPT** | generic ConversationCore lease |
| one agent + tools | WA4 mixes deterministic intents, search, booking and response logic | **ADOPT** | one AgentRuntime first |
| persistent bounded history | current messages exist; prompt assembly is complex | **ADOPT** | bounded memory from conversation ledger |
| check new inbound before send | not a single universal pre-send step | **ADOPT** | mandatory stale/human recheck |
| follow-up separated from reply path | follow-up is fragmented/planned | **ADOPT** | JobOutbox L6 |
| fixed external project's debounce/lock durations | unproven for Zi Vital | **REJECT exact values** | benchmark local values |
| Chatwoot API dependency | not needed | **REJECT** | native ConversationCore |
| direct source copy | no observed license | **REJECT** | conceptual reimplementation only |

## 3. LangGraph

Repository: `langchain-ai/langgraph`  
License observed: MIT.  
Project is active and purpose-built for resilient/stateful agents.

### Useful concepts

- explicit state;
- graph transitions;
- tool execution;
- persistence/checkpoints;
- interrupt/human-in-loop;
- durable recovery.

### Parity table

| Pattern | Decision | Reason |
|---|---|---|
| `state -> decide -> tool -> observe -> respond` | **ADOPT** | clean mental/runtime model |
| explicit interrupt before sensitive action | **ADAPT** | booking/handoff confirmation boundaries |
| checkpointing | **ADAPT** | only if native ledger + job state is insufficient |
| framework as mandatory dependency | **UNDECIDED / default REJECT** | add only if L3 benchmark proves value |
| multi-agent graph from day 1 | **REJECT** | complexity without demonstrated need |

**L3 rule:** implement to the frozen AgentRuntime contract. A framework can be swapped underneath later.

## 4. Meta official WhatsApp API examples

Repository: `fbsamples/whatsapp-api-examples`  
Observed current activity: 2026.  
License permits use/copy/modify for Facebook web-services/API integration subject to Meta/Facebook platform policy and attribution terms.

Examples include:
- webhook receive;
- webhook signature validation;
- media;
- message templates;
- interactive messages;
- message statuses;
- ecommerce scenarios.

### Decision

**ADOPT official provider contracts**, revalidated against current Meta documentation before L1 implementation/canary.

Meta samples are provider truth reference; they are not an application architecture.

## 5. KronIA inside ASCENDA

Current internal pattern:
`UI -> /api/kronia/chat -> selective context/business calls -> model -> answer`.

### What it proves

- a short cognition path can feel substantially more fluid;
- data can be requested on demand;
- not every possible business fact must be preloaded before a response.

### What cannot be copied blindly

- privileged internal/admin assumptions;
- action authority unsuitable for an external WhatsApp customer;
- lack of Meta service-window/template/provider constraints.

### Decision

**ADAPT simplicity and selective context loading**, preserve Conversations-specific safety.

## 6. n8n

### Value
Strong general-purpose workflow automation.

### Rejection as mandatory dependency

For ASCENDA's replicable product:
- another runtime;
- another DB/state model;
- another deployment/backup surface;
- workflow versioning outside the core source;
- tenant operational dependency.

**Decision:** **REJECT mandatory runtime**. Build bounded native JobOutbox/worker. Integrations can be optional in the future.

## 7. Dify

Useful agent/RAG workbench.

Would duplicate:
- prompt/orchestration control;
- retrieval surfaces;
- operational state;
- another admin product.

**Decision:** **REJECT current runtime dependency**. Research reference only.

## 8. Typebot

Useful visual deterministic conversation flows.

Current objective is a natural tool-using sales agent rather than a scripted form tree.

**Decision:** **REJECT current dependency**.

## 9. Evolution API / non-official channel abstraction

ASCENDA already targets official Meta Cloud API.

An additional provider abstraction product would add another failure/upgrade boundary while the target ChannelAdapter can own portability itself.

**Decision:** **REJECT**.

## 10. Accepted blueprint principles

The L0 accepted set is:

1. **One provider adapter** owns Meta transport.
2. **Webhook accepts once** and emits normalized internal events.
3. **Conversation core separate from provider and agent.**
4. **One agent first**, with typed deterministic tools.
5. **Per-conversation single flight / stale-turn suppression.**
6. **Short measured burst coalescing**, not copied magic constants.
7. **Structured facts via tools**, semantic knowledge only when needed.
8. **Follow-up/campaign work outside live reply path.**
9. **Human takeover is an interrupt**, not a suggestion.
10. **Provider, conversation, business and AI authority are separate contracts.**
11. **ASCENDA owns the operator UI and business model.**
12. **Frameworks are replaceable implementation details.**

## 11. Rejected architecture patterns

Do not introduce in L1-L6 without reopening architecture:

- Chatwoot as required production middle layer;
- n8n as required job engine;
- a second CRM/patient/contact master;
- a second price/booking authority;
- another direct Meta client outside ChannelAdapter;
- multiple autonomous agent runtimes responding to the same conversation;
- universal RAG before every response;
- browser high-frequency polling as primary real-time design;
- direct model access to SQL/provider APIs.
