# ASCENDA Conversations — WhatsApp Revenue Hub — CURRENT

**Captured:** 2026-08-25 America/Lima  
**Program:** `WHATSAPP-REVENUE-HUB-V2`  
**Runtime merge baseline:** `main@6e6e69eac108e3a4497425d5c53b757760185ccc`  
**WA-7A.0:** `CLOSED AT DEMONSTRATED BOUNDARY`  
**ACTIVE MUTABLE SUBPHASE:** `WA-7A.1 — Identity Resolution`  
**LIVE hold:** Supabase REST/Auth HTTP 402

## Current phase state

- `WA-V2-0 — Baseline & Governance` = **CLOSED**.
- `WA-3 — Human Operations Multiagent` = **OFFLINE CERTIFIED / LIVE recovery debt**.
- `WA-3.5 — Revenue Inbox UX` = **OFFLINE CERTIFIED 100% / LIVE recovery debt**.
- `WA-7A.0 — Identity Compatibility` = **CODE/CI/ZERO-COST/PROD-SCHEMA/PHONE-COMPAT CERTIFIED**; fresh REST/Auth/provider/BSUID LIVE canary remains blocked by Supabase 402.
- `WA-7A.1 — Identity Resolution` = **ACTIVE NEXT MUTABLE SUBPHASE**.
- `WA-7A.2 — Identity Verification & Continuity` = next.
- `WA-7A.3 — Attribution Ingress` = next.
- `WA-7A.4 — Marketing Eligibility Foundation` = next.
- WA-4A/B/C, WA-5, WA-6, WA-7B/C/D, WA-8, WA-9..14 remain future roadmap.

## WA-7A.0 closeout evidence

PR `#374` merged with exact head `8d081b9be16edd2e7858e015faf0d32ff8fb87fd` into runtime merge `6e6e69eac108e3a4497425d5c53b757760185ccc`.

Exact-head SUCCESS:

- WA-7A.0 Identity Compatibility;
- WA-1 Secure Gateway;
- WA-3 Stabilization;
- Ascenda CI;
- Performance Guard;
- ASC-PERF Audit 360.

Production schema is applied additively. PHONE remains backward compatible while BSUID/parent-BSUID become governed channel aliases. Username remains display/search metadata only and is never routing or canonical identity authority.

Production readback after migration:

- 21 messages preserved;
- 2 conversations, both PHONE;
- 2 PHONE aliases;
- 0 invalid address contracts;
- 0 typed PHONE-key regressions;
- 0 production BSUID rows yet;
- 21/21 existing messages remain bound to PHONE conversations with alias evidence;
- alias ledger RLS/FORCE RLS enabled, direct anon/authenticated reads denied.

Railway status for the exact runtime merge = SUCCESS.

## Current external blocker

Supabase SQL management access is available, but current API logs continue to return HTTP 402 for `/rest-admin/v1/ready`, `/auth/v1/health` and real `/rest/v1/*` traffic from ASCENDA.

Therefore:

- fresh authenticated UI smoke cannot be certified;
- fresh Meta/provider canary cannot be certified through the governed runtime path;
- fresh BSUID LIVE behavior cannot be claimed;
- historical provider evidence does not substitute fresh certification.

No auth/service-role bypass is allowed to manufacture a LIVE result.

## WA-7A.1 objective

Connect WhatsApp channel aliases to existing canonical ASCENDA identity through governed REV/F5 boundaries without creating a parallel customer master.

Required invariants:

- phone is a nullable contact point, not mandatory WhatsApp identity;
- BSUID is portfolio-scoped channel identity, not canonical person id;
- username is display-only;
- PHONE + BSUID evidence may converge to one governed channel relationship;
- conflicting identifiers fail closed;
- no merge from username similarity;
- phone matching may assist identity resolution but is never attribution authority;
- attribution/touchpoint remains separate from identity.

## Preserved safety

- signed Meta webhook + replay/idempotency remains mandatory;
- Auth V3/2FA, exact owner, active assignment and canary controls remain authority;
- `auto_routing=false`;
- `ai_send=false`;
- Copilot remains SAFE-OFF;
- auto-reply remains SAFE-OFF;
- no broad Ads sync before WA-7B;
- no phone-only attribution;
- no parallel CRM/Agenda/revenue truth.

Canonical persisted conversation states remain:

`NEW / AI_ACTIVE / HUMAN_REQUESTED / HUMAN_ACTIVE / AI_COPILOT / WAITING_CUSTOMER / APPOINTMENT_PENDING / APPOINTMENT_BOOKED / WON / LOST / CLOSED`.

There is no persisted literal `BOT_ACTIVE`.

Authoritative WA-7A.0 certificate: `docs/control/WHATSAPP_REVENUE_HUB_WA_7A_0_CERTIFICATE.md`.
Authoritative roadmap: `docs/control/WHATSAPP_REVENUE_HUB_V2_ROADMAP_CURRENT.md`.
Authoritative lock: `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
