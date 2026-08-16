# SENTINEL F3 — Telemetry Contract & OpenTelemetry Foundation — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `VALIDATING`  
**F1:** `100_COMPLETE`  
**F2:** `100_COMPLETE`  
**Baseline F3:** `main@2ec3c7ad0883d171dcfb81f61049d6b51e38f882`  
**Branch:** `feat/sentinel-f3-otel-foundation`  
**Riesgo:** HIGH — privacy/telemetry contract; runtime activation remains forbidden in F3.

## 1. Objetivo

Certificar un contrato portable de telemetría con identidad de servicio, correlation IDs, W3C Trace Context, sampling, filtering/redaction y exporter abstraction, sin PHI/PII, sin dependencia estructural de proveedor y sin activar export productivo.

## 2. Decisiones F3

- Schema contrato: `sentinel-telemetry-contract/v1`.
- Schema envelope: `sentinel-telemetry-envelope/v1`.
- CommonJS puro, sin nueva dependencia productiva.
- `service.namespace=ascenda-os`.
- W3C Trace Context para `traceparent`.
- `baggage` disabled.
- sampling determinista: development=1, zero-cost=1, production=0.
- allowlist-first + denylist + sensitive-value redaction.
- exporters F3: `noop` y `memory-test`.
- Collector: referencia no desplegada.
- cero cambios `app/`, Railway, migrations/DB o funciones Supabase.

## 3. Gates F3

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F3-G01 | F1/F2 `100_COMPLETE`; F3 única `Siguiente` al iniciar | PASS |
| F3-G02 | baseline exacta y branch aislada desde `main@2ec3c7ad` | PASS |
| F3-G03 | contract JSON V1 machine-readable, vendor-neutral, zero-PHI/PII | PASS by implementation; CI pending |
| F3-G04 | resource attributes requeridos y namespace canónico | PASS by implementation; CI pending |
| F3-G05 | W3C `traceparent` parse/format y parent propagation | PASS by implementation; CI pending |
| F3-G06 | `baggage` inbound/outbound deshabilitado | PASS by contract; CI pending |
| F3-G07 | `request_id` UUID v4 independiente y validado | PASS by implementation; CI pending |
| F3-G08 | sampling determinista; production default=0 | PASS by implementation; CI pending |
| F3-G09 | allowlist-first para resource/event attributes | PASS by implementation; CI pending |
| F3-G10 | denylist + sensitive-value redaction antes de exporter | PASS by implementation; CI pending |
| F3-G11 | fixture sintético demuestra cero leakage de valores sensibles | PENDING CI |
| F3-G12 | noop/memory/custom exporter reciben contrato intercambiable | PENDING CI |
| F3-G13 | Collector reference tiene filter/redaction/batch y no está desplegado | PASS by design; CI pending |
| F3-G14 | CommonJS + Node built-ins; cero nueva dependencia en `app/package.json` | PASS by design; CI pending |
| F3-G15 | final diff sin `app/`, Railway, DB/migrations, providers ni secrets | PENDING |
| F3-G16 | exact-head self-hosted F3 certificate PASS | PENDING |
| F3-G17 | regresiones F1 + F2 + Ascenda CI sin rojo material | PENDING |
| F3-G18 | merge + Notion F3=100/Cerrada y F4 única Siguiente + certificado final | PENDING |

## 4. Artefactos

- `sentinel/telemetry/contract-v1.json`
- `sentinel/telemetry/index.js`
- `sentinel/collector/otel-collector-reference.yaml`
- `ci/sentinel/fixtures/f3_sensitive_fixture.json`
- `ci/sentinel/phase3_telemetry_contract.js`
- `.github/workflows/sentinel-phase3-telemetry.yml`
- `docs/control/SENTINEL_F3_TELEMETRY_CONTRACT_V1.md`
- `docs/control/SENTINEL_F3_VALIDATION_REPORT_20260816.md`

## 5. No-certificaciones deliberadas

Cerrar F3 no significa que exista Sentry/Collector/OTLP activo, tracing productivo, métricas productivas, logs productivos o export de red. F4 instala Sentry Error Monitoring Core; F5 cubre disponibilidad; F6 business health; F7 correlation release/deploy.

## 6. Loop pendiente

1. versionar workflow F3;
2. abrir PR;
3. ejecutar self-hosted exact-head contract;
4. corregir sin relajar privacy contract;
5. verificar diff/secret scope;
6. integrar checkpoint técnico;
7. sincronizar Notion;
8. emitir certificado `100_COMPLETE`;
9. gate final y merge;
10. dejar F4 como única `Siguiente`.
