# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-09-01 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Entry main:** `66ac1bfaa92465f061c243578607388926970c32`  
**Current target:** `AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`  
**Active loop:** GitHub issue #410  
**Active technical gate:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`

## CURRENT summary

ASCENDA WhatsApp has already passed the assisted-operation foundation: signed/provider ingress substrate, canonical message/conversation store, ownership/assignment, human send, commercial Copilot/runtime, governed knowledge/price context, patient identity adapter, campaign/referral adapter, clinical skill/procedure hierarchy, schedule-aware booking resolver and P0 performance hardening.

The new production requirement is stricter: the bot must autonomously maintain a grounded commercial conversation through booking, confirmations/reminders and rebooking, while preserving safety, attribution and cost traceability.

Full autonomous architecture CURRENT is frozen in `docs/control/WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT.md` and issue #410.

## Production state at capture

- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- current WA-3/WA-4 schema/contracts still make autonomous reply/send structurally impossible;
- existing booking V1 is live;
- unified AGV2 V2 BOOK/REBOOK is not yet in PROD;
- PR #409 is Draft;
- future schedule rows = 91, overall freshness through `2026-09-30`;
- 182 active services;
- 94 canonical procedures;
- 182/182 active services currently lack explicit `duracion_sesion`;
- governed Meta campaign context map rows = 0;
- current canary data has no real Click-to-WhatsApp referral/ad proof;
- legacy Supabase RLS debt remains a gate for general autonomous rollout, not a reason to blindly enable RLS across all tables.

Counters must be re-read live after any mutation; these are checkpoint values, not permanent constants.

## Clinical and Team authority closed

Professional service/skill hierarchy is no longer a flat SKU list.

`service/SKU → canonical procedure → parent skill → role → professional scope`.

Admin Team now supports categories, parent skills and child procedures, with explicit scope freeze to prevent future child procedures from auto-granting accidentally.

Panel Roles/Permissions are also governed: a user sees authorized panels based on selected access, including mixed ADMIN + operational panels. César level 1 remains supreme/non-delegable.

## Booking authority CURRENT

Target chain:

`service/SKU → procedure → skill → role → professional → site/date schedule → duration/capacity/resource → real slot → BOOK/REBOOK`.

Already achieved:

- treatment role detection;
- doctor exact-provider semantics;
- nursing site-pool semantics;
- professional skill/procedure eligibility;
- date/site schedule authority;
- real slot resolver;
- governed booking V1;
- strong Agenda status transaction;
- performance/index improvements.

Still required before autonomous booking is production-grade:

- procedure duration/buffer/capacity/resource authority;
- unified transactional BOOK/REBOOK V2 in PROD;
- post-commit provider side effects;
- live business-hours smoke.

## AGV2-1 — BUSINESS FROZEN

Frozen commercial rules:

- do not ask doctor vs nurse;
- first real availability by default;
- provider preference only when explicitly requested and valid;
- if one provider is valid, do not show fake provider choices;
- trusted WhatsApp phone is reused;
- name/surname collected when needed;
- email recommended but optional;
- DNI optional for normal booking;
- no hardcoded free evaluation;
- free text remains valid;
- buttons/lists only for discrete decisions such as site/date/slot/confirm/rebook;
- initially show up to 3 real dates and up to 5 real slots;
- explicit final booking confirmation;
- slot revalidation under lock;
- REBOOK preserves the same logical appointment and append-only history;
- email/Meta confirmation/reminders are post-commit side effects.

## AGV2-2 — CURRENT

PR #409 contains additive/dormant V2 contracts shared by internal Agenda and WhatsApp:

- idempotent BOOK/REBOOK operation ledger;
- append-only appointment event ledger;
- common booking core;
- common rebooking core;
- Agenda strong-session wrapper;
- WhatsApp conversation owner + active assignment wrapper;
- identity conflict fail-closed;
- slot check before and after advisory lock;
- existing V1 preserved until V2 rollout is certified.

Current exact test condition at capture:

- WA-4C FULL LOCAL = PASS;
- dedicated AGV2 gate = FAIL before BOOK because the reduced test fixture lacks `aos_booking_capability_for_service_v1(uuid)`;
- fix the fixture/substrate, not product semantics.

## Autonomous agent boundary

Autonomy is a new authority, not a flag flip.

Required runtime:

`semantic conversation state → governed facts → commercial policy → safety/quality → tool selection → autonomous authority → idempotent provider send`.

Required controls:

- `AUTO_OFF | CANARY | PROD`;
- allowlist by number/conversation/campaign;
- budget;
- max turns;
- rate limit/cooldown;
- duplicate protection;
- kill switch;
- human takeover/handoff;
- clinical/safety/identity/provider errors fail to human.

Never allow direct LLM → Meta or direct LLM → arbitrary SQL.

## Meta campaign operating model

ASCENDA does not require a separate ManyChat-style flow per campaign. One governed Revenue Agent can use explicit Meta referral/ad evidence to select campaign context.

Required governed mapping:

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy`.

No treatment or attribution inference from campaign naming alone. Organic stays organic without evidence.

Before campaign attribution is certified, require a real CTWA canary:

`ad → signed referral webhook → conversation/touchpoint → governed campaign context → booking/rebook → attendance → sale`.

## Confirmations and reminders

Existing email infrastructure is already operational and includes transaction types for booking confirmation, reminders, no-show and reprogramming.

New rule:

`DB COMMIT → event/outbox → provider send → provider status/retry`.

Provider failure must never undo or duplicate a valid booking.

WhatsApp notifications outside the customer service window require approved/active Meta templates where policy requires them.

## Cost Intelligence

Build cost from evidence already modeled:

- Meta `pricing_category`, `pricing_model`, `billable` and provider billing evidence;
- AI provider/model/tokens/latency/estimated cost;
- conversation/messages;
- booking/rebook;
- attendance;
- sale/revenue.

Unknown Meta cost remains UNKNOWN.

Target mini-panel per chat: Meta cost, AI cost, messages, booking/rebook, attendance, sale, revenue, cost/conversation, cost/booking, cost/attendance, cost/sale and revenue/cost.

## Current release loop

Authoritative order from issue #410:

`L0 baseline → L1 BOOK/REBOOK V2 → L2 duration/capacity/resources → L3 confirmations/reminders → L4 autonomous authority → L5 conversational booking/rebooking → L6 Meta attribution → L7 cost intelligence → L8 selective security hardening → L9 autonomous demo → L10 limited production canary → L11 gradual general production`.

Do not enable autonomous send before L1–L3 are closed.

## Next action

Fix the AGV2 reduced fixture, rerun dedicated AGV2 + WA-4C FULL LOCAL on canonical self-hosted Linux, exact-head/anti-drift, merge PR #409 only if green, apply merged lineage to PROD dormantly, read back V2, then continue L2.

Related CURRENT docs:

- `docs/control/WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT.md`
- `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
- `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`
- `docs/adn/AGENTS_CURRENT.md`
- GitHub issue #410
