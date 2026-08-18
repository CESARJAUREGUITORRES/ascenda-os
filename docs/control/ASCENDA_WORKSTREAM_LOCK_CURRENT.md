# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / cross-program control  
**Baseline:** `main@ce7ca6ee1326646f22e9f70ef51eb25e7f9d4189`  
**Release:** S15.3 — F17 buffered HTTP framing  
**ACTIVE LOCK:** `CONTROL-REALIGNMENT`  
**NEXT LOCK:** `CIA-F17/F18-CLOSEOUT`

## Global rule

ASCENDA contains multiple programs in one repository. At most **one HIGH/CRITICAL feature/data workstream may mutate ASCENDA at a time**.

Canonical namespaces:

- `CIA-F*` — Commercial Intelligence & Audience OS V3
- `REV-F*` — Revenue Data & Intelligence
- `WA-*` — WhatsApp Revenue Hub
- `SEN-F*` — Sentinel
- `K*` / `K1-*` — KronIA
- `PARITY-*` — #238 migration parity
- `BASELINE-*` — #250 reproducible pre-history baseline
- `CONTROL-*` — portfolio/governance

Bare phase names such as `F17` are prohibited in cross-program control.

## CURRENT runtime

Railway:

`NODE_OPTIONS=--require ./sentinel-sentry-init.cjs node server-phase-s-f17.js`

Chain:

`Phase S F17 → Phase S → F17 → F5 → WA4 → WA3 → WA2 → F4 → lower/core`

S15.3 preserves this topology and fixes buffered HTTP framing for governed/signed WhatsApp traffic. `app/server.js` is not the outer Railway entrypoint.

## Exclusivity

While a workstream owns the lock:

1. other projects are read-only/documentation-only;
2. no competing migrations/materializers/canaries/deploys are intentionally started;
3. FAST runners may execute isolated regression/syntax/UI checks required by the owner;
4. `ASCENDA-ZERO-COST-V2` is reserved to the owner for DB/migration/security gates;
5. a PASS from another project cannot certify the owner;
6. `queued/pending` is capacity wait, not product failure;
7. any unrelated merge that advances `main` invalidates pending exact-head certification until revalidated.

## CONTROL-REALIGNMENT — ACTIVE

Allowed:

- GitHub/Supabase/Railway read-only audit;
- docs/agent/memory/tracker reconciliation;
- stale PR classification;
- no feature/data production mutation.

Exit gate:

- portfolio map + root AGENTS + agent bootstrap + memory reconciled;
- old merge candidates classified/closed where clearly superseded;
- Notion project states serialized;
- `aos_memory` current keys refreshed;
- exact current main/Railway/readiness rechecked;
- explicit CIA-F17 input contract recorded.

## CIA-F17/F18 — NEXT

Live after S15.3:

- contracts=true
- WhatsApp bridge=true
- outbound policy=true
- rollback=true
- webhook replay=false
- canary=false
- ready_for_f18=false
- governed inbound facts=1
- governed send requests/events=0
- WA message facts=12

The inbound fact demonstrates improved traversal but is not a replay/idempotency certificate. Readiness remains 4/6 until explicit evidence flips the live gates.

PR #261 is paused/evidence-only; it predates #265/S15.3 and must not merge as-is.

## Other programs while locked

- `REV-F5`: paused; no ingest/rebuild/apply.
- `WA-*`: paused; no Meta canary, AI activation or WA5+ implementation.
- `K*`: paused; no K1 materialization/cutover; old K1 PR #94/#175 are closed evidence-only.
- `SEN-F1..F13`: closed/regression-only; PR #271 remains draft maintenance unless a production-safety incident warrants reprioritization.
- `PARITY-*` / `BASELINE-*`: read-only analysis only unless the active project explicitly requires a scoped repair.

## Runner policy

### Zero-Cost DB runner

`ASCENDA-ZERO-COST-V2` / `[self-hosted, Linux, X64, ascenda-zero-cost-v2]`

- one active workstream owner;
- unique DB/container/project names;
- cleanup on success/failure;
- no production PII/PHI/secrets in fixtures;
- no billable hosted fallback merely because queued/offline.

### FAST runners

Same-workstream syntax/UI/runtime contracts and required regressions only. They do not replace DB/security gates.

## Resume rule

When a paused project resumes:

1. re-read exact `main`;
2. re-read live Supabase state;
3. classify old branches/PRs: `MERGE_CANDIDATE`, `PAUSED`, `SUPERSEDED`, `EVIDENCE_ONLY`;
4. for HIGH/CRITICAL drift, prefer a fresh branch from CURRENT;
5. never merge solely because historical CI was green.

## Lock transition gate

The lock changes only after exact `main`/runtime, live phase readiness, PR classification, CI/canary/rollback state, GitHub CURRENT docs, `aos_memory`, and Notion are reconciled. If unfinished but safe to pause, record `PAUSED_WITH_CHECKPOINT`.

## Sequential portfolio queue

1. `CONTROL-REALIGNMENT`
2. `CIA-F17/F18-CLOSEOUT`
3. `REV-F5/F7-CLOSEOUT`
4. `WA-1/WA-8-CLOSEOUT`
5. `BASELINE-#250`
6. `K1/K8-CLOSEOUT`
7. `FINAL-CROSS-PROGRAM-CERTIFICATION`

Sentinel remains frozen/regression-only unless a demonstrated Sentinel regression receives an explicit maintenance lock.

## Bootstrap for every new chat/agent

Read root `AGENTS.md` → `SECURITY.md` → `ASCENDA_PROJECT_PORTFOLIO_CURRENT.md` → this lock → declare `WORKSTREAM_ID` → read only that project's CURRENT control → verify GitHub/live Supabase → execute only the next declared gate.
