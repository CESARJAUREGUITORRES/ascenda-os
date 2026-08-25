# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-24 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Current closeout PR:** `#372 — WA-3.5 Closeout`  
**Baseline before PR #372:** `main@6292852fad190f1489836fc34644a2161aa575a2`  
**WA-3.5 product code head:** `71a8a327bf832c58ea50b0998a41a73306e30bdb`  
**Production hold:** Supabase project `ituyqwstonmhnfshnaqz` currently HTTP 402

## Current phase state

- `WA-V2-0 — Baseline & Governance` = **CLOSED**.
- `WA-3 — Human Operations Multiagent` = **OFFLINE CERTIFIED / LIVE HOLD**.
- `WA-3.5 — Revenue Inbox UX` = **CLOSEOUT / CODE-CI-ZERO-COST** in PR #372.
- `WA-7A — Meta Attribution Ingress` = **NEXT MUTABLE PHASE AFTER #372 MERGE**.
- `WA-4A/B/C`, `WA-5`, `WA-6`, `WA-7B/C/D`, `WA-8`, `WA-9..14` = future roadmap.
- Notifications `S13 → S15.5` = **CLOSED / REGRESSION ONLY**.
- Existing WA-4 infrastructure remains **SAFE-OFF**: `ai_send=false`, `copilot=false`, `auto_reply=false`.

## WA-3.5 implemented scope

### P0 — Revenue Inbox

- shared canonical inbox snapshot; no duplicate read owner;
- filters for all/mine, human requested, unread, waiting customer, bot/AI-active and finalised;
- canonical campaign filter;
- richer cards with direction/time, unread, owner, campaign, handoff age and 24h state;
- canonical state model preserved.

### P1A — Advisor productivity

- safe quick replies that populate, never auto-send;
- actor+conversation drafts, bounded and expiring;
- keyboard shortcuts;
- responsive baseline;
- no internal-note browser truth.

### P2 — Governed context

- `DETAILS` keeps native WA-3 operational authority;
- `CUSTOMER 360` reuses canonical REV-F6 Patient 360 on demand and existing patient permissions;
- `CAMPAIGN` exposes existing `campaign_source`, `ad_id`, `lead_id` only and hands expanded provenance to WA-7A;
- `ACTIVITY` derives from canonical conversation timestamps;
- `COPILOT` remains visible SAFE-OFF pending WA-4A/B/C;
- tablet/mobile Context drawer and explicit degraded/empty states;
- P2 owns zero polling timers, zero MutationObserver, zero direct WA `/api/` calls and zero provider/Cloud transport.

## Security / authority invariants

- explicit `whatsapp-agent` permission and strong Auth V3/2FA;
- boxes/members/`max_active`;
- AVAILABLE/AWAY/OFFLINE readiness with fail-closed stale handling;
- `HUMAN_REQUESTED` queue semantics;
- queue privacy;
- claim/reassign/release and concurrent single-owner claim;
- exact-owner human send + customer 24h window;
- supervisor/manual intervention and ownership-loss recovery;
- `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false` during live hold.

Canonical persisted conversation states remain:

`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

There is no persisted literal `BOT_ACTIVE`.

## WA-3.5 product-head evidence

At `71a8a327bf832c58ea50b0998a41a73306e30bdb` the following passed:

- WA-3.5 Closeout;
- WA-3 Boxes Routing Handoff with local DB/pgTAP/concurrency/rollback;
- WA-3.5 P1A including P0 regression;
- WA-3 FINAL Presence Handoff FAST + DB;
- Performance Guard;
- ASC-PERF Audit 360;
- S14 Web Push;
- S15 Unified Notifications.

The final certification/documentation head is governed by `ASCENDA WA-3.5 Closeout`; docs-only changes do not alter the validated product code tree.

## Production boundary

`WA-3.5 LIVE / PRODUCTION CERTIFIED 100% = NOT YET`.

Do not bypass login or security while Supabase is on 402. When Cloud recovers, perform exact-SHA Railway health, Auth/2FA, provider health, signed inbound, allowlisted outbound, terminal status, CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback, notifications, Revenue Inbox visual smoke and egress observation.

## Next lock

After PR #372 merges with its exact expected head and final closeout gate green:

`WA-7A — META ATTRIBUTION INGRESS`.

WA-7A owns explicit first-inbound Meta provenance/touchpoints. Attribution must never be fabricated from phone matching.

Authoritative certificate: `docs/control/WHATSAPP_REVENUE_HUB_WA_3_5_OFFLINE_CERTIFICATE.md`.
Authoritative roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.
