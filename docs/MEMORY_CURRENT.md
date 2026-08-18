# ASCENDA OS — MEMORY CURRENT

**Use this file before `docs/MEMORY.md`.**  
**Captured:** 2026-08-17 20:03 America/Lima  
**GitHub baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`

## Authority

Current continuity is recovered in this order:

1. `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. project-specific CURRENT Control Maestro / phase checkpoint
6. GitHub branch/PR/checks + live Supabase/Railway state
7. `aos_memory`
8. Notion visual tracker

`docs/MEMORY.md` and `docs/adn/AGENTS.md` describe earlier generations of ASCENDA and are historical context unless a CURRENT source explicitly adopts a rule from them.

## Runtime CURRENT

Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Runtime chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core runtime`

Do not assume `node server.js` is the Railway entrypoint.

## Project portfolio

### Sentinel

- F1–F13: `100_COMPLETE`.
- Status: frozen/regression-only.
- Do not reopen because another program changes runtime unless Sentinel evidence actually regresses.

### Commercial Intelligence & Audience OS V3

- F0–F16: closed.
- F17: live 4/6 gates; F17 is now in the production runtime chain after S15.2.
- Missing F17 gates: signed webhook/replay and real allowlisted canary.
- F18: pending.
- This is the first feature project released after portfolio realignment.

### Revenue Data & Intelligence

- F1–F4: closed.
- F5: active historically but paused by portfolio lock; live = 1000/15498 staged, 3950 provisional clusters, 0 members, 0 previews.
- F6/F7: pending.
- F5 canonical patient mutation remains forbidden before provenance + preview + human approval.

### WhatsApp Revenue Hub

- WA0, WA2, WA3: closed.
- WA1: 98%, missing real signed Meta canary/outbound allowlist evidence.
- WA4: 70%, infra/model routing present; real Meta inbound + sales playbook/tool policies/evals remain.
- WA5–WA8: pending.
- The prior state with both WA1 and WA4 `En curso` is considered a scheduling defect. Only one phase may resume when the WhatsApp portfolio lock is granted.

### KronIA V2

- K0: closed.
- K1: first implementation phase but stale historical branches/PRs are evidence-only.
- K2–K8: pending.
- CIA F15 Tool Registry / Agent Registry SHADOW / Policy Gate are canonical reusable inputs.
- KronIA must not build an incompatible second registry.
- Fresh K1 begins from CURRENT only after upstream portfolio locks complete.

## Cross-program maintenance

- #238 = migration history parity. Owner-scoped; no blind replay/history rewrite.
- #250 = reproducible pre-history schema baseline. Separate from feature projects.
- Neither issue authorizes concurrent DB-heavy work while another workstream owns the lock.

## Global execution order

`CONTROL_REALIGNMENT → CIA F17/F18 → Revenue F5/F7 → WhatsApp WA1/WA8 → #250 baseline → KronIA K1/K8 → final cross-program certificate`

## Learned rules institutionalized

1. One repo does not mean one project.
2. One active phase per project was insufficient; ASCENDA now requires one active HIGH/CRITICAL workstream globally.
3. Shared Zero-Cost DB runner is serialized by project ownership, not merely by GitHub queue order.
4. A runtime wrapper added by another program changes the baseline for every later CRITICAL branch.
5. Historical green CI does not certify a stale branch.
6. Runtime activation does not equal phase completion (`F17` is the current example).
7. Live DB beats old Notion counts (`F5` is the current example).
8. Closed programs such as Sentinel remain regression-only; do not rebuild them during unrelated work.
9. Project-specific evidence may be reused as an input contract, but closing one project never automatically closes another.
10. Notion is updated last and must never carry two active phases in the same project.

## Current lock

`CONTROL_REALIGNMENT`

No new HIGH/CRITICAL feature/data mutation should start until the portfolio-control PR is reviewed/merged and the trackers/memory are reconciled.
