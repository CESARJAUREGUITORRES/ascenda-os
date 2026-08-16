# SENTINEL F1 — Governance, Privacy & Cost Guardrails — Validation Report

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `VALIDATING`  
**Baseline main:** `d362442cc111cb712cc627a7e8118e3b190c15b5`  
**Branch:** `docs/sentinel-control-v1`  
**PR:** `#179`  
**Riesgo:** HIGH por política de privacidad/telemetría; implementación F1 es docs/control/CI only.

---

## 1. Objetivo de certificación

Cerrar F1 únicamente cuando Sentinel tenga gobierno verificable antes de cualquier export productivo: privacidad allowlist-first, presupuesto US$0, arquitectura vendor-neutral, kill switches definidos, anti-scope explícito y contrato automático self-hosted.

F1 no instala sensores ni modifica runtime/DB.

## 2. Recovery / evidencia inicial

- `main` verificado en `d362442cc111cb712cc627a7e8118e3b190c15b5`.
- runtime productivo actual documentado: `server-phase-s.js → server-f5.js → server-wa4.js → server-wa3.js → server-wa2.js → server-f4.js → server-phase2.js → server.js`.
- búsqueda sobre current main no encontró `SENTRY_DSN`, `@sentry`, inicialización Sentry, OpenTelemetry ni Uptime Kuma en el runtime.
- PR histórico #80 y PR #92 documentaron conexión externa Sentry/GitHub/ChatGPT, pero no instrumentación runtime; se consideran antecedente, no certificación Sentinel.
- `SECURITY.md`, `AGENTS.md` y Zero-Cost CI V2 siguen siendo controles superiores aplicables.

## 3. Baseline económico/técnico externo

Baseline consultada el 2026-08-16 y sujeta a reverificación antes de cualquier upgrade/consumo ampliado:

- Sentry Developer: plan gratuito apto para baseline humana de Error Monitoring/MCP, con cuotas limitadas; Sentinel no depende de su API para el core.
- OpenTelemetry Collector: arquitectura de processors permite filtering/redaction/transformation/sampling antes de exportar.
- Uptime Kuma: alternativa self-hosted de availability con notificaciones Telegram; su utilidad requiere observador 24/7 independiente y no autoriza hosting pagado automático.

Fuentes de referencia:
- `https://sentry.io/pricing/`
- `https://opentelemetry.io/docs/collector/architecture/`
- `https://github.com/louislam/uptime-kuma`

## 4. Gates F1

| Gate | Evidencia requerida | Estado |
|---|---|---|
| F1-G01 | current `main` verificado | PASS |
| F1-G02 | branch/PR Sentinel aislado | PASS |
| F1-G03 | `SENTINEL_CONTROL_MASTER.md` canónico | PASS |
| F1-G04 | roadmap exactamente 13 fases + F13 Hub/System Map | PASS |
| F1-G05 | Zero-PHI/PII policy allowlist-first | PASS |
| F1-G06 | denylist + allowlist de atributos | PASS |
| F1-G07 | ambientes development/zero-cost/staging/production | PASS |
| F1-G08 | kill switches definidos | PASS |
| F1-G09 | presupuesto incremental F1 US$0 + no auto pay-as-you-go | PASS |
| F1-G10 | arquitectura híbrida/vendor-neutral | PASS |
| F1-G11 | anti-scope: F1 no instrumenta runtime/DB | PASS |
| F1-G12 | respuesta ante fuga + secret handling | PASS |
| F1-G13 | Sentry/OpenTelemetry/Kuma responsibilities separadas | PASS |
| F1-G14 | contrato automático machine-checkable | PASS |
| F1-G15 | workflow self-hosted FAST, sin hosted fallback | PENDING until workflow committed |
| F1-G16 | exact-head F1 CI PASS | PENDING |
| F1-G17 | diff final demuestra 0 `app/`, 0 migrations/DB, 0 secrets | PENDING |
| F1-G18 | PR integrado a main + Validation Report final + Notion F1=100/Cerrada, F2 única Siguiente | PENDING |

## 5. Invariantes de cierre

No declarar `100_COMPLETE` mientras cualquier G15–G18 permanezca pendiente.

No se requiere canary productivo porque F1 no introduce runtime, exporter, schema, secret ni provider call. El gate equivalente es exact-head static certification + scope proof + merge documental/control.

## 6. Siguiente loop

1. versionar workflow F1 self-hosted;
2. ejecutar contrato sobre exact HEAD;
3. verificar changed files contra `main`;
4. corregir cualquier fallo sin debilitar la política;
5. obtener CI PASS;
6. fusionar PR #179 si el scope sigue docs/control/CI only;
7. crear checkpoint de cierre exacto si el merge SHA cambia evidencia;
8. actualizar este reporte a `100_COMPLETE` mediante cierre documental;
9. actualizar Notion como último paso;
10. dejar F2 como única fase `Siguiente`.
