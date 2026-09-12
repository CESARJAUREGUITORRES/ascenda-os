# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-11 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**LAST CLOSED:** `CONV-L0 #504 — AUDIT / EXTRACTION / CONTRACT FREEZE`  
**NEXT ELIGIBLE:** `CONV-L1 #505 — NATIVE META CHANNEL GATEWAY · NOT STARTED · NOT AUTHORIZED`  
**Legacy WA-L10 #456:** `FROZEN · SAFE-OFF EVIDENCE ONLY · NO NEW FEATURE PATCHING`  
**P0 #485:** `CLOSED / COMPLETED — PROD RECURRENCE+LOAD PASS`  
**GitHub authority:** Issue `#502` = `OPEN`; Issue `#456` = `OPEN / FROZEN`  
**Current main at L0 technical closeout:** `60b987f75e5efe8906c2eed0d8c560ff449de3b7`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF · AI SEND OFF · AUTO ROUTING OFF`  
**Active autonomous allowlist:** `0`  
**L11/general autonomous PROD:** `NOT AUTHORIZED`

## Binding architecture pivot

The owner approved a consolidation pivot after the R8/R9 WhatsApp canary investigation showed that continuing to stack patches on the WA2/WA3/WA4/F4/L4-L10 hot path was creating latency, operational coupling and debugging complexity without yet meeting the required conversational-sales experience.

CONV-001 remains the active program, but after L0 technical closeout **no HIGH/CRITICAL implementation lane is active**. CONV-L1 #505 is only NEXT ELIGIBLE and requires a separate owner authorization.

External projects such as Chatwoot, Fazer clinical sales agent patterns, LangGraph and official Meta samples are engineering blueprints only. They are not runtime dependencies unless separately approved.

## Legacy WA-L10 freeze

WA-L10 #456 remains preserved for audit/evidence and rollback knowledge, but is frozen:

- no new conversational features on the legacy autonomous hot path;
- no new wrapper/server layer;
- no new duplicate sender, state authority, pricing authority, identity authority or campaign engine;
- no autonomous CANARY reactivation while CONV-001 is active;
- only P0 security, data-loss, privacy or production-break fixes may modify legacy runtime;
- production remains SAFE-OFF with active autonomous allowlist zero.

## CONV-001 governing rules

1. Preserve proven ASCENDA business authorities: patient/identity, catalog/pricing, agenda/booking, sales, attribution, consent and audit.
2. Preserve useful panel UX, but rewire it progressively to the new Conversation Core.
3. New architecture must be tenant-aware and reusable across companies/channels.
4. No Chatwoot, n8n, Dify, Typebot or Evolution API runtime dependency.
5. One normalized inbound envelope, one conversation state authority, one outbound dispatch boundary and one job/outbox mechanism.
6. Routine hot path target: `1 inbound -> 1 reasoning cycle -> 0–2 tools -> 1 outbound`.
7. No heavy global preloads and no fixed high-frequency browser polling.
8. Structured business truth comes from narrow tools/RPCs; semantic commercial knowledge uses bounded retrieval; clinical-sensitive questions fail closed/handoff.
9. Human takeover and STOP/consent always outrank AI.
10. Existing code is classified `KEEP | PORT | REPLACE | RETIRE | DELETE`. Nothing is deleted until replacement parity, zero runtime references and rollback evidence exist.

## Current execution sequence

`CONV-L0 Freeze/Inventory -> L1 Meta Channel Gateway -> L2 Conversation Core + Panel -> L3 Sales Agent -> L4 Business Tools/RAG -> L5 Booking/Media/Templates -> L6 Follow-up/Hot Leads/Campaigns -> L7 Benchmark/Canary -> L8 Cutover/Legacy Retirement/Replication`

## Immediate next gate

**CONV-L0 is technically closed.** The exact runtime/UI/API/DB audit, authority map, extraction matrix, blueprint parity, frozen 40-case benchmark and target contracts are now persisted.

**CONV-L1 #505 is NEXT ELIGIBLE / NOT STARTED / NOT AUTHORIZED.** No Meta Channel Gateway implementation may begin until the owner separately authorizes L1.

See Issue #502 and `docs/control/ASCENDA_CONVERSATIONS_CORE_V1_ROADMAP_CURRENT.md`.
