# WA-L5 — Conversational BOOK/REBOOK Wiring · Impact Report

**Date:** 2026-09-02 America/Lima  
**Project:** WhatsApp Revenue Hub V2  
**Issue:** #445  
**Entry main:** `bc604d69e9ec8f759ad644fc4161055f69865e86`  
**Lock main:** `6378102210a159ddc04a26f9d5d5f0b90edf819f`  
**Branch:** `wa-l5-conversational-booking-20260902`  
**Risk:** CRITICAL — autonomous agent action boundary + SECURITY DEFINER + Agenda writes  
**Rollout:** additive / dormant under `AUTO_OFF + kill switch engaged`

## 1. Purpose

WA-L5 wires the certified WA4C conversation decision layer to the certified AGV2 V2 BOOK/REBOOK transactional authority. It does not create a second Agenda, identity model, treatment catalog or send authority.

Target deterministic loop:

`inbound intent → governed context → booking readiness → site/date → real availability → exact slot → explicit confirmation → L4 action gate → AGV2 V2 BOOK/REBOOK → append-only event → L3 post-commit side effects`

## 2. Existing authorities reused

- `aos_wa_conversations_v1`: channel/conversation state and trusted inbound address.
- REV/F5/F6 identity: canonical patient resolution; name-only/phone-only merge remains prohibited.
- `aos_catalogo_servicios`: active treatment/service authority.
- `aos_booking_availability_v2` + `aos_booking_resolve_selected_slot_v2`: slot/capacity/provider authority.
- `aos_booking_commit_core_v2` / `aos_booking_rebook_core_v2`: transactional BOOK/REBOOK authority.
- `aos_booking_operations_v2`: idempotent operation ledger.
- `aos_agenda_events_v2`: append-only BOOKED/RESCHEDULED event ledger.
- L3 delivery outbox: post-commit confirmations/reminders; provider dispatch remains separate.
- WA-L4: `AUTO_OFF | CANARY | PROD`, kill switch, allowlist and autonomous action safety boundary.

## 3. New L5 state

### `aos_wa_l5_booking_memory_v1`
One bounded row per conversation. It stores only the minimum operational booking state:

- flow `BOOK | REBOOK`;
- state `COLLECTING | SLOT_SELECTED | AWAITING_CONFIRMATION | CONFIRMED | RESELECT_REQUIRED | COMMITTED | HANDOFF`;
- treatment/site/date/time/provider/role selection;
- appointment ID for REBOOK;
- canonical patient ID only after governed resolution/verification;
- minimal given/family name only when needed for unresolved new booking;
- confirmation nonce, preparation/expiry and inbound provider-message proof;
- revision/error metadata.

It does **not** store raw prompts, chat transcript, clinical notes, DNI or email.

### `aos_wa_l5_booking_events_v1`
Append-only sanitized state transitions. No raw chat text, document value, email or model prompt/reply.

## 4. Privacy / identity boundary

### BOOK
- trusted WhatsApp phone is derived from the conversation, never from an untrusted booking payload;
- `MATCH` may reuse canonical patient name/contact through AGV2 core;
- `UNRESOLVED` may book only with sufficient given name + surname supplied for the booking;
- `IDENTITY_CONFLICT` routes to human;
- email and DNI remain optional.

### REBOOK
Patient-specific appointment details are not disclosed until stronger verification succeeds.

L5 verification:
- resolves the trusted phone to one canonical patient;
- compares the supplied document exactly against the canonical patient record;
- never persists or echoes the document;
- records only `VERIFIED` + canonical patient ID;
- active appointment lookup then uses `aos_rev_customer_agenda_identity_v1`, not phone/name heuristics;
- identity conflict, unresolved identity, no verifiable document or ambiguous appointment state fails closed/handoffs.

## 5. Explicit confirmation boundary

A BOOK/REBOOK commit requires a prepared selection and a fresh confirmation nonce.

Confirmation proof is accepted only when:
- memory is `AWAITING_CONFIRMATION`;
- nonce matches and is unexpired;
- a concrete `aos_wa_messages_v1` inbound provider message belongs to that same conversation;
- the message arrived after preparation;
- its normalized text is a conservative affirmative response while the conversation is awaiting confirmation.

The raw message body stays only in the canonical message ledger; L5 memory/events retain the provider message ID, not the text.

## 6. Autonomous action boundary

`aos_wa_l5_commit_confirmed_v1` is the only L5 autonomous commit bridge. It requires all of:

1. memory `CONFIRMED` + current nonce + non-expired confirmation;
2. conversation exists, is non-terminal and has no human takeover;
3. autonomous conversation state (`AI_ACTIVE`, `WAITING_CUSTOMER` or `APPOINTMENT_PENDING`);
4. L4 mode is `CANARY` or `PROD`;
5. L4 kill switch is disengaged;
6. `auto_reply_enabled=true` and `ai_send_enabled=true`;
7. in CANARY, the conversation/phone/BSUID/campaign is currently allowlisted;
8. autonomous actor comes from L4 authority, never from the LLM/browser;
9. slot is revalidated by AGV2 immediately before the write;
10. writes happen only through AGV2 V2 core.

Therefore L5 deployment under current `AUTO_OFF` is dormant and cannot mutate Agenda autonomously.

## 7. Conversational/runtime changes

`wa4-conversation-runtime-v2` adds deterministic detection for:
- `RESCHEDULE_INTENT`;
- explicit booking confirmation intent;
- HIGH booking readiness for those states.

`wa4-booking-resolver` exposes only sanitized real slot options needed by the tool planner (max 5 per date) and treatment authority ID; it does not expose capacity internals.

`wa4-copilot` emits a deterministic `booking_tool_plan` alongside natural-language drafting. The LLM does not choose arbitrary SQL/RPC calls.

`server-wa4` gains advisor/controlled L5 planning endpoints while preserving the existing HUMAN_ONLY `/api/wa4/.../book` route unchanged.

`server-f4` owns the internal autonomous L5 commit endpoint beside `/api/wa/auto-send`, protected by the existing server-only L4 internal token. No browser CORS route is added for autonomous commit.

## 8. Side effects

L5 does not send confirmations/reminders inside the booking transaction. AGV2 emits the event; L3 projects delivery intents after commit. With current provider-verified WhatsApp template count = 0 and L4 AUTO_OFF, autonomous provider dispatch remains fail-closed.

## 9. Sibling consumers / regression boundary

Mandatory exit regression:
- Agenda create/edit/status + AGV2;
- Call Center hot paths;
- Marketing monthly load/attribution;
- Ventas/Comisiones;
- Patient 360 + canonical identity;
- L4 authority and human send;
- shared Supabase/background pressure.

No timeout inflation, polling, duplicate heavy reads or direct Agenda writes are permitted.

## 10. Zero-Cost validation

Dedicated L5 gate must prove with synthetic data:
- schema + ACL + SECURITY DEFINER callers;
- runtime intent/confirmation corpus;
- sanitized memory/event contract;
- real-slot preparation;
- unresolved BOOK requires name+surname;
- identity conflict fail closed;
- REBOOK requires stronger verification;
- appointment ambiguity safe handling;
- explicit inbound confirmation proof;
- `AUTO_OFF` blocks commit with zero Agenda mutation;
- CANARY requires allowlist;
- authorized CANARY BOOK commits exactly one appointment;
- replay is idempotent;
- authorized CANARY REBOOK preserves the same appointment ID;
- `BOOKED` / `RESCHEDULED` append-only events exist;
- stale slot/reselection path fails closed;
- rollback refuses destructive removal after committed L5 lineage;
- cleanup/recovery is reproducible before committed lineage.

Existing WA4C FULL LOCAL, AGV2, WA-L4, Performance, Audit 360 and cross-module suites remain required at final exact head.

## 11. Production rollout / rollback

Production DDL may be installed only from merged lineage and must remain dormant under `AUTO_OFF + kill switch engaged`.

Production certification performs **read-only** L5 readback and regression; it will not create or rebook a real appointment.

Structural rollback is allowed only while no L5 `COMMITTED` event exists. Once committed lineage exists, recovery is SAFE-OFF through L4 and preservation of L5/AGV2 audit history; destructive rollback must fail closed.

## 12. Explicit non-authorization

This L5 implementation does not authorize:
- `AUTO_OFF → CANARY`;
- disabling the kill switch;
- autonomous Meta sends;
- real autonomous production BOOK/REBOOK;
- campaign activation/broadcast;
- L6 Meta attribution expansion;
- L7 cost-intelligence rollout.
