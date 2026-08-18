# ASCENDA OS — PROJECT PORTFOLIO CURRENT

**CURRENT control baseline:** `main@addd14f2a57f06ec54b5ace10e042f4d8b69a85a`  
**Runtime inherited:** S15.3 / `ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**ACTIVE PORTFOLIO OWNER:** `CIA-F17/F18-CLOSEOUT`

## Runtime

Railway outer command:

`NODE_OPTIONS=--require ./sentinel-sentry-init.cjs node server-phase-s-f17.js`

Chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`

S15.3 fixed buffered HTTP framing while preserving the topology.

## Program map

| Program | Closed | Remaining | Portfolio state |
|---|---|---|---|
| Sentinel | SEN-F1..F13 | only deferred/maintenance findings | **FROZEN / REGRESSION-ONLY** |
| CIA | CIA-F0..F16 | CIA-F17 4/6; CIA-F18 pending | **ACTIVE** |
| Revenue | REV-F1..F4 | REV-F5/F6/F7 | **PAUSED** |
| WhatsApp | WA0/WA2/WA3 | WA1=98; WA4=70; WA5–WA8 | **PAUSED** |
| KronIA | K0 | K1–K8 | **PAUSED / REBUILD FROM CURRENT** |
| Migration governance | safe owner slices | #238 owner parity; #250 baseline | **MAINTENANCE LANE** |

## CIA active entry state

Live at handoff:

- contracts=true
- WhatsApp bridge=true
- outbound policy=true
- rollback=true
- webhook replay=false
- canary=false
- ready_for_f18=false
- illegal send states=0
- governed inbound=1
- governed send requests/events=0
- WA messages=12

Runtime traversal has improved after S15.3, but F17 is still exactly 4/6 until explicit replay/idempotency and allowlisted canary evidence exists.

PR #261 is evidence-only; remaining work starts from CURRENT.

## Paused inputs

### Revenue
1000/15498 staged, 3950 clusters, 0 members, 0 previews, 7675 canonical patients at control handoff. No concurrent ingest/rebuild/apply and no canonical mutation.

### WhatsApp
WA1 and WA4 are no longer simultaneously active. When WhatsApp receives the lock, WA1 is revalidated/closed first, then WA4 is rebaselined.

CIA may use the same Meta transport for its own explicitly scoped F17 canary; that evidence does not automatically close WA1/WA4.

### KronIA
K0 closed; K1–K8 pending. PR #94/#175 closed as superseded. New K1 starts from then-CURRENT and reuses CIA-F15 canonical registry/policy.

### Sentinel
F1–F13 100_COMPLETE; PR #271 is paused maintenance evidence. Sentinel regressions may be checked, but program scope is not reopened by default.

## Sequential closeout

1. **CIA-F17/F18 — ACTIVE**
2. Revenue F5/F7
3. WhatsApp WA1/WA8
4. #250 reproducible baseline once feature schemas stabilize
5. KronIA K1/K8
6. final cross-program certification

#238 is resolved only as an owner-scoped dependency of the active project; it is not a parallel schema-history rewrite project.

## Handoff requirement

Before CIA releases the lock to Revenue: exact main/runtime, live readiness, PR classification, CI/canary/rollback evidence, no untracked mutation, GitHub CURRENT docs, `aos_memory`, Notion-last update, and explicit Revenue input contract.