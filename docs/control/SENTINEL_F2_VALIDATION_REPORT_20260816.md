# SENTINEL F2 — System Registry & Topology Taxonomy — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `TECHNICALLY_CERTIFIED / NOTION_FINALIZATION_PENDING`  
**Lifecycle:** `VALIDATING → TECHNICALLY_CERTIFIED → 100_COMPLETE`  
**F1:** `100_COMPLETE`  
**Baseline F2:** `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`  
**Fundación F2:** PR `#184` → `main@97a03444a00d5e008231ff33ce35969d2b49e94a`  
**Riesgo:** MEDIUM — inventory/control only; no runtime or DB mutation.

---

## 1. Resultado técnico

F2 dispone de un registry machine-readable que clasifica las superficies de producto, cadena runtime, dominios, capabilities, dependencias y data-access crítico sin afirmar salud operativa no observada.

F2 no modificó runtime, database schema, Railway, Supabase data ni secrets.

## 2. Recovery y baseline

- F1 estaba `100_COMPLETE` antes de iniciar.
- F2 era la única fase `Siguiente` en Notion.
- `main` había avanzado concurrentemente por F17; F2 tomó el current `2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0` como snapshot inicial.
- Durante el gate fundacional `main` no cambió.
- Railway arranca `node server-phase-s.js`.
- Cadena source-verified: `server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`.
- `app/public/` contiene 41 superficies HTML top-level.
- Supabase live metadata read-only: 254 tablas, 141 con RLS, 38 vistas, 1 materialized view, 658 funciones públicas y 522 funciones `aos_*`.

## 3. Coverage certificada por contrato

El run fundacional emitió:

```text
SENTINEL_F2_REGISTRY_CONTRACT_PASS
public_html_surfaces = 41
domains = 14
capabilities = 34
dependencies = 8
runtime_nodes = 8
false_green_claims = 0
unmapped_critical_nodes = 0
changed_files_checked = 7
```

El registry cubre 14 dominios canónicos y 8 dominios críticos iniciales. `CLINICAL` permanece bajo boundary `metadata-only-no-PHI`.

## 4. Evidencia CI exacta

Candidate fundacional: `f10fdcd129d502cd0d756e58a32277bf92365b11`.

- Sentinel F2 Registry Certificate — run `31953402560` — **PASS**.
- Ascenda CI — run `31953402539` — **PASS**.
- Sentinel F1 Governance regression — run `31953402541` — **PASS**.
- PR #184 era `mergeable=true` antes del merge.

Changed files PR #184:

1. `.github/workflows/sentinel-phase2-registry.yml`
2. `ci/sentinel/phase2_registry_contract.js`
3. `docs/control/SENTINEL_F2_REGISTRY_CHANGE_POLICY.md`
4. `docs/control/SENTINEL_F2_REGISTRY_README.md`
5. `docs/control/SENTINEL_F2_TOPOLOGY_REPORT_20260816.md`
6. `docs/control/SENTINEL_F2_VALIDATION_REPORT_20260816.md`
7. `docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json`

Resultado scope: **0 `app/`, 0 migrations/DB, 0 Supabase runtime, 0 production mutation**.

## 5. Gates F2

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F2-G01 | F1 `100_COMPLETE` y F2 única siguiente al iniciar | PASS |
| F2-G02 | current `main` snapshot exacto y branch aislada | PASS |
| F2-G03 | 41/41 HTML top-level clasificados exactamente una vez | PASS |
| F2-G04 | Railway entrypoint registrado y verificado | PASS |
| F2-G05 | cadena de 8 procesos Node y spawn edges verificados | PASS |
| F2-G06 | taxonomía de 14 dominios canónica y IDs únicos | PASS |
| F2-G07 | 34 capabilities con criticality y evidence | PASS |
| F2-G08 | runtime/dependencies/capabilities en `UNKNOWN`; cero false-green | PASS |
| F2-G09 | 8 dependencias registradas con evidencia | PASS |
| F2-G10 | snapshot live Supabase agregado y no-PII | PASS |
| F2-G11 | relaciones/RPC críticos mapeados por capability | PASS |
| F2-G12 | sensibilidad CLINICAL/PHI y metadata-only boundary | PASS |
| F2-G13 | registry JSON machine-readable + drift checks | PASS |
| F2-G14 | contrato automático sin secretos ni acceso productivo | PASS |
| F2-G15 | workflow self-hosted FAST sin hosted fallback | PASS |
| F2-G16 | exact-head F2 CI + Ascenda CI + F1 regression PASS | PASS |
| F2-G17 | final diff control/docs/CI only; 0 `app/`, 0 migrations/DB | PASS |
| F2-G18 | checkpoint integrado + Notion F2=100/Cerrada + F3 única Siguiente + certificado final | PENDING |

## 6. No-certificaciones deliberadas

Cerrar F2 no certifica:

- que los módulos estén `HEALTHY`;
- que todas las políticas RLS existentes sean correctas;
- que cada integración externa esté disponible;
- que cada RPC pública sea segura;
- que exista tracing/error/uptime monitoring.

F2 certifica topología y cobertura. Las señales reales se añaden en F3–F6.

## 7. Estado de cierre

G01–G17 están técnicamente certificados. Falta únicamente G18: integrar este checkpoint, sincronizar Notion y emitir el certificado final `100_COMPLETE` que deje F3 como única fase `Siguiente`.
