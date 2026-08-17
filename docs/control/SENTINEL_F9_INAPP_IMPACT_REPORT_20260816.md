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
- The application already has a strong app-session token issued by Auth V3 and the service worker injects governed application code into the canonical ASCENDA shell.

## Code impact

Implemented/planned files:

- `sentinel/alerts/f9-contract.json` — transport-neutral v2 policy and non-blocking Telegram debt.
- `sentinel/alerts/alert-router.cjs` — canonical `ascenda-in-app` owner route with explicit Telegram compatibility.
- `sentinel/alerts/alert-dispatcher.cjs` — provider-neutral sanitized owner envelope while preserving Telegram renderer compatibility.
- `sentinel/alerts/ascenda-inapp-transport.cjs` — in-app transport ACK contract.
- `app/public/phase2-service-worker.js` — load the Sentinel owner notification client into the canonical shell without changing the certified backend process chain.
- `app/public/sentinel-inapp-notifications.js` — owner/admin-only UI client; authorization remains server-authoritative in PostgreSQL.
- `ci/sentinel/*phase9*` and dedicated F9-C workflow — deterministic contract/security tests.
- `docs/control/SENTINEL_F9_*`, roadmap/control master — canonical rebaseline/certificate.

## Data impact

Versioned additive migration planned:

- allow `aos_sentinel_alert_dispatches_v1.channel` to accept only `ascenda-in-app` and `telegram-owner`;
- reuse the certified durable F9 dispatch row itself as the in-app delivery record rather than duplicate notification payloads;
- add per-actor read receipts so `READ` remains distinct from transport `DELIVERED`;
- add a service-controlled runtime switch (`aos_sentinel_alert_runtime_v1.inapp_enabled`);
- add strong-session owner/admin feed + mark-read RPCs that internally validate Auth V3 session + 2FA and never trust client role/username;
- add sanitized routing-error telemetry containing only operation + SQLSTATE so F9 faults never abort F8.

No patient/contact/message content, request body, arbitrary evidence, tokens or secrets are persisted by Sentinel F9.

## Consumers

- ASCENDA topbar notification bell / existing notification panel shell.
- Future F13 Sentinel Hub may deep-link from these alerts but F13 remains a separate phase.
- Telegram adapter remains dormant until live credentials are provisioned later.

## Security

- Legacy `aos_notificaciones` is not a Sentinel persistence target.
- New Sentinel support tables are RLS + FORCE RLS with no direct `anon`/`authenticated` table access.
- Internal routing/publish/config RPCs are service-role only.
- Browser-facing owner read/mark-read RPC requires a valid, non-revoked, unexpired `PASSWORD_2FA` Auth V3 token and active admin hierarchy (`nivel_jerarquia <= 2`).
- Browser role claims are UI optimization only and never authorization.
- Fixed `search_path=''` on SECURITY DEFINER functions.
- Telegram secrets remain absent and are not requested or committed.

## Test plan

1. Contract/syntax and sensitive-field allowlist tests.
2. Route P0/P1 immediate to `ascenda-in-app`; P2 digest; P3 panel-only.
3. In-app transport ACK only after durable dispatch persistence succeeds; failure never becomes `DELIVERED`.
4. Exact replay does not duplicate.
5. Durable cooldown, escalation bypass, flapping, maintenance and one recovery remain green.
6. Anonymous/weak/non-admin session cannot read or mark Sentinel alerts.
7. Strong 2FA owner/admin session can list sanitized alerts and mark a dispatch read.
8. No PHI/PII/secrets in schema, fixtures or responses.
9. Rollback/reapply in Zero-Cost staging with F8/F9-B preserved.
10. Production preflight, additive apply, synthetic canary, replay/noise/recovery verification, runtime kill-switch verification.
11. F5/F6/F7/F8/F9 + Ascenda CI regressions.

## Kill switch

The canonical F9-C kill switch is the service-only runtime flag `aos_sentinel_alert_runtime_v1.inapp_enabled`. It can disable in-app publication atomically without disabling Sentinel sensing or F8 incident persistence. Telegram remains separately disabled/unconfigured.

## Rollback

1. Set the in-app runtime flag false.
2. Remove the UI transport injection if needed.
3. Execute the versioned F9-C rollback to remove only new trigger/RPC/support objects; restore the old channel constraint only when no in-app audit rows remain.
4. Verify F8 incident tables and F9-B durable outbox remain intact.
5. Re-run F8/F9 regression fixtures.

## Exit gate

F9 may become `100_COMPLETE` only after the in-app transport has a production synthetic delivery ACK, no duplicate on replay/cooldown, exactly one recovery, authorization negatives, kill switch and rollback/reapply evidence. Telegram is then tracked separately as `F9-T DEFERRED / NON-BLOCKING` and does not block F10.
