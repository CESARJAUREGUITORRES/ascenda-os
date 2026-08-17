# Sentinel F12 — Safe Remediation Loop — Final Certificate

**Estado:** CERRADA / 100_COMPLETE  
**Fecha:** 2026-08-17 (America/Lima)  
**Impact Report:** `docs/control/SENTINEL_F12_SAFE_REMEDIATION_IMPACT_REPORT_20260817.md`  
**Riesgo:** CRITICAL  
**PR de implementación:** #244  
**Merge:** `a82089b3cf40bbc8546b6c98bb8f6b48512933c5`

## Scope certificado

F12 convierte evidencia validada `SEN-* → F10 → F11` en un candidate fix verificable sin crear una ruta de mutación productiva automática.

Flujo certificado:

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

## Evidencia funcional y exact-head

Head funcional: `e7d6ed7b05286885ffac663f6530ffe5ce80c71a`.

- F12 Certificate `32063873662`: FAST PASS + Linux Zero-Cost PASS.
- Ascenda CI `32063873475`: PASS.
- markers:
  - `SENTINEL_F12_CONTRACT=PASS`
  - `SENTINEL_F12_NO_PROD_WRITE=PASS`
  - `SENTINEL_F12_NEGATIVE_BOUNDARY=PASS`
  - `SENTINEL_F12_REMEDIATION_E2E=PASS`
  - `SENTINEL_F12_REPLAY_ROLLBACK=PASS`
  - `SENTINEL_F12_STATIC_BOUNDARY=PASS`

Head con certificado pre-merge: `89d9887bbfa9b340b3b90e496beddd6b878743cf`.

- F12 Certificate `32064239491`: FAST PASS + Linux Zero-Cost PASS.

## Candidate PR canary

Synthetic incident: `SEN-2099-9201`.

Candidate branch: `fix/sentinel-f12-canary-sen-2099-9201`.
Candidate commit: `f4306d91a811aa37ecd06c1b1d5b8ff6ace58171`.
Candidate PR: **#243**, DRAFT.
Diff: un único archivo allowlisted `sentinel/remediation/fixtures/synthetic-target.txt`, `retry_budget=2 → 3`.
F12 PR run `32064051908`: FAST PASS + Linux Zero-Cost PASS.

Resultado del human gate: PR #243 fue **CLOSED / NOT MERGED**. No hubo deployment ni mutación productiva. Esto prueba que un incidente puede llegar a PR validado y detenerse antes de integración.

## Implementation PR / merge-ref

PR #244 `feat(sentinel): F12 Safe Remediation Loop`.

- head exacto: `89d9887bbfa9b340b3b90e496beddd6b878743cf`;
- F12 PR run `32064409164`: FAST PASS + Linux Zero-Cost PASS;
- Ascenda CI PR run `32064409124`: PASS;
- PR marcado READY únicamente después de ambos gates;
- merge ejecutado con `expected_head_sha=89d9887bbfa9b340b3b90e496beddd6b878743cf`;
- merge commit: `a82089b3cf40bbc8546b6c98bb8f6b48512933c5`.

## Post-merge

Sobre `main@a82089b3cf40bbc8546b6c98bb8f6b48512933c5`:

- F12 post-merge `32064580020`: FAST PASS + Linux Zero-Cost PASS;
- Ascenda CI post-merge `32064579939`: PASS.

No se detectó ruta de escritura productiva, auto-merge o auto-deploy añadida por F12.

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
| G15 | certificado-head exacto + implementation PR merge-ref | PASS |
| G16 | merge con expected-head | PASS |
| G17 | post-merge F12 + Ascenda CI sobre main | PASS |

## Cierre

**F12 = CERRADA / 100_COMPLETE.**

Safe Remediation queda certificada para candidate fixes y PRs bajo gates. Ninguna ruta puede auto-fusionar o auto-desplegar HIGH/CRITICAL; producción conserva aprobación humana explícita. F13 Sentinel Hub/System Map queda habilitada para promoción.
