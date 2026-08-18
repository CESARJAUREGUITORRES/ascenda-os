# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / cross-program control  
**Portfolio handoff baseline:** `main@addd14f2a57f06ec54b5ace10e042f4d8b69a85a`  
**Runtime baseline inherited:** S15.3 / `ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**ACTIVE LOCK:** `CIA-F17/F18-CLOSEOUT`  
**NEXT LOCK AFTER CIA:** `REV-F5/F7-CLOSEOUT`

## Global rule

At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces: `CIA-F*`, `REV-F*`, `WA-*`, `SEN-F*`, `K*`, `PARITY-*`, `BASELINE-*`, `CONTROL-*`.

While `CIA-F17/F18-CLOSEOUT` owns the lock:

- Revenue, WhatsApp and KronIA are read-only/documentation-only;
- no competing migrations/materializers/canaries/deploys are intentionally started;
- Sentinel is regression-only unless a demonstrated production-safety incident receives an explicit maintenance lock;
- #238/#250 are maintenance lanes and may only run a scoped CIA-required repair, not an independent history project;
- FAST runners may execute isolated CIA/runtime regressions;
- `ASCENDA-ZERO-COST-V2` is reserved for CIA-F17/F18 DB/security/release gates;
- any unrelated `main` merge invalidates pending exact-head CIA certification until revalidated.

## CURRENT runtime

Railway outer command:

`NODE_OPTIONS=--require ./sentinel-sentry-init.cjs node server-phase-s-f17.js`

Effective chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`

S15.3 fixes buffered HTTP framing for signed/governed WhatsApp traffic through F17. Railway was SUCCESS at the control handoff.

## CIA-F17 entry state

Live state immediately before this handoff:

- `contracts_active=true`
- `whatsapp_bridge_validated=true`
- `outbound_policy_validated=true`
- `rollback_verified=true`
- `webhook_replay_validated=false`
- `canary_passed=false`
- `ready_for_f18=false`
- `illegal_send_states=0`
- browser direct governed-table access=false
- governed inbound facts=1
- governed send requests=0
- governed send events=0
- WA message facts=12

Interpretation: S15.3 improved real traffic traversal, but CIA-F17 remains **4/6**. Do not infer replay/idempotency or canary from a single inbound fact.

## CIA-F17 closeout contract

Work only from CURRENT.

1. Re-read `main`, Railway status and live readiness before each mutable gate.
2. Treat PR #261 as `EVIDENCE_ONLY`; do not merge/rebase it wholesale.
3. Inventory unresolved F17 history/parity against CURRENT and preserve only still-needed owner scope.
4. Run F17 isolated DB/history replay/security/rollback using the active lock's Zero-Cost runner.
5. Prove authentic Meta-signed webhook traversal.
6. Prove duplicate/replay/idempotency through governed F17 evidence.
7. Execute a real canary only against the explicit owner-approved allowlist; broad send remains OFF.
8. Reconcile requests/events/inbound/provider outcomes and require `illegal_send_states=0`.
9. Re-run rollback/recovery.
10. Re-read `aos_cia_f18_readiness_v1()` and require all six gates true + `ready_for_f18=true`.
11. Only then mark `CIA-F17=100_COMPLETE` and unlock CIA-F18.

## CIA-F18 gate

CIA-F18 cannot start before F17 returns the certified readiness marker (`READY_F18_MULTICHANNEL_CERTIFIED` or equivalent canonical gate) and `ready_for_f18=true`.

F18 must be completed under the same CIA lock before the portfolio transitions to Revenue.

## Paused projects

### Revenue
`REV-F5` remains 1000/15498 staged, 3950 clusters, 0 members, 0 previews at handoff. No ingest/rebuild/apply while CIA owns lock; canonical mutation remains forbidden.

### WhatsApp
WA1=98%, WA4=70%, WA5–WA8 pending. No Meta canary/AI activation/WA5+ project execution while CIA owns lock. CIA may use the shared Meta transport only for CIA-F17's explicitly scoped governed canary; that evidence does not auto-close WA phases.

### KronIA
K0 closed. K1–K8 pending. PR #94/#175 are closed evidence-only. No K1 materialization/cutover while CIA owns lock.

### Sentinel
SEN-F1..F13 remains 100_COMPLETE/regression-only. PR #271 is paused maintenance evidence.

## Runner policy

- Zero-Cost DB runner belongs to CIA while this lock is active.
- unique DB/container/project names per run;
- cleanup on success/failure;
- no production PII/PHI/secrets as fixtures;
- queued/pending = capacity wait, not failure;
- no hosted paid fallback merely to bypass queue.

## Lock transition

The lock may move from CIA to Revenue only after:

1. CIA-F17/F18 exact `main`/runtime captured;
2. live readiness and production evidence reconciled;
3. CIA PRs classified/closed;
4. CI/canary/rollback state recorded;
5. no untracked CIA production mutation remains;
6. GitHub CURRENT docs updated;
7. `aos_memory` updated;
8. Notion updated last;
9. explicit Revenue input contract written.
