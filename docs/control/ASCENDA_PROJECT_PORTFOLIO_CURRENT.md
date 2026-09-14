# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-09-12 America/Lima  
**Current main at L0 technical closeout:** `60b987f75e5efe8906c2eed0d8c560ff449de3b7`  
**ACTIVE PORTFOLIO OWNER:** `CONV-001 — CONVERSATIONS CORE V1`  
**ACTIVE HIGH/CRITICAL GATE:** `CONV-L4 #508 — BUSINESS TOOLS + BOUNDED RAG`  
**OWNER MODE:** `PROCEDE · implementar todo en el sistema · RUN UNTIL BLOCKED hasta canary humano`  
**JUST CLOSED:** `INT-GOOGLE-001 #542 — GC-0→GC-8 COMPLETE`

## Current owner state

Google integration is closed after human canary and bounded reconciliation. The sole HIGH/CRITICAL mutable lane is transferred to CONV-L4 #508 under the existing owner authorization to continue L4→L7 and stop at the next real human canary.

Legacy WA-L10 #456 is FROZEN / SAFE-OFF evidence only. No new conversational feature patching is permitted on the legacy hot path except narrowly scoped P0 security/privacy/data-loss/production-break remediation.

## Program map

| Program | Preserved input | Current state |
|---|---|---|
| INT-GOOGLE-001 Google Calendar + Contacts | Agenda authority, patient identity, existing integration catalog, Resend templates | **CLOSED / GC-0→GC-8 COMPLETE** |
| CONV-001 Conversations Core V1 | existing panel, WA evidence, Meta integration knowledge, canonical ASCENDA business authorities | **ACTIVE / L4 #508 MUTABLE OWNER** |
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

Owner authorization covers orderly L4→L7 execution until the separately gated human canary. Each loop must still satisfy its technical exit gate before advancing.

## Global rule

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. CONV-L4 #508 now owns the lock; all other programs remain read-only/regression-only except narrowly required compatibility/regression work.
