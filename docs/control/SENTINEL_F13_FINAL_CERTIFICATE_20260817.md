# Sentinel F13 — Hub, System Map & Final Certification

**Estado:** PRE-MERGE CERTIFIED / POST-MERGE PENDING  
**Fecha:** 2026-08-17 (America/Lima)  
**Riesgo:** HIGH  
**PR:** #252  
**Impact Report:** `docs/control/SENTINEL_F13_HUB_IMPACT_REPORT_20260817.md`  
**Functional head certificado:** `a52fa75ece1112db104cc3a4d8a28b1561cc4b79`

## Resultado funcional

F13 entrega el Hub final de Sentinel dentro de ASCENDA con proyección pública de topología sanitizada, drill-down `dominio → componente → capability`, incidentes `SEN-*`, estados `HEALTHY/DEGRADED/INCIDENT/CRITICAL/UNKNOWN`, correlación técnica sanitizada, controles owner/admin y política no-false-green.

La topología pública deriva de `SENTINEL_SYSTEM_REGISTRY_V1.json` y cubre las 34 capabilities F2 sin publicar `db_relations`, RPC internos, dependencias, paths, hosts ni secretos.

## Seguridad / privacidad

- Hub live restringido por Auth V3 + `PASSWORD_2FA` mediante `aos_sentinel_owner_actor_v1`.
- RPC F13 `aos_sentinel_owner_hub_v1(text,integer)` es `SECURITY DEFINER`, `STABLE`, `search_path=''` y read-only.
- navegador usa únicamente anon key pública + app token fuerte; no existe `service_role` en browser.
- topology JSON público contiene solo taxonomía owner-safe.
- timeline live expone solo `event_type` + `occurred_at`; no stack traces/payloads.
- UI usa `textContent`, no `innerHTML` para datos remotos.
- missing/stale/unavailable evidence → `UNKNOWN`; nunca false-green.
- no auto-remediation, auto-merge ni deploy desde F13.

## Resilience / portability

Certificado por `phase13_hub_resilience_test.js`:

- Sentry unavailable → no rompe Hub / evidencia dependiente no se marca HEALTHY.
- Kuma unavailable → availability no false-green.
- Collector unavailable → freshness ausente produce UNKNOWN.
- Sentinel Core unavailable → Hub fail-closed/UNKNOWN.
- provider/fixture alternativo bajo el mismo contrato produce modelo determinista.

## Evidencia CI — functional head

PR #252 merge context con head `a52fa75ece1112db104cc3a4d8a28b1561cc4b79`:

- Sentinel F13 Hub Final Certificate run `32076979482`: PASS.
  - `hub-fast`: PASS.
  - `hub-zero-cost`: PASS.
  - `hub-db-zero-cost`: PASS, incluido compile/ACL/canary/rollback/reapply PostgreSQL aislado.
- Ascenda CI `32076979501`: PASS.
- Sentinel F9 regression `32076979446`: FAST + Linux Zero-Cost PASS.

## Producción — read boundary

Proyecto Supabase: `ituyqwstonmhnfshnaqz`.

- migración live autoritativa: `20260817203504 sentinel_f13_owner_hub`.
- `aos_sentinel_owner_hub_v1` presente, `SECURITY DEFINER`, `search_path=''`.
- llamada live con token inválido: `ok=false / SENTINEL_OWNER_2FA_REQUIRED` — fail-closed PASS.
- preflight live: existe al menos una sesión owner/admin activa con assurance `PASSWORD_2FA`; no se extrajo ni expuso token alguno.
- el canary positivo de authorization/read se ejecuta en DB Zero-Cost aislado. La herramienta conectada bloqueó correctamente la creación de una sesión sintética transaccional en producción; no se intentó evadir ese control.

La cadena auth positiva de producción reutilizada por F13 es el boundary F9 ya certificado; F13 no crea un segundo mecanismo de autenticación.

## Gate matrix pre-merge

| Gate | Control | Estado |
|---|---|---|
| G01 | Impact Report HIGH governance-first | PASS |
| G02 | F2 topology lineage / 34 capabilities | PASS |
| G03 | public topology privacy allowlist | PASS |
| G04 | no-false-green state contract | PASS |
| G05 | owner/admin Auth V3 + 2FA boundary | PASS |
| G06 | sanitized incident/timeline projection | PASS |
| G07 | browser no service-role / no remote innerHTML | PASS |
| G08 | Sentry/Kuma/Collector/Core resilience | PASS |
| G09 | provider/fixture portability | PASS |
| G10 | FAST exact functional head | PASS |
| G11 | Linux Zero-Cost exact functional head | PASS |
| G12 | DB Zero-Cost compile/ACL/canary/rollback/reapply | PASS |
| G13 | Ascenda CI exact functional head | PASS |
| G14 | F9 regression | PASS |
| G15 | production migration/read boundary preflight | PASS |
| G16 | certificate-head exact recheck | PENDING |
| G17 | PR merge-ref after certificate | PENDING |
| G18 | merge with expected-head | PENDING |
| G19 | post-merge F13 + Ascenda CI + F9 | PENDING |
| G20 | production Hub asset/shell smoke | PENDING |
| G21 | GitHub roadmap + Notion alignment | PENDING |

## Cierre pendiente

F13 todavía no se declara `100_COMPLETE` en este documento. Solo tras G16–G21 se actualizará este certificado a terminal y Sentinel baseline podrá declararse `CERRADA / 100_COMPLETE` para F1–F13.
