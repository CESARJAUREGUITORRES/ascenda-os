# WA-L4 — Autonomous Authority + Kill Switch · Entry / Implementation Control

**Date:** 2026-09-02 America/Lima  
**Authority:** GitHub issue #443  
**Entry main:** `73a4bab955fffb8a423f8ff07fa8c835df125227`  
**Active lock commit:** `ee05aee59af5e145d62228a7cab27aaf597bd8f8`  
**Branch:** `wa-l4-autonomous-authority-20260902`  
**Operational state during implementation:** `AUTO_OFF · SAFE-OFF`

## Entry readback

Production safety at L4 entry:

- `copilot_enabled=true`;
- `auto_reply_enabled=false`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `human_send_enabled=true`;
- Booking Operations V2 = `0`;
- Agenda Events V2 = `0`;
- L3 Delivery Outbox V3 = `0`;
- L3 dispatchable = `0`;
- active template registry = `10`;
- active WhatsApp templates = `6`;
- provider-verified active WhatsApp templates = `0`;
- existing outbound request ledger = `15` rows, `7` with provider message ID.

No CANARY or autonomous send is authorized by this implementation workstream.

## Frozen architecture

L4 inserts one centralized server-side authority **before** existing provider reservation/dispatch:

`internal agent/runtime -> F4 internal auto-send endpoint -> L4 DB authority -> existing idempotency reservation -> Meta Cloud API`

The LLM never receives direct Meta or arbitrary SQL authority.

### Authority state

- `AUTO_OFF`: autonomous authority always blocks.
- `CANARY`: requires explicit level-1 authorization reference, kill switch disengaged and an active allowlist match.
- `PROD`: requires previous CANARY state plus a new explicit authorization reference.
- global kill switch wins over mode.

Deployment initializes `AUTO_OFF + kill_switch_engaged=true` unconditionally.

### Server boundary

`/api/wa/auto-send`:

- POST only;
- no browser CORS path;
- requires a server-only `WA_L4_INTERNAL_TOKEN` (minimum 32 chars, timing-safe compare);
- secret is stripped from the legacy child process;
- calls `aos_wa_l4_authorize_autonomous_send_v1` before outbound reservation and before `graphSend()`;
- BLOCK never reaches Meta;
- HANDOFF invokes existing governed `aos_wa3_handoff_request_v1`;
- provider failure is non-auto-retry and requests human handoff.

Existing `/api/wa/send` remains the separate 2FA human route and records `send_origin=HUMAN`.

## Database controls

### `aos_wa_auto_authority_v1`
Singleton state machine + kill switch + daily message limit + max turns + global/conversation rate + cooldown + duplicate window + authorization metadata.

### `aos_wa_auto_allowlist_v1`
Server-only allowlist for exact `PHONE | BSUID | CONVERSATION | CAMPAIGN` subjects.

### `aos_wa_auto_decisions_v1`
Append-only decision ledger. Stores recipient/content hashes and decision metadata; does **not** store raw prompt or raw model reply.

### `aos_wa_auto_control_events_v1`
Append-only administrative authority/allowlist audit.

### Existing outbound lineage
Existing `aos_wa_outbound_requests_v1` remains the provider idempotency source of truth; L4 only adds `send_origin`, `conversation_id`, `authority_decision_id`. Existing human history defaults to `HUMAN`.

## Fail-closed decision order

Before autonomous provider dispatch L4 checks:

1. valid idempotency/content hash;
2. state exists;
3. `AUTO_OFF`;
4. kill switch;
5. AI/routing flag consistency;
6. conversation existence/terminal state;
7. human ownership/takeover boundary;
8. exact recipient ↔ conversation continuity;
9. safety action;
10. identity conflict / required canonical identity;
11. provider-verified template if template send;
12. CANARY allowlist;
13. daily message limit;
14. max turns;
15. global rate;
16. conversation rate;
17. cooldown;
18. duplicate-content window.

Any unsafe state returns BLOCK or HANDOFF; there is no best-effort autonomous bypass.

## Recovery

Recovery first forces:

- `AUTO_OFF`;
- kill switch engaged;
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`.

It then refuses structural rollback if any real `send_origin=AUTO` provider history exists. This prevents audit/provider lineage from being silently erased.

## Mandatory exit gates

L4 implementation is not complete until:

- dedicated runtime/static CI PASS;
- isolated DB apply + behavior + replay + recovery PASS;
- relevant existing WA/Performance/Ascenda gates PASS;
- exact-head anti-drift PASS;
- merge with expected head;
- Railway exact merge deployment SUCCESS;
- Supabase migration from merged lineage;
- LIVE readback proves `AUTO_OFF + kill=true + auto_reply=false + ai_send=false + auto_routing=false + human_send=true`;
- no autonomous outbound rows/provider IDs are created;
- full cross-panel regression matrix PASS;
- shared PostgreSQL/API pressure shows no new L4-attributable timeout/lock amplification.

**CANARY transition is explicitly outside this exit and remains blocked until a separate owner authorization.**
