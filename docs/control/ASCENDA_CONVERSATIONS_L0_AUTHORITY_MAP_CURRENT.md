# ASCENDA CONVERSATIONS — CONV-L0 AUTHORITY MAP CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L0 #504  
**Purpose:** prevent duplicate truth/authority during migration.

## Binding principle

The new Conversations Core may own **conversation orchestration**. It may not become a second CRM, patient master, price master, Agenda, sales ledger, consent ledger or attribution authority.

## Current -> target authority map

| Domain | Current authoritative source / contract | Current duplication risk | Target owner |
|---|---|---|---|
| authenticated ASCENDA actor | Auth V3 / `aos_app_actor_v3`, WA actor bridge | actor RPC repeated across wrappers | existing Auth; Conversation API consumes one server-resolved ActorContext |
| tenant/company | current Zi Vital installation/context | not yet explicit in every WA row/API | TenantContext additive mapping; no big-bang current DB rewrite |
| channel account | Railway/Meta configuration + phone/WABA refs | config checks split across WA3/F4/F17 | MetaCloudAdapter/ChannelAccount config |
| provider transport | WA3 + F4 + F17 legacy paths | **high**: more than one sender/provider implementation | **MetaCloudAdapter only** |
| inbound normalization | F4 + WA4/F17 re-processing | **high** | MetaCloudAdapter emits normalized event once |
| conversation projection | `aos_wa_conversations_v1` | state also inferred by assignments/routing/AI flags | ConversationCore current projection; existing table evolved during migration |
| message ledger | `aos_wa_messages_v1` | provider/status/audit also in other ledgers | keep durable message ledger; event ledger references it |
| current human owner | conversation owner + active assignment | two representations must remain consistent | ConversationCore owns transition; projection + immutable event |
| routing history | `aos_wa_routing_events_v1` | none material if kept history-only | immutable audit |
| team/box membership | boxes + members + users | repeated bootstrap reads | keep source; produce bounded read model |
| presence | presence table + effective presence over users/team state | high write frequency | ConversationCore presence lease/read model |
| autonomous ownership/mode | conversation state + L4 control + AI/routing control + L10 scope | **high** | conversation mode + OutboundPolicy; legacy L4/L10 retired after parity |
| outbound idempotency | `aos_wa_outbound_requests_v1` + message unique keys | human/autonomous implementations differ | unified Outbox reservation contract |
| patient identity | Revenue/Patients canonical identity + governed aliases | risk if channel address treated as person | **existing canonical identity only** |
| channel identity/reachability | WA aliases/address compatibility | must not become patient master | keep as channel evidence |
| catalog/service/product | canonical catalog | generic knowledge layer can duplicate facts | ToolGateway reads canonical catalog |
| current price | price authority / canonical catalog evidence | prompt/RAG copies can become stale | structured `get_prices` only |
| promotions | governed current promo/business source | conversational copy can invent/age | structured `get_promotions` |
| location/hours/payment | canonical business configuration/data | prompt duplication | structured business-facts tool |
| availability | Agenda availability authority | AI can otherwise invent slot | `get_availability` tool only |
| booking / rebook | existing governed booking/rebook core + Agenda trigger | multiple wrapper endpoints | ToolGateway wraps same canonical core |
| sales/revenue | existing Sales/Revenue ledgers | must not block reply path | existing authority; async signal/read tools only |
| campaign attribution | existing strong-key attribution | webhook/channel parsing duplicated | event consumer writes existing attribution evidence |
| consent / STOP | L8 consent/eligibility evidence + inbound STOP semantics | legacy L4/L8 distributed | OutboundPolicy consumes preserved consent authority |
| templates | Meta approved templates + current helper paths | provider/template logic fragmented | MetaCloudAdapter sync + local read model |
| media | provider media + ASCENDA governed media metadata | fragmented | ToolGateway chooses governed media; MetaCloudAdapter transports |
| AI model | WA4 model/provider config | model health tied to wrapper | AgentRuntime model adapter |
| semantic business knowledge | WA4A knowledge fabric | expensive generic retrieval overused | bounded semantic retrieval only |
| clinical safety | current safety/escalation rules | can be spread across prompt/guards | AgentPolicy + mandatory handoff classes |
| follow-up/campaign job state | fragmented/planned/legacy flows | no one clear native owner | JobOutbox |
| provider delivery status | WA events/messages status callbacks | multiple reconciliation layers | MetaCloudAdapter status -> ConversationCore apply once |
| cost intelligence | L7 views/events | can become hot-path enrichment | keep cold-path telemetry |
| audit | multiple append-only ledgers | many phase-specific tables | preserve history; converge future events into explicit event taxonomy |

## Duplicate authority prohibitions

CONV-L1+ may not introduce:
- new patient/customer master;
- copied/stored “current price” owned by the agent;
- alternate booking table;
- alternate conversation table used as a second live master;
- separate AI sender and human sender;
- separate provider status engines;
- another consent master;
- another campaign-attribution master.

A cache/read model is allowed only when:
1. its source authority is explicit;
2. freshness/revision is defined;
3. it cannot accept authoritative writes that bypass the source.

## Current state duplication to eliminate

### Provider state
WA3 health/send versus F4 send/typing versus F17 template/send/channel evidence.

**Resolution:** MetaCloudAdapter.

### Conversation control
Conversation state + assignments + routing control + AI control + L4 mode + L10 scope.

**Resolution:** ConversationCore owns conversation/HUMAN-AI state; OutboundPolicy owns global/tenant send policy. History remains events.

### Knowledge/pricing
Generic WA4A knowledge can surface structured catalog facts while price authority separately governs current money.

**Resolution:** money/promo/availability always tools; semantic retrieval cannot override.

### Browser state
Native inbox polling + multiagent polling + fetch-hardening caches each infer freshness.

**Resolution:** server revision/event stream is freshness source.

## Cutover invariant

At every migration slice exactly one implementation is WRITE-authoritative for each capability.

Shadow mode may compare outputs, but the shadow implementation:
- cannot send provider messages;
- cannot mutate booking/customer/sales state;
- cannot create a second current owner;
- cannot amplify production DB load materially.
