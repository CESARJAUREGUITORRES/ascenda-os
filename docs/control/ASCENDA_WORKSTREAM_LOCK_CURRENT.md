# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-12 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `INT-GOOGLE-001 #542 / GC-0→GC-7 — GOOGLE CALENDAR + CONTACTS`  
**OWNER AUTHORIZATION:** `PROCEDE · implementar todo en el sistema · RUN UNTIL BLOCKED hasta canary humano`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-001 / CONV-L4 #508 — preflight ready; no competing mutations until Google closeout`  
**Legacy WA-L10 #456:** `FROZEN · SAFE-OFF EVIDENCE ONLY · NO NEW FEATURE PATCHING`  
**P0 #485:** `CLOSED / COMPLETED — PROD RECURRENCE+LOAD PASS`  
**GitHub authority:** Google `#542` = `OPEN / ACTIVE`; Conversations `#502` = `OPEN`; L4 `#508` = `OPEN / PAUSED`; legacy `#456` = `OPEN / FROZEN`  
**Google lock baseline:** `17fc0109399db1eabf7116e29d50c6038eb30670`  
**Current production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF · AI SEND OFF · AUTO ROUTING OFF`  
**Active autonomous allowlist:** `0`  
**L11/general autonomous PROD:** `NOT AUTHORIZED`

## Binding architecture pivot

The owner approved a consolidation pivot after the R8/R9 WhatsApp canary investigation showed that continuing to stack patches on the WA2/WA3/WA4/F4/L4-L10 hot path was creating latency, operational coupling and debugging complexity without yet meeting the required conversational-sales experience.

Owner authorization on 2026-09-12 supersedes the prior mutable-lane assignment for the duration of this integration loop. **INT-GOOGLE-001 #542 owns the sole HIGH/CRITICAL implementation lane through its bounded human canary**. CONV-001 remains preserved and resumes at L4 only after Google closeout/lock transfer.

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

**INT-GOOGLE-001 #542 is ACTIVE.** Complete OAuth, encrypted persistence, Calendar create/update/delete, Contacts exact-identity sync, Resend Calendar action and unified dormant outbox; deploy with sync flags SAFE-OFF, then stop only for the bounded human OAuth/canary action. After certified Google closeout, transfer the lock to `CONV-L4 #508`. CONV production AI autonomy remains SAFE-OFF.

See Issue #502 and `docs/control/ASCENDA_CONVERSATIONS_CORE_V1_ROADMAP_CURRENT.md`.
