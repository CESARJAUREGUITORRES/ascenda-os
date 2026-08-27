# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-27 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**WA-7A.2 exact head:** `8106f0ba6d644c062168fe84dc52dd83e50edb69`  
**WA-7A.2 merge:** `a943dca94534e9016de158177131e88bbcb72b73`  
**WA-7A.2:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE MUTABLE SUBPHASE:** `WA-7A.3 — Attribution Ingress`  
**LIVE hold:** Supabase REST/Auth HTTP 402

## Current phase state

- `WA-V2-0 — Baseline & Governance` = CLOSED.
- `WA-3 — Human Operations Multiagent` = OFFLINE CERTIFIED / LIVE recovery debt.
- `WA-3.5 — Revenue Inbox UX` = OFFLINE CERTIFIED 100% / LIVE recovery debt.
- `WA-7A.0 — Identity Compatibility` = CLOSED at demonstrated boundary.
- `WA-7A.1 — Identity Resolution` = CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK boundary.
- `WA-7A.2 — Identity Verification & Continuity` = CLOSED at CODE/CI/ZERO-COST/PROD-SCHEMA/READBACK/RAILWAY boundary.
- `WA-7A.3 — Attribution Ingress` = ACTIVE NEXT MUTABLE SUBPHASE.
- `WA-7A.4 — Marketing Eligibility Foundation` = blocked behind WA-7A.3.
- WA-4A/B/C, WA-5, WA-6, WA-7B/C/D, WA-8 and WA-9..14 remain later roadmap.

## Canonical identity architecture preserved

WA-7A.0 owns scoped PHONE/BSUID/PARENT_BSUID channel continuity. WA-7A.1 resolves a conversation toward existing canonical ASCENDA patient identity only through governed REV/F5/F6 evidence. WA-7A.2 adds verification and non-destructive identifier lineage without becoming a new person/customer master.

`WhatsApp channel alias != canonical patient identity != acquisition touchpoint`.

Username remains display-only. BSUID is a scoped WhatsApp alias, not a universal canonical person id.

## WA-7A.2 delivered

PR #376 merged from exact head `8106f0ba6d644c062168fe84dc52dd83e50edb69` to `a943dca94534e9016de158177131e88bbcb72b73`.

Minimum changes:

- verification fields on existing `aos_wa_channel_aliases_v1`;
- `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` semantics;
- old→new alias lineage through inactive history + `superseded_by`;
- identity events stored in existing `aos_wa_events_v1`;
- Meta `messages[].system` support for `user_changed_number` and `user_changed_user_id`;
- signed PHONE+BSUID pair verification evidence;
- native contact-request disclosure semantics;
- forwarded/manual contact cards remain CLAIMED only;
- delivered/read `recipient_user_id` provider binding;
- governed `request_contact_info` interactive payload support;
- replay/idempotency, concurrency fork prevention and rollback guards.

No customer/person master was created. No `aos_pacientes` or REV canonical write was added. No attribution, Ads Sync, AI send, auto-reply, auto-routing or campaign automation was introduced.

## Exact-head gates

At `8106f0ba6d644c062168fe84dc52dd83e50edb69` all relevant workflows completed SUCCESS:

- WA-7A.2 Identity Verification & Continuity — `32911787992`;
- WA-7A.0 Identity Compatibility — `32911788228`;
- WA-1 Secure WhatsApp Gateway — `32911788014`;
- Phase S WA3 Stabilization — `32911787931`;
- Ascenda CI — `32911788025`;
- Performance Guard — `32911787970`;
- ASC-PERF Audit 360 — `32911788017`.

Tests cover provider system rotation, PHONE+BSUID pair, BSUID-only continuity, REQUEST_CONTACT_INFO, forwarded/manual non-verification, recipient_user_id, conflict/no-theft, stale-phone retirement, replay/idempotency, concurrent fork prevention, WA-7A.0/7A.1 regressions and destructive rollback guard.

## Production / Railway readback

Production migration: `wa7a2_identity_verification_continuity_v1` (management version `20260825234845`).

Readback on 2026-08-27:

- WA-7A.2 schema/function/trigger exist;
- messages = 21 preserved;
- conversations = 2 preserved;
- alias rows = 2, both active PHONE;
- both legacy aliases remain `UNKNOWN / LEGACY_OBSERVED`;
- real identity events = 0;
- superseded aliases = 0;
- aliases with provider evidence = 0;
- conflict aliases = 0.

This is intentional: legacy phone observations were not retroactively promoted to VERIFIED and no synthetic identity history was fabricated.

Railway external status for exact merge `a943dca94534e9016de158177131e88bbcb72b73` = SUCCESS.

Safety readback remains:

- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`;
- `human_send=true` is the pre-existing governed canary state.

## Current external blocker

Current Supabase API logs on 2026-08-27 still show HTTP 402 on real `/rest/v1/*` ASCENDA traffic. SQL management remains available, but this does not constitute REST/Auth/provider recovery.

Therefore fresh authenticated browser smoke, physical `REQUEST_CONTACT_INFO`, genuine provider BSUID rotation and fresh Meta provider end-to-end canaries remain unverified. No service-role/Auth bypass is allowed.

`WA-7A.2 FRESH LIVE PROVIDER END-TO-END CERTIFIED 100% = NO` while the external 402 hold remains.

## NEXT — WA-7A.3 Attribution Ingress

Goal: preserve explicit acquisition provenance as immutable touchpoint evidence without confusing attribution with channel/person identity.

Discover/build only what is necessary for explicitly supplied first-inbound provenance:

- CTWA/referral payload and `ctwa_clid` or provider-equivalent id;
- source/referral id and type;
- safe supplied source URL;
- explicit `ad_id`, `lead_id`, `campaign_source` when available;
- permitted headline/body and sanitized raw referral evidence;
- immutable touchpoint id;
- provider message/event/replay ids and timestamps;
- lineage `touchpoint → WA conversation → optional canonical patient via existing WA-7A.1 resolver`.

Rules:

- `BSUID != touchpoint`;
- no attribution from phone/username/BSUID alone;
- one identity may have multiple touchpoints;
- missing referral evidence degrades safely;
- no broad Meta Ads Sync before WA-7B;
- no canonical identity mutation to force attribution;
- no AI/campaign automation activation.

Authoritative WA-7A.2 certificate: `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_2_CERTIFICATE.md`.  
Authoritative roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.  
Authoritative lock: `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
