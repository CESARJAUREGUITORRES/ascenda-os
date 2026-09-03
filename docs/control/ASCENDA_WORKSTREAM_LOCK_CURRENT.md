# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L9 — AUTONOMOUS DEMO READY`  
**GitHub authority:** Issue `#453` = `OPEN / ACTIVE`  
**ENTRY baseline:** `main@c0e546b77f072f85662c0c2ce5ab13f6f4f64f0d`  
**Parent roadmap:** Issue `#410`  
**Previous closed lane:** `WA-L8 — Security Gate for Autonomous Canary + Meta 2026 pricing/policy hardening`  
**WA-L8 status:** `CLOSED · PRODUCTION CERTIFIED · DORMANT / SAFE-OFF`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — L10 remains a separate explicit owner-authorized boundary.

## WA-L9 authority

L9 is the sole mutable HIGH/CRITICAL lane. Its purpose is to certify the WhatsApp Revenue Agent as **AUTONOMOUS DEMO READY** while suppressing autonomous provider dispatch in production.

Required demonstration chain:

`Meta/campaign context → conversation + identity state → intent/need → governed knowledge/price → real availability authority → BOOK/REBOOK decision path → confirmation/follow-up plan → attribution context → Meta/AI cost reconciliation/projection → audit/human handoff`.

L9 must:

- reuse L4 autonomous authority and L8 security/preflight; no parallel autonomy authority;
- reuse WA-7A.4 scoped consent/suppression + persistent STOP semantics;
- use deterministic shadow/dry-run evidence for the autonomous send decision/envelope;
- suppress live autonomous Meta/provider dispatch during L9 certification;
- retain identity, attribution and revenue strong-key boundaries;
- remain fail-closed on consent, STOP, identity, capability, availability, template/provider verification, pricing/cost materiality, replay/duplicate and safety ambiguity;
- retain direct auditable human escalation;
- keep telemetry PII/PHI/raw-prompt/raw-model-reply safe;
- preserve one-message-per-turn economy where UX allows;
- pass dedicated exact-head L9 CI plus L8/L7/L6/L5/L4, WA-4C FULL LOCAL and P0 #432 cross-module regressions;
- merge only with `expected_head_sha` after exact-head green CI;
- if runtime/schema changes reach PROD, deploy them dormant and prove PRE→POST SAFE-OFF/cross-module parity before L9 closeout.

## WA-L8 certified dependency

WA-L8 remains closed and live as a dormant security/policy layer:

- issue `#451` CLOSED/completed;
- certified exact-head `7d50c28aba0c1b78c86c4d55b035d8e184d23cc0`;
- 13/13 exact-head workflows SUCCESS;
- merge `31efdda8b082122436c2587fc8b635ecd313e5d8`;
- Railway exact-merge SUCCESS;
- Supabase PROD WA-7A.4 + L8 lineage `20260903215729` through `20260903220209`;
- PRE→POST unchanged: Agenda 3209, llamadas 37186, Leads 6694, Ventas 1393, Pacientes 7760;
- autonomous outbound 0, AI runs 0, pricing authority rows 0;
- Meta real cost events 7/7 KNOWN, 0 billables, cost 0;
- Utility/Marketing eligibility on sampled real conversation fail closed with `CONSENT_UNKNOWN`.

## Retained P0 #432 doctrine

- no heavy global analytical views on synchronous hot paths;
- no synchronous materialized-view refresh/rebuild on message/call/booking/sales writes;
- no timeout inflation;
- bounded/indexed reads;
- no duplicate legacy/new generation;
- governed browser fan-out;
- enrichment/cold path isolated;
- mandatory regressions: Agenda + Call Center + Marketing + Sales/Commissions + Patients/Identity + shared Supabase/background;
- CODE PASS ≠ DEPLOY PASS ≠ PROD PASS.

## Explicitly outside WA-L9 authority

WA-L9 does **not** authorize:

- `AUTO_OFF → CANARY`;
- kill-switch disengagement;
- `auto_reply=true`;
- `ai_send=true`;
- `auto_routing=true`;
- live allowlisted autonomous traffic;
- autonomous provider dispatch in production;
- bulk sends/broadcasts;
- WA-L10 execution.

`WA-L10 — AUTONOMOUS PRODUCTION CANARY` requires a separate explicit owner authorization after L9 closeout.
