# F4 — Cartera service-worker 401 hotfix — 2026-08-15

## Owner canary evidence

A fresh owner login with Auth V3 + 2FA succeeded in production, but opening Cartera rendered `Acceso restringido — No fue posible validar Cartera`.

Production API evidence at the same session:

- `aos_verificar_2fa_v3` → HTTP 200.
- `aos_sales_admin_gateway_v4` → HTTP 200.
- `aos_sales_intelligence_gateway` → HTTP 200.
- `aos_cartera_gateway_v2` → HTTP 401 after the service-worker rewrite.
- the active owner session remained `PASSWORD_2FA`, non-revoked and valid.

This excludes owner credentials, 2FA and the canonical Auth V3 session as the primary failure.

## Runtime cause

`admin-cartera.html` already sends the application token in `p_token` to the legacy read name `aos_cartera_gateway` using the normal Supabase public request headers.

After the preceding Auth V3 chain hotfix, production DB already defines `aos_cartera_gateway` as a narrow read-only compatibility alias to `aos_cartera_gateway_v2`.

The service worker still intercepted that request and rebuilt it as a second cross-origin request to `aos_cartera_gateway_v2`. The reconstructed request is redundant and is the remaining boundary associated with the observed PostgREST HTTP 401.

## Fix

- remove only the Cartera read remap/interception from `phase2-service-worker.js`;
- keep identity, Caja and protected-write interception unchanged;
- preserve the DB compatibility alias as the single Cartera read routing authority;
- add F4 and Cartera CI contracts forbidding the service-worker Cartera remap while requiring the Auth V3 DB alias.

## Safety

- no production business data is changed;
- no sale, payment, patient, debt or reconciliation is created;
- no write-path is widened;
- `aos_cartera_reconcile` / V2 reconciliation behavior is unchanged;
- Revenue legacy-write cutover remains blocked until the owner visual canary succeeds.

## Canary after deployment

1. Close the ASCENDA session.
2. Fresh login + 2FA so `registerBridge()` calls `reg.update()` with `updateViaCache:'none'` and activates the new worker.
3. Open Cartera.
4. Expected Supabase public request: `POST /rest/v1/rpc/aos_cartera_gateway` → HTTP 200. The DB alias then routes internally to V2.
5. Validate Todos, San Isidro, Pueblo Libre and one read-only `Revisar` case.
6. Do not save reconciliation during the first canary.

Tracking: F4 final Issue #138.