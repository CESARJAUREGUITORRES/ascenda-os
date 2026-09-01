# ASCENDA Conversations — Autonomous Revenue Agent — CURRENT

**Captured:** 2026-09-01 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Production target:** `AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`  
**Authoritative execution loop:** GitHub issue `#410 — WA-AUTO · Autonomous Revenue Agent Production Loop`  
**Entry main:** `66ac1bfaa92465f061c243578607388926970c32`

## Product definition frozen

Production is not merely an advisor Copilot. The target product must demonstrate:

`Meta/WhatsApp ingress → campaign/referral context → autonomous commercial conversation → governed price/knowledge → booking intent → real availability → BOOK → WhatsApp/email confirmation → reminders → natural-language REBOOK on the same logical appointment → attendance → sale → attribution + cost`.

The first live rollout is always controlled/allowlisted. General campaign traffic is not authorized until the canary, kill switch, observability and security gates pass.

## CURRENT production truth at this checkpoint

- GitHub `main=66ac1bfaa92465f061c243578607388926970c32`.
- Linux self-hosted runner `ascenda-zero-cost-v2` returned and passed canonical Zero-Cost validation, Performance/ASC-PERF, WA-4C FULL LOCAL, Team Skill Authority, Professional Skill Hierarchy and P0 Call Center/Agenda performance gates.
- Runner autoboot supervisor/WSL startup was installed; final `AUTOBOOT 100%` requires observation after a real Windows restart/login.
- WhatsApp store/provider substrate exists and real inbound/outbound human operation has been demonstrated historically.
- Production safety state at checkpoint: `copilot_enabled=true`, `auto_reply_enabled=false`, `ai_send_enabled=false`, `auto_routing_enabled=false`, `human_send_enabled=true`.
- Automatic AI reply/send is still structurally prohibited by WA-4/WA-3 contracts; it is not a switch that may simply be flipped.
- PROD has `aos_wa4_commit_booking_v1`; unified AGV2 BOOK/REBOOK V2 is not yet in PROD.
- PR #409 is Draft: `AGV2: freeze booking rules + unified Agenda/WhatsApp contract`.
- PR #409 has WA-4C FULL LOCAL PASS, but its dedicated AGV2 canary is still red because the reduced synthetic fixture lacks `aos_booking_capability_for_service_v1(uuid)` before the V2 BOOK call. Do not change production semantics merely to make this fixture pass.
- Current future schedule source has 91 active future rows with freshness through `2026-09-30` overall.
- Clinical skills/procedure matrix is frozen explicitly for all currently selected staff capabilities; no implicit new child procedure should auto-grant after the freeze.
- Team panel authority is governed: selected panels are actual access authority; ADMIN may additionally receive operational panels such as Call Center/Commissions; César level 1 remains supreme and non-delegable.
- Current catalog has 182 active services and 94 canonical procedures for skill hierarchy.
- `duracion_sesion` is missing for all 182 active services. Autonomous slot offering must not pretend procedure duration; AGV2 must introduce procedure-level duration/buffer/capacity/resource authority.
- Meta referral/ad ingestion code already preserves referral source/ad evidence, but current canary data has no real Click-to-WhatsApp referral and `aos_wa4_campaign_context_map_v1` currently has 0 governed campaign mappings.
- WhatsApp message economics fields already include `pricing_category`, `pricing_model`, `billable`; AI-run schema includes tokens/latency/estimated cost. Current canary pricing coverage is incomplete and AI run rows are not yet populated for autonomous execution.
- Existing email subsystem is real and active; confirmation/reminder/reprogramming are transactional categories. Email/Meta side effects must execute after BOOK/REBOOK commit through idempotent outbox/event handling, never inside the DB transaction.
- Supabase advisor reports a critical legacy security debt: many tables remain without RLS. Do not enable RLS globally without policies; harden the exact WhatsApp/Agenda autonomous surfaces first and migrate legacy direct browser writes to governed RPCs before general rollout.

## Clinical / booking truth frozen

Canonical booking chain:

`service/SKU → procedure → skill/capability → role eligibility → professional authority → site/date schedule → duration/capacity/resource → real slot → transactional BOOK/REBOOK`.

Rules:

- Do not ask the customer to choose `DOCTORA` vs `ENFERMERIA`; role is derived from treatment authority.
- DOCTORA uses exact-provider authority.
- ENFERMERIA uses governed site-pool semantics unless a later exact-provider rule is explicitly added.
- If only one valid professional has schedule/capacity, do not show a fake provider choice; inform who will attend after slot resolution.
- Provider preference is honored only when the customer explicitly requests it and the professional is clinically + operationally eligible.
- Never invent slots when schedule freshness, role, skill, child procedure, duration, capacity or resource authority is missing.
- REBOOK preserves the same logical `aos_agenda_citas.id` and appends history; it must not delete the original appointment and create an unrelated second appointment.

## Conversational booking business rules frozen — AGV2-1

- WhatsApp behaves as a conversation, not a long form.
- Default: answer the explicit need, add small useful value, ask one strategic next question.
- Reuse known campaign/treatment/site/context and never re-ask a resolved fact.
- Reuse the trusted inbound WhatsApp phone; do not ask for it again unless the user wants another contact number.
- Collect name + surname when needed.
- Email is recommended for confirmations/reminders but optional for booking.
- DNI/document is optional for normal booking; it may be requested after booking to accelerate reception or when a future explicit governed rule requires it.
- Inbound commercial booking defaults to `CONSULTA NUEVA` unless canonical context proves `APLICACION` or `CONTROL`.
- Do not promise a free evaluation unless governed price/campaign policy proves it.
- Buttons/lists are appropriate for discrete decisions: site, date, slot, confirm, rebook. Free text remains valid and must continue the same state machine.
- Initially show up to 3 real dates and up to 5 real slots, then `Ver más`.
- BOOK requires explicit final confirmation and slot revalidation under lock.
- Customer replies such as `se me complicó`, `puede ser viernes`, `no llego mañana`, `más tarde` must be treated as potential `RESCHEDULE_INTENT`, then pass identity/privacy + active appointment + real availability gates.
- Existing verified/resolved patient journeys should be shorter; no name-only canonical binding and no sensitive appointment disclosure to an unverified sender.

## Autonomous authority rules — new WA-AUTO boundary

The target autonomous path is:

`Runtime/semantic state → governed knowledge + price + campaign facts → deterministic sales/booking policy → safety/quality guard → allowed tool decision → autonomous send authority → idempotent Meta outbound`.

Never:

- allow the LLM to send directly to Meta;
- allow arbitrary SQL/tool execution from model text;
- allow model-generated price/promotion/availability/clinical fact to become authority;
- auto-diagnose, prescribe, determine candidacy or handle adverse-event clinical decisions autonomously;
- expose another person's appointment/history on phone/name coincidence;
- bypass identity conflict, slot conflict, strong-session/human takeover, budget or kill-switch controls.

Autonomous control must introduce `AUTO_OFF | CANARY | PROD`, allowlist boundaries, max turns, daily budget, rate limits, cooldown, duplicate protection, kill switch and human handoff.

## Campaign / Meta operating model

ASCENDA does not need a separate ManyChat-style flow per ad. One Revenue Agent may receive many campaign entries, while explicit Meta referral/ad evidence selects governed context.

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy` must be an explicit governed mapping with evidence. Never infer treatment or attribution from an ad/campaign name alone.

Organic ingress remains explicitly organic when no campaign evidence exists.

Required live proof before production attribution claims:

`real Click-to-WhatsApp → signed webhook/referral → conversation/touchpoint → governed campaign map → BOOK/REBOOK → attendance → sale/revenue`.

## Cost Intelligence target

Per conversation/journey reconcile where evidence exists:

- Meta pricing category/model/billable status and actual provider pricing basis;
- AI provider/model/tokens/latency/estimated cost;
- inbound/outbound count;
- BOOK/REBOOK;
- attendance/no-show;
- sale/revenue.

Target UI popup: conversation cost, Meta cost, AI cost, booking/rebook outcome, attendance, sale, revenue and derived cost/conversation, cost/booking, cost/attendance, cost/sale, revenue/cost.

Do not fabricate missing Meta cost. Unknown remains UNKNOWN until provider/billing evidence closes it.

## Production execution loop — authoritative order

Follow GitHub issue #410 without skipping gates:

1. `L0` baseline / anti-drift / safety snapshot.
2. `L1` close AGV2-2 unified BOOK/REBOOK and promote dormantly to PROD.
3. `L2` duration/buffer/capacity/resource slot authority.
4. `L3` post-commit confirmations/reminders/outbox.
5. `L4` autonomous send authority with CANARY controls.
6. `L5` conversational BOOK/REBOOK wiring.
7. `L6` real Meta campaign context + attribution.
8. `L7` WhatsApp/AI cost intelligence.
9. `L8` selective security hardening for autonomous surfaces.
10. `L9` `AUTONOMOUS DEMO READY` live allowlisted scenario.
11. `L10` `AUTONOMOUS PRODUCTION CANARY` on one limited campaign/audience.
12. `L11` gradual general production.

Do not activate L4 autonomous send before L1–L3 provide a reliable transactional/action boundary.

## Mandatory next-chat bootstrap

When a new chat/session resumes this project:

1. read `docs/adn/AGENTS_CURRENT.md`;
2. read `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
3. read `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. read this file;
5. read GitHub issue #410;
6. inspect PR #409 CURRENT head and exact workflow results;
7. re-read live Supabase flags/functions/schedule/campaign-map state;
8. re-read exact GitHub `main` and reconcile any drift before write;
9. never trust stale chat assertions over CURRENT + GitHub + PROD readback.

Immediate resume point at capture: **finish L1 by fixing the AGV2 reduced canary fixture, not product semantics; rerun dedicated AGV2 + WA-4C FULL LOCAL on self-hosted Linux, then exact-head/anti-drift/merge and PROD dormant readback.**
