# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / OWNER HANDOFF TO ASC-PERF STABILIZATION  
**Captured:** 2026-08-22 America/Lima  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**ACTIVE LOCK:** `ASC-PERF-STABILIZATION`  
**CURRENT GATE:** `ASC-PERF-0 — GOVERNANCE FREEZE & EXACT BASELINE`  
**NEXT:** `ASC-PERF-1 — RUNTIME CALL MAP 360`

## Owner directive

The owner explicitly prioritized systemic ASCENDA performance stabilization before continuing feature expansion because current read amplification, duplicated synchronization loops and unnecessary recurrent database/API traffic materially interfere with normal application use and continued development.

At most one HIGH/CRITICAL mutable workstream may operate at a time. While ASC-PERF owns the lock:

- unrelated feature/data work remains PAUSED / READ-ONLY / REGRESSION-ONLY;
- no new overlapping runtime pollers, workers or performance-sensitive feature layers are to be introduced;
- no ad-hoc production patching;
- all mutable remediation follows isolated branch, tests, Zero-Cost when applicable, production read-only preflight, canary and exact-head certification;
- documentation/read-only investigation may proceed if it does not create competing DB-heavy work.

Canonical execution contract: `docs/control/ASCENDA_PERFORMANCE_STABILIZATION_CURRENT.md`.

## Previous lock — WhatsApp Revenue Hub V2

`WHATSAPP-REVENUE-HUB-V2` is now **PAUSED / RECOVERABLE**, not closed and not superseded.

Frozen handoff baseline:

- production `main` at handoff: `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`;
- latest merged change at handoff: PR #352, WA-3 session continuity hotfix;
- production runtime chain remains `server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`;
- WA core and Notifications S13–S15.5 remain preserved regression inputs;
- existing WA messages/conversations/events/outbound/routing state must not be reset or re-created for ASC-PERF;
- `auto_routing_enabled`, `ai_send_enabled` and `auto_reply_enabled` remain governed by the WA checkpoint and must not be enabled by performance work;
- when WA resumes it must revalidate from CURRENT rather than assume this frozen baseline is still mergeable/certified.

ASC-PERF may modify WA runtime synchronization only when the change is explicitly a performance stabilization dependency and all WA auth/ownership/send invariants remain protected.

## Other preserved checkpoints

- MKT Integrity / Call Center Loop 6 V2.3: **PAUSED / RECOVERABLE**, prior 0/5 genuine-op terminal gate preserved;
- REV: certified upstream truth preserved; later mutable phases paused;
- CIA / Email / Acquisition: read-only dependency sources unless required by ASC-PERF evidence;
- Sentinel: regression/observability only;
- KronIA: paused except performance evidence on existing runtime;
- migration governance: maintenance only unless required by an ASC-PERF DB optimization gate.

## ASC-PERF entry evidence

Read-only audit before handoff identified cross-domain amplification patterns including:

- multiple WA readers for inbox/messages/team/presence;
- repeated WA actor validation and queue/presence fan-out;
- fixed 4-second notification push claim pump;
- Product Resolution badge using a heavy admin RPC recurrently;
- recurring agent reads broader than required;
- duplicate `aos_panel_admin` / `aos_panel_asesor` consumption within visual refresh paths;
- weekly calendar fan-out;
- coordination/chat overlapping timers;
- directly reachable legacy pollers that can continue independent traffic.

The full root-cause map is not considered frozen until ASC-PERF-1 closes.

## ASC-PERF exit gate

The stabilization lock may be released only when:

1. Runtime Call Map 360 is complete for CURRENT production scope;
2. every recurrent read has a declared owner and performance budget;
3. targeted duplicate/amplified reads are remediated through independently measurable patches;
4. residual hot RPC/queries are remeasured after call reduction and optimized only with evidence;
5. automated Performance Guard CI rejects representative recurrence patterns;
6. production canary proves lower request/egress pressure without functional/security regression;
7. CURRENT performance architecture, ownership registry, budgets and anti-pattern learning are committed;
8. GitHub exact head, live production evidence, `aos_memory` and Notion continuity are reconciled;
9. the next mutable owner is explicitly handed the lock after fresh CURRENT revalidation.

## Immediate execution

Proceed in this order:

`ASC-PERF-0 → ASC-PERF-1 → ASC-PERF-2 → ASC-PERF-3 → ASC-PERF-4/5/6 → ASC-PERF-7 → ASC-PERF-8 → ASC-PERF-9 → ASC-PERF-10`.

No production remediation begins merely because a code smell is known. PERF-0/1 establish the matched baseline and complete recurrent-call inventory first.
