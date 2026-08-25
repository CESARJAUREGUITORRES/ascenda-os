# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-25 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**GitHub baseline:** `main@e454c9535eeff00c665794c2ac319dcc38bdf13f`  
**WA-3.5 closeout:** `PR #372 — MERGED / CODE-CI-ZERO-COST OFFLINE CERTIFIED 100%`  
**Production hold:** Supabase project `ituyqwstonmhnfshnaqz` currently HTTP 402

## Current phase state

- `WA-V2-0 — Baseline & Governance` = **CLOSED**.
- `WA-3 — Human Operations Multiagent` = **OFFLINE CERTIFIED / LIVE HOLD**.
- `WA-3.5 — Revenue Inbox UX` = **OFFLINE CERTIFIED 100% / LIVE HOLD**.
- `WA-7A — WhatsApp Identity & Attribution Foundation` = **ACTIVE NEXT MUTABLE PHASE**.
- `WA-4A/B/C`, `WA-5`, `WA-6`, `WA-7B/C/D`, `WA-8`, `WA-9..14` = future roadmap.
- Notifications `S13 → S15.5` = **CLOSED / REGRESSION ONLY**.
- Existing WA-4 infrastructure remains **SAFE-OFF**: `ai_send=false`, `copilot=false`, `auto_reply=false`.
- `auto_routing=false` remains fail-closed during the current LIVE hold.

## Why WA-7A was expanded before implementation

The 2026 WhatsApp username rollout changes the identity contract of the channel:

- a consumer phone number may be absent from inbound/outbound messaging payloads;
- WhatsApp supplies a Business-Scoped User ID (`BSUID`) for the business-portfolio/user relationship;
- username is informational/display data and must not be treated as the routing or canonical identity key;
- BSUID is portfolio-scoped and may change when the WhatsApp user changes phone number;
- authentication templates such as one-tap/zero-tap/copy-code still require phone numbers;
- phone availability and WhatsApp reachability are now separate concepts.

ASCENDA therefore must stop assuming `WhatsApp identity == numero_limpio`.

Current `app/wa-gateway.js` is still phone-first: it normalizes `msg.from` to digits and outbound validates `to` as an 8–15 digit phone number. WA-7A must fix this before attribution features depend on the old assumption.

## New identity model

WhatsApp channel identity is now modeled as aliases attached to an existing canonical ASCENDA person/contact boundary, not as a replacement CRM identity.

### Channel identity facts

Store when supplied and governed:

- `phone_e164` — nullable;
- `whatsapp_bsuid` — portfolio-scoped routing identity;
- `whatsapp_parent_bsuid` — optional lineage field when emitted by provider/platform;
- `whatsapp_username` — display/search aid only;
- `business_portfolio_id`;
- validity/status metadata for identifier changes;
- provider evidence and observed timestamps.

Never use username as a primary key or marketing-address import key.

### Recipient abstraction

Outbound code must move from a phone-only parameter to a channel recipient contract conceptually equivalent to:

`ChannelRecipient { channel=WHATSAPP, kind=PHONE|BSUID, value, portfolio_id }`.

Adapters may expose provider-specific field names, but product/business logic must not depend on them.

## WA-7A subphases

### WA-7A.0 — Identity Compatibility

- accept phone+BSUID or BSUID-only inbound safely;
- preserve username as display-only;
- eliminate phone-only parsing/routing assumptions;
- support outbound routing by PHONE or BSUID where the provider permits it;
- preserve auth-template phone-only restrictions;
- no duplicate conversation/contact creation merely because phone visibility changes.

### WA-7A.1 — Identity Resolution

- link channel aliases to existing canonical identity through governed REV/F5 boundaries;
- never auto-merge persons from username similarity;
- phone matching may help identity resolution but is never attribution authority;
- conflicting identifiers fail closed to review/explicit resolution.

### WA-7A.2 — Identity Verification & Continuity

- consume identifier-update events when supplied (`user_id_update`/provider equivalent);
- retain old→new BSUID lineage instead of destructive overwrite;
- support governed `REQUEST_CONTACT_INFO` acquisition when useful;
- distinguish `VERIFIED / CLAIMED / UNKNOWN / CONFLICT` contact data;
- Contact Book may assist continuity but is not ASCENDA's canonical identity store.

### WA-7A.3 — Attribution Ingress

Persist immutable first-inbound provenance when supplied:

- `ctwa_clid` or provider-equivalent CTWA click identifier;
- referral/source id and source type;
- source URL when supplied and policy-safe;
- ad id;
- lead id;
- campaign source;
- headline/body when permitted;
- sanitized raw referral evidence;
- immutable touchpoint id;
- message/provider/replay identifiers and observed timestamps.

`BSUID` identifies a WhatsApp relationship. `ctwa_clid`/touchpoint identifies acquisition provenance. They are not interchangeable.

### WA-7A.4 — Marketing Eligibility Foundation

This does **not** build the bulk campaign product yet. It creates the governed foundation:

- recipient identity;
- WhatsApp reachability;
- marketing consent/eligibility;
- user marketing preference (`stop/resume` or provider equivalent);
- suppression reason;
- last eligibility observation.

Core rule:

`IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.

A reachable BSUID is not automatically marketing consent.

## Acquisition / marketing implications

- Consumer usernames do not become a cold-prospect directory or scrape/import list.
- A WhatsApp-native lead can be valuable even when `phone_e164 = NULL` if a governed BSUID relationship exists.
- Business username can become a new inbound acquisition source and should be preserved as provenance when observable.
- Future campaigns must address eligible WhatsApp recipients, not merely rows that contain phone numbers.
- Cold username blasting is out of scope and must not be inferred as supported behavior.

## Attribution architecture

Target:

`Meta Ad / Business Username / Organic / QR / Web → signed WhatsApp ingress → immutable touchpoint/provenance → WhatsApp channel identity → canonical identity resolver → conversation → appointment/sale/revenue`.

A single person may have multiple touchpoints. Never collapse customer identity and acquisition touchpoint into one record.

## WA-3.5 preserved scope

WA-3.5 remains closed in product scope:

- P0 Revenue Inbox;
- P1A advisor productivity;
- P2 governed `DETAILS / CUSTOMER 360 / CAMPAIGN / ACTIVITY / COPILOT`;
- zero P2 polling/timers/MutationObserver;
- Customer 360 on demand through canonical REV-F6 permission boundaries;
- Copilot SAFE-OFF.

## Security / authority invariants

- signed Meta webhook + replay/idempotency;
- strong Auth V3/2FA;
- explicit `whatsapp-agent` authorization;
- exact-owner send + customer 24h window;
- queue/privacy/claim/reassign/release/supervisor controls;
- one active HIGH/CRITICAL mutable workstream;
- no secrets in frontend/Git/Notion;
- no phone-only attribution;
- no username-only identity merge;
- no parallel CRM/Agenda/revenue truth;
- no AI auto-reply/autonomous send.

Canonical persisted conversation states remain:

`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

There is no persisted literal `BOT_ACTIVE`.

## Production boundary

`WA LIVE / PRODUCTION CERTIFIED 100% = NOT YET` while Supabase production remains HTTP 402 and fresh provider/session canaries cannot be executed.

When Cloud recovers, historical evidence does not substitute fresh certification.

## External research baseline

Architecture update is based on the 2026 WhatsApp username/BSUID rollout plus observed ecosystem migration patterns. Confirmed provider behavior includes:

- Twilio WhatsApp Usernames / BSUID rollout and Peru rollout group;
- BSUID as `ExternalUserId`, phone nullable, username informational;
- BSUID portfolio scope and regeneration on phone-number change;
- outbound BSUID support with authentication-template exceptions;
- Contact Book as a provider continuity aid, not a replacement for ASCENDA canonical identity.

Community/BSP implementations are treated as engineering evidence, not policy authority. Provider/Meta policy must be rechecked at implementation and LIVE certification time.

Authoritative design contract: `docs/control/WHATSAPP_WA_7A_IDENTITY_ATTRIBUTION_FOUNDATION.md`.
Authoritative roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.
