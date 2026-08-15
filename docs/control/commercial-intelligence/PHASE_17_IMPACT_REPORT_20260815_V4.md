# ASCENDA OS — CIA V3 F17 Impact Report V4

Date: 2026-08-15
Base: `main@bb04bf1cb207c96dc39ed54958690fd728b77c95`
Mode: discovery/design/CI only; production F17 mutation prohibited until F16 readiness is authoritative and true.

## Source-of-truth objective
Extend the existing canonical Audience Engine to SMS, WhatsApp and future messaging channels without creating channel-specific audience/customer/lead truth. Provider/backend remains interchangeable. Channel-specific components may own transport, conversations, delivery events and provider facts only.

## Authoritative F16 gate
Fresh production read-only evidence:
- `aos_cia_email_f17_readiness_v1()` exists.
- Current status is `IN_PROGRESS_DELIVERY_GOVERNANCE`.
- `ready_for_f17=false`.
- Release gates currently true: gateway active, admin UI gateway-only, legacy ACL hardening, rollback verified.
- Release gates currently false: provider configured, webhook verified, canary passed.
- GitHub Issue #104 remains OPEN.

Therefore F17 production migration, provider activation/spend and production channel cutover remain blocked.

## Current multichannel baseline discovered on current main
- Existing WhatsApp server/webhook handling is present in `app/server.js`.
- WA-1 secure gateway assets exist, including migration, recovery SQL, isolated CI schema/tests and workflow.
- WA-2 conversation/live-inbox contracts exist.
- WhatsApp Revenue Hub control/impact documentation exists.
- Existing WhatsApp tables and transport/routing infrastructure are channel facts, not an Audience Engine replacement.

## F17 hard invariants
1. Reuse canonical Audience/Activation and canonical identity resolution.
2. No new per-channel audience, customer, lead or patient truth tables.
3. Provider/backend-specific adapters must sit behind provider-neutral contracts.
4. Secrets remain environment-only; never persist provider tokens in repository, issues, CI logs or browser code.
5. Outbound requests require idempotency and fail-closed authorization.
6. Inbound webhooks require signature verification where supported, replay protection and provider-event idempotency.
7. Consent/opt-out/suppression must be enforced before send; UNKNOWN consent is not equivalent to permission.
8. Phone identity must normalize into canonical identity/linkage rather than create channel-local identity truth.
9. Message/conversation/event facts must preserve attribution linkage without exposing PII/PHI in operational evidence.
10. Production readiness must include rollback/recovery and zero-residue proof.

## Additive target contracts — design only while F16 is blocked
Provider-neutral primitives should cover:
- channel endpoint/identity reference;
- outbound message request + idempotency key;
- provider dispatch attempt/result;
- inbound message fact;
- delivery/read/failure/provider event fact;
- conversation/thread fact;
- consent and suppression decision reference;
- attribution touch linkage;
- assignment/routing linkage;
- webhook receipt/deduplication evidence.

Names and schema are intentionally not materialized in production in this report. Any future migration must prove it references canonical Audience/Activation and identity contracts and does not duplicate audience truth.

## F8/F16 dependencies
- F8 supplies canonical Audience/Activation semantics and attribution-facing audience truth.
- F16 supplies the governed messaging pattern: authoritative backend boundary, idempotent send request, provider outcome tracking, signed/replay-safe webhook handling, environment-only secrets, ACL hardening, rollback and readiness contract.
- F17 must generalize these patterns across channels rather than clone F16 tables per channel.

## Safe preparation allowed now
- repository inventory;
- provider-neutral schema/design review;
- synthetic fixtures;
- negative tests for duplicate/replay/idempotency/consent/suppression/auth;
- Zero-Cost/self-hosted CI;
- exact-head Impact Report/checkpoint synchronization.

## Production entry criteria
F17 production work may start only when authoritative production evidence returns:
- `status = READY_F17_EMAIL_CERTIFIED`;
- `ready_for_f17 = true`;
- required F16 provider/webhook/canary/rollback/ACL evidence is complete;
- Issue #104 exit criteria are resolved/closed.

Until then this branch is a preparation vehicle only.