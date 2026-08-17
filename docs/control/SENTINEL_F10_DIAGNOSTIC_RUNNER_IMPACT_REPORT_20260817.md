# Sentinel F10 — Diagnostic Runner — Impact Report

**Estado:** PRE-IMPLEMENTATION / REQUIRED FIRST ARTIFACT  
**Fecha:** 2026-08-17 America/Lima  
**Riesgo:** HIGH  
**Fuente previa auditable:** GitHub Issue #233

## Objetivo
Diagnosticar incidentes `SEN-*` de forma reproducible en self-hosted CI usando solo metadata/evidencia sanitizada y sin mutar producción.

## Anti-scope
F10 no escribe producción, no modifica incidentes, no fusiona/despliega, no ejecuta rollback, no crea fixes automáticos y no usa PHI/PII/messages/secrets. AI/MCP pertenece a F11 y remediation a F12.

## Baseline
`SEN-* → sanitized diagnostic request → workflow_dispatch controlado → self-hosted runner → affected-SHA checkout → contracts/fixtures + recent-diff + safe health evidence → JSON/Markdown diagnostic report`

Permisos baseline: `contents: read`; sin PR/deploy/actions write ni credenciales cloud de escritura.

## Data contract
Allowlist: incident_id, severity, status, environment, domain, component, capability, failure_family, signal_count, reopened_count, release, commit_sha, deployment_id, typed evidence refs y timestamps técnicos.

Denylist: patient/paciente, DNI, phone/telefono, email address, message/body/payload, authorization, cookie, token, password, secret y datos clínicos.

Evidence kinds: `CONTRACT_TEST`, `SYNTHETIC_REPRO`, `RECENT_DIFF`, `HEALTH_CHECK`, `RELEASE_CORRELATION`, `DEPENDENCY_STATUS`, `MISSING_EVIDENCE`.

Hipótesis: confidence `SUPPORTED / PLAUSIBLE / WEAK / UNKNOWN`; `causality_confirmed=false` por defecto. Proximidad temporal no prueba causalidad.

## Zero-Cost gates
G01 contract/denylist → G02 planner → G03 synthetic fixture → G04 affected-SHA checkout → G05 read-only permissions → G06 no-production-write scan → G07 domain tests → G08 recent diff → G09 timeout/concurrency/idempotency → G10 sanitized report → G11 Linux Zero-Cost → G12 negatives → G13 disable/remove preserves F1–F9 → G14 synthetic end-to-end → G15 certificate + Notion.

## Exit gate
F10 solo puede quedar `100_COMPLETE` cuando un `SEN-*` sintético genera diagnóstico reproducible, SHA exacto o `UNKNOWN`, reporte sanitizado, replay determinista, timeout/negatives PASS, no existe ruta de escritura productiva, rollback lógico preserva F1–F9 y exact-head/post-merge CI quedan verdes.

## Rollback
Deshabilitar/remover workflow + artifacts. Baseline sin DDL productivo. Persistencia futura requiere Impact Report adicional antes de migration.

## Deuda separada
Supabase migration-history parity sigue como deuda transversal; resolver mediante auditoría completa + `migration repair`, nunca reejecutando DDL dentro de F10.
