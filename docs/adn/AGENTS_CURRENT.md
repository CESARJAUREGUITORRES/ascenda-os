# ASCENDA OS — AGENTS CURRENT OVERLAY

**Captured:** 2026-08-17 20:03 America/Lima  
**Applies to:** every AI/Codex/development agent working on CURRENT ASCENDA.

This overlay supersedes operational assumptions in `docs/adn/AGENTS.md`. The historical agent document is retained for provenance and domain knowledge, but it must not override root `AGENTS.md`, `SECURITY.md` or CURRENT project controls.

## Mandatory bootstrap for every agent

Before writing anything:

1. Read root `AGENTS.md` and `SECURITY.md`.
2. Read `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`.
3. Read `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.
4. Verify exact `main` and production runtime chain.
5. Verify live Supabase state for the selected project.
6. Read only the selected project's Control Maestro, active phase and blockers.
7. Classify old PRs/branches before reuse.
8. Refuse to start a second HIGH/CRITICAL workstream while another owns the portfolio lock.

## Current role model

### A-01 Portfolio Controller

Owns scope isolation, workstream lock and handoff.

Must answer before implementation:

- Which project owns this change?
- Which phase owns it?
- Is that project currently allowed to mutate code/data?
- Which other projects share the touched runtime/table/RPC?
- Is the branch based on CURRENT?

If ownership is ambiguous: stop writes and perform read-only reconciliation.

### A-02 Runtime Architect

Authority for deploy topology. Reads `app/railway.json`, `app/package.json` and actual wrapper chain before changing server code.

CURRENT captured chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`.

Never assumes `server.js` is the outer runtime solely because it remains in the repository.

### A-03 Data/Supabase Architect

- owns migration/RPC/RLS/ACL impact analysis;
- does not rewrite production history to satisfy CI;
- serializes DB-heavy work under the portfolio lock;
- preserves F5 provenance and human review;
- keeps #238 parity and #250 baseline distinct.

### A-04 Security Guardian

Applies root `SECURITY.md`. HIGH/CRITICAL requires Zero-Cost evidence, negative auth, rollback and exact-current revalidation. Secrets remain environment/vault only.

### A-05 CI/Runner Governor

- Zero-Cost runner belongs exclusively to the ACTIVE HIGH/CRITICAL workstream during DB gates;
- queued/pending != failure;
- no unrelated materializers compete for the same workspace/ports;
- FAST runners may run isolated syntax/UI/regression only;
- certification evidence must identify the project/phase and exact SHA.

### A-06 Project Historian / Memory Manager

At close/pause:

1. update GitHub CURRENT docs;
2. update `aos_memory` current keys;
3. update exactly one phase state in Notion;
4. mark superseded checkpoints explicitly instead of deleting history;
5. record next input contract.

Never uses `aos_codigo_fuente` as CURRENT production authority.

### A-07 Release Certifier

A phase is 100% only when all declared gates are complete. Distinguishes:

- ZERO-COST CERTIFIED;
- CANARY CERTIFIED;
- PRODUCTION CERTIFIED;
- 100_COMPLETE.

A closed sibling project is input evidence, not automatic closure.

## Current project states

- Sentinel: closed F1–F13, regression-only.
- CIA: F17/F18 remaining; next active after control realignment.
- Revenue: F5–F7 remaining; paused.
- WhatsApp: WA1/WA4/WA5–WA8 remaining; paused and internal phase state must be serialized.
- KronIA: K1–K8 remaining; paused; stale branches are evidence-only.

## Anti-confusion rules

Do not:

- run F5 recovery while certifying F17;
- run K1 Auth/security materialization while F17 runtime is still changing;
- treat Sentinel checks as Sentinel development when they are only regressions;
- treat WhatsApp WA transport completion as CIA F17 readiness or vice versa;
- count `SKIPPED`, `queued` or another project's PASS as the selected phase gate;
- continue from a chat summary without re-reading CURRENT GitHub/Supabase.

## Historical agents

`docs/adn/AGENTS.md` includes useful role concepts from the GAS/Sheets generation, but several operational assumptions are obsolete (GAS primacy, `aos_codigo_fuente` authority, Railway as future-only). Preserve it as history; use this overlay for CURRENT execution.
