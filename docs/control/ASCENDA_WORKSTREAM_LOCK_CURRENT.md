# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-25 America/Lima  
**Baseline:** `main@e454c9535eeff00c665794c2ac319dcc38bdf13f`  
**WA-3.5:** `CLOSED / OFFLINE CERTIFIED 100%`  
**ACTIVE LOCK:** `WA-7A — WHATSAPP IDENTITY & ATTRIBUTION FOUNDATION`

## Owner directive

Continue WhatsApp Revenue Hub under the improved 2026 identity model discovered before WA-7A implementation. At most one HIGH/CRITICAL mutable workstream may operate at a time.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- MKT Integrity Loop 6 V2.3 = PAUSED / RECOVERABLE.
- CIA, Sentinel, KronIA and unrelated product/data work remain read-only/regression-only unless WA proves a strict dependency.

## WA foundation preserved

- signed Meta gateway + replay/idempotency controls;
- canonical conversation projection;
- strong Auth V3/2FA;
- explicit `whatsapp-agent` authorization;
- boxes/members/`max_active`;
- AVAILABLE/AWAY/OFFLINE readiness;
- explicit `HUMAN_REQUESTED` queue;
- queue privacy;
- claim/reassign/release;
- supervisor/manual intervention;
- concurrent single-owner claim;
- exact-owner send + 24h window;
- ownership-loss recovery;
- alerts/notifications regressions;
- Supabase 402 fail-closed retry containment;
- `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`.

## New WA-7A lock scope

WA-7A is explicitly expanded from attribution-only to:

`WHATSAPP IDENTITY & ATTRIBUTION FOUNDATION`.

This is a corrective architecture decision based on the 2026 WhatsApp username/BSUID rollout and implementation evidence from current providers/open-source systems.

### WA-7A.0 — Identity Compatibility

May mutate:

- WhatsApp ingress parsing;
- channel recipient abstraction;
- BSUID/username-safe transport contracts;
- identity-safe message/status envelope;
- tests/migrations strictly necessary to persist governed channel identifiers.

Must not mutate unrelated Revenue/CIA/Agenda/AI logic.

### WA-7A.1 — Identity Resolution

May add/adapt channel alias contracts that hand off to canonical REV/F5 identity resolution.

Must not create a parallel person/customer master.

### WA-7A.2 — Verification & Continuity

May handle:

- identifier update events;
- old/new BSUID lineage;
- governed contact-info disclosure;
- verification/source metadata.

Must not silently overwrite canonical contact facts.

### WA-7A.3 — Attribution Ingress

May persist immutable CTWA/referral/touchpoint evidence.

Must not infer attribution from phone, username or customer identity alone.

### WA-7A.4 — Marketing Eligibility Foundation

May model addressability/reachability/consent/suppression/preferences needed by future campaigns.

Must not build or activate bulk marketing sending yet.

## Mandatory identity invariants

- `phone` is nullable for WhatsApp.
- BSUID is an alias, not the canonical ASCENDA person id.
- BSUID is portfolio-scoped.
- username is display-only and mutable.
- username must never be a routing primary key or cold-marketing import key.
- identifier changes preserve lineage; no destructive overwrite.
- phone disclosure does not automatically imply verified ownership.
- Contact Book is provider assistance, not canonical identity.
- provider-specific payload naming remains inside adapter/transport boundaries.

## Mandatory attribution invariants

- `BSUID != ctwa_clid/touchpoint`.
- one canonical person may have many acquisition touchpoints.
- first-inbound provenance is immutable evidence.
- webhook signature and replay/idempotency remain mandatory.
- missing referral fields must degrade safely.
- no broad Ads sync before WA-7B.

## Mandatory marketing invariants

- `IDENTITY != REACHABILITY != MARKETING ELIGIBILITY`.
- a technically reachable recipient is not automatically marketing-authorized.
- future bulk campaigns operate on governed WhatsApp recipients, not just phone-number rows.
- consumer username discovery/scraping is not a supported growth strategy.
- auth templates that require phone remain phone-only.

## Current known technical debt to resolve first

`app/wa-gateway.js` currently:

- digit-normalizes `msg.from`;
- looks up contact `wa_id` through phone normalization;
- stores inbound identity in `from_number`;
- requires outbound `to` to normalize to an 8–15 digit phone number.

Therefore WA-7A implementation must begin with an identity-compatibility contract before new attribution persistence is allowed.

## Production hold

Supabase production remains HTTP 402. Therefore:

- no production auth bypass;
- no Cloud write retries merely to exercise WA;
- historical counts are not fresh readback;
- WA LIVE certification remains false;
- code/CI/Zero-Cost implementation may continue independently.

LIVE recovery gate remains:

`402 → 200 → Railway exact health → Auth/2FA → provider health → signed inbound → allowlisted outbound → terminal delivery → CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback → notifications → WA visual smoke → egress observation`.

## Lock transition rule

WA-7A remains the sole mutable HIGH/CRITICAL lane until its scoped closeout is certified. WA-4A must not become mutable merely because an individual WA-7A subphase passes.

## Safety invariants

- one mutable HIGH/CRITICAL lane;
- no secrets in Git/Notion/chat/frontend;
- no autonomous diagnosis;
- no AI auto-reply before future controlled-autonomy gates;
- no phone-only attribution;
- no username-only merge;
- no parallel CRM/Agenda/sales/email truth;
- fail-closed recovery;
- exact-head → merge → reconciliation → next lock.
