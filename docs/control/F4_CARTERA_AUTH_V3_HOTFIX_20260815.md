# F4 Cartera Auth V3 hotfix — 2026-08-15

Status: IN_PROGRESS — FAST materialization PASS — PR gate pending.

## Problem
`admin-cartera.html` still required the Sales Intelligence token scope (`aos_si_token`) even though CURRENT production Cartera is protected by Auth V3 and `aos_cartera_gateway_v2`.

## Fix
- Cartera reads `aos_app_token` only.
- F4 Revenue Operations browser bridge uses `aos_app_token` only; no fallback to `aos_si_token`.
- Cartera and F4 Node parity contracts fail if the SI token scope reappears.

## Safety
- browser/runtime + static-contract change only;
- no SQL migration;
- no production business-data mutation;
- no anonymous/auth bypass;
- no change to Sales Intelligence token semantics;
- F4 financial actions remain Auth V3 + 2FA + panel-gated server-side.

## Evidence before PR
Temporary deterministic materializer executed on `ASCENDA-FAST-01` and passed:
- exact source-shape replacement;
- inline Cartera JS syntax compile;
- Cartera Node UI contract;
- F4 Node UI/runtime contract.

The temporary materializer/workflow were removed; intended runtime diff remains isolated.

## Exit gate
1. PR exact-head Cartera FAST PASS.
2. PR exact-head Phase 4 FAST PASS.
3. Ascenda CI baseline PASS/no relevant regression.
4. Merge to CURRENT main and Railway deploy.
5. Owner fresh-session smoke: open Cartera, filters SI/PL, candidates visible, no fake reconciliation.
6. Confirm Ventas and Sales Intelligence remain green.
7. Continue F4 Importar + Caja + cutover certification.
