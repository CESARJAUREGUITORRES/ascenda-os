# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-09-01 America/Lima  
**Entry main:** `66ac1bfaa92465f061c243578607388926970c32`  
**ACTIVE LOCK:** `WA-AUTO · Autonomous Revenue Agent Production Loop`  
**ACTIVE TECHNICAL GATE:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`  
**Authoritative loop:** GitHub issue #410

## Execution rule

Only one HIGH/CRITICAL mutable workstream at a time. WhatsApp Revenue Hub V2 owns that lane. Agenda V2 is allowed only as a strict dependency of the autonomous WhatsApp production goal. All other HIGH/CRITICAL workstreams remain read-only/regression-only unless a narrowly documented dependency is required.

Preserved: REV-F5/F6 certified upstream inputs; Marketing Loop 6 paused; CIA/Sentinel/KronIA/unrelated mutation read-only/regression-only.

## Current objective

Move from controlled Copilot/HUMAN_ONLY operation to a governed autonomous revenue agent that can prove:

`Meta ingress/referral → campaign context → autonomous commercial conversation → governed price/knowledge → real availability → BOOK → WhatsApp/email confirmation → reminders → natural-language REBOOK same appointment → attendance → sale → attribution/cost`.

Rollout must be staged:

`AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`.

## Current safety state

At capture PROD remains:

- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`.

Current WA-3/WA-4 contracts structurally prohibit autonomous send. Do not bypass those checks or mutate flags directly. Autonomous send requires a new governed authority with canary controls.

## Frozen separations

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`

`ATTRIBUTION EVIDENCE != CONSENT`

`LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`

`COMMERCIAL PHASE != CLINICAL LIFECYCLE`

`PROCESS TEMPLATE != PATIENT-SPECIFIC PRESCRIPTION`

`LLM OUTPUT != BUSINESS FACT AUTHORITY`

`LLM OUTPUT != DIRECT META SEND AUTHORITY`

`BOOK/REBOOK TRANSACTION != PROVIDER SIDE EFFECT`

`REBOOK != DELETE OLD + CREATE UNRELATED NEW APPOINTMENT`

`TEST CERTIFICATION != LIVE CANARY CERTIFICATION`

## Frozen booking authority

`service/SKU → procedure → skill/capability → role → eligible professional → site/date schedule → duration/capacity/resource → slot → BOOK/REBOOK`.

Rules:

- do not ask patient to choose doctor vs nurse; derive role;
- doctor exact-provider;
- nursing governed site-pool unless explicitly redesigned;
- if only one valid professional, do not offer a fake provider choice;
- provider preference only if explicitly requested and valid;
- never invent availability;
- no autonomous slot offering while required duration/capacity/resource authority is missing;
- final slot is revalidated under lock;
- REBOOK keeps the same logical appointment id and appends event history.

## Frozen conversational booking rules

- use known conversation/campaign facts first;
- one useful question at a time;
- reuse trusted WhatsApp phone;
- collect name/surname when needed;
- email recommended but optional;
- DNI optional for normal booking;
- no hardcoded free evaluation;
- site/date/slot/confirm/rebook may use buttons/lists; free text remains accepted;
- existing verified patient flows should be shorter;
- no name-only canonical identity binding;
- no sensitive appointment/history disclosure to unverified sender.

## AGV2-2 current gate

PR #409 is Draft and is the only current functional mutation allowed.

It contains additive/dormant V2 contracts for shared Agenda/WhatsApp BOOK + REBOOK, idempotency, operation ledger, append-only event ledger, strong Agenda session, WhatsApp owner/assignment checks and double slot revalidation.

Current test state at capture:

- WA-4C FULL LOCAL = PASS;
- dedicated AGV2 canary = FAIL before BOOK because the reduced synthetic fixture lacks `aos_booking_capability_for_service_v1(uuid)`;
- corrective action is to align the test fixture/substrate with CURRENT authority;
- production semantics must not be weakened to make the fixture green.

PR #409 must not merge until dedicated AGV2 and WA-4C FULL LOCAL are both PASS at exact head.

## Next gate order — issue #410

1. L1 — AGV2-2 unified BOOK/REBOOK.
2. L2 — procedure duration/buffer/capacity/resource authority.
3. L3 — post-commit WhatsApp/email confirmation/reminder outbox.
4. L4 — autonomous send authority with `AUTO_OFF | CANARY | PROD`, allowlists, budgets, rate limits, duplicate guard, kill switch and handoff.
5. L5 — conversational BOOK/REBOOK wiring.
6. L6 — real Meta campaign context + CTWA attribution.
7. L7 — Meta/AI cost intelligence.
8. L8 — selective security hardening of autonomous surfaces.
9. L9 — allowlisted autonomous demo.
10. L10 — limited campaign production canary.
11. L11 — gradual general production.

L4 MUST NOT activate before L1–L3 are closed.

## Meta / attribution rule

Gateway may persist referral/ad evidence provided by Meta. Governed mapping must be explicit:

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy`.

Never infer treatment or revenue attribution from campaign/ad naming alone. At capture PROD campaign context map has 0 governed rows and current canary data does not prove real Click-to-WhatsApp referral; real CTWA canary is mandatory.

## Cost rule

Only evidenced provider economics may be presented. Unknown Meta cost remains UNKNOWN. AI costs may use persisted provider/model/token/latency evidence. Target journey economics are conversation → booking → attendance → sale → revenue.

## Security rule

Supabase has significant legacy RLS debt. Do not enable RLS globally without policies because that may break ASCENDA. Before general autonomous rollout, harden the exact WhatsApp/Agenda surfaces, remove obsolete browser direct writes and move business actions behind governed RPCs.

No secrets/PII/PHI in GitHub/public logs. No autonomous diagnosis/prescription/candidacy. No arbitrary SQL from AI.

## CI / runner rule

Canonical Linux runner: `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`.

The Linux runner is back and canonical gates have passed after temporary hosted fallback removal. Any unrelated `main` advance requires PR #409 exact-head reconciliation/revalidation.

Runner autoboot is installed but remains physically unverified until a real Windows restart/login proves automatic WSL + runner reconnection.

## Resume command

Any new chat/agent must begin by reading:

`AGENTS_CURRENT → AGENT_BOOTSTRAP_CURRENT → WORKSTREAM_LOCK_CURRENT → WHATSAPP_REVENUE_HUB_CURRENT → WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT → issue #410 → PR #409 → exact main/PROD readback`.

Immediate action: **fix the AGV2 reduced fixture, rerun dedicated AGV2 + WA-4C FULL LOCAL on self-hosted Linux, then exact-head/anti-drift/merge #409 and apply V2 dormantly to PROD.**
