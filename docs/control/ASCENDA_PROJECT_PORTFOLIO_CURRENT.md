# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-09-11 America/Lima  
**Current main at L0 technical closeout:** `60b987f75e5efe8906c2eed0d8c560ff449de3b7`  
**ACTIVE PORTFOLIO OWNER:** `CONV-001 — ASCENDA CONVERSATIONS CORE V1`  
**ACTIVE HIGH/CRITICAL GATE:** `CONV-L2 #506 — Conversation Core + event-driven panel transport`  
**OWNER MODE:** `RUN UNTIL BLOCKED hasta la siguiente prueba · WhatsApp humano activo · AI autonomy SAFE-OFF`  
**LAST CLOSED:** `CONV-L1 #505 — PROVIDER CERTIFIED`

## Current owner state

CONV-001 remains the active portfolio program. CONV-L2 #506 is the sole HIGH/CRITICAL mutable lane.

Legacy WA-L10 #456 is FROZEN / SAFE-OFF evidence only. No new conversational feature patching is permitted on the legacy hot path except narrowly scoped P0 security/privacy/data-loss/production-break remediation.

## Program map

| Program | Preserved input | Current state |
|---|---|---|
| CONV-001 Conversations Core V1 | existing panel, WA evidence, Meta integration knowledge, canonical ASCENDA business authorities | **ACTIVE / CONV-L2 MUTABLE OWNER** |
| Legacy WhatsApp Revenue Hub WA-* | WA3/3.5 UI, L4 authority, L5 booking, L6 attribution, L7 cost, L8 security, L9/L10 evidence | **FROZEN / EVIDENCE + EXTRACTION SOURCE** |
| Revenue REV-* | patient/product/revenue identity and 360 authorities | READ-ONLY dependency source |
| Agenda / Call Center / Marketing | current operational systems | PROTECTED regression dependencies |
| Sentinel | observability/integrity foundation | REGRESSION-ONLY |
| KronIA | internal proof of selective/on-demand conversational context | READ-ONLY blueprint/reference |
| Migration governance | current safe migration/rollback standards | MAINTENANCE dependency |

## Truth ownership retained

- Patient/identity -> existing canonical Revenue/Patients authorities.
- Catalog/product/pricing -> existing canonical catalog/price authorities.
- Agenda/availability/booking -> existing canonical Agenda/booking authorities.
- Sales/revenue/commissions -> existing Revenue/Sales authorities.
- Attribution -> existing governed attribution authorities.
- Consent/STOP/privacy/audit -> existing WA/security authorities.
- Conversations Core -> owns normalized channel events, conversation lifecycle, ownership, agent/tool orchestration and async conversation jobs.

CONV-001 must consume these sources and must not create parallel patient, pricing, sales, agenda, attribution or consent masters.

## Architecture decision

Native ASCENDA product:
- ASCENDA panel remains the operator UI;
- one new Conversations Core progressively replaces the legacy wrapper hot path;
- Chatwoot/Fazer/LangGraph/Meta examples are engineering blueprints only;
- no mandatory Chatwoot, n8n, Dify, Typebot or Evolution runtime;
- tenant-aware interfaces are designed from day 1;
- current Zi Vital production DB is not converted into multi-tenant SaaS by big-bang mutation.

## Execution sequence

`L0 #504 -> L1 #505 -> L2 #506 -> L3 #507 -> L4 #508 -> L5 #509 -> L6 #510 -> L7 #511 -> L8 #512`.

No later loop becomes active automatically. Each exit gate plus current owner/governance rules apply.

## Global rule

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. While CONV-L2 owns the lock, all other programs remain read-only/regression-only except narrowly required compatibility/regression work.
