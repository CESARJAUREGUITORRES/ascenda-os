# Sentinel F12 — Safe Remediation Loop — Final Certificate

**Estado:** PRE-MERGE CERTIFIED / READY AFTER EXACT-HEAD + MERGE-REF  
**Fecha:** 2026-08-17 (America/Lima)  
**Impact Report:** `docs/control/SENTINEL_F12_SAFE_REMEDIATION_IMPACT_REPORT_20260817.md`  
**Riesgo:** CRITICAL

## Scope certificado

F12 convierte evidencia validada `SEN-* → F10 → F11` en un candidate fix verificable sin crear una ruta de mutación productiva automática.

Flujo:

`SEN-* → diagnostic_id F10 → F11 triage audit digest/evidence → remediation request → deterministic plan → isolated sandbox → targeted tests → Zero-Cost/security gate → candidate PR DRAFT → human gate → canary/rollback cuando aplique → producción únicamente tras autorización explícita`

## Invariantes

- `production_mutation=false` en la baseline F12.
- `auto_merge=false` y `auto_deploy=false`.
- branch/base SHA explícitos y candidate branch distinta de `main`.
- máximo 5 archivos y patch total acotado.
- roots allowlisted: `app/`, `sentinel/`, `ci/`, `docs/`.
- `.git/`, `.github/`, `supabase/migrations/`, `.env*`, llaves/certificados, `AGENTS.md` y `SECURITY.md` bloqueados por el engine baseline.
- path traversal, repo escape y symlink escape fallan cerrado.
- secrets, email, teléfono Perú, DNI y prompt/tool injection se rechazan.
- F11 nunca se interpreta como autorización de producción.
- no network client, arbitrary shell, arbitrary SQL, service-role credential ni deployment capability en `remediation-core.cjs`.
- kill switch fail-closed: `enabled !== true` bloquea cualquier apply/rollback.
- rollback verifica hash posterior y restaura hash previo.

## Evidencia exact-head funcional

Head funcional previo a este certificado: `e7d6ed7b05286885ffac663f6530ffe5ce80c71a`.

- F12 Certificate `32063873662`: FAST PASS + Linux Zero-Cost PASS.
- Ascenda CI `32063873475`: PASS.
- markers:
  - `SENTINEL_F12_CONTRACT=PASS`
  - `SENTINEL_F12_NO_PROD_WRITE=PASS`
  - `SENTINEL_F12_NEGATIVE_BOUNDARY=PASS`
  - `SENTINEL_F12_REMEDIATION_E2E=PASS`
  - `SENTINEL_F12_REPLAY_ROLLBACK=PASS`
  - `SENTINEL_F12_STATIC_BOUNDARY=PASS`

## Candidate PR canary

Synthetic incident: `SEN-2099-9201`.

Candidate branch: `fix/sentinel-f12-canary-sen-2099-9201`.
Candidate commit: `f4306d91a811aa37ecd06c1b1d5b8ff6ace58171`.
Candidate PR: **#243**, DRAFT.
Diff: un único archivo allowlisted `sentinel/remediation/fixtures/synthetic-target.txt`, `retry_budget=2 → 3`.
F12 PR run `32064051908`: FAST PASS + Linux Zero-Cost PASS.

Resultado del human gate: PR #243 fue **CLOSED / NOT MERGED**. No hubo deployment ni mutación productiva. Esto prueba que un incidente puede llegar a PR validado y detenerse antes de integración.

## Security gate

PASS por controles positivos y negativos machine-checkable:

- contract schema/version drift;
- strict request/approval shape;
- base SHA mismatch;
- traversal / absolute path / Windows path;
- `.github/workflows` denied;
- `supabase/migrations` denied en baseline;
- `.env` / secret material denied;
- real Peru phone/DNI denied;
- prompt injection / bypass tests / reveal secrets denied;
- approval bypass denied;
- symlink escape denied en Linux;
- no production/network capability static gate.

## Gate matrix

| Gate | Control | Estado |
|---|---|---|
| G01 | Impact Report CRITICAL previo al código | PASS |
| G02 | remediation contract machine-readable | PASS |
| G03 | base SHA + evidence lineage F10/F11 | PASS |
| G04 | target allowlist / denylist / blast-radius limits | PASS |
| G05 | secrets/PII/PHI scanner | PASS |
| G06 | injection / approval bypass negatives | PASS |
| G07 | path traversal / repo escape / symlink escape | PASS |
| G08 | deterministic plan/replay | PASS |
| G09 | sandbox candidate apply | PASS |
| G10 | rollback hash verification | PASS |
| G11 | kill switch / no-prod-write | PASS |
| G12 | FAST + Linux Zero-Cost exact-head funcional | PASS |
| G13 | Ascenda CI exact-head funcional | PASS |
| G14 | synthetic candidate PR DRAFT + CI + CLOSED NOT MERGED | PASS |
| G15 | certificado-head exacto + implementation PR merge-ref | PENDING |
| G16 | merge con expected-head | PENDING |
| G17 | post-merge F12 + Ascenda CI sobre main | PENDING |

## Criterio de cierre

F12 solo pasa a `CERRADA / 100_COMPLETE` cuando G15–G17 sean PASS. F13 permanece bloqueada hasta ese momento.
