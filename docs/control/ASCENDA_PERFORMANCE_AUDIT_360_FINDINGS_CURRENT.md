# ASCENDA OS — ASC-PERF AUDIT 360 FINDINGS CURRENT

**Status:** CURRENT / LIVING EVIDENCE REGISTER  
**Captured:** 2026-08-24 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Branch:** `perf/asc-perf-stabilization-20260822`  
**Parent:** `ASCENDA_PERFORMANCE_AUDIT_360_CURRENT.md`  
**Online loop:** `ASCENDA_PERFORMANCE_ONLINE_LOOP_CURRENT.md`

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
| PERF-F003 | WhatsApp | CONFIRMED | Actor/session validation amplification | `aos_wa3_actor_v1` is invoked across sibling endpoints and is one of the highest-call statements in production statistics. Current cumulative count remains ~39.6k in the same stats window while current idle logs are dominated by server background work, so WA is a proven amplification family but not the current idle dominant producer. | PERF-1D |
| PERF-F004 | WhatsApp | CONFIRMED | Team presence N+1 | Team summary maps candidate users to `aos_wa3_effective_presence_v2`, multiplying RPCs by user count. | PERF-1D then PERF-4 |
| PERF-F005 | Notifications | CONFIRMED | Fixed 4-second idle claim pump | `server-f17.js` owns one immediate + fixed 4000ms notification pump. Fresh live logs on 2026-08-24 show `aos_notification_push_claim_v1` every ~4s with `AscendaOS-F17/1.4`. Same stats window reached `56,485` calls, ~`894,013 ms` total, ~`15.83 ms` mean. | PERF-1D/1E then PERF-5 |
| PERF-F006 | Agents | CONFIRMED | Cron scheduler recurrent `select=*` | CURRENT `server.js` runs guarded `autoTick` every 60s and first reads `aos_agentes?select=*&activo=eq.true&tipo_ejecucion=eq.cron`. Fresh live logs match ~60s cadence. Same stats window reached `3,770` calls. | PERF-1E then PERF-3/5 |
| PERF-F007 | Product Resolution | CONFIRMED | Heavy admin snapshot used as badge/status refresh | Product-resolution badge can invoke `aos_product_review_admin_v1`; RPC constructs queue/catalog and updates session `last_used_at`, making a visual status read materially heavier than a counter. Current same-window count ~`2,922`, ~`155.53 ms` mean. | PERF-1C/1D then PERF-3/6 |
| PERF-F008 | Admin Home | CONFIRMED | Same-cycle `aos_panel_admin` duplication | Admin home main load and monitoring load can request the same read model twice for the same date. | PERF-1C then PERF-6 |
| PERF-F009 | Call Center | CONFIRMED | `aos_panel_asesor` duplicate snapshot + weekly calendar fan-out | Metrics/history duplicate advisor snapshot; month calendar can issue one weekly RPC per rendered week. | PERF-1C/1D then PERF-6 |
| PERF-F010 | Coordination | CONFIRMED | Overlapping 8s/15s synchronization loops | `coordinacion.html` contains two recurrent channel/message refresh paths; `lCh()` can itself trigger `lMs()`, amplifying active-chat reads. | PERF-1C/1F then PERF-6 |
| PERF-F011 | Legacy WA | CANDIDATE | Legacy direct pages can independently poll | `admin-whatsapp.html` and `admin-whatsapp-wa3.html` contain their own recurrent polling. Need runtime/navigation proof for current reachability/usage. | PERF-1B/1F |
| PERF-F012 | Brain / KronIA | CANDIDATE | Realtime + unconditional REST fallback on same audit stream | `cerebro.html` opens Supabase Realtime on `aos_log_auditoria` while also polling the same audit stream every 8s, plus a separate 30s connectivity read. The REST fallback is not conditioned on WebSocket failure in CURRENT source. | PERF-1B/1C/1F |
| PERF-F013 | Brain / KronIA | CANDIDATE | Separate 15s proactive polling chain | `checkProactiveEvents()` runs every 15s; initial pass queries latest IDs from sales/agenda/leads in parallel, then subsequent cycles query new sales and conditionally agenda/leads. | PERF-1B/1C/1E |
| PERF-F014 | Studio | UNKNOWN | Recurrent unauthorized background query conflicts with hibernation contract | Fresh live API logs on 2026-08-24 still show `aos_studio_contenido?...estado=eq.PROGRAMADO...` returning HTTP 401 at ~60s cadence. CURRENT `server.js` registers Studio only when `AOS_STUDIO_BACKGROUND_ENABLED=true`, at 120s cadence; the canonical Studio Hibernation doc says default OFF and no query while OFF. Live table currently has 0 rows / 0 PROGRAMADO. Current source and live cadence therefore do not reconcile. | PERF-1B/1D/1F |
| PERF-F015 | CI / Control Plane | CONFIRMED | Global CURRENT doc edits trigger unrelated heavy domain workflows | REV-F6 workflows include global lock/portfolio/memory files in PR path filters. ASC-PERF documentation changes therefore fan out into unrelated suites. The ASC-PERF Audit 360 run on head `284f983...` waited without executing and ended `cancelled`, leaving no certifiable scanner output while unrelated workflows were also triggered/cancelled. | PERF-1B control-plane map then PERF-8 |
| PERF-F016 | Shell lifecycle | CANDIDATE | Timer cleanup does not prove cleanup of all recurrent resource classes | Shell captures/clears panel-created intervals, but MutationObservers, listeners, WebSockets, Service Workers, fetch monkey patches and recursive async loops require independent teardown proof. | PERF-1F |
| PERF-F017 | Runtime patches | CANDIDATE | Multiple global `window.fetch` monkey patches may form layered runtime behavior | CURRENT source contains several fetch wrappers/shims across Calls, Revenue, Auth/Security and WA modules. Ordering/teardown/consumer scope must be mapped before performance or auth changes. | PERF-1B/1F |
| PERF-F018 | Agents | CONFIRMED | Due-agent execution amplifies one scheduler decision into multiple DB reads/writes | Production has 9 active cron agents and 55 active tasks. The minute dispatcher reads all cron agents, then for each due agent reads its active tasks. Same stats window contains `227` broad `aos_agente_tareas.*` reads, `407` `aos_execute_agent_query` calls, `1,195` agent status update shape calls, `1,151` `aos_agente_logs` inserts, plus domain RPCs such as `fn_dante_alertar_leads_alto_valor` (`123`) and `aos_estado_bases` (`123`). This proves execution fan-out, but does not classify the business tasks themselves as unnecessary. | PERF-1D/1E then PERF-5 |
| PERF-F019 | Shell global runtime | CANDIDATE | Logged-in shell keeps global per-user polling independent of active panel | CURRENT `app/public/app.html` starts ADMIN `pollAgentFeed` every 15s and `pollNotifications` every 30s, plus ADMIN refresh hook every 60s. `pollAgentFeed` directly reads `aos_agentes`. No `visibilitychange` guard is present in CURRENT shell source. Dynamic user-session cost still needs browser proof. | PERF-1C/1F |
| PERF-F020 | Database structural backlog | CANDIDATE | Supabase advisor reports structural performance debt outside amplification root cause | Read-only performance advisors report many unindexed foreign keys, multiple permissive RLS policy warnings on core tables, many currently-unused indexes and one confirmed duplicate-index warning on `aos_cia_admin_sessions`. These are PERF-7 inputs only; no index/policy mutation is justified from advisor output alone. | PERF-7 after call reduction |

## Triage examples — avoid false positives

Not every short interval is a network defect.

- `notification-center-s15.js` runs `patchPanels` every 1s, but current implementation mainly discovers/patches DOM functions and guards already-patched functions. It is a performance candidate for DOM overhead, not evidence of one network request per second.
- `f4-revenue-ops.js` combines a MutationObserver and 1.2s `patchSales` timer, but that recurring function is primarily UI patching; any network consequence must be traced separately.
- Brain audio/VAD intervals are local audio/DOM computation and must not be grouped with network polling merely because their cadence is short.
- `app/public/app.html` also has 1s clock/turn/break timers that are DOM-only and are not counted as network amplification.

This distinction is mandatory for the static scanner and future CI rules.

## Baseline snapshots

`pg_stat_statements_info.stats_reset = 2026-08-22 00:01:09.895151+00` remains unchanged.

### Audit 360 start snapshot

- WA actor-shaped statement: `39,593` calls, ~`1,173,429 ms` total, ~`29.64 ms` mean;
- notification claim-shaped statement: `23,498` calls, ~`569,830 ms` total, ~`24.25 ms` mean;
- broad WA conversation read shape: `13,030` calls;
- Product Resolution admin-shaped RPC: `2,814` calls, ~`444,991 ms` total, ~`158.13 ms` mean;
- agent cron `SELECT *`: `1,563` calls, ~`28,819 ms` total, ~`18.44 ms` mean;
- advisor panel-shaped RPC: `701` calls, ~`328,093 ms` total, ~`468.04 ms` mean.

### Online-loop rebaseline — 2026-08-24

Captured around `2026-08-24 15:09 UTC` / `10:09 America/Lima` against the same stats reset:

- notification claim-shaped statement: `56,485` calls, ~`894,013 ms` total, ~`15.83 ms` mean;
- WA actor-shaped statement: `39,593` calls, ~`1,173,429 ms` total, ~`29.64 ms` mean;
- broad WA conversation read shape: `13,030` calls;
- agent cron `SELECT *`: `3,770` calls, ~`52,236 ms` total, ~`13.86 ms` mean;
- Product Resolution admin-shaped RPC: ~`2,922` calls, ~`454,454 ms` total, ~`155.53 ms` mean;
- advisor panel-shaped RPC: `701` calls, ~`328,093 ms` total, ~`468.04 ms` mean;
- `aos_ticker_mkt` shape: ~`76` calls, ~`101,502 ms` total, ~`1,335.55 ms` mean;
- `aos_panel_admin`: `74` calls, ~`77,388 ms` total, ~`1,045.78 ms` mean.

The unchanged WA actor count versus strongly growing notification/agent counts is evidence that permanent server background traffic is currently a higher idle priority than active WA UI traffic. It does not downgrade the already-confirmed WA design defects.

## Agent scheduler inventory — 2026-08-24

There are 9 active cron agents:

- `analista`: every 4h, 8 active tasks;
- `analista_mkt`: daily, 4 active tasks;
- `archivista`: daily, 3 active tasks;
- `cartero`: several scheduled hours/day, 24 active tasks;
- `centinela`: every 30m, 4 active tasks;
- `guardian`: twice/day, 4 active tasks;
- `monitor`: hourly, 6 active tasks;
- `planificador`: weekly, 1 active task;
- `resumidor`: daily, 1 active task.

The scheduler nevertheless performs its broad cron-agent discovery every minute. Optimization must preserve due-time semantics while reducing idle discovery/payload and unnecessary execution fan-out.

## Current control state

- Production application/database mutation by ASC-PERF: **0**.
- `main` mutation by ASC-PERF: **0**.
- Supabase project: `ACTIVE_HEALTHY` at latest read-only check.
- Branch-only Audit 360 tooling: active.
- `ASCENDA ASC-PERF Audit 360` latest exact-head run: `CANCELLED` without certifiable scanner execution; requires self-hosted runner availability for R1.
- Online investigation continues under `ASCENDA_PERFORMANCE_ONLINE_LOOP_CURRENT.md` until the remaining proof genuinely requires a runner/browser execution.
- Remediation phases PERF-3+: blocked until Audit 360 has enough evidence to avoid symptom-only fixes.
