# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**Captured:** 2026-08-22 America/Lima  
**Entry baseline:** `main@ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**ACTIVE PORTFOLIO OWNER:** `ASC-PERF-STABILIZATION`

## Current owner state

The owner explicitly moved the single HIGH/CRITICAL mutable lane to systemic performance stabilization before further feature expansion. Current degradation is cross-domain and must be solved as infrastructure/read-architecture debt rather than by adding more patches or purchasing capacity as a substitute for optimization.

`ASC-PERF-0 — Governance Freeze & Exact Baseline` is the active gate.

Canonical plan: `docs/control/ASCENDA_PERFORMANCE_STABILIZATION_CURRENT.md`.

## Program map

| Program | Certified / preserved input | Remaining | Portfolio state |
|---|---|---|---|
| ASC-PERF — Performance Stabilization & Read Architecture | read-only root-cause evidence across WA, agents, dashboards, coordination and Product Resolution | PERF-0..PERF-10 | **ACTIVE** |
| WhatsApp Revenue Hub V2 | WA core + Notifications S13–S15.5 + PR #352 session continuity preserved | resume WA roadmap after stabilization and fresh revalidation | PAUSED / RECOVERABLE |
| Revenue | REV-F1..F6 certified upstream truth | REV-F7 and later | PAUSED / READ-ONLY |
| MKT Integrity / Call Center | Loop 6 V2.3 baseline preserved | terminal 5 genuine-op gate | PAUSED / RECOVERABLE at preserved checkpoint |
| CIA / Email / Acquisition | certified facts and adapters preserved | later activation work | READ-ONLY dependency source |
| Sentinel | observability/integrity foundation preserved | regression/deferred maintenance | REGRESSION-ONLY |
| KronIA | prior baseline preserved | later hardening | PAUSED except performance evidence on existing runtime |
| Migration governance | existing safe owner slices | parity/baseline maintenance | MAINTENANCE ONLY unless ASC-PERF requires evidence-backed DB work |

## Why ASC-PERF owns the lane

Current investigation has demonstrated the same architectural anti-pattern across several domains: recurrent reads are created locally by features without a global read owner, resulting in duplicate polling, broad payloads, N+1 fan-out, repeated expensive RPC execution and permanent idle workers.

The priority is therefore to:

1. inventory every recurrent NETWORK/DB producer in CURRENT runtime;
2. define one owner per read model;
3. set measurable performance budgets;
4. remove no-semantic-change waste first;
5. consolidate WA/background/dashboard synchronization;
6. remeasure before DB/index/RPC tuning;
7. make the rules enforceable in CI;
8. certify production with matched before/after telemetry;
9. persist the learning into CURRENT governance before returning to feature work.

## Preserved business truth boundaries

ASC-PERF does not create a new truth model. Existing ownership remains:

- F3 = product identity/facts;
- F4 = payment/revenue/cartera/reconciliation truth;
- F5 = patient identity + provenance;
- F6 = derived intelligence/read models;
- CIA = governed audience/channel/acquisition facts;
- Email = governed email channel facts/events;
- WA = conversation/channel product;
- Sentinel = observation/integrity.

Performance work may optimize how these truths are read, cached, batched or subscribed to, but must not duplicate or silently redefine them.

## Current runtime baseline

Exact `main` at ASC-PERF entry: `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`.

Preserved production chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

Runtime-chain/preload/auth boundary changes remain HIGH/CRITICAL and require exact-chain regression evidence.

## Global rule while ASC-PERF is active

At most one HIGH/CRITICAL feature/data workstream mutates shared CURRENT at a time. During ASC-PERF:

- no unrelated new HIGH/CRITICAL feature work;
- no parallel DB-heavy release lanes;
- read-only investigations and documentation are allowed;
- each performance patch must be independently measurable and reversible;
- no production mutation without the applicable Zero-Cost/preflight/canary gates;
- no capacity upgrade is treated as remediation evidence for duplicated/amplified reads.

## Immediate execution

1. `ASC-PERF-0` — freeze exact baseline and impact/rollback contract.
2. `ASC-PERF-1` — complete Runtime Call Map 360.
3. `ASC-PERF-2` — freeze Read Ownership Registry + budgets.
4. `ASC-PERF-3` — remove zero-semantic-change waste.
5. `ASC-PERF-4/5/6` — WA, workers and dashboard/coordination consolidation.
6. `ASC-PERF-7` — remeasure and optimize residual DB/RPC hotspots.
7. `ASC-PERF-8` — enforce Performance Guard CI.
8. `ASC-PERF-9` — matched production canary/certification.
9. `ASC-PERF-10` — freeze learning/governance and hand the lock back after fresh revalidation.
