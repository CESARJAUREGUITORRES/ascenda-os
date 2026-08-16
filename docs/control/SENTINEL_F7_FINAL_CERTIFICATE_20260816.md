# Sentinel F7 — Final Certificate

**Phase:** F7 — Release, Deploy & Correlation Layer  
**Status:** `100_COMPLETE` candidate pending terminal exact-head merge gate  
**Date:** 2026-08-16 (America/Lima)  
**Baseline:** `main@c1a857fc515397ad9b9b6dcbadc6e53df30341`  
**Implementation mode:** read-only / provider-neutral  

## Scope certified

F7 establishes a correlation layer that can identify the technical version context of a Sentinel signal without asserting unsupported causality.

The baseline correlates:

- release;
- git commit SHA;
- Railway deployment ID;
- Railway environment/service/replica technical metadata;
- F3 `request_id` and `trace_id`;
- sanitized GitHub commit→PR metadata supplied to the engine;
- regression-window deployment candidates;
- latest prior known-good rollback target.

No Railway API/token is required and F7 does not modify production runtime.

## Upstream evidence

### F3

The telemetry contract already provides:

- `service.version`;
- `deployment.environment.name`;
- UUID-v4 `request_id`;
- W3C Trace Context;
- 32-hex `trace_id`.

### F4

The Sentry contract already provides release format:

`ascenda-os@<commit_sha>`

using `RAILWAY_GIT_COMMIT_SHA` as the primary Railway Git source.

### Railway

Railway's current Variables Reference was verified on 2026-08-16. The F7 allowed technical system variables are:

- `RAILWAY_GIT_COMMIT_SHA`;
- `RAILWAY_DEPLOYMENT_ID`;
- `RAILWAY_ENVIRONMENT_NAME`;
- `RAILWAY_SERVICE_NAME`;
- `RAILWAY_REPLICA_ID`.

Human-authored `RAILWAY_GIT_AUTHOR` and `RAILWAY_GIT_COMMIT_MESSAGE` are deliberately not captured.

## Correlation confidence

| Level | Meaning |
|---|---|
| EXACT | deployment ID and commit SHA agree in the same environment/service |
| STRONG | exact SHA/release maps to same-scope deployment; deployment ID absent in the signal |
| WEAK | only time proximity inside the regression window identifies a candidate |
| UNKNOWN | evidence missing, ambiguous, out-of-scope, or contradictory |

## Causality boundary

A deployment correlated to an incident is **not automatically its cause**.

F7 emits:

`causality = NOT_ESTABLISHED`

Temporal-only matches are explicitly marked:

`basis = TEMPORAL_CANDIDATE`

This prevents Sentinel from presenting sequence as proof of causation.

## Rollback target policy

F7 may determine a rollback target only when evidence identifies the latest deployment that is:

- prior to the suspect deployment;
- same environment;
- same service;
- `status=SUCCESS`;
- `health_state=HEALTHY`;
- backed by a valid commit SHA.

If no such deployment exists, target = `UNKNOWN`.

`action_authorized=false` is permanent in F7. Rollback execution belongs to F12.

## Synthetic gate evidence

The F7 fixture proves:

1. fake Railway system env → exact release/SHA/deployment/environment metadata;
2. author/commit-message free text is not ingested;
3. exact signal → `EXACT` correlation;
4. release-only signal → `STRONG` correlation;
5. temporal-only signal → `WEAK`, candidate only, causality not established;
6. contradictory explicit SHA vs release SHA → `UNKNOWN`;
7. request/trace IDs survive as technical identifiers only;
8. same-scope exact change can map to a sanitized PR number;
9. rollback target selects the latest prior known-good deployment;
10. absent prior known-good evidence → rollback `UNKNOWN`;
11. mismatched environment cannot be correlated as exact;
12. unapproved signal keys are rejected.

## Gates

| Gate | Result |
|---|---|
| F7-G01 Recovery F3/F4/Railway | PASS |
| F7-G02 Privacy/free-text exclusion | PASS |
| F7-G03 Safe runtime extractor | PASS |
| F7-G04 Exact SHA/environment/deployment | PASS |
| F7-G05 Request/trace passthrough | PASS |
| F7-G06 GitHub change correlation | PASS |
| F7-G07 Temporal inference labeling | PASS |
| F7-G08 Contradiction → UNKNOWN | PASS |
| F7-G09 Rollback target / never guess | PASS |
| F7-G10 Cross-platform CI | PASS |
| F7-G11 Scope/read-only | PASS |
| F7-G12 Closure | PENDING terminal exact-head PASS → merge → post-merge PASS → Notion |

## CI evidence before terminal docs

Implementation head:

`3c944bab0e022c181e34315b8bd074223502f745`

- push `Sentinel F7 Release Deploy Correlation Certificate` #2: SUCCESS;
- PR #207 `Sentinel F7 Release Deploy Correlation Certificate` #3: SUCCESS;
- PR #207 `Ascenda CI` #2032: SUCCESS;
- Windows FAST contract/synthetic: SUCCESS;
- Linux `ascenda-zero-cost-v2` disposable Node: SUCCESS.

## Scope audit

Pre-terminal diff:

- 7 added files;
- Sentinel correlation code/contract;
- Sentinel CI fixtures/workflow;
- Sentinel control documentation;
- no `app/` changes;
- no database migrations;
- no Railway variable changes;
- no provider credentials;
- no production writes.

## Final decision

F7 is functionally ready for `100_COMPLETE`.

The authoritative closure requires:

1. terminal certificate/roadmap/control head exact checks remain green;
2. PR #207 merge;
3. post-merge Sentinel F7 and Ascenda CI PASS on `main`;
4. Notion updated last.

After that, **F8 — Sentinel Incident Engine (`SEN-*`)** becomes the only next phase.
