# ASCENDA OS — MEMORY CURRENT

**Read this before `docs/MEMORY.md`.**  
**Captured:** 2026-08-17 20:03 America/Lima  
**Baseline:** `main@644cb0d0a1290276d9cb5d2a8c8f015b4a24d073`

## Authority

Recover continuity in this order:

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. selected project CURRENT control / phase checkpoint
6. exact GitHub + live Supabase/Railway
7. `aos_memory`
8. Notion

`docs/MEMORY.md` and `docs/adn/AGENTS.md` describe earlier generations and are historical unless CURRENT explicitly re-adopts a rule.

## Runtime

Railway outer command:

`env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js`

Chain:

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core runtime`

Do not infer the outer runtime from old `server.js` documentation.

## Programs

- **Sentinel:** SEN-F1..F13 closed / regression-only.
- **CIA:** CIA-F0..F16 closed; F17 live 4/6; F18 pending.
- **Revenue:** REV-F1..F4 closed; F5 paused at live `1000/15498`, `3950 clusters`, `0 members`, `0 previews`; F6/F7 pending.
- **WhatsApp:** WA0/WA2/WA3 closed; WA1=98%, WA4=70%, WA5–WA8 pending; previously simultaneous active phases are now paused for serialization.
- **KronIA:** K0 closed; K1–K8 pending; stale K1 candidates are evidence-only; fresh K1 must start from CURRENT.
- **#238/#250:** transversal maintenance; do not run as a competing feature project.

## Global lock

Current during this control repair: `CONTROL-REALIGNMENT`.

Next: `CIA-F17/F18-CLOSEOUT`.

Default closeout queue:

`CONTROL → CIA → Revenue → WhatsApp → #250 baseline → KronIA → final cross-program certification`.

## Institutional learning

1. One repository contains multiple projects; never use bare `F17` without namespace.
2. One active phase per project was insufficient; one HIGH/CRITICAL workstream is now active globally.
3. Shared Zero-Cost DB runner is serialized by workstream ownership.
4. Runtime wrappers inserted by one program change the baseline for every later CRITICAL branch.
5. Old green CI does not certify a stale branch.
6. Runtime activation does not equal phase closure — CIA-F17 is the current example.
7. Live Supabase overrides stale Notion counts — Revenue F5 is the current example.
8. Closed Sentinel is regression-only; do not rebuild it during unrelated work.
9. Evidence can be reused as an input contract; closure never transfers automatically between projects.
10. Notion is updated last and must not show multiple active phases for the same paused program.
