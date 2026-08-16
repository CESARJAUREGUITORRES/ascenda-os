# CIA V3 F17 — Impact Report V10

Date: 2026-08-16 (Lima)
Baseline: `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`
Branch: `feature/cia-phase17-multichannel-20260816-v10`
Risk: CRITICAL

## Objective
Continue F17 — SMS / WhatsApp / Future Channels from CURRENT main after the compatibility-preserving P0 legacy WhatsApp ACL hardening. Preserve one canonical Audience/Activation/identity truth and keep providers/transports interchangeable.

## Fresh authoritative entry gate
Production `public.aos_cia_email_f17_readiness_v1()` returns exactly `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`; all F16 release gates are true. GitHub Issue #104 is CLOSED/completed.

## Fresh F17 production state
Production `public.aos_cia_f18_readiness_v1()` remains `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.

Passing gates:
- `contracts_active=true`
- `whatsapp_bridge_validated=true`

Open gates:
- `outbound_policy_validated=false`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `rollback_verified=false`

## Fresh legacy WhatsApp ACL state after V9/P0
Production metadata now confirms browser mutation privileges are removed from both legacy tables checked:
- `aos_plantillas_whatsapp`: anon/authenticated SELECT=true; INSERT/UPDATE/DELETE=false; RLS=false; FORCE RLS=false.
- `aos_whatsapp_mensajes`: anon/authenticated SELECT=true; INSERT/UPDATE/DELETE=false; RLS=false; FORCE RLS=false.

Issue #173 therefore remains OPEN but has narrowed materially: the remaining security/architecture work is browser SELECT retirement/gateway cutover plus RLS/FORCE RLS or explicit legacy retirement, not further browser mutation hardening.

## V10 allowed scope
1. Inventory every repository consumer of `aos_plantillas_whatsapp` and `aos_whatsapp_mensajes` from CURRENT main.
2. Design a server-authoritative read gateway/RPC/API contract for the minimum template data required by current UI consumers.
3. Add synthetic negative tests proving browser roles cannot mutate governed or legacy messaging configuration and cannot bypass the new gateway after cutover.
4. Preserve current UI compatibility until the gateway consumer smoke is proven.
5. Only after exact-head CI is green and read-only production preflight confirms compatibility, perform a controlled additive gateway/cutover migration and then remove legacy browser SELECT.
6. Validate outbound policy, webhook replay/idempotency, controlled canary, rollback/recovery and zero-residue as separate evidence-backed release gates.
7. Keep SMS provider activation/spend OFF and do not broad-send WhatsApp during certification.

## Hard invariants
- Same canonical Audience Engine for Email/SMS/WhatsApp/future channels.
- No channel-specific audience/customer/lead/patient truth.
- Canonical contact identity remains the linkage key.
- Unknown consent/suppression fails closed.
- Provider webhooks are signed/replay-safe where applicable and all event ingestion is idempotent.
- Secrets remain environment-only.
- Governed tables remain RLS + FORCE RLS and server/service-role authoritative.
- No PII/PHI, phone numbers, message content, tokens or secrets in CI/issues/logs.

## Production certification gate
F17 may be marked `100_COMPLETE / PRODUCTION CERTIFIED` only when production `aos_cia_f18_readiness_v1()` returns exactly `READY_F18_MULTICHANNEL_CERTIFIED` with `ready_for_f18=true`, all release gates are true, Issue #173 is closed, exact-head repository gates are green, rollback/recovery and zero-residue evidence are proven, and the final release is merged according to governance.
