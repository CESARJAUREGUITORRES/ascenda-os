# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / OWNER HANDOFF TO WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-22 America/Lima  
**Entry main:** `26171abe38bb4bb6f6364aff6624ddc3d0d39580`  
**Railway entry status:** SUCCESS (`ASCENDA-OS - ascenda-os`)  
**ACTIVE LOCK:** `WHATSAPP-REVENUE-HUB-V2`  
**CURRENT GATE:** `WA-V2-0 — BASELINE & GOVERNANCE`  
**NEXT AFTER CERTIFICATION:** `WA-3 — HUMAN OPERATIONS MULTIAGENT`

## Owner directive

The owner explicitly ordered ASCENDA to resume and finish the WhatsApp Revenue Hub so it can be connected to Meta and become an operational sales channel. This handoff supersedes the prior scheduling preference while preserving every previous workstream checkpoint.

At most one HIGH/CRITICAL mutable workstream may operate at a time.

## Previous lock — preserved checkpoint, not closed

`MKT-INTEGRITY-HOTFIX-V3 / LOOP 6 V2.3` is **PAUSED / RECOVERABLE**, not certified terminally.

Frozen resume checkpoint:

- V2.3 baseline: `2026-08-22T02:27:02.696935+00:00`;
- genuine post-cutover operations at handoff readback: **0 / 5**;
- no qualifying customer operation was interrupted by this handoff;
- PR #342 / runtime `0318597188fbd358b9b207181426094154766d55` and all frozen Loop 6 invariants remain evidence for later resume;
- do not infer Loop 6 100% from the pause.

MKT must remain read-only while WA owns the mutable lane.

## Certified upstream state available to WhatsApp V2

- REV-F5: **PRODUCTION CERTIFIED — 100%**;
- REV-F6.0–F6.7 / REV-F6 global: **PRODUCTION CERTIFIED — 100%**;
- canonical patient records live: **7,702**;
- canonical sales live: **1,331**;
- leads live: **5,880**;
- F5 provenance: **15,498 source rows / 15,498 memberships / 8,716 clusters / 8,716 previews**;
- CIA contact/email facts live: **11,911**.

These are upstream sources of truth. WA must consume them through explicit contracts; it must not create a competing customer, sales, lead or email truth layer.

## WhatsApp V2 entry baseline

Live readback at handoff:

- `aos_wa_messages_v1 = 15` — 11 inbound / 4 outbound;
- `aos_wa_conversations_v1 = 2`;
- `aos_wa_events_v1 = 25`;
- `aos_wa_outbound_requests_v1 = 9`;
- `aos_wa_routing_events_v1 = 11`;
- active boxes = 2: `VENTAS_GENERAL`, `WA_TEST`;
- active box memberships = 2, currently belonging to the same operational actor;
- active assignments = 1;
- AI runs = 0;
- `human_send_enabled=true`;
- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `copilot_enabled=false`;
- `auto_reply_enabled=false`.

Attribution gap at entry: 0/15 WA messages currently have populated `campaign_source`, `ad_id`, `lead_id` or `raw_referral`.

Knowledge/catalog entry:

- 221 services active;
- 221 with price;
- 175 with commercial description;
- 198 with benefits;
- 167 with contraindications;
- 221 with FAQ payload;
- 0 with populated tags.

## Certified WhatsApp infrastructure preserved

Notifications `S13 → S15.5` are **CLOSED / 100% CERTIFIED / REGRESSION ONLY**.

Preserved evidence includes:

- signed Meta inbound path;
- canonical message/event persistence;
- WA-2 live conversation store;
- WA-3 ownership/human-send boundary;
- closed-PWA Web Push delivery;
- native Windows notification;
- notification click opening the installed PWA while respecting Auth;
- final notification ACL cutover.

Do not reopen notifications unless a real regression is demonstrated.

## Runtime at entry

Railway deploy configuration remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/railway.json` still mounts Sentry and the backend-only email compatibility preload before `server-phase-s-f17.js`. Recent Revenue/Sales Explorer/Cartero work therefore becomes part of the exact-current regression surface for WA, not a reason to fork another runtime.

## Current Meta outbound boundary

The human outbound transport has historical ACCEPTED sends, but credential/provider health is **not recertified for the current date**. Historical outbound ledger contains four `META_190` failures and one `META_SEND_REJECTED`; therefore production selling cannot be declared ready until a current Meta credential/provider health gate and controlled outbound canary pass.

Never put Meta access tokens in GitHub, Notion, chat, logs or browser code.

## WA-V2-0 exit gate

WA-V2-0 may be certified only when:

1. CURRENT docs agree on `WHATSAPP-REVENUE-HUB-V2` as the active mutable owner;
2. old WA snapshots no longer claim `0 outbound` or `Phase S` as CURRENT;
3. exact current runtime, Railway status and live Supabase WA baseline are recorded;
4. MKT Loop 6 is preserved as PAUSED / 0-of-5 checkpoint, not silently closed;
5. Notifications remain regression-only;
6. `aos_memory` and Notion are reconciled after GitHub merge;
7. no functional product/data mutation occurred during WA-V2-0;
8. anti-drift readback confirms the merged exact head.

## Next functional execution

After WA-V2-0 certification, proceed to `WA-3 — HUMAN OPERATIONS MULTIAGENT` in DISCOVER-FIRST mode.

Do not enable auto-routing or AI auto-reply during the first WA-3 canary. Preserve:

- `auto_routing_enabled=false`;
- `ai_send_enabled=false`;
- `auto_reply_enabled=false`.

The next phase after WA-3 is `WA-3.5 — REVENUE INBOX UX`; it must not contaminate WA-3 security/ownership contracts.
