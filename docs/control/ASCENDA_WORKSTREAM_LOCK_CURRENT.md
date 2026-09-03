# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-02 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `WA-L5 — Conversational BOOK/REBOOK Wiring`  
**GitHub authority:** Issue `#445`  
**Entry main:** `bc604d69e9ec8f759ad644fc4161055f69865e86`  
**Branch:** `wa-l5-conversational-booking-20260902`  
**Effective production safety:** `AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF`  
**CANARY:** `NOT AUTHORIZED` — separate explicit owner authorization required.

## WA-L5 entry objective

Wire the certified WA4C conversational runtime to the certified AGV2 BOOK/REBOOK transactional authority so a conversation can deterministically progress through:

`booking intent → site → date/window → real availability → slot → explicit confirmation → BOOK/REBOOK V2 → post-commit side effects`

The LLM may interpret language and draft copy, but it does not receive direct SQL/Agenda authority. Every write must pass deterministic server policy, identity/privacy gates and the AGV2 transactional core.

## Frozen L5 behavior

- `booking_readiness=HIGH` advances toward real slots rather than generic selling;
- buttons/lists are optional accelerators; free text remains valid;
- trusted inbound WhatsApp phone is reused instead of re-requested;
- canonical patient data may fill name/contact only through governed identity authority;
- for unresolved/new contacts, sufficient name + surname is required before commit;
- email and DNI remain optional unless a future explicit canonical rule changes that contract;
- explicit confirmation state/token is mandatory before BOOK or REBOOK;
- `RESCHEDULE_INTENT` must be detected in natural language;
- active appointment read must obey identity/privacy and ambiguity gates;
- REBOOK preserves the same logical `aos_agenda_citas.id` and appends event history;
- selected slots are revalidated transactionally immediately before commit;
- side effects happen post-commit and remain provider-verified-template gated;
- conversation memory is bounded and must not become a parallel patient/clinical record.

## LIVE entry snapshot

Read immediately before acquiring L5:

- L4 mode = `AUTO_OFF`;
- kill switch = `ENGAGED`;
- effective autonomous send = `false`;
- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `ai_send_enabled=false`;
- `auto_routing_enabled=false`;
- `human_send_enabled=true`;
- active L4 allowlist = `0`;
- `aos_booking_operations_v2 = 0`;
- `aos_agenda_events_v2 = 0`;
- `aos_wa4_booking_actions_v1 = 0`;
- Agenda total = `3,205`;
- future active Agenda = `36`;
- WhatsApp conversations = `2` / active `2`;
- WhatsApp messages = `21`;
- provider-verified active WhatsApp templates = `0`.

No production BOOK/REBOOK mutation is authorized merely to certify L5 deployment. Local/synthetic canaries own the write-path proof until a separately authorized live canary exists.

## L5 exit gates

1. deterministic conversational booking state machine;
2. bounded per-conversation memory + explicit confirmation lifecycle;
3. real slot selection with 3-date / 5-slot conversational UX contract and free-text parity;
4. natural-language REBOOK intent + governed active-appointment resolution;
5. BOOK and REBOOK route through AGV2 V2 only;
6. identity conflict / appointment ambiguity / stale slot / duplicate confirmation fail closed;
7. same-appointment REBOOK + append-only event proof;
8. exact-head dedicated L5 CI;
9. WA4C FULL LOCAL + AGV2 + WA-L4 + existing cross-module CI GREEN;
10. anti-drift;
11. expected-head merge;
12. DDL/runtime deploy from merged lineage;
13. LIVE tables/RPC/runtime readback while `AUTO_OFF + kill switch ON`;
14. zero autonomous outbound/provider traffic;
15. final regression: Agenda, Call Center, Marketing, Ventas/Comisiones, Pacientes/Identity, shared DB pressure;
16. close #445 and sync Notion/CURRENT.

## L4 frozen prerequisite

WA-L4 remains `CLOSED · PRODUCTION CERTIFIED`. Its central state machine, kill switch, allowlist, budgets, duplicate/cooldown guards, provider-template gate, human/clinical/identity handoff and append-only authority audit remain mandatory upstream safety controls.

L4 implementation/deploy lineage: `1402361923977db9ffdcaa047f21e8775b595e10` via PR `#444` / issue `#443`.

## Mandatory reliability boundary

Every L5 exit gate must preserve:

- Agenda governed create/edit/status and AGV2 transactional booking;
- Call Center next-lead + prepare + commit/confirm hot paths;
- Marketing monthly load without legacy/new duplication or annual fan-out;
- Sales/Commissions exact totals, filters, ownership and responsive reads;
- Patients/Patient 360 canonical search/core rendering and identity fail-closed semantics;
- historical aliases without overwrite of canonical contacts;
- shared Supabase/background pressure without new timeout/lock amplification.

Binding doctrine: `docs/control/ASCENDA_RELIABILITY_PERFORMANCE_DOCTRINE_CURRENT.md`.

## Forbidden during this lane without separate authorization

- `AUTO_OFF → CANARY`;
- disengaging the L4 kill switch for autonomous operation;
- `auto_reply_enabled=true`;
- `ai_send_enabled=true`;
- autonomous `auto_routing_enabled=true`;
- autonomous Meta dispatch;
- real production autonomous BOOK/REBOOK;
- bulk sends/broadcasts/campaign activation.
