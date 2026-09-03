# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured:** 2026-09-03 America/Lima  
**Canonical baseline at capture:** `main@bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**LAST CLOSED:** `WA-L9 — AUTONOMOUS DEMO READY`  
**NEXT ELIGIBLE:** `WA-L10 — AUTONOMOUS PRODUCTION CANARY · NOT STARTED`  
**CANARY:** `NOT AUTHORIZED`

## Mandatory bootstrap before any write

Read in this order:

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/MEMORY_CURRENT.md`;
6. `docs/control/WA_AUTO_L9_TO_L11_CONTINUITY_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`;
10. relevant latest WA phase contract/certificate/migrations/CI;
11. exact GitHub `main` and current PR/head;
12. Railway exact deploy status;
13. live Supabase safety + scoped boundary readbacks;
14. Notion Control Maestro / Roadmap Maestro / Master Closeout / WA-AUTO continuity last.

Historical docs, chat snapshots or stale Notion callouts never override exact CURRENT + persisted runtime evidence.

## Non-negotiable execution governance

- exactly one mutable HIGH/CRITICAL lane at a time;
- do not start the next lane because the previous one closed unless the owner authorized continuation;
- every `main` advance requires exact-head revalidation for the active lane;
- merge only after exact-head gates and anti-drift; use `expected_head_sha`;
- `CODE PASS != DEPLOY PASS != PROD PASS`;
- Railway SUCCESS does not prove Supabase PROD correctness;
- migration presence does not prove runtime behavior;
- no production evidence may be fabricated with synthetic rows;
- Notion is synchronized after technical truth, never used to override it.

## P0 #432 reliability/performance gate

Every HIGH/CRITICAL phase must preserve:

- Agenda;
- Call Center;
- Marketing/Leads;
- Sales/Commissions;
- Patients/Identity;
- shared Supabase/background pressure.

Forbidden patterns:

- heavy global analytics on synchronous hot paths;
- synchronous materialized-view refresh/rebuild on message/call/booking/sales writes;
- timeout inflation;
- duplicate legacy/new execution;
- unbounded browser fan-out;
- expensive enrichment inside transactional paths.

Required patterns:

- bounded/indexed reads;
- single-flight/bounded concurrency where browser fan-out exists;
- cold-path enrichment/analytics;
- fail-closed provider/identity/pricing/consent decisions;
- exact-head + deploy + LIVE readbacks.

## Current product architecture

The governed Revenue Agent loop is:

`Meta lead/referral -> WhatsApp conversation -> campaign context -> canonical identity -> governed knowledge/pricing -> intent/readiness -> real availability -> BOOK/REBOOK -> follow-up/handoff -> attendance -> sale -> attribution -> WhatsApp/AI cost`.

Consume canonical sources; do not create parallel CRM, patient, sales, agenda, marketing-attribution, pricing or identity masters.

Hard separations retained:

- channel alias != canonical patient identity;
- acquisition touchpoint != consent;
- identity != reachability != marketing eligibility;
- attribution evidence != consent;
- provider delivery/billing evidence != inferred invoice;
- generic LLM knowledge != governed business fact authority.

## Production safety at WA-L9 closeout

Binding until a separately authorized transition:

- `mode=AUTO_OFF`;
- kill switch engaged;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- autonomous provider dispatch = 0;
- active canary allowlist required for `AUTO_OFF -> CANARY`.

The L4 authority structurally forbids direct `AUTO_OFF -> PROD`; general production must follow demonstrated CANARY.

## Closed WA autonomy layers

Treat as regression dependencies unless evidence proves a defect:

- L4 Autonomous Authority + Kill Switch;
- L5 Conversational BOOK/REBOOK;
- L6 Meta campaign context + strong-key attribution;
- L7 WhatsApp/AI Cost Intelligence;
- L8 Security Gate + Meta 2026 hardening;
- L9 Autonomous Demo Ready shadow certification.

WA-L9 exact evidence:

- certified head `b0a65d5b340896263a3f75cb66ab7850fdb3c5fa`;
- PR #454 merge/deploy `f909e972aab243af954fc8e2fb15e5a37c68d1b6`;
- Supabase PROD `20260903225152 · wa_l9_shadow_demo_v1`;
- issue #453 CLOSED/completed;
- final closeout main `bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`;
- lock NONE;
- PROD L9 demo/would-send/provider-dispatch/raw-content rows all 0;
- autonomous outbound 0.

## Meta / AI business rules agents must remember

- Meta charging is based on delivered messages and recipient market/category.
- Do not seed unverified future Meta rates as VERIFIED pricing authority.
- Confirm actual WABA billing currency/rate card in Meta Billing Hub before invoice-grade certification.
- Recheck Meta terms before live canary; an announced terms update is effective 2026-09-23.
- Business-initiated sends require approved template/eligibility evidence.
- Respect explicit consent, STOP/opt-out and human escalation.
- Keep the AI business-specific; do not turn WhatsApp into a generic ask-anything AI service.
- Do not use WhatsApp Business Solution Data to train/improve a general-purpose AI model.
- Prefer one useful outbound provider message per turn where UX permits; unnecessary bubble splitting increases provider cost and duplicate/fan-out risk.

## Current execution boundary — WA-L10

`WA-L10 — AUTONOMOUS PRODUCTION CANARY` is **NEXT ELIGIBLE / NOT STARTED / CANARY NOT AUTHORIZED**.

An agent may, under SAFE-OFF and explicit work authorization, audit/build/certify the L10 preflight package, observability, rollback, allowlist tooling and CI. It must stop before any real autonomous Meta dispatch unless the owner separately authorizes the CANARY transition.

L10 real activation requires at minimum:

- exact-current anti-drift;
- live authority/kill-switch readback;
- explicitly selected minimal allowlisted conversation/cohort;
- L8 consent/STOP/security preflight PASS;
- provider credential/template readiness;
- cost/budget/rate/duplicate/idempotency boundaries;
- human handoff and emergency kill path;
- PRE fingerprints for cross-module regressions;
- owner authorization for `AUTO_OFF -> CANARY`;
- real provider delivery/outcome evidence;
- immediate rollback criteria;
- POST fingerprints and no unrelated mutation.

## WA-L11 — General Production

L11 remains blocked until L10 closes with real canary evidence. Do not shortcut CANARY.

L11 must prove controlled ramp, stable provider delivery, customer safety, conversation quality, attribution/cost integrity, P0 performance, operating ownership, rollback and production runbook before general autonomy is certified.

## Post-L11 customer experience validation

After L11 technical/production certification, execute a separate real-customer validation program covering conversation naturalness, intent/context quality, latency, duplicate/repetition rate, booking/REBOOK usability, human handoff, STOP behavior, privacy/identity, drop-off, cost per qualified conversation/booking/attendance/sale and customer/operator feedback.

Real customer-experience evidence must come from consented real pilots; never manufacture it in PROD.
