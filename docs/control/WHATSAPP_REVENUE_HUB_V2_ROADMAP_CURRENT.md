# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-24 America/Lima  
**Runtime anchor:** `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**Active closeout gate:** `WA-3 — OFFLINE CLOSEOUT / PR #369`  
**Next mutable gate after closeout merge:** `WA-3.5 — REVENUE INBOX UX`  
**Live production hold:** Supabase HTTP 402 + provider/canary recertification

## North Star

`Meta Ads / Organic → WhatsApp → explicit provenance → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a conversation/channel product, not a CRM replacement.
- F5 owns canonical patient identity/provenance.
- F3/F4/F6 own product/revenue/intelligence truth.
- CIA owns governed acquisition/channel facts.
- Email owns governed email facts/events.
- Agenda/Call Center remain existing business systems consumed through tools/contracts.
- Meta attribution requires explicit provenance; phone matching alone is never attribution authority.
- Knowledge is source-governed; general model knowledge is never authoritative for price, promo, availability, stock or clinical facts.
- CODE/CI/ZERO-COST certification is distinct from LIVE production certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 OFFLINE CLOSEOUT → WA-3.5 → WA-7A → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

Some implementation slices may be dependency-safe earlier, but certification cannot bypass prerequisites.

## WA-V2-0 — Baseline & Governance

**Status: CLOSED.**

Baseline/governance was reacquired and the active WhatsApp V2 ownership was established without rebuilding prior certified infrastructure.

## WA-3 — Human Operations Multiagent

**Status: FUNCTIONALLY BUILT / CODE-CI-ZERO-COST CLOSEOUT.**

Implemented and covered offline:

- explicit `whatsapp-agent` permission;
- multiagent boxes/members/`max_active`;
- claim/reassign/release;
- supervisor override/manual intervention;
- presence/readiness with labor-state integration and stale fail-closed behavior;
- exact-owner send boundary;
- per-agent visibility/ownership isolation;
- `HUMAN_REQUESTED` human-only queue semantics;
- routing/queue/unread integrity;
- audit events;
- concurrent single-owner claim;
- rollback/recovery;
- strong Auth V3/2FA continuity;
- performance shared-snapshot/single-owner hardening;
- Supabase 402 retry-storm circuit.

First production canary remains fail-closed with:

- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`.

**Live exit still pending:** Supabase 402→200 + provider health + consolidated CESAR↔MIREYA handoff/send/reassign canary.

## WA-3.5 — Revenue Inbox UX

**Status: NEXT AFTER PR #369 MERGE.**

Purpose: turn the governed WA-3 runtime into an advisor-grade Revenue Inbox without changing ownership/security authority.

### P0 — canonical workspace foundation

Start with existing canonical fields only:

- My conversations;
- Human requested;
- Unread;
- Waiting customer;
- Bot/New state view;
- filters by campaign/state/owner/box where already available;
- cards with contact, last message, state, owner/box, unread, campaign and handoff/queue age when available;
- clean timeline preserving sent/delivered/read/failure;
- exact conversation restoration from notifications/auth;
- shared inbox snapshot remains the single read owner; no duplicate high-frequency poller.

### P1 — advisor productivity

- quick replies/templates;
- persistent drafts;
- keyboard shortcuts;
- optional event separation;
- internal notes only through governed persistence, not browser-only truth;
- responsive/basic mobile behavior;
- clear empty/error/degraded states.

### P2 — governed side panel integrations

Right panel target:

- DETAILS;
- COPILOT placeholder/integration boundary;
- CUSTOMER 360 read models;
- CAMPAIGN provenance;
- ACTIVITY.

Agenda/call actions must reuse existing ASCENDA systems. Treatment/sede/sales-stage filters are added only after those canonical facts are exposed; do not fabricate them in the inbox.

Private Meta media fetch/storage/signed URLs/STT are **WA-5**, not WA-3.5.

### WA-3.5 exit

- usable by a real advisor;
- no ambiguous ownership/queue state;
- no security/2FA regression;
- no duplicate read owner;
- basic responsive behavior;
- exact-head CI and production smoke when Cloud is available.

## WA-7A — Meta Attribution Ingress

Purpose: preserve explicit provenance at first inbound.

Persist when Meta supplies it:

- referral/source id/type;
- headline/body;
- ad id;
- lead id;
- campaign source;
- sanitized raw referral;
- immutable touchpoint id.

Flow: `Meta webhook → referral parser → touchpoint/provenance → conversation → canonical identity`.

Exit requires a real CTWA canary; never infer attribution from phone alone.

## WA-4A — Knowledge Fabric

Authority layers:

1. transactional live truth;
2. approved commercial knowledge;
3. approved enterprise docs/connectors;
4. campaign context;
5. Customer 360 facts;
6. current conversation context;
7. general LLM knowledge last.

Build source registry, authority/version/validity/sensitivity, structured retrieval first, selective vector retrieval, evidence IDs, cache invalidation, ACLs and retrieval evals.

## WA-4B — Sales Playbook Engine

Separate handling state from commercial progression.

Handling State target:
`AI_AUTO / AI_COPILOT / HUMAN_ACTIVE / WAITING_CUSTOMER / CLOSED`.

Sales Stage target:
`NEW / DISCOVERY / QUALIFIED / OFFER / OBJECTION / BOOKING_INTENT / BOOKED / FOLLOW_UP / WON / LOST`.

Add intent, interest/treatment, lead temperature, objections, qualification, next-best-action, playbook version, CTA/escalation rules, lost reason, follow-up timers and appointment/sale/revenue links.

## WA-4C — AI Sales Copilot Canary

Prerequisites: Knowledge Fabric + Playbook Engine.

- provider/model health;
- exact-owner authorization;
- grounded retrieval/evidence;
- safety/escalation;
- budget/cost/latency audit;
- human approval required;
- no autonomous send in initial certification.

## WA-5 — Multimedia / Audio / Media Library

- receive image/audio/document;
- private media storage + retention;
- STT transcript and structured audio summary;
- approved media outbound;
- limited vision under explicit safety policy;
- clinical uncertainty escalates to human/clinical workflow.

## WA-6 — Business Tools

Reuse existing ASCENDA systems:

- Agenda / availability / booking;
- follow-up;
- Call Center;
- Customer 360 read models;
- approved payments/cartera context by role.

AI never invents availability. No parallel Agenda engine.

## WA-7B — Meta Ads Sync

Resolve explicit `ad_id` into `ad → adset → campaign → creative → treatment/offer metadata` with incremental, auditable and cost-governed sync.

## WA-7C — Campaign Flow Router + WhatsApp Flows

Choose governed business flow from provenance and sales context. Support WhatsApp Flows for qualification/booking/support where they reduce friction.

## WA-7D — Revenue Stitching

Create explicit lineage:
`touchpoint → conversation → canonical customer → appointment → attendance → sale → revenue`.

Measure qualification, appointment, attendance, close, revenue and CAC/ROAS where evidence exists. Never infer revenue attribution solely from phone.

## WA-8 — Production / SLO / Security / FinOps

- SLO/error budgets;
- provider failure policy;
- load/performance;
- cost ceilings;
- retention/deletion;
- disaster/recovery drills;
- audit/export controls;
- regression/eval registry;
- Sentinel integration;
- staged rollout.

## WA-9 → WA-14 expansion

- WA-9 Supervisor Intelligence;
- WA-10 Customer 360 Omnichannel;
- WA-11 Lifecycle Automation;
- WA-12 Controlled AI Autonomy;
- WA-13 Revenue Optimization;
- WA-14 reusable platform core.

## Standard phase loop

`REVALIDATE CURRENT → DISCOVER → PLAN → BUILD ISOLATED → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → MERGE → RAILWAY EXACT DEPLOY → LIVE CANARY → SECURITY/DATA CHECK → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → aos_memory when available → Notion LAST → NEXT LOCK`.
