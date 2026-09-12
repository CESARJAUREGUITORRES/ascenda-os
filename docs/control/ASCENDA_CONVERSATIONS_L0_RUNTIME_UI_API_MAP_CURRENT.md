# ASCENDA CONVERSATIONS — CONV-L0 RUNTIME & UI/API MAP CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L0 #504  
**Production runtime audited:** `60fd6b260c8abb4d71c8375f490ee05ef63252c3`

## A. Process/proxy chain

| Layer | Child | WhatsApp responsibility observed |
|---|---|---|
| `server-phase-s-f17.js` | Phase S | outer WA/F17 composition via spawn rewrite |
| `server-phase-s.js` | F17 effectively | phase status, WA3 bootstrap aggregation |
| `server-f17.js` | F5 | webhook post-processing, channel reconciliation, push, legacy send/templates |
| `server-f5.js` | WA4 | unrelated F5 features + WA transit |
| `server-wa4.js` | WA3-v2 | copilot/booking/L10 webhook bridge |
| `server-wa3-v2.js` | WA3 | queue/team/presence/stability |
| `server-wa3.js` | WA2 | inbox/routing/human send/provider health |
| `server-wa2.js` | F4 | inbox/timeline/cost projection |
| `server-f4.js` | Phase2 | webhook persistence, provider sends, typing, L4 boundary |
| `server-phase2.js` | server.js | Auth V3/2FA |
| `server.js` | terminal | core ASCENDA APIs |

## B. Provider ingress routes

### `GET /webhook`

Owned at F4 for Meta verification. Outer wrappers proxy it until F4.

**Target owner:** MetaCloudAdapter.

### `POST /webhook`

Observed execution:

1. F17 buffers raw request and proxies inward.
2. WA4 buffers raw request and proxies inward.
3. WA3-v2 proxies.
4. WA3 proxies.
5. WA2 proxies.
6. F4 verifies/normalizes/persists inbound/status.
7. WA4, after inner success, performs L10 bridge enqueue/process.
8. F17, after inner success, performs channel reconciliation and push dispatch.

**Target:** one ingress handler:
`verify -> normalize -> durable acceptance -> ACK -> internal event consumers`.

No AI/revenue/push work should be required before the provider ACK except facts required for durable acceptance/security.

## C. Panel startup requests

Current `wa-native-panel.js`:

| Request | Purpose | Current call behavior | Target |
|---|---|---|---|
| `GET /api/phase-s/status` | phase/runtime state | once on panel mount | merge into bounded panel bootstrap if still useful |
| `GET /api/wa3/bootstrap` | actor, routing, boxes/members/users/control | once on mount + after mutations | replace with Conversation bootstrap snapshot |
| `GET /api/wa3/inbox?limit=120` | conversation list | mount + every 2.5s heartbeat + after writes | event-driven invalidation + bounded page fetch |
| `GET /api/wa3/provider-health` | Meta state | admin mount/probe/error | keep capability under ChannelAdapter health |
| `GET /api/wa3/conversations/:id/messages?limit=250` | timeline | selection + when heartbeat detects change + after send | cursor timeline + MESSAGE_ADDED event |

## D. Panel writes

| Route | Owner today | Target contract |
|---|---|---|
| `POST /api/wa3/conversations/:id/send` | WA3 direct Meta sender | Conversation command -> OutboundPolicy -> MetaCloudAdapter |
| `POST /api/wa3/conversations/:id/route` | WA3 RPC wrapper | ConversationCore.assign |
| `POST /api/wa3/conversations/:id/release` | WA3 RPC wrapper | ConversationCore.release |
| `POST /api/wa3/conversations/:id/mode` | WA3 RPC wrapper | ConversationCore.setControlMode |
| `POST /api/wa3/claim-next` | WA3-v2/WA3 compatibility | ConversationCore.claim |
| `POST /api/wa3/presence` | WA3-v2 | presence lease/update |

## E. Supervisor/queue requests

Current multiagent enhancer:

| Route | Current cadence | DB owner |
|---|---:|---|
| `GET /api/wa3/queue-summary` | adaptive 8/12/20/30s | `aos_wa3_queue_summary_v1` |
| `GET /api/wa3/team-summary` | adaptive 8/12/20/30s for admins | several box/member/presence reads |
| `POST /api/wa3/presence` | ~30s + focus/online/visibility events | presence touch/effective presence |
| `POST /api/wa3/claim-next` | user action | claim RPC |

Target: queue/team changes delivered as lightweight revisions/events; fetch summary on material change/user action rather than periodic global refresh.

## F. WA4 / legacy AI routes

| Route | Current role | L0 disposition |
|---|---|---|
| `GET /api/wa4/health` | AI/provider model readiness | PORT to AgentRuntime health |
| `GET /api/wa4/bootstrap` | AI control/models | REPLACE with Agent config/status API |
| `POST /api/wa4/control` | copilot config | PORT necessary config only |
| `POST /api/wa4/conversations/:id/suggest` | current Copilot response generation | REPLACE with AgentRuntime.runTurn |
| `POST /api/wa4/conversations/:id/book` | booking commit wrapper | PORT into ToolGateway |
| `POST /api/wa4/conversations/:id/rebook` | rebook wrapper | PORT into ToolGateway |
| `/api/wa5/conversations/:id/*` | L5 booking helpers | PORT canonical booking tool contracts |
| L10 bridge internal calls | autonomous orchestration | RETIRE after new AgentRuntime parity |

## G. F4 provider routes

| Route | Current role | L0 disposition |
|---|---|---|
| `POST /api/wa/send` | legacy human/governed Meta send | replace with MetaCloudAdapter |
| `POST /api/wa/auto-send` | L4 autonomous Meta send | replace with unified dispatch + OutboundPolicy |
| `POST /api/wa/auto-typing` | provider typing/read marker | port into MetaCloudAdapter |
| `GET /api/wa/status` | config/L4 status | split Channel health and OutboundPolicy health |

## H. F17 WhatsApp routes

| Route | Current role | L0 disposition |
|---|---|---|
| `POST /webhook` | post-inner reconciliation + push | replace synchronous interception; event consumer |
| `POST /api/wa/send` | governed legacy send overlay | retire after unified dispatch |
| `/api/f17/whatsapp/templates` | template provider helper | port template sync contract |
| notification/push endpoints | operator notification system | keep outside Conversation hot path |

## I. Browser timers and event hooks

### Primary inbox
- fixed `2.5s` visible inbox heartbeat.
- focus and visibility trigger forced refresh.
- selected message timeline is re-read when inbox projection changes.

### Presence
- `30s` timer.
- extra focus/online/visibility writes.
- 10s burst guard.
- 120s auth-denial backoff.

### Supervisor
- adaptive one-shot timer:
  - 8s healthy;
  - 12s latency >=1.2s;
  - 20s latency >=2.5s;
  - 30s failure.
- an enhancer bootstrap timer at 100ms exists only until panel hook is attached, max ~60 tries.

### Fetch hardening
- response cache/coalescing wraps inbox/queue/team/timeline.
- failure backoff.
- hidden page 60s behavior.

## J. L0 endpoint consolidation target

Target public/internal shape is intentionally smaller:

```text
POST /channels/meta/webhook
GET  /conversations/bootstrap
GET  /conversations
GET  /conversations/:id/messages
POST /conversations/:id/messages
POST /conversations/:id/assignment
POST /conversations/:id/handoff
POST /conversations/:id/control
GET  /conversations/events          [or Realtime/SSE equivalent]

GET  /channels/meta/health
GET  /channels/meta/templates
POST /channels/meta/templates/sync  [admin]

internal:
ConversationCore.acceptInbound
AgentRuntime.runTurn
ToolGateway.execute
OutboundPolicy.authorize
MetaCloudAdapter.dispatch
JobOutbox.claim/complete
```

Exact URL naming may change in L1/L2, but **ownership boundaries may not** without reopening the frozen contracts.

## K. Explicit anti-duplication rule

During migration, compatibility routes may proxy to the new owner. They may not retain a second implementation.

Examples:
- old WA3 human-send route may become a compatibility adapter to ConversationCore;
- old provider-health route may proxy to MetaCloudAdapter health;
- old WA4 suggest route may be shadow-only then retired.

A compatibility route is acceptable. A second sender/state master is not.
