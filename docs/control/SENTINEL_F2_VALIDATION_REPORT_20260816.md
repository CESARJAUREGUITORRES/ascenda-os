# SENTINEL F2 — System Registry & Topology Taxonomy — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `100_COMPLETE`  
**Lifecycle:** `VALIDATING → TECHNICALLY_CERTIFIED → 100_COMPLETE`  
**F1:** `100_COMPLETE`  
**Baseline F2:** `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0`  
**Fundación F2:** PR `#184` → `97a03444a00d5e008231ff33ce35969d2b49e94a`  
**Checkpoint técnico:** PR `#185` → `ea71b4cb41e14343f4d3b410f8d837d1091b95ea`  
**Riesgo:** MEDIUM — inventory/control only; no runtime or DB mutation.

---

## 1. Certificación

**SENTINEL F2 — System Registry & Topology Taxonomy queda certificada al 100% para la baseline 2026-08-16.**

El resultado canónico es `docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json`, registry machine-readable de superficies, runtime, dominios, capabilities, dependencias y data-access crítico. F2 describe qué existe y cómo se conecta; no inventa salud operativa.

## 2. Recovery y evidencia

- F1 estaba `100_COMPLETE` antes de iniciar.
- F2 era la única fase `Siguiente` al iniciar.
- F2 tomó current `main@2608c90a9f0d1d80f0f9a7ca6713ef8f221b03c0` como snapshot inicial, incorporando el avance concurrente de F17.
- Railway arranca `node server-phase-s.js`.
- Cadena source-verified: `server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`.
- `app/public/` contiene 41 HTML top-level y todos están clasificados exactamente una vez.
- Metadata live read-only de Supabase: 254 tablas, 141 con RLS, 38 vistas, 1 materialized view, 658 funciones públicas y 522 funciones `aos_*`.
- El snapshot de catálogo es evidencia topológica; **no** certifica la seguridad/RLS de cada objeto.

## 3. Coverage certificada

El contrato fundacional emitió:

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

Dominios canónicos: `AUTH`, `SALES`, `CALL_CENTER`, `AGENDA`, `WHATSAPP`, `EMAIL`, `MARKETING`, `CLINICAL`, `INVENTORY`, `PEOPLE`, `KRONIA`, `STUDIO`, `FINANCE`, `PLATFORM`.

Dominios críticos iniciales: `AUTH`, `SALES`, `CALL_CENTER`, `AGENDA`, `WHATSAPP`, `CLINICAL`, `FINANCE`, `PLATFORM`.

`CLINICAL` conserva `sensitivity=PHI` y boundary `metadata-only-no-PHI`.

## 4. Evidencia CI

### Fundación PR #184

Candidate: `f10fdcd129d502cd0d756e58a32277bf92365b11`.

- Sentinel F2 Registry Certificate — run `31953402560` — **PASS**.
- Ascenda CI — run `31953402539` — **PASS**.
- Sentinel F1 Governance regression — run `31953402541` — **PASS**.
- Scope: 7 archivos control/docs/CI; 0 `app/`; 0 migrations/DB; 0 production mutation.
- Merge: `97a03444a00d5e008231ff33ce35969d2b49e94a`.

### Checkpoint PR #185

Candidate: `71aa41f2e30c72656aecbcd529c1d98fb3e20396`.

- Sentinel F2 Registry Certificate — run `31953540695` — **PASS**.
- Sentinel F1 Governance regression — run `31953540706` — **PASS**.
- Scope: 1 documento de validación.
- Merge: `ea71b4cb41e14343f4d3b410f8d837d1091b95ea`.

## 5. Evidencia Notion

Después del checkpoint técnico integrado:

- F2 page `3be0e4fe-8414-81b1-95c6-e96c28e200eb`: `Estado=Cerrada`, `Progreso=100`.
- F3 page `3be0e4fe-8414-8126-bb3e-d6e997c31025`: `Estado=Siguiente`, `Progreso=0`.
- F1 permanece cerrada; F4–F13 permanecen pendientes.

## 6. Gates F2

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F2-G01 | F1 `100_COMPLETE` y F2 única siguiente al iniciar | PASS |
| F2-G02 | current `main` snapshot exacto y branch aislada | PASS |
| F2-G03 | 41/41 HTML top-level clasificados exactamente una vez | PASS |
| F2-G04 | Railway entrypoint registrado y verificado | PASS |
| F2-G05 | cadena de 8 procesos Node y spawn edges verificados | PASS |
| F2-G06 | taxonomía de 14 dominios canónica e IDs únicos | PASS |
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
| F2-G18 | checkpoint integrado + Notion F2=100/Cerrada + F3 única Siguiente + certificado final | PASS |

**Resultado:** `18/18 PASS`.

## 7. Decisiones congeladas al cerrar F2

- Registry canónico: `SENTINEL_SYSTEM_REGISTRY_V1.json`.
- Schema: `sentinel-system-registry/v1`.
- 41 superficies, 14 dominios, 34 capabilities, 8 dependencias y 8 nodos runtime en la baseline.
- Todo `observability_state` permanece `UNKNOWN` en F2.
- `HEALTHY` está prohibido en F2 por contrato automático.
- Un nuevo HTML top-level, cambio de entrypoint Railway o spawn edge genera drift y debe actualizar el registry.
- Zero PHI/PII telemetry permanece vigente.
- F2 no instala Sentry, OpenTelemetry, Kuma ni ningún sensor productivo.

## 8. No-certificaciones deliberadas

F2 no certifica disponibilidad en tiempo real, seguridad total de RLS/RPC, configuración actual de todos los proveedores ni tracing/error/uptime monitoring. Esas capacidades pertenecen a F3–F6 y workstreams de seguridad específicos.

## 9. Handoff a F3

F3 — `Telemetry Contract & OpenTelemetry Foundation` es la única fase `Siguiente`.

F3 debe partir del registry V1 y definir el contrato portable de telemetría, correlation IDs, redaction/filtering, sampling y exporter abstraction sin introducir PHI/PII ni dependencia estructural de un proveedor.
