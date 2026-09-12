# ASCENDA CONVERSATIONS — CONV-L0 AUDIT CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L0 #504  
**Audit date:** 2026-09-11 America/Lima  
**Governance main:** `81e3e5559b4427dcada03ecb0fc03203ecf0a478`  
**Production runtime SHA audited:** `60fd6b260c8abb4d71c8375f490ee05ef63252c3`  
**Production deployment audited:** Railway `d943ec4c-06fe-4ee6-8b27-4138c98422f4` · SUCCESS  
**Mutation policy:** read-only production discovery; no autonomous activation; no destructive migration.

## Executive finding

The current WhatsApp problem is not primarily data volume, Meta capability or missing business intelligence. It is **runtime and authority fragmentation**.

ASCENDA already has useful canonical assets: conversation/message persistence, idempotency, identity bridges, governed pricing, booking, consent/STOP, attribution and a usable operator panel. However, routine WhatsApp traffic currently crosses a deep local-proxy chain and responsibilities are duplicated across layers.

The replacement should therefore **extract and consolidate**, not rewrite all business truth.

## 1. Current production runtime topology

Railway starts:

```
server-phase-s-f17.js
  -> server-phase-s.js
       -> server-f17.js      [inserted by outer spawn rewrite]
            -> server-f5.js
                 -> server-wa4.js
                      -> server-wa3-v2.js
                           -> server-wa3.js
                                -> server-wa2.js
                                     -> server-f4.js
                                          -> server-phase2.js
                                               -> server.js
```

Important implementation fact:
`server-phase-s-f17.js` monkey-patches child-process spawn so the `server-f5.js` child requested by Phase S becomes `server-f17.js`. Most wrappers start a child HTTP server on another local port and proxy unmatched traffic inward.

### Consequence

A simple request can cross multiple HTTP/process boundaries before reaching its owner. Each wrapper can add buffering, auth, DB work, failure modes and logging. This architecture made incremental safety additions possible, but is not an acceptable final conversational hot path.

**L0 decision:** runtime wrapper topology = **REPLACE**, progressively, behind compatibility routes.

## 2. Current inbound WhatsApp path

A real Meta POST `/webhook` currently traverses:

```
Meta
 -> F17 webhook wrapper
    -> WA4 webhook wrapper
       -> WA3-v2 proxy
          -> WA3 proxy
             -> WA2 proxy
                -> F4 webhook handler
                   -> persist/normalize core inbound
       <- WA4 observes inner success and enqueues L10 bridge
 <- F17 observes inner success, re-parses/reconciles channel evidence and triggers push
```

Three layers materially participate in the same inbound event:

1. **F4** verifies/persists core webhook behavior.
2. **WA4** reuses the successful inbound to drive L10 autonomous bridge work.
3. **F17** re-parses the webhook for CIA/provider reconciliation and push notification dispatch.

### Risk

- provider ACK is coupled to a deep synchronous proxy chain;
- duplicate parsing/normalization exists;
- channel evidence, conversation persistence, autonomy and notification concerns are mixed;
- an inner slowdown can hold outer provider response;
- debugging a single inbound requires tracing several processes.

**Target:** one Meta Channel Gateway verifies, normalizes and durably accepts once, then emits internal events. Conversation, push, attribution and AI consume the normalized event asynchronously where safe.

## 3. Current outbound provider boundaries

There are multiple Meta dispatch implementations.

### Human send

Panel:
`POST /api/wa3/conversations/:id/send`

WA3:
- authorizes through `aos_wa3_human_send_authorize_v1`;
- reserves idempotency in `aos_wa_outbound_requests_v1`;
- directly calls Meta Graph `/messages`;
- persists accepted outbound into messages/events/routing events.

### Autonomous send

WA4 L10 bridge:
- produces suggestion;
- invokes inner `/api/wa/auto-send`;
- F4 applies L4/L8 authority;
- F4 directly calls Meta Graph.

### Additional legacy/provider surface

F17 also governs `/api/wa/send`; F4 also exposes `/api/wa/send` and `/api/wa/status`.

### L0 decision

Provider dispatch must have **one physical boundary** in CONV-L1:
`MetaCloudAdapter.dispatch()`.

Human/AI/template/campaign callers may have different authorization policies but must converge on the same provider adapter, error taxonomy, idempotency contract and status reconciliation.

## 4. Panel / browser call graph

### Native panel startup

`wa-native-panel.js` starts with parallel requests:

- `GET /api/phase-s/status`
- `GET /api/wa3/bootstrap`
- `GET /api/wa3/inbox?limit=120`
- admin additionally probes `GET /api/wa3/provider-health`.

Selected conversation:
- `GET /api/wa3/conversations/:id/messages?limit=250`.

Writes include:
- route;
- release;
- mode;
- human send.

### High-frequency polling still present

`wa-native-panel.js` runs an inbox heartbeat every **2.5 seconds** while visible.

Each tick refreshes the inbox; if last-message identity/count/time changed it also reloads the selected timeline.

`wa-shell-integration.js` sends agent presence every **30 seconds**, plus focus/online/visibility events, with a 10-second burst guard.

`wa-multiagent-final-panel.js` now uses adaptive queue/team refresh after PR #501:
- ~8s healthy;
- 12s after >=1.2s;
- 20s after >=2.5s;
- 30s on failure.

### Compensatory cache layer

`wa-performance-hardening.js` wraps browser fetch and coalesces/caches:
- inbox: 8s visible TTL;
- queue: 12s;
- team: 20s;
- selected messages: 5s;
- hidden: 60s;
- exponential failure backoff.

This cache is useful as an incident guard, but it is architectural evidence that the browser still asks for data too frequently.

**L0 decision:** fixed inbox polling + cache compensation = **REPLACE** in L2 with event-driven invalidation/delivery plus bounded fallback refresh.

## 5. Supabase structural inventory

Current production data volume is tiny:

| Relation | Approx size | Estimated rows |
|---|---:|---:|
| `aos_wa_conversations_v1` | 224 kB | 2 |
| `aos_wa_messages_v1` | 216 kB | 21 estimate; live count 45 at baseline |
| `aos_wa_events_v1` | 200 kB | 91 |
| `aos_wa_channel_aliases_v1` | 128 kB | 3 |
| `aos_wa_routing_events_v1` | 112 kB | 135 |
| other control/bridge/audit relations | <= 96 kB each | small |

There are currently:
- **94** `aos_wa*` functions;
- **56** marked `SECURITY DEFINER`;
- 9 directly executable by `anon`;
- 9 directly executable by `authenticated` in the inspected privilege snapshot.

This count is not itself a vulnerability. It is evidence of a large API/control surface that L0/L1-L4 must reduce and review.

### Key useful indexes already exist

Messages:
- unique `provider_message_id`;
- unique `idempotency_key`;
- conversation/time;
- status/time;
- automatic-send subset;
- channel identity indexes.

Conversations:
- unique conversation key;
- address;
- state/time;
- owner/time;
- handoff queue partial index;
- unread partial index.

Assignments:
- one-current-assignment unique partial index;
- owner/state/time;
- box/state/time.

**Conclusion:** poor behavior is not caused by missing basic indexing or large WhatsApp tables.

## 6. DB pressure evidence

Historical `pg_stat_statements` shows the dominant WhatsApp pressure is high-frequency orchestration, not conversation-table scans.

| Function / relation | Calls | Total DB time | Mean | Max |
|---|---:|---:|---:|---:|
| `aos_wa3_actor_v1` | 17,608 | ~1,289.8 s | 73 ms | 2.78 s |
| `aos_wa3_agent_presence_touch_v1` | 10,762 | ~763.4 s | 71 ms | 5.33 s |
| `aos_wa3_queue_summary_v1` | 1,309 | ~144.6 s | 110 ms | 4.62 s |
| `aos_wa3_effective_presence_v2` | 2,178 | ~54.5 s | 25 ms | 2.21 s |
| `aos_wa4a_knowledge_search_v3` | 37 | ~51.6 s | **1.39 s** | 4.39 s |
| base conversations access | 1,917 | ~7.8 s | ~4 ms | 1.41 s |
| base assignments access | 1,090 | ~3.2 s | ~3 ms | 128 ms |
| base box/member reads | ~1.7k each | low | ~4–6 ms | <252 ms |

### Safe L0 EXPLAIN measurements

Read-only representative queries produced:

- queue summary: **~209 ms**, 1,074 shared-hit blocks;
- effective presence: **~4 ms**, 175 shared-hit blocks;
- governed toxin fast-price RPC: **~132 ms**, 1,089 shared-hit blocks, 4 rows;
- generic `aos_wa4a_knowledge_search_v3`: **~1,125 ms**, 4,575 shared-hit blocks, **2,012 temp blocks written**, 8 rows.

### Interpretation

1. Actor/session verification and presence writes create the largest accumulated cost.
2. Queue/team orchestration is acceptable only at bounded cadence, not as high-frequency UI chatter.
3. Generic knowledge search is not suitable as a routine prerequisite for simple structured questions.
4. Narrow canonical tools are materially better than generic preloaded/search-heavy knowledge paths.
5. Base conversation/message tables are not the bottleneck.

## 7. Authority/dependency map

### Identity

Canonical patient identity remains existing Revenue/Patients authority. WhatsApp channel aliases are evidence/reachability, not a second person master.

### Conversation state

Today conversation state is held in `aos_wa_conversations_v1`, with assignment/routing state across:
- conversations;
- assignments;
- routing events;
- boxes/members/presence.

Target must define **one ConversationCore authority** and treat event/history tables as ledger, not competing state owners.

### Provider authority

Today provider logic is duplicated across WA3/F4/F17-related paths.

Target: one `MetaCloudAdapter`.

### AI authority

Today WA4 copilot + deterministic price/booking paths + L10 bridge + L4/L8 controls collectively govern autonomy.

Target: one AgentRuntime invokes deterministic tools; one outbound policy gate authorizes dispatch.

### Business truth

Must remain external to Conversations Core:
- patient/identity;
- catalog/pricing;
- Agenda/booking;
- sales/revenue;
- attribution;
- consent/privacy evidence.

## 8. Useful trigger contracts to preserve or port

Current DB triggers include:

- message -> conversation binding/projection;
- new-conversation routing;
- channel-address compatibility;
- identity-event application;
- append-only guards for authority/audit ledgers;
- governed booking guard on `aos_agenda_citas`;
- outbound recipient normalization.

These are not automatically legacy debt. L0 classifies each by contract:
- preserve invariant if still needed;
- move implementation only when the new owner can prove parity.

## 9. Protected-module baseline

Captured at L0 start/read-only baseline:

- Leads: 7,192
- Agenda: 3,283
- Ventas: 1,449
- Llamadas: 38,851
- Pacientes: 7,812
- WA conversations: 2
- WA messages: 45
- active DB queries >2s: 0
- active DB queries >5s: 0
- deadlocks counter: 0 in current DB stats snapshot.

These counts are comparison fingerprints, not business completion metrics.

## 10. Background/runtime noise observed

Current Railway runtime repeatedly logs:
- `[S15] notification pump fail-open F17_RPC_UNAVAILABLE`;
- occasional template-cache shape error.

This is not the root cause of conversational intelligence, but it is runtime noise and shared-background debt. It must not be pulled into the new conversational hot path. Background work must remain independently degradable.

## 11. Root causes established by L0

### RC-1 — Deep proxy/process chain
Too many local server boundaries for one conversation.

### RC-2 — Duplicate provider responsibilities
Human and autonomous sends use different Meta implementations.

### RC-3 — Webhook work occurs at multiple layers
Provider response depends on nested proxy success while other concerns re-process the event.

### RC-4 — Polling drives avoidable DB work
The primary inbox still polls every 2.5 seconds.

### RC-5 — Authentication/presence are called far more often than business value requires
Actor/presence dominate accumulated WA DB execution.

### RC-6 — Generic knowledge retrieval is too expensive for structured sales facts
Simple price/fact turns must use narrow tools, not generic search first.

### RC-7 — Safety/business logic and transport evolved together
Correct controls exist, but are distributed across wrappers and are hard to reason about as one product.

## 12. L0 architectural conclusion

ASCENDA does **not** need a third-party inbox to solve these problems.

It needs consolidation into:

```
Panel
  -> Conversation API / event stream
      -> ConversationCore
          -> AgentRuntime
          -> ToolGateway
          -> Outbox
      -> MetaCloudAdapter
```

The existing system contains enough correct domain authority to make this an extraction/migration project rather than a greenfield rewrite.

No legacy component is deleted during L0.
