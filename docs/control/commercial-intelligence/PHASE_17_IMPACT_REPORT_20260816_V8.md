# CIA V3 F17 — Impact Report V8

Date: 2026-08-16 (Lima)
Baseline: `main@d362442cc111cb712cc627a7e8118e3b190c15b5`
Branch: `feature/cia-phase17-multichannel-20260816-v8`
Risk: CRITICAL

## Objective
Advance F17 — SMS / WhatsApp / Future Channels toward production certification while preserving one canonical Audience/Activation/identity truth. Providers and transport backends remain interchangeable implementation details.

## Authoritative entry gate
Production `public.aos_cia_email_f17_readiness_v1()` exists and returns `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`; all F16 release gates are true. GitHub Issue #104 is CLOSED/completed.

## Current F17 production state
`public.aos_cia_f18_readiness_v1()` returns `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.

Passing gates:
- `contracts_active=true`
- `whatsapp_bridge_validated=true`

Open gates:
- `outbound_policy_validated=false`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `rollback_verified=false`

## Fresh production security finding
Issue #173 remains OPEN. Read-only metadata verification on this baseline confirms:
- `aos_plantillas_whatsapp`: RLS/FORCE RLS disabled; browser roles retain SELECT plus broad mutation-capable privileges.
- `aos_whatsapp_mensajes`: RLS/FORCE RLS disabled; browser roles retain SELECT.

The modern governed `aos_wa_*` and F17 generic channel contracts must remain the authoritative messaging boundary. No certification is permitted while legacy browser mutation can bypass that boundary.

## Repository health
CURRENT main advanced through WhatsApp Phase S stabilization. Exact-head GitHub Actions still includes `f16-provider-outcomes-test-adapt` reporting FAILURE with zero jobs. Treat this as an unresolved exact-head repository gate until revalidated/explained; do not use it as evidence of functional failure by itself.

## Allowed scope on V8
1. Compatibility-preserving remediation of legacy WhatsApp mutation privileges, preserving required read compatibility until consumers are migrated.
2. Provider-neutral outbound policy validation against canonical consent/suppression controls.
3. Replay/idempotency validation for governed provider events/webhooks without logging PII, message contents, phone numbers, tokens or secrets.
4. Synthetic canary and rollback/recovery contracts first; production canary only after exact-head gates and fresh read-only preflight are clean.
5. Keep SMS provider activation/spend OFF unless configuration and explicit owner authorization for a new paid/critical provider action are present.

## Hard invariants
- No channel-specific audience/customer/lead/patient truth.
- No duplicated Audience Engine tables per SMS, WhatsApp or future channel.
- Canonical contact identity remains the linkage key.
- Unknown consent/suppression fails closed.
- Webhooks must be signed/replay-safe where applicable and idempotent.
- Secrets remain environment-only.
- New governed tables remain RLS + FORCE RLS and server/service-role authoritative.
- No broad send during certification.

## Production gate
Before any F17 production mutation on this branch: exact-head CI must be green or the zero-job workflow anomaly must be explicitly resolved; production ACL/readiness must be re-read; migration scope must have exact rollback; consumer compatibility smoke must be defined. F17 may be marked `100_COMPLETE / PRODUCTION CERTIFIED` only when `aos_cia_f18_readiness_v1()` returns `READY_F18_MULTICHANNEL_CERTIFIED` with `ready_for_f18=true`, all release gates true, Issue #173 closed/completed, rollback/recovery proven, and repository exact-head gates are clean.