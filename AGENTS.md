# AGENTS.md — ASCENDA OS CURRENT

## Purpose

This file defines mandatory operating rules for every AI/Codex/development agent working on ASCENDA OS. Speed never overrides scope isolation, production safety, traceability or exact-current evidence.

## Mandatory bootstrap — read before any write

1. `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`
7. `docs/control/ASCENDA_ZERO_COST_CI_V2_HANDOFF.md`
8. the CURRENT Control Maestro / phase checkpoint of **one selected project only**
9. exact GitHub `main`, branch/PR/checks and live Supabase/Railway evidence

Historical documents may contain useful context, but they do not override CURRENT.

Before continuing work from another chat/agent, revalidate GitHub + Supabase. Never assume an old checkpoint, branch, runtime chain or migration version is still valid.

---

## Global portfolio lock — non-negotiable

ASCENDA contains multiple programs in one repository. One repo does **not** mean one project.

At most **one HIGH/CRITICAL feature/data workstream may be ACTIVE globally**.

The active owner is declared in `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.

While another HIGH/CRITICAL workstream owns the lock:

- other projects are read-only/documentation-only;
- do not launch their migrations, materializers, canaries or deploys;
- do not intentionally start competing DB-heavy Zero-Cost jobs;
- FAST runners may run only isolated regression/syntax/UI checks needed by the active workstream;
- a PASS from another project cannot certify the active project;
- queued/pending from another project is contamination/capacity evidence, not a product failure.

When a paused project resumes, rebase/rebuild from CURRENT when risk or drift warrants it. Historical green CI never makes a stale branch mergeable by itself.

### Portfolio programs

- **Sentinel** — F1–F13 closed; regression-only unless real regression exists.
- **Commercial Intelligence & Audience OS V3** — F17/F18 remaining.
- **Revenue Data & Intelligence** — F5/F6/F7 remaining.
- **WhatsApp Revenue Hub** — WA1, WA4, WA5–WA8 remaining; project state must be serialized.
- **KronIA V2** — K1–K8 remaining; stale K1 branches are evidence-only.
- **#238/#250** — cross-program maintenance, not parallel feature projects.

---

## CURRENT production runtime

Always verify `app/railway.json` and `app/package.json` before changing server topology.

Captured CURRENT Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Captured effective chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core runtime`

Important:

- `app/server.js` remains a lower/core API server; it is **not automatically the outer Railway entrypoint**.
- `app/public/` is the product frontend served by the runtime chain.
- wrappers belong to different workstreams and must not be bypassed accidentally.
- a runtime-chain change is HIGH/CRITICAL and needs exact-chain regression evidence.

---

## Repository classification

- `app/` = CURRENT product application/runtime.
- `app/public/` = CURRENT product frontend.
- `supabase/migrations/` = versioned forward schema history; reconcile against live history, do not rewrite blindly.
- `supabase/pending/` = explicitly not active until its gate is satisfied.
- `src/` = historical/legacy unless proven CURRENT.
- `docs/control/` = technical governance; CURRENT files outrank historical snapshots.
- `docs/MEMORY_CURRENT.md` = current continuity memory.
- `docs/MEMORY.md` = historical April-generation memory.
- `docs/adn/AGENTS_CURRENT.md` = current agent overlay.
- `docs/adn/AGENTS.md` = historical role knowledge, not current runtime authority.
- `aos_codigo_fuente` = historical source archive, **not** canonical production source.
- `aos_memory` = technical memory, subordinate to GitHub/runtime/live DB.

---

## Zero-Cost CI V2

Normal DB/security CI uses repo-level `ASCENDA-ZERO-COST-V2` with labels:

`[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Rules:

- target paid GitHub Actions spend = US$0;
- if runner is offline, jobs queue; do not switch to billable hosted runners as fallback;
- with a single DB runner, jobs serialize;
- reserve the DB runner to the active HIGH/CRITICAL workstream;
- use unique DB/container/project names per run;
- cleanup must run on success **and** failure;
- no production secrets or real PHI/PII as fixtures;
- compile exact release migrations, lint, contracts, security, performance and rollback as applicable;
- CI green does not authorize production.

FAST runners may handle isolated same-workstream syntax/UI/contracts. They never replace Zero-Cost DB/security gates.

---

## Rule zero — analyze before write

For every bug/feature/data change:

1. name the owning project and phase;
2. confirm it owns the portfolio lock;
3. identify exact UI/flow;
4. locate the product runtime file actually loaded;
5. locate endpoint/RPC/table/view;
6. inspect triggers and side effects;
7. identify sibling consumers;
8. classify risk;
9. define tests + rollback;
10. only then modify.

Do not fix symptoms by mutating data or bypassing wrappers without identifying the source of truth.

---

## Branches and PRs

- `main` = GitHub production baseline.
- no normal development directly on `main`;
- no force push on `main`;
- work in `feature/*`, `fix/*`, `security/*`, `data/*`, `chore/*`, `control/*` or project-specific branches;
- HIGH/CRITICAL stale branches must be revalidated against CURRENT before reuse;
- classify old PRs as `MERGE_CANDIDATE`, `PAUSED`, `SUPERSEDED`, or `EVIDENCE_ONLY`;
- close superseded PRs rather than leaving misleading merge candidates open.

A PR cannot be certified using tests from a different HEAD or another project.

---

## Risk

### LOW

Documentation, isolated text/style, read-only investigation.

### MEDIUM

Functional frontend, filters/reporting, read-only queries with known consumers.

### HIGH

Changes involving core sales, patients, agenda, calls, leads, payments, inventory, clinical data, F5 identity resolution, channel delivery, KronIA actions or multi-module runtime behavior.

Requires Impact Report, isolated branch, tests, Zero-Cost when applicable and rollback.

### CRITICAL

Auth/session/2FA, RLS/GRANT/REVOKE, SECURITY DEFINER, secrets, destructive migrations, patient merges, mass writes/deletes, deploy topology, infrastructure, cross-project runtime wrappers, multi-tenant boundaries.

Requires Zero-Cost certificate, negative tests, read-only production preflight, rollback/recovery, canary/additive rollout when possible, final security review and explicit owner authorization before production mutation.

---

## PostgreSQL / Supabase

### DDL and history

- structural changes are versioned migrations;
- do not apply ad-hoc production DDL except explicitly approved incident recovery;
- prefer backward-compatible changes;
- do not rename/drop columns before consumer audit;
- **do not replay production DDL merely to make migration-history checks green**;
- #238 migration parity is owner-scoped;
- #250 reproducible pre-history baseline is a separate foundational problem.

### Data

- before bulk UPDATE/DELETE: run equivalent SELECT and report counts/examples;
- use deterministic filters and idempotency;
- never erase clinical/financial data as cleanup;
- F5 never mutates canonical patients before provenance + preview + human approval;
- production is not a test environment.

### Critical identifiers

Treat `numero_limpio/contact_key` as transversal legacy/current bridge until an explicitly certified canonical identity supersedes it. Any identity change requires cross-domain impact review.

### RPC

Before modifying an RPC:

- read all tables/views it touches;
- identify callers;
- inspect SECURITY DEFINER/search_path;
- inspect effective grants;
- inspect indirect trigger effects;
- version return contracts when breaking compatibility.

---

## Security

Root `SECURITY.md` is authoritative.

Never:

- commit/log/print real passwords, API keys, service-role keys or provider tokens;
- put service credentials in browser code;
- trust browser-supplied role/permission as authority;
- give agents arbitrary write SQL;
- weaken a control merely to make CI green.

Secrets come from environment/vault/secret manager. Removing a leaked secret from HEAD does not replace provider-side rotation/revocation.

---

## KronIA / agents

KronIA is its own K0–K8 program.

- CIA F15 Tool Registry + Agent Registry SHADOW + Policy Gate are reusable canonical inputs.
- Do not create a second incompatible Tool/Agent Registry.
- K1 must be rebuilt from CURRENT when KronIA receives the portfolio lock.
- historical K1 PRs/branches are evidence-only unless revalidated.
- sensitive writes require allowlisted tools, server authority, confirmation where required, audit and rollback.

---

## Project boundaries

### CIA vs WhatsApp

CIA owns provider-neutral Audience/Activation/channel-governance and F17/F18 readiness. WhatsApp owns conversational product, inbox, routing, AI agent, media, booking and conversation/revenue UX.

A Meta canary may produce evidence useful to both, but closing CIA F17 does **not** automatically close WA1/WA4 and vice versa.

### Revenue vs CIA/WhatsApp

Revenue F5 owns historical patient/source identity and canonical enrichment review. It does not run in parallel with channel/runtime releases.

### Sentinel

Sentinel is already closed F1–F13. Its checks are regressions/sensors for other projects, not a reason to reopen Sentinel unless its own contract regresses.

---

## Frontend

- locate the exact panel loaded by the shell;
- preserve shell/session/navigation;
- reuse existing contracts instead of duplicating business logic;
- validate loading/error/empty and responsive states;
- validate roles;
- do not assume Vite/app/src controls production pages without proof.

---

## Minimum tests

### Always

- syntax;
- `git diff --check` / diff hygiene;
- module smoke;
- prove unrelated files were not modified.

### HIGH/CRITICAL

Also:

- dependency/regression tests;
- role/auth positive + negative tests;
- data pre/post evidence where applicable;
- Zero-Cost DB/security gates;
- rollback executed in isolated environment when safe;
- production preflight read-only;
- exact SHA evidence.

### CRITICAL additional

- trust-boundary review;
- explicit bypass/replay/forged-claim negatives;
- canary/additive rollout where possible;
- zero unresolved HIGH/CRITICAL findings in scope;
- explicit owner authorization before first production mutation.

---

## Impact Report for HIGH/CRITICAL

Document at minimum:

```md
## Impact Report
**Project / phase:**
**Objective:**
**Risk:** HIGH / CRITICAL

### Code/runtime
### Data/RPC/triggers
### Consumers/dependencies
### Security/roles/sensitive data
### Tests
### Rollback
### Portfolio-lock impact
```

---

## Certification states

Never conflate:

- `ZERO-COST CERTIFIED`
- `CANARY CERTIFIED`
- `PRODUCTION CERTIFIED`
- `100_COMPLETE`

`100_COMPLETE` means every declared gate of that phase is closed and GitHub/runtime/live DB/aos_memory/Notion are reconciled.

A runtime merge does not equal 100% — CIA F17 is an explicit current example.

---

## Project handoff / pause protocol

Before the portfolio lock moves:

1. capture exact `main` SHA and runtime chain;
2. capture live Supabase phase state;
3. classify all project PRs/branches;
4. record CI/rollback/canary state;
5. update GitHub CURRENT docs;
6. update `aos_memory` current key;
7. update Notion last;
8. state the exact next input contract.

No chat should reconstruct a project from informal memory when these sources exist.

---

## Explicit prohibitions

Do not:

- run multiple HIGH/CRITICAL projects concurrently on shared CI/DB infrastructure;
- experiment in production;
- broad DROP/TRUNCATE/DELETE for convenience;
- force-push production history;
- blind-rewrite migration history;
- copy secrets between environments;
- use real Zi Vital data as generic SaaS seed;
- hide/skip failing tests to get green;
- infer project completion from a sibling project's certificate;
- revive a stale branch without CURRENT revalidation.

---

## Long-term objective

Stabilize ASCENDA Zi Vital as a controlled reference implementation, migrate it to corporate-owned infrastructure, and build the future multi-tenant SaaS separately. The current production database is not to be converted into multi-tenant SaaS by a big-bang mutation.
