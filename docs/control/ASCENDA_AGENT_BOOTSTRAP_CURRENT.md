# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Status:** CURRENT  
**Baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`  
**Captured:** 2026-08-17 20:03 America/Lima

## Mandatory read order

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. selected project's CURRENT Control Maestro / active phase
7. `app/railway.json` + exact runtime files
8. GitHub exact `main`/PR/checks + relevant Supabase live state

Do not use a generic chat summary, `docs/MEMORY.md`, `docs/adn/AGENTS.md`, `aos_codigo_fuente` or old Notion checkpoint as the current production baseline.

## Runtime CURRENT

Railway currently starts:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

`app/server.js` remains part of the lineage but is not the outer entrypoint.

## Workstream lock

**ACTIVE now: `CONTROL-REALIGNMENT`.**

Purpose: finish portfolio/agent/memory/tracker reconciliation before any further HIGH/CRITICAL feature/data work.

**NEXT after control merge: `CIA-F17/F18-CLOSEOUT`.**

Until transition:

- CIA/Revenue/WhatsApp/KronIA feature mutation is paused;
- Sentinel remains closed/regression-only;
- read-only audits and docs are allowed;
- do not launch competing Zero-Cost DB jobs.

## Project snapshot

- Sentinel: F1–F13 100_COMPLETE.
- CIA: F0–F16 closed; F17 4/6 live; F18 pending.
- Revenue: F1–F4 closed; F5 live 1000/15498 staged, 3950 clusters, 0 members/previews; F6/F7 pending.
- WhatsApp: WA0/WA2/WA3 closed; WA1 98%; WA4 70%; WA5–WA8 pending and paused.
- KronIA: K0 closed; K1–K8 remaining; historical K1 branches are evidence-only.

## CIA-F17 input contract when lock is released

- F16 input = `READY_F17_EMAIL_CERTIFIED`, `ready_for_f17=true`.
- F17 live = `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, 4/6.
- true: contracts, WhatsApp bridge, outbound policy, rollback.
- false: signed webhook replay/idempotency, real allowlisted canary.
- PR #265 is already merged and F17 is in the production chain.
- PR #261 predates CURRENT and must not merge as-is.
- begin remaining work from CURRENT, preserving fail-closed/broad-send-off state.

## Certification rule

Never declare `100_COMPLETE` from a percentage, runtime activation, sibling project's PASS or historical CI. Require the selected phase Definition of Done, exact-head, live readiness, security, rollback/recovery, required canary/smoke and final GitHub + `aos_memory` + Notion reconciliation.