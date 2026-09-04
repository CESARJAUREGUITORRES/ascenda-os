# P0 #457 — Auth outage / DB pressure incident — 2026-09-03

Status: ACTIVE — WA-L10 paused; AUTO_OFF; kill switch engaged; CANARY NOT AUTHORIZED.

## Proven timeline

- WA-L10/L11 introduced no production runtime implementation before the outage. Between merged WA-L9 and the P0 lock, the main-line changes were governance/docs and a CI contract adjustment.
- Production then entered a broad PostgreSQL/PostgREST degradation window with 504 responses, statement timeouts and idle-in-transaction terminations. Auth V3 and 2FA depend on the same project and became unavailable.
- The login boundary also synchronously reconciled the Resend private vault before canonical Auth V3. P0 #457 PR #458 removed that transient single point of failure without bypassing 2FA and restored the canonical logo/password visibility UX.

## Pressure evidence

Production is already a mixed operational workload. Historical pg_stat_statements includes material cost from advisor/admin panels, Call Center identity/action reads, notifications and analytics.

During L8/L9 certification, cold audit/readback work overlapped this workload. `aos_wa_l8_security_status_v1()` mixes safety controls with several global COUNT(*) scans and one production invocation reached approximately 10.6 seconds. A global L7 cost reconciliation readback also reached approximately 1.8 seconds.

This violates the P0 #432 separation principle for production certification: a safety deploy/readback must be bounded and must not run global audit aggregation synchronously against live clinic traffic.

## Hypothesis explicitly disproved

The old `trg_refresh_llammap` foreground materialized-view refresh trigger is NOT present in production. `aos_llamadas` currently retains the governed-write guard, commercial guard, manual-agenda cleanup, audit and sync-key triggers only. `aos_refresh_llammap()` remains available for explicit cold refresh.

## Remediation

1. PR #458 / merge `13d508d586423668f1c55df2b380920c8a5fa1b9`: Auth resilience + login UX, no timer/polling and no timeout increase.
2. Add `aos_wa_l8_safety_status_v2()` and `aos_wa_l9_safety_status_v2()` as service-role-only bounded production certification surfaces.
3. Keep legacy L8/L9 global-count status functions as COLD_AUDIT_ONLY; never invoke them as synchronous deploy/prod readbacks.
4. Safety v2 uses singleton control rows plus existence probes only. Production EXPLAIN of the equivalent L8 safety query: ~9 ms execution, 10 shared buffer hits, zero reads.
5. No change to autonomous authority, routing, booking, patient/sales ledgers, 2FA, statement_timeout or browser polling.

## Closure gates

- exact-head CI including WA-L8/WA-L9 + Performance Guard + Audit 360;
- apply additive migration to PROD;
- bounded safety readback under existing timeout;
- Railway exact-line health/login asset readback;
- real owner + Wilmer login/2FA smoke;
- observe DB/API for recurrence before releasing the P0 lock.
