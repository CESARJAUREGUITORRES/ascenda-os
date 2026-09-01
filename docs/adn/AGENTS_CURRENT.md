# ASCENDA OS — AGENTS CURRENT OVERLAY

**Applies to:** every CURRENT ASCENDA agent/chat  
**Captured:** 2026-09-01 America/Lima  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE EXECUTION LOOP:** `WA-AUTO · Autonomous Revenue Agent Production Loop` — GitHub issue #410  
**ENTRY MAIN:** `66ac1bfaa92465f061c243578607388926970c32`  
**ACTIVE TECHNICAL GATE:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`

This overlay supersedes operational assumptions in historical `docs/adn/AGENTS.md` and earlier CURRENT snapshots while preserving them as provenance.

## Mandatory bootstrap before any write

1. root `AGENTS.md` + `SECURITY.md`;
2. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
3. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
4. `docs/MEMORY_CURRENT.md`;
5. `docs/control/ASCENDA_AGENT_BOOTSTRAP_CURRENT.md`;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT.md`;
8. GitHub issue #410;
9. PR #409 CURRENT head + workflow evidence;
10. exact GitHub `main`, Railway exact deployment/runtime and live Supabase state;
11. Notion Control Maestro / Roadmap only after technical truth is re-read.

Historical docs/chat statements never override CURRENT + exact GitHub + live persisted state.

## Portfolio Controller

Declare `WORKSTREAM_ID=WHATSAPP-REVENUE-HUB-V2`.

Only one HIGH/CRITICAL mutable lane at a time. Current lane is WhatsApp + its strict Agenda V2 dependency. Marketing Loop 6, Revenue, CIA, KronIA and unrelated mutation remain read-only/regression-only unless a narrowly documented dependency is required.

## Current production product boundary

Target product is no longer merely Copilot. Required production journey:

`Meta/referral → autonomous commercial conversation → governed facts/price → real availability → BOOK → confirmation/reminders → natural-language REBOOK same appointment → attendance → sale → attribution/cost`.

Rollout stages are mandatory:

`AUTONOMOUS DEMO READY → AUTONOMOUS PRODUCTION CANARY → GENERAL PRODUCTION`.

Never jump directly to unrestricted traffic.

## WhatsApp / AI Agent

CURRENT safety snapshot at capture:

- Copilot ON;
- human send ON;
- auto reply OFF;
- AI send OFF;
- auto routing OFF;
- autonomous send is structurally prohibited by current WA-3/WA-4 contracts.

Autonomous authority must be a new governed boundary, not a blind flag flip. Required path:

`Runtime → governed knowledge/price/campaign facts → deterministic policy → safety/quality → tool decision → send authority → idempotent Meta outbound`.

Never let LLM output directly call Meta, arbitrary SQL or unrestricted tools.

Required autonomous controls: `AUTO_OFF | CANARY | PROD`, allowlist, daily budget, max turns, rate limit, cooldown, duplicate guard, kill switch, handoff.

Clinical/adverse-event/identity-conflict/provider-error/unsupported cases must hand off to human.

## Conversational Sales Agent

Frozen behavior:

- one useful customer turn → one outbound by default;
- answer explicit need before advancing the sale;
- use known campaign/treatment/site/context and do not repeat questions;
- stop over-selling when booking readiness is HIGH;
- free text remains primary; buttons/lists only for discrete choices such as site/date/slot/confirm/rebook;
- do not promise free evaluation unless governed commercial authority proves it;
- no invented price/promo/availability/clinical facts.

## Patient Identity / Privacy Agent

- reuse canonical ASCENDA identity; no second customer master;
- phone/channel evidence may accelerate low-risk flow but name-only binding is forbidden;
- identity conflict fails closed;
- sensitive appointment/history disclosure requires sufficient verification;
- trusted WhatsApp phone is reused for booking rather than re-asked;
- name/surname collected when needed;
- email recommended but optional for normal booking;
- DNI/document optional for normal booking unless a future explicit governed policy says otherwise;
- clinical intake remains outside sales conversation unless specifically required.

## Booking / Agenda Agent

Canonical chain:

`service/SKU → procedure → skill → role → eligible professional → site/date schedule → duration/capacity/resource → real slot → BOOK/REBOOK`.

Frozen rules:

- never ask customer to choose doctor vs nurse; derive role;
- doctor = exact-provider;
- nursing = governed site-pool unless explicitly redesigned;
- if only one professional is eligible/available, do not show fake provider choice;
- provider preference only if explicitly requested and valid;
- no slot without fresh schedule + clinical skill + child procedure + duration/capacity/resource authority;
- final slot must be revalidated under lock;
- REBOOK changes the same logical appointment and appends history; never delete/create unrelated replacement;
- BOOK/REBOOK DB transaction must not synchronously send email/Meta side effects.

AGV2-1 business rules are frozen. PR #409 implements AGV2-2 but remains Draft until its dedicated canary passes.

## Clinical Skill Authority Agent

- Team category/skill/procedure hierarchy is the booking skill authority;
- current professional procedure scopes were explicitly frozen after admin configuration;
- a newly added child procedure must not auto-grant to existing staff;
- preserve role-incompatible restrictions;
- HIFU remains doctor-only where catalog authority says so;
- products/operational supplies are not bookable clinical procedures;
- do not mutate staff clinical competence automatically.

## Meta / Attribution Agent

Gateway already captures explicit referral/ad evidence when Meta provides it. Do not infer treatment or attribution from campaign/ad names.

Governed campaign context must be explicit:

`ad_id/campaign_id → treatment/promotion/booking_goal/media strategy`.

At capture, governed campaign-map rows in PROD are 0 and current canary messages do not yet prove real Click-to-WhatsApp referral. A real CTWA canary is mandatory before claiming campaign attribution.

Organic traffic remains explicitly organic when no campaign evidence exists.

## Confirmation / Reminder Agent

Email infrastructure is already operational. Booking side effects must be post-commit and idempotent:

`BOOKED/RESCHEDULED event → outbox/provider dispatch → email/WhatsApp → status audit/retry`.

Provider failure must not roll back or duplicate a valid appointment.

Outside the Meta customer-service window, WhatsApp notification sends must use approved/active templates as required by provider policy.

## Cost Intelligence Agent

Track only evidenced economics:

- Meta pricing category/model/billable;
- provider billing evidence where available;
- AI provider/model/tokens/latency/estimated cost;
- conversation/message counts;
- booking/rebook/attendance/sale/revenue.

Unknown Meta cost remains UNKNOWN; never fabricate it.

Target KPIs: cost/conversation, cost/booking, cost/attendance, cost/sale, revenue/cost.

## Performance Agent

Call Center/Agenda P0 reduced repeated/high-I/O paths and introduced governed Agenda status write. Preserve the rule: fix query amplification and transactional design before assuming infrastructure upgrade is the solution.

Do not reintroduce browser-side multi-request pseudo-transactions for a single business action.

## Security Guardian

- root `SECURITY.md` remains authoritative;
- no PII/PHI/secrets in GitHub/public artifacts;
- no Meta/Groq/Resend tokens in chat, Git, Notion, frontend or logs;
- no autonomous diagnosis/prescription/candidacy;
- no arbitrary SQL from AI;
- exact Auth/2FA/owner/assignment boundaries remain authoritative where applicable;
- Supabase currently has significant legacy tables without RLS; do not enable RLS globally without policies;
- harden exact autonomous WhatsApp/Agenda surfaces first and migrate direct browser writes to governed RPCs before general rollout.

## CI / Runner Governor

- self-hosted Linux canonical label: `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`;
- Windows `ascenda-fast` remains a separate lane where still configured;
- runners are execution capacity, never source of truth;
- exact commit/diff + live post-conditions are authority;
- any `main` advance requires active PR exact-head reconciliation/revalidation;
- no temporary GitHub-hosted fallback unless owner explicitly authorizes it for a named boundary;
- runner autoboot has been installed but is not `100%` certified until a real restart/login proves automatic recovery.

## Historian / Continuity Manager

For every material gate:

1. re-read exact main + active PR head;
2. freeze exact workflow evidence;
3. read live production invariants;
4. record drift and supersede stale claims explicitly;
5. update CURRENT GitHub docs;
6. update Notion last;
7. never mark a provider/user-visible gate `100%` without physical/live evidence when required.

## Immediate resume point

Do not start autonomous send yet.

Resume issue #410 at `L1`:

1. fix the reduced AGV2 canary fixture so it contains the CURRENT booking capability authority;
2. do not weaken or change production semantics merely to pass the fixture;
3. rerun dedicated AGV2 + WA-4C FULL LOCAL on self-hosted Linux;
4. exact-head + anti-drift;
5. Ready/merge PR #409 only after PASS;
6. apply AGV2 migrations from merged lineage to PROD;
7. read back dormant BOOK/REBOOK functions/tables/guards;
8. then continue L2 duration/capacity/resource authority.
