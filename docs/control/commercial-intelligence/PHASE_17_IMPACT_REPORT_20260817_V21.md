# CIA V3 F17 — V21 CURRENT Closeout Impact Report

Date: 2026-08-17 America/Lima
Exact baseline: `main@addd14f2a57f06ec54b5ace10e042f4d8b69a85a`
Workstream: `CIA-F17`

## Authoritative preflight

Production Supabase project: `ituyqwstonmhnfshnaqz`.

F16→F17 readiness is certified:
- `aos_cia_email_f17_readiness_v1()` exists.
- `status=READY_F17_EMAIL_CERTIFIED`.
- `ready_for_f17=true`.
- all seven F16 release gates are true.
- `illegal_send_states=0`.
- browser direct table access is false for `anon` and `authenticated`.
- GitHub #104 is closed/completed.

F17→F18 remains fail-closed:
- `status=IN_PROGRESS_MULTICHANNEL_GOVERNANCE`.
- `ready_for_f18=false`.
- true: `contracts_active`, `whatsapp_bridge_validated`, `outbound_policy_validated`, `rollback_verified`.
- false: `webhook_replay_validated`, `canary_passed`.
- `illegal_send_states=0`.
- browser direct table access is false for `anon` and `authenticated`.
- GitHub #173 is closed/completed.

## CURRENT alignment

PR #265 is merged and production runtime now includes F17 in the effective chain:
`Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4`.

This physical traversal is necessary but is not evidence that the remaining F17 replay/canary gates passed.

PR #261 is historical/stale evidence and must not be merged wholesale. V21 starts from exact CURRENT `main` to avoid reusing stale exact-head evidence.

## Scope

V21 is the controlled closeout vehicle for the two remaining F17 functional gates and F17-owned migration-history reconciliation only.

1. Revalidate runtime-chain and provider-neutral F17 contracts against CURRENT.
2. Prove signed Meta WhatsApp webhook traversal through the production F17 boundary.
3. Prove replay/idempotency with no duplicate side effects.
4. Run exactly one owner-authorized, allowlisted outbound canary when fresh authorization and an approved recipient are available.
5. Re-read production readiness and require both remaining gates to become true.
6. Prove rollback/recovery and zero-residue.
7. Require exact-head CI/deployment smoke before merge/closure.
8. Reconcile only the F17-owned slice of #238 without re-running historical production DDL or falsifying migration history.

## Architectural invariants

- One canonical Audience Engine and one canonical identity/contact truth.
- No duplicated audience/customer/lead/patient tables per channel.
- Providers/backends remain interchangeable transport adapters.
- Channel facts, conversations and provider events link back to canonical identity/audience/activation/attribution contracts.
- Consent, suppression and opt-out fail closed.
- Webhooks must be signed and replay-safe.
- Idempotency is mandatory for inbound/outbound provider interactions.
- Secrets remain environment-only/server-side.
- No PII/PHI, phone numbers, message bodies, tokens or secrets in CI/issues/logs.

## Safety boundaries

- No broad-send.
- No SMS/provider activation or paid fallback.
- No new provider spend.
- No production mutation merely to create a green status.
- No canary without fresh owner authorization and an allowlisted owner-controlled recipient.
- No F18 implementation until production returns `READY_F18_MULTICHANNEL_CERTIFIED` with `ready_for_f18=true` and closeout evidence is clean.

## Rollback

Any additive F17 closeout change must have a versioned rollback/recovery path and a post-rollback proof of zero duplicate side effects and zero residue. If exact-head CI, production preflight or authorization gates fail, V21 remains draft/fail-closed.