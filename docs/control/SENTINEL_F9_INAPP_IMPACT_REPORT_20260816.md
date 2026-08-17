# Sentinel F9-C — ASCENDA In-App Owner Alerts Impact Report

**Date:** 2026-08-16 America/Lima  
**Baseline:** `main@24a36b64ca85a856a5640f306435405c0b5d92ac`  
**Branch:** `feature/sentinel-f9-inapp-owner-alerts`  
**Risk:** CRITICAL — authenticated owner/admin read surface + SECURITY DEFINER/RLS changes.  

## Objective

Rebaseline F9 from a Telegram-mandatory exit gate to a transport-neutral owner-notification contract. `ASCENDA_IN_APP` becomes the mandatory production notification transport for F9 closure. Telegram remains implemented as an optional transport boundary but live provisioning is deferred as non-blocking debt `F9-T`.

The change must preserve F8 as the incident source of truth and the existing F9 durable outbox/noise-control semantics. It must not create a second incident engine, a second business-data truth, automatic diagnosis, AI mutation or remediation.

## Current evidence

- F8 is production-certified and owns `SEN-*` incidents.
- F9-A routing/noise control is certified.
- F9-B durable outbox is production-certified.
- Production migrations: `20260817013916 sentinel_f9_alert_outbox` and `20260817014618 sentinel_f9_digest_incident_fk_index`.
- The current F9 database contract hardcodes `telegram-owner` in the durable dispatch channel.
- ASCENDA already renders a notification panel in `app/public/app.html`.
- Legacy `aos_notificaciones` / `aos_log_notificaciones` have RLS disabled and broad browser-role grants in production; Sentinel must NOT persist owner alerts there.
- The application already has a strong app-session token issued by Auth V3 and the service worker injects `X-AOS-App-Token` for governed same-origin APIs.

## Code impact

Planned files:

- `sentinel/alerts/f9-contract.json` — transport-neutral v2 policy and non-blocking Telegram debt.
- `sentinel/alerts/alert-router.cjs` — canonical `ascenda-in-app` route for owner alerts.
- `sentinel/alerts/alert-dispatcher.cjs` — provider-neutral sanitized owner envelope while preserving Telegram adapter compatibility.
- `sentinel/alerts/ascenda-inapp-transport.cjs` — in-app transport contract.
- `app/server-f4.js` — same-origin owner notification API using strong Auth V3 app token; no trust in browser role fields.
- `app/public/phase2-service-worker.js` — inject existing app token into `/api/sentinel/*`.
- `app/public/app.html` — use the existing notification panel shell for Sentinel owner feed when the authenticated user is admin; preserve existing non-Sentinel behavior outside this scope.
- `ci/sentinel/*phase9*` and workflow — deterministic contract/security tests.
- `docs/control/SENTINEL_F9_*`, roadmap/control master — canonical rebaseline/certificate.

## Data impact

Versioned additive migration planned:

- allow `aos_sentinel_alert_dispatches_v1.channel` to accept only `ascenda-in-app` and `telegram-owner`;
- add a dedicated sanitized owner-notification persistence table keyed to durable F9 dispatches;
- add per-actor read receipts so `READ` remains distinct from transport `DELIVERED`;
- add service-only publish RPC used by the in-app transport;
- add strong-session owner/admin feed + mark-read RPCs that internally validate Auth V3 session + 2FA and never trust client role/username.

No patient/contact/message content, request body, arbitrary evidence, tokens or secrets may be stored.

## Consumers

- ASCENDA topbar notification bell / existing notification panel.
- Future F13 Sentinel Hub may deep-link from these alerts but F13 remains a separate phase.
- Telegram adapter remains dormant until live credentials are provisioned later.

## Security

- Legacy `aos_notificaciones` is not a Sentinel persistence target.
- Sentinel persistence tables remain RLS/FORCE-RLS with no direct `anon`/`authenticated` table access.
- Publish/transport RPC is `service_role` only.
- Browser-facing owner read/mark-read RPC requires a valid, non-revoked, unexpired `PASSWORD_2FA` Auth V3 token and active admin hierarchy (`nivel_jerarquia <= 2`).
- Server/UI must not accept role claims as authorization.
- Fixed `search_path=''` on SECURITY DEFINER functions.
- Telegram secrets remain absent and are not requested or committed.

## Test plan

1. Contract/syntax and sensitive-field allowlist tests.
2. Route P0/P1 immediate to `ascenda-in-app`; P2 digest; P3 panel-only.
3. In-app transport ACK only after persistence succeeds; failure never becomes `DELIVERED`.
4. Exact replay does not duplicate.
5. Durable cooldown, escalation bypass, flapping, maintenance and one recovery remain green.
6. Anonymous/weak/non-admin session cannot read or mark Sentinel alerts.
7. Strong 2FA owner/admin session can list sanitized alerts and mark a dispatch read.
8. No PHI/PII/secrets in schema, fixtures or responses.
9. Rollback/reapply in Zero-Cost staging with F8/F9-B preserved.
10. Production preflight, additive apply, synthetic canary, replay/noise/recovery verification, kill-switch verification.
11. F5/F6/F7/F8/F9 + Ascenda CI regressions.

## Kill switch

`SENTINEL_ASCENDA_ALERTS_ENABLED=false` disables the runtime in-app publication/read surface without disabling Sentinel sensing or F8 incident persistence. Telegram remains separately disabled/unconfigured.

## Rollback

1. Disable `SENTINEL_ASCENDA_ALERTS_ENABLED`.
2. Revert app transport/UI integration.
3. Execute versioned F9-C rollback to remove only the new owner-notification/read-receipt objects and restore the dispatch channel constraint to the prior safe state if no non-Telegram rows remain.
4. Verify F8 incident tables and F9-B durable outbox remain intact.
5. Re-run F8/F9 regression fixtures.

## Exit gate

F9 may become `100_COMPLETE` only after the in-app transport has a production synthetic delivery ACK, no duplicate on replay, exactly one recovery, authorization negatives, kill switch and rollback/reapply evidence. Telegram is then tracked separately as `F9-T DEFERRED / NON-BLOCKING` and does not block F10.