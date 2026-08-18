# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / cross-program control  
**Baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Captured:** 2026-08-17 20:03 America/Lima  
**ACTIVE LOCK:** `CONTROL-REALIGNMENT`  
**NEXT LOCK AFTER CONTROL MERGE:** `CIA-F17/F18-CLOSEOUT`

## Purpose

ASCENDA shares GitHub, Railway, Supabase and self-hosted CI across multiple programs. Shared infrastructure does **not** make them one project. This lock prevents phases, migrations, PRs, runners and certifications from different programs being mixed accidentally.

## Canonical namespaces

Every task/checkpoint declares a `WORKSTREAM_ID`:

- `CIA-F*` — Commercial Intelligence & Audience OS V3.
- `REV-F*` — Revenue Data & Intelligence.
- `WA-*` — WhatsApp Revenue Hub.
- `SEN-F*` — Sentinel.
- `K*` / `K1-*` — KronIA.
- `PARITY-*` — Git ↔ Supabase history parity (#238).
- `BASELINE-*` — reproducible pre-history baseline (#250).
- `CONTROL-*` — portfolio/governance alignment.

Bare `F17` is prohibited in cross-program control because several roadmaps use the same phase numbers.

## Global exclusivity

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

While a workstream owns the lock:

1. other programs are read-only/documentation-only;
2. no competing migrations/materializers/canaries/deploys are intentionally started;
3. FAST runners may execute isolated regression/syntax/UI checks required by the owner;
4. the Zero-Cost DB runner is reserved to the owner for DB/migration/security gates;
5. a PASS from another project cannot certify the owner;
6. queued/pending means capacity wait, not product failure;
7. any unrelated merge that advances `main` invalidates a pending exact-head certificate until revalidated.

## CURRENT runtime

PR #265 / S15.2 is merged.

Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Effective chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core runtime`

`app/server.js` is not the outer Railway entrypoint.

## Current portfolio state

### CONTROL-REALIGNMENT — ACTIVE

Allowed now:

- read-only GitHub/Supabase/runtime audit;
- documentation and tracker reconciliation;
- stale PR classification;
- `aos_memory` control keys;
- no feature/data production mutation.

Exit gate:

- canonical portfolio map + agents/memory + Notion reconciled;
- stale/overlapping PRs classified;
- root AGENTS points to CURRENT runtime/lock;
- next input contract for CIA-F17 recorded.

### CIA-F17/F18 — NEXT

Live F17 at control capture:

- `contracts_active=true`
- `whatsapp_bridge_validated=true`
- `outbound_policy_validated=true`
- `rollback_verified=true`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `ready_for_f18=false`

S15.2 fixed the production-chain bypass. Runtime activation does not equal F17 100%.

PR #261 was built before #265 and is **not mergeable as-is**; remaining F17 work starts/reconciles from CURRENT.

### Other programs while CONTROL/CIA owns lock

- `REV-F5`: paused; no ingest/rebuild/apply.
- `WA-*`: paused; no Meta canary, AI activation or WA5+ implementation.
- `K*`: paused; no K1 materialization/cutover and no stale K1 merge.
- `SEN-F1..F13`: closed/regression-only. Maintenance findings are queued unless they represent an actual production-safety incident.
- `PARITY-*` / `BASELINE-*`: read-only analysis allowed; no independent history rewrite or DDL replay.

## Runner routing

### Zero-Cost DB runner

`ASCENDA-ZERO-COST-V2` / `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Rules:

- reserved to active workstream for DB/security/release gates;
- unique DB/container/project names per run;
- cleanup on success/failure;
- no production PII/PHI/secrets in fixtures;
- no GitHub-hosted billable fallback merely because it is queued/offline.

### FAST runners

May run isolated same-workstream syntax/UI/runtime contracts or explicitly required regressions. They do not replace the Zero-Cost DB/security gate.

## Branch/PR resume rule

When a paused project resumes:

1. re-read exact `main`;
2. re-read live Supabase state;
3. classify branches/PRs: `MERGE_CANDIDATE`, `PAUSED`, `SUPERSEDED`, `EVIDENCE_ONLY`;
4. for HIGH/CRITICAL drift, prefer fresh branch from CURRENT;
5. never merge because historical CI was green.

## Lock transition gate

The active lock changes only after:

1. exact `main` SHA/runtime captured;
2. project live readiness/state captured;
3. active PRs classified;
4. CI/canary/rollback state recorded;
5. no untracked production mutation remains;
6. GitHub CURRENT docs updated;
7. `aos_memory` current key updated;
8. Notion updated last;
9. next project input contract written.

If unfinished but safe to pause, state is `PAUSED_WITH_CHECKPOINT`, never “finished”.

## Sequential portfolio queue

1. `CONTROL-REALIGNMENT` — ACTIVE.
2. `CIA-F17/F18-CLOSEOUT`.
3. `REV-F5/F7-CLOSEOUT`.
4. `WA-1/WA-8-CLOSEOUT`.
5. `BASELINE-#250` after feature schemas stabilize.
6. `K1/K8-CLOSEOUT`.
7. `FINAL-CROSS-PROGRAM-CERTIFICATION`.

Sentinel remains frozen/regression-only unless a demonstrated Sentinel regression requires a maintenance lock.

## Recovery protocol for any new chat/agent

Before touching ASCENDA:

1. read root `AGENTS.md`;
2. read `SECURITY.md`;
3. read `ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. read this lock;
5. declare `WORKSTREAM_ID`;
6. read only that project's CURRENT control/phase;
7. verify GitHub main/PR/checks and Supabase live;
8. confirm no other mutable lock is active;
9. execute only the next declared gate.

GitHub/runtime/Supabase live override stale memory/Notion. Notion is corrected last.