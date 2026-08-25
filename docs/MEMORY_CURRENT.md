# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-24 America/Lima  
**Runtime tree:** `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**ACTIVE WORKSTREAM:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-3 — OFFLINE CLOSEOUT / PR #369`  
**NEXT LOCK AFTER CLOSEOUT:** `WA-3.5 — REVENUE INBOX UX`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/WHATSAPP_REVENUE_HUB_CURRENT.md`;
7. `docs/control/WHATSAPP_REVENUE_HUB_WA_CLOSEOUT_OFFLINE_CERTIFICATE.md`;
8. `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`;
9. exact GitHub runtime + Railway + Supabase LIVE when available;
10. fresh scoped `aos_memory` rows when Cloud is available;
11. Notion executive continuity.

Historical chat/doc snapshots never override exact CURRENT + runtime evidence.

## Portfolio state

- REV-F5 — **PRODUCTION CERTIFIED — 100%**;
- REV-F6 — **PRODUCTION CERTIFIED — 100%**;
- REV-F7 — paused while WA owns the mutable lane;
- MKT Integrity Loop 6 V2.3 — **PAUSED / RECOVERABLE at 0/5 genuine operations**;
- WhatsApp Revenue Hub V2 — **ACTIVE**;
- Notifications S13–S15.5 — **CLOSED / 100% CERTIFIED / REGRESSION ONLY**;
- CIA, Sentinel, KronIA and unrelated feature/data work — read-only/regression-only unless WA proves a strict dependency.

## WhatsApp V2 current state

- `WA-V2-0` = CLOSED.
- `WA-3` = functionally built; CODE/CI/ZERO-COST closeout is being sealed by PR #369.
- `WA-3.5` = next mutable phase after #369 merge/reconciliation.
- WA-4 existing AI infrastructure = DEPLOYED / SAFE-OFF; this does not certify WA-4A/B/C.
- Future phases remain the declared V2 roadmap, not hidden WA-3 defects.

## Runtime exact-current

PR #368 merged the scoped Supabase 402 quota circuit.

Runtime tree before docs/CI-only PR #369:
`main@43c1ac717622b9c1a809f6883980e7e60f00ef89`.

Railway status for that exact SHA: **SUCCESS**.

Runtime chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → WA3 V2/V1 → server-wa2.js → server-f4.js → lower/core`.

Runtime preloads include Sentry, backend-only email compatibility and the host/UA-scoped WA Supabase quota circuit.

## PR #368 exact-head certification evidence

Exact head: `81f7f6e5f329bc9184f4d4f611de6d0ca48b5608`.

PASS:

- Ascenda CI `32792393890`;
- Phase S `32792393973`;
- WA-2 Zero-Cost `32792393969`;
- WA-3 V2 FAST `32792393859`;
- WA-3 routing/concurrency Zero-Cost `32792393938`;
- S15 notifications `32792393894`;
- WA-4 AI router `32792393949`;
- Performance Guard `32792393960`;
- ASC-PERF Audit 360 `32792393877`.

Sentinel's independent `F2_PUBLIC_HTML_DRIFT` remains outside the WA mutable lane.

## WA-3 invariants preserved

- signed Meta gateway and idempotent ledger;
- canonical conversation projection;
- provider replay/out-of-order protection;
- explicit `whatsapp-agent` + strong 2FA;
- physical presence follows ASCENDA/labor state with stale OFFLINE fail-closed;
- human queue only explicit `HUMAN_REQUESTED`;
- claim/reassign/release + supervisor intervention;
- concurrent claim single-owner;
- exact-owner human send + 24h customer-window gate;
- ownership-loss recovery;
- queue privacy and routing audit;
- alerts exact-owner + HUMAN_ACTIVE + inbound-only;
- Web Push/PWA notification chain regression-certified;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`.

Current persisted state model:
`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

Do not invent a separate `BOT_ACTIVE` database state for checklist parity.

## 402 containment

Supabase management can remain ACTIVE_HEALTHY while the production API returns HTTP 402 due quota. During that condition:

- do not use Supabase Cloud as a certification target;
- the WA quota circuit short-circuits recurrent target traffic after the first 402;
- scope = configured ASCENDA Supabase host + `Phase-S / WA2 / WA3 / WA3V2 / WA4 / WA-Gateway / F17`;
- one probe after bounded cooldown;
- mixed `F4-RevenueProxy` remains untouched;
- this mitigation is not a substitute for live recovery validation.

## Historical live baseline preserved

Last reliable pre-402 checkpoint (2026-08-22):

- messages 15 = 11 INBOUND / 4 OUTBOUND;
- conversations 2;
- events 25;
- outbound requests 9;
- routing events 11;
- active boxes 2;
- active memberships 2;
- active assignments 1;
- AI runs 0.

Do not relabel those values as a fresh 2026-08-24 Cloud readback.

## Production hold

`WA PRODUCTION CERTIFIED 100% = NOT YET`.

Still required after Supabase recovers:

- observe `402 → 200`;
- exact deployed SHA + health;
- Auth/2FA continuity;
- current Meta provider health;
- real signed inbound;
- controlled allowlisted human outbound inside open 24h window;
- terminal status evidence;
- consolidated CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback canary;
- alerts/notification smoke;
- post-recovery egress/request-rate measurement.

## WA-3.5 first build boundary

After PR #369 closes GitHub/Notion reconciliation, build advisor-grade UX over existing WA authority, not a new backend truth layer.

P0 priority:

- My conversations;
- Human requested;
- Unread;
- Waiting customer;
- Bot/New view;
- campaign/state/owner/box filters only where canonical fields exist;
- richer cards: contact, preview, state, owner/box, unread, campaign, handoff/queue age when available;
- clean timeline with sent/delivered/read/failure;
- notification/auth destination restoration;
- keep the shared inbox snapshot as single read owner.

Do not fabricate treatment/sede/sales-stage fields. Private media pipeline/STT remains WA-5.

## Safety invariants

- one HIGH/CRITICAL mutable workstream;
- no secrets in frontend/Git/Notion/chat;
- no auto-reply AI before controlled autonomy gates;
- no diagnosis/clinical advice automation;
- no attribution invented from phone alone;
- no duplicate CRM/agenda/sales/email truth layer;
- exact-head evidence before any certification claim;
- GitHub first; `aos_memory` only when Cloud available; Notion last.
