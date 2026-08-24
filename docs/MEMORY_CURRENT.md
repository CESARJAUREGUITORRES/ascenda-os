# ASCENDA OS — MEMORY CURRENT

**Captured:** 2026-08-22 America/Lima  
**GitHub entry baseline:** `main@ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**ACTIVE WORKSTREAM:** `ASC-PERF-STABILIZATION`  
**CURRENT GATE:** `ASC-PERF-0 — GOVERNANCE FREEZE & EXACT BASELINE`

## Authority order

1. root `AGENTS.md`;
2. root `SECURITY.md`;
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`;
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`;
5. this file;
6. `docs/control/ASCENDA_PERFORMANCE_STABILIZATION_CURRENT.md`;
7. exact GitHub CURRENT + Railway exact deploy + Supabase LIVE;
8. the preserved CURRENT checkpoint of the paused domain being touched for performance;
9. fresh scoped rows in `aos_memory`;
10. Notion executive continuity last.

Historical chat/doc snapshots never override exact CURRENT + live production.

## Portfolio state

- ASC-PERF — **ACTIVE**;
- WhatsApp Revenue Hub V2 — **PAUSED / RECOVERABLE** after PR #352 session-continuity baseline;
- Notifications S13–S15.5 — preserved certified regression input, not reopened unless a real regression is demonstrated;
- REV-F1..F6 — certified upstream truth preserved; later mutable Revenue work paused;
- MKT Integrity Loop 6 V2.3 — preserved paused/recoverable checkpoint;
- CIA, Sentinel, KronIA and unrelated feature/data work — read-only/regression-only unless ASC-PERF proves a strict dependency.

## Why the lock moved

Read-only production/repository investigation found a cross-domain synchronization architecture problem rather than a single isolated Supabase defect. The repeated pattern is distributed read ownership: multiple modules independently poll or refresh the same or overlapping state, often with broad payloads, repeated session validation, N+1 fan-out or permanent idle workers.

Confirmed investigation families include:

- WhatsApp inbox/messages/team/presence duplicate readers;
- repeated `aos_wa3_actor_v1` validation across sibling requests;
- fixed ~4-second notification claim pump;
- Product Resolution badge invoking `aos_product_review_admin_v1` recurrently even when only a small counter is needed;
- recurring agent scheduler/API reads broader than required;
- duplicate expensive admin/advisor RPC consumption inside one visual refresh;
- calendar weekly fan-out;
- coordination/chat overlapping timers and nested message reloads;
- reachable legacy pages with independent polling.

This evidence is sufficient to prioritize stabilization, but not yet sufficient to declare the complete 360 call map closed.

## Runtime exact-current entry

Current `main` at ASC-PERF handoff: `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`.

Latest merged change at entry: PR #352 — WA-3 strong 2FA session continuity hotfix.

Production chain remains:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/railway.json` also preloads Sentry and the backend-only email runtime compatibility module. Runtime-chain/preload/auth changes remain HIGH/CRITICAL.

## Performance evidence already captured

Approximate cumulative production statement evidence in the active pg_stat_statements window includes:

- `aos_wa3_actor_v1` ~39k calls;
- `aos_notification_push_claim_v1` ~21k+ calls;
- `aos_product_review_admin_v1` ~2.8k calls, ~158 ms mean;
- `aos_wa3_queue_summary_v1` ~1.1k calls, ~150 ms mean;
- `aos_panel_asesor` ~700 calls, ~468 ms mean;
- `aos_panel_admin` ~74 calls, ~1.0 s mean;
- `aos_ticker_mkt` ~74 calls, ~1.3 s mean;
- `aos_siguiente_lead` ~338 calls, ~559 ms mean;
- `aos_horarios_semana` repeated weekly fan-out;
- `aos_llamadas` inserts >1 s mean in the sampled statement shape.

WA currently contains only a small number of conversations, so request amplification is proven but the full monthly egress overrun must not be attributed to WA alone without byte/time-window evidence.

## ASC-PERF canonical execution

1. `ASC-PERF-0` — Governance Freeze & Exact Baseline.
2. `ASC-PERF-1` — Runtime Call Map 360.
3. `ASC-PERF-2` — Read Ownership Registry & Performance Budgets.
4. `ASC-PERF-3` — Zero-Semantic-Change Waste Removal.
5. `ASC-PERF-4` — WhatsApp Single Read Owner.
6. `ASC-PERF-5` — Background Worker & Scheduler Efficiency.
7. `ASC-PERF-6` — Dashboards / Call Center / Coordination Read Consolidation.
8. `ASC-PERF-7` — Database/RPC Optimization After Call Reduction.
9. `ASC-PERF-8` — Performance Guard CI.
10. `ASC-PERF-9` — Production Canary & Performance Certification.
11. `ASC-PERF-10` — Governance Freeze, Learning & Handoff.

Canonical control document: `docs/control/ASCENDA_PERFORMANCE_STABILIZATION_CURRENT.md`.

## Safety invariants

- one HIGH/CRITICAL mutable workstream;
- no secrets in frontend/Git/Notion/chat;
- no direct experiment in production;
- no functional feature expansion while stabilization owns the lane;
- do not weaken Auth/2FA/RLS/ownership to reduce request cost;
- do not treat a larger Supabase tier as proof of remediation;
- no `select=*` or recurrent polling change is optimized blindly: first prove caller, consumer and freshness requirement;
- every mutable patch independently testable and reversible;
- DB/index/RPC tuning happens after amplification is reduced and remeasured;
- updates land GitHub first, then `aos_memory`, then Notion last.

## Resume contract for paused workstreams

After `ASC-PERF = PRODUCTION CERTIFIED`, the next owner is not resumed from stale chat state. It must revalidate exact CURRENT GitHub, runtime, live Supabase and its own preserved checkpoint, then receive an explicit lock handoff.
