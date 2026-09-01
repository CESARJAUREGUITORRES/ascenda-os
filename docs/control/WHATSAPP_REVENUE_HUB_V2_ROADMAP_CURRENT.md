# ASCENDA Conversations — WhatsApp Revenue Hub V2 — ROADMAP CURRENT

**Captured:** 2026-09-01 America/Lima  
**Entry main:** `66ac1bfaa92465f061c243578607388926970c32`  
**ACTIVE EXECUTION LOOP:** GitHub issue #410 — `WA-AUTO · Autonomous Revenue Agent Production Loop`  
**ACTIVE GATE:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`

## North Star

`Meta Ads / Organic / QR / Web → WhatsApp → explicit provenance → autonomous governed conversation → canonical identity/privacy → current knowledge/price → real booking authority → BOOK/REBOOK → confirmations/reminders → attendance → sale → attribution + cost → learning`.

The current production goal is no longer only Copilot. Required staged release:

`AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`.

## Achieved foundation

- secure WhatsApp ingress/store/conversation projection;
- ownership/assignment/human outbound;
- commercial AI Copilot/runtime;
- governed Knowledge Fabric + commercial playbook + current price authority;
- canonical patient identity integration;
- campaign/referral adapter;
- clinical category/skill/procedure hierarchy;
- explicit professional procedure scope freeze;
- Team panel/permission authority;
- date/site/professional booking availability;
- governed booking V1;
- Call Center/Agenda P0 performance hardening;
- canonical self-hosted Linux FULL LOCAL regression;
- existing transactional email confirmation/reminder pipeline.

## CURRENT blockers to autonomous production

1. AGV2-2 BOOK/REBOOK V2 is not yet in PROD.
2. Procedure duration/buffer/capacity/resource authority is missing; 182/182 active services currently lack explicit `duracion_sesion`.
3. Booking confirmation/reminder provider sends are not yet driven from the new BOOK/REBOOK event ledger.
4. Current WA-3/WA-4 contracts structurally prohibit auto-reply/AI-send.
5. Real Click-to-WhatsApp referral/campaign mapping has not been demonstrated; governed campaign map currently has 0 rows.
6. Meta/AI cost journey is only partially evidenced.
7. Autonomous-surface security/RLS hardening remains before general traffic.

## Frozen architecture rules

- no second CRM/customer/patient/sales/agenda/email/price master;
- canonical patient identity remains external authority;
- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`;
- `ATTRIBUTION EVIDENCE != CONSENT`;
- `LIVE PRICE AUTHORITY != DOCUMENT EXAMPLE PRICE`;
- `LLM OUTPUT != BUSINESS FACT AUTHORITY`;
- `LLM OUTPUT != DIRECT META SEND AUTHORITY`;
- `BOOK/REBOOK TRANSACTION != PROVIDER SIDE EFFECT`;
- `REBOOK != DELETE + CREATE UNRELATED APPOINTMENT`;
- TEST/local certification never substitutes LIVE/provider canary evidence.

## Booking architecture frozen

`service/SKU → procedure → skill → role → eligible professional → site/date schedule → duration/capacity/resource → real slot → BOOK/REBOOK`.

- role is derived; do not ask doctor vs nurse;
- doctor exact-provider;
- nursing site-pool unless explicitly redesigned;
- one eligible provider means no fake provider selection;
- provider preference only when explicit and valid;
- no invented slot if any authority is absent/stale;
- final slot revalidated under lock;
- REBOOK preserves same logical appointment and event history.

## AGV2-1 — BUSINESS FROZEN ✅

- first real availability by default;
- trusted WhatsApp phone reused;
- collect name/surname when needed;
- email recommended/optional;
- DNI optional for normal booking;
- no hardcoded free evaluation;
- inbound commercial booking defaults to `CONSULTA NUEVA` unless canonical context proves another type;
- free text stays valid;
- buttons/lists only for discrete site/date/slot/confirm/rebook decisions;
- initial UX: up to 3 dates + 5 slots, then more;
- explicit confirmation before BOOK;
- confirmations/reminders are post-commit side effects.

## L0 — Baseline / anti-drift

Exit requires exact main/head, Railway, Supabase, runner, safety flags, schedule/skills/campaign/email snapshots and frozen fixtures.

Current entry: main `66ac1bfa...`, Copilot ON, auto-reply/AI-send/auto-routing OFF, human-send ON.

## L1 — AGV2-2 Unified BOOK/REBOOK — ACTIVE

PR #409 contains additive/dormant V2:

- booking operation ledger;
- append-only agenda event ledger;
- shared BOOK core;
- shared REBOOK core;
- Agenda strong-session wrapper;
- WhatsApp owner + active-assignment wrapper;
- identity conflict fail-closed;
- pre/post-lock slot revalidation;
- V1 compatibility preserved.

Current test state:

- WA-4C FULL LOCAL = PASS;
- dedicated AGV2 canary = FAIL before BOOK because reduced fixture lacks `aos_booking_capability_for_service_v1(uuid)`;
- fix fixture/substrate only; do not weaken production semantics.

Exit:

`dedicated AGV2 PASS + WA-4C FULL LOCAL PASS → exact-head → anti-drift → Ready/merge #409 → apply migrations from merged lineage → PROD dormant readback`.

## L2 — Slot Authority V2: duration / capacity / resources

Create explicit authority at canonical procedure level:

`procedure → duration → buffer → capacity → resource/cabin`.

Commercial SKU variants inherit procedure rules unless explicit override exists.

Must cover at least representative Toxina, Cellbooster/Biorevitalización, HIFU, Hidrofacial and Criolipólisis canaries.

Fail closed when required timing/resource authority is missing.

## L3 — Post-commit confirmations / reminders

`BOOKED/RESCHEDULED → event/outbox → WhatsApp/email provider dispatch → provider status/retry`.

Reuse current email confirmation/reminder/reprogramming infrastructure.

Never send provider side effects inside the DB booking transaction.

WhatsApp notifications outside the customer-service window use approved/active Meta templates as required.

## L4 — WA-AUTO Autonomous Send Authority

Replace structural prohibition with a new governed authority, not an unrestricted ON switch.

Required:

- `AUTO_OFF | CANARY | PROD`;
- allowlists by phone/conversation/campaign;
- daily budget;
- max turns;
- rate limit/cooldown;
- duplicate guard;
- kill switch;
- human takeover;
- deterministic handoff for clinical/safety/identity/provider/unsupported conditions.

Pipeline:

`Runtime → governed facts → policy → safety/quality → tool decision → send authority → idempotent Meta outbound`.

No direct LLM → Meta/SQL.

L4 cannot activate before L1–L3 close.

## L5 — Conversational BOOK / REBOOK wiring

- booking readiness HIGH drives real site/date/slot flow;
- buttons/lists for discrete choices; free text still works;
- reuse phone;
- name required only when absent;
- email/DNI optional;
- natural-language `RESCHEDULE_INTENT`;
- identity/privacy gate before reading appointment;
- REBOOK same appointment;
- conversation memory continues after booking/rebooking.

Exit: allowlisted conversation can BOOK and REBOOK without human action.

## L6 — Meta Campaign Context & Attribution

Gateway already preserves explicit referral/ad evidence when provider sends it.

Build governed mapping:

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy`.

Never infer by campaign name.

Required real CTWA canary:

`ad → signed webhook/referral → conversation/touchpoint → campaign context → BOOK/REBOOK → attendance → sale`.

Organic stays explicitly organic.

## L7 — WhatsApp / AI Cost Intelligence

Reconcile evidence:

- Meta pricing category/model/billable/provider billing;
- AI model/tokens/latency/estimated cost;
- messages;
- booking/rebook;
- attendance;
- sale/revenue.

Unknown provider cost remains UNKNOWN.

Target mini-panel per chat + cost/conversation, booking, attendance, sale and revenue/cost KPIs.

## L8 — Security Gate for autonomous canary

Supabase has substantial legacy RLS debt. Do not blindly enable RLS globally.

Before general autonomous rollout:

- harden exact WhatsApp/Agenda tables/RPCs touched by autonomy;
- remove/retire replaced browser direct writes;
- keep secrets server-only;
- signed webhook/replay/idempotency;
- redact PII/PHI from AI/logging paths.

## L9 — AUTONOMOUS DEMO READY

Allowlisted LIVE scenario must show:

`real WhatsApp/Meta entry → autonomous grounded sale conversation → price/objection → real availability → BOOK appears in Agenda → email + WhatsApp confirmation → customer asks natural-language rebook → same appointment changes + history → updated confirmation → attribution/cost visible`.

Exit: `AUTONOMOUS DEMO READY = PASS`.

## L10 — AUTONOMOUS PRODUCTION CANARY

One limited campaign/audience, kill switch, human takeover, error/latency/cost/booking observability and conversation review.

Exit: `AUTONOMOUS PRODUCTION CANARY = PASS`.

## L11 — GENERAL PRODUCTION

Gradual expansion, SLO/error budget, monitoring/alerts, security backlog by batches and rollback/recovery runbook.

Exit: `WHATSAPP REVENUE AGENT = GENERAL PRODUCTION CERTIFIED`.

## Runner / CI rule

Canonical Linux runner is `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`.

Temporary GitHub-hosted fallback was removed after Linux returned. Runner autoboot is installed but remains unverified until a real Windows restart/login proves automatic WSL + runner reconnect.

Any main advance requires exact-head reconciliation of the active functional PR before merge.

## Immediate resume

Start at **L1 only**:

`fix reduced AGV2 fixture → rerun AGV2 + WA-4C FULL LOCAL Linux → exact-head/anti-drift → merge #409 → PROD dormant V2 readback → L2`.
