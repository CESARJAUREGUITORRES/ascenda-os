# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Captured:** 2026-09-01 America/Lima  
**Entry baseline:** `main@66ac1bfaa92465f061c243578607388926970c32`  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**ACTIVE LOOP:** GitHub issue `#410 — WA-AUTO · Autonomous Revenue Agent Production Loop`  
**ACTIVE TECHNICAL GATE:** `L1 / AGV2-2 Unified BOOK/REBOOK Contract`

## Mandatory bootstrap before any write

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. `docs/MEMORY_CURRENT.md`;
6. `docs/adn/AGENTS_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
8. `docs/control/WHATSAPP_AUTONOMOUS_PRODUCTION_CURRENT.md`;
9. GitHub issue #410;
10. PR #409 CURRENT head + workflow runs;
11. exact GitHub `main`, Railway exact deploy/runtime and live Supabase state;
12. Notion Control Maestro/Roadmap only after technical truth is read.

Historical docs/chat checkpoints never override CURRENT + exact GitHub + live persisted state.

## Portfolio ownership

`WHATSAPP-REVENUE-HUB-V2` owns the single HIGH/CRITICAL mutable lane. Agenda V2 is currently a strict dependency inside that same lane. Marketing Loop 6, Revenue, CIA, KronIA and unrelated mutation remain paused/read-only/regression-only unless a narrowly documented dependency is necessary.

## Current achieved boundary

- WA-4C conversation runtime, Knowledge/Playbook, patient identity, campaign adapter, professional skill hierarchy and booking authority are implemented and have passed canonical Linux FULL LOCAL regression.
- Team clinical skills + procedure children are explicitly frozen after admin configuration.
- Team panel access is governed from Roles/Permissions; mixed ADMIN + operational panels work; César level 1 remains supreme.
- P0 Call Center/Agenda performance changes are merged and canonical Linux gates passed.
- Linux runner is back and `ascenda-zero-cost-v2` is canonical again; GitHub-hosted fallback is removed.
- WSL/runner autoboot was installed; physical restart certification remains pending.
- Production Copilot is ON for assistance; auto reply/AI send/auto routing remain OFF and structurally blocked by current contracts.
- Existing booking V1 remains live; AGV2 V2 is still additive/dormant work in PR #409.

## PR #409 / AGV2-2 exact resume state

PR #409 is Draft and implements:

- frozen AGV2-1 business rules;
- shared Agenda/WhatsApp BOOK core;
- shared REBOOK core preserving same appointment;
- idempotent operation ledger;
- append-only appointment event ledger;
- Agenda strong-session wrapper;
- WhatsApp owner/active-assignment wrapper;
- slot revalidation before/after lock;
- post-commit provider side-effect boundary.

Known blocker at capture:

- WA-4C FULL LOCAL = PASS;
- dedicated AGV2 canary = FAIL before BOOK because reduced synthetic fixture is missing `aos_booking_capability_for_service_v1(uuid)`;
- fix fixture/substrate, not production semantics.

## Production truth that must be re-read on every resume

At capture:

- Copilot ON;
- human send ON;
- auto reply OFF;
- AI send OFF;
- auto routing OFF;
- future schedule rows = 91, overall freshness through 2026-09-30;
- 182 active services;
- 94 canonical procedures;
- all 182 active service `duracion_sesion` values missing;
- governed campaign context mapping rows = 0;
- current canary Meta referral/ad coverage = 0 real CTWA evidence;
- legacy Supabase RLS debt exists and must be handled selectively before general autonomous rollout.

Do not reuse these counters blindly after any new mutation; query live PROD again.

## Frozen Agenda/booking rules

- do not ask doctor vs nurse; derive from treatment authority;
- doctor exact-provider; nursing governed site-pool unless explicitly redesigned;
- if one valid professional, do not offer fake provider choice;
- reuse trusted WhatsApp phone;
- name/surname only when needed;
- email recommended but optional;
- DNI optional for normal booking;
- do not claim free evaluation unless governed commercial authority proves it;
- buttons/lists for site/date/slot/confirm/rebook, free text must still work;
- BOOK requires explicit confirmation + slot revalidation;
- REBOOK mutates the same logical appointment and appends history;
- email/WhatsApp confirmation/reminder dispatch happens after DB commit through idempotent event/outbox logic.

## Autonomous rollout rule

The production target is not a blind `auto_reply=true` switch. Required authority:

`Runtime → governed facts → policy → safety/quality → tool decision → send authority → idempotent Meta outbound`.

Mandatory controls: `AUTO_OFF | CANARY | PROD`, allowlist, budgets, max turns, rate limits, duplicate guard, cooldown, kill switch, human handoff.

Do not start autonomous send before issue #410 L1–L3 are complete.

## Runner rule

Canonical Linux labels: `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`.

Runner autoboot is installed through Windows-login/WSL bootstrap + Linux supervisor. It is only certified after a real restart/login shows the runner reconnects without opening Ubuntu or entering sudo manually.

## Immediate next action

Resume issue #410 `L1` only:

`fix AGV2 reduced fixture → rerun AGV2 + WA-4C FULL LOCAL Linux → exact-head/anti-drift → merge PR #409 → apply merged migrations to PROD → readback dormant V2 → L2 duration/capacity/resource authority`.
