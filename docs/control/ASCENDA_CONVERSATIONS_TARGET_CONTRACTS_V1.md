# ASCENDA CONVERSATIONS — TARGET CONTRACTS V1

**Program:** CONV-001 #502  
**Frozen by:** CONV-L0 #504  
**Purpose:** define implementation boundaries before CONV-L1 code.

These are architecture contracts, not a final language/package choice.

## 1. Tenant / channel context

Every channel event and conversation action must carry a server-resolved tenant/channel context.

```ts
type TenantId = string
type ConversationId = string

interface ChannelContext {
  tenantId: TenantId
  channelAccountId: string
  provider: 'META_WHATSAPP'
  businessAccountRef?: string
  phoneNumberRef?: string
}
```

Rules:
- no provider secret in this object;
- browser cannot assert tenant/provider authority;
- Zi Vital-specific behavior is configuration/tool policy, not engine code;
- current single-clinic production may map to one tenant during migration without mutating the whole legacy DB into SaaS.

## 2. Normalized inbound event

The provider adapter outputs one normalized event.

```ts
interface NormalizedInboundMessage {
  eventId: string
  providerMessageId: string
  channel: ChannelContext
  occurredAt: string
  receivedAt: string

  sender: {
    channelAddressType: 'PHONE' | 'BSUID' | 'OTHER'
    channelAddress: string
    displayName?: string
  }

  message: {
    type: 'TEXT' | 'IMAGE' | 'AUDIO' | 'VIDEO' | 'DOCUMENT' | 'INTERACTIVE' | 'UNKNOWN'
    text?: string
    mediaRef?: string
    replyToProviderMessageId?: string
  }

  referral?: {
    sourceType?: string
    sourceId?: string
    campaignRef?: string
    adRef?: string
  }

  rawEvidenceRef: string
}
```

Rules:
- normalization happens once;
- raw provider payload is not passed throughout application code;
- sensitive raw payload retention is minimized and governed;
- `providerMessageId` is idempotency authority for inbound provider messages;
- unknown message types remain observable and fail safely.

## 3. Normalized provider status event

```ts
interface NormalizedProviderStatus {
  eventId: string
  channel: ChannelContext
  providerMessageId: string
  status: 'ACCEPTED' | 'SENT' | 'DELIVERED' | 'READ' | 'FAILED'
  occurredAt: string
  error?: {
    code: string
    subcode?: string
    category:
      | 'AUTH'
      | 'PERMISSION'
      | 'RECIPIENT'
      | 'TEMPLATE'
      | 'RATE'
      | 'POLICY'
      | 'TRANSIENT'
      | 'UNKNOWN'
  }
  pricingEvidenceRef?: string
}
```

Status application must be monotonic/valid and idempotent. Out-of-order callbacks cannot regress a terminal state incorrectly.

## 4. ChannelAdapter

```ts
interface ChannelAdapter {
  verifyWebhook(input: {
    headers: Record<string,string>
    rawBody: Uint8Array
  }): Promise<{ ok: true } | { ok: false; reason: string }>

  normalizeWebhook(rawBody: Uint8Array): Promise<{
    messages: NormalizedInboundMessage[]
    statuses: NormalizedProviderStatus[]
  }>

  health(ctx: ChannelContext): Promise<ProviderHealth>

  sendText(cmd: SendTextCommand): Promise<DispatchReceipt>
  sendMedia(cmd: SendMediaCommand): Promise<DispatchReceipt>
  sendTemplate(cmd: SendTemplateCommand): Promise<DispatchReceipt>
  sendInteractive(cmd: SendInteractiveCommand): Promise<DispatchReceipt>
  typing(cmd: TypingCommand): Promise<TypingReceipt>

  syncTemplates(ctx: ChannelContext): Promise<TemplateSyncResult>
}
```

### Provider health contract

```ts
interface ProviderHealth {
  ok: boolean
  checkedAt: string
  credentialState: 'READY' | 'INVALID' | 'UNKNOWN'
  assetState: 'READY' | 'INVALID' | 'UNKNOWN'
  permissionsState: 'READY' | 'INVALID' | 'UNKNOWN'
  diagnosis?: string
}
```

A stale health result cannot authorize provider dispatch by itself.

## 5. Outbound command / receipt

All provider sends converge on one dispatch boundary.

```ts
interface OutboundBase {
  tenantId: TenantId
  conversationId: ConversationId
  channelAccountId: string
  idempotencyKey: string
  origin: 'HUMAN' | 'AI' | 'TEMPLATE_JOB' | 'CAMPAIGN'
  correlationId: string
}

interface SendTextCommand extends OutboundBase {
  text: string
  replyToProviderMessageId?: string
}

interface SendMediaCommand extends OutboundBase {
  media: {
    kind: 'IMAGE' | 'AUDIO' | 'VIDEO' | 'DOCUMENT'
    mediaRef: string
    caption?: string
  }
}

interface SendTemplateCommand extends OutboundBase {
  templateName: string
  language: string
  variables: Record<string,string>
  mediaRef?: string
}

interface DispatchReceipt {
  accepted: boolean
  state: 'ACCEPTED' | 'FAILED' | 'AMBIGUOUS'
  providerMessageId?: string
  providerError?: {
    code: string
    category: string
  }
  retrySafe: boolean
  latencyMs: number
}
```

Rules:
- caller never invokes Meta directly;
- an ambiguous timeout is not automatically retry-safe;
- the same idempotency key cannot create two provider dispatches;
- raw provider secrets/payloads are not returned to callers.

## 6. ConversationCore

```ts
interface ConversationCore {
  acceptInbound(event: NormalizedInboundMessage): Promise<InboundAcceptance>
  applyProviderStatus(event: NormalizedProviderStatus): Promise<void>

  getConversation(id: ConversationId, actor: ActorContext): Promise<ConversationSnapshot>
  listInbox(query: InboxQuery, actor: ActorContext): Promise<InboxPage>
  getTimeline(id: ConversationId, cursor: TimelineCursor, actor: ActorContext): Promise<TimelinePage>

  assign(cmd: AssignCommand, actor: ActorContext): Promise<ConversationSnapshot>
  claim(cmd: ClaimCommand, actor: ActorContext): Promise<ConversationSnapshot>
  release(cmd: ReleaseCommand, actor: ActorContext): Promise<ConversationSnapshot>
  requestHuman(cmd: HandoffCommand): Promise<ConversationSnapshot>
  setControlMode(cmd: ConversationModeCommand, actor: ActorContext): Promise<ConversationSnapshot>
}
```

### Canonical conversation state

Initial target states:

```text
NEW
AI_ACTIVE
HUMAN_REQUESTED
HUMAN_ACTIVE
WAITING_CUSTOMER
CLOSED
```

State transitions must be explicit and audited.

Human ownership rule:
**HUMAN_ACTIVE / explicit takeover always outranks pending AI work.**

## 7. Conversation event ledger

Every material state transition writes an immutable event.

```ts
interface ConversationEvent {
  eventId: string
  tenantId: string
  conversationId: string
  type:
    | 'INBOUND_ACCEPTED'
    | 'OUTBOUND_RESERVED'
    | 'OUTBOUND_ACCEPTED'
    | 'OUTBOUND_FAILED'
    | 'OWNER_ASSIGNED'
    | 'OWNER_RELEASED'
    | 'HANDOFF_REQUESTED'
    | 'MODE_CHANGED'
    | 'TOOL_CALLED'
    | 'AI_DECISION'
    | 'STOP_OBSERVED'
    | 'BOOKING_CONFIRMED'
    | 'FOLLOWUP_SCHEDULED'
  occurredAt: string
  actorRef?: string
  correlationId: string
  evidence: Record<string,unknown>
}
```

Sensitive content must be minimized/redacted according to event type.

## 8. Panel event stream

The browser should not require a 2.5-second inbox poll to feel live.

```ts
interface PanelEvent {
  seq: string
  tenantId: string
  type:
    | 'CONVERSATION_CHANGED'
    | 'MESSAGE_ADDED'
    | 'ASSIGNMENT_CHANGED'
    | 'PRESENCE_CHANGED'
    | 'PROVIDER_HEALTH_CHANGED'
  conversationId?: string
  occurredAt: string
  revision?: number
}
```

Preferred transport in L2:
- Supabase Realtime or server push/SSE/WebSocket based on a bounded technical spike;
- event contains identifiers/revisions, not full privileged records;
- client re-fetches scoped canonical data when needed;
- fallback refresh is bounded and visibility-aware, never 2.5s global polling.

## 9. Operator presence contract

Presence is a lease, not a permanent stream of expensive writes.

```ts
interface PresenceLease {
  actorId: string
  state: 'ONLINE' | 'AWAY' | 'OFFLINE'
  leaseUntil: string
  updatedAt: string
}
```

L2 must benchmark an update cadence that materially reduces current presence-touch volume while preserving routing semantics.

## 10. AgentRuntime

Start with one agent.

```ts
interface AgentRuntime {
  runTurn(input: AgentTurnInput): Promise<AgentTurnResult>
}

interface AgentTurnInput {
  tenantId: string
  conversationId: string
  semanticTurnId: string
  inboundMessages: BoundedConversationMessage[]
  memory: BoundedMemory
  allowedTools: ToolDescriptor[]
  policy: AgentPolicy
}

interface AgentTurnResult {
  outcome: 'RESPOND' | 'HANDOFF' | 'NO_ACTION'
  response?: {
    text?: string
    media?: MediaSuggestion[]
  }
  toolTrace: ToolCallTrace[]
  confidence?: number
  handoffReason?: string
  usage?: ModelUsage
}
```

Rules:
- one reasoning cycle by default;
- new messages arriving before send can invalidate/stale the turn;
- per-conversation single-flight prevents concurrent competing AI responses;
- message bursts may be coalesced through a measured bounded debounce;
- framework dependency is optional; the contract is framework-independent.

## 11. Semantic-turn concurrency

Required behavior adapted from mature agent patterns:

```
inbound accepted
  -> enqueue semantic turn
  -> short measured burst window
  -> acquire conversation lease/lock
  -> confirm no newer turn superseded it
  -> run agent
  -> recheck human takeover + newer inbound
  -> authorize outbound
  -> reserve/send once
  -> release lock
```

A fixed long debounce from another project must not be copied. L3 benchmark chooses the smallest useful window.

## 12. ToolGateway

```ts
interface ToolGateway {
  execute<TInput,TOutput>(
    toolName: ToolName,
    input: TInput,
    ctx: ToolContext
  ): Promise<ToolResult<TOutput>>
}
```

Initial typed tools:

```text
get_customer_context
get_prices
get_promotions
get_locations_payment_methods
get_availability
prepare_booking
confirm_booking
rebook_booking
cancel_booking
get_media
handoff
create_hot_lead_signal
```

Each tool contract declares:
- auth scope;
- tenant scope;
- read/write;
- timeout budget;
- idempotency requirement;
- source authority;
- sensitive fields;
- failure behavior.

No generic `execute_sql` tool exists for the conversational agent.

## 13. Structured truth versus bounded retrieval

### Structured tool authority

Use tools for:
- price;
- promotion;
- location;
- hours;
- payment methods;
- availability;
- patient/appointment state;
- booking;
- current media metadata.

### Semantic retrieval

Use bounded retrieval for:
- service explanation;
- commercial FAQ;
- non-patient-specific treatment description;
- objection-supporting approved business knowledge.

A generic semantic search must not be a mandatory step for every turn.

### Clinical boundary

Patient-specific diagnosis, contraindication or clinical prescription routes to governed safe response/handoff, not open-ended tool/RAG invention.

## 14. OutboundPolicy

```ts
interface OutboundPolicy {
  authorize(cmd: OutboundIntent): Promise<PolicyDecision>
}

interface PolicyDecision {
  allowed: boolean
  reason: string
  evidenceRefs: string[]
  constraints?: {
    messageType?: string[]
    templateRequired?: boolean
    maxProviderMessages?: number
  }
}
```

Inputs include:
- HUMAN/AI ownership;
- consent/STOP;
- service-window/template eligibility;
- duplicate/idempotency state;
- provider health/freshness;
- rate/budget limits;
- safety outcome.

The model cannot override a DENY.

## 15. JobOutbox

Async work does not run inside the message response path.

```ts
interface ConversationJob {
  id: string
  tenantId: string
  conversationId?: string
  type:
    | 'FOLLOW_UP'
    | 'HOT_LEAD_REMINDER'
    | 'APPOINTMENT_REMINDER'
    | 'POST_VISIT'
    | 'REACTIVATION'
    | 'CAMPAIGN_TEMPLATE'
  executeAt: string
  state: 'PENDING' | 'CLAIMED' | 'DONE' | 'FAILED' | 'CANCELLED'
  attempts: number
  idempotencyKey: string
  payloadRef: string
}
```

Rules:
- native ASCENDA worker; no n8n requirement;
- claim with lease;
- bounded retry;
- provider ambiguity reconciled before retry;
- STOP/eligibility rechecked at execution time;
- job success cannot clear another subsystem's degradation state.

## 16. Latency / request budgets

Routine turn target:
- webhook durable acceptance/ACK <= 300ms where architecture permits;
- scoped conversation state load <= 150ms target;
- narrow structured business tool <= 300ms target;
- useful reply p50 <= 2.5s;
- useful reply p95 <= 5s benchmark load;
- 0–2 business tools per routine turn;
- one provider outbound per semantic turn by default.

Current generic knowledge search (~1.1s read-only test, >4.5k shared blocks, temp writes) cannot be a default prerequisite.

## 17. Compatibility/migration rule

During L1-L6, legacy panel/routes may coexist behind adapters, but:

- no request is dispatched twice;
- one side is authoritative for each capability;
- shadow reads must not create duplicate background load;
- runtime flag/cutover must be reversible;
- legacy tables remain available for evidence/history;
- no big-bang schema rewrite.

## 18. Contract freeze rule

Any L1+ proposal that adds:
- a second provider client;
- a second conversation master;
- a second patient/price/booking authority;
- global data preload;
- browser high-frequency polling;
- direct LLM->SQL or LLM->Meta;

is rejected unless CONV-001 owner explicitly reopens this architecture decision with evidence.
