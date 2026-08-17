# CIA V3 F17 — V19 Cutover Impact Report

Date: 2026-08-17
Baseline: main@13dafdb4711c9554718a4846c5ed644e016dd42e
Tracking: #173

## Purpose
Move the remaining legacy WhatsApp template browser read behind the server-authoritative F17 boundary without changing canonical audience/contact identity truth.

## Invariants
- Canonical CIA Audience/Activation/contact identity remains the only customer/audience truth.
- No channel-specific customer/lead/patient/audience duplicate is introduced.
- Service-role material remains server-side/environment-only.
- Missing/invalid ASCENDA app session fails closed.
- No provider activation, broad-send, SMS spend, message-content logging, PII/PHI logging or secret exposure.

## Controlled order
1. Deploy F17 outer runtime boundary and keep unrelated routes proxied to the existing F5→WA4→WA3→WA2→F4 chain.
2. Verify unauthenticated template endpoint fails closed and runtime health remains good.
3. Switch the remaining call-center template consumer from direct browser REST to `/api/f17/whatsapp/templates` using the existing ASCENDA app-session token.
4. Compare active-template shape/count with the legacy source and perform compatibility smoke.
5. Prepare and validate rollback.
6. Only after consumer cutover proof, revoke browser SELECT on legacy WhatsApp tables and enable FORCE RLS under a reversible migration.
7. Continue outbound policy, provider-event replay/idempotency, allowlisted WhatsApp canary and rollback gates until `READY_F18_MULTICHANNEL_CERTIFIED`.

## Rollback
Runtime rollback: restore package start to `server-f5.js` and remove `server-f17.js`.
Consumer rollback: restore the single legacy template fetch in `app/public/calls.js`.
ACL rollback: versioned migration restores only the compatibility privileges required before cutover if production smoke fails.

## Release rule
F17 remains fail-closed until `public.aos_cia_f18_readiness_v1()` returns `READY_F18_MULTICHANNEL_CERTIFIED` and `ready_for_f18=true` with all six release gates true.