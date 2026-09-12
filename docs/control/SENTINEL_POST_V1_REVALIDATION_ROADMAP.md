# Sentinel — Post‑V1 Revalidation & Hub Evolution Roadmap

**Status:** REGISTERED / PAUSED BY GLOBAL PORTFOLIO LOCK  
**Owner:** Sentinel / ASCENDA control plane  
**Historical baseline:** `SENTINEL V1 F1–F13 = 100_COMPLETE` at `main@15de6f0358c53f9088a20d44e579dafae99fa041`  
**Maintenance lane:** PR #271 — `fix/sentinel-v11-current-alignment-20260817`  
**Rule:** this roadmap does **not** reopen F1–F13. It defines the post‑V1 lifecycle and final cross‑system revalidation once the active ASCENDA workstreams finish.

## 1. Objective

Keep Sentinel useful while ASCENDA continues evolving, without competing with active product/data work, and finish with a full cross‑system recertification plus an upgraded Sentinel Hub that distinguishes historical certification from current alignment.

Sentinel therefore operates in two modes:

1. **Regression-only surveillance while ASCENDA evolves** — detect incidents, preserve evidence and revalidate only when a material failure or high-risk change requires it.
2. **Terminal cross-system revalidation** — after database ingestion, database management, WhatsApp, email/SMS and KronIA are complete, absorb the final CURRENT topology and execute the full Sentinel maintenance loop.

## 2. Canonical post‑V1 stages

### R0 — Continuous Surveillance During ASCENDA Buildout

**State:** ACTIVE / regression-only  
**Purpose:** keep the existing Sentinel V1 sensors, incident engine, in-app owner alerts, diagnostics and Hub available while other workstreams are still changing.

Required behaviour:
- preserve F1–F13 baseline certificates by SHA;
- treat missing/stale CURRENT evidence as `UNKNOWN`, never false-green;
- open `SEN-*` incidents for real Sentinel-detectable failures;
- allow incident diagnosis and safe fixes through the existing PR/CI/human-gate flow;
- do not force a full Sentinel recertification after every unrelated commit;
- record material topology/auth/notification/runtime changes for later revalidation.

Exit gate: R0 does not close until R6 closes; it is the continuous watch layer.

### R1 — Database Ingestion Completion Checkpoint

**External prerequisite:** ingestion of the remaining ASCENDA databases is complete and certified by its owning workstream.

Sentinel capture:
- final database inventory relevant to monitored capabilities;
- new/removed schemas, migrations, ingestion jobs and data-health boundaries;
- change-impact map against F2/F3/F5/F6/F8/F10/F13;
- sanitized health invariants only — no PHI/PII payload capture.

Checkpoint gate:
- owning database workstream is closed;
- exact completion SHA/migration frontier recorded;
- no Sentinel-owned P0/P1 unresolved incident blocks progression.

### R2 — Database Management & Governance Completion Checkpoint

**External prerequisite:** management/governance layer for the ingested databases is complete.

Sentinel capture:
- canonical read/write boundaries;
- RLS/auth/service-role boundaries that affect observability or Hub access;
- lifecycle/retention/data-quality invariants;
- management jobs, queues, RPCs and failure modes relevant to silent-failure detection;
- impact map against F1/F3/F6/F8/F10/F12/F13.

Checkpoint gate:
- database management workstream closed with rollback/read-back evidence;
- Sentinel registry has pointers to the final technical sources of truth.

### R3 — WhatsApp Completion Checkpoint

**External prerequisite:** WhatsApp runtime, inbox, send/receive, routing, AI/human handoff, notifications and governance are complete according to the WhatsApp workstream.

Sentinel capture:
- final Railway/runtime chain;
- WhatsApp provider and webhook boundaries;
- inbox/send/receive/AI-router capability map;
- notification-center integration;
- canary and failure families;
- impact map against F2/F4/F5/F6/F7/F8/F9/F10/F13.

Checkpoint gate:
- WhatsApp closeout certified;
- final runtime entrypoint and wrapper chain recorded;
- material regressions either fixed or explicitly tracked.

### R4 — Email + SMS Completion Checkpoint

**External prerequisite:** email and SMS sending/receiving/status/event flows are complete and certified by their owning workstreams.

Sentinel capture:
- provider boundaries and cost controls;
- delivery/bounce/failure/status events;
- queue/retry/idempotency boundaries;
- business-health invariants for silent delivery failures;
- notification routing impact;
- impact map against F1/F3/F5/F6/F8/F9/F10/F13.

Checkpoint gate:
- email and SMS workstreams closed;
- zero unintended pay-as-you-go activation;
- provider secrets remain server-side and out of telemetry.

### R5 — KronIA Completion Checkpoint

**External prerequisite:** KronIA current roadmap/workstream is complete and certified.

Sentinel capture:
- KronIA service/component/capability topology;
- AI/model/agent dependencies that can fail or degrade;
- deterministic vs inferred diagnostic evidence boundaries;
- safe AI-triage/remediation boundaries;
- impact map against F2/F3/F6/F8/F10/F11/F12/F13.

Checkpoint gate:
- KronIA closeout certified;
- observable technical health signals exist without ingesting sensitive business content;
- no automatic remediation is enabled outside F12 policy.

### R6 — Full Cross-System Revalidation + Sentinel Hub V1.2

**Prerequisites:** R1–R5 checkpoint prerequisites are complete and the global serialized release lane releases Sentinel maintenance.

This is the terminal post‑V1 work package.

Required revalidation loop:
1. fetch exact CURRENT `main` and production runtime/schema state;
2. regenerate/rebind the machine-readable CURRENT registry/overlay;
3. generate topology digest and freshness timestamp;
4. compute path/domain → Sentinel phase impact map;
5. re-run the affected phase contracts plus mandatory F4/F9/F13 regressions;
6. run FAST + Linux Zero-Cost + DB rollback/reapply + production smoke where applicable;
7. verify Railway health/runtime chain and Sentry runtime-only preload;
8. verify Supabase Sentinel tables/RPC/auth boundaries and no new Sentinel-owned advisor issue;
9. verify Zero-PHI/PII and cost guardrails;
10. certify `CURRENT_ALIGNED` only on exact SHA/read-back evidence;
11. update Hub V1.2 and Notion last;
12. merge only through serialized lane with expected-head protection.

Exit gate:
`SENTINEL V1 BASELINE = CERTIFIED` **and** `SENTINEL CURRENT = ALIGNED` against the then-current ASCENDA system.

## 3. Sentinel Hub V1.2 — planned capability set

The existing Hub remains the V1 certified owner/admin surface. V1.2 adds a maintenance/control layer; it does not replace the incident engine.

Required panels/status fields:
- `Baseline V1: CERTIFIED` with certified SHA;
- `CURRENT: ALIGNED | REVALIDATING | DRIFTED | UNKNOWN`;
- `current_main_sha`;
- `aligned_to_sha`;
- `last_revalidated_at`;
- topology/registry freshness;
- runtime chain and major dependency summary;
- domain/workstream coverage: Database Ingestion, Database Management, WhatsApp, Email, SMS, KronIA;
- latest checkpoint per domain;
- impacted Sentinel phases for each material change;
- open `SEN-*` incidents and severity summary;
- unresolved Sentinel maintenance findings;
- deferred optional transports such as `F9-T Telegram`;
- sanitized links/references to GitHub evidence and canonical Notion control pages.

Security rules remain unchanged:
- owner/admin only;
- no PHI/PII, message bodies, phone/email, tokens, cookies or secrets;
- no browser service-role key;
- no automatic destructive remediation;
- missing evidence => `UNKNOWN`.

## 4. CURRENT registry/digest automation — planned

R6 must replace manual topology counters with deterministic generation where practical:
- enumerate public/admin Sentinel-relevant surfaces;
- enumerate runtime wrapper/entrypoint chain;
- store stable digest/hash of normalized topology;
- store source SHA and timestamp;
- compare generated digest against the last aligned digest;
- material drift => `REVALIDATING` or `DRIFTED`, never silent success;
- expose freshness/status to Hub V1.2.

## 5. Revalidation policy while R1–R5 are still open

Do **not** perform a full Sentinel recertification after every active workstream commit.

Instead:
- routine unrelated change → record only if materially relevant;
- material topology/auth/notification/runtime change → run targeted regression if safe and useful;
- actual incident → diagnose/fix through Sentinel's existing safe loop;
- workstream closeout → create/update its R1–R5 checkpoint evidence;
- all prerequisites complete → execute R6 full revalidation once against consolidated CURRENT.

This prevents runner churn and stale certifications while retaining meaningful surveillance.

## 6. Backlog after R6

Non-blocking improvements after CURRENT alignment:
- automatic impact-map generator;
- scheduled/triggered topology freshness evaluation;
- CI/GitHub Actions and npm supply-chain hygiene;
- load-based review of Sentinel indexes currently marked unused;
- optional `F9-T Telegram` transport;
- richer owner-safe Hub drill-down and trend views.

## 7. Source-of-truth rule

`GitHub/docs canonical → runtime/schema live → CI/sensor evidence → Sentinel Core → Notion visual`.

Notion mirrors progress and checkpoints but never overrides GitHub/runtime evidence.
