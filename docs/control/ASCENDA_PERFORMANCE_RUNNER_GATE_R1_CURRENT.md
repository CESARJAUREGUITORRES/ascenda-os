# ASCENDA OS — ASC-PERF RUNNER GATE R1 CURRENT

**Status:** READY / WAITING FOR RUNNER  
**Captured:** 2026-08-24 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Branch:** `perf/asc-perf-stabilization-20260822`  
**PR:** `#353` DRAFT

## 1. Why the online loop stops here

GitHub source, Git history, Supabase read-only statistics/logs, current table state and static runtime tracing have been exhausted enough that the remaining material assertions require actual controlled execution rather than more source-only inference.

No remediation is authorized yet.

## 2. Required runner

Primary label:

`[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

Only this runner is required for R1. The Windows FAST runner and other runners do not need to be powered on for the first ASC-PERF gate.

## 3. R1 execution sequence

### R1-A — Exact-head static census

Run workflow:

`ASCENDA ASC-PERF Audit 360`

Required job:

`PERF-1A static runtime census`

Required evidence:

- exact branch head checkout;
- Zero-Cost runner enforcement PASS;
- `runtime-census.mjs` PASS;
- non-empty census JSON;
- files scanned / lines scanned / finding counts captured;
- no scanner crash or incomplete artifact.

### R1-B — Reconcile automated census with online Runtime Call Map

Compare scanner output against:

`docs/control/ASCENDA_RUNTIME_CALL_MAP_ONLINE_CURRENT.json`

Every automated candidate must become:

`CONFIRMED / CANDIDATE / UNKNOWN / JUSTIFIED / SUPERSEDED`.

Missing material producer in either direction is a gap and keeps PERF-1A open.

### R1-C — Controlled browser trace foundation

After R1-A passes, prepare/run Playwright or equivalent controlled browser instrumentation against the exact-head Zero-Cost/runtime fixture.

Minimum routes/panels:

- shell idle ADMIN;
- Admin Home;
- Calls;
- Caja;
- Agents;
- Coordination Admin;
- Advisor Coordination;
- Brain/KronIA;
- current WhatsApp native/multiagent surface;
- direct legacy WhatsApp pages only for reachability/concurrency proof;
- Product Resolution badge/runtime.

For each capture request counts and response bytes over controlled windows and then repeat with the tab hidden/navigation changed.

### R1-D — Lifecycle assertions

Prove dynamically:

- panel intervals stop after navigation;
- MutationObservers/listeners do not keep network producers alive unexpectedly;
- WebSockets close/stop when their owning view is retired where required;
- Service Workers do not create an undocumented recurrent read owner;
- global `window.fetch` patches do not accumulate across panel transitions;
- hidden tabs obey the intended performance budget;
- direct legacy pages cannot silently create an unnoticed second canonical owner in normal workflow.

### R1-E — Multi-proxy baseline

Measure representative request latency at outer boundary versus nearest feasible inner/base boundary in controlled execution.

Purpose: quantify `PERF-F021`; do not flatten the runtime chain merely because it is deep.

## 4. Current runner-blocking assertions

The following cannot be certified online-only:

1. automated static census exact-head result;
2. actual request/minute for logged-in shell global polls;
3. active Agents/Brain/Coordination panel request volumes;
4. teardown after dynamic navigation;
5. actual concurrent legacy/canonical WA behavior;
6. hidden-tab browser behavior across panels;
7. latency contribution of the multi-proxy process chain;
8. final reconciliation of every source-only candidate with dynamic behavior.

Studio `PERF-F014` also remains `UNKNOWN`: live production emits a ~60s 401 query while CURRENT source/history specify Studio default OFF and 120s if explicitly enabled. Runner R1 may help reproduce source behavior, but resolving the production owner may additionally require Railway runtime/config evidence.

## 5. Stop rule

Do not begin PERF-3 remediation until:

- R1-A is PASS;
- automated census is reconciled with the online map;
- dynamic traces cover the material active-panel candidates;
- remaining UNKNOWNs are explicitly identified with the exact missing evidence.

## 6. Owner action when ready

Power on the Linux runner carrying all labels:

`self-hosted`, `Linux`, `X64`, `ascenda-zero-cost-v2`

Then re-run `ASCENDA ASC-PERF Audit 360` against the latest ASC-PERF branch head. No other runner is required for the first gate.
