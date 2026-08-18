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

## Global portfolio lock — non-negotiable

ASCENDA contains multiple programs in one repository. One repo does **not** mean one project.

At most **one HIGH/CRITICAL feature/data workstream may be ACTIVE globally**. The active owner is declared in `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`.

While another HIGH/CRITICAL workstream owns the lock:

- other projects are read-only/documentation-only;
- do not launch their migrations, materializers, canaries or deploys;
- do not intentionally start competing DB-heavy Zero-Cost jobs;
- FAST runners may run only isolated regression/syntax/UI checks needed by the active workstream;
- a PASS from another project cannot certify the active project;
- queued/pending from another project is capacity evidence, not product failure.

When a paused project resumes, rebase/rebuild from CURRENT when risk or drift warrants it. Historical green CI never makes a stale branch mergeable by itself.

### Canonical namespaces

- `CIA-F*` — Commercial Intelligence & Audience OS V3.
- `REV-F*` — Revenue Data & Intelligence.
- `WA-*` — WhatsApp Revenue Hub.
- `SEN-F*` — Sentinel.
- `K1-*` / `K*` — KronIA.
- `PARITY-*` / `BASELINE-*` — cross-program migration control.

Do not use a bare `F17` in cross-program control because several programs have numbered phases.

## CURRENT production runtime

Always verify `app/railway.json` and `app/package.json` before changing server topology.

Captured Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Captured effective chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core runtime`

Important:

- `app/server.js` remains a lower/core API server; it is **not automatically the outer Railway entrypoint**.
- `app/public/` is the product frontend served through the runtime chain.
- wrappers belong to different workstreams and must not be bypassed accidentally.
- runtime-chain change = HIGH/CRITICAL and requires exact-chain regression evidence.

## Repository classification

- `app/` = CURRENT product application/runtime.
- `app/public/` = CURRENT product frontend.
- `supabase/migrations/` = versioned forward schema history; reconcile against live history, do not rewrite blindly.
- `supabase/pending/` = explicitly inactive until its gate is met.
- `src/` = historical/legacy unless proven CURRENT.
- `docs/control/` = governance; CURRENT files outrank historical snapshots.
- `docs/MEMORY_CURRENT.md` = current continuity memory.
- `docs/MEMORY.md` = historical April-generation memory.
- `docs/adn/AGENTS_CURRENT.md` = current agent overlay.
- `docs/adn/AGENTS.md` = historical role knowledge, not runtime authority.
- `aos_codigo_fuente` = historical archive, not canonical production source.
- `aos_memory` = technical memory subordinate to GitHub/runtime/live DB.

Never modify `src/` assuming it changes production without proving its CURRENT consumer path.

## Zero-Cost CI V2

Normal DB/security CI uses repo-level `ASCENDA-ZERO-COST-V2` with labels `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`.

- target paid GitHub Actions spend = US$0;
- runner offline → jobs queue; no billable hosted fallback;
- single DB runner means jobs serialize;
- reserve DB runner to the active HIGH/CRITICAL workstream;
- use unique DB/container/project names per run;
- cleanup on success and failure;
- no production secrets or real PHI/PII fixtures;
- compile exact release migrations, lint, contracts, security, performance and rollback as applicable;
- CI green does not authorize production.

FAST runners may handle isolated same-workstream syntax/UI/contracts. They never replace Zero-Cost DB/security gates.

## Rule zero — analyze before write

For every bug/feature/data change:

1. name owning project + phase;
2. confirm it owns the portfolio lock;
3. identify exact UI/flow;
4. locate the runtime file actually loaded;
5. locate endpoint/RPC/table/view;
6. inspect triggers/side effects;
7. identify sibling consumers;
8. classify risk;
9. define tests + rollback;
10. only then modify.

Do not fix symptoms by mutating data or bypassing wrappers without identifying the source of truth.

## Branches and PRs

- `main` = GitHub production baseline.
- no normal development directly on `main`;
- no force push on `main`;
- work in scoped branches;
- HIGH/CRITICAL stale branches must be revalidated against CURRENT before reuse;
- classify old PRs as `MERGE_CANDIDATE`, `PAUSED`, `SUPERSEDED`, or `EVIDENCE_ONLY`;
- close superseded PRs instead of leaving misleading candidates open;
- a PR cannot be certified using tests from a different HEAD/project.

## Risk

### LOW
Documentation, isolated text/style, read-only investigation.

### MEDIUM
Functional frontend, filters/reporting, read-only queries with known consumers.

### HIGH
Core sales, patients, agenda, calls, leads, payments, inventory, clinical data, F5 identity resolution, channel delivery, KronIA actions or multi-module runtime behavior.

Requires Impact Report, isolated branch, tests, Zero-Cost when applicable and rollback.

### CRITICAL
Auth/session/2FA, RLS/GRANT/REVOKE, SECURITY DEFINER, secrets, destructive migrations, patient merges, mass writes/deletes, deploy topology, infrastructure, cross-project wrappers, multi-tenant boundaries.

Requires Zero-Cost certificate, negative tests, read-only production preflight, rollback/recovery, canary/additive rollout when possible, final security review and explicit owner authorization before production mutation.

## PostgreSQL / Supabase

### DDL/history

- structural changes are versioned migrations;
- no ad-hoc production DDL except explicitly approved incident recovery;
- prefer backward-compatible changes;
- do not rename/drop columns before consumer audit;
- do not replay production DDL merely to make migration-history checks green;
- #238 parity is owner-scoped;
- #250 reproducible pre-history baseline is separate.

### Data

- before bulk UPDATE/DELETE run equivalent SELECT and report count/examples;
- deterministic filters and idempotency;
- never erase clinical/financial data as cleanup;
- REV-F5 never mutates canonical patients before provenance + preview + human approval;
- production is not a test environment.

### Identifiers

Treat `numero_limpio/contact_key` as a transversal bridge until an explicitly certified canonical identity supersedes it. Identity changes require cross-domain impact review.

### RPC

Before modifying an RPC: identify reads/writes, callers, SECURITY DEFINER/search_path, effective grants and indirect trigger effects. Version breaking return contracts.

## Security

Root `SECURITY.md` is authoritative.

Never commit/log/print real passwords, API keys, service-role keys or provider tokens. Never put service credentials in browser code. Never trust browser-supplied role/permission as authority. Never grant agents arbitrary production write SQL. Never weaken a control just to make CI green.

Secrets come from environment/vault/secret manager. Removing an exposed secret from HEAD does not replace provider-side rotation/revocation.

## Project boundaries

### CIA vs WhatsApp
CIA owns provider-neutral Audience/Activation/channel governance and F17/F18 readiness. WhatsApp owns conversation product, inbox, routing, AI agent, media, booking and conversation/revenue UX.

A Meta canary may provide evidence to both, but closing CIA-F17 does not close WA1/WA4 and vice versa.

### Revenue
Revenue F5 owns historical patient/source identity and canonical enrichment review. Do not run it concurrently with channel/runtime releases.

### Sentinel
Sentinel SEN-F1..F13 is closed. Run regressions as sensors for other projects; reopen Sentinel only on a demonstrated Sentinel regression.

### KronIA
KronIA is K0–K8. CIA-F15 Tool Registry + Agent Registry SHADOW + Policy Gate are canonical reusable inputs. Do not build a second incompatible registry. Fresh K1 starts from CURRENT when it receives the portfolio lock; historical K1 PRs are evidence-only.

## Frontend

Locate the exact panel loaded by the shell, preserve session/navigation, reuse existing contracts, validate loading/error/empty/responsive/roles, and do not assume Vite/app/src controls production without proof.

## Minimum tests

### Always
- syntax;
- diff hygiene;
- module smoke;
- prove unrelated files were not modified.

### HIGH/CRITICAL
Also dependency/regression tests, role/auth positive + negative tests, data pre/post evidence where applicable, Zero-Cost DB/security gates, rollback in isolated env when safe, production preflight read-only and exact SHA evidence.

### CRITICAL additional
Trust-boundary review, bypass/replay/forged-claim negatives, canary/additive rollout where possible, zero unresolved HIGH/CRITICAL in scope and explicit owner authorization before first production mutation.

## Impact Report for HIGH/CRITICAL

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

## Certification states

Never conflate `ZERO-COST CERTIFIED`, `CANARY CERTIFIED`, `PRODUCTION CERTIFIED`, and `100_COMPLETE`.

`100_COMPLETE` requires every declared gate closed and GitHub/runtime/live DB/aos_memory/Notion reconciled. Runtime activation alone is not completion — CIA-F17 is the current example.

## Handoff / pause protocol

Before moving the portfolio lock:

1. exact `main` SHA/runtime;
2. live Supabase phase state;
3. project PR/branch classification;
4. CI/rollback/canary state;
5. GitHub CURRENT docs;
6. `aos_memory` current key;
7. Notion last;
8. explicit next input contract.

No chat should reconstruct a project from informal memory when these sources exist.

## Prohibitions

Do not run multiple HIGH/CRITICAL projects concurrently on shared CI/DB infrastructure; experiment in production; broad DROP/TRUNCATE/DELETE for convenience; force-push production history; blind-rewrite migration history; copy secrets between environments; use real Zi Vital data as generic SaaS seed; hide failing tests; infer project closure from sibling certificates; or revive stale branches without CURRENT revalidation.

## Long-term objective

Stabilize ASCENDA Zi Vital as a controlled reference implementation, migrate it to corporate-owned infrastructure, and build the future multi-tenant SaaS separately. Do not convert the current production DB into multi-tenant SaaS by big-bang mutation.
