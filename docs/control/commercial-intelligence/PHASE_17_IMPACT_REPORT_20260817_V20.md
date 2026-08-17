# CIA V3 F17 — V20 Current-Main Cutover Impact Report

Date: 2026-08-17
Exact baseline: main@0ca1869f63dca728b582b2451a823155fd1c8f6b
Tracking: #173

V20 supersedes V18/V19 before production because main advanced. No prior superseded branch was merged.

## Scope
Activate the already-audited server-authoritative WhatsApp template boundary at the real current main, preserving the existing F5→WA4→WA3→WA2→F4 runtime chain for all unrelated routes.

## Security invariants
- ASCENDA app-session verification is mandatory for template reads.
- Supabase service-role remains server-side/environment-only.
- No browser direct mutation is introduced.
- No duplicated channel-specific audience/customer/lead/patient truth.
- No provider activation, broad-send, SMS spend, PII/PHI/message logging or secret exposure.

## Controlled order
1. Runtime boundary + entrypoint.
2. Production negative smoke: unauthenticated route fails closed; `/health` stays healthy.
3. Consumer cutover in `app/public/calls.js` from direct legacy REST to `/api/f17/whatsapp/templates`.
4. Compatibility/rollback smoke and active-template parity.
5. Controlled legacy SELECT retirement + RLS/FORCE RLS.
6. Governed outbound policy, replay/idempotency, allowlisted WhatsApp canary, rollback.
7. Require `READY_F18_MULTICHANNEL_CERTIFIED` / `ready_for_f18=true` before F17 closure.

## Rollback
Restore package start to the prior entrypoint, remove the outer wrapper, revert the consumer fetch, and use the versioned ACL rollback only if compatibility proof fails.