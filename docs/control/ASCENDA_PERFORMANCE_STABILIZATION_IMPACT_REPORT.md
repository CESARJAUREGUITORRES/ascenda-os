# ASCENDA OS — ASC-PERF IMPACT REPORT

**Project / phase:** `ASC-PERF-STABILIZATION / PERF-0..PERF-10`  
**Objective:** eliminate systemic read/request amplification, reduce unnecessary egress/DB load, preserve functional realtime behavior, and enforce recurrence prevention before feature work resumes.  
**Entry main:** `ae0448d0cb56a3df91e92f9c28b8250cdc0ecad8`  
**Risk:** HIGH overall; CRITICAL for any auth/session/2FA, SECURITY DEFINER/RLS/GRANT, outer runtime-chain or shared-wrapper change.

## Code/runtime

Likely mutable surfaces after audit freeze include:

- `app/public/wa-native-panel.js`;
- `app/public/wa-multiagent-final-panel.js`;
- `app/public/wa-shell-integration.js`;
- directly reachable WA legacy pages after consumer proof;
- `app/server-wa3.js` / `app/server-wa3-v2.js` / Phase-S wrappers where duplicated auth/bootstrap/queue/presence fan-out is proven;
- `app/server-f17.js` and notification dispatch runtime;
- agent scheduler/runtime sources;
- `app/public/rev-prc1-product-resolution-center.js` and governed lightweight status path;
- `app/public/admin-home.html`;
- `app/public/calls.html`;
- `app/public/coordinacion.html`;
- `app/public/asesor-coord.html`;
- `app/public/caja.html`;
- performance CI/contracts and CURRENT governance docs.

Exact files may change after PERF-1. No file is authorized for mutation merely because it appears in this candidate list.

## Data / RPC / triggers

Potential affected read contracts include:

- WA actor/bootstrap/inbox/messages/queue/team/presence RPC/views;
- notification claim/complete RPCs;
- Product Resolution admin/status RPCs;
- agent state/log/task tables;
- admin/advisor dashboard RPCs;
- schedule/calendar RPCs;
- residual top statements identified after amplification reduction.

Any new/changed SQL contract must use a versioned migration, preserve security boundaries, and pass local schema/pgTAP/lint/authorization checks.

## Consumers / dependencies

Cross-domain consumers include:

- admin and advisor shell users;
- WhatsApp native/multiagent UI;
- push notifications;
- call center and schedule views;
- Sales/Product Resolution;
- coordination/internal messaging;
- Caja;
- agent runtime;
- Sentinel/Sentry observability;
- Railway server chain.

A performance patch cannot be certified by endpoint success alone; affected consumer flows require regression smoke.

## Security / roles / sensitive data

Performance work must not:

- cache privileged data across users/roles;
- bypass token/2FA validation;
- move service credentials to browser code;
- weaken RLS/ACL/SECURITY DEFINER contracts;
- expose patient/financial payloads through new shared stores without existing authorization;
- convert server-side authenticated state into browser-trusted authority.

Any auth/session/2FA or shared runtime-wrapper modification is CRITICAL and requires explicit owner authorization before production mutation.

## Tests

Minimum program gates:

- syntax/static checks for every changed runtime;
- per-domain UI/runtime contracts;
- recurrence/ownership performance contracts;
- hidden-tab and in-flight overlap tests for recurrent readers;
- auth/role positive and negative tests where governed APIs are touched;
- Zero-Cost Supabase local + pgTAP/lint for SQL/RPC/RLS changes;
- matched before/after call-rate and payload measurements;
- production read-only preflight;
- canary role/panel where feasible;
- post-deploy regression for WA, notifications, Sales/Product Resolution, Call Center/admin, coordination and Caja as affected.

## Rollback

Rollback is patch-scoped, not program-monolithic.

Preferred sequence for synchronization changes:

1. introduce shared snapshot/store additively;
2. migrate one consumer;
3. validate canary;
4. disable old reader only after subscriber parity;
5. preserve a short-lived kill switch/fallback that does not run concurrently;
6. rollback by re-enabling the previous owner and disabling the new subscriber path;
7. remove legacy/fallback only after production certification.

Worker cadence/backoff changes must preserve a configuration path to previous certified cadence during canary. SQL changes must be backward-compatible where possible and versioned so the prior runtime remains functional during rollback.

Do not bundle WA ownership consolidation, notification worker changes, dashboard RPC rewrites, DB indexes and auth/session changes in one deployment.

## Portfolio-lock impact

ASC-PERF owns the single HIGH/CRITICAL mutable lane until its exit gate. WhatsApp Revenue Hub V2 and other mutable programs remain paused/recoverable. Read-only investigation and narrowly scoped regression can continue without competing releases.

## Initial measurable success criteria

Targets to validate/finalize during PERF-0/2:

- >=70% reduction in avoidable repeated calls in targeted recurrent paths;
- one declared read owner per certified resource;
- zero recurrent `select=*` in governed hot loops without exception;
- zero N+1 recurrent fan-out in governed hotspots;
- zero duplicate canonical + legacy poller for the same read model;
- downward matched-window API request and egress slope;
- no security weakening;
- no functional regression in affected critical flows.

These are program targets, not automatic 100% certification conditions. Exact SLOs/budgets are frozen in PERF-2 from measured baseline.
