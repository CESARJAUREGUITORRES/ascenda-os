# ASCENDA OS — CIA V3 F17 Impact Report V5

Date: 2026-08-15 Lima
Base: `main@73990606d3e5aa89c2e4eade163ab6a2faf206a3`
Mode: F17 production entry is now permitted, but only through additive/provider-neutral contracts, exact-head CI, canary and rollback gates.

## Source-of-truth objective
Extend the existing canonical Audience/Activation Engine to WhatsApp, SMS and future messaging channels without creating channel-specific audience/customer/lead truth. Provider/backend remains interchangeable. Channel-specific components may own transport, conversation, dispatch and provider event facts only.

## Authoritative F16 gate — CLOSED
Fresh production evidence before starting this branch:
- `aos_cia_email_f17_readiness_v1()` returns `status=READY_F17_EMAIL_CERTIFIED`.
- `ready_for_f17=true`.
- all F16 release gates are true: gateway, provider, signed webhook, exact replay/canary, rollback, legacy ACL hardening and admin gateway-only.
- direct browser access to governed Email tables is blocked for `anon` and `authenticated`.
- `illegal_send_states=0`.
- GitHub Issue #104 is CLOSED as completed.
- F16 is `Cerrada / 100%` in the CIA V3 control master.

Therefore F17 is formally unblocked.

## Existing multichannel baseline on current main
ASCENDA already contains WhatsApp transport/routing work from WA-1/WA-2/WA-3 and later shell/recovery hotfixes. This infrastructure is treated as channel transport/fact infrastructure, not a second Audience Engine. F17 must wrap/reconcile it behind canonical CIA contracts rather than fork customer or audience truth.

## Hard invariants
1. Reuse canonical Audience/Activation and canonical contact identity.
2. No new per-channel audience, customer, patient or lead truth tables.
3. Provider/backend-specific adapters sit behind provider-neutral channel contracts.
4. Secrets remain environment-only and server-side; never browser/DB/CI/issue content.
5. Outbound requests require authorization, consent/suppression decision and idempotency before provider dispatch.
6. Inbound webhooks require verification where the provider supports it, replay protection and provider-event idempotency.
7. UNKNOWN consent is not permission. Opt-out/suppression must fail closed.
8. Phone/e-mail/channel endpoints link to canonical identity; they do not become identity truth.
9. Conversation/message/event facts preserve attribution linkage without duplicating Audience state.
10. Production cutover requires canary, rollback and zero-residue proof.

## F17 target contract
The additive provider-neutral layer should cover:
- channel endpoint reference linked to canonical contact identity;
- outbound message request with channel, purpose, activation/context provenance and idempotency key;
- dispatch attempt/provider result;
- provider webhook receipt/deduplication;
- inbound message fact;
- delivery/read/failure event fact;
- conversation/thread linkage;
- consent/suppression decision reference;
- attribution touch linkage;
- assignment/routing linkage;
- release-state/readiness contract for F18.

## Compatibility strategy
- Existing WhatsApp tables/routes remain operational during transition.
- F17 starts additive and read-through/reconciliation-first.
- Existing WA transport may be used as the first adapter after the provider-neutral contract passes synthetic CI.
- No destructive ACL/schema change is permitted until consumer compatibility is proven.
- SMS stays provider-neutral: schema/contracts may support it before any paid provider is activated.

## Security gates
- RLS/FORCE RLS on new governed tables.
- no `anon`/`authenticated` direct write access.
- server-authoritative admin/session gate for outbound operations.
- channel/provider secrets environment-only.
- idempotent outbound dispatch and webhook ingestion.
- replay-safe webhook/event handling.
- suppression/consent fail closed.
- no PII/PHI in CI evidence.

## Execution order
1. Inventory current WhatsApp/SMS/channel facts and current server routes.
2. Map existing WA facts to canonical identity/Audience/Activation.
3. Materialize additive provider-neutral F17 schema + readiness contract in branch only.
4. Build synthetic contracts/negative tests: duplicate dispatch, replay, unknown consent, unauthorized caller, provider failure, rollback.
5. Run FAST-01/FAST-02 static/runtime checks and ZERO-COST DB/contracts.
6. Production read-only preflight and exact-head certification.
7. Apply additive production migration.
8. Canary WhatsApp adapter with fixed allowlist/no broad messaging.
9. Verify inbound/outbound/provider outcomes and rollback.
10. Mark F17 production-ready only after authoritative readiness is true.

## Production safety
No SMS spend or broad WhatsApp send is authorized by this report. The first production activation must be a fixed canary/allowlist using existing configured infrastructure. Any provider that would introduce new paid spend remains disabled until its own canary gate is explicitly satisfied.
