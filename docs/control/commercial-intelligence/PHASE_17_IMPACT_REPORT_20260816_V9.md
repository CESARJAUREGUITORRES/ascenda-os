# CIA V3 F17 — Impact Report V9

Date: 2026-08-16 (Lima)
Baseline: `main@a9b20ca6e6890ab733e1f0eadbb41ea75904fc89`
Branch: `feature/cia-phase17-multichannel-20260816-v9`
Risk: CRITICAL

## Objective
Continue F17 — SMS / WhatsApp / Future Channels from CURRENT main while preserving one canonical Audience/Activation/identity truth. Providers and transport backends remain interchangeable implementation details.

## Authoritative entry gate
Fresh production evidence confirms `public.aos_cia_email_f17_readiness_v1()` exists and returns `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`; all F16 release gates are true. GitHub Issue #104 is CLOSED/completed.

## Current F17 production state
Fresh production `public.aos_cia_f18_readiness_v1()` remains `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.

Passing gates:
- `contracts_active=true`
- `whatsapp_bridge_validated=true`

Open gates:
- `outbound_policy_validated=false`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `rollback_verified=false`

## Fresh production security finding
Issue #173 remains OPEN. Read-only metadata verification confirms:
- `aos_plantillas_whatsapp`: RLS/FORCE RLS disabled; browser roles retain SELECT plus INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER.
- `aos_whatsapp_mensajes`: RLS/FORCE RLS disabled; browser roles retain SELECT.

The modern governed `aos_wa_*` and provider-neutral F17 channel contracts remain the authoritative messaging boundary. No certification is permitted while legacy browser mutation can bypass that boundary.

## V8 reconciliation evidence
V8 exact-head `7defb15c35f9fe89f1906230b350ed3e9e284071` obtained SUCCESS on all three F17/PR workflows. A separate legacy `f16-provider-outcomes-test-adapt` push run reported FAILURE but exposed zero jobs, so it is recorded as an orchestration anomaly rather than functional F17 evidence. V8 is now diverged from CURRENT main (7 commits ahead / 3 behind), therefore V9 is created cleanly from CURRENT main instead of force-rebasing production work.

## Allowed scope on V9
1. Port the already-proven compatibility-preserving P0 ACL remediation from V8.
2. Preserve browser SELECT temporarily for the observed template-reading consumer while removing browser mutation privileges.
3. Keep recovery fail-closed; never restore unnecessary write privileges.
4. Re-run self-hosted Zero-Cost synthetic negative authorization on this exact head.
5. Define and execute consumer compatibility smoke before any production ACL mutation.
6. Continue provider-neutral outbound policy and webhook replay/idempotency validation only after the ACL release vehicle is clean.
7. Keep SMS provider activation/spend OFF; no broad WhatsApp send during certification.

## Hard invariants
- No channel-specific audience/customer/lead/patient truth.
- No duplicated Audience Engine tables per SMS, WhatsApp or future channel.
- Canonical contact identity remains the linkage key.
- Unknown consent/suppression fails closed.
- Webhooks must be signed/replay-safe where applicable and idempotent.
- Secrets remain environment-only.
- New governed tables remain RLS + FORCE RLS and server/service-role authoritative.
- No PII/PHI, phone numbers, message content, tokens or secrets in CI/issues/logs.

## Production gate
Before any F17 production mutation on V9: exact-head CI must be green; production ACL/readiness must be re-read; consumer compatibility smoke must pass; migration scope must have exact fail-closed recovery; and the change must remain limited to the declared F17 ACL boundary.

F17 may be marked `100_COMPLETE / PRODUCTION CERTIFIED` only when production `aos_cia_f18_readiness_v1()` returns exactly `READY_F18_MULTICHANNEL_CERTIFIED` with `ready_for_f18=true`, all release gates are true, Issue #173 is closed, repository gates are clean, rollback/recovery and zero-residue evidence exist, and the final release is merged according to governance.