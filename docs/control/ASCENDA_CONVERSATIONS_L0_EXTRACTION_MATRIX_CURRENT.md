# ASCENDA CONVERSATIONS — CONV-L0 EXTRACTION MATRIX CURRENT

**Program:** CONV-001 #502  
**Loop:** CONV-L0 #504  
**Status:** L0 CLASSIFICATION  
**Rule:** no destructive deletion is authorized by this document.

## Classification vocabulary

- **KEEP** — current authority/asset remains canonical.
- **PORT** — current invariant/contract is retained but implementation moves into the new Core.
- **REPLACE** — requirement stays, current implementation is superseded by a smaller implementation.
- **RETIRE** — becomes dormant after parity/cutover.
- **DELETE** — not eligible in L0; requires the later L8 deletion gate.

## Runtime / transport matrix

| Current component | Current responsibility | Current callers/position | L0 class | Target owner | Migration note |
|---|---|---|---|---|---|
| `server-phase-s-f17.js` | outer bootstrap + spawn rewrite + unrelated PRC bridge | Railway outer runtime | **REPLACE** for WA concern | app composition / stable outer runtime | Do not alter unrelated PRC behavior during CONV extraction. Remove WA-specific spawn indirection only after new core is independently routed. |
| `server-phase-s.js` WA bootstrap interception | WA3 bootstrap/status + shell injection | outer proxy before F17 | **REPLACE** | Conversation API + panel bootstrap | Preserve Auth/session behavior; eliminate WA-specific wrapper ownership after L2. |
| `server-f17.js` WA webhook/send overlay | channel reconciliation, governed legacy send, push | wraps F5 | **PORT + RETIRE** | MetaCloudAdapter + event consumers | Port provider/channel evidence semantics; push becomes async event consumer. Retire WA interception only after L1/L2 parity. |
| `f17-wa-adapter.js` | CIA channel prepare/dispatch/inbound/provider evidence | F17 | **PORT** | channel/audit event adapter | Preserve strong attribution/provider evidence without synchronous webhook coupling. |
| `f17-whatsapp-legacy-gateway.js` | legacy WhatsApp template/provider helper | F17 | **REPLACE** | MetaCloudAdapter template API | One provider client only. |
| `server-f5.js` WA role | mainly wrapper transit toward WA4; F5 owns unrelated historical features | chain | **KEEP unrelated / RETIRE WA transit** | no WA ownership | Never remove F5 business functionality merely to simplify WA. New Conversation routes should bypass only the WA transit once safe. |
| `server-wa4.js` | copilot APIs, L5 helpers, L10 bridge, model health, webhook bridge | wraps WA3-v2 | **REPLACE** | AgentRuntime + ToolGateway + event consumer | Decompose. Keep useful contracts, not wrapper process. |
| `server-wa3-v2.js` | queue/team/presence/claim stability layer | wraps WA3 | **REPLACE** | ConversationCore presence/queue read model | Fold into one API. No nested server. |
| `server-wa3.js` | inbox/routing/ownership/human send/provider health/direct Meta send | wraps WA2 | **PORT + REPLACE** | ConversationCore + MetaCloudAdapter | Port ownership/idempotency semantics; replace direct provider implementation. |
| `server-wa2.js` | inbox/timeline/cost projections | wraps F4 | **PORT + REPLACE** | ConversationCore read model | Preserve useful projections/cost linkage; consolidate endpoints. |
| `server-f4.js` WhatsApp section | core webhook persistence, legacy/human/autonomous sends, typing/status, L4 authority boundary | wraps phase2 | **PORT + REPLACE** | MetaCloudAdapter + OutboxPolicy | Port signature/persistence/authority invariants. Remove duplicate provider client after parity. |
| `server-phase2.js` | Auth V3 / 2FA outer behavior | below F4 | **KEEP** | existing Auth platform | Not owned by Conversations project except compatibility. |
| `server.js` | core ASCENDA APIs including KronIA | bottom runtime | **KEEP** | existing ASCENDA core | Conversations must not rewrite unrelated core. |

## Provider / normalization modules

| Component | Current value | L0 class | Target |
|---|---|---|---|
| `wa-gateway.js` Meta signature verification | strong reusable contract | **PORT** | `MetaCloudAdapter.verifyWebhook()` |
| `wa-gateway.js` inbound extraction/normalization | reusable normalized concepts | **PORT** | normalized ChannelEvent |
| `wa-gateway.js` outbound payload helpers | useful base, incomplete media/template scope | **PORT + EXTEND** | MetaCloudAdapter payload builders |
| WA3 `graphSend` | human Meta send client | **REPLACE** | one MetaCloudAdapter |
| F4 `graphSend` | autonomous/legacy Meta send client | **REPLACE** | same MetaCloudAdapter |
| WA3 provider-health implementation | useful error taxonomy | **PORT** | provider health/freshness API |
| F4 auto-typing provider call | useful behavior | **PORT** | `MetaCloudAdapter.typing()` |
| F17 template listing/provider path | useful capability | **PORT** | template sync/read model |

## Panel / frontend matrix

| Component | Responsibility | L0 class | Target |
|---|---|---|---|
| `wa-native-panel.js` visual workspace | conversation list/timeline/composer/right context | **KEEP UX / REWIRE DATA** | ASCENDA panel on Conversation API |
| `wa-native-panel.js` 2.5s inbox polling | freshness | **REPLACE** | event-driven invalidation + bounded fallback |
| `wa-shell-integration.js` navigation/permission integration | shell mount + panel permissions | **KEEP/PORT** | existing shell with Conversation feature registration |
| `wa-shell-integration.js` presence heartbeat | operator presence | **REPLACE** | lease/event presence with bounded writes |
| `wa-multiagent-final-panel.js` supervisor/inbox UX | filters, owner labels, queue/team productivity | **KEEP UX / PORT** | new read model/event stream |
| adaptive queue/team polling | current incident containment | **RETIRE after L2** | event-driven supervisor updates |
| `wa-performance-hardening.js` fetch cache/coalescer | protects polling fan-out | **RETIRE after L2** | server/event architecture should make shim unnecessary |
| MutationObservers used only for decorative integration | DOM patching | **REPLACE gradually** | explicit component state/rendering where practical |
| Revenue Inbox filters/campaign context | operator value | **KEEP** | panel read model |

## Conversation persistence / routing

| DB asset | Current role | L0 class | Target note |
|---|---|---|---|
| `aos_wa_conversations_v1` | current conversation projection/state | **KEEP then evolve** | Strong candidate for ConversationCore aggregate during migration. Avoid creating a parallel live conversation master. |
| `aos_wa_messages_v1` | durable inbound/outbound ledger | **KEEP** | Preserve provider/idempotency uniqueness. |
| `aos_wa_events_v1` | provider/channel/identity events | **KEEP/PARTITION RESPONSIBILITY** | Continue as audit/evidence source; target normalized event taxonomy. |
| `aos_wa_assignments_v1` | queue/owner assignments | **PORT/EVOLVE** | One ownership authority; history separate from current projection. |
| `aos_wa_routing_events_v1` | append-only ownership/routing history | **KEEP** | Useful audit ledger. |
| `aos_wa_boxes_v1` / members | team/box config | **KEEP** | Reuse unless tenant model requires additive keys later. |
| `aos_wa_agent_presence_v1` | presence projection | **REPLACE semantics / migrate** | Reduce high-frequency writes; preserve compatibility during L2. |
| message bind/project triggers | message -> conversation projection | **PORT/PRESERVE INVARIANT** | New ingress must still atomically bind/project once. |
| auto-route-on-new-conversation trigger | current routing default | **REVIEW / PORT IF NEEDED** | Avoid competing routing authority with new Core. |

## Human operations

| Contract | L0 class | Rationale |
|---|---|---|
| actor/server-side role verification | **KEEP/PORT** | Security boundary is correct; invocation frequency is not. |
| `aos_wa3_human_send_authorize_v1` semantics | **PORT** | Human ownership and send eligibility remain required. |
| route / claim / release / mode semantics | **PORT** | Core operator workflow remains. |
| multiple bootstrap actor rechecks | **REPLACE** | Consolidate one bounded authenticated snapshot per request/session boundary. |
| queue/team RPC polling | **REPLACE read delivery** | Keep business semantics, change delivery/update mechanism. |

## AI / conversation intelligence

| Component | Current role | L0 class | Target |
|---|---|---|---|
| `wa4-copilot.js` | large intent/quality/knowledge/booking response orchestrator | **REPLACE as orchestrator** | Small AgentRuntime + tools |
| deterministic greeting/price/booking draft functions | hard-coded UX fallbacks | **PORT selectively / otherwise RETIRE** | Keep only contractual safety/fast paths demonstrated useful |
| `aos_wa4a_knowledge_search_v3` generic search | broad semantic retrieval | **KEEP cold capability / REMOVE from routine prerequisite** | bounded RAG only when semantic knowledge is actually needed |
| `aos_wa4_toxin_price_fast_v1` | narrow governed structured price tool | **KEEP/GENERALIZE PATTERN** | ToolGateway `get_prices` |
| model health/provider selection | AI dependency health | **PORT** | AgentRuntime model adapter |
| response quality guard ideas | no hallucinated/unsafe output | **PORT as eval/policy** | post-tool safety + eval harness, not giant deterministic conversation tree |
| L10 bridge | event-driven legacy autonomous orchestration | **RETIRE after L7 parity** | new Conversation worker/AgentRuntime |
| L4 autonomous authority implementation | legacy canary authority | **PORT safety invariants; RETIRE implementation after L8** | one outbound policy gate |
| L8 preflight/STOP/consent rules | current safety authority | **KEEP/PORT** | OutboundPolicy + CampaignEligibility |

## Business tools / authorities

| Authority | L0 class | Rule |
|---|---|---|
| patient canonical identity / REV bridge | **KEEP** | Conversations consumes; never creates second patient master. |
| catalog/services/products | **KEEP** | Structured tools query canonical source. |
| price authority | **KEEP** | No prompt/RAG price authority. |
| promotions | **KEEP/FORMALIZE TOOL** | Only current governed promotional facts. |
| locations/payment methods | **KEEP/FORMALIZE TOOL** | Structured facts. |
| Agenda availability | **KEEP** | One canonical availability tool. |
| governed BOOK/REBOOK core | **KEEP/PORT TOOL** | Explicit confirmation + idempotency. |
| governed booking trigger on Agenda | **KEEP** | Defense-in-depth while contracts remain compatible. |
| sales/revenue/commissions | **KEEP** | Cold signals/attribution; not message hot path. |
| campaign attribution | **KEEP** | Strong-key evidence; async where possible. |
| cost intelligence | **KEEP COLD-PATH** | Must not block conversation. |
| media library | **FORMALIZE TOOL** | Controlled media metadata/dispatch. |

## Legacy autonomy / certification artifacts

| Asset | L0 class | Retirement gate |
|---|---|---|
| L9 demo tables/functions | **RETIRE later, preserve evidence** | L8 cutover + archival plan |
| L10 canary run/scope/bridge tables | **RETIRE later, preserve evidence** | new L7 canary authority certified and audit retained |
| append-only legacy audit ledgers | **KEEP historical** | never destroy merely for cleanup |
| legacy allowlist/control tables | **REPLACE/RETIRE** | new OutboundPolicy parity + rollback |
| old CI gates tied to replaced implementation | **PORT assertions then RETIRE** | equivalent new-contract CI exists |

## Background / unrelated runtime

| Component | L0 class | Note |
|---|---|---|
| S15 notification pump | **OUTSIDE CONV CORE / ISOLATE** | Repeated fail-open noise must not block conversations. |
| template cache background task | **OUTSIDE CONV CORE / FIX separately if P0** | Do not pull into message hot path. |
| snapshots/analytics workers | **KEEP COLD** | Background retreat policy applies. |
| email, KronIA, Sales, Patient 360 wrappers | **PROTECTED / NOT OWNED** | Must not be removed by Conversations simplification. |

## Proposed target owner map

```
MetaCloudAdapter
  owns: Meta webhook verification, provider API, media/templates, provider statuses/errors

ConversationCore
  owns: conversation projection, message acceptance, ownership, handoff, idempotency coordination

PanelEventStream
  owns: lightweight change notifications to browser

AgentRuntime
  owns: bounded memory, reasoning cycle, tool selection, response composition

ToolGateway
  owns: narrow typed calls into canonical ASCENDA business authorities

OutboundPolicy
  owns: consent/STOP, human-vs-AI ownership, duplicate/rate/provider eligibility

JobOutbox
  owns: follow-up, campaign dispatch scheduling, retries and reconciliation outside hot path

Audit/Telemetry
  owns: immutable decision/provider/tool evidence and SLOs
```

## Deletion gate — binding

No component above is deleted merely because it is marked REPLACE or RETIRE.

Before DELETE:
1. replacement merged/deployed;
2. shadow or parity proof complete;
3. no current imports/routes/runtime calls;
4. CI assertions moved to replacement;
5. production telemetry proves zero callers for declared window;
6. rollback path exists;
7. protected ASCENDA regressions pass;
8. controlled deletion PR explicitly reviews affected files/functions/migrations.
