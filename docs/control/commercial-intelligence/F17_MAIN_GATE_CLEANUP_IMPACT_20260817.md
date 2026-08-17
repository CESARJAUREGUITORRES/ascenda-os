# F17 main gate cleanup — Impact Report — 2026-08-17

## Context

F17 V17 is merged on `main@262feba72f73ad8aceb9514d37a824033d74fd7c`. Production F16 is authoritatively certified (`READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`). F17 remains fail-closed (`IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`) with outbound policy, webhook replay/idempotency, canary, rollback and legacy WhatsApp ACL retirement still pending.

## Fresh repository finding

The obsolete one-shot workflow `.github/workflows/f16-provider-outcomes-test-adapt.yml` creates a failed GitHub Actions check suite on current `main` with zero jobs. The workflow is scoped to the historical branch `hotfix/f16-resend-outcomes-20260815` and is no longer part of F16 certification, which is closed by production evidence and Issue #104.

## Intended change

Make the historical F16 adaptation workflow manual-only so future `main` pushes do not create a false red exact-head signal. Preserve the workflow body for audit/manual recovery; do not alter F16/F17 application code, database schema, provider configuration, production ACL, messaging transport or Audience Engine contracts.

## Safety invariants

- No production mutation.
- No provider activation or spend.
- No PII/PHI, phone numbers, message contents, tokens or secrets.
- Zero-Cost/self-hosted CI only.
- One canonical Audience/Activation/contact identity truth; no channel-specific audience tables.
- F17 remains fail-closed until authoritative `READY_F18_MULTICHANNEL_CERTIFIED` evidence exists.

## Rollback

Revert the workflow-only commit if manual hotfix branch automation must be restored. Production is unaffected.