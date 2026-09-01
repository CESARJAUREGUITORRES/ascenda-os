# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-09-01 America/Lima  
**ACTIVE PROGRAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE LOOP:** GitHub issue #410 — `WA-AUTO · Autonomous Revenue Agent Production Loop`  
**ACTIVE TECHNICAL GATE:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`  
**ENTRY MAIN:** `66ac1bfaa92465f061c243578607388926970c32`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/adn/AGENTS_CURRENT.md`;
7. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
9. `docs/control/WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT.md`;
10. GitHub issue #410 + active PR #409;
11. exact GitHub/Supabase/Railway/runtime evidence;
12. Notion executive continuity last.

Historical chat/doc snapshots never override exact CURRENT + runtime evidence.

## Portfolio state

- WhatsApp Revenue Hub V2 owns the single HIGH/CRITICAL mutable lane.
- Agenda V2 is allowed only as a strict dependency of the WhatsApp autonomous-production target.
- Marketing Loop 6 remains paused/recoverable.
- REV-F5/F6 remain certified upstream inputs.
- Revenue/CIA/Sentinel/KronIA/unrelated HIGH/CRITICAL work remains read-only/regression-only unless strict dependency.

## Product target now frozen

Required production journey:

`Meta/WhatsApp ingress → campaign/referral context → autonomous commercial conversation → governed current facts/price → real booking availability → BOOK → WhatsApp/email confirmation → reminders → natural-language REBOOK preserving same appointment → attendance → sale → attribution + cost`.

Rollout is staged:

`AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`.

Copilot-only operation is an achieved foundation, not the final production definition.

## Current production safety snapshot

At capture:

- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`.

Current WA-3/WA-4 contracts structurally prohibit autonomous AI send/reply. Do not bypass them. A new governed autonomous authority must be built with `AUTO_OFF | CANARY | PROD`, allowlists, budgets, max turns, rate limits, cooldown, duplicate guards, kill switch and human handoff.

## Achieved WhatsApp / commercial foundation

- secure provider ingress/store/conversation substrate;
- real inbound/outbound human operation historically demonstrated;
- commercial Copilot and multi-turn semantic runtime;
- governed Knowledge Fabric + playbook + current price authority;
- patient identity adapter with fail-closed conflict behavior;
- campaign/referral ingestion adapter;
- response quality/safety regression suite;
- canonical self-hosted Linux WA-4C FULL LOCAL PASS;
- current Linux `ascenda-zero-cost-v2` restored as canonical runner;
- temporary hosted fallback removed.

## Runner continuity

Runner autoboot supervisor/Windows-login→WSL startup has been installed. It is not `100% certified` until a real Windows restart/login proves automatic runner reconnect without manual Ubuntu/sudo start.

## Team / clinical authority achieved

- services/skills are modeled as category → parent skill → child procedure → commercial SKU;
- current staff procedure scopes were explicitly frozen after user configuration;
- newly added child procedures must not auto-grant to existing staff;
- role incompatibilities remain fail-closed;
- Team Roles/Permissions now govern actual panels;
- ADMIN users may additionally receive operational panels such as Call Center/Commissions;
- César level 1 remains supreme/non-delegable;
- removing a panel removes it from the menu/access path rather than relying on role hardcoding.

## Booking / Agenda authority frozen

Canonical chain:

`service/SKU → procedure → skill → role → eligible professional → site/date schedule → duration/capacity/resource → real slot → BOOK/REBOOK`.

Rules:

- do not ask customer doctor vs nurse;
- doctor = exact-provider;
- nursing = governed site-pool unless explicitly redesigned;
- if one valid provider exists, do not show fake provider choice;
- provider preference only if explicitly requested and valid;
- no slot if required authority is missing/stale;
- final slot revalidated under lock;
- REBOOK updates same logical appointment and appends history;
- provider side effects are post-commit.

## AGV2-1 business rules frozen

- first real availability by default;
- trusted WhatsApp phone reused;
- name/surname requested when needed;
- email recommended but optional;
- DNI optional for normal booking;
- no hardcoded free evaluation;
- inbound commercial booking defaults to `CONSULTA NUEVA` unless canonical context proves otherwise;
- free text stays valid;
- buttons/lists are used only for discrete site/date/slot/confirm/rebook decisions;
- initial UX up to 3 dates and 5 slots;
- explicit confirmation before BOOK;
- booking/rebooking confirmation/reminder provider sends occur after DB commit.

## AGV2-2 current state

PR #409 is Draft and implements additive/dormant shared Agenda/WhatsApp BOOK/REBOOK V2:

- idempotent operation ledger;
- append-only appointment event ledger;
- shared BOOK core;
- shared REBOOK core;
- Agenda strong-session wrapper;
- WhatsApp owner + active-assignment wrapper;
- identity conflict fail-closed;
- availability recheck before and after advisory lock;
- same appointment id preserved on rebook;
- V1 remains live until V2 is certified.

Test condition at capture:

- WA-4C FULL LOCAL = PASS;
- dedicated AGV2 canary = FAIL before BOOK because the reduced test fixture lacks `aos_booking_capability_for_service_v1(uuid)`;
- correct fix is the test fixture/substrate, not production semantics.

## Agenda gaps discovered

- 182 active services;
- 94 canonical procedures;
- all 182 active services currently have missing `duracion_sesion`;
- autonomous booking therefore requires procedure-level duration/buffer/capacity/resource authority before real production slot promises;
- future schedule source had 91 active rows and overall freshness through 2026-09-30 at capture; re-read live before use.

## Meta / attribution memory

Gateway already captures referral/ad evidence when provider sends it. Do not infer treatment or attribution from campaign names.

Governed mapping must be explicit:

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy`.

At capture `aos_wa4_campaign_context_map_v1` has 0 governed rows and current canary data has no real CTWA referral/ad evidence. A real Click-to-WhatsApp canary is mandatory before claiming end-to-end campaign attribution.

Organic remains organic when no evidence exists.

## Confirmations / reminders memory

Existing email infrastructure is active and already supports transactional confirmation/reminder/reprogramming categories.

Future BOOK/REBOOK integration must use:

`DB commit → event/outbox → email/WhatsApp provider send → status/retry`.

Provider failures must never roll back/duplicate bookings.

## Cost intelligence memory

Existing WA message model carries `pricing_category`, `pricing_model`, `billable`. AI run model carries provider/model/tokens/latency/estimated cost.

Target journey economics:

`conversation → Meta cost + AI cost → BOOK/REBOOK → attendance → sale → revenue`.

Unknown Meta cost stays UNKNOWN until provider/billing evidence closes it.

## Performance lesson

Call Center/Agenda P0 demonstrated that repeated analytical calls and browser-side multi-request pseudo-transactions caused major latency/HTTP 500 risk. Preserve the rule:

- remove query amplification before assuming hardware upgrade;
- one logical business write should use one governed transactional RPC;
- do not reintroduce PATCH/DELETE/POST chains from browser for one appointment action.

## Security debt

Supabase advisor reports substantial legacy tables without RLS. Do not mass-enable RLS without correct policies because this can break production. Before autonomous general rollout, harden exact WhatsApp/Agenda surfaces and retire obsolete direct browser writes behind governed RPCs.

No secrets/PII/PHI in GitHub/public artifacts. No autonomous diagnosis/prescription/candidacy. No arbitrary SQL from AI.

## Authoritative remaining loop

Issue #410:

`L0 baseline → L1 BOOK/REBOOK V2 → L2 duration/capacity/resources → L3 confirmations/reminders → L4 autonomous authority → L5 conversational BOOK/REBOOK → L6 Meta attribution → L7 cost intelligence → L8 selective security → L9 demo → L10 limited campaign canary → L11 general production`.

Do not activate autonomous send before L1–L3 close.

## Immediate resume point

Start with issue #410 L1 only:

`fix reduced AGV2 fixture → rerun dedicated AGV2 + WA-4C FULL LOCAL on self-hosted Linux → exact-head/anti-drift → merge PR #409 if green → apply merged V2 migrations to PROD dormantly → live readback → L2`.
