# CIA V3 F17 — Impact Report V13

Date: 2026-08-16 (America/Lima)
Base: `main@00797fe87869f4cee8a11414de1f1de262e8c109`
Branch: `feature/cia-phase17-multichannel-20260816-v13`

## Fresh authoritative preflight
- F16 production readiness exists and returns exactly `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`.
- All F16 release gates are true; Issue #104 is CLOSED/completed.
- F17 production readiness remains `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.
- F17 gates currently true: `contracts_active`, `whatsapp_bridge_validated`.
- F17 gates currently false: `outbound_policy_validated`, `webhook_replay_validated`, `canary_passed`, `rollback_verified`.
- CRITICAL Issue #173 remains OPEN.

## Why V13
V12 PR #193 reached 3/3 exact-head workflow SUCCESS at `c53c6f5c9255b4c341e46393ba16306d4278aa79`, but `main` advanced by 29 commits after its base and the PR became non-mergeable. Fresh compare shows the intervening `main` changes do not overlap the V12 gateway/workflow/test paths. V13 therefore starts from CURRENT main and ports only the previously green, branch-only gateway preparation after this Impact Report is committed.

## Scope
- Reconcile the service-role-only, app-session-authorized legacy WhatsApp template gateway with CURRENT main.
- Preserve fail-closed authorization and synthetic negative tests.
- Keep Zero-Cost/self-hosted CI.
- No destructive production ACL cutover in this report/branch preparation step.

## Hard invariant
One canonical Audience Engine / Activation / contact identity truth. No duplicated audience, customer, lead, patient, or campaign truth per channel.

## Safety
- No provider activation or spend.
- No broad-send.
- No production mutation before exact-head gates are green and fresh read-only preflight confirms compatibility.
- No PII/PHI, phone numbers, message bodies, provider tokens, or secrets in CI/issues/logs.
- #173 remains fail-closed until browser legacy SELECT/RLS retirement is proven with compatibility smoke and rollback.
