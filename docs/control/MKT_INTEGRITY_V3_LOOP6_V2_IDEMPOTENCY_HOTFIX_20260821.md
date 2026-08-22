# MKT-INTEGRITY-HOTFIX-V3 — Loop 6 V2 idempotency precheck hotfix — 2026-08-21

## Trigger
Dedicated V2 canary 8 discovered that a retry with the same idempotency key was being re-evaluated against the active-appointment rule before the existing journal result was returned. The first request correctly created one Call + one Agenda + one action journal row, but the second identical request returned `ACTIVE_APPOINTMENT_EXISTS` instead of the original result with `idempotent=true`.

No duplicate data was created, but this violated the retry-after-timeout contract.

## Fix
The existing V2 policy implementation is preserved as `aos_callcenter_commit_action_core_impl_v2`. A narrow `aos_callcenter_commit_action_core_v1` wrapper now:
1. validates actor/key/action/source/phone shape;
2. computes the same request hash used by V2;
3. checks `aos_callcenter_actions_v1` before F6/patient-state/active-appointment/ownership re-evaluation;
4. returns `IDEMPOTENCY_ACTOR_CONFLICT` for actor mismatch;
5. returns `IDEMPOTENCY_CONFLICT` for request-hash mismatch;
6. returns the stored COMPLETE result with `idempotent=true` for an identical retry;
7. delegates only first-seen actions to the unchanged V2 implementation.

F6 remains private; browser grants are unchanged.

## LIVE gate before apply
- action journal = 0;
- policy events = 0;
- canonical core existed;
- implementation alias did not yet exist.

The wrapper migration was then applied to Supabase LIVE. It changes no customer rows, Calls, Agenda, sales, leads or F5/F6 data.

## Canary PASS after fix
Rollback canary used a synthetic new prospect with one identical action invoked twice.

Observed inside the transaction:
- journal_count = 1;
- call_count = 1;
- agenda_count = 1;
- second result `ok=true`;
- second result `idempotent=true`;
- same `callId` and `agendaId` as the first action.

Transaction ended in ROLLBACK.

## Downstream readback after all V2 canaries
- action journal = 0;
- policy events = 0;
- synthetic Calls = 0;
- synthetic Agenda rows = 0;
- repaired Calls intact: 36701, 37185, 37813, 38012, 38168, 38186;
- five repaired direct links intact;
- removed Alberto/Alan duplicate Agenda rows remain absent;
- REV-F5 = 6 batches / 15,498 source rows / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events;
- F6 Identity/Lifecycle remain service-role-only;
- Acquisition = V2 56 / V3 57 / V2-only 0 / sole V3-only 973438607 -> lead 2135;
- August Attribution snapshot after canaries: V2 22 rows / S/6,538; V3 35 rows / S/13,747. Canaries were rollback-only and could not create attribution rows.

## Governance note
PR #337 was merged externally at `main@521c013209702a7c26ddafed23799f9c36236481` while the final canary sequence was still running. The idempotency defect was found after that merge. This hotfix PR exists solely to restore Git↔Supabase parity and must be merged from exact current main with `expected_head_sha` after exact-head CI passes.

Loop 6 remains production-canary / NOT YET CERTIFIED. Loop 7 remains NOT STARTED.
