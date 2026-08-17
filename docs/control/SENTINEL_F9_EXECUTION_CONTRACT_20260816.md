# Sentinel F9 — Alert Routing, Telegram & Noise Control

**Status:** IN PROGRESS  
**Baseline:** `main@f90542bfa21b7be5e3a306f0d9241c52368fbe19`  
**Branch:** `feature/sentinel-f9-alert-routing`  
**Risk:** MEDIUM for secret-free routing core; HIGH only when live Telegram credentials/delivery are materialized.  

## Objective

Convert F8 `SEN-*` incident state into owner-facing notification decisions without leaking PHI/PII/secrets or creating alert fatigue.

F9 owns notification routing and noise control. It does not diagnose incidents, mutate production, generate fixes or deploy remediation.

## Recovery / live preflight

Read-only production preflight found:

- F8 is authoritative and persisted in production;
- existing ASCENDA integration secret boundary is available server-side;
- `aos_integration_secrets_v1` is FORCE-RLS/service-only by its existing contract;
- Telegram integrations currently configured: `0`;
- active Telegram integrations: `0`;
- Telegram secret references: `0`.

Therefore the first F9 implementation is intentionally **secret-free**. No token or chat ID is invented, committed or requested by browser code.

## Phase split

### F9-A — Routing / noise-control core

Build and certify without live credentials:

- P0/P1 immediate routing;
- P2 grouped digest;
- P3 panel/log only;
- cooldown/dedup;
- severity escalation bypass;
- flapping summary + suppression;
- maintenance windows;
- one recovery notification after a notifiable incident;
- sanitized fixed templates;
- transport interface;
- fake transport;
- explicit `UNAVAILABLE` instead of false `DELIVERED`;
- Windows + Linux self-hosted CI.

### F9-B — Live Telegram materialization

Separate controlled gate after F9-A passes:

- create/identify owner bot outside source control;
- store bot token/chat target only through server-side secret boundary or runtime secret store;
- never make credential browser-readable;
- implement server-side Telegram adapter;
- validate transport with synthetic P3/P2/P1/P0 policy fixtures as appropriate without spamming owner;
- prove no PHI/PII/secrets in rendered message;
- recovery notification canary;
- kill switch;
- rollback/removal of adapter config;
- volume/noise test.

Live Telegram is not considered configured until the transport itself acknowledges a synthetic delivery.

## Canonical routing policy

| Severity | Baseline action | Owner notification |
|---|---|---|
| P0 | IMMEDIATE | yes; bypass maintenance/flapping suppression |
| P1 | IMMEDIATE | yes; cooldown + maintenance/noise control |
| P2 | DIGEST | grouped 15-minute digest |
| P3 | PANEL_ONLY | no Telegram |

Recovery is emitted once for P0/P1/P2 after a prior notifiable route. Exact replay inside cooldown must not resend.

## Flapping

Within a 10-minute window, four status changes activate a 15-minute suppression window. Sentinel emits one sanitized flapping summary, then suppresses repetitive lifecycle noise. P0 bypasses flapping suppression.

## Maintenance windows

Maintenance matching is limited to technical taxonomy:

- environment;
- domain;
- component;
- capability.

P1/P2/P3 expected incidents may be suppressed during a matching active window. P0 is never suppressed by maintenance.

## Privacy contract

Allowed notification content is technical metadata only:

- `SEN-*` ID;
- severity/status;
- environment/domain/component/capability/failure family;
- release/commit/deployment ID;
- signal/reopen counts;
- controlled timestamps;
- digest incident IDs/count.

Forbidden:

- patient/contact names;
- phones/DNI/email addresses;
- WhatsApp/email content;
- request bodies;
- evidence payloads;
- tokens/cookies/auth headers;
- provider secrets;
- arbitrary free text from the incident.

## Delivery truth

A route decision is not a delivery. `DELIVERED` may only be recorded after the transport returns an explicit positive acknowledgement. If Telegram is unconfigured/unavailable, status is `UNAVAILABLE`; Sentinel must not start a delivery cooldown on a failed/unavailable transport.

## F9-A exit gate

F9-A can pass when synthetic tests prove:

1. P0/P1 immediate;
2. P2 grouped;
3. P3 panel-only;
4. repeated P1 suppressed inside cooldown after an acknowledged delivery;
5. failed/unavailable transport is retryable and never false-delivered;
6. P2→P1 escalation becomes immediate;
7. flapping emits one summary then suppresses noise;
8. P0 bypasses maintenance and flapping suppression;
9. recovery emits once;
10. sensitive keys/templates are rejected;
11. same fixtures pass Windows FAST and Linux Zero-Cost runners.

## F9 final exit gate

F9 can close only after F9-A and the live Telegram materialization gate both pass, including real synthetic delivery/recovery evidence and rollback/kill-switch documentation. If owner credentials are not yet available, F9 remains in progress rather than claiming a false green.
