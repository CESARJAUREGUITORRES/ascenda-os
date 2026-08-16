# ASCENDA CIA V3 — F17 Impact Report V14

## Baseline
- Fresh base: `main@3a4a26d06d45960f1a12ac8c68c21d47fe57525e`.
- F16 production readiness is authoritative and certified: `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`, all F16 release gates=true; Issue #104 closed/completed.
- F17 production readiness remains fail-closed: `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, `ready_for_f18=false`.
- Passing F17 gates: `contracts_active`, `whatsapp_bridge_validated`.
- Pending F17 gates: `outbound_policy_validated`, `webhook_replay_validated`, `canary_passed`, `rollback_verified`.

## Reason for V14
V13 PR #197 was created from an earlier current-main and later became non-mergeable after unrelated Sentinel work advanced `main`. Its exact-head Zero-Cost DB contract also exposed a branch-only syntax regression in `ci/f17-multichannel/test_legacy_whatsapp_gateway.js` (`Unexpected token ')'` at line 53). V14 starts from fresh CURRENT main and ports only the previously intended legacy WhatsApp gateway preparation using the syntactically valid V12 fixture.

## Production risk / #173
Production preflight still shows `aos_plantillas_whatsapp` and `aos_whatsapp_mensajes` with RLS/FORCE RLS disabled and direct browser `SELECT` for `anon`/`authenticated`. Prior P0 hardening removed direct browser write privileges. Issue #173 remains OPEN.

This branch does not revoke the remaining browser SELECT, enable provider spend, broad-send messages, expose PII/PHI, or mutate production. It prepares a server-authoritative read gateway and synthetic fail-closed negatives so the eventual cutover can be proven compatible before ACL closure.

## Architectural invariant
- One canonical Audience/Activation/contact identity truth.
- No channel-specific audience/customer/lead/patient truth.
- Provider/backend remains interchangeable.
- Channel-specific infrastructure may store transport/conversation/event facts only.

## Scope
1. Port the service-role-only, app-session-authorized legacy WhatsApp template read gateway.
2. Port synthetic authorization/upstream failure tests.
3. Extend the Zero-Cost F17 workflow to validate the gateway before isolated DB ACL contracts.
4. Require fresh exact-head green evidence before any production cutover.

## Rollback
Branch-only changes can be dropped with no production residue. Any future production ACL cutover remains separately gated by read-only preflight, compatibility smoke, rollback proof, and #173 closure criteria.
