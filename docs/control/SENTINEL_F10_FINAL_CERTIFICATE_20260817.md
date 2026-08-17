# Sentinel F10 — Diagnostic Runner — Final Certificate

**Estado:** `CERRADA / 100_COMPLETE / G01–G15 PASS`  
**Fecha:** 2026-08-17 America/Lima  
**PR:** #235  
**Impact Report:** Issue #233 + `docs/control/SENTINEL_F10_DIAGNOSTIC_RUNNER_IMPACT_REPORT_20260817.md`  
**Functional head:** `616e401c167dc451ae1d92f53119a22ab03c868b`  
**Merge main:** `45d0d176b1bb5838a2a76fb1f7163a262b13ea9a`

## Alcance
F10 automatiza diagnóstico reproducible de incidentes `SEN-*` mediante self-hosted CI y evidencia sanitizada. Es estrictamente read-only.

No escribe producción, no modifica incidentes, no fusiona/despliega, no ejecuta rollback productivo, no crea fixes y no usa AI/MCP. F11 posee AI triage; F12 remediation.

## Arquitectura certificada
`SEN-* → sanitized request → controlled workflow → self-hosted runner → exact affected-SHA checkout separado → F6/F7/F8 contracts + recent filenames + health evidence → deterministic JSON/Markdown report`

Seguridad:
- workflow GitHub `contents: read` únicamente;
- `persist-credentials:false` en checkouts;
- cero credenciales Supabase/Railway write;
- tooling F10 se ejecuta desde código certificado, nunca desde el checkout afectado;
- affected SHA debe ser 40-hex o queda `UNKNOWN`;
- sensitive keys se rechazan recursivamente;
- evidence refs heredan allowlist F8;
- message/body/payload/secrets prohibidos;
- causality siempre `false` en F10 baseline.

## G01–G12 — PASS
- G01 contract/denylist — PASS.
- G02 planner determinista — PASS.
- G03 synthetic fixture `SEN-2099-9001` — PASS.
- G04 exact affected-SHA checkout — PASS.
- G05 read-only permissions — PASS.
- G06 no-production-write static scan — PASS.
- G07 F6 domain contract evidence — PASS.
- G08 recent diff filenames-only — PASS.
- G09 timeout/concurrency/idempotency — PASS.
- G10 JSON/Markdown sanitized report — PASS.
- G11 Linux Zero-Cost on `ASCENDA-ZERO-COST-V2 / CREACTIVE` — PASS.
- G12 negatives: sensitive input, invalid SHA, unapproved key, query-string evidence ref, revision 0, unknown/missing evidence — PASS.

## G09/G14 runtime replay evidence
Branch run `32055149504`:
- target SHA checkout — `EXACT`;
- synthetic incident — `SEN-2099-9001`;
- diagnostic id — `F10-396d072b9dfadfca7585`;
- report digest — `22588779c2665ca96fd35c1cb2d0fb0992481705b97ffe9b9b78b2a93e584b3a`;
- immediate replay diagnostic id/digest — identical;
- byte-for-byte JSON/Markdown compare — PASS;
- `SENTINEL_F10_RUNTIME_REPLAY=PASS`;
- `SENTINEL_F10_ZERO_COST_DIAGNOSTIC=PASS`.

This is the controlled synthetic end-to-end G14 baseline. `workflow_dispatch` remains available for owner-triggered diagnostics; no public webhook or automatic production trigger is enabled.

## G13 rollback/isolation — PASS
F10 changes only diagnostic workflow/tooling/tests/docs. No migration, DB/RPC, Railway runtime, application server or production frontend file is changed.

Logical rollback = disable/remove F10 workflow/tooling. F1–F9 remain intact.

## Infrastructure defects resolved
1. Linux host had no global Node → disposable container; host unchanged.
2. Full Node image was too heavy → cached `node:22-bookworm-slim` derived runtime with only Git/CA certs.
3. Container root ownership caused report-hash and Git safe-directory failures → diagnostic container runs with host UID/GID + `HOME=/tmp`.

All fixes preserve read-only scope.

## Exact-head / merge-ref certification
- Final pre-merge F10 head `616e401c167dc451ae1d92f53119a22ab03c868b`:
  - F10 certificate run `32055373422` — FAST + Linux SUCCESS;
  - Ascenda CI run `32055376752` — SUCCESS.
- PR merge-ref compatibility run `32055154914` — FAST + Linux SUCCESS.
- PR #235 merged with `expected_head_sha=616e401c...` to `main@45d0d176b1bb5838a2a76fb1f7163a262b13ea9a`.

## G15 post-merge — PASS
On `main@45d0d176b1bb5838a2a76fb1f7163a262b13ea9a`:
- F10 post-merge run `32055537762`:
  - `contract-fast` — SUCCESS;
  - `diagnostic-zero-cost` — SUCCESS;
  - exact affected-SHA checkout — PASS;
  - deterministic diagnostic + exact replay — PASS;
  - report/digest gate — PASS.
- Ascenda CI post-merge run `32055537694`:
  - Runtime baseline — SUCCESS.

No production DDL or runtime deployment is required for the F10 baseline.

## Resultado terminal
**F10 Diagnostic Runner = `100_COMPLETE`.**

Promotion gate:
`F1–F10 = 100_COMPLETE → F11 MCP / AI-Assisted Triage = NEXT / EN CURSO`.
