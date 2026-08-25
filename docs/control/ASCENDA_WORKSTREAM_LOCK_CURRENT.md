# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-24 America/Lima  
**Main after WA closeout:** `b97b84a1878c42e41e7870bcde2289d1541e0f58`  
**Certified runtime baseline:** `43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**Railway runtime status:** SUCCESS on certified runtime baseline  
**ACTIVE LOCK:** `WA-3.5 — REVENUE INBOX UX`  
**CURRENT GATE:** `WA-3.5 P0 — Revenue Inbox UX / read-model only`

## Owner directive

Finish WhatsApp Revenue Hub as the active ASCENDA mutable program while preserving other certified/paused checkpoints. At most one HIGH/CRITICAL mutable workstream may operate at a time.

## Previous workstreams preserved

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- MKT Integrity Loop 6 V2.3 = PAUSED / RECOVERABLE at 0/5 genuine operations.
- Notifications S13–S15.5 = CLOSED / regression-only.
- Sentinel's historical `F2_PUBLIC_HTML_DRIFT` remains a separate cross-workstream debt; do not mutate Sentinel inside WA solely to force a green status.

## WA closeout checkpoint — CLOSED

PR #368 merged the fail-closed Supabase 402 circuit.

- PR #368 exact head: `81f7f6e5f329bc9184f4d4f611de6d0ca48b5608`.
- runtime merge SHA: `43c1ac717622b9c1a809f6883980e7e60f00ef89`.
- Railway: SUCCESS for runtime merge SHA.

PR #369 closed the implemented WhatsApp scope offline.

- PR #369 exact head: `582e4fe4547f7dcbf38023ab5229c2f3120a40c5`.
- merge/main SHA: `b97b84a1878c42e41e7870bcde2289d1541e0f58`.
- aggregate WA-CLOSEOUT exact-head gate: PASS.
- `WA CODE / CI / ZERO-COST = OFFLINE CERTIFIED 100%`.
- PR #369 changed certification/CI/docs only and did not change DB schema or the certified runtime baseline.

The following remain regression invariants:

- explicit `whatsapp-agent` permission + strong 2FA;
- multiagent boxes/members/`max_active`;
- presence AVAILABLE/AWAY/OFFLINE with stale fail-closed behavior;
- explicit `HUMAN_REQUESTED` human-only queue;
- queue privacy;
- claim/reassign/release;
- supervisor/manual intervention;
- concurrent single-owner claim;
- exact-owner human send + 24h window;
- ownership-loss recovery;
- routing audit/rollback;
- alerts and closed-PWA Web Push regression chain;
- `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`.

## Production hold

Supabase production API is currently returning HTTP 402 quota responses. Therefore:

- Cloud is not a valid certification or development target;
- do not add production writes merely to exercise WA-3.5;
- historical live counts remain evidence only, not fresh readback;
- WA-3.5 may advance through CODE/CI/ZERO-COST independently;
- `WA PRODUCTION CERTIFIED 100%` remains false until live recovery/canary gates pass.

Live gates after recovery:

`402 → 200 → Railway exact health → Auth/2FA → provider health → signed inbound → allowlisted outbound → terminal delivery status → CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback → alerts → egress measurement`.

## Active mutable lock — WA-3.5

`WA-3.5 — REVENUE INBOX UX` is now the single mutable WA lane.

### P0 boundary

P0 is UX/read-model work, not a new CRM, database or routing authority. It must reuse the certified WA-3 inbox snapshot and existing canonical fields.

Target surface:

- all / my conversations;
- human requested;
- unread;
- waiting customer;
- bot / AI-active view;
- finalised conversations;
- campaign filter from canonical `campaign_source`;
- richer cards using last-message direction/time, unread, state, owner, campaign, handoff age and 24h window;
- no duplicate inbox polling;
- no new Supabase table/RPC;
- no ownership, 2FA, routing or AI-send authority changes.

Treatment, sede and sales-stage must not be invented while absent from the canonical inbox read model. Private media/STT stays in WA-5. Agenda/call tooling stays in its existing authority.

### P0 implementation branch

`feat/wa-3-5-revenue-inbox-p0-20260824`

P0 must pass its dedicated Zero-Cost contract plus the existing WA-3 UI/runtime regressions before merge.

## Safety invariants

- one mutable HIGH/CRITICAL lane;
- no secrets in Git/Notion/chat/frontend;
- no autonomous diagnosis;
- no auto-reply AI before its future gates;
- no attribution from phone alone;
- no parallel CRM/Agenda/sales/email truth;
- fail-closed recovery;
- exact-head → merge → reconciliation → next lock.
