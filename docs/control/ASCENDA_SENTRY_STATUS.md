# ASCENDA OS — SENTRY STATUS

**Estado:** EN EJECUCIÓN / NO CERTIFICADO EN RUNTIME  
**Fecha:** 2026-08-14 (America/Lima)

## Confirmado

- El usuario confirmó visualmente el plugin `Sentry` instalado en ChatGPT.
- La pantalla del plugin muestra la skill `Sentry (Read-only Observability)` para inspección de issues/eventos.
- El usuario confirmó visualmente la integración Sentry ↔ GitHub para la cuenta/configuración `CESARJAUREGUITORRES`.
- El MCP indicado por el usuario es `https://mcp.sentry.dev/mcp`.

## No certificado todavía

La integración externa NO equivale a instrumentación del runtime de ASCENDA.

Auditoría del repo `CESARJAUREGUITORRES/ascenda-os` realizada el 2026-08-14:

- `SENTRY_DSN` → 0 referencias;
- `@sentry/` → 0 referencias;
- `Sentry.init` → 0 referencias;
- `sentry` → 0 referencias de código/configuración.

Por tanto el estado correcto es:

`CHATGPT↔SENTRY = CONNECTED (evidencia visual)`

`SENTRY↔GITHUB = CONNECTED (evidencia visual)`

`ASCENDA RUNTIME↔SENTRY = PENDING / NOT CERTIFIED`

## Gate para declarar Sentry OPERATIVO

No marcar `OPERATIVO` hasta demostrar:

1. proyecto Sentry correcto para ASCENDA;
2. DSN/configuración por variables de entorno, nunca hardcodeada;
3. integración Node/Railway;
4. integración frontend si se aprueba;
5. `environment` y `release` correctos;
6. source maps cuando apliquen;
7. PII/data scrubbing validado;
8. evento/error controlado emitido desde staging;
9. evento visible en Sentry;
10. ChatGPT/Sentry capaz de consultar al menos un issue/evento real del proyecto;
11. rollback/desactivación documentada;
12. Notion + `aos_memory` actualizados.

## Reglas de privacidad

No enviar a Sentry sin revisión explícita:

- historia clínica;
- notas médicas;
- fotos;
- documentos;
- teléfonos completos;
- emails completos cuando no sean necesarios;
- tokens/secrets;
- payloads con datos sensibles de pacientes.

Preferir tags técnicos, IDs internos no reversibles y metadata mínima necesaria.

## Integración con el roadmap CIA

Sentry es una capacidad transversal de observabilidad. Su hardening completo sigue encajando en F18 — Attribution, Learning & Hardening, pero una instrumentación mínima segura puede adelantarse si existe Impact Report, staging, PII scrubbing y smoke controlado.

Sentry no cambia el estado de fases CIA por sí solo.
