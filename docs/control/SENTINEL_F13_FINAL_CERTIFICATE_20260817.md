# Sentinel F13 — Hub, System Map & Final Certification

**Estado:** `CERRADA / 100_COMPLETE`  
**Fecha:** 2026-08-17 (America/Lima)  
**Riesgo:** HIGH  
**PR funcional:** #252  
**PR paridad:** #255  
**PR terminal smoke/current:** #254  
**PR closeout documental/current:** #263  
**Impact Report:** `docs/control/SENTINEL_F13_HUB_IMPACT_REPORT_20260817.md`  
**Functional head certificado:** `a52fa75ece1112db104cc3a4d8a28b1561cc4b79`  
**Terminal technical merge:** `aacd92148a2a15f12bed7d0e014fb7424bc25415`  
**CURRENT de closeout:** `043b4e454682e13cc0b84e860b90e0a15e8ed0cc` (S15.1 auth-bound notifications)

## Resultado funcional

F13 entrega el Hub final de Sentinel dentro de ASCENDA con proyección pública de topología sanitizada, drill-down `dominio → componente → capability`, incidentes `SEN-*`, estados `HEALTHY/DEGRADED/INCIDENT/CRITICAL/UNKNOWN`, correlación técnica sanitizada, controles owner/admin y política no-false-green.

La topología pública deriva de `SENTINEL_SYSTEM_REGISTRY_V1.json` y cubre las 34 capabilities F2 sin publicar `db_relations`, RPC internos, dependencias, paths, hosts ni secretos.

## Seguridad / privacidad

- Hub live restringido por Auth V3 + `PASSWORD_2FA` mediante `aos_sentinel_owner_actor_v1`.
- RPC F13 `aos_sentinel_owner_hub_v1(text,integer)` es `SECURITY DEFINER`, `STABLE`, `search_path=''` y read-only.
- Navegador usa únicamente anon key pública + app token fuerte; no existe `service_role` en browser.
- Topology JSON público contiene solo taxonomía owner-safe.
- Timeline live expone solo `event_type` + `occurred_at`; no stack traces/payloads.
- UI usa `textContent`, no `innerHTML` para datos remotos.
- Missing/stale/unavailable evidence → `UNKNOWN`; nunca false-green.
- F13 no introduce auto-remediation, auto-merge ni auto-deploy.

## Resilience / portability

`phase13_hub_resilience_test.js` certifica:

- Sentry unavailable → Hub continúa sin declarar evidencia dependiente como HEALTHY;
- Kuma unavailable → availability queda UNKNOWN cuando corresponde;
- Collector unavailable → freshness ausente produce UNKNOWN;
- Sentinel Core unavailable → Hub fail-closed/UNKNOWN;
- backend/fixture alternativo bajo el mismo contrato produce modelo determinista.

## Evidencia funcional inicial — PR #252

PR #252 con head funcional `a52fa75ece1112db104cc3a4d8a28b1561cc4b79`:

- Sentinel F13 Hub Final Certificate run `32076979482`: PASS (`hub-fast`, `hub-zero-cost`, `hub-db-zero-cost`).
- Ascenda CI `32076979501`: PASS.
- Sentinel F9 regression `32076979446`: FAST + Linux Zero-Cost PASS.
- PR #252 fusionado y Hub F13 incorporado a `main`.

## Paridad migration-history — PR #255

Producción registra de forma autoritativa:

`20260817203504 sentinel_f13_owner_hub`

PR #255 preservó el SQL F13 sin cambios funcionales y alineó Git con el ledger live:

- migration Git canónica: `supabase/migrations/20260817203504_sentinel_f13_owner_hub.sql`;
- filename legado `20260817203500_sentinel_f13_owner_hub.sql` eliminado;
- workflow F13, DB Zero-Cost y UI/Auth security test actualizados a `203504`;
- merge PR #255: `f68b5c0efe3765af8ea8abd0760af29cd13928df`.

El drift era exclusivamente de versión/filename; no se reejecutó DDL productivo para maquillar historial.

## Terminal CURRENT + production smoke — PR #254

Durante el cierre, `main` avanzó por trabajo concurrente S15. #254 fue rebasado fail-closed sobre el CURRENT real `f6db7f5fffa0f9bdb383b47557e34f8f5049f65b` antes de fusionar.

Head terminal exacto:

`4109465080d55e02f9a87bd5d94853981406a566`

Diff terminal: únicamente `.github/workflows/sentinel-phase13-hub.yml`, añadiendo `hub-production-smoke`; cero DDL/runtime/product logic.

Exact-current CI:

- Sentinel F13 Hub Final Certificate run `32082197260`: PASS.
  - `hub-fast`: PASS.
  - `hub-zero-cost`: PASS.
  - `hub-db-zero-cost`: PASS — compile/ACL/canary/rollback/reapply.
  - `hub-production-smoke`: PASS.
- Ascenda CI run `32082197300`: PASS.

El primer intento de smoke detectó correctamente una limitación de infraestructura del runner (`node` ausente en host, exit 127). No se ocultó el rojo: se cambió únicamente la validación JSON para usar el runtime Zero-Cost ya aprobado `node:22-alpine`, y el nuevo exact-head volvió a ejecutar todos los gates desde cero.

Antes del merge se confirmó que `main` seguía exactamente en `f6db7f5f...`; PR #254 se marcó READY solo entonces y se fusionó con `expected_head_sha=4109465080d55e02f9a87bd5d94853981406a566`.

Merge terminal técnico:

`aacd92148a2a15f12bed7d0e014fb7424bc25415`

## Compatibilidad CURRENT posterior — S15.1

Después del merge técnico F13, `main` avanzó a `043b4e454682e13cc0b84e860b90e0a15e8ed0cc` por S15.1, que endurece el boundary de notificaciones generales/F17 y service worker.

Auditoría de diff `aacd9214… → 043b4e45…` confirmó que S15.1 **no modifica**:

- `sentinel/*`;
- `app/public/sentinel-inapp-notifications.js`;
- `app/public/admin-sentinel.html`;
- `app/public/sentinel-hub.js` / bootstrap / topology;
- workflow F13;
- RPC/migration F13.

El closeout documental #263 se rebasa sobre ese CURRENT y activa regresiones F9/F13 por dependencia del Roadmap. Esto valida compatibilidad con el boundary de notificaciones vigente sin reabrir ni duplicar F13.

## Producción terminal

- Railway deployment/status para `main@aacd92148a2a15f12bed7d0e014fb7424bc25415`: SUCCESS.
- Production smoke certificado sobre `https://ascenda-os-production.up.railway.app`:
  - `/health`: PASS;
  - `/admin-sentinel.html`: PASS;
  - `/sentinel-hub.js`: PASS;
  - `/sentinel-hub-bootstrap.js`: PASS;
  - `/sentinel-topology.v1.json`: PASS;
  - topology schema `sentinel-hub-topology/v1`: PASS;
  - projection `owner-ui-safe`: PASS;
  - default state `UNKNOWN`: PASS;
  - browser/public artifact privacy denylist: PASS.
- Supabase post-merge read-back: `20260817203504 sentinel_f13_owner_hub` presente.
- `aos_sentinel_owner_hub_v1(text,integer)` presente.
- Live invalid-token boundary verificado: `SENTINEL_OWNER_2FA_REQUIRED` — fail-closed.
- Positive Auth V3/PASSWORD_2FA se certifica en DB Zero-Cost aislado; no se fabricaron ni extrajeron credenciales productivas.

## Flujo transversal certificado

La baseline cubre:

`detect → incident SEN-* → notify owner in-app → diagnose read-only → AI/MCP triage → candidate remediation → PR + CI + human gate`

F12 mantiene `production_mutation=false`, `auto_merge=false` y `auto_deploy=false`; HIGH/CRITICAL conserva aprobación humana explícita.

## Gate matrix terminal

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
| G14 | F9 regression / owner notification compatibility | PASS |
| G15 | production migration/read boundary preflight | PASS |
| G16 | certificate/current exact recheck | PASS |
| G17 | PR merge-ref/current drift control | PASS |
| G18 | merge with expected-head | PASS |
| G19 | terminal CURRENT integration + Ascenda CI | PASS |
| G20 | Railway + production Hub asset/privacy smoke | PASS |
| G21 | canonical GitHub certificate/roadmap/control closeout | PASS |

Notion es un mirror operativo posterior a la verdad GitHub/runtime y se sincroniza después de fusionar este closeout documental; su actualización no puede convertir un gate técnico rojo en verde ni reabrir F13 por sí sola.

## Decisión final

**F13 = `CERRADA / 100_COMPLETE`.**

Con F12 ya certificada `CERRADA / 100_COMPLETE`, las trece fases Sentinel quedan técnicamente cerradas. Tras fusionar el closeout documental canónico y sincronizar/read-back de Notion, la baseline Sentinel se declara:

**`SENTINEL BASELINE F1–F13 = 100_COMPLETE`**.
