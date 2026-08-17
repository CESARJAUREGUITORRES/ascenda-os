# CIA V3 F17 — Impact Report V17

Date: 2026-08-16 (Lima)
Baseline: `main@24a36b64ca85a856a5640f306435405c0b5d92ac`
Branch: `feature/cia-phase17-multichannel-20260816-v17`

## Authoritative preflight

- F16 production readiness is certified: `aos_cia_email_f17_readiness_v1()` returns `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`; all F16 release gates are true and Issue #104 is CLOSED/completed.
- F17 production remains fail-closed: `aos_cia_f18_readiness_v1()` returns `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.
- Current passing F17 gates: `contracts_active`, `whatsapp_bridge_validated`.
- Current pending F17 gates: `outbound_policy_validated`, `webhook_replay_validated`, `canary_passed`, `rollback_verified`.
- CRITICAL Issue #173 remains OPEN; legacy WhatsApp browser SELECT / RLS retirement is not yet certified.
- V16 exact-head `f4b15ad61bb0cf0da778ca7c7f558fd25e292bcf` completed 3/3 workflows SUCCESS after the self-hosted workspace ownership repair, but main subsequently advanced; that evidence is historical and will not be reused as V17 exact-head certification.

## Scope

Reconcile only the already validated server-authoritative legacy WhatsApp template gateway, its fail-closed synthetic negatives, and Zero-Cost/self-hosted CI workflow hardening onto the current main baseline. No production ACL cutover, provider activation, broad send, SMS activation, provider spend, or PII/PHI/message-content logging is in scope for this branch.

## Architectural invariant

One canonical Audience/Activation/contact identity truth. Provider/backend remains interchangeable. No channel-specific audience/customer/lead/patient truth or duplicated audience tables.

## Production safety gate

Require fresh exact-head V17 gates green before any controlled production compatibility/cutover work for Issue #173. Production changes, if later authorized by the existing governance, must follow read-only preflight → consumer smoke → narrowly scoped ACL/RLS cutover → rollback/recovery → zero-residue evidence.
