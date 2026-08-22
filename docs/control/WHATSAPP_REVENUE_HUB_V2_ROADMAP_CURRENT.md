# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-22 America/Lima  
**Active gate:** `WA-V2-0 — BASELINE & GOVERNANCE`  
**Goal:** finish WhatsApp as an integrated ASCENDA sales channel, connect current Meta traffic/provenance, ground agents in certified business data, and close the loop through appointment, sale and revenue attribution.

## North Star

`Meta Ads / Organic → WhatsApp → provenance → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a conversation/channel product, not a CRM replacement.
- F5 owns canonical patient identity/provenance.
- F3/F4/F6 own product/revenue/intelligence truth.
- CIA owns governed acquisition/channel facts.
- Email owns governed email facts/events.
- Agenda/Call Center remain existing business systems consumed through tools/contracts.
- Meta attribution requires explicit provenance; phone matching alone is never attribution authority.
- Knowledge is source-governed; general model knowledge is never authoritative for price, promo, availability, stock or clinical facts.

## Phase graph

`WA-V2-0 → WA-3 → WA-3.5 → WA-7A → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

Some implementation slices may be executed earlier when dependency-safe, but phase certification cannot bypass declared prerequisites.

## WA-V2-0 — Baseline & Governance

Purpose: reacquire exact-current ownership and reconcile GitHub, Railway, Supabase, aos_memory and Notion without changing product behavior.

Exit:

- active lock = `WHATSAPP-REVENUE-HUB-V2`;
- Notifications S13–S15.5 = CLOSED / regression-only everywhere;
- exact runtime and live counts recorded;
- stale `0 outbound` / old Phase S CURRENT claims superseded;
- previous MKT Loop 6 preserved as PAUSED / 0-of-5 checkpoint;
- GitHub merged, Railway read back, aos_memory updated, Notion updated last.

## WA-3 — Human Operations Multiagent

Purpose: move from single operational actor to governed multiagent sales operation.

Discover/build:

- explicit `whatsapp-agent` permission;
- 2+ authorized canary agents;
- boxes/members/max_active;
- claim/reassign/release;
- supervisor override;
- presence/readiness;
- ownership_version and exact-owner send boundary;
- per-agent inbox visibility;
- no cross-owner leakage;
- routing/queue/unread integrity;
- audit events and rollback.

Evaluate first topology:

- `BOT_INBOX`;
- `VENTAS_GENERAL`;
- `FOLLOW_UP`;
- `ESCALAMIENTO_CLINICO`.

Do not auto-create boxes by sede/treatment without volume evidence.

First canary keeps auto-routing OFF and AI auto-send OFF.

## WA-3.5 — Revenue Inbox UX

Purpose: turn the current functional Hub into an advisor-grade workspace.

Left rail:

- My conversations;
- unassigned;
- bot;
- waiting customer;
- SLA critical;
- unread;
- hot leads;
- follow-up;
- filters: campaign, treatment, sede, sales stage, owner.

Conversation workspace:

- clean timeline;
- sent/delivered/read/failure state;
- optional event separation;
- quick replies/templates;
- attachments/media;
- internal notes;
- drafts and keyboard shortcuts;
- Agenda/call actions;
- Copilot integrated in composer later.

Right panel:

- DETAILS;
- COPILOT;
- CUSTOMER 360;
- CAMPAIGN;
- ACTIVITY.

UX backlog: notification click → Auth if required → preserve destination → open exact conversation after login.

## WA-7A — Meta Attribution Ingress

Purpose: preserve provenance at first inbound.

Persist when Meta supplies it:

- referral/source id;
- source type;
- headline/body;
- ad id;
- lead id;
- campaign source;
- sanitized raw referral;
- immutable touchpoint id.

Flow:

`Meta webhook → referral parser → touchpoint/provenance → conversation → canonical identity`.

Exit requires a real CTWA canary with provenance visible and no attribution invented by phone.

## WA-4A — Knowledge Fabric

Authority layers:

1. transactional live truth;
2. approved commercial knowledge;
3. approved enterprise docs from GitHub/Notion/Drive connectors;
4. campaign context;
5. Customer 360 facts;
6. current conversation context;
7. general LLM knowledge last.

Build:

- source registry;
- owner/version/validity/sensitivity/authority;
- structured retrieval first;
- selective document chunking/vector retrieval only where useful;
- source/evidence IDs in AI runs;
- cache invalidation for changing prices/policies;
- role/domain ACL;
- retrieval evals.

Never bulk-copy all enterprise docs into an ungoverned vector store.

## WA-4B — Sales Playbook Engine

Separate sales progression from conversation handling.

Handling State:

`AI_AUTO / AI_COPILOT / HUMAN_ACTIVE / WAITING_CUSTOMER / CLOSED`

Sales Stage:

`NEW / DISCOVERY / QUALIFIED / OFFER / OBJECTION / BOOKING_INTENT / BOOKED / FOLLOW_UP / WON / LOST`

Add:

- intent taxonomy;
- treatment/interest;
- lead temperature;
- objection taxonomy;
- qualification fields;
- next-best-action;
- playbook version by treatment/campaign;
- CTA policy;
- escalation rules;
- lost reason;
- follow-up timers;
- appointment/sale/revenue links.

## WA-4C — AI Sales Copilot Canary

Prerequisites: Knowledge Fabric + Playbook Engine.

Requirements:

- provider/model health;
- exact-owner authorization;
- grounded retrieval;
- source evidence;
- safety/escalation model;
- budget/cost/latency audit;
- human approval required;
- no autonomous send in initial certification.

## WA-5 — Multimedia / Audio / Media Library

- receive image/audio/document;
- private media storage + retention;
- STT transcript;
- structured audio summary;
- approved media outbound;
- limited vision only under explicit safety policy;
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

Resolve explicit `ad_id` into:

`ad → adset → campaign → creative → treatment/offer metadata`.

Keep sync incremental, auditable and cost-governed.

## WA-7C — Campaign Flow Router + WhatsApp Flows

Purpose: choose the correct business flow from provenance and sales context.

Example:

`HIFU ad → HIFU campaign metadata → HIFU playbook → booking intent → WhatsApp Flow / Agenda tool`.

Support governed WhatsApp Flows for lead qualification, appointment booking and support where they reduce friction.

## WA-7D — Revenue Stitching

Create explicit lineage:

`touchpoint → conversation → canonical customer → appointment → attendance → sale → revenue`.

Measure:

- qualified conversation rate;
- appointment rate;
- attendance rate;
- sale conversion;
- revenue;
- CAC/ROAS where cost source exists;
- AI-only vs human-only vs hybrid contribution.

Never infer revenue attribution solely from phone.

## WA-8 — Production / SLO / Security / FinOps

- SLOs and incident boundaries;
- provider failover policy;
- load/performance;
- cost ceilings;
- retention/deletion;
- disaster/recovery drills;
- audit/export controls;
- regression/eval registry;
- Sentinel integration;
- staged scale rollout.

## Expansion

### WA-9 — Supervisor Intelligence
SLA, queue age, intent/temperature, objections, next-best-action, agent/box conversion, quality evals, loss reasons and coaching.

### WA-10 — Customer 360 Omnichannel
One timeline across Meta touchpoint, WhatsApp, calls, follow-up, Agenda, attendance, sales, payments/cartera and email, role-gated.

### WA-11 — Lifecycle Automation
Governed recontact for abandoned price inquiry, availability-no-book, appointment confirmation, no-show, post-attention commercial follow-up and allowed reactivation with opt-in/templates/frequency caps.

### WA-12 — Controlled AI Autonomy
Escalation ladder: suggest-only → classify → allowlisted internal actions → low-risk auto-reply → book with explicit confirmation → broader autonomy only by new gates.

### WA-13 — Revenue Optimization
Campaign-to-sale funnel, CAC/ROAS, demand signals, staffing/load forecast and budget recommendations with human approval.

### WA-14 — Platformization
Extract reusable provider adapters, secure gateway, message ledger, conversation engine, routing, policy, AI capability router, business tools, attribution, observability and FinOps only after ASCENDA core is stable.

## Standard phase loop

For every phase:

`REVALIDATE CURRENT → DISCOVER → PLAN → BUILD ISOLATED → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → MERGE → RAILWAY EXACT DEPLOY → LIVE CANARY → SECURITY/DATA CHECK → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → aos_memory → Notion LAST → NEXT LOCK`.
