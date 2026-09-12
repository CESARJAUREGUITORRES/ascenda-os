# ASCENDA CONVERSATIONS CORE V1 — ROADMAP CURRENT

**Program:** `CONV-001`  
**Owner issue:** `#502`  
**Pivot date:** 2026-09-11 America/Lima  
**Source main at pivot:** `60fd6b260c8abb4d71c8375f490ee05ef63252c3`  
**Legacy WA-L10:** FROZEN SAFE-OFF  
**Goal:** native, fast, governed, multi-company conversational sales platform integrated with ASCENDA.

## 1. Product North Star

ASCENDA Conversations must let a customer start on WhatsApp, receive a useful natural response in seconds, ask about services/prices/promotions/locations/payment, send bursts/audio/media, receive governed media, progress naturally to availability/booking, move to a human at any point, receive eligible follow-ups/templates, and generate hot-lead/booking/revenue signals.

The same engine must onboard another company through configuration/adapters rather than a source fork.

## 2. What remains authoritative

KEEP:
- ASCENDA panel shell and useful inbox/lead UX;
- canonical patient/identity authorities;
- catalog and price authority;
- agenda/availability/booking;
- sales/revenue/attribution;
- consent/STOP/privacy/audit;
- Auth V3 / 2FA and existing global ASCENDA security boundaries.

External repositories are blueprints only:
- Chatwoot -> Meta transport/media/templates/inbox/handoff patterns;
- Fazer clinical sales agent -> burst/debounce/lock/tool/handoff patterns;
- LangGraph -> state/decision/tool/observe/respond execution model;
- Meta official examples -> webhook/provider/template contracts.

No mandatory Chatwoot, n8n, Dify, Typebot or Evolution runtime.

## 3. Target architecture

```
ASCENDA Panel
   |
   | Conversation API + event stream
   v
ASCENDA Conversations Core
   |-- canonical conversation state
   |-- HUMAN / AI ownership
   |-- idempotency / single flight
   |-- short-term memory
   |-- Sales Agent
   |-- safety / handoff
   |-- job/outbox worker
   |
   +-- ChannelAdapter
   |      +-- MetaCloudAdapter
   |      +-- future Web/Instagram/Messenger adapters
   |
   +-- ToolGateway
          +-- customer
          +-- prices
          +-- promotions
          +-- locations/payment
          +-- availability
          +-- booking
          +-- media
          +-- hot-lead / revenue signals
```

The new hot path must not inherit the historical server-wrapper chain.

## 4. Hard invariants

- tenant-aware from day 1;
- one normalized inbound envelope;
- one conversation state authority;
- one outbound dispatch boundary;
- one job/outbox mechanism;
- event-driven UI where possible, bounded adaptive fallback only;
- routine turn target: `1 inbound -> 1 reasoning cycle -> 0–2 tools -> 1 outbound`;
- no global business-data preload;
- no invented price/promo/slot/booking state;
- secrets stay server-side;
- human takeover and STOP/consent always win;
- regex may support safety/STOP, but does not become the primary conversation brain;
- no destructive legacy removal before parity + zero callers + rollback evidence.

## 5. Migration classification

Every existing component must become exactly one of:

- `KEEP`: remains canonical.
- `PORT`: contract is good; implementation moves into the new core.
- `REPLACE`: same requirement, simpler new implementation.
- `RETIRE`: no longer needed after cutover.
- `DELETE`: only after runtime references and telemetry prove it is dead.

Deletion gate:
1. replacement PASS;
2. no current runtime imports/routes/calls;
3. CI references migrated;
4. production telemetry shows no callers;
5. rollback path exists;
6. separate controlled deletion PR.

## 6. Execution loops

### CONV-L0 — Freeze, inventory, benchmark

Deliver:
- exact WA runtime dependency graph;
- wrapper/import/route graph;
- UI endpoint/call-frequency map;
- Supabase hot-query/RPC map;
- current state/authority duplication map;
- KEEP/PORT/REPLACE/RETIRE table;
- blueprint comparison;
- 30 sales benchmark transcripts + 10 failure/adversarial scenarios.

Exit:
- no ambiguous target authority;
- no unknown hot-path dependency;
- deletion candidates identified but untouched;
- target API contracts frozen.

### CONV-L1 — Native Meta Channel Gateway

Implement one `MetaCloudAdapter`:
- webhook verification/signature;
- normalized inbound/status envelopes;
- text/media/template/interactive send;
- typing;
- current provider health;
- template sync/read model;
- normalized error taxonomy;
- idempotency;
- no AI dependency.

Exit:
real test number proves inbound, outbound text, image/media, approved template and provider status reconciliation.

### CONV-L2 — Conversation Core + panel transport

Implement:
- canonical conversation lifecycle;
- ownership and human takeover;
- assignment/handoff;
- durable message/event ledger;
- single-flight/idempotency;
- lightweight inbox summary;
- event-driven panel delivery;
- no fixed high-frequency polling.

Exit:
panel is operational for human messaging with real WhatsApp traffic; zero duplicates; protected ASCENDA modules show no material DB-pressure regression.

### CONV-L3 — Sales Agent Runtime

Implement:
- bounded short-term memory;
- burst/debounce semantics;
- provider-independent LLM adapter;
- tool selection/calling;
- one useful response by default;
- persona/tone;
- objection handling and next-best action;
- deterministic safety/handoff boundaries.

Exit:
offline/shadow benchmark passes conversation quality before autonomous provider send.

### CONV-L4 — Business Tools + bounded knowledge

Initial tools:
- `get_customer_context`
- `get_prices`
- `get_promotions`
- `get_locations_payment_methods`
- `get_availability`
- `prepare_booking`
- `confirm_booking`
- `get_media`
- `handoff`
- `create_hot_lead_signal`

Knowledge policy:
- structured current facts -> tools;
- semantic commercial knowledge -> bounded retrieval;
- patient-specific/clinical-sensitive -> policy/human.

Exit:
no hallucinated business facts; routine turn stays inside agreed DB/tool budget and latency SLO.

### CONV-L5 — Booking, media, templates

Prove:
`info -> price/promo -> objection -> intent -> location/date/time -> real availability -> explicit confirmation -> booking`.

Add governed image/video/document delivery and approved-template catalog.

Exit:
real end-to-end test passes conversation, media, booking, human takeover and template continuity.

### CONV-L6 — Follow-up, hot lead and campaigns

Implement native job/outbox worker:
- follow-up;
- abandoned hot lead;
- appointment reminders;
- reactivation;
- approved-template campaigns;
- consent/eligibility/rate controls;
- delivery/read/reply/conversion metrics.

No n8n required.

Exit:
bounded campaign and follow-up reconcile to conversation -> booking -> revenue signals.

### CONV-L7 — Benchmark + real canary

Required:
- 30/30 commercial scenarios have no critical failure;
- 10/10 failure/adversarial scenarios fail safely;
- duplicate/unauthorized sends = 0;
- invented price/promo/availability = 0;
- STOP/human takeover = 100%;
- provider/local reconciliation PASS;
- target p50 useful reply <= 2.5s;
- target p95 useful reply <= 5s under test load;
- no material protected-module regression.

Only after this is one-conversation autonomous CANARY eligible.

### CONV-L8 — Cutover, retirement, replication

- route Zi Vital to Conversations Core;
- maintain rollback/shadow window;
- deprecate replaced legacy endpoints;
- prove zero callers;
- retire/delete in controlled PRs;
- freeze tenant configuration contract;
- dry-deploy second company without source fork.

Exit:
Zi Vital operational on new core and second tenant reproducible by configuration/adapters.

## 7. Definition of Done

The project is not complete because tests are green. It is complete when:

- real conversation is fast, natural and context-aware;
- pricing/promo/media/booking use governed truth;
- operator takeover/release is immediate;
- follow-ups/hot leads/templates/campaigns work safely;
- panel remains responsive;
- WhatsApp load does not degrade other ASCENDA modules;
- provider failures fail fast and visibly;
- another company can be onboarded without custom-forking the conversation engine.

## 8. Performance budget

Initial target:
- webhook ACK <= 300 ms when durable acceptance succeeds;
- lightweight conversation/state load <= 150 ms target;
- routine business tool <= 300 ms target;
- useful reply p50 <= 2.5 s, p95 <= 5 s;
- 0–2 business tools per routine turn;
- one outbound per semantic turn by default;
- zero unbounded retries or browser polling loops.

## 9. Current binding state

Legacy autonomous production:
`AUTO_OFF · KILL ON · AI SEND OFF · AUTO ROUTING OFF · ALLOWLIST 0`.

CONV-L1 #505 is CLOSED / PROVIDER CERTIFIED. CONV-L2 #506 is the only authorized HIGH/CRITICAL implementation lane under RUN UNTIL BLOCKED to the next bounded human-messaging/panel proof. Autonomous AI remains SAFE-OFF and L3 is not authorized.
