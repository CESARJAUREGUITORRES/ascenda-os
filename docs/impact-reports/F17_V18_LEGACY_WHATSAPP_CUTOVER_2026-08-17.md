# F17 V18 — Legacy WhatsApp Cutover Impact Report

Date: 2026-08-17
Base: `main@13dafdb4711c9554718a4846c5ed644e016dd42e`
Branch: `feature/cia-phase17-multichannel-20260817-v18`

## Objective

Close the remaining CRITICAL legacy WhatsApp browser-read boundary tracked in #173 without creating a parallel audience/customer/lead truth and without changing provider spend or enabling broad sends.

## Fresh preflight evidence

- Production F16 readiness exists and returns `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true` and all F16 release gates true.
- GitHub Issue #104 is closed/completed.
- Production F17→F18 readiness remains fail-closed: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`.
- F17 gates currently true: `contracts_active`, `whatsapp_bridge_validated`.
- F17 gates still false: `outbound_policy_validated`, `webhook_replay_validated`, `canary_passed`, `rollback_verified`.
- Issue #173 remains open.
- Production `aos_plantillas_whatsapp` and `aos_whatsapp_mensajes` expose only `SELECT` to `anon`/`authenticated`; write privileges are already removed. Both still have RLS/FORCE RLS disabled.
- Current `main` exact-head `Ascenda CI` is green.

## Hard invariants

1. Keep the canonical Audience Engine and identity/contact model as the sole source of truth.
2. Do not create WhatsApp-, SMS-, or provider-specific audience/customer/lead tables.
3. Provider/backend integrations remain adapters/facts, not identity truth.
4. Fail closed for authorization, consent/suppression, malformed requests, replay/idempotency and missing configuration.
5. Never log PII/PHI, phone numbers, message bodies, secrets or provider tokens.
6. Zero-cost/self-hosted CI only. No paid fallback.
7. No production ACL/RLS mutation until exact-head CI is green and a read-only compatibility + rollback preflight passes.
8. No provider activation, broad-send or external spend in this scope.

## Intended V18 scope

- Inventory every remaining runtime/browser consumer of the two legacy WhatsApp tables.
- Wire the already merged server-authoritative legacy WhatsApp gateway into the active runtime only where required.
- Replace direct browser table reads with the gateway contract where a consumer still exists.
- Add synthetic negative tests for unauthenticated/unauthorized access, malformed input, direct-table bypass, and data-minimizing responses/logging.
- Prepare an additive/reversible ACL/RLS cutover migration only after compatibility is proven in CI.
- Require explicit rollback/recovery and zero-residue checks before any controlled production cutover.

## Blast radius

Expected: legacy WhatsApp template/message read paths, server route wiring, F17 CI, and later (separate gated step) ACL/RLS on the two legacy tables. No canonical Audience Engine schema changes are expected.

## Rollback strategy

Before production mutation, preserve the exact pre-cutover grants/RLS state as machine-checkable evidence. Any production cutover must have a tested reverse migration restoring only the prior read contract, followed by consumer smoke and zero-residue verification. If gateway compatibility or authorization checks fail, do not revoke browser SELECT and do not enable FORCE RLS.

## Exit criteria for #173 block

- No direct browser access to legacy WhatsApp tables.
- Server-authoritative gateway compatibility proven.
- `anon`/`authenticated` direct table privileges removed.
- RLS/FORCE RLS posture deliberately enabled or legacy tables safely retired, with policies/ownership documented.
- Negative authorization tests pass.
- Rollback/recovery passes with zero residue.
- Exact-head repository gates green and production postflight matches the declared state.
