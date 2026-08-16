# ASCENDA OS — CIA V3 F17 Impact Report V6

Date: 2026-08-15 Lima
Base: `main@db7a172a2d3b95127fe1695f816b49167e667fbd`
Mode: additive/provider-neutral F17 preparation. No production mutation until the exact current main deployment gate is green.

## Fresh authoritative entry gate
Production `aos_cia_email_f17_readiness_v1()` exists and currently returns:
- `status=READY_F17_EMAIL_CERTIFIED`
- `ready_for_f17=true`
- all F16 release gates true
- `delivery_enabled=true`
- `illegal_send_states=0`
- browser direct governed Email table access false for both `anon` and `authenticated`

GitHub Issue #104 is CLOSED as completed. F16 is therefore genuinely certified for F17 entry.

At creation time, the newest `main@db7a172...` Railway exact-head status is still pending because main advanced with WhatsApp shell/recovery documentation after the previously green F16 head. This does not revoke the authoritative F16 production readiness, but it blocks any new F17 production cutover until exact-head deployment is green.

## Source-of-truth objective
Extend the same canonical Audience/Activation Engine to WhatsApp, SMS and future messaging. Provider/backend remains interchangeable. Output is unified multichannel messaging for attribution. No audience/customer/lead truth may be duplicated per channel.

## Existing production baseline
Current production already contains WhatsApp transport/routing facts and functions, including:
- `aos_wa_conversations_v1`
- `aos_wa_messages_v1`
- `aos_wa_events_v1`
- `aos_wa_outbound_requests_v1`
- `aos_wa_conversation_events_v1`
- `aos_wa_boxes_v1`, `aos_wa_box_members_v1`, `aos_wa_assignments_v1`, `aos_wa_routing_events_v1`, `aos_wa_routing_control_v1`
- WA-2 conversation projection/binding functions
- WA-3 actor/routing/handoff/human-send authorization functions
- WA-4 AI control/authorization facts

These objects are transport/conversation/routing facts. They are not a second Audience Engine.

## Hard invariants
1. Reuse canonical Audience/Activation and canonical contact identity.
2. No per-channel audience, customer, patient or lead truth tables.
3. Provider-specific adapters sit behind provider-neutral channel/message contracts.
4. Secrets remain environment-only and server-side.
5. Outbound dispatch requires server-authoritative authorization, consent/suppression decision and idempotency before provider send.
6. Inbound/provider webhooks require signature/verification where available plus replay protection and event idempotency.
7. UNKNOWN consent is not permission; opt-out/suppression is fail-closed.
8. Phone/channel endpoints reference canonical identity and never become identity truth.
9. Conversation/message/event facts preserve activation/context/attribution provenance.
10. Production cutover requires canary, rollback/recovery and zero-residue proof.
11. No PII/PHI, phone numbers, message content, tokens or secrets in CI/issues/log evidence.
12. No new paid provider activation or spend without verified configuration and owner authorization.

## F17 additive target contract
The provider-neutral layer must cover:
- canonical channel endpoint reference linked to contact identity;
- outbound message request with channel, purpose, activation/context provenance and idempotency key;
- consent/suppression decision reference and audit provenance;
- dispatch attempt/provider result;
- replay-safe provider webhook receipt/deduplication;
- inbound message fact;
- delivery/read/failure event fact;
- conversation/thread linkage;
- assignment/routing linkage;
- attribution touch linkage;
- release/readiness contract for F18.

## Compatibility strategy
- Existing WA runtime remains intact while F17 starts additive/read-through/reconciliation-first.
- Existing WA tables may serve as the first provider adapter after synthetic CI proves the neutral contract.
- Do not destructively rewrite WA-1/WA-2/WA-3 stores in the first F17 migration.
- SMS is schema-capable but provider-disabled until a provider is explicitly configured and authorized.

## Required negatives
Synthetic/Zero-Cost tests must prove:
- duplicate outbound idempotency key cannot double-send;
- duplicate/replayed provider event cannot double-project;
- unauthorized browser/authenticated caller cannot dispatch or mutate governed facts;
- UNKNOWN/denied consent blocks marketing send;
- explicit opt-out/suppression blocks future eligible sends;
- provider failure remains auditable and non-delivered;
- attribution linkage points to canonical activation/context, not duplicated audience rows;
- rollback disables dispatch first and leaves no active residue.

## Execution order
1. Inventory WA/SMS/channel schemas, grants, RLS, server routes, provider config patterns and canonical identity linkage.
2. Map WA facts to canonical contact identity/Audience/Activation.
3. Materialize additive provider-neutral F17 schema and F18 readiness contract in branch only.
4. Build Zero-Cost synthetic fixtures and negative tests.
5. Require exact-head GitHub/Railway gates green.
6. Production read-only preflight.
7. Controlled additive migration only after gates pass.
8. Fixed allowlist WhatsApp canary using existing configured infrastructure; no patient-real broad send.
9. Verify inbound/outbound/event idempotency, consent enforcement, attribution linkage and rollback.
10. Only then set F17 `100_COMPLETE / PRODUCTION CERTIFIED` and F18 READY.

## Current hold
F17 production remains unmutated in this checkpoint. The only temporary hold is the latest `main@db7a172...` Railway deployment still pending. Branch-only discovery/design/CI may continue safely.
