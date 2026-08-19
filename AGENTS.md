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
10. for Revenue F5 / identity / historical data work, `docs/control/REV_F5_LEARNING_INTERCONNECTION_CURRENT_20260819.md`
11. for F5→F6 identity/Patient 360 work, `docs/control/REV_F5_F6_IMPLEMENTATION_ROADMAP_CURRENT_20260819.md`, `docs/control/REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md`, `docs/control/REV_PATIENT_COMMERCIAL_360_V2_CONTRACT.md` and `docs/control/REV_CUSTOMER_LIFECYCLE_IDENTITY_CONFIDENCE_CONTRACT.md`.

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

## Persistence Triple-Proof — mandatory for HIGH/CRITICAL data work

A data mutation is not certified because an agent/tool/RPC/local loop reports `success`.

Before closing any data checkpoint require:

1. **Execution receipt** — the intended RPC/job/transaction reports the expected action.
2. **Direct live readback** — the authoritative production tables show the expected persisted delta.
3. **Independent invariant query** — a separate query proves count/range/uniqueness/orphans/conflicts/protected-table invariants.

For source/batch ingestion also require a full idempotent replay of the exact SHA-bound source at batch closure, with zero new inserts/conflicts.

Timeout, blocked transport, truncated response, local completion or generated payload never proves persistence. Always reconcile live state before retrying or advancing.

Canonical recovery loop:

`OBSERVE LIVE → IDENTIFY EXACT GAP → MUTATE ONLY GAP → READ BACK → VERIFY → CHECKPOINT → CONTINUE`.

Never use:

`ERROR/AMBIGUITY → ASSUME → SKIP → CERTIFY`.

False or stale certification claims must be explicitly superseded in CURRENT documentation; do not silently preserve them.

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
- production is not a test environment;
- every HIGH/CRITICAL data gate follows Persistence Triple-Proof.

### Patient identity / duplicate resolution

- `canonical_patient_id` is the durable identity target once REV-F5 certifies it;
- `numero_limpio/contact_key` remains an import/search/compatibility bridge, never sole merge authority;
- preserve old/current phones, emails and source-scoped IDs as governed aliases when identity is proven;
- same name alone never merges patients;
- same phone alone never merges patients;
- approximate/numeric-near phone values are **not** identity evidence; heuristics such as phone `±3` are prohibited;
- exact normalized name+surname+phone+valid document with zero strong conflicts may be `AUTO_ELIGIBLE_EXACT`, but physical consolidation still requires governed admin+2FA, dry-run, canary, audit and rollback;
- strong evidence with changed phone/name formatting routes to `REVIEW_STRONG` unless already verified;
- conflicting valid documents/DOB/sex or an identifier mapped to another canonical patient routes to `BLOCK_CONFLICT`;
- absorbed profiles/identifiers remain provenance/aliases; do not erase history;
- the legacy `aos_fusionar_pacientes` and `aos_duplicados_paciente` must not become F5 batch authority without dependency/security/versioning audit.

F5 governed identity/provenance is the canonical patient resolution layer. CIA, WA, F6, Patient 360 and historical-sales imports must not create competing customer identity truth.

### RPC

Before modifying an RPC: identify reads/writes, callers, SECURITY DEFINER/search_path, effective grants and indirect trigger effects. Version breaking return contracts.

## Security

Root `SECURITY.md` is authoritative.

Never commit/log/print real passwords, API keys, service-role keys or provider tokens. Never store real credentials in skills, examples, README files, prompts or agent memory. Never put service credentials in browser code. Never trust browser-supplied role/permission as authority. Never grant agents arbitrary production write SQL. Never weaken a control just to make CI green.

Secrets come from environment/vault/secret manager. Removing an exposed secret from HEAD does not replace provider-side rotation/revocation.

## Project boundaries

### CIA vs WhatsApp
CIA owns provider-neutral Audience/Activation/channel governance and F17/F18 readiness. WhatsApp owns conversation product, inbox, routing, AI agent, media, booking and conversation/revenue UX.

A Meta canary may provide evidence to both, but closing CIA-F17 does not close WA1/WA4 and vice versa.

### Revenue
Revenue F5 owns historical patient/source identity, duplicate resolution and canonical enrichment review. Do not run it concurrently with channel/runtime releases.

Canonical Revenue responsibility:

- REV-F3 = product/service identity for sales;
- REV-F4 = payment/revenue/cartera/reconciliation truth;
- REV-F5 = historical patient identity + provenance + duplicate resolution + governed canonical enrichment;
- REV-F6 = Patient Commercial 360/read-model intelligence derived from certified F3/F4/F5 facts.

Historical 2024–2025 transaction imports must reuse those domains rather than create a new product/customer/revenue model. See `docs/control/REV_HISTORICAL_SALES_2024_2025_INGEST_CONTRACT.md`.

The existing Patient 360 (`app/public/patients.html` / `aos_paciente_360`) must be evolved, not duplicated. V2 resolves lookup identifiers through canonical identity/aliases before aggregating history.

### Sentinel
Sentinel SEN-F1..F13 is closed. Run regressions as sensors for other projects; reopen Sentinel only on a demonstrated Sentinel regression or explicit maintenance handoff. Data-integrity signals use `docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`: aggregate/zero-PII observation only; Sentinel never silently repairs business data.

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

`100_COMPLETE` requires every declared gate closed and GitHub/runtime/live DB/aos_memory/Notion reconciled. Runtime activation alone is not completion.

For data phases, `PRODUCTION CERTIFIED` additionally requires persisted post-conditions proven through Persistence Triple-Proof and any declared full-source replay/coverage gates.

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

Do not run multiple HIGH/CRITICAL projects concurrently on shared CI/DB infrastructure; experiment in production; broad DROP/TRUNCATE/DELETE for convenience; force-push production history; blind-rewrite migration history; copy secrets between environments; use real Zi Vital data as generic SaaS seed; hide failing tests; infer project closure from sibling certificates; infer data persistence from tool output alone; certify a phase whose live post-conditions are not present; merge patient identities from name/phone/approximate-phone alone; or revive stale branches without CURRENT revalidation.

## Long-term objective

Stabilize ASCENDA Zi Vital as a controlled reference implementation, migrate it to corporate-owned infrastructure, and build the future multi-tenant SaaS separately. Do not convert the current production DB into multi-tenant SaaS by big-bang mutation.