# ASCENDA CONVERSATIONS — BLUEPRINT REGISTRY CURRENT

**Program:** CONV-001 #502  
**Status:** REFERENCE ONLY · NO RUNTIME DEPENDENCY APPROVED  
**Rule:** adopt contracts/patterns deliberately; do not cargo-cult or copy entire stacks.

## Blueprint A — Chatwoot

Repository: https://github.com/chatwoot/chatwoot  
Role: mature customer-messaging/inbox/provider implementation.

Study:
- WhatsApp Cloud provider boundary;
- media/text/template/interactive dispatch;
- provider config validation;
- status/error normalization;
- template sync;
- inbox assignment/handoff patterns;
- attachment/message lifecycle.

Decision: **ADAPT patterns, do not adopt runtime**.

Reason:
ASCENDA already owns the panel, CRM/business context and canonical business authorities. Replacing the panel would create unnecessary dependency and customization work.

License note:
core repository content outside restricted enterprise areas is MIT; every copied/ported fragment still requires file-level/license review and attribution where applicable.

## Blueprint B — Fazer clinical sales-agent implementations

Representative repository:
https://github.com/fazer-ai/ia-vendedora-clinica-langgraph

Role:
domain-near reference for WhatsApp clinical sales automation.

Study:
- message-burst debounce;
- per-conversation locking;
- persistent memory/checkpoints;
- tool boundary;
- booking/handoff;
- scheduled follow-up;
- audio processing.

Decision: **ADAPT architecture patterns**.

Reject by default:
- fixed debounce intervals without measurement;
- product-specific assumptions;
- external components that duplicate ASCENDA authorities.

## Blueprint C — LangGraph

Repository:
https://github.com/langchain-ai/langgraph

Role:
stateful agent orchestration reference.

Study:
`state -> decide -> tool -> observe -> respond`, persistence, tool execution, interrupt/human-in-loop semantics.

Decision: **ADOPT conceptual execution model; runtime dependency undecided**.

CONV-L0/L3 must prove whether a lightweight native loop is sufficient before adding a framework dependency.

## Blueprint D — Meta official WhatsApp samples/contracts

Representative repository:
https://github.com/fbsamples/whatsapp-api-examples

Role:
provider truth reference.

Study:
- webhook verification/signatures;
- Cloud API payload contracts;
- media;
- templates;
- delivery/read/failure statuses;
- authentication and provider error behavior.

Decision: **ADOPT official provider contracts**.

Current Meta documentation/policies must be rechecked before implementation/canary because provider rules and terms change.

## Blueprint E — KronIA inside ASCENDA

Role:
internal proof that a shorter cognition/data path produces a more fluid user experience.

Study:
- on-demand context loading;
- simple request/response path;
- selective business queries;
- direct model/context orchestration.

Decision: **ADAPT simplicity; do not copy privileged/admin assumptions into customer WhatsApp**.

## Rejected as mandatory runtime dependencies

### n8n
Useful automation product, but not required for a replicable ASCENDA installation. Follow-up/campaign jobs belong in native job/outbox infrastructure.

### Typebot
Useful deterministic-flow builder; not needed for the initial core. Its current licensing and product overlap also make it a poor foundation for ASCENDA Conversations.

### Dify
Useful RAG/agent workbench; would duplicate orchestration and operational surfaces. Keep as research reference only.

### Evolution API
Additional WhatsApp abstraction layer is unnecessary while ASCENDA uses official Meta Cloud API directly.

## Pattern acceptance rubric

A blueprint pattern is accepted only if it improves at least one:
- correctness;
- latency;
- provider compatibility;
- failure isolation;
- observability;
- testability;
- tenant reuse;
- operator UX;

and does not create unacceptable:
- runtime dependency;
- license restriction;
- duplicate authority;
- database pressure;
- security/privacy risk;
- operational surface.

Every accepted pattern must record:
`source -> problem -> adopted contract -> ASCENDA implementation -> test -> rollback`.
