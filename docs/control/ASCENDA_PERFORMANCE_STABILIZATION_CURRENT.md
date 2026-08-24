# ASCENDA OS — ASC-PERF PERFORMANCE STABILIZATION & READ ARCHITECTURE CURRENT

**Status:** CURRENT / EXECUTION PLAN / PRE-PRODUCTION  
**Captured:** 2026-08-22 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Owning namespace:** `ASC-PERF-*`  
**Risk:** HIGH / CRITICAL where runtime, auth/session, shared wrappers or production DB contracts are changed  
**Primary objective:** restore a responsive ASCENDA runtime, reduce unnecessary database/API/egress amplification, and install enforceable performance guardrails before feature development resumes.

## 1. Owner directive

The owner has prioritized systemic performance stabilization before further feature expansion because current read amplification and duplicated synchronization loops materially interfere with normal operation and development.

Until ASC-PERF reaches its exit gate:

- do not start new unrelated HIGH/CRITICAL feature/data workstreams;
- preserve existing workstream checkpoints as PAUSED / RECOVERABLE;
- read-only investigation and regression evidence may continue where it does not compete with ASC-PERF;
- do not patch symptoms directly in production;
- every mutable change must follow branch → tests → Zero-Cost when applicable → read-only preflight → canary → exact-head certification.

## 2. Problem statement

ASCENDA currently shows a cross-domain pattern of **read amplification and distributed state ownership** rather than a single Supabase-capacity defect.

Observed families include:

- multiple independent WhatsApp pollers reading the same inbox/team/presence state;
- repeated actor/session validation across sibling endpoints;
- background notification claims on a fixed 4-second cadence;
- agent scheduler reads using broader payloads than required;
- Product Resolution badge refresh invoking a heavy administrative RPC rather than a lightweight counter/event;
- duplicated dashboard/advisor RPC reads inside one visual refresh;
- weekly fan-out where one range snapshot can serve the same UI;
- coordination/chat runtimes with overlapping timers and repeated message reads;
- legacy pages capable of continuing independent polling if left open.

The remediation objective is not to make every timer slower. It is to establish **one owner per read model**, event-driven updates where available, bounded fallback polling, narrow payloads, batching, backoff, caching/snapshot reuse and CI-enforced budgets.

## 3. Baseline evidence already established

Production read-only evidence collected before this plan includes:

- `aos_wa3_actor_v1`: ~39k cumulative calls in current pg_stat_statements window;
- `aos_notification_push_claim_v1`: ~21k+ cumulative calls, matching a persistent ~4-second pump fingerprint;
- `aos_product_review_admin_v1`: ~2.8k calls with ~158 ms mean execution in the sampled window;
- `aos_panel_asesor`: ~700 calls with ~468 ms mean;
- `aos_panel_admin`: ~74 calls with ~1.0 s mean;
- `aos_ticker_mkt`: ~74 calls with ~1.3 s mean;
- `aos_siguiente_lead`: ~338 calls with ~559 ms mean;
- `aos_horarios_semana`: repeated weekly fan-out with ~243 ms mean;
- `aos_llamadas` inserts averaging >1 s in the sampled statement window;
- live WA conversation count is currently small, so WhatsApp request amplification is a major request/CPU issue but is not, by itself, sufficient evidence to attribute the full monthly egress quota overrun.

These are investigation inputs, not yet remediation certification.

## 4. Canonical execution index

### ASC-PERF-0 — Governance Freeze & Exact Baseline

**Purpose:** establish the single stabilization lane and freeze unrelated mutable expansion.

Required:

1. exact `main` SHA and runtime chain;
2. live Supabase project health;
3. current pg_stat_statements reset timestamp;
4. API request-rate sample;
5. egress/billing-cycle baseline from available production evidence;
6. top statements by calls, total time, mean time and rows;
7. preserve WA/MKT/REV/CIA/KronIA checkpoints without falsely closing them;
8. create Impact Report + rollback strategy for the stabilization program.

**Exit:** baseline reproducible and CURRENT docs agree on ASC-PERF as owner.

### ASC-PERF-1 — Runtime Call Map 360

**Purpose:** inventory every recurrent network/database producer in CURRENT runtime.

Scope:

- `app/` and `app/public/` CURRENT consumers;
- server timers/pumps/workers;
- `setInterval`, recursive `setTimeout`, focus/online/visibility handlers;
- MutationObservers that can trigger network effects;
- SSE/Realtime/WebSocket subscriptions;
- fetch/RPC wrappers and retry loops;
- legacy pages only after proving they remain directly reachable/usable;
- CI/runtime scripts only when they can hit production or shared services.

Every recurrent producer must be classified as:

`NETWORK` / `DB` / `DOM_ONLY` / `UI_CLOCK` / `ONE_SHOT` / `BACKGROUND` / `USER_TRIGGERED`.

For each NETWORK/DB producer record:

- file/function;
- cadence and hidden-tab behavior;
- endpoint/RPC/table;
- calls generated per user/process;
- fan-out per endpoint;
- selected fields/row limit;
- approximate payload bytes when measurable;
- authentication/session cost;
- shared consumers;
- duplication status;
- functional freshness SLA.

**Exit:** no unidentified recurrent production caller remains in CURRENT application scope.

### ASC-PERF-2 — Read Ownership Registry & Performance Budgets

**Purpose:** prevent multiple modules from independently owning the same read model.

Create canonical ownership for at least:

- WA inbox;
- WA messages;
- WA presence;
- WA team/queue state;
- notifications;
- agents runtime state;
- admin dashboard snapshot;
- advisor/call-center snapshot;
- coordination/chat state;
- caja snapshot;
- Product Resolution badge/status.

Initial policy candidates to validate and freeze:

- recurrent network loops `< 2 s`: prohibited;
- recurrent network loops `2–5 s`: explicit documented exception only;
- hidden-tab full polling: prohibited unless justified by a critical delivery contract;
- `select=*` in recurrent reads: prohibited;
- concurrent overlapping request for same owner/resource: prohibited;
- more than one runtime owner for same resource: prohibited;
- N+1 RPC inside recurrent polling: prohibited;
- heavy/full administrative RPC for a badge/counter: prohibited;
- server idle worker without backoff/event trigger: prohibited;
- legacy and canonical pollers active simultaneously: prohibited.

Budgets must be linked to a measurable SLO, not arbitrary timers.

**Exit:** every recurrent read has one declared owner and a measurable freshness/cost budget.

### ASC-PERF-3 — Zero-Semantic-Change Waste Removal

**Purpose:** capture low-risk savings before architectural rewrites.

Priority candidates:

- narrow recurring `select=*` reads to required columns;
- reuse identical in-flight/same-cycle snapshots;
- remove duplicate same-parameter RPC reads inside one UI refresh;
- stop recurrent reads while owning view is inactive/hidden where safe;
- suppress stale legacy pollers when canonical shell/runtime is active;
- remove redundant repeated message fetches caused by nested refresh functions;
- preserve exact user-visible behavior and authorization semantics.

**Gate:** each patch independently measurable and reversible.

**Exit target:** material request/byte reduction with zero functional behavior loss.

### ASC-PERF-4 — WhatsApp Single Read Owner

**Purpose:** consolidate WA synchronization without weakening realtime UX or ownership security.

Target architecture:

`WA Store / Snapshot Owner → subscribers/events → native UI + multiagent UI + badges`

Required work:

- one inbox fetch/subscription owner;
- multiagent consumes shared inbox state instead of refetching;
- messages reload only on active-conversation change or version/message-state change;
- focus/visibility can force refresh without creating permanent duplicate loops;
- presence heartbeat separated from queue-summary payload when semantics permit;
- team effective presence batched, not one RPC per candidate user;
- fallback polling bounded and paused when hidden;
- legacy pages cannot run a second canonical poller concurrently.

Auth/2FA/ownership boundaries must remain unchanged or stronger.

**Exit:** realtime/human operations smoke PASS with substantially lower WA request amplification.

### ASC-PERF-5 — Background Worker & Scheduler Efficiency

**Purpose:** eliminate permanent idle load.

Scope:

- notification push claim pump;
- agent cron scheduler;
- agent/task background workers;
- integration health/reconcile loops;
- any server process that periodically checks for absent work.

Patterns:

- adaptive/exponential idle backoff;
- immediate reset to fast cadence when backlog/work exists;
- event-driven wake-up where reliable;
- narrow payload reads;
- singleton/mutex protection;
- no duplicate worker per process topology.

**Exit:** idle production produces bounded, low background database traffic without losing operational SLA.

### ASC-PERF-6 — Dashboards / Call Center / Coordination Read Consolidation

**Purpose:** eliminate duplicate expensive read-model execution.

Scope includes:

- `aos_panel_admin` reuse;
- `aos_ticker_mkt` caching/snapshot strategy;
- `aos_panel_asesor` single snapshot reuse;
- calendar range/month reads replacing weekly fan-out;
- coordination/chat duplicated timers and nested message reloads;
- caja refresh only while relevant view is active;
- badges and small counters backed by lightweight read models.

**Exit:** one refresh action maps to one declared snapshot per domain, not repeated heavy RPCs.

### ASC-PERF-7 — Database/RPC Optimization After Call Reduction

**Purpose:** optimize the residual real workload only after amplification is removed.

Required sequence:

1. remeasure pg_stat_statements after phases 3–6;
2. identify remaining high-total-time / high-mean-time statements;
3. EXPLAIN/plan analysis in safe environment where applicable;
4. add only evidence-backed indexes;
5. fix query shapes/casts/date filters/join patterns;
6. review RLS and SECURITY DEFINER overhead without weakening authorization;
7. version breaking RPC contracts;
8. avoid blindly dropping indexes from `unused_index` lint without stable statistics evidence.

**Exit:** no unresolved in-scope hot statement exceeds agreed budget without documented exception.

### ASC-PERF-8 — Performance Guard CI

**Purpose:** make recurrence mechanically difficult.

Create automated contracts that detect or require explicit allowlisting for:

- network `setInterval` / recursive timers under budget;
- hidden-tab polling;
- `select=*` in recurrent runtime paths;
- duplicate ownership registry entries;
- N+1 recurrent fan-out patterns in governed hotspots;
- direct legacy pollers when canonical runtime is active;
- recurring heavy RPC used for simple badge/counter;
- missing abort/inflight/mutex protection where overlapping requests are possible.

The gate must be precise enough to avoid flagging UI clocks, day-boundary checks or other non-network timers as defects.

**Exit:** representative bad-pattern fixtures FAIL and compliant fixtures PASS in Zero-Cost CI.

### ASC-PERF-9 — Production Canary & Performance Certification

**Purpose:** prove improvement on the actual deployed runtime.

Before/after evidence:

- API requests/min;
- recurrent DB calls/min by hot object;
- egress slope where measurable;
- p50/p95 latency for key UI/API paths where instrumentation permits;
- statement timeout count;
- browser-visible load/interaction smoke;
- WA send/receive/ownership/presence/notifications regression;
- Sales/Product Resolution regression;
- Call Center/admin/caja/coordination regression;
- CPU/RAM/connection behavior where platform evidence is available.

Initial success target to validate during baseline:

- >=70% reduction in avoidable repeated calls in targeted recurrent paths;
- zero duplicate read owners in certified scope;
- zero unauthorized security relaxation;
- zero functional regressions in affected workflows;
- clear downward egress/request slope versus matched baseline window.

No single percentage alone certifies the phase; all functional and security gates must pass.

### ASC-PERF-10 — Governance Freeze, Learning & Handoff

**Purpose:** make the optimization durable and return the portfolio lock safely.

Create/update CURRENT documents:

- `PERFORMANCE_ARCHITECTURE_CURRENT.md`;
- `READ_OWNERSHIP_REGISTRY_CURRENT.md`;
- `PERFORMANCE_BUDGETS_CURRENT.md`;
- `PERFORMANCE_ANTI_PATTERNS.md`;
- `AGENTS.md` bootstrap/rules for recurrent network work;
- applicable workstream-specific docs;
- `docs/MEMORY_CURRENT.md`;
- `aos_memory` after GitHub merge;
- Notion executive continuity last.

Then restore the prior workstream from a fresh revalidation of CURRENT, not from stale branch state.

**Exit:** `ASC-PERF = PRODUCTION CERTIFIED` and the next mutable owner is explicitly handed the lock.

## 5. Execution order and dependency rule

Canonical order:

`PERF-0 → PERF-1 → PERF-2 → PERF-3 → PERF-4/5/6 → PERF-7 → PERF-8 → PERF-9 → PERF-10`

PERF-4, PERF-5 and PERF-6 may be developed as separately measurable patches but must not be deployed concurrently without an explicit canary plan. PERF-7 must use post-amplification measurements, not the polluted pre-fix baseline alone.

## 6. Risk segmentation

### LOW

- read-only audit;
- documentation;
- static inventory;
- CI detection logic that does not affect release behavior.

### MEDIUM/HIGH

- frontend timer ownership;
- shared snapshot/event architecture;
- polling/caching behavior;
- endpoint response changes preserving auth and data contract.

### CRITICAL when applicable

- Auth/session/2FA path;
- SECURITY DEFINER/RLS/grants;
- outer runtime chain;
- shared server wrappers;
- migration affecting multiple domains;
- notification delivery trust boundary.

No CRITICAL production mutation without explicit owner authorization after green preproduction evidence.

## 7. Rollback doctrine

Performance patches must be independently reversible.

Preferred rollout:

1. additive shared snapshot/store;
2. subscriber migration;
3. canary one role/panel where possible;
4. observe;
5. disable old owner;
6. keep short-lived kill switch/fallback only when it does not create duplicate traffic;
7. remove legacy path after certification.

Do not combine unrelated query rewrites, session changes, worker cadence changes and UI consolidation into one irreversible release.

## 8. Non-goals

ASC-PERF does not:

- add new customer-facing product features;
- redesign UI for aesthetics;
- change business truth ownership;
- weaken realtime/user experience merely to reduce calls;
- buy a higher Supabase tier as a substitute for fixing amplification;
- delete historical/legacy code before consumer proof;
- declare egress root cause from request count alone.

## 9. Immediate next action

Start `ASC-PERF-0` and `ASC-PERF-1` in read-only mode against exact-current production/runtime. Do not implement remediation until the 360 runtime call map and ownership conflicts are frozen enough to prevent one patch from hiding another source of amplification.
