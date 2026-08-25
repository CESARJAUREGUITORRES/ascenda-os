# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Estado:** V2 ACTIVE / WA-3 OFFLINE CLOSEOUT  
**Captured:** 2026-08-24 America/Lima  
**Runtime tree:** `main@43c1ac717622b9c1a809f6883980e7e60f00ef89`  
**Closeout PR:** `#369` — CODE/CI/ZERO-COST certification candidate  
**Supabase:** `ituyqwstonmhnfshnaqz` — production API currently blocked by HTTP 402 quota  
**Railway:** SUCCESS for runtime tree `43c1ac717622b9c1a809f6883980e7e60f00ef89`

## 1. North Star

`Meta Ads / Organic → WhatsApp → explicit provenance → canonical identity → conversation → handling state + sales stage → knowledge → human/AI → business tools → appointment/follow-up/call → attendance → sale → revenue attribution → learning`.

WhatsApp is a governed conversation/revenue channel. It must not create a parallel CRM, patient master, sales ledger, agenda or email truth layer.

## 2. Runtime exact-current

Certified runtime tree before the docs/CI-only closeout PR:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3-v2.js / server-wa3.js → server-wa2.js → server-f4.js → lower/core`

Railway also loads the Sentry, backend-only email compatibility and scoped Supabase 402 quota preloads. PR #368 introduced the fail-closed 402 circuit and merged as `43c1ac717622b9c1a809f6883980e7e60f00ef89`; Railway reported SUCCESS for that exact merge SHA.

## 3. Phase state

- `WA-V2-0 — Baseline & Governance` = **CLOSED**.
- `WA-3 — Human Operations Multiagent` = **FUNCTIONALLY BUILT / OFFLINE CLOSEOUT**.
- `WA-3.5 — Revenue Inbox UX` = **NEXT**, activated only after PR #369 closeout merge/reconciliation.
- `WA-7A`, `WA-4A/B/C`, `WA-5`, `WA-6`, `WA-7B/C/D`, `WA-8`, `WA-9..14` = future roadmap phases; do not count them as WA-3 defects.
- Notifications `S13 → S15.5` = **CLOSED / REGRESSION ONLY**.
- WA-4 existing infrastructure = **DEPLOYED / SAFE-OFF**; `copilot=false`, `auto_reply=false`.

## 4. WA-3 implemented invariants

Offline/Zero-Cost evidence covers:

- explicit `whatsapp-agent` authorization + strong 2FA;
- 2+ agent membership model;
- boxes / memberships / `max_active`;
- AVAILABLE / AWAY / OFFLINE readiness with stale fail-closed behavior;
- explicit `HUMAN_REQUESTED` handoff;
- queue privacy — aggregate queue does not expose customer phone or conversation id;
- claim / reassign / release primitives;
- concurrent claim remains single-owner;
- supervisor/manual intervention;
- exact-owner human-send boundary;
- customer 24h window gate;
- ownership-loss recovery;
- routing/event audit;
- rollback/recovery contracts;
- auto-routing OFF and AI send OFF.

The canonical persisted conversation state model remains:

`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

There is no separate literal `BOT_ACTIVE` persisted state. Do not introduce one only to mirror checklist wording.

## 5. Performance / quota containment

Performance hardening already established single inbox ownership/shared snapshots, bounded presence cadence and adaptive notification behavior.

PR #368 adds a process-local Supabase quota circuit scoped to the configured ASCENDA Supabase hostname and these WA runtime families only:

`Phase-S / WA2 / WA3 / WA3V2 / WA4 / WA-Gateway / F17`.

First upstream 402 opens a bounded cooldown; repeated WA calls short-circuit locally; one controlled probe is admitted after cooldown. Mixed `F4-RevenueProxy` traffic is deliberately not intercepted.

## 6. Exact-head evidence for PR #368

Exact head: `81f7f6e5f329bc9184f4d4f611de6d0ca48b5608`.

PASS:

- Ascenda CI `32792393890`;
- Phase S WA3 Stabilization `32792393973`;
- WA-2 Zero-Cost `32792393969`;
- WA-3 V2 Multiagent FAST `32792393859`;
- WA-3 Boxes/Routing Zero-Cost `32792393938`;
- S15 Notifications `32792393894`;
- WA-4 AI Router `32792393949`;
- Performance Guard `32792393960`;
- ASC-PERF Audit 360 `32792393877`.

Sentinel F4 continues to report the independent historical `F2_PUBLIC_HTML_DRIFT`; it was not introduced by WhatsApp closeout and remains outside the mutable WA lane.

## 7. Historical live baseline preserved

Last reliable pre-402 WA readback remains the 2026-08-22 checkpoint:

- 15 canonical messages: 11 inbound / 4 outbound;
- 2 conversations;
- 25 events;
- 9 outbound requests;
- 11 routing events;
- 2 active boxes;
- 2 active memberships;
- 1 active assignment;
- 0 AI runs;
- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`.

Do not present these counts as a fresh 2026-08-24 live readback while 402 persists.

## 8. Meta / production hold

The transport has historical ACCEPTED evidence, but current provider/credential readiness is **not recertified**.

`WA PRODUCTION CERTIFIED 100% = NOT YET`.

Production remains blocked until one exact deployed SHA demonstrates:

1. Supabase `402 → 200` recovery;
2. Railway `/health` and exact-SHA runtime;
3. Auth V3 + 2FA continuity;
4. current provider health;
5. real signed inbound;
6. allowlisted human outbound within the 24h window;
7. sent/delivered/read or explicit terminal provider state;
8. consolidated CESAR↔MIREYA `HUMAN_REQUESTED → queue → claim → send → reassign → access isolation → readback/release` canary;
9. alert/notification smoke;
10. post-recovery egress/request-rate observation.

## 9. WA-3.5 next build boundary

After PR #369 is green and merged, the single mutable WA lock moves to `WA-3.5 — Revenue Inbox UX`.

P0 must reuse the existing canonical WA-2/WA-3 read model and shared inbox snapshot. Start with fields that exist today:

- My conversations;
- Human requested;
- Unread;
- Waiting customer;
- Bot/New state view;
- owner / box / state / campaign filters only where source fields exist;
- richer cards using contact, campaign, state, owner/box, unread and handoff/queue age where available;
- preserve sent/delivered/read/failure timeline;
- preserve notification deep-link/auth destination.

Do not invent treatment/sede/sales-stage data if the canonical read model does not provide it. Private media storage/STT belongs to WA-5, not WA-3.5.

## 10. Safety invariants

- one HIGH/CRITICAL mutable workstream at a time;
- no secrets in frontend/Git/Notion/chat;
- no autonomous diagnosis;
- no AI auto-reply before controlled-autonomy gates;
- no attribution fabricated from phone matching;
- no duplicate CRM/agenda/sales/email truth;
- idempotent/audited writes;
- recovery remains fail-closed;
- code/CI certification and live production certification remain distinct.

Authoritative closeout matrix: `docs/control/WHATSAPP_REVENUE_HUB_WA_CLOSEOUT_OFFLINE_CERTIFICATE.md`.
Authoritative phase roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.
