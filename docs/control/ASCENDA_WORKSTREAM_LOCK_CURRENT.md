# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-02 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L4 — Autonomous Authority + Kill Switch`  
**GitHub authority:** Issue `#443`  
**Entry main:** `73a4bab955fffb8a423f8ff07fa8c835df125227`  
**Mandatory PRE-L4 doctrine:** `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md` · freeze commit `f874f9797ed65408f43b4beb3bab6c31603042a1`  
**WA-L4 exact operational state:** `IN DEVELOPMENT · AUTO_OFF · SAFE-OFF`

## Entry safety snapshot

Production remains fail-closed while L4 is built:

- authority mode = `AUTO_OFF`;
- global autonomous state = `SAFE-OFF`;
- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `human_send_enabled=true`;
- no autonomous provider dispatch authorized;
- no direct LLM → Meta authority;
- no direct LLM → SQL authority.

LIVE entry evidence:
- booking operations V2 = `0`;
- Agenda events V2 = `0`;
- L3 delivery outbox V3 = `0`;
- L3 dispatchable = `0`;
- active template registry = `10`;
- active WhatsApp templates = `6`;
- provider-verified WhatsApp templates = `0`;
- existing outbound request ledger = `15` rows / `7` provider message IDs.

## Sole mutable lane

While #443 is open, no other HIGH/CRITICAL workstream may mutate ASCENDA. Other workstreams may perform read-only audit/documentation only.

## L4 implementation boundary

Allowed under `AUTO_OFF`:
- implement explicit authority state machine `AUTO_OFF | CANARY | PROD`;
- global kill switch;
- server-side allowlist;
- daily/message/turn/rate/cooldown/duplicate budgets;
- provider idempotency authority;
- provider-approved-template gate;
- clinical/safety/identity/provider-error handoff;
- append-only authority decision audit/telemetry;
- recovery/rollback;
- runtime wiring that remains dormant in AUTO_OFF;
- CI, isolated DB canaries and production read-only validation.

Forbidden without a separate explicit owner authorization:
- transition effective mode from `AUTO_OFF` to `CANARY`;
- set `auto_reply_enabled=true`;
- set `ai_send_enabled=true`;
- set `auto_routing_enabled=true` for autonomous operation;
- autonomous Meta dispatch;
- bulk sends/broadcasts/campaign activation.

## Mandatory regression boundary

Every L4 exit gate must preserve:
- Agenda governed create/edit/status and transactional booking;
- Call Center next-lead + prepare + commit/confirm hot paths;
- Marketing monthly load without legacy/new duplication or annual fan-out;
- Sales/Commissions exact totals, filters, rules, ownership and responsive reads;
- Patients/Patient 360 canonical search/core rendering and deferred-enrichment survivability;
- current non-FUSIONADO patient master + governed historical aliases with fail-closed conflicts;
- shared Supabase/background pressure without new timeout/lock amplification.

## Exit decision

L4 implementation may be merged/deployed in `AUTO_OFF` after exact-head CI, anti-drift, recovery, LIVE readback and cross-module regression PASS. `CANARY` remains a distinct authorization boundary and must not be inferred from implementation completion.
