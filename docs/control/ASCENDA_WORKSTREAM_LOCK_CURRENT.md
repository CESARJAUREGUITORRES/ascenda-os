# ASCENDA OS — WORKSTREAM LOCK CURRENT

**State:** ACTIVE  
**Captured baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Current lock:** `CONTROL_REALIGNMENT`  
**Next lock after merge/reconciliation:** `CIA_F17_F18_CLOSEOUT`

## Why this lock exists

ASCENDA has multiple programs in one repository and a shared Supabase/Railway/CI footprint. Running unrelated HIGH/CRITICAL workstreams simultaneously created queue contention, stale branches, shared-runner collisions and ambiguous certification evidence.

The lock makes scheduling an explicit technical control.

## Global rule

At most **one HIGH/CRITICAL feature/data workstream** may be ACTIVE across ASCENDA.

All other programs are `PAUSED_BY_PORTFOLIO_LOCK` unless they are:

- read-only investigation;
- documentation/control work;
- regression-only checks explicitly required by the active workstream;
- emergency incident response authorized by the owner.

## Runner routing

### Zero-Cost DB runner

`ASCENDA-ZERO-COST-V2` / `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Reserved exclusively for the ACTIVE workstream while it is running DB/migration/security gates.

Rules:

1. Do not intentionally launch a second DB-heavy project on the same runner.
2. Use unique DB/container/project names per run.
3. Always clean workspace/container/Supabase residue in `if: always()` or equivalent.
4. `queued`/`pending` means capacity wait, not product failure.
5. A run from a non-active project cannot certify the active project.

### FAST runners

FAST runners may execute same-workstream syntax/UI/contracts or regression checks that are isolated from shared mutable state. They must not be used to bypass the Zero-Cost DB/security gate.

## Branch rule

When a paused project resumes:

1. re-read `main`;
2. re-read its live Supabase state;
3. classify old branches/PRs as `MERGE_CANDIDATE`, `EVIDENCE_ONLY`, `SUPERSEDED`, or `PAUSED`;
4. prefer a fresh branch from CURRENT for HIGH/CRITICAL work when the old branch predates runtime/schema changes;
5. never merge a stale branch simply because its historical CI was green.

## Lock transition gate

The lock moves to the next project only after:

- current project Definition of Done is satisfied or an explicit safe pause checkpoint is recorded;
- no untracked production mutation remains;
- exact-current regression is green or explicitly documented;
- active project PRs are classified;
- GitHub control + `aos_memory` + Notion are reconciled.

## Portfolio queue

1. `CONTROL_REALIGNMENT` — ACTIVE now.
2. `CIA_F17_F18_CLOSEOUT` — next.
3. `REVENUE_F5_F7_CLOSEOUT`.
4. `WHATSAPP_WA1_WA8_CLOSEOUT`.
5. `BASELINE_REPRODUCIBILITY_250`.
6. `KRONIA_K1_K8_CLOSEOUT`.
7. `FINAL_ASCENDA_CROSS_PROGRAM_CERTIFICATION`.

Sentinel F1–F13 is frozen/regression-only and is not part of this queue unless a real regression reopens it.

## Current pause declarations

Until `CONTROL_REALIGNMENT` closes:

- CIA F17: no additional migration/canary work; live state remains 4/6 fail-closed.
- Revenue F5: no additional ingest/rebuild/apply; canonical mutation remains 0.
- WhatsApp: no AI activation, Meta canary or WA5+ work.
- KronIA: no K1 production/cutover work and no stale K1 merge.
- Sentinel: regression-only.

After control realignment, only CIA F17/F18 is released from pause.
