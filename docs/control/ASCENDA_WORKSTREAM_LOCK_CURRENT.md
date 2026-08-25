# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-25 America/Lima  
**Runtime baseline:** `main@6e6e69eac108e3a4497425d5c53b757760185ccc`  
**WA-7A.0:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE LOCK:** `WA-7A.1 — IDENTITY RESOLUTION`

## Owner directive

Continue WhatsApp Revenue Hub with at most one HIGH/CRITICAL mutable workstream at a time.

**Only WA-7A.1 is mutable now.** Other HIGH/CRITICAL workstreams remain read-only/regression-only unless WA-7A.1 proves a strict dependency.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- CIA, Sentinel, KronIA and unrelated product/data work = read-only/regression-only unless strict dependency.

## WA-7A.0 handoff

WA-7A.0 delivered PHONE + BSUID transport compatibility, generic recipients, alias continuity, conflict fail-closed semantics, PHONE-key regression protection and S14 provider-message target resolution.

Production schema/readback and existing PHONE compatibility passed. Railway exact merge is green. Fresh REST/Auth/provider/BSUID LIVE validation remains external debt because Supabase API currently returns HTTP 402.

WA-7A.0 must not be reopened merely to bypass the 402. Post-recovery provider/BSUID canaries remain a recertification gate.

## WA-7A.1 — allowed mutations

May discover/build only what is necessary to connect governed WhatsApp channel alias evidence to existing canonical ASCENDA identity boundaries.

Allowed:

- read/audit existing REV/F5 identity contracts;
- alias-to-canonical resolution contracts;
- explicit portfolio/business scope;
- evidence/confidence/source timestamps;
- conflict/review states;
- additive schema/functions/tests strictly necessary for resolution;
- reversible/fail-closed migration and rollback contracts;
- read-only integration with current canonical identity surfaces.

Must not:

- create a parallel person/customer master;
- auto-merge from username similarity;
- treat BSUID as a universal cross-portfolio customer id;
- infer attribution from phone, username or identity alone;
- broaden to WA-7A.2/3/4 without closing WA-7A.1;
- build broad Meta Ads sync before WA-7B;
- activate AI send, auto-reply or auto-routing.

## Mandatory identity invariants

- phone is nullable for WhatsApp;
- BSUID is channel identity alias, not canonical person id;
- BSUID scope must remain explicit;
- username is mutable display/search metadata only;
- PHONE + BSUID continuity may converge when evidence is explicit;
- conflicting identifiers fail closed;
- canonical identity remains governed by existing REV/F5 authority;
- channel identity and acquisition touchpoint remain separate concepts;
- identifier changes preserve lineage; no destructive overwrite.

## Safety state

Preserve:

- signed Meta gateway;
- replay/idempotency;
- Auth V3/2FA;
- explicit whatsapp-agent authorization;
- exact-owner send;
- active assignment requirement;
- queue privacy/claim/reassign/release;
- customer 24h window;
- canary allowlist;
- `auto_routing=false`;
- `ai_send=false`;
- `copilot=false`;
- `auto_reply=false`.

`human_send=true` is a pre-existing governed canary state and must not be widened as part of WA-7A.1.

## External LIVE hold

Supabase SQL management access currently works, but REST/Auth remains HTTP 402. Do not interpret SQL access as full Cloud recovery.

Forbidden:

- auth bypass;
- service-role substitution for a user/session canary;
- blind provider retries;
- synthetic LIVE claims based only on historical provider evidence.

Post-recovery recertification remains:

`402 → 200 → Railway health → Auth/2FA → REST → provider health → signed inbound → governed outbound → delivery readback → ownership isolation → visual smoke`.

## Lock transition rule

WA-7A.1 remains the sole mutable HIGH/CRITICAL lane until its scoped closeout is certified. Only then may the lock advance to `WA-7A.2 — Identity Verification & Continuity`.
