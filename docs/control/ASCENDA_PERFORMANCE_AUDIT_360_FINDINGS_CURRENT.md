# ASCENDA OS — ASC-PERF AUDIT 360 FINDINGS CURRENT

**Status:** CURRENT / LIVING EVIDENCE REGISTER  
**Captured:** 2026-08-22 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Branch:** `perf/asc-perf-stabilization-20260822`  
**Parent:** `ASCENDA_PERFORMANCE_AUDIT_360_CURRENT.md`

## Classification

- `CONFIRMED`: source + live/runtime/DB evidence agree sufficiently to prove the pattern.
- `CANDIDATE`: source pattern is plausible but runtime ownership/cost still requires dynamic confirmation.
- `UNKNOWN`: live behavior exists but source/owner/cadence is not yet reconciled.
- `JUSTIFIED`: recurrent behavior is intentional and within a declared budget.
- `SUPERSEDED`: finding was replaced by a more precise diagnosis.

Material `UNKNOWN` findings block `ASC-PERF-1G` closure.

## Current findings

| ID | Domain | State | Finding | Evidence / current interpretation | Next gate |
|---|---|---|---|---|---|
| PERF-F001 | WhatsApp | CONFIRMED | More than one inbox owner | Native WA refreshes inbox at high cadence while multiagent also fetches `/api/wa3/inbox?limit=120`. | PERF-1C/1D then PERF-4 |
| PERF-F002 | WhatsApp | CONFIRMED | Message refresh amplification | Active-conversation messages are reloaded periodically even with no semantic change; legacy pages contain independent inbox/message loops. | PERF-1C/1F |
| PERF-F003 | WhatsApp | CONFIRMED | Actor/session validation amplification | `aos_wa3_actor_v1` is invoked across sibling endpoints and is one of the highest-call statements in production statistics. | PERF-1D |
| PERF-F004 | WhatsApp | CONFIRMED | Team presence N+1 | Team summary maps candidate users to `aos_wa3_effective_presence_v2`, multiplying RPCs by user count. | PERF-1D then PERF-4 |
| PERF-F005 | Notifications | CONFIRMED | Fixed 4-second idle claim pump | `aos_notification_push_claim_v1` continues at ~4-second cadence; fresh live logs and cumulative calls match this fingerprint. | PERF-1D/1E then PERF-5 |
| PERF-F006 | Agents | CONFIRMED | Cron scheduler recurrent `select=*` | `aos_agentes?select=*&activo=eq.true&tipo_ejecucion=eq.cron` runs about once/minute despite scheduler requiring a much smaller column set. | PERF-1E then PERF-3/5 |
| PERF-F007 | Product Resolution | CONFIRMED | Heavy admin snapshot used as badge/status refresh | Product-resolution badge can invoke `aos_product_review_admin_v1`; RPC constructs queue/catalog and updates session `last_used_at`, making a visual status read materially heavier than a counter. | PERF-1C/1D then PERF-3/6 |
| PERF-F008 | Admin Home | CONFIRMED | Same-cycle `aos_panel_admin` duplication | Admin home main load and monitoring load can request the same read model twice for the same date. | PERF-1C then PERF-6 |
| PERF-F009 | Call Center | CONFIRMED | `aos_panel_asesor` duplicate snapshot + weekly calendar fan-out | Metrics/history duplicate advisor snapshot; month calendar can issue one weekly RPC per rendered week. | PERF-1C/1D then PERF-6 |
| PERF-F010 | Coordination | CONFIRMED | Overlapping 8s/15s synchronization loops | `coordinacion.html` contains two recurrent channel/message refresh paths; `lCh()` can itself trigger `lMs()`, amplifying active-chat reads. | PERF-1C/1F then PERF-6 |
| PERF-F011 | Legacy WA | CANDIDATE | Legacy direct pages can independently poll | `admin-whatsapp.html` and `admin-whatsapp-wa3.html` contain their own recurrent polling. Need runtime/navigation proof for current reachability/usage. | PERF-1B/1F |
| PERF-F012 | Brain / KronIA | CANDIDATE | Realtime + unconditional REST fallback on same audit stream | `cerebro.html` opens Supabase Realtime on `aos_log_auditoria` while also polling the same audit stream every 8s, plus a separate 30s connectivity read. The REST fallback is not conditioned on WebSocket failure in current source. | PERF-1B/1C/1F |
| PERF-F013 | Brain / KronIA | CANDIDATE | Separate 15s proactive polling chain | `checkProactiveEvents()` runs every 15s; initial pass queries latest IDs from sales/agenda/leads in parallel, then subsequent cycles query new sales and conditionally agenda/leads. | PERF-1B/1C/1E |
| PERF-F014 | Studio | UNKNOWN | Recurrent unauthorized background query | Live Supabase API logs show `aos_studio_contenido?...PROGRAMADO...` returning 401 roughly every minute. Current `server.js` source has a Studio scheduler guarded by `AOS_STUDIO_BACKGROUND_ENABLED` and a 120s interval when enabled, so live cadence/source does not yet reconcile exactly with CURRENT source. | PERF-1B/1D/1F |
| PERF-F015 | CI / Control Plane | CONFIRMED | Global CURRENT doc edits trigger unrelated heavy domain workflows | REV-F6 workflows include `ASCENDA_WORKSTREAM_LOCK_CURRENT.md`, `ASCENDA_PROJECT_PORTFOLIO_CURRENT.md` and/or `docs/MEMORY_CURRENT.md` in PR path filters. ASC-PERF governance edits therefore fan out into unrelated FAST/DB suites and contend for self-hosted runners. | PERF-1B control-plane map then PERF-8 |
| PERF-F016 | Shell lifecycle | CANDIDATE | Timer cleanup does not prove cleanup of all recurrent resource classes | Shell captures/clears panel-created intervals, but MutationObservers, listeners, WebSockets, Service Workers, fetch monkey patches and recursive async loops require independent teardown proof. | PERF-1F |
| PERF-F017 | Runtime patches | CANDIDATE | Multiple global `window.fetch` monkey patches may form layered runtime behavior | CURRENT source contains several fetch wrappers/shims across Calls, Revenue, Auth/Security and WA modules. Ordering/teardown/consumer scope must be mapped before performance or auth changes. | PERF-1B/1F |

## Triage examples — avoid false positives

Not every short interval is a network defect.

- `notification-center-s15.js` runs `patchPanels` every 1s, but current implementation mainly discovers/patches DOM functions and guards already-patched functions. It is a performance candidate for DOM overhead, not evidence of one network request per second.
- `f4-revenue-ops.js` combines a MutationObserver and 1.2s `patchSales` timer, but that recurring function is primarily UI patching; any network consequence must be traced separately.
- Brain audio/VAD intervals are local audio/DOM computation and must not be grouped with network polling merely because their cadence is short.

This distinction is mandatory for the static scanner and future CI rules.

## Fresh baseline snapshot at Audit 360 start

`pg_stat_statements_info.stats_reset = 2026-08-22 00:01:09.895151+00`.

A fresh read-only snapshot at Audit 360 start showed, among other statements:

- WA actor-shaped statement: `39,593` calls, ~`1,173,429 ms` total, ~`29.64 ms` mean;
- notification claim-shaped statement: `23,498` calls, ~`569,830 ms` total, ~`24.25 ms` mean;
- broad WA conversation read shape: `13,030` calls;
- Product Resolution admin-shaped RPC: `2,814` calls, ~`444,991 ms` total, ~`158.13 ms` mean;
- agent cron `SELECT *`: `1,563` calls, ~`28,819 ms` total, ~`18.44 ms` mean;
- advisor panel-shaped RPC: `701` calls, ~`328,093 ms` total, ~`468.04 ms` mean.

These cumulative statistics are baseline evidence for prioritization, not proof that each call was avoidable.

## Current control state

- Production application/database mutation by ASC-PERF: **0**.
- `main` mutation by ASC-PERF: **0**.
- Branch-only Audit 360 tooling: active.
- PERF-1A Zero-Cost workflow: queued on self-hosted infrastructure at this checkpoint.
- Remediation phases PERF-3+: blocked until Audit 360 has enough evidence to avoid symptom-only fixes.
