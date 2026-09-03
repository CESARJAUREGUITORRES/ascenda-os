# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-02 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**WA-L4:** `CLOSED · PRODUCTION CERTIFIED · AUTO_OFF · SAFE-OFF`  
**L4 implementation/deploy main:** `1402361923977db9ffdcaa047f21e8775b595e10`  
**GitHub authority:** Issue `#443` · PR `#444`  
**NEXT ELIGIBLE:** `WA-L5 — Conversational BOOK/REBOOK Wiring`  
**CANARY:** `NOT AUTHORIZED` — requires a separate explicit owner authorization.

## WA-L4 production certificate

L4 autonomous authority is installed in production but remains completely dormant:

- authority mode = `AUTO_OFF`;
- global kill switch = `ENGAGED`;
- effective autonomous send = `false`;
- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- active L4 allowlist = `0`;
- autonomous decisions = `0`;
- autonomous outbound requests = `0`;
- autonomous messages = `0`;
- no autonomous provider dispatch authorized.

Frozen L4 safety budgets:
- daily messages = `20`;
- max turns/conversation = `8`;
- global rate/min = `6`;
- conversation rate/min = `2`;
- cooldown = `15s`;
- duplicate window = `120s`.

## Certified architecture

WA-L4 provides:
- centralized DB-first `AUTO_OFF | CANARY | PROD` authority;
- global kill switch;
- server-only allowlist for PHONE / BSUID / CONVERSATION / CAMPAIGN;
- daily/turn/rate/cooldown/duplicate budgets;
- provider idempotency authority before dispatch;
- provider-verified template gate;
- clinical/safety/identity/human-ownership handoff;
- append-only hashed authority/control audit without raw model prompt/reply;
- HUMAN/AUTO outbound lineage;
- internal-only autonomous send route;
- fail-closed recovery that preserves provider/audit history.

Direct browser control is prohibited. `anon` and `authenticated` cannot read or execute L4 control authority. `service_role` has read access to L4 state but no direct UPDATE/INSERT on authority/allowlist ledgers; state mutation is through governed SECURITY DEFINER RPCs.

## CI / anti-drift certificate

Exact certified PR head: `113d636d9bc7180f9f37b421a8b3c46f8af9473d`.

10/10 exact-head workflows PASS:
- Ascenda CI;
- ASCENDA ASC-PERF Audit 360;
- ASCENDA Phase 4 Revenue Operations;
- ASCENDA WA-L4 Autonomous Authority;
- Sentinel F6 Business Health Certificate;
- ASCENDA WA-1 Secure WhatsApp Gateway;
- ASCENDA WA-4C FULL LOCAL Integration;
- ASCENDA Cartera Phase 2 Hardening;
- ASCENDA PHASE S WA3 Stabilization;
- ASCENDA Performance Guard CI.

Anti-drift before merge: branch `ahead 14 / behind 0` over `main@ee05aee59af5e145d62228a7cab27aaf597bd8f8`.
PR #444 merged with expected-head lock. Railway status for `1402361923977db9ffdcaa047f21e8775b595e10` = SUCCESS.

The WA4C red gate was a calendar-dependent test defect: the stale-schedule fixture landed on Sunday and correctly hit `WA4_BOOKING_SUNDAY_CLOSED` before schedule-staleness. The test was made calendar-stable by choosing a non-Sunday stale date; production booking logic was not weakened or reordered.

## LIVE DDL / readback

Applied to Supabase PROD `ituyqwstonmhnfshnaqz`:
- `wa_l4_autonomous_authority_v1`;
- `wa_l4_authority_hardening_v1`.

L4 tables and governed RPCs exist. LIVE ACL/readback verifies:
- `anon` authority SELECT = false;
- `authenticated` authority SELECT = false;
- `service_role` authority SELECT = true;
- `service_role` direct authority UPDATE = false;
- `service_role` direct allowlist INSERT = false;
- `anon/authenticated` set-control EXECUTE = false;
- `service_role` set-control EXECUTE = true.

## Mandatory cross-module regression certificate

Post-L4 LIVE baselines:
- Agenda = `3,205` rows;
- Call Center = `37,039` calls;
- Marketing = `6,688` leads;
- Ventas = `1,391`, all certified 2026; pre-2026 sales = `0`;
- Pacientes = `7,757` total / `7,331` current / `426 FUSIONADO`.

The exact-head regression matrix and LIVE readback show no L4 cross-module regression. The mandatory reliability doctrine remains binding for every WA-L5+ change:
`docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.

## Next boundary

WA-L5 may now become the next HIGH/CRITICAL workstream when explicitly started. Its purpose is conversational BOOK/REBOOK wiring over the already certified Agenda/identity/knowledge/authority layers.

**Important:** L4 closure does not authorize `AUTO_OFF → CANARY`. No allowlist entry, auto-reply, AI-send, autonomous routing or autonomous Meta dispatch may be enabled until a separate explicit CANARY authorization is recorded and its own gates pass.
