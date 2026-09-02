# ASCENDA OS — RELIABILITY & PERFORMANCE DOCTRINE CURRENT

**Captured:** 2026-09-02 America/Lima  
**Scope:** all HIGH/CRITICAL ASCENDA workstreams  
**Applies to:** WhatsApp, Agenda, Call Center, Marketing, Sales, Commissions, Revenue, CIA and shared background/runtime infrastructure  
**Status:** MANDATORY REGRESSION BOUNDARY

## Why this exists

During the 2026-09-01/02 Call Center, Agenda and Marketing incidents, ASCENDA demonstrated a recurring failure mode: new functionality could be correct in isolation while increasing database/read pressure or reintroducing expensive analytic work into operational paths. Code PASS alone was not sufficient to prove production reliability.

This document freezes the engineering lessons so future WhatsApp and Revenue work does not repeat them.

> **CODE PASS != DEPLOY PASS != PROD PASS.**
>
> A user-visible or load-sensitive change closes only after exact-head CI, deploy proof, live backend invariants and a realistic production smoke/readback.

## Core architecture rule

**Critical path first; analytics later; background retreats.**

Operational synchronous actions must not reconstruct global analytics. Saving a booking, confirming a call, fetching the next lead, registering a sale or performing another revenue-critical write should resolve only the facts required for that action.

## Non-negotiable guardrails

1. **No global analytic views inside operational writes.** Keep lifecycle/history/attribution-style materialization out of booking, call and sale hot paths unless it is provably required for the decision.
2. **Do not raise `statement_timeout` to hide slow SQL.** The current browser boundary (`anon` approximately 3 s) is a design budget, not a nuisance to bypass.
3. **Push predicates down.** Prefer phone-scoped, period-scoped, site-scoped, advisor-scoped or entity-scoped reads instead of materializing global datasets and filtering afterward.
4. **Parity before optimization.** Any SQL/identity/attribution replacement must prove old<->new equivalence (0 unexplained differences) on a representative sample or the applicable universe before PROD.
5. **No legacy + new duplicate generation.** If V2/V4 owns rendering/decisioning, obsolete legacy reads must not continue hitting Supabase when their output is discarded.
6. **Single-flight and selective serialization.** Identical reads coalesce. Heavy reads sharing the same graph/dataset must not be fired in unnecessary parallel bursts.
7. **Never cache failures.** Cache only successful 2xx reads. Do not cache 5xx, 52x, SQLSTATE 57014, provider or transport failures.
8. **Browser abort is not PostgreSQL cancellation.** Once a heavy read has reached PostgREST, do not immediately launch another heavy read assuming abort stopped the server statement. UI cycle guards may discard stale results while the server read settles.
9. **Annual analytics stay off monthly critical paths.** History/LTV/cohorts should lazy-load and wait for month-switch quiescence; changing month must not rebuild annual analytics unnecessarily.
10. **Background retreat is shared infrastructure.** Cron, notification claims, caches and other non-critical work back off on provider/database degradation. One successful background job must not erase another job's failure cooldown.
11. **Cold path matters.** Warm-cache measurements are useful but cannot certify a browser path whose first load can fail.
12. **Do not run heavy diagnostics during an active business incident.** Native Advisor or other expensive management queries can worsen an already degraded system; use targeted read-only probes first.

## Mandatory remediation / optimization sequence

1. Capture a **LIVE baseline**: API/Postgres logs, `pg_stat_statements`, latency, calls, buffers and error rate.
2. Identify the exact endpoint/RPC that fails; do not patch from visual perception alone.
3. Run `EXPLAIN (ANALYZE, BUFFERS)` on the actual failing case when safe.
4. Locate the dominant hotspot, not merely the most obvious subquery.
5. Design a scoped fast path with the same business semantics.
6. Prove parity before production mutation.
7. Branch from exact `main`.
8. Require a dedicated regression gate plus relevant transversal CI/Performance Guard/Audit gates.
9. Anti-drift immediately before merge; merge with `expected_head_sha` when available.
10. Deploy code and apply DB migration from merged lineage only.
11. Canary under the real boundary:
   - writes: transactional `BEGIN -> real RPC path -> assertions -> ROLLBACK`;
   - reads: real role / timeout boundary, including cold behavior where possible.
12. Run human LIVE smoke when the original defect was browser-, concurrency- or user-dependent.
13. Read back HTTP status, PostgreSQL errors, latency, persistence/rollback and residual rows.
14. Only then mark **PRODUCTION CERTIFIED**.

## Proven lessons — Call Center / Agenda

- The booking incident was not the form itself: `prepare_action` returned 200 while `aos_callcenter_commit_action_v1` crossed the browser statement timeout.
- `customer lifecycle` analytics did not belong in the synchronous booking commit.
- Phone-scoped identity resolution + indexed operational facts preserved identity/business semantics while reducing critical-context work from seconds to milliseconds.
- Required booking canary pattern:
  `prepare -> commit/confirm -> llamada + agenda + action COMPLETE -> ROLLBACK`.
- Do not infer partial persistence from a UI error. Query residual rows before concluding that a transaction committed partially.

## Proven lessons — Marketing

- The panel paid for legacy generation and V4.2 analytics together; annual History/LTV also repeated across month switches.
- History/LTV must execute lazily and not once per month.
- Attribution/Intent/Detail share expensive attribution graphs; unnecessary concurrency can push each other over the role timeout even if isolated warm runs are fast.
- A targeted partial index can drastically reduce buffers, but an index alone does not fix repeated global materialization.
- `aos_marketing_call_lead_match_v2` improved by replacing repeated scans with phone-scoped one-pass aggregation while preserving exact match/confidence semantics.
- Monthly summary/insight orchestration must avoid caching failures and should serialize critical monthly work where overlap creates pressure.
- First/cold access is part of the product SLO.

## Proven lessons — Supabase / infrastructure

- Separate provider/API Gateway degradation from project compute capacity before deciding an upgrade.
- Optimize software first and certify provider stability before concluding Nano is undersized.
- Project restart is exceptional recovery, not a performance architecture.
- Pro/Micro is justified only by reproducible capacity evidence after software containment and under a healthy provider window.

## Mandatory cross-module regression matrix for WhatsApp changes

Any WhatsApp change that touches runtime/preloads, Supabase, Agenda, identity, booking, cron, notification/background traffic, sales truth or attribution must prove the following boundaries remain healthy:

### Agenda
- governed create/edit/status path remains functional;
- no browser 404/500/schema-cache regression;
- booking write path remains transactionally consistent.

### Call Center
- next-lead critical path remains prioritized;
- `prepare` and governed `commit/confirm` remain within the browser budget;
- no return of analytic lifecycle/global identity work to the write path;
- calendar/background reads do not fan out ahead of the lead boundary.

### Marketing
- month switch does not cause legacy+new duplicate reads;
- annual analytics do not repeat per month;
- no cached 500/timeout;
- no avoidable heavy-RPC burst that competes with revenue-critical traffic.

### Sales / Commissions
- sales and commission dashboards must be audited for request census, duplicate loads, polling, cold/warm latency, buffers and fan-out before optimization;
- optimizations may not change totals, commission rules, ownership or financial lineage without explicit business approval and parity proof.

### WhatsApp safety
Until L4 is explicitly authorized and certified:
- `auto_reply=false`;
- `ai_send=false`;
- `auto_routing=false`;
- `human_send=true`;
- LLM never writes arbitrary SQL or sends directly to Meta.

### Background
Non-critical jobs must not compete with Call Center, Agenda, Sales or WhatsApp critical traffic during degradation.

## Performance budget guidance

A 3 s browser timeout does not mean 2.9 s is acceptable. Critical RPCs need material headroom.

Guideline:
- strive for sub-second hot paths where practical;
- target p95 comfortably below 2 s for critical browser RPCs;
- evaluate latency + buffers + request count + error rate together;
- record cold and warm behavior separately when caching materially changes performance.

## Next performance workstream

**REV-PERF — Sales + Commissions**

Discover first, mutate second:
1. map frontend owners and all initial/month-switch/filter requests;
2. inspect polling/retries/duplicate generations;
3. rank RPCs/views by mean/max time and shared/temp buffers;
4. identify analytics accidentally placed on critical paths;
5. create parity fixtures for Sales and Commission totals before any SQL rewrite;
6. implement read-pressure containment / predicate pushdown / indexes only where evidence supports them;
7. certify LIVE with real dashboard usage.

## WhatsApp continuation rule

WA work may resume from its SAFE-OFF checkpoint, but this doctrine becomes a transversal exit gate. A WA phase is not complete if it makes Agenda, Call Center, Marketing, Sales/Commissions or shared Supabase pressure regress.

L4 Authority + Kill Switch remains a separate authorization boundary and must not start merely because performance work is green.
