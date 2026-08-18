# ASCENDA OS — MEMORY CURRENT

**Read before `docs/MEMORY.md`.**  
**CURRENT:** `main@ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**Release:** S15.3 — F17 buffered HTTP framing  
**Railway:** SUCCESS at CURRENT

## Authority order

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. selected project CURRENT control / phase
6. exact GitHub + live Supabase/Railway
7. `aos_memory`
8. Notion

`docs/MEMORY.md` and `docs/adn/AGENTS.md` are historical generations unless CURRENT explicitly re-adopts a rule.

## Runtime

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 keeps the topology and corrects buffered HTTP framing for signed/governed WhatsApp webhooks.

## Portfolio state

### Sentinel
- SEN-F1..F13 = 100_COMPLETE.
- regression-only.
- PR #271 = paused post-cert maintenance evidence.

### CIA
- CIA-F0..F16 closed.
- CIA-F17 live 4/6; CIA-F18 pending.
- true: contracts, WhatsApp bridge, outbound policy, rollback.
- false: signed webhook replay/idempotency, real allowlisted canary.
- `ready_for_f18=false`.
- after S15.3: governed inbound facts=1; governed send requests/events=0; WA messages=12.
- PR #261 = paused/evidence-only; do not merge as-is.

### Revenue
- REV-F1..F4 closed.
- REV-F5 paused by portfolio lock: 1000/15498 staged, 3950 clusters, 0 members, 0 previews, 7675 canonical patients.
- no canonical mutation before provenance + preview + human approval.
- F6/F7 pending.

### WhatsApp
- WA0/WA2/WA3 closed.
- WA1=98%, WA4=70%, WA5–WA8 pending.
- WA1 and WA4 were incorrectly simultaneous `En curso`; both are now paused.
- when WA resumes: revalidate/close WA1 first, then rebaseline WA4.

### KronIA
- K0 closed.
- K1–K8 pending.
- PR #94 and #175 closed as superseded/evidence-only.
- fresh K1 starts from then-CURRENT and reuses CIA-F15 Tool Registry + Agent Registry SHADOW + Policy Gate.

### Migration governance
- #238 = owner-scoped history parity.
- #250 = reproducible pre-history schema baseline.
- neither runs as a competing feature project.

## Global lock

`CONTROL-REALIGNMENT` until canonical control PR #267 is CURRENT and merged.

Next lock: `CIA-F17/F18-CLOSEOUT`.

Queue:

`CONTROL → CIA → Revenue → WhatsApp → #250 → KronIA → final cross-program certification`

## Institutional learning

1. One repo contains several projects; always namespace phases.
2. One active phase per project was insufficient; ASCENDA now has one global HIGH/CRITICAL mutable workstream.
3. Shared Zero-Cost DB runner is serialized by ownership.
4. Runtime wrapper changes invalidate later CRITICAL branches until CURRENT revalidation.
5. Historical green CI never certifies a stale branch.
6. Runtime activation does not equal phase completion.
7. Live Supabase overrides stale Notion counts.
8. Closed Sentinel remains regression-only.
9. Sibling-project evidence is input, not closure.
10. Notion is updated last.
