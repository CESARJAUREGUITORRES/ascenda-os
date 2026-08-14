# ASCENDA OS — ZERO-COST CI V2 CHANGELOG

**Fecha:** 2026-08-14  
**Branch:** `infra/zero-cost-ci-v2`  
**Base:** `main` @ `fdc6edb69c3d525b0c2b1c9eac8eef3636ff013d`  
**Riesgo:** MEDIUM (infraestructura CI / sin cambio de runtime productivo)

## Motivo

La cuenta GitHub Free agotó los 2,000 minutos incluidos de GitHub-hosted Actions. El uso facturable visible permaneció en US$0, pero nuevos jobs quedaron bloqueados por el límite incluido.

## Decisión

Adoptar Zero-Cost CI V2:

- self-hosted Linux x64 repo-level;
- label `ascenda-zero-cost-v2`;
- prohibición de hosted runner por defecto;
- no fallback facturable;
- workflows por paths;
- concurrency con cancelación;
- sync histórico manual;
- artifacts mínimos;
- guard automático contra `ubuntu-latest`/`windows-latest`/`macos-*`;
- budget objetivo de additional paid usage = US$0.

## Workflows migrados

- Ascenda CI
- ASCENDA Zero-Cost Staging
- Sales Intelligence Phase 1
- Cartera Phase 2
- Cartera Phase 2 Hardening
- Cartera Phase 2 Final Release
- Sync Supabase → GitHub (legacy/manual)

## Fase 2

La certificación final se amplía para cubrir también los dos hotfixes de Auth posteriores al cutover inicial:

- `20260814163000_p0_auth_audit_trigger_search_path_fix.sql`
- `20260814164500_restore_2fa_email_branding.sql`

El Final Release reproduce en fixture el fallo del audit trigger bajo `search_path=''` y valida el template branded V3 sin restaurar el 2FA inseguro legacy.

## Producción observada antes del CI V2

Validación read-only:

- Auth V3 activo;
- challenges 2FA reales consumidos;
- sesiones `PASSWORD_2FA` activas;
- sesión admin/finance activa;
- un único usuario activo con `admin-cartera` y 2FA;
- 162 filas en bridge Cartera: 123 originadas en venta y 39 en cotización;
- `saldo_confirmado` total = S/0.00;
- legacy login/2FA/abono no ejecutables por `anon`;
- `aos_ventas` sin INSERT directo para `anon` ni `authenticated`;
- branded sender/template presentes en `aos_login_v3`;
- audit trigger referencia `public.aos_log_auditoria` explícitamente.

## Gate restante

Registrar el self-hosted runner en la PC autorizada y obtener checks verdes sobre el SHA final. Hasta entonces no se declara `PHASE 2 — PRODUCTION CERTIFIED 100%`.
