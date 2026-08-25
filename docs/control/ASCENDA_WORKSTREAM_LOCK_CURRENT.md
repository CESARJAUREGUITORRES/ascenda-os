# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-24 America/Lima  
**Runtime tree:** `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**Railway runtime status:** SUCCESS  
**ACTIVE LOCK:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-3 — OFFLINE CLOSEOUT / PR #369`  
**NEXT AFTER CLOSEOUT:** `WA-3.5 — REVENUE INBOX UX`

## Owner directive

Finish WhatsApp Revenue Hub as the active ASCENDA mutable program while preserving other certified/paused checkpoints. At most one HIGH/CRITICAL mutable workstream may operate at a time.

## Previous workstreams preserved

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- MKT Integrity Loop 6 V2.3 = PAUSED / RECOVERABLE at 0/5 genuine operations.
- Notifications S13–S15.5 = CLOSED / regression-only.
- Sentinel's historical `F2_PUBLIC_HTML_DRIFT` remains a separate cross-workstream debt; do not mutate Sentinel inside WA solely to force a green status.

## Runtime / closeout checkpoint

PR #368 merged the fail-closed Supabase 402 circuit.

- PR #368 exact head: `81f7f6e5f329bc9184f4d4f611de6d0ca48b5608`.
- runtime merge SHA: `43c1ac717622b9c1a809f6883980e7e60f00ef89`.
- Railway: SUCCESS for runtime merge SHA.
- PR #369 is docs/CI/offline-certificate only; it does not mutate runtime or DB schema.

PR #368 final exact-head PASS surface:

- Ascenda CI;
- Phase S;
- WA-2 Zero-Cost;
- WA-3 V2 FAST;
- WA-3 routing/concurrency Zero-Cost;
- S15 notifications;
- WA-4 AI Router;
- Performance Guard;
- ASC-PERF Audit 360.

## WA-3 closeout boundary

The following are implemented and treated as regression invariants:

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

PR #369 must seal the aggregate offline contract and leave no `UNKNOWN` in the implemented WA-1→WA-3 / notifications / WA-4-infrastructure scope.

## Production hold

Supabase production API is currently returning HTTP 402 quota responses. Therefore:

- Cloud is not a valid certification target;
- no live production writes are required or permitted for WA closeout;
- historical live counts remain evidence only, not fresh readback;
- WA CODE/CI/ZERO-COST may close independently;
- `WA PRODUCTION CERTIFIED 100%` must remain false until live recovery/canary gates pass.

Live gates after recovery:

`402 → 200 → Railway exact health → Auth/2FA → provider health → signed inbound → allowlisted outbound → terminal delivery status → CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback → alerts → egress measurement`.

## Next mutable lock — WA-3.5

Only after PR #369 is exact-head green, merged and Notion is reconciled, move the mutable lock to:

`WA-3.5 — REVENUE INBOX UX`.

P0 is UX/read-model work, not a new CRM or routing authority:

- My conversations;
- Human requested;
- Unread;
- Waiting customer;
- Bot/New view;
- filters only from existing canonical campaign/state/owner/box fields;
- richer cards;
- clean sent/delivered/read/failure timeline;
- notification/auth destination restore;
- reuse shared inbox snapshot and avoid duplicate pollers.

Treatment/sede/sales-stage are not invented if absent. Private media/STT stays in WA-5.

## Safety invariants

- one mutable HIGH/CRITICAL lane;
- no secrets in Git/Notion/chat/frontend;
- no autonomous diagnosis;
- no auto-reply AI before its future gates;
- no attribution from phone alone;
- no parallel CRM/Agenda/sales/email truth;
- fail-closed recovery;
- exact-head → merge → reconciliation → next lock.
