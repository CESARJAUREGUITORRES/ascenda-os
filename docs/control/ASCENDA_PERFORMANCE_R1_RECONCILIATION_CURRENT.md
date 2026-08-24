# ASCENDA OS — ASC-PERF R1 RECONCILIATION CURRENT

**Status:** R1-A PASS / R1-B MATERIAL RECONCILIATION IN PROGRESS  
**Captured:** 2026-08-24  
**Exact base main:** `70e94da5e9b598e60081b50839ff980afb30dff5`  
**Execution PR:** `#358`  
**Runner:** `ASCENDA-ZERO-COST-V2`

## R1-A certified runner result

`ASCENDA ASC-PERF Audit 360` run `32755453534`, job `97521895511` completed `SUCCESS`.

Runner/runtime evidence:

- self-hosted Linux runner matched correctly;
- Node `v20.20.2` installed by `actions/setup-node@v4`;
- `ASCENDA_ZERO_COST_POLICY=PASS`, `workflows=64`;
- `ASC-STUDIO HARD OFF CONTRACT PASS`;
- Runtime census PASS;
- Census integrity PASS;
- persisted audit artifact removed after validation.

Static census:

- files scanned: `134`;
- lines scanned: `46,935`;
- raw static signals: `2,616`;
- recurrent-network candidate files: `55`;
- literal interval candidates below 5 seconds: `11`;
- broad-read candidates: `63`.

The 55-file count is deliberately conservative and is NOT the defect count. A file enters this set when it combines any recurrent construct with any network primitive; one-shot setTimeouts, local UI timers and unrelated network functions can coexist in the same file.

## Reconciliation rule

Each candidate must be reduced to one of:

- `CONFIRMED_WASTE`;
- `CONFIRMED_BUT_BOUNDED`;
- `JUSTIFIED_LOCAL`;
- `ACTIVE_PANEL_ONLY`;
- `DYNAMIC_PROOF_REQUIRED`;
- `SUPERSEDED`.

No remediation is authorized from scanner count alone.

## Material recurrent set after source reconciliation

### Background/server — confirmed

1. `app/server-f17.js` — fixed 4s notification claim pump. `CONFIRMED_WASTE_WHEN_IDLE`.
2. `app/server.js` — 60s cron-agent discovery with recurrent `select=*`; due-agent work fans out to task reads/RPC or SQL/status writes/log writes. `CONFIRMED_WASTE_IN_DISCOVERY`, business task execution remains semantically valid.
3. `app/server.js` — template/brand/CMP/snapshot cache refresh loops. `CONFIRMED_BUT_BOUNDED`; not first remediation target.
4. Studio scheduler source remains compiled into `server.js`, but production start contract is now HARD-OFF. Live 401 ownership must still be reconciled independently before Studio is certified silent.

### Global shell/user producers — material

5. `app/public/app.html` — admin agent feed 15s + general notification 30s + admin callback 60s; local 1s clocks are excluded. `DYNAMIC_PROOF_REQUIRED`.
6. `app/public/wa-shell-integration.js` — global WA presence heartbeat + focus/online/visibility. `CONFIRMED_DESIGN`; dynamic post-hardening cost required.
7. `app/public/wa-human-alerts.js` — **new material finding**: injected shell script starts automatically and ticks every `2200ms`; it refreshes actor bootstrap at most every 60s and `/api/wa3/inbox?limit=120` on each tick. `CONFIRMED_GLOBAL_PRODUCER`. PR #354 browser coalescing can reduce physical network calls but does not remove this read owner.
8. `app/public/sentinel-inapp-notifications.js` — **new material finding**: global admin/owner feed poll every 15s plus focus refresh. `CONFIRMED_GLOBAL_PRODUCER`; actual live DB/network cost requires dynamic correlation.

### Active-panel producers — confirmed/candidates

9. `app/public/wa-native-panel.js` — 1.5s heartbeat; post-PR #354 network reads are mediated by `wa-performance-hardening.js` TTL/coalescing. `CONFIRMED_LOGICAL_LOOP / DYNAMIC_PHYSICAL_COST_REQUIRED`.
10. `app/public/wa-multiagent-final-panel.js` and V2 companion — additional WA refresh ownership. `CONFIRMED_LOGICAL_LOOP / DYNAMIC_PHYSICAL_COST_REQUIRED`.
11. `app/public/admin-whatsapp.html` — direct legacy page 2.5s visible / 12s hidden. `CONFIRMED_CAPABILITY`, normal-route usage proof required.
12. `app/public/admin-whatsapp-wa3.html` — direct legacy page 3s. `CONFIRMED_CAPABILITY`, normal-route usage proof required.
13. `app/public/agents.html` — independent ~8s/10s/15s/30s active-panel reads. `ACTIVE_PANEL_ONLY / CONSOLIDATION_CANDIDATE`.
14. `app/public/cerebro.html` — Realtime + unconditional 8s REST audit fallback, 15s proactive-event chain and 30s connectivity read. `CONFIRMED_SOURCE / DYNAMIC_COST_REQUIRED`.
15. `app/public/coordinacion.html` — overlapping 8s and 15s channel/message paths, including nested active-message read. `CONFIRMED_WASTE_WHEN_PANEL_ACTIVE`.
16. `app/public/asesor-coord.html` — full `aos_mis_mensajes` snapshot every 8s. `ACTIVE_PANEL_ONLY / CONSOLIDATION_CANDIDATE`.
17. `app/public/admin-home.html` — guarded 60s refresh but same-cycle dashboard model reuse remains candidate. `ACTIVE_PANEL_ONLY / DUPLICATE_READ_CONFIRMED`.
18. `app/public/caja.html` — 60s caja + 300s exchange rate. `CONFIRMED_BUT_BOUNDED`; add lifecycle guard before cadence changes.
19. `app/public/sentinel-hub.js` — 15s hub refresh only while Sentinel panel is active; `sentinel-hub-bootstrap.js` calls `stop()` on navigation away. `ACTIVE_PANEL_ONLY`, not a global leak.

### Scanner false-positive / local categories

20. `app/public/calls.html` — 60s day-boundary interval is local until the date actually changes. `JUSTIFIED_LOCAL`; duplicate initial panel RPC/calendar fanout remains a separate non-timer finding.
21. `app/public/notification-center-s15.js` — 1s interval primarily patches DOM/contracts; do not classify as one network request per second. `JUSTIFIED_LOCAL_PENDING_CPU_TRACE`.
22. `app/public/f4-revenue-ops.js` — short interval/MutationObserver primarily UI patching. `JUSTIFIED_LOCAL_PENDING_CPU_TRACE`.
23. Files entering the scanner set only through one-shot `setTimeout` plus unrelated `fetch`/RPC are not recurrent-network defects until call graph evidence proves recurrence.

## New findings

### PERF-F022 — WA human alerts as global inbox read owner

State: `CONFIRMED`.

`wa-human-alerts.js` is injected into the application shell and calls `start()` at load. With alerts enabled by default it runs a 2200ms timer. It is functionally valuable, but architecturally duplicates WA inbox freshness ownership. It should ultimately subscribe to the canonical WA read/event owner rather than independently polling the inbox.

### PERF-F023 — Sentinel in-app feed as second global notification poller

State: `CONFIRMED_SOURCE / LIVE_COST_PENDING`.

`sentinel-inapp-notifications.js` starts globally for eligible admin/owner sessions and polls `aos_sentinel_owner_feed_v1` every 15s plus focus. This exists independently of the shell notification poll. Future architecture should avoid multiple global notification freshness owners.

## PR #354 reconciliation

`wa-performance-hardening.js` is present before the native WA script in the Phase S app injection and wraps same-origin GETs for:

- `/api/wa3/inbox`: 4s visible / 20s hidden cache;
- `/api/wa3/queue-summary`: 4s / 15s;
- `/api/wa3/team-summary`: 4s / 15s;
- conversation messages: 3.5s / 20s.

It coalesces same-key inflight requests and invalidates after WA mutations/foreground transitions. Therefore pre-PR-354 logical timer rates can no longer be equated directly with physical request rates. R1-C must measure the resulting network rate rather than infer it.

## R1-B status

Material source reconciliation is sufficient to proceed to dynamic measurement, but R1-B is not fully closed until R1-C proves actual physical request ownership/cadence for the global shell and active high-frequency panels.

Next gate: `R1-C — controlled dynamic/browser instrumentation foundation`.
