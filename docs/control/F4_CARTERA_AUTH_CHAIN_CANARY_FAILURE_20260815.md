# F4 Cartera — canary failure / Auth V3 chain hotfix — 2026-08-15

## Observed owner canary
`Acceso restringido · No fue posible validar Cartera` after a fresh ASCENDA Auth V3 login.

## Root cause
The owner session was valid. The failure was an incompatible double-authentication chain:
1. deployed `admin-cartera.html` calls the legacy read RPC `aos_cartera_gateway`;
2. `aos_cartera_gateway_v2` first validates correctly through `aos_f4_actor(...,'admin-cartera')` / `aos_app_sessions_v3`;
3. the current V2 implementation then calls legacy `aos_cartera_gateway`;
4. the legacy gateway validates through `aos_cartera_actor` / `aos_cia_admin_sessions`, which rejects the valid `aos_app_token`.

## Controlled fix
Branch `fix/f4-cartera-v2-auth-chain-20260815`:
- make `aos_cartera_gateway_v2` self-contained on Auth V3;
- preserve admin + 2FA + explicit `admin-cartera` panel checks;
- make only the old READ gateway name a transitional alias to V2 so stale browser/service-worker assets also work;
- do not widen `aos_cartera_reconcile` or any other legacy write function;
- add Zero-Cost synthetic contract with valid/invalid token checks and San Isidro/Pueblo Libre filters;
- recovery removes the legacy read alias from public execution while keeping V2 Auth V3 available; it never restores the broken V2→legacy auth loop.

## Production safety
No sale, payment, patient, confirmed debt or reconciliation is created by this hotfix. Business reads remain governed; the only expected operational write is session `last_used_at` after successful strong authentication.

## Exit
F4 remains open until exact-head CI is green, the migration is applied, production function definitions are verified read-only, and the owner re-runs the Cartera canary successfully.
