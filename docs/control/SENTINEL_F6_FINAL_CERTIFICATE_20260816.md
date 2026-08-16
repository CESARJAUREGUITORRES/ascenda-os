# Sentinel F6 — Final Certificate

**Phase:** F6 — Business Health & Silent Failure Invariants  
**Status:** `100_COMPLETE` candidate pending final exact-head merge gate  
**Date:** 2026-08-16 (America/Lima)  
**Baseline:** `main@81da6ceb18ed35cca8acb0ac68b90dc6e9ed8aae`  
**Implementation mode:** `aggregate-read-only`  

## Scope certified

F6 adds a provider-neutral business-health layer capable of detecting silent functional failures even when HTTP availability and Sentry error monitoring remain green.

The baseline covers exactly four critical domains:

1. `CALL_CENTER` — correlated lead/backlog/activity stall.
2. `SALES` — same-scope source vs Sales Intelligence consistency.
3. `WHATSAPP` — accepted outbound without provider status progression.
4. `EMAIL` — governed configuration plus recent send/webhook progression.

F6 emits sanitized signals only. Persistent incidents belong to F8; notifications belong to F9.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| F6-G01 Recovery | PASS | GitHub contracts + live Supabase schema/function metadata verified for 4 domains |
| F6-G02 Privacy | PASS | aggregate-only allowlist; sensitive/unapproved key negative test |
| F6-G03 Call Center | PASS | synthetic correlated stall produces DEGRADED/INCIDENT only with backlog + active advisers + operating window |
| F6-G04 Sales | PASS | source-present/gateway-empty → INCIDENT; same-scope divergence → DEGRADED |
| F6-G05 WhatsApp | PASS | accepted-without-progress → DEGRADED/INCIDENT by age |
| F6-G06 Email | PASS | governed config + recent horizon + provider-event stall; child warning alone does not trigger incident |
| F6-G07 Valid empty | PASS | legitimate zero activity does not automatically become an incident |
| F6-G08 Cross-platform | PASS | Windows FAST + Linux Zero-Cost disposable Node fixtures |
| F6-G09 Live aggregate preflight | PASS | aggregate-only production reads; no patient/contact rows returned |
| F6-G10 Exact-head CI | PASS on implementation head `cc3024ce...`; final certificate head must rerun before merge |
| F6-G11 Scope | PASS | branch diff contains only Sentinel engine/contract/tests/docs/workflow; no `app/` modifications or DB migration |
| F6-G12 Closure | PENDING final exact-head PASS → merge → post-merge PASS → Notion |

## Live aggregate preflight

### Call Center

Observed on 2026-08-16:

- active adviser-coded users: 10;
- leads for the business date: 0;
- calls for the business date: 0;
- no eligible backlog evidence was present.

**Decision:** `UNKNOWN / NO_ELIGIBLE_BACKLOG`, not an incident. Zero calls alone is not failure evidence.

### Sales

Same-scope 2026 comparison:

- direct source count: `1299`;
- Sales Intelligence aggregate count: `1299`;
- `hasData=true`;
- count match: `true`;
- data through: `2026-08-15`.

**Decision:** consistency signal `HEALTHY`.

### WhatsApp

- accepted outbound without later progression: `0`;
- stalled >=15 minutes: `0`;
- stalled >=60 minutes: `0`.

**Decision:** provider-status progression signal `HEALTHY`.

### Email

Initial aggregate scan found 12 historical sent records without matching provider event. Treating that entire historical set as current health would have produced a false incident.

F6 v1.1 therefore applies a 1,440-minute current-health horizon.

Recent aggregate evidence:

- sends inside 24h: `1`;
- recent sends without provider event: `1`;
- unmatched age: approximately 20h at observation time;
- governed `CONFIG_HEALTH` was not verified by the aggregate database query.

**Decision:** current Email state is `UNKNOWN / EMAIL_CONFIG_EVIDENCE_INCOMPLETE`, not an inferred incident. Historical unmatched records outside the current-health horizon do not affect live health.

## False-positive protections certified

F6 explicitly rejects these unsafe shortcuts:

- `0 sales = incident`;
- `0 calls = incident`;
- `legacy child EMAIL_SERVICE_ROLE_NOT_CONFIGURED = email down`;
- `old unmatched Email records = current outage`;
- `missing telemetry = healthy`.

When context/evidence is insufficient, Sentinel emits `UNKNOWN`.

## Privacy boundary

The invariant engine accepts only approved aggregate primitive fields (`boolean`, `number`, `null`) per domain.

It rejects or forbids:

- patient/contact identifiers;
- names;
- DNI;
- phones;
- email addresses;
- WhatsApp/email content;
- request bodies;
- prompts;
- authorization material;
- cookies;
- tokens/API keys;
- service-role keys;
- passwords/secrets.

Signal evidence is aggregate-only and contains no identifying payload.

## Architecture boundary

F6 does **not**:

- create database objects;
- change Supabase data/schema;
- change Railway configuration;
- modify ASCENDA business runtime;
- persist `SEN-*` incidents;
- send Telegram alerts;
- auto-remediate;
- depend on Sentry as its data model.

## CI evidence

Implementation head:

`cc3024ce7c8fa155b893462efb9b2b462b4bfe1e`

Push workflow:

- `Sentinel F6 Business Health Certificate` run #8: **SUCCESS**.

PR #206 workflow:

- `Sentinel F6 Business Health Certificate` run #9: **SUCCESS**.
- `contract-fast`: SUCCESS.
- `synthetic-fast`: SUCCESS.
- `synthetic-linux`: SUCCESS using disposable `node:22-alpine` on `ASCENDA-ZERO-COST-V2`.

The Linux runner does not need a permanent Node installation; the Node container is read-only against the workspace and destroyed after validation.

`Ascenda CI` for the PR is also required to complete successfully before merge.

## Final decision

F6 is functionally ready for `100_COMPLETE`. The closure becomes authoritative only after:

1. this terminal certificate/roadmap head reruns exact-head checks successfully;
2. PR #206 is merged;
3. post-merge F6 and Ascenda CI remain green on `main`;
4. Notion is updated last.

After that, **F7 — Release, Deploy & Correlation Layer** becomes the only next Sentinel phase.
