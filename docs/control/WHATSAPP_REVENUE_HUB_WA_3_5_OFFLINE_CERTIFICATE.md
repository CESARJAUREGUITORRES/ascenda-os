# ASCENDA Conversations — WA-3.5 Revenue Inbox — OFFLINE CERTIFICATE

**Captured:** 2026-08-24 America/Lima  
**PR:** `#372 — WA-3.5 Closeout — Revenue Inbox complete offline`  
**Baseline before closeout:** `main@6292852fad190f1489836fc34644a2161aa575a2`  
**Product code exact head:** `71a8a327bf832c58ea50b0998a41a73306e30bdb`  
**LIVE hold:** Supabase production HTTP 402 + fresh provider/session canary

## Certification rule

`WA-3.5 CODE / CI / ZERO-COST = OFFLINE CERTIFIED 100%` is valid only when the commit containing this certificate passes the dedicated `ASCENDA WA-3.5 Closeout` exact-head gate. If that final gate is not green, this declaration is void.

`WA-3.5 LIVE / PRODUCTION CERTIFIED 100% = NOT YET` while Supabase production remains unavailable and the real production smoke cannot be executed.

## Certified scope

### P0 — Revenue Inbox foundation

- canonical shared WA inbox snapshot remains the single read owner;
- all / mine / human-requested / unread / waiting-customer / bot-AI / finalised filters;
- campaign selector from existing `campaign_source`;
- conversation cards with direction/age, unread, state, owner, campaign, handoff age and 24h window;
- canonical states only; no invented `BOT_ACTIVE` persistence;
- no duplicate inbox polling.

### P1A — Advisor productivity

- generic quick replies populate the composer only and never send automatically;
- per-actor + per-conversation drafts, 4096-char bound, 24h TTL;
- draft restoration/cleanup;
- `Alt+1..4` quick-reply shortcuts and `Ctrl/Cmd+K` search focus;
- responsive baseline;
- native WA send authority, ownership, 2FA and 24h rules remain unchanged.

### P2 — Governed conversation context

Right-panel target is implemented as:

- `DETAILS` — certified native WA-3 operational details remain authority;
- `CUSTOMER 360` — on-demand only, reusing canonical REV-F6 Patient 360 and existing patient-panel permissions;
- `CAMPAIGN` — factual existing `campaign_source`, `ad_id`, `lead_id` only;
- `ACTIVITY` — derived only from canonical conversation timestamps;
- `COPILOT` — visible boundary, SAFE-OFF.

Customer 360 deliberately projects only a narrow commercial subset. It does not expand notes, documents, DNI, email, emergency-contact, clinical notes or treatment data into the WA context layer. Identity conflicts are never auto-resolved.

P2 is fully event-driven: no `fetch`, no WA `/api/` calls, no direct Meta/Supabase coupling, no polling timer and no DOM MutationObserver. It reacts to the canonical `aos:wa3-inbox` event and explicit user clicks.

## Governance exclusions / handoffs

- **Internal notes:** not implemented as browser truth. No canonical governed WA-note write contract was found, so this capability is deliberately deferred rather than persisted in `localStorage` or a duplicate table.
- **Expanded Meta provenance / immutable touchpoints:** handed to `WA-7A`.
- **Treatment / sales-stage semantics:** not fabricated in WA-3.5; future governed sources own them.
- **Copilot:** `ai_send=false`, `copilot=false`, `auto_reply=false`; future authority is `WA-4A → WA-4B → WA-4C`.
- **Private media/STT:** remains `WA-5`.
- **Agenda / Call Center:** existing ASCENDA systems remain authority; WA-3.5 creates no parallel engine.

## Product-head evidence — `71a8a327bf832c58ea50b0998a41a73306e30bdb`

PASS:

- `ASCENDA WA-3.5 Closeout` — P2 + P0 + P1A + WA-3 authority + Supabase 402 circuit;
- `ASCENDA WA-3 Boxes Routing Handoff` — local Supabase, pgTAP V1/V2, concurrent claim, rollback/recovery;
- `ASCENDA WA-3.5 P1A Advisor Productivity` — including P0 regression and WA-3 UI authority;
- `ASCENDA WA-3 FINAL Presence Handoff` — FAST UI + local DB/pgTAP + concurrent claim + rollback;
- `ASCENDA Performance Guard CI`;
- `ASCENDA ASC-PERF Audit 360`;
- `WA S14 Web Push Notification Standard`;
- `S15 Unified Notification Events`.

`Ascenda CI`, `WA-3 V2 Multiagent FAST` and `Phase S WA3 Stabilization` runs attached to that product head were cancelled by later commits on the same PR, not failed. Syntax and their relevant WA authority boundaries are independently covered by the green Closeout, Routing, Presence/Handoff and performance contracts above.

## Delivery hardening

The shell cache key was advanced from the old WA-3 FINAL asset version to the WA-3.5 P1A version and the additive P2 closeout module is loaded only after Native + Layout + Multiagent. This prevents a browser from silently retaining the old pre-WA-3.5 multiagent asset.

## LIVE exit after Supabase recovery

Required before declaring WA-3.5 LIVE:

1. observe Supabase `402 → 200`;
2. verify Railway exact deployed SHA and `/health`;
3. Auth V3 + 2FA continuity;
4. current Meta/provider health;
5. real signed inbound;
6. allowlisted human outbound inside the 24h window;
7. sent/delivered/read or explicit terminal provider state;
8. CESAR↔MIREYA handoff → queue → claim → send → reassign → access-isolation → readback/release;
9. alerts / notification smoke;
10. visual verification of Revenue Inbox P0/P1/P2 with real governed data;
11. post-recovery egress/request-rate observation.

## Handoff

After PR #372 merges and the final exact-head closeout gate is green:

`NEXT MUTABLE LOCK = WA-7A — META ATTRIBUTION INGRESS`.

WA-7A must preserve explicit Meta provenance at first inbound and must never infer attribution solely from phone matching.
