# ASCENDA OS — AGENT BOOTSTRAP CURRENT

**Status:** CURRENT  
**Baseline:** `main@ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**Release:** S15.3 — F17 buffered HTTP framing

## Mandatory read order

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. `docs/MEMORY_CURRENT.md`
6. selected project's CURRENT Control Maestro / active phase
7. `app/railway.json` + exact runtime files
8. GitHub exact `main`/PR/checks + relevant Supabase live state

Historical chat summaries, `docs/MEMORY.md`, `docs/adn/AGENTS.md`, `aos_codigo_fuente` and old Notion checkpoints are not production authority.

## Runtime CURRENT

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 fixes buffered HTTP framing for signed/governed WhatsApp requests through F17 without changing the outer topology.

## Workstream lock

**ACTIVE:** `CONTROL-REALIGNMENT`.

**NEXT:** `CIA-F17/F18-CLOSEOUT`.

Until control transition:

- CIA/Revenue/WhatsApp/KronIA feature mutation is paused;
- Sentinel remains closed/regression-only;
- read-only audits/docs are allowed;
- do not launch competing Zero-Cost DB jobs.

## Project snapshot

- Sentinel: F1–F13 100_COMPLETE.
- CIA: F0–F16 closed; F17 4/6 live; F18 pending.
- Revenue: F1–F4 closed; F5 live 1000/15498 staged, 3950 clusters, 0 members/previews; F6/F7 pending.
- WhatsApp: WA0/WA2/WA3 closed; WA1 98%; WA4 70%; WA5–WA8 pending/paused.
- KronIA: K0 closed; K1–K8 pending; stale K1 branches/PRs closed or evidence-only.

## CIA-F17 input contract when lock is released

- F16 = `READY_F17_EMAIL_CERTIFIED`, ready=true.
- F17 = `IN_PROGRESS_MULTICHANNEL_GOVERNANCE`, ready_for_f18=false.
- true: contracts, bridge, outbound policy, rollback.
- false: signed webhook replay/idempotency, real allowlisted canary.
- S15.2 inserted F17 into the production chain.
- S15.3 fixed buffered webhook framing; live governed inbound facts increased to 1, but replay/canary gates remain false.
- PR #261 predates CURRENT and must not merge as-is.

## Certification rule

Never declare 100_COMPLETE from percentage, runtime activation, sibling PASS, queued/skipped checks or old CI. Require exact-head DoD, live readiness, security, rollback/recovery, required canary/smoke and final GitHub + `aos_memory` + Notion reconciliation.