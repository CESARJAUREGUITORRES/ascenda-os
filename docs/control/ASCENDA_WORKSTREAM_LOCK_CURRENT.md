# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV RUNTIME REGRESSION HOTFIX ACTIVE  
**Captured:** 2026-08-20 America/Lima  
**Baseline before hotfix:** `main@85bbe92e68b4c702c0f08546932e69e5a8a2af43`  
**ACTIVE LOCK:** `REV-RUNTIME-BRIDGE-HOTFIX`  
**CURRENT GATE:** `Patient 360 + Sales Import runtime regression / CI + production smoke pending`  
**ACTIVE BRANCH:** `fix/rev-f6-runtime-bridge-regression-20260820`  
**REV-F5:** `PRODUCTION CERTIFIED — 100%`  
**REV-F6.0:** `PASS / CERTIFIED — 100%`  
**REV-F6.1:** `PASS / CERTIFIED — 100% · regression maintenance active`  
**REV-F6.2:** `PASS / CERTIFIED — 100%`  
**REV-F6.3:** `PASS / CERTIFIED — 100%`  
**REV-F6.4:** `PASS / CERTIFIED — 100%`  
**REV-F6.5:** `PASS / CERTIFIED — 100%`  
**REV-F6.6:** `PASS / CERTIFIED — 100%`  
**REV-F6.7:** `PASS / CERTIFIED — 100%`  
**REV-F6 global:** `PRODUCTION CERTIFIED — 100% · certification preserved; runtime regression under repair`  
**REV-F7:** `NEXT / UNBLOCKED by F6, temporarily PAUSED by portfolio lock until hotfix closes`

GitHub CURRENT + Supabase LIVE remain authoritative. The regression does not reclassify certified F6 data contracts as incomplete; it temporarily acquires the single HIGH mutable lane to restore the certified runtime behavior.

## REV-RUNTIME-BRIDGE-HOTFIX — active regression maintenance

Owner-reported symptoms on 2026-08-20:

- Patients search returns the expected patient card but selecting it can render `No encontrado`.
- Importar ventas opens but the legacy write request can fail.

Read-only production preflight found:

- the reported patient still exists in `aos_pacientes`;
- canonical CANONICAL_ID / PHONE / DOCUMENT aliases resolve unambiguously to the same patient;
- legacy `aos_paciente_360(text)` remains correctly service-role-only;
- legacy `aos_importar_ventas(jsonb)` remains correctly service-role-only;
- Patient V2 and Sales Import V4 tokenized contracts remain present;
- the owner admin account remains active, PASSWORD_2FA, RRHH ACTIVO and authorized for `admin-patients` + `admin-import-ventas`.

Root-cause class: **runtime compatibility bridge drift/staleness**, not deleted patient/sales truth. A concrete defect was found in `patients-f6-v2.js`: it stopped waiting after ~60 seconds, allowing long-lived shells to miss the Patients panel lifecycle. A secure stale-shell fallback is also being added so the old import request can only route through `aos_importar_ventas_v4` with the existing controlled app token; legacy browser ACLs remain closed.

Impact/rollback: `docs/control/REV_F6_RUNTIME_BRIDGE_REGRESSION_IMPACT_20260820.md`.

Closure requires exact-head F6.1 + F4 runtime CI, read-only production invariants, deploy, owner smoke of both reported flows, and then release of `REV-RUNTIME-BRIDGE-HOTFIX`. Until then do not start REV-F7 or another HIGH/CRITICAL lane.

## REV-F6.7 terminal certification — preserved upstream baseline

PR **#319** merged with `expected_head_sha=ccb788cb9aabbe72688c7a9656f7142b78dd4ad2` to `main@04f4da5d363cf6b80777b5a5e89c5ed4d1d9f70d`.

The code-bearing technical exact-head `bf2ca5406735ce32f00015d7a7654d731eadc623` completed **10/10 SUCCESS**:

- Ascenda CI **#2730**
- REV-F6.0 **#68**
- REV-F6.1 **#68**
- REV-F6.2 **#47**
- REV-F6.3 **#38**
- REV-F6.4 **#33**
- REV-F6.5 **#25**
- REV-F6.6 **#19**
- REV-F6.7 **#2**
- Sales Intelligence Phase 1 **#157**

The later terminal evidence commit `ccb788cb...` adds only certificate/snapshot documentation and does not alter runtime code, migrations, business data, ACL logic or analytical semantics.

## Supabase LIVE terminal state before regression hotfix

Applied F6.7 migration:

- `20260821013922 rev_f6_7_ui_acceptance_gateway_v1`

Protected truth after F6.7 merge:

- patients **7,694**
- sales **1,299**
- F3 **406**
- F4 **162**

Current certified fingerprints before hotfix:

- F6.0 `d8a86d5787ffeaee436eabbbff502d51`
- F6.1 `cd313998c5b5b38d5cb9e2f08882b826`
- F6.2 `d977b9669b9e741e8785cd863caaf9c2`
- F6.3 `4d4f22d764a43da965caa65f864d9a0f`
- F6.4 `5c0879041eb8d21e29a3407a8197935b`
- F6.5 `7534bdd97182593788d0a8b0e980ac1d`
- F6.6 `a1959bb7bc39034efab2657607c5a45d`

Sales Intelligence V3 LIVE certified baseline:

- 2026 billed amount **S/ 561,889.27**
- transactions **1,299**
- executive revenue coverage **100%**
- confidence **HIGH**
- freshness **CURRENT**
- sample size **1,299**
- core execution **37.533 ms** under the **1,000 ms** gate

Security / transport baseline that must remain true:

- `/api/f4/sales-intelligence-read` same-origin transport preserved
- admin + 2FA authority preserved
- invalid token returns `UNAUTHORIZED`
- V2 compatibility base browser-closed and service-role-only
- raw V3 browser-closed
- governed compatibility gateway browser-callable through the existing protected flow
- read-only semantics preserved
- no patient/sale/F3/F4/F5 business mutation by the hotfix deployment itself

Historical transactional revenue remains:

- 2024: `value=null / NO_CERTIFIED_SOURCE`
- 2025: `value=null / NO_CERTIFIED_SOURCE`

`NO_CERTIFIED_SOURCE != zero` remains non-negotiable.

Sentinel terminal health baseline remains **9 OK + 1 UNKNOWN + 0 DEGRADED + 0 BROKEN**. The only UNKNOWN is `SEN-DQ-F5-005 DUPLICATE_PROFILE_DRIFT` because the requested duplicate-profile telemetry is not materialized; missing telemetry must never false-green.

Certificate: `docs/control/REV_F6_7_FINAL_CERTIFICATION_CERTIFICATE_20260820.md`  
Snapshot: `docs/control/REV_F6_7_FINAL_CERTIFICATION_SNAPSHOT_20260820.json`

## Handoff rule after hotfix

If the regression hotfix closes successfully, release `REV-RUNTIME-BRIDGE-HOTFIX`, preserve `REV-F6 — PRODUCTION CERTIFIED — 100%`, and return `REV-F7 — NEXT / UNBLOCKED` as the next Revenue gate.
