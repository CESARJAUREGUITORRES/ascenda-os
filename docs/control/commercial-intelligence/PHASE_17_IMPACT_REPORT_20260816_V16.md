# CIA V3 F17 — Impact Report V16

Date: 2026-08-16
Base: `main@01958565af1a5ffe426ffb0ac9e0588c77341175`
Branch: `feature/cia-phase17-multichannel-20260816-v16`

## Fresh authoritative gate

- Production F16 readiness exists and returns exactly `READY_F17_EMAIL_CERTIFIED` with `ready_for_f17=true`.
- All F16 release gates are true; browser direct Email table access is false for `anon` and `authenticated`; illegal send states = 0.
- GitHub Issue #104 is CLOSED/completed.
- Production F17 readiness remains `IN_PROGRESS_MULTICHANNEL_GOVERNANCE` with `ready_for_f18=false`.
- F17 gates true: `contracts_active`, `whatsapp_bridge_validated`.
- F17 gates false: `outbound_policy_validated`, `webhook_replay_validated`, `canary_passed`, `rollback_verified`.
- CRITICAL #173 remains OPEN.
- Fresh production legacy WhatsApp ACL metadata: `aos_plantillas_whatsapp` and `aos_whatsapp_mensajes` are SELECT-only for browser roles but still have RLS/FORCE RLS disabled.

## Why V16

V15 PR #203 reached exact-head green, but `main` advanced by 45 unrelated Sentinel commits after its base. Fresh compare shows no overlap between those intervening changes and the F17 gateway/workflow/test paths. V16 starts from CURRENT main and ports only the already-green gateway preparation, then requires fresh exact-head evidence.

## Scope

- Service-role-only, app-session-authorized legacy WhatsApp template read gateway.
- Synthetic fail-closed negative tests.
- Zero-Cost/self-hosted CI validation.
- No production ACL cutover in this branch step.
- No broad-send, SMS/provider activation, provider spend, PII/PHI, phone numbers, message contents, tokens or secrets in CI/issues/logs.

## Architectural hard gate

One canonical Audience/Activation/contact identity truth. No duplicated audience/customer/lead/patient truth per channel. Provider/backend remains interchangeable and channel-specific infrastructure is transport/facts only.

## Production gate

Do not retire legacy browser SELECT or mutate F17 production until fresh exact-head gates are green, compatibility smoke is proven, rollback/recovery is demonstrated, and #173 exit criteria are satisfied.