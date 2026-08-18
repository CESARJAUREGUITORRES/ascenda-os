# ASCENDA OS — MEMORY CURRENT

**CURRENT control baseline:** `main@addd14f2a57f06ec54b5ace10e042f4d8b69a85a`  
**Runtime inherited:** S15.3 / `ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**Railway at handoff:** SUCCESS  
**ACTIVE WORKSTREAM:** `CIA-F17/F18-CLOSEOUT`

## Authority

Read in order:

1. root `AGENTS.md`
2. `SECURITY.md`
3. `docs/control/ASCENDA_PROJECT_PORTFOLIO_CURRENT.md`
4. `docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md`
5. selected project CURRENT control / phase
6. exact GitHub + live Supabase/Railway
7. `aos_memory`
8. Notion

Historical `docs/MEMORY.md`, `docs/adn/AGENTS.md`, chat summaries and `aos_codigo_fuente` do not override CURRENT.

## Runtime

`server-phase-s-f17.js → server-phase-s.js → server-f17.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → lower/core`

S15.3 fixes buffered HTTP framing for signed/governed WhatsApp traffic through F17.

## Active project — CIA

- CIA-F0..F16 closed.
- CIA-F17 live 4/6.
- true: contracts, WhatsApp bridge, outbound policy, rollback.
- false: signed webhook replay/idempotency, real allowlisted canary.
- `ready_for_f18=false`.
- handoff live evidence: governed inbound=1, governed send requests/events=0, WA message facts=12.
- PR #261 = evidence-only; do not merge as-is.
- CIA-F18 remains blocked until F17 is 6/6 and ready=true.

## Paused programs

### Sentinel
SEN-F1..F13 100_COMPLETE; regression-only. PR #271 paused maintenance.

### Revenue
REV-F1..F4 closed. REV-F5 paused: 1000/15498 staged, 3950 clusters, 0 members, 0 previews, 7675 patients. No canonical mutation.

### WhatsApp
WA0/WA2/WA3 closed; WA1=98%, WA4=70%, WA5–WA8 pending. Project execution paused while CIA owns the lock.

### KronIA
K0 closed; K1–K8 pending. PR #94/#175 closed evidence-only. Fresh K1 starts from then-CURRENT and reuses CIA-F15 canonical registry/policy artifacts.

### Migration governance
#238 is owner-scoped history parity. #250 is reproducible pre-history baseline. Neither is an independent concurrent feature workstream.

## Lock sequence

`CIA-F17/F18 → Revenue F5/F7 → WhatsApp WA1/WA8 → #250 baseline → KronIA K1/K8 → final cross-program certification`

## Institutional rules

- one HIGH/CRITICAL mutable workstream globally;
- Zero-Cost DB runner reserved to that workstream;
- exact CURRENT revalidation before every merge/certification;
- runtime activation != phase completion;
- sibling-project PASS is input evidence only;
- Notion updated last;
- old green CI never certifies a stale branch.
