# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-08-25 America/Lima  
**Current GitHub baseline:** `main@e454c9535eeff00c665794c2ac319dcc38bdf13f`  
**WA-3.5:** `CLOSED / CODE-CI-ZERO-COST OFFLINE CERTIFIED 100%`  
**Active next mutable phase:** `WA-7A — WHATSAPP IDENTITY & ATTRIBUTION FOUNDATION`  
**LIVE hold:** Supabase HTTP 402 + fresh provider/session canary recertification

## North Star

`Meta Ads / Business Username / Organic / QR / Web → WhatsApp → explicit provenance + channel identity → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

## Architecture rules

- WA is a governed conversation/channel product, not a CRM replacement.
- The phone number is a contact point, not a mandatory WhatsApp primary key.
- BSUID is a WhatsApp channel identity alias scoped to the business portfolio.
- Username is informational/display data and is never canonical routing identity.
- Canonical person resolution remains governed by REV/F5 identity boundaries.
- Acquisition touchpoints are separate from person/channel identity.
- `ctwa_clid`/referral evidence identifies provenance; it must not be confused with BSUID.
- Meta attribution requires explicit provenance; phone matching alone is never attribution authority.
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- Knowledge is source-governed; a general model is never authoritative for price, promo, availability, stock or clinical facts.
- CODE/CI/ZERO-COST certification is distinct from LIVE production certification.

## Phase graph

`WA-V2-0 ✅ → WA-3 ✅ OFFLINE → WA-3.5 ✅ OFFLINE → WA-7A [0→4] → WA-4A → WA-4B → WA-4C → WA-5 → WA-6 → WA-7B → WA-7C → WA-7D → WA-8 → WA-9..WA-14`

## WA-V2-0 — Baseline & Governance

**Status: CLOSED.**

## WA-3 — Human Operations Multiagent

**Status: OFFLINE CERTIFIED / LIVE HOLD.**

Implemented: permissions/2FA, boxes/members/max-active, presence/readiness, human-request queue, privacy, claim/reassign/release, supervisor controls, concurrent single-owner claim, exact-owner send, 24h window, audit/recovery and Supabase-402 retry containment.

## WA-3.5 — Revenue Inbox UX

**Status: OFFLINE CERTIFIED 100% / LIVE HOLD.**

### Closed scope

- P0 canonical Revenue Inbox;
- P1A advisor productivity;
- P2 governed side-panel context;
- no duplicate inbox read owner;
- no browser-only internal notes;
- no P2 polling/timers/MutationObserver;
- Customer 360 reuses REV-F6 on-demand/permission-gated;
- Campaign exposes factual provenance only;
- Copilot remains SAFE-OFF.

## WA-7A — WhatsApp Identity & Attribution Foundation — ACTIVE NEXT

### Why this precedes attribution-only implementation

The 2026 WhatsApp username rollout means new conversations may not expose a consumer phone number. Existing ASCENDA WA gateway behavior is phone-first, so attribution must not be built on top of a soon-invalid identity assumption.

WA-7A therefore owns both:

1. **channel identity compatibility/continuity**, and
2. **immutable acquisition provenance at first inbound**.

It does not replace canonical ASCENDA identity and does not yet build the full campaign manager.

### WA-7A.0 — Identity Compatibility

**Goal:** make WhatsApp transport identity phone-optional.

Required:

- parse and persist phone+BSUID or BSUID-only safely;
- store username only as display/search aid;
- keep business portfolio scope with BSUID;
- replace phone-only recipient assumptions with `PHONE|BSUID`;
- retain phone-only restriction for authentication template types that require it;
- update tests so an alphanumeric BSUID cannot be digit-normalized or rejected as an invalid phone;
- preserve all WA-1/WA-3 auth/ownership/idempotency authority.

Exit:

- inbound BSUID-only does not create blank/garbled `from_number`;
- outbound can address a governed BSUID where provider support permits;
- no existing phone-based conversation regression.

### WA-7A.1 — Identity Resolution

**Goal:** connect channel aliases to canonical ASCENDA identity without unsafe merges.

Required:

- alias model linking `canonical_contact/person` ↔ `phone` ↔ `BSUID` ↔ optional username;
- explicit portfolio scope;
- conflict states;
- no merge from username similarity;
- no assumption that BSUID is a universal cross-portfolio customer ID;
- reuse REV/F5 resolution contracts rather than creating a parallel CRM.

Exit:

- same person is not duplicated solely because phone visibility changes;
- conflicts fail closed;
- identity evidence is auditable.

### WA-7A.2 — Identity Verification & Continuity

**Goal:** preserve identity through contact disclosure and WhatsApp identifier changes.

Required:

- consume `user_id_update` or provider-equivalent events when available;
- retain prior/current BSUID lineage;
- support governed `REQUEST_CONTACT_INFO` acquisition where useful;
- distinguish contact source and verification state;
- optionally use delivery/status evidence as corroboration only when contractually reliable;
- treat Contact Book as provider-side assistance, never canonical ASCENDA identity.

Suggested contact states:

`VERIFIED / CLAIMED / UNKNOWN / CONFLICT`.

Exit:

- identifier replacement never destroys lineage;
- newly disclosed phone joins the existing identity instead of creating a duplicate;
- unverified contact claims cannot silently override canonical data.

### WA-7A.3 — Attribution Ingress

**Goal:** preserve immutable acquisition touchpoints at the first inbound.

Persist when supplied:

- `ctwa_clid` or provider-equivalent click identifier;
- referral/source id and source type;
- source URL when supplied and policy-safe;
- ad id;
- lead id;
- campaign source;
- headline/body when permitted;
- sanitized raw referral evidence;
- immutable touchpoint id;
- provider message/event ids;
- replay/idempotency evidence and observed timestamps.

Flow:

`Meta signed webhook → identity-safe envelope → provenance parser → immutable touchpoint → canonical conversation → identity resolver`.

Rules:

- `BSUID != touchpoint`;
- one customer may own many touchpoints;
- no attribution from phone alone;
- parser degrades safely when referral/CTWA fields are absent;
- no broad Meta Ads sync yet — that belongs to WA-7B.

### WA-7A.4 — Marketing Eligibility Foundation

**Goal:** prepare future campaigns without conflating addressability and consent.

Persist/derive through governed contracts:

- recipient identity kind/value;
- WhatsApp reachability;
- marketing consent/eligibility;
- `stop/resume` or provider-equivalent preference events;
- suppression reason;
- last eligibility observation.

Rules:

- a BSUID-only contact can be a valid WhatsApp-native customer/lead;
- reachable does not mean marketing-authorized;
- username is not a cold-prospect import key;
- no consumer-username scraping/directory assumption;
- no bulk marketing engine in WA-7A.

Exit:

- future campaign engine can select eligible WhatsApp recipients by governed recipient identity instead of requiring every row to have a phone number.

## Future campaign identity model

Conceptual audience decomposition:

- `PHONE + BSUID`;
- `BSUID-only`;
- `PHONE-only`;
- `not WhatsApp reachable`.

Marketing eligibility is then evaluated separately from identity/reachability.

## Business Username inbound

Business username may become a new inbound acquisition/discovery source. When provider evidence identifies this origin, preserve it as provenance. Do not infer it merely because a business username exists.

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

## Research / evidence policy for WA-7A

- Meta/provider current documentation is policy/transport authority.
- BSPs and public repositories are implementation evidence, not permission to assume policy behavior.
- Any capability observed only in community code remains provisional until verified against current provider behavior.
- Re-check rollout/policy immediately before LIVE certification because usernames/BSUID behavior is actively rolling out during 2026.

## Standard phase loop

`REVALIDATE CURRENT → DISCOVER → PLAN → BUILD ISOLATED → CONTRACT TESTS → EXACT-HEAD CI → ANTI-DRIFT → MERGE → RAILWAY EXACT DEPLOY → LIVE CANARY WHEN AVAILABLE → SECURITY/DATA CHECK → CERTIFY OR FAIL-CLOSED → GitHub CURRENT → aos_memory when available → Notion LAST → NEXT LOCK`.
