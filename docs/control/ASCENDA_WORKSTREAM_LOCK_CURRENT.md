# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-03 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `NONE`  
**LAST CLOSED LANE:** `WA-L5 — Conversational BOOK/REBOOK Wiring`  
**Status:** `CLOSED · PRODUCTION CERTIFIED · DORMANT`  
**GitHub authority:** Issue `#445` · PR `#446`  
**Certified implementation main:** `1c424d7e1919d56429ea43d68ddf5690566b87bf`  
**Final PR exact-head:** `f717f7726eb75ea00d6982f2a084ecbff592a6d0`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L5 final certification

WA-L5 is installed in production as a dormant capability. It wires governed conversational BOOK/REBOOK to the certified AGV2 transactional authority without giving the LLM direct Agenda/SQL authority.

Certified behavior:

- real governed availability and bounded 3-date / 5-slot conversational selection;
- free-text parity with buttons/lists as optional accelerators;
- bounded per-conversation booking memory;
- explicit inbound confirmation required before commit;
- natural-language REBOOK intent;
- exact patient verification and ambiguity/conflict handoff;
- REBOOK preserves the same logical `aos_agenda_citas.id`;
- selected slot is revalidated transactionally;
- BOOK/REBOOK writes route through AGV2 V2 only;
- sanitized append-only L5 event history;
- no raw DNI/email/clinical chat stored in L5 booking memory/events.

## Certified Git / deploy lineage

- Final exact-head matrix: `13/13 SUCCESS`.
- Anti-drift before merge: base `6378102210a159ddc04a26f9d5d5f0b90edf819f`; branch `20 ahead / 0 behind`.
- PR `#446` merged with expected-head protection.
- Railway on implementation main `1c424d7e1919d56429ea43d68ddf5690566b87bf`: `SUCCESS`.
- Supabase PROD migrations:
  - `20260903070134` · `wa_l5_conversational_booking_v1`
  - `20260903070151` · `wa_l5_treatment_resolver_uuid_fix_v1`

## LIVE dormant readback

- L4 mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- active allowlist = `0`;
- `aos_wa_l5_booking_memory_v1 = 0`;
- `aos_wa_l5_booking_events_v1 = 0`;
- `aos_booking_operations_v2 = 0`;
- `aos_agenda_events_v2 = 0`;
- `aos_wa4_booking_actions_v1 = 0`;
- autonomous outbound WA messages = `0`;
- Agenda total = `3,205`, unchanged from L5 entry;
- WhatsApp conversations = `2` / active `2`;
- WhatsApp messages = `21`, unchanged from L5 entry.

Resolver hardening LIVE:

- `aos_wa_l5_appointment_treatment_v1(text)` is `SECURITY DEFINER` + `STABLE`;
- defective `min(uuid)` path absent;
- deterministic exact-count fallback gate present;
- EXECUTE restricted to `service_role`; anon/authenticated denied;
- both L5 tables have RLS + FORCE RLS.

Post-deploy API/Postgres logs show no L5-specific 5xx, statement timeout or lock amplification. Security advisors show no L5-specific blocker. Performance advisors show no L5-specific WARN/ERROR; INFO-only tuning remains non-blocking, including the treatment FK covering-index suggestion and expected unused-index notices while L5 tables remain empty.

## Frozen prerequisite and reliability boundary

WA-L4 remains `CLOSED · PRODUCTION CERTIFIED`. Its authority state machine, kill switch, allowlist, budgets, duplicate/cooldown guards, provider-template gate, human/clinical/identity handoff and append-only audit remain mandatory upstream controls.

L4 implementation/deploy lineage: `1402361923977db9ffdcaa047f21e8775b595e10` via PR `#444` / issue `#443`.

The cross-module reliability doctrine remains binding for Agenda, Call Center, Marketing, Sales/Commissions, Patients/Identity and shared Supabase pressure:
`docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.

## Next eligible roadmap item

`L6 — Meta attribution expansion` is **NEXT / NOT STARTED**. No HIGH/CRITICAL mutable lane is currently acquired by this document.

Starting L6 does not authorize autonomous WhatsApp activation.

## Still forbidden without separate explicit authorization

- `AUTO_OFF → CANARY`;
- disengaging the L4 kill switch;
- `auto_reply_enabled=true`;
- `ai_send_enabled=true`;
- autonomous `auto_routing_enabled=true`;
- autonomous Meta dispatch;
- real production autonomous BOOK/REBOOK;
- bulk sends/broadcasts/campaign activation.
