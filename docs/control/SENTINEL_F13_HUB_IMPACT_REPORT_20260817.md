# Sentinel F13 — Hub, System Map & Final Certification — Impact Report

**Estado:** ACTIVE / GOVERNANCE FIRST  
**Fecha:** 2026-08-17 (America/Lima)  
**Branch:** `feature/sentinel-f13-hub-system-map`  
**Base:** F12 terminal `main@42e39946249b44322dab75890d593daa0e9dc401`  
**Riesgo:** HIGH

## Objetivo

Entregar el panel final **Sentinel dentro de ASCENDA**, protegido para owner/admin, con System Map y drill-down `dominio → componente → capability`, incidentes `SEN-*`, estado operativo, evidencia técnica sanitizada, release/correlation y acciones seguras; después certificar transversalmente F1–F13 para declarar la baseline Sentinel `100_COMPLETE`.

## Código previsto

- `sentinel/hub/**`: composición vendor-neutral y reglas de estado/no-false-green;
- `app/public/admin-sentinel.html` y `app/public/sentinel-hub.js`: UI owner/admin responsive;
- integración mínima en shell ASCENDA para acceso al panel, preservando el patrón Auth V3/2FA ya certificado;
- `ci/sentinel/phase13_*`: contrato, privacy, resilience, portability y UI security tests;
- `.github/workflows/sentinel-phase13-hub.yml`: FAST/Linux Zero-Cost;
- si resulta necesario para datos live, una única migración F13 **read-only** que reutilice las tablas/incidentes F8 y el boundary Auth V3 de F9; no se crea una segunda fuente de verdad.

## Datos

- `docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json` sigue siendo la fuente de verdad topológica F2;
- F8 sigue siendo la fuente de incidentes `SEN-*`;
- F9 sigue siendo la fuente de owner notifications;
- F10/F11/F12 aportan diagnosis/triage/remediation lineage, no una segunda persistencia de incidentes;
- el Hub no almacena PHI/PII, stack traces, cuerpos de mensajes, secretos ni payloads arbitrarios;
- cualquier RPC F13 será agregada/read-only, sanitizada, token-gated y de mínimo privilegio.

## Seguridad / privacidad

- solo owner/admin autorizado puede consumir información live del Hub;
- la existencia del HTML estático no equivale a autorización: los datos live requieren sesión Auth V3 válida y 2FA conforme al shell existente;
- nunca usar `service_role` en navegador;
- no exponer tablas/RPC/dependencies internos en un artefacto público de topología;
- no usar `innerHTML` para datos remotos;
- no mostrar stack traces, provider payloads, query strings, tokens, email, teléfono, DNI ni datos clínicos;
- missing/stale evidence se representa `UNKNOWN`, nunca `HEALTHY` por ausencia de errores;
- proveedores externos son sensores intercambiables: Sentry/Kuma/Collector down debe degradar evidencia, no romper Sentinel Core;
- acciones del Hub: lectura, navegación, reconocer cuando ya exista boundary certificado, diagnosticar/abrir GitHub; no auto-remediation ni deploy.

## Contrato de estados

- `CRITICAL`: incidente activo P0 o evidencia equivalente validada;
- `INCIDENT`: incidente activo P1;
- `DEGRADED`: incidente P2/P3, health degradado o evidencia parcial reciente;
- `HEALTHY`: solo con evidencia de salud explícita, reciente y suficiente;
- `UNKNOWN`: evidencia ausente, stale, sensor requerido no disponible o capability sin señal suficiente.

## Resilience / portability

Se certificarán al menos:

1. Sentry unavailable → Sentinel no cae; señal dependiente pasa a `UNKNOWN`/degraded según evidencia disponible.
2. Kuma unavailable → availability no se presenta false-green.
3. Collector unavailable → telemetry freshness faltante se representa `UNKNOWN`.
4. Sentinel Core data unavailable → Hub fail-closed/UNKNOWN; nunca fabrica estado.
5. Fixture/provider alternativo con el mismo contrato produce el mismo modelo del Hub.

## Costo

F13 no autoriza nuevas suscripciones ni pay-as-you-go. La baseline debe funcionar con infraestructura ya certificada y Zero-Cost CI; cualquier gasto futuro queda fuera de scope y requiere autorización separada.

## Rollback

- frontend: revert del commit/PR F13;
- integración shell: retirar entrada Sentinel sin afectar paneles existentes;
- RPC read-only F13, si se crea: rollback versionado que elimina únicamente el boundary F13 y conserva F8/F9;
- no se borra ni reescribe historial/incidentes F8;
- F12 Safe Remediation permanece independiente de F13.

## Gate de salida

F13 solo puede declararse cerrada cuando:

- topology contract F2→Hub PASS;
- Auth/2FA + privacy negatives PASS;
- status/no-false-green PASS;
- resilience + portability PASS;
- FAST/Linux Zero-Cost + Ascenda CI exact-head PASS;
- live read boundary/canary PASS si se introduce RPC;
- PR merge-ref PASS;
- merge con expected-head;
- post-merge CI + smoke productivo del Hub PASS;
- roadmap GitHub + Control Maestro/Notion alineados;
- certificado final F13 registra F1–F13 como `100_COMPLETE`.

Hasta esos gates, Sentinel baseline no se declara completa.
