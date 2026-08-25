# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-24 America/Lima  
**Baseline before WA-3.5 closeout:** `main@6292852fad190f1489836fc34644a2161aa575a2`  
**Active closeout:** `WA-3.5 / PR #372`  
**Next mutable phase after merge:** `WA-7A — META ATTRIBUTION INGRESS`  
**LIVE hold:** Supabase HTTP 402 + provider/session canary recertification

## North Star

`Meta Ads / Organic → WhatsApp → explicit provenance → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- F5 owns canonical identity/provenance resolution boundaries.
- REV/F3/F4/F6 own revenue and Customer 360 truth.
- CIA owns governed acquisition/channel facts.
- Agenda and Call Center remain existing ASCENDA systems consumed through contracts.
- Meta attribution requires explicit provenance; phone matching alone is never attribution authority.
- Knowledge is source-governed; a general model is never authoritative for price, promo, availability, stock or clinical facts.
- CODE/CI/ZERO-COST certification is distinct from LIVE production certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE CLOSEOUT → WA-7A → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-V2-0 — Baseline & Governance

**Status: CLOSED.**

## WA-3 — Human Operations Multiagent

**Status: OFFLINE CERTIFIED / LIVE HOLD.**

Implemented: permissions/2FA, boxes/members/max-active, presence/readiness, human-request queue, privacy, claim/reassign/release, supervisor controls, concurrent single-owner claim, exact-owner send, 24h window, audit/recovery and Supabase-402 retry containment.

## WA-3.5 — Revenue Inbox UX

**Status: CODE/CI/ZERO-COST CLOSEOUT — PR #372.**

### P0 — canonical workspace foundation — DONE

- all / mine / human requested / unread / waiting customer / bot-AI / finalised filters;
- campaign filter from canonical `campaign_source`;
- richer conversation cards and handoff/24h context;
- existing timeline and notification/auth restoration preserved;
- shared inbox snapshot remains the single read owner.

### P1A — advisor productivity — DONE

- generic quick replies, populate-only;
- per-actor/per-conversation drafts with TTL and size bound;
- keyboard shortcuts;
- responsive baseline;
- no browser-only internal notes.

### P2 — governed side-panel context — DONE

- `DETAILS` — native WA-3 authority;
- `CUSTOMER 360` — canonical REV-F6 read model, on-demand and permission-gated, narrow commercial projection;
- `CAMPAIGN` — current factual provenance only;
- `ACTIVITY` — canonical conversation milestones;
- `COPILOT` — SAFE-OFF integration boundary;
- mobile Context drawer and explicit degraded states;
- event-driven only: zero P2 pollers/timers/MutationObserver.

### WA-3.5 governance exclusions

- internal notes require a governed persistence contract; they are not browser truth;
- treatment/sales-stage are not fabricated merely to satisfy UI filters;
- private media/STT belongs to WA-5;
- Copilot autonomy belongs to WA-4C;
- expanded attribution belongs to WA-7A.

### WA-3.5 LIVE exit

Requires Supabase recovery plus a fresh real production smoke. Until then: offline certified only.

## WA-7A — Meta Attribution Ingress — NEXT

**Purpose:** preserve explicit Meta provenance at the first inbound, before identity or downstream business logic can blur the original touchpoint.

### Target facts

Persist when supplied by Meta:

- referral/source id and source type;
- referral headline/body where policy permits;
- ad id;
- lead id;
- campaign source;
- sanitized raw referral evidence;
- immutable touchpoint id;
- received-at/provider identifiers necessary for replay/idempotency.

### Flow

`Meta signed webhook → referral parser → immutable provenance/touchpoint → canonical conversation → identity resolver`.

### Rules

- no attribution from phone alone;
- webhook signature and replay/idempotency remain mandatory;
- provenance is immutable evidence, not a mutable CRM label;
- parser must degrade safely when referral fields are absent;
- no broad Meta Ads sync yet — that belongs to WA-7B;
- real CTWA/live provider canary remains required for LIVE exit when Cloud is available.

## WA-4A — Knowledge Fabric

Build governed source registry, authority/version/validity/sensitivity, structured retrieval, selective vector retrieval, evidence IDs, ACLs, cache invalidation and retrieval evals.

## WA-4B — Sales Playbook Engine

Separate handling state from commercial progression. Add governed intent, qualification, objection, next-best-action, lost reason, follow-up and booking intent semantics.

## WA-4C — AI Sales Copilot Canary

Prerequisites: WA-4A + WA-4B. Initial mode is human approval required; no autonomous send.

## WA-5 — Multimedia / Audio / Media Library

Private media storage, audio/STT, documents/images, approved outbound media, retention and safety boundaries.

## WA-6 — Business Tools

Reuse Agenda, follow-up, Call Center and Customer 360 contracts. Never invent availability; create no parallel agenda.

## WA-7B — Meta Ads Sync

Resolve explicit `ad_id → adset → campaign → creative` with incremental, auditable and cost-governed sync.

## WA-7C — Campaign Flow Router + WhatsApp Flows

Choose governed flows from provenance + sales context; use WhatsApp Flows where they reduce friction.

## WA-7D — Revenue Stitching

`touchpoint → conversation → canonical customer → appointment → attendance → sale → revenue` with explicit evidence and no phone-only attribution.

## WA-8 — Production / SLO / Security / FinOps

SLO/error budgets, provider failure policy, load/performance, cost ceilings, retention/deletion, DR, audit/export, regression/evals, Sentinel integration and staged rollout.

## WA-9 → WA-14 expansion

- WA-9 Supervisor Intelligence;
- WA-10 Customer 360 Omnichannel;
- WA-11 Lifecycle Automation;
- WA-12 Controlled AI Autonomy;
- WA-13 Revenue Optimization;
- WA-14 reusable platform core.

## Standard phase loop

`REVALIDATE CURRENT → DISCOVER → PLAN → BUILD ISOLATED → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → MERGE → RAILWAY EXACT DEPLOY → LIVE CANARY WHEN AVAILABLE → SECURITY/DATA CHECK → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → aos_memory when available → Notion LAST → NEXT LOCK`.
