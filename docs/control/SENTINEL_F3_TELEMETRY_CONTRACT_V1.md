# SENTINEL F3 — Telemetry Contract V1

**Estado:** CURRENT / CANONICAL FOR F3  
**Fecha:** 2026-08-16 (America/Lima)  
**Schema:** `sentinel-telemetry-contract/v1`  
**Baseline:** `main@2ec3c7ad0883d171dcfb81f61049d6b51e38f882`

## 1. Propósito

Definir una capa portable de telemetría para ASCENDA OS antes de activar un proveedor. F3 establece nombres, contexto, privacy filtering, sampling y exporter abstraction, pero **no activa telemetría productiva**.

La implementación de referencia vive en `sentinel/telemetry/` y es CommonJS puro, sin dependencia nueva en `app/package.json`.

## 2. Principios congelados

- **Zero PHI/PII telemetry**.
- **allowlist-first**: un atributo no permitido se descarta.
- Vendor-neutral: Sentinel Core no depende de Sentry, Grafana, GlitchTip ni otro backend.
- Producción mantiene export de red **OFF** en F3.
- Producción mantiene sampling por defecto `production=0` en F3.
- Fixtures pueden usar `zero-cost=1` exclusivamente con datos sintéticos.
- Ningún cambio F3 puede modificar `app/`, Railway, migrations o funciones Supabase.

## 3. Resource attributes

OpenTelemetry modela `service.name`, `service.version` y `service.namespace` como identidad del servicio. Sentinel congela:

- `service.namespace=ascenda-os`
- `service.name`
- `service.version`
- `deployment.environment.name`
- `sentinel.domain`
- `sentinel.component`
- `sentinel.phase`

Ambientes F3 válidos: `development`, `zero-cost`, `production`.

No se registra identidad de paciente, teléfono, email, DNI, body o contenido clínico como resource attribute.

## 4. Event/span attributes permitidos

Allowlist V1:

- `sentinel.domain`
- `sentinel.component`
- `sentinel.capability`
- `sentinel.dependency`
- `sentinel.operation`
- `sentinel.phase`
- `sentinel.request_id`
- `sentinel.provider`
- `sentinel.route_template`
- `sentinel.site_code`
- `error.type`
- `error.code`
- `http.request.method`
- `http.response.status_code`
- `http.route`

Todo lo demás se descarta por defecto.

## 5. Propagación

El contrato usa **W3C Trace Context** para `traceparent`.

- `trace_id`: 32 hex.
- `span_id`: 16 hex.
- `request_id`: UUID v4 independiente.
- `traceparent` inválido se ignora y genera un nuevo contexto.
- `baggage` inbound: **DROP / disabled**.
- `baggage` outbound: **OFF**.

La decisión de deshabilitar `baggage` evita propagar metadata arbitraria o sensible entre servicios. Una futura habilitación necesita allowlist y gate propio.

## 6. Sampling

F3 usa sampling determinista por `trace_id` para que la decisión sea reproducible y no dependa de identidad de usuario.

- `development=1`
- `zero-cost=1`
- `production=0`

Cambiar production por encima de cero corresponde a una fase posterior y exige privacy/cost gate.

## 7. Redaction

Doble regla:

1. key desconocida o denylisted → **DROP**;
2. valor sensible detectado dentro de una key permitida → **`[REDACTED]`**.

Clases prohibidas incluyen:

- Authorization/cookies/API keys/tokens/service role/passwords;
- teléfonos, emails, DNI/documentos;
- paciente/nombre/recipient/wa_id;
- request/response bodies;
- contenido WhatsApp/email;
- prompts/respuestas/inputs/outputs de IA;
- raw webhooks.

## 8. Exporter abstraction

Interfaz mínima:

`export(envelope)`

F3 certifica dos exporters locales:

- `noop`: kill switch efectivo;
- `memory-test`: fixture/CI.

Un exporter alternativo que implemente la misma interfaz debe recibir exactamente el mismo envelope sanitizado. Ningún exporter de red está autorizado en F3.

## 9. Envelope V1

Schema: `sentinel-telemetry-envelope/v1`.

Campos:

- `schema_version`
- `signal`
- `timestamp`
- `resource`
- `context`
- `attributes`

Signals reservadas: `span`, `error`, `metric`, `event`.

## 10. Collector reference

`sentinel/collector/otel-collector-reference.yaml` es **diseño no desplegado**. Documenta un pipeline futuro con:

`memory_limiter → filter → redaction → batch → exporter`

El orden busca descartar primero lo innecesario/sensible y batch al final. En F3 el único exporter del ejemplo es `debug`, sin endpoint ni credenciales.

## 11. Compatibilidad ASCENDA

La fundación es CommonJS y usa solo módulos nativos de Node (`crypto`). Por eso es compatible con la cadena actual de procesos Node sin tocarla todavía.

F4/F7 podrán adaptar esta capa hacia Sentry/OpenTelemetry SDK y release correlation, manteniendo el contrato F3 como frontera de privacidad.

## 12. Kill switches y precedencia

F1 conserva precedencia:

- `SENTINEL_ENABLED`
- `SENTINEL_SENTRY_ENABLED`
- `SENTINEL_OTEL_EXPORT_ENABLED`

F3 no cambia esas variables ni las activa. Si no existe exporter productivo, Sentinel debe seguir funcionando como no-op.

## 13. Gate de cambio

Modificar allowlist, denylist, environments, sampling productivo, baggage, schema, exporter interface o activar red requiere:

1. PR aislado;
2. fixture sintético actualizado;
3. `Sentinel F3 Telemetry Certificate` PASS;
4. regresión F1 PASS;
5. revisión de privacidad/costo según impacto.
