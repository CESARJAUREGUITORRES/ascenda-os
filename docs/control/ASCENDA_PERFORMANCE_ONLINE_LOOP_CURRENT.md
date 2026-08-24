# ASCENDA OS — ASC-PERF ONLINE EXECUTION LOOP CURRENT

**Status:** CURRENT / ACTIVE EXECUTION LOOP  
**Captured:** 2026-08-24 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Branch:** `perf/asc-perf-stabilization-20260822`  
**PR:** `#353` DRAFT  
**Namespace:** `ASC-PERF-*`

## 1. Purpose

Advance the ASC-PERF Audit 360 as far as possible using only online connected evidence from GitHub and production read-only Supabase access, and stop only when the next unresolved gate requires execution on self-hosted runners or a controlled browser/fixture environment.

This loop is investigation/documentation only. It does not authorize production mutation, database DDL/DML, Railway changes, merge, deploy or feature expansion.

## 2. Canonical online loop

`ONLINE-L0 Rebaseline → ONLINE-L1 Background Runtime Census → ONLINE-L2 Static Runtime Surface → ONLINE-L3 DB/RPC Correlation → ONLINE-L4 Payload/Egress Attribution → ONLINE-L5 Lifecycle/Legacy Static → ONLINE-L6 UNKNOWN Reconciliation → ONLINE-L7 Evidence Freeze → RUNNER-GATE-R1`

### ONLINE-L0 — Exact Rebaseline

Required every significant audit session:

- verify exact `main` SHA;
- verify ASC-PERF PR/branch exact head;
- verify Supabase project health;
- capture `pg_stat_statements_info.stats_reset` and current timestamp;
- capture current high-call/high-time statements;
- inspect a fresh API-log window for recurrent idle/background traffic.

**Exit:** Git/runtime evidence is temporally matched enough for the next analysis.

### ONLINE-L1 — Background Runtime Census

Prioritize producers that continue without a user actively navigating a panel:

- notification pumps;
- agent cron/schedulers;
- Studio/content schedulers;
- snapshots/cache reloaders;
- email/marketing background jobs;
- integration health/reconcile loops;
- any recurrent failed request.

For every producer record source owner, cadence, auth mode, query/RPC, fan-out, writes, failure behavior and whether work was actually present.

**Exit:** every material background producer is `CONFIRMED`, `CANDIDATE` or `UNKNOWN`; source/live mismatches remain explicit UNKNOWN.

### ONLINE-L2 — Static Runtime Surface

Map CURRENT runtime source without executing a browser:

- server entry chain;
- `app/public` panel scripts actually referenced by shell/routes;
- `setInterval` and recursive `setTimeout`;
- MutationObservers;
- WebSocket / EventSource / Realtime;
- focus/visibility/online handlers;
- fetch/RPC/REST wrappers;
- global `window.fetch` patches;
- Service Workers;
- retry/backoff logic.

Do not classify local UI/audio clocks as network defects merely because cadence is short.

**Exit:** static recurrent producer inventory is materially complete for CURRENT source.

### ONLINE-L3 — DB/RPC Correlation

For each confirmed/candidate producer connect:

`source trigger → HTTP endpoint/request → RPC/table → pg_stat_statements shape → rows/time/writes`

Quantify request amplification and N+1/fan-out where source and live evidence allow it.

**Exit:** highest-cost recurrent paths have a traceable causal chain or remain explicit UNKNOWN.

### ONLINE-L4 — Payload / Egress Attribution

Measure or bound:

- response bytes per recurrent read;
- selected columns and row limits;
- calls/hour or calls/minute;
- expected monthly bytes at current cadence;
- whether bytes are user-driven or permanent background traffic.

Do not attribute total Supabase egress to one subsystem without matched byte evidence.

**Exit:** material egress contributors are ranked with evidence/confidence.

### ONLINE-L5 — Lifecycle / Legacy Static

Determine from source and routing evidence:

- whether panel timers are torn down;
- whether observers/listeners/WebSockets survive navigation;
- whether legacy pages remain reachable/current;
- whether canonical and legacy owners can run simultaneously;
- whether global shims/monkey patches layer across panels.

Dynamic proof that requires navigation remains deferred to Runner Gate R1.

### ONLINE-L6 — UNKNOWN Reconciliation

For every material UNKNOWN, attempt to reconcile using:

- fresh API/postgres/realtime logs;
- exact CURRENT source;
- Git history when drift is suspected;
- runtime/environment configuration evidence available online;
- statement fingerprint/cadence matching.

`UNKNOWN > 0` may persist only when the missing proof genuinely requires controlled execution or infrastructure evidence unavailable online.

### ONLINE-L7 — Evidence Freeze

Update:

- `ASCENDA_PERFORMANCE_AUDIT_360_FINDINGS_CURRENT.md`;
- Audit 360 status/current priorities;
- current source SHA and measurement timestamp;
- explicit list of unresolved runner-required assertions;
- candidate remediation order without applying remediation.

**Exit:** no further material evidence can be obtained online without repeating already-completed reads.

## 3. RUNNER-GATE-R1 — Stop point

Turn on the required self-hosted runner only when at least one of these is the next blocking proof:

1. execute `tools/perf-audit/runtime-census.mjs` against exact-head source;
2. run `ASCENDA ASC-PERF Audit 360` CI contracts;
3. execute Playwright/browser network traces per panel;
4. verify hidden-tab/navigation teardown and lifecycle leaks dynamically;
5. execute Zero-Cost fixture/load tests such as k6 or controlled concurrency;
6. validate any future remediation patch before merge/canary.

At this gate the assistant must state exactly which runner label is needed and why. Until then, runners may remain off.

## 4. Classification contract

- source + live evidence agree → `CONFIRMED`;
- source-only plausible behavior → `CANDIDATE`;
- live behavior without reconciled CURRENT owner/cadence → `UNKNOWN`;
- recurrent behavior proven intentional and within frozen budget → `JUSTIFIED`;
- previous diagnosis replaced by better evidence → `SUPERSEDED`.

No source-only candidate may be described as current production load without live corroboration.

## 5. Current recalculated priority — 2026-08-24

Current idle/background evidence changes the investigation order:

1. notification push claim pump — permanent ~4-second cadence;
2. Studio recurrent 401 — live ~60-second cadence with CURRENT-source mismatch;
3. agent scheduler — permanent ~60-second broad read plus due-agent execution fan-out;
4. other server cache/snapshot/background producers;
5. active-panel/UI amplification (WhatsApp, Product Resolution, Admin, Calls, Coordination);
6. residual DB/RPC structural optimization after call reduction.

This priority is investigative, not authorization to patch.

## 6. Safety boundary

During this Online Loop:

- production reads/log inspection are allowed;
- branch documentation/tooling updates are allowed under owner authorization;
- production DML/DDL is prohibited;
- `main` merge is prohibited;
- Railway/Supabase runtime configuration changes are prohibited;
- feature work stays frozen;
- structural DB advisor findings are backlog inputs for PERF-7, not automatic migrations.
