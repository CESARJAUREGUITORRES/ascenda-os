# REV-F6 / F4 Runtime Bridge Regression — Impact Report

**Status:** HOTFIX CANDIDATE / NOT PRODUCTION CERTIFIED  
**Captured:** 2026-08-20 America/Lima  
**Baseline:** `main@85bbe92e68b4c702c0f08546932e69e5a8a2af43`  
**Branch:** `fix/rev-f6-runtime-bridge-regression-20260820`  
**Project / phase:** Revenue regression maintenance over certified REV-F6.1 Patient Commercial 360 V2 + F4 Revenue Operations import compatibility  
**Objective:** restore the certified patient-detail and sales-import flows without reopening legacy browser ACLs or mutating business truth.  
**Risk:** HIGH

## Observed production symptoms

1. Patients search still locates a real patient card, but selecting it can render `No encontrado` instead of the Patient Commercial 360 detail.
2. The legacy Importar ventas modal opens, but the write can fail after confirmation.

## Read-only production evidence

- The reported patient remains present in `aos_pacientes`; no patient-data loss was observed.
- The same patient's canonical identity aliases for CANONICAL_ID, PHONE and DOCUMENT resolve to one canonical patient with `candidate_count=1` and `status=RESOLVED`.
- `aos_paciente_360(text)` remains correctly service-role-only after REV-F6.0 hardening.
- `aos_patient_search_v2` and `aos_patient_commercial_360_v2` remain browser-callable only through their tokenized Auth V3 contract.
- `aos_importar_ventas(jsonb)` remains correctly service-role-only.
- `aos_importar_ventas_preview_v4` and `aos_importar_ventas_v4` remain the tokenized browser contracts.
- The affected owner account is active, admin level 1, PASSWORD_2FA enabled, has `admin-patients`, `admin-sales`, `admin-import-ventas`, and its RRHH row is ACTIVO.

## Root-cause class

The product intentionally closed legacy direct browser RPCs while preserving old UI surfaces through runtime bridges. A stale or delayed shell therefore fails closed when a bridge is absent/stale. In addition, `patients-f6-v2.js` stopped waiting after 240 x 250 ms (~60 s), so a long-lived shell could miss the Patient panel lifecycle even when the bridge asset had loaded.

This is a compatibility/runtime regression, not evidence that certified patient or sales data disappeared.

## Code/runtime change

### Patient Commercial 360

- Remove the 60-second bridge expiry.
- Make the Patient V2 bridge globally idempotent with explicit `waiting` / `installed` state.
- Keep retrying at low frequency until the existing Patients panel runtime (`_rpc`, `render360`, `renderTab`, `PT`) actually exists.
- Advance the service-worker cache-buster for the Patient V2 asset.

### Sales import

- Preserve the normal F4 browser flow: legacy UI request -> `f4-revenue-ops.js` -> preview V4 -> explicit F4 preview approval -> import V4.
- Add a service-worker safety net only for stale shells where the F4 JavaScript bridge did not intercept the legacy request.
- The safety net requires the controlled cached app token and routes only to `aos_importar_ventas_v4`; it never reopens `aos_importar_ventas` to browser roles.
- The existing legacy UI confirmation remains in front of this fallback path; the V4 RPC still performs its server-side preview/validation before delegating to the legacy service-role implementation.

## Data / RPC / triggers

- No migration.
- No RLS/GRANT/REVOKE change.
- No patient merge/enrichment/write.
- No sales write during CI.
- Production sales are mutated only by the pre-existing authorized V4 importer after explicit user action.
- Protected truth expected unchanged by deployment itself: patients, sales, F3 and F4 counts/fingerprints.

## Consumers / dependencies

- `app/public/patients-f6-v2.js`
- `app/public/phase2-service-worker.js`
- F6.1 Patient 360 UI contract
- F4 Revenue Operations UI/runtime contract
- Existing app shell and login-managed `aos-phase2-auth` token cache

No server topology or Railway wrapper change.

## Security / roles / sensitive data

- Legacy `aos_paciente_360` stays browser-closed.
- Legacy `aos_importar_ventas` stays browser-closed.
- No service-role credential is introduced in frontend code.
- Fallback requires Auth V3 controlled app token from the existing service-worker cache.
- Existing admin + PASSWORD_2FA + panel authorization remains authoritative inside V2/V4 RPCs.
- No PHI/PII is added to logs, tests or fixtures.

## Tests

Required before merge/release:

1. JavaScript syntax for service worker + Patient V2 bridge.
2. REV-F6.1 FAST/UI contract must prove the bridge no longer expires after 60 seconds and remains canonical-id based.
3. F4 UI/runtime contract must prove a stale-shell legacy import can only route to tokenized V4 and fails closed without app token.
4. Existing REV-F6.0..F6.7 / Sales Intelligence / F4 regressions as triggered by path ownership.
5. Zero-Cost DB/security regression: legacy Patient 360 remains denied to anon/authenticated; V2/V4 authorization contracts remain unchanged.
6. Production read-only preflight after candidate SHA.
7. Owner smoke after deploy: patient search/detail and sales-import preview/import with a deliberately controlled row/batch.

## Rollback

Code-only rollback:

- revert the hotfix commit/PR and redeploy the prior exact `main` runtime;
- no database rollback is required because this hotfix contains no migration or DDL;
- legacy RPC ACLs must remain closed during rollback;
- if a production import was executed during owner smoke, reconcile it using the existing import batch/audit/deduplication evidence rather than deleting financial rows ad hoc.

## Portfolio-lock impact

This regression maintenance temporarily owns the single HIGH mutable lane as `REV-RUNTIME-BRIDGE-HOTFIX`. REV-F7 remains NEXT / UNBLOCKED but must not start until this regression is either certified and the lock released, or explicitly abandoned with CURRENT restored.

## Certification condition

Do not mark this hotfix `PRODUCTION CERTIFIED` until exact-head CI is green, production read-only preflight passes, deployment is confirmed, the owner reproduces both affected flows successfully, and unrelated Revenue/Sentinel/WA regressions remain green.
