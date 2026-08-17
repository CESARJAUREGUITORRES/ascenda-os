# Sentinel F10 — Diagnostic Runner — Final Certificate

**Estado:** PRE-MERGE CERTIFIED / G01–G14 PASS  
**Fecha:** 2026-08-17 America/Lima  
**PR:** #235  
**Impact Report:** Issue #233 + `docs/control/SENTINEL_F10_DIAGNOSTIC_RUNNER_IMPACT_REPORT_20260817.md`  
**Functional head certificado antes de este commit:** `9a59163d40bd1e5ed68f4f891fae6bea738f0ecd`

## Alcance
F10 automatiza diagnóstico reproducible de incidentes `SEN-*` mediante self-hosted CI y evidencia sanitizada. Es estrictamente read-only.

No escribe producción, no modifica incidentes, no fusiona/despliega, no ejecuta rollback productivo, no crea fixes y no usa AI/MCP. F11 posee AI triage; F12 remediation.

## Arquitectura certificada
`SEN-* → sanitized request → controlled workflow → self-hosted runner → exact affected-SHA checkout separado → F6/F7/F8 contracts + recent filenames + health evidence → deterministic JSON/Markdown report`

Seguridad:
- workflow GitHub `contents: read` únicamente;
- `persist-credentials:false` en checkouts;
- cero credenciales Supabase/Railway write;
- tooling F10 se ejecuta desde la branch certificada, nunca desde el checkout afectado;
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
Branch run `32055149504` on functional head `9a59163d40bd1e5ed68f4f891fae6bea738f0ecd`:

- `contract-fast` — SUCCESS;
- `diagnostic-zero-cost` — SUCCESS;
- target SHA checkout — EXACT;
- synthetic incident — `SEN-2099-9001`;
- first diagnostic id — `F10-396d072b9dfadfca7585`;
- first report digest — `22588779c2665ca96fd35c1cb2d0fb0992481705b97ffe9b9b78b2a93e584b3a`;
- immediate replay diagnostic id — identical;
- immediate replay report digest — identical;
- byte-for-byte JSON/Markdown compare — PASS;
- marker `SENTINEL_F10_RUNTIME_REPLAY=PASS`;
- marker `SENTINEL_F10_ZERO_COST_DIAGNOSTIC=PASS`.

This is the controlled synthetic end-to-end G14 baseline. `workflow_dispatch` remains available for owner-triggered diagnostics after merge; no public webhook or automatic production trigger is enabled.

## G13 rollback/isolation — PASS
Diff against current main contains only:
- `.github/workflows/sentinel-phase10-diagnostic-runner.yml`;
- `sentinel/diagnostics/f10-contract.json`;
- `sentinel/diagnostics/diagnostic-runner.cjs`;
- `ci/sentinel/phase10_diagnostic_contract.js`;
- `ci/sentinel/phase10_synthetic_request.json`;
- F10 governance/certificate docs.

No migration, DB/RPC, Railway runtime, application server or production frontend file is changed. Logical rollback is removal/disable of the F10 workflow/tooling and therefore leaves F1–F9 intact.

## Infrastructure defects resolved during certification
1. Linux host had no global Node: fixed by disposable container; host unchanged.
2. Full Node image pull was too heavy: replaced by cached `node:22-bookworm-slim` derived image with only Git/CA certs.
3. Container root ownership caused report hash failure and Git safe-directory `UNKNOWN`: fixed by running the diagnostic container with host UID/GID + `HOME=/tmp`.

All fixes preserve read-only scope.

## PR merge-ref compatibility
PR run `32055154914` against the current merge candidate passed both FAST and Linux diagnostic jobs, including exact replay. This validates F10 combined with concurrent `main` changes rather than branch-only behavior.

## G15 terminal sequence
F10 is not marked `100_COMPLETE` until:
1. final certificate commit exact-head F10 + Ascenda CI PASS;
2. PR #235 ready and merged;
3. post-merge F10 + Ascenda CI PASS on `main`;
4. GitHub roadmap + Notion set F10 `CERRADA / 100_COMPLETE`;
5. F11 promoted.

No production DDL or runtime deployment is required for F10 baseline.
