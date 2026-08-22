# ASCENDA OS — MKT Integrity V3 · Loop 6 V2.3 · CI Rearm

Date (Lima): 2026-08-21
Workstream: MKT-INTEGRITY-HOTFIX-V3
PR: #342

## Purpose

Re-arm all pull-request CI gates after the self-hosted runtime patcher materialized the final V2.3 frontend. GitHub Actions-generated commits do not recursively execute the full PR workflow graph, so the bot-materialized head showed `action_required` with zero jobs rather than test failures.

## Materialized runtime verified before this rearm

- Previous materialized head: `5dc7ad31c5bb0334bc4739653e5539ee34fbf12d`.
- `app/public/calls-loop6.js` parses with the corrected success-modal expression.
- Queue runtime marker: `v2.3`.
- Normal queue selector removed.
- Agenda Manual selector retained with COMMERCIAL / CALLBACK / AGENDA_ONLY.
- Queue confirmation uses `aos_callcenter_confirm_queue_appointment_v1`.
- Success modal exposes only `CONTINUAR LLAMADAS`.
- `loadLead()` is not invoked inside the queue commit block; it is invoked only from the post-commit success confirmation.
- Loop 7 remains NOT STARTED.

## Gate

This commit intentionally changes documentation only. Its sole purpose is to trigger the complete CI graph against the already materialized V2.3 runtime. Do not merge PR #342 unless the new exact head is green and production invariants are revalidated.