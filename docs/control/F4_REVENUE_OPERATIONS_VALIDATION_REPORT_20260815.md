# ASCENDA OS — F4 Revenue Operations Integration V1
## Production Validation Report — 2026-08-15

**Status:** PRODUCTION CERTIFIED — 100%  
**Certification date:** 2026-08-15  
**Production code baseline:** `main` `7bfc2081d2608284c009291b44c4f2bb6def35d4` before documentation-only certification commit.  
**Primary tracking issue:** #138  
**Auth boundary:** Auth V3 + PASSWORD_2FA + panel authorization.  
**Safety rule:** no fake production sale, payment, patient or debt was created for final acceptance.

## 1. Scope certified

F4 integrates the already-certified canonical product layer with Revenue Operations:

- Ventas Admin V4 read/edit boundary;
- canonical product metrics while preserving historical raw descriptions;
- Importar Ventas V4 preview + commit contract;
- Caja V4 tokenized sale path;
- Cartera V2 candidate matching and evidence-link reconciliation;
- strong Auth V3/2FA/panel enforcement;
- controlled retirement of legacy public mutation paths;
- fail-closed recovery contract.

## 2. Owner production canary

On 2026-08-15 the owner completed a fresh login + 2FA and supplied visual evidence that both sensitive Revenue surfaces load in production:

### Cartera Operativa

- panel visible under `ADMIN · 2FA`;
- 162 active cases rendered;
- 162 pending;
- 0 review;
- S/0.00 confirmed balance;
- rows from both San Isidro and Pueblo Libre visible in the live table;
- reminder automation remains blocked.

### Sales Intelligence V2

- panel visible under `ACTIVO · SOLO LECTURA`;
- 2026 YTD/MTD/projection cards render;
- current-month and annual comparison surfaces load.

Backend verification immediately after the screenshots confirmed the latest owner session was `PASSWORD_2FA`, active and non-revoked. `last_used_at` advanced in both `aos_app_sessions_v3` and `aos_cia_admin_sessions`, proving the production backend consumed the real session rather than only rendering cached UI.

## 3. Auth transport incident resolved

The final P0 was not a database authorization defect. Production diagnostics established:

- Auth V3 session issuance was correct;
- app and finance session hashes matched;
- RPC grants were present;
- transactional diagnostics had already proven Cartera and Sales Intelligence RPCs under the anonymous transport role;
- the remaining fault boundary was browser/direct-PostgREST token transport and token continuity.

PR #146 moved read-only Cartera and Sales Intelligence transport to ASCENDA same-origin endpoints while preserving database-side authorization as the authority:

- `POST /api/f4/cartera-read`
- `POST /api/f4/sales-intelligence-read`

The browser sends only the opaque ASCENDA app token to ASCENDA's own origin. `server-f4` forwards `p_token` to the protected RPC using the configured anonymous Supabase transport. No service-role credential is exposed to the browser.

PR #146 exact head `34a7563634bd8c5b4a42b05937de07c4afd5cd39` passed:

- Ascenda CI;
- F4 Revenue Operations;
- Sales Intelligence Phase 1;
- Cartera Phase 2;
- Cartera Phase 2 Hardening;
- WA-1;
- WA-2;
- WA-3.

It was merged to `main` as `7bfc2081d2608284c009291b44c4f2bb6def35d4`.

## 4. Functional contracts

The F4 isolated pgTAP suite contains 38 assertions and rolls back all fixture writes. It certifies:

- strong actor accepted / bad actor rejected;
- Sales Admin V4 secure read;
- raw sale description preserved beside canonical product identity;
- canonical product aggregation, physical units and pack lines;
- tokenized edit and optimistic-lock stale-sale rejection;
- unknown edit fields fail closed;
- Importar preview is read-only;
- Importar preview returns canonical resolution, `REVIEW_REQUIRED` and advance counts;
- preview creates no sales;
- secure import path resolves known products and fails unknown products closed;
- Caja V4 rejects unauthorized calls without creating a sale;
- authorized Caja path is tokenized;
- Cartera candidate lookup creates no payment;
- `PAGO_RECONCILIADO` requires linked evidence;
- evidence-link reconciliation associates existing evidence without creating another payment.

The owner canary was intentionally non-mutating. Production acceptance does not require synthetic business records because the functional write contracts are certified in isolated rollback tests and the final production gate is ACL/cutover integrity.

## 5. Controlled production cutover

After the owner canary passed, migration `f4_revenue_operations_final_cutover_20260815` was applied in production.

The following legacy public mutation functions were revoked from `public`, `anon` and `authenticated`:

- `aos_editar_venta(bigint,jsonb,text,text,text)`;
- `aos_importar_ventas(jsonb)`;
- `aos_grabar_venta_caja(...)`;
- `aos_cartera_reconcile(...)`.

Postflight confirmed `anon_exec=false` and `auth_exec=false` for all four legacy mutations.

The secure replacements remain callable as transport functions and enforce Auth V3 internally:

- `aos_editar_venta_v4(...)`;
- `aos_importar_ventas_v4(...)`;
- `aos_grabar_venta_caja_v4(...)`;
- `aos_cartera_reconcile_v2(...)`;
- `aos_importar_ventas_preview_v4(...)`;
- `aos_sales_admin_gateway_v4(...)`;
- `aos_sales_admin_sale_v4(...)`;
- `aos_cartera_candidates_v2(...)`.

The cutover event is persisted in `aos_security_log` as `F4_REVENUE_CUTOVER`.

## 6. Recovery contract

`supabase/rollbacks/20260814223900_f4_revenue_operations_recovery.sql` is fail-closed.

If an emergency recovery is needed, it:

- revokes the new Revenue mutation paths;
- leaves diagnostic/read-only operations available;
- does **not** restore weak legacy mutation functions;
- records `F4_REVENUE_RECOVERY` in the security log.

Therefore rollback cannot silently re-open the insecure pre-F4 mutation surface.

## 7. Production integrity postflight

Immediately after cutover:

- `aos_ventas`: **1,293** rows;
- `aos_pagos`: **1** row;
- active Cartera cases: **162**;
- Cartera status: **162 `PENDIENTE_RECONCILIAR`**;
- `SALDO_CONFIRMADO`: **0**;
- confirmed balance total: **S/0**;
- Cartera source distribution by linked sale: **70 San Isidro / 53 Pueblo Libre / 39 without derivable sale sede**;
- no case was converted to debt automatically;
- no final-certification synthetic sale/payment/patient/debt was persisted.

The increase in live sales seen during the day is normal production activity and was not generated by certification work.

## 8. Exit-gate decision

F4 exit criteria are satisfied:

- canonical product foundation remains intact;
- owner production canary passed for Cartera and Sales Intelligence;
- real Auth V3 session consumption verified;
- F4 runtime/UI contracts green;
- Cartera hardening and recovery contracts green;
- Importar/Caja/Cartera/Ventas behavior covered by isolated rollback suite;
- legacy public Revenue mutations revoked in production;
- secure V4/V2 transports remain enabled;
- recovery stays fail-closed;
- production counts and Cartera financial state remained stable through cutover.

**Decision: F4 — Revenue Operations Integration V1 = PRODUCTION CERTIFIED — 100%.**

## 9. Next phase unlocked

**F5 — Historical Client & Sales Consolidation + Patient Identity is now the active next phase.**

Entry rule:

1. inventory historical CSV/Excel sources by year and origin;
2. profile columns and data quality before import;
3. normalize non-destructively;
4. resolve patient identity using evidence, never name-only bulk merge;
5. preview duplicates/conflicts and require human approval for ambiguity;
6. import idempotently with provenance;
7. reconcile historical sales against canonical product and Cartera;
8. publish field-coverage and conflict reports before F6 Sales Intelligence 3.0.

F6 remains blocked until F5 produces a certified multi-year patient/sales dataset. F7 remains blocked until F6 and governance/consent gates are satisfied.
