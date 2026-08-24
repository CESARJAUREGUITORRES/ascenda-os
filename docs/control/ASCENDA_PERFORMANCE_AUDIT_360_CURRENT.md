# ASCENDA OS — ASC-PERF AUDIT 360 CURRENT

**Status:** CURRENT / ACTIVE / READ-ONLY DISCOVERY FIRST  
**Captured:** 2026-08-22 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Branch:** `perf/asc-perf-stabilization-20260822`  
**Parent workstream:** `ASC-PERF — Performance Stabilization & Read Architecture`  
**Current gates:** `ASC-PERF-0` + `ASC-PERF-1A`  

## 1. Purpose

This document expands `ASC-PERF-1 — Runtime Call Map 360` into an exhaustive, machine-assisted audit before remediation begins.

The current findings are confirmed defects/hotspots, but they are not treated as a complete inventory until `ASC-PERF-1G` closes with zero unidentified recurrent network/database producers in CURRENT runtime scope.

ASC-PERF Audit 360 reuses Sentinel as the canonical observability foundation. It does **not** create a competing telemetry/incident platform.

Sentinel remains responsible for vendor-neutral telemetry, release/request correlation, privacy boundaries, incidents and operational health. ASC-PERF adds a specialized performance-analysis layer focused on recurrent call ownership, request amplification, payload/egress cost, lifecycle leaks and regression prevention.

## 2. Canonical architecture

```text
CURRENT runtime source
        |
        +--> Static Census --------------------+
        |                                      |
        +--> Browser/fixture Network Trace ----+--> ASC-PERF evidence model
        |                                      |       |
        +--> Server/RPC fan-out map -----------+       +--> Runtime Call Map
        |                                      |       +--> Read Ownership Registry
        +--> pg_stat_statements / logs --------+       +--> Performance Budgets
        |                                      |       +--> Anti-pattern Registry
        +--> response-byte attribution --------+       +--> CI Performance Guard
                                                       |
Sentinel / OTel contracts <-----------------------------+
        |
        +--> release / component / operation / request correlation
        +--> zero-PII/PHI telemetry boundary
        +--> HEALTHY / DEGRADED / INCIDENT / UNKNOWN discipline
```

## 3. ASC-PERF-1 subgates

### PERF-1A — Static Runtime Census

Scan the full CURRENT production source surface, primarily `app/` and `app/public/`, for recurrent/network-affecting constructs.

Required pattern families:

- `setInterval`;
- recursive/recurrent `setTimeout`;
- `fetch` / REST / RPC wrappers;
- `XMLHttpRequest`;
- `WebSocket`;
- `EventSource` / SSE;
- `navigator.sendBeacon`;
- Service Worker registration/message/network behavior;
- `MutationObserver` with possible network side effects;
- `visibilitychange`, `focus`, `online`, `offline`, `pagehide` handlers;
- poll/refresh/heartbeat/retry/backoff/pump/cron/worker loops;
- `Promise.all(...map(...network/RPC...))` fan-out candidates;
- recurrent `select=*` / broad field lists;
- recurrent large row limits;
- monkey patches of `window.fetch` or other global network primitives.

Each finding must include file, line, construct and contextual snippet. Static detection is evidence discovery, not automatic defect classification.

**Exit:** machine census generated over the complete CURRENT runtime surface and manually triaged into recurrent producer candidates vs non-network/UI-only constructs.

### PERF-1B — Runtime Surface Map

Prove which source files actually participate in production/runtime paths.

For every major panel/capability map:

`UI/panel -> HTML/JS -> server endpoint/wrapper -> RPC/view/table -> side effects`

Required domains include at minimum:

- App shell/auth;
- Admin Home;
- Calls / Call Center;
- Caja;
- Sales / Product Resolution;
- WhatsApp;
- Agents/KronIA surfaces;
- Coordination/chat;
- Patients/Patient 360;
- Agenda;
- Marketing/CIA surfaces;
- Inventory/clinical surfaces that contain recurrent network behavior.

`src/` and historical code are not counted as CURRENT unless a live consumer path is proven.

**Exit:** every recurrent candidate has CURRENT / LEGACY / INACTIVE / UNKNOWN runtime classification.

### PERF-1C — Dynamic Browser Trace

Use an automated browser fixture, preferably Playwright in Zero-Cost CI, to observe real network behavior rather than infer it only from source.

For each governed panel measure:

- request URL/template and method;
- call count during mount;
- call rate during active idle;
- call rate while hidden;
- call rate after navigating away;
- response status and duration;
- transferred/response bytes where measurable;
- duplicate simultaneous/in-flight requests;
- network activity after panel unmount.

Recommended trace windows: startup, 1 minute active, hidden, navigation-away, and an extended 5–10 minute sample for recurrent behavior.

**Exit:** observed runtime traffic reconciled against PERF-1A/1B; any source-only or runtime-only discrepancy becomes an explicit gap.

### PERF-1D — DB/RPC Correlation

For every relevant browser/server request map downstream amplification:

`browser action/request -> Node endpoint -> auth/session validation -> RPC/REST queries -> PostgreSQL statement(s)`

Record:

- request amplification factor;
- N+1 behavior;
- repeated actor/session validation;
- writes caused by nominally read-only UI refreshes;
- mean/total execution time;
- statement call counts;
- statement timeouts/lock waits where relevant.

**Exit:** all high-frequency/current recurrent endpoints have an attributable DB/RPC cost model.

### PERF-1E — Egress Attribution

Measure or estimate using observed bytes, never call counts alone.

Canonical model:

`calls/hour x response bytes x concurrent users/processes x active hours`

Track separately:

- Supabase/PostgREST response egress;
- Storage/CDN egress where applicable;
- Railway/browser payload where relevant to user-perceived performance;
- background server-to-Supabase traffic;
- static/media assets if material.

**Exit:** material egress sources have measured/defensible attribution and unexplained monthly usage is explicitly labeled UNKNOWN rather than guessed.

### PERF-1F — Lifecycle & Legacy Audit

Audit not only how recurrent work starts, but how it stops.

Required teardown classes:

- intervals/timeouts;
- MutationObservers;
- event listeners;
- fetch monkey patches/global wrappers;
- Service Workers;
- workers;
- recursive promises/timeouts;
- legacy tabs/routes;
- scripts that survive dynamic panel replacement.

Prove whether shell timer cleanup covers each mechanism. A hidden/removed panel that continues material traffic is a lifecycle leak.

**Exit:** all recurrent resources have owner + mount + teardown behavior documented.

### PERF-1G — Zero-Unknown Closure

Every recurrent producer discovered by static scan, dynamic trace, production logs or DB statistics receives exactly one classification:

- `JUSTIFIED`;
- `OPTIMIZE`;
- `DUPLICATED`;
- `LEGACY`;
- `EVENT_DRIVEN_CANDIDATE`;
- `REMOVE`;
- `UNKNOWN`.

`UNKNOWN > 0` for a material recurrent production producer means `ASC-PERF-1 = FAIL / OPEN`.

**Exit:** zero material unidentified recurrent network/database producers inside certified CURRENT scope.

## 4. ASC-PERF LAB repository components

ASC-PERF tooling belongs inside `ascenda-os` so GitHub CURRENT remains the single source of truth.

Planned structure:

```text
tools/perf-audit/
  runtime-census.mjs
  network-census.mjs
  rpc-census.mjs
  payload-analyzer.mjs
  ownership-checker.mjs

ci/performance/
  runtime-contract.mjs
  polling-contract.mjs
  payload-contract.mjs
  ownership-contract.mjs
  regression-budget.mjs

docs/control/
  RUNTIME_CALL_MAP_CURRENT.json
  READ_OWNERSHIP_REGISTRY_CURRENT.*
  PERFORMANCE_BUDGETS_CURRENT.*
  PERFORMANCE_ANTI_PATTERNS.md
```

No second repository is authoritative for ASCENDA runtime performance.

## 5. Tooling strategy

### Built into repository / Zero-Cost

- Node static scanner: dependency-free initial census;
- Playwright: dynamic browser/network fixture when dependency/runtime availability is validated;
- `pg_stat_statements`: PostgreSQL workload evidence;
- Supabase API/log evidence: request endpoint evidence;
- Sentinel/OpenTelemetry: portable runtime correlation under zero-PII/PHI policy;
- Sentry: specialized error/trace sensor, not sole source of truth.

### Candidate external/open-source tooling

- Semgrep for precise static anti-pattern rules;
- k6 for synthetic load/performance regression in isolated Zero-Cost staging;
- OpenTelemetry collector for controlled metric/trace routing where already compatible with Sentinel policy.

External tools are helpers; they do not replace CURRENT contracts or create a second source of truth.

## 6. Initial anti-pattern registry

Confirmed examples to turn into future CI rules after Audit 360:

- `PERF-RULE-001`: one recurrent owner for WA inbox;
- `PERF-RULE-002`: no `select=*` in recurrent production reads without explicit allowlist;
- `PERF-RULE-003`: simple badge/counter must not poll a heavy full administrative snapshot;
- `PERF-RULE-004`: no N+1 RPC fan-out inside recurrent refresh;
- `PERF-RULE-005`: hidden/inactive panel must not continue full polling without explicit critical-delivery contract;
- `PERF-RULE-006`: recurrent worker must have bounded idle behavior/backoff or event-driven justification;
- `PERF-RULE-007`: dynamic panel teardown must clean every recurrent resource type it creates;
- `PERF-RULE-008`: legacy and canonical consumers must not independently poll the same read model.

Rules are not enforced until fixtures demonstrate low false-positive risk.

## 7. Entry baseline evidence

At Audit 360 start:

- `main = ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`;
- `pg_stat_statements_info.stats_reset = 2026-08-22 00:01:09.895151+00`;
- a fresh production read-only sample continues to show the known high-frequency actor, notification-claim, WA conversation and agent scheduler patterns;
- production is not mutated by PERF-0/1 investigation.

## 8. Current execution state

- `ASC-PERF-0`: **IN PROGRESS** — exact main and DB statistics window revalidated; remaining baseline evidence will be frozen into the performance baseline report.
- `PERF-1A`: **IN PROGRESS** — machine static census being introduced.
- `PERF-1B..1G`: **PENDING**.
- remediation `PERF-3+`: **BLOCKED** until Audit 360 evidence is sufficiently frozen.
