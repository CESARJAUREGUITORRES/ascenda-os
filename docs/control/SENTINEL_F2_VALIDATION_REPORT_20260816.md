# SENTINEL F2 — System Registry & Topology Taxonomy — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `VALIDATING`  
**F1:** `100_COMPLETE`  
**Baseline F2:** `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`  
**Branch:** `docs/sentinel-f2-registry-v1`  
**Riesgo:** MEDIUM — inventory/control only; no runtime or DB mutation.

---

## 1. Objetivo

Certificar un registry machine-readable y verificable de ASCENDA OS que clasifique las superficies de producto, cadena runtime, dominios, capabilities, dependencias y data-access crítico sin afirmar salud operativa que todavía no se observa.

## 2. Recovery

- F1 verificada `100_COMPLETE`.
- F2 era la única fase `Siguiente` en Notion antes de iniciar.
- `main` avanzó concurrentemente por F17 y F2 tomó como snapshot inicial el current `2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`, no el SHA antiguo de F1.
- Railway actual arranca `node server-phase-s.js`.
- Cadena source-verified: `server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`.
- `app/public/` contiene 41 superficies HTML top-level.
- Supabase live metadata read-only: 254 tablas, 141 con RLS, 38 vistas, 1 materialized view, 658 funciones públicas, 522 funciones `aos_*`.

## 3. Artifact set F2

- `docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json`
- `docs/control/SENTINEL_F2_TOPOLOGY_REPORT_20260816.md`
- `docs/control/SENTINEL_F2_VALIDATION_REPORT_20260816.md`
- `ci/sentinel/phase2_registry_contract.js`
- `.github/workflows/sentinel-phase2-registry.yml`

## 4. Gates F2

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F2-G01 | F1 `100_COMPLETE` y F2 única siguiente al iniciar | PASS |
| F2-G02 | current `main` snapshot exacto y branch aislada | PASS |
| F2-G03 | 41/41 HTML top-level clasificados exactamente una vez | PASS by registry; CI pending |
| F2-G04 | Railway entrypoint registrado | PASS by evidence; CI pending |
| F2-G05 | cadena de 8 procesos Node y spawn edges registrados | PASS by evidence; CI pending |
| F2-G06 | taxonomía de dominios canónica y IDs únicos | PASS by registry; CI pending |
| F2-G07 | capabilities y criticality por dominio | PASS by registry; CI pending |
| F2-G08 | todas las capabilities/dependencias/runtime en `UNKNOWN`; cero false-green | PASS by registry; CI pending |
| F2-G09 | dependencias externas registradas con evidencia | PASS by registry; CI pending |
| F2-G10 | snapshot live Supabase agregado y no-PII | PASS |
| F2-G11 | relaciones/RPC críticos mapeados por capability | PASS by registry; CI pending |
| F2-G12 | sensibilidad CLINICAL/PHI y boundary metadata-only declarados | PASS |
| F2-G13 | registry JSON machine-readable + drift checks | PASS by implementation; CI pending |
| F2-G14 | contrato automático sin secretos ni acceso productivo | PASS by implementation; CI pending |
| F2-G15 | workflow self-hosted FAST sin hosted fallback | PENDING until workflow committed |
| F2-G16 | exact-head F2 CI PASS contra merge candidate | PENDING |
| F2-G17 | final diff = control/docs/CI only; 0 `app/`, 0 migrations/DB | PENDING |
| F2-G18 | merge + Validation Report final + Notion F2=100/Cerrada y F3 única Siguiente | PENDING |

## 5. No-certificaciones deliberadas

Cerrar F2 **no** certifica:

- que los módulos estén `HEALTHY`;
- que todas las políticas RLS existentes sean correctas;
- que cada integración externa esté disponible;
- que cada RPC pública sea segura;
- que exista tracing, error monitoring o uptime monitoring.

F2 certifica topología y cobertura de registry. Las señales reales se añaden en F3–F6.

## 6. Drift policy

El contrato F2 compara dinámicamente:

- todos los HTML top-level actuales de `app/public/` contra el registry;
- `app/railway.json` contra el entrypoint registrado;
- cada edge del runtime chain contra el source code del parent process;
- referencias de dominios, components y dependencies;
- ausencia global de `HEALTHY`;
- scope del PR contra `main`.

Si `main` cambia durante F2 y el merge candidate modifica una superficie/runtime relevante, el gate debe fallar y el registry debe actualizarse antes de certificar.

## 7. Loop pendiente

1. versionar workflow F2;
2. abrir PR;
3. ejecutar exact-head self-hosted CI;
4. corregir cualquier drift/fallo sin relajar contrato;
5. verificar final changed-files scope;
6. fusionar checkpoint técnico;
7. sincronizar Notion;
8. emitir certificado `100_COMPLETE`;
9. correr gate final y fusionar;
10. actualizar Notion con SHA final y dejar F3 como única `Siguiente`.
