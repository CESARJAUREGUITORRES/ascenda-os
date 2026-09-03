# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT MAIN AT CAPTURE:** `bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**LAST CLOSED LANE:** `WA-L9 — AUTONOMOUS DEMO READY`  
**NEXT ELIGIBLE:** `WA-L10 — AUTONOMOUS PRODUCTION CANARY · NOT STARTED`  
**CANARY:** `NOT AUTHORIZED · REQUIRES SEPARATE EXPLICIT OWNER AUTHORIZATION`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
7. `docs/control/WA_AUTO_L9_TO_L11_CONTINUITY_CURRENT.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
9. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
10. `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`;
11. exact GitHub + Supabase + Railway/runtime evidence;
12. Notion Control Maestro / Roadmap / Closeout / WA-AUTO continuity.

Historical chat/doc snapshots never override exact CURRENT + persisted runtime evidence.

## Global execution governance

- Exactly one mutable HIGH/CRITICAL lane at a time.
- Every advance of `main` invalidates stale exact-head certification and requires revalidation for the active lane.
- Protected merges use the certified PR head through `expected_head_sha` plus anti-drift verification.
- `CODE PASS != DEPLOY PASS != PROD PASS`.
- A completed lane does not implicitly authorize the next lane.
- `AUTO_OFF -> CANARY` is a distinct owner decision. It must never be inferred from implementation, CI, deployment or broad continuation language.
- `CANARY -> PROD` is also evidence-gated; no direct `AUTO_OFF -> PROD` transition is allowed by the L4 authority contract.
- No synthetic production rows may be presented as real customer/provider evidence.

## Reliability doctrine retained from P0 #432

Binding across all future WA work:

- no heavy global analytical views on synchronous message/call/booking/sales hot paths;
- no synchronous materialized-view refresh/rebuild on transactional writes;
- no timeout inflation to hide query defects;
- bounded/indexed operational reads;
- no legacy+new duplicate generation;
- browser fan-out governed by single-flight / bounded concurrency / jitter / cooldown;
- enrichment and analytical work stay on cold paths;
- mandatory regressions: Agenda + Call Center + Marketing + Sales/Commissions + Patients/Identity + shared Supabase/background;
- exact-head, deploy and LIVE readbacks are separate proof layers.

## WhatsApp Revenue Agent — closed foundation through WA-L9

The product is no longer merely a chatbot. The certified architecture connects:

`Meta/WhatsApp ingress -> campaign/referral context -> governed identity -> conversation -> governed facts/pricing -> intent/readiness -> real availability -> BOOK/REBOOK -> handoff/follow-up -> attendance/sale -> attribution -> WhatsApp/AI cost`.

### Safety / authority foundation

Production remains deliberately dormant:

- `mode=AUTO_OFF`;
- kill switch engaged;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- autonomous provider dispatch disabled;
- active canary allowlist required before any CANARY transition.

### L4 — Autonomous Authority + Kill Switch

Production-certified authority layer with `AUTO_OFF | CANARY | PROD`, kill switch, allowlist, rate/daily/max-turn/cooldown/duplicate guards, provider/template/identity/safety gates, append-only decisions and fail-closed transitions.

Important transition invariant: `AUTO_OFF -> CANARY` requires an active allowlisted conversation; `AUTO_OFF -> PROD` is forbidden; PROD requires prior CANARY evidence.

### L5 — Conversational BOOK/REBOOK

Production-certified conversational booking wiring. Reuses canonical availability/booking authority; BOOK/REBOOK must follow real sede/date/slot evidence and explicit confirmation. REBOOK preserves the same appointment identity where contractually required. No invented slot/provider/appointment state.

### L6 — Meta Campaign Context & Attribution

Production-certified strong-key attribution chain:

`provider touchpoint -> conversation_id -> governed BOOK/REBOOK -> appointment_id -> attendance -> explicit venta_id_match -> canonical venta_id`.

No revenue/cost attribution by phone/name/username/BSUID alone. Marketing Attribution V2 remains authoritative.

### L7 — WhatsApp / AI Cost Intelligence

Production-certified effective-dated pricing authority and scoped cost/journey reads. Missing/unverified rates fail closed as PARTIAL/UNKNOWN; zero provider-billable evidence may be KNOWN zero. No fabricated FX/rates and no global heavy cost view on hot paths.

### L8 — Security Gate + Meta 2026 Hardening

Production-certified under SAFE-OFF. Includes:

- provider `pricing.type` evidence;
- recipient-market-aware pricing authority;
- per-business-phone/category billing observability;
- consent/opt-in/opt-out/STOP evidence;
- business-initiated messaging preflight;
- signed webhook/idempotency/secrets/server-only boundaries;
- PII/PHI minimization and redacted audit;
- least privilege and cross-module P0 regressions.

### L9 — AUTONOMOUS DEMO READY

**CLOSED · PRODUCTION CERTIFIED · DORMANT SAFE-OFF.**  
Issue `#453` CLOSED/completed.  
Certified exact-head: `b0a65d5b340896263a3f75cb66ab7850fdb3c5fa`.  
PR `#454` merged with `expected_head_sha`.  
Merge/deploy: `f909e972aab243af954fc8e2fb15e5a37c68d1b6`.  
Supabase PROD: `20260903225152 · wa_l9_shadow_demo_v1`.

L9 executes the exact L4+L8 authority inside rollback-only shadow execution. It can produce deterministic would-send evidence but structurally forbids provider dispatch and raw-content storage.

Production closeout evidence:

- Agenda 3209;
- Call Center 37195;
- Leads 6694;
- Ventas 1393;
- Pacientes 7760;
- WA messages 21;
- autonomous outbound 0;
- L9 demo runs 0;
- L9 would-send rows 0;
- L9 provider-dispatch rows 0;
- L9 raw-content rows 0.

Final governance closeout: `main@bab9f0865f779217aadc7c88af4ebf0e1fb0b3ee`, HIGH/CRITICAL lock `NONE`.

## Meta pricing / policy 2026 — retained operational knowledge

Current observed policy/rate logic must remain evidence-backed and effective-dated.

Through 2026-09-30, Meta’s public pricing model charges delivered messages by recipient market/category. Service replies inside the customer-service window and qualifying utility replies are currently free; eligible Click-to-WhatsApp / Facebook CTA entry can create a 72-hour free-entry window.

Peru current July-2026 public list evidence used during the L8 audit:

- Marketing: USD 0.0703 / delivered message;
- Utility: USD 0.0200;
- Authentication: USD 0.0200.

PEN rate-card evidence observed: Marketing PEN 0.2339; Utility/Auth PEN 0.0665. Actual WABA billing currency and invoice authority must be confirmed in Meta Billing Hub; do not replace an official WABA card with spot FX.

For changes announced effective 2026-10-01, external corroboration indicates Service becomes billable after the first 1,000 Service messages per business phone number/month, Utility inside the open 24h window becomes billable, inbound remains free and Free Entry Point remains. Peru USD 0.0300 for Utility/Auth/Service was strongly corroborated but not directly fetched from Meta during the audit because the official developer card returned 429. Therefore **do not seed the October USD 0.0300 as VERIFIED in PROD until the clinic’s official Meta Billing Hub/WABA rate card is read.**

Meta policy boundaries retained:

- business-initiated conversations require approved templates;
- free-form replies are governed by the customer-service window;
- explicit opt-in and STOP/opt-out must be respected;
- automation must preserve clear human escalation;
- health/privacy data requires minimum-data discipline;
- WhatsApp data must not be used to train/improve a general-purpose AI model;
- the agent must remain business-specific, not a generic ask-anything AI service.

Meta terms have an announced update effective 2026-09-23; recheck official terms before L10 live canary.

## Groq cost baseline retained

Verified current public rates at the L7/L8 audit:

- GPT-OSS 20B: USD 0.075/M input, USD 0.30/M output;
- GPT-OSS 120B: USD 0.15/M input, USD 0.60/M output.

Once Meta service-message charging applies, provider delivery can dominate inference cost. Product default should remain one useful outbound message per turn where conversational UX allows; do not split one answer into multiple provider messages purely for style.

## Remaining final roadmap

### WA-L10 — AUTONOMOUS PRODUCTION CANARY

`NEXT ELIGIBLE · NOT STARTED · CANARY NOT AUTHORIZED`.

Purpose: controlled real autonomous traffic to a tiny allowlisted cohort, with L4/L8 authority, budgets, duplicate/idempotency guards, human handoff, rollback/kill-switch, provider delivery evidence, cost and cross-module regression monitoring.

L10 can be prepared/certified up to the activation boundary under SAFE-OFF, but actual `AUTO_OFF -> CANARY`, allowlisting of live customer conversations, autonomous Meta dispatch and kill-switch disengagement require separate explicit owner authorization.

### WA-L11 — GENERAL PRODUCTION

May start only after L10 has real canary evidence and an explicit go/no-go decision. Requires controlled ramp, no direct AUTO_OFF->PROD shortcut, stable customer outcomes, provider/invoice reconciliation, performance/P0 regression proof, operational runbook, rollback and ownership/on-call controls.

### Post-L11 — Customer Experience & Conversation Validation

After general-production certification, run an explicit real-customer validation program. It is not a substitute for L10/L11 safety certification.

Measure at minimum:

- naturalness / non-robotic conversation;
- first useful answer and full-turn latency;
- intent understanding and context retention;
- no repetitive loops or duplicate sends;
- one outbound provider message per turn by default where appropriate;
- governed facts/prices only;
- booking ease, booking conversion and correct REBOOK continuity;
- safe identity/privacy behavior;
- clear human handoff and escalation;
- STOP/opt-out behavior;
- drop-off/friction by conversation stage;
- WhatsApp + AI cost per qualified conversation / booking / attended appointment / sale;
- attribution continuity from campaign to sale;
- customer feedback and operator review;
- auditability of every autonomous decision.

Use real consented/allowlisted pilots and redacted evidence. Never fabricate production customer experience evidence.

## Immediate execution boundary

1. keep `AUTO_OFF + kill switch engaged`;
2. refresh all technical memory/roadmap/Notion authority to this state;
3. perform read-only L10 entry audit;
4. build/certify any SAFE-OFF L10 preflight package if needed;
5. stop at the explicit `AUTO_OFF -> CANARY` owner gate;
6. after explicit authorization, execute real L10 canary;
7. only with L10 PASS, proceed to L11;
8. after L11 certification, run the real Customer Experience & Conversation Validation program.
