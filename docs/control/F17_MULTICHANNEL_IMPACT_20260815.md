# ASCENDA OS — F17 MULTICHANNEL CHANGE IMPACT REPORT

## Identificación

**Título del cambio:** CIA V3 F17 — SMS / WhatsApp / Future Channels  
**Fecha:** 2026-08-15  
**Solicitante:** ASCENDA OS governance  
**Rama:** `feature/cia-phase17-multichannel-20260815`  
**Base exacta:** `d63b5f47d2847d2bc36ae75ea20131014b6ff5ba`  
**Riesgo:** 🔴 HIGH

## Objetivo

Extender el Audience Engine existente a SMS, WhatsApp y futuros canales sin crear una segunda verdad de audiencias, leads o clientes por canal. El provider/backend debe permanecer intercambiable y los hechos inbound/outbound deben quedar enlazados con attribution y routing existentes.

## Gate previo obligatorio

F17 no puede mutar producción hasta que F16 pruebe de forma autoritativa `aos_cia_email_f17_readiness_v1() => READY_F17_EMAIL_CERTIFIED` con `ready_for_f17=true` y se satisfagan los criterios de salida del Issue #104.

Preflight observado el 2026-08-15:
- `aos_cia_email_f17_readiness_v1()` no existe en producción.
- 0/6 migraciones F16 declaradas están aplicadas.
- GitHub Issue #104 permanece abierto.
- Por tanto: F17 producción BLOQUEADA; solo discovery, diseño y CI sintético están autorizados.

## Evidencia / inventario inicial

Referencias WhatsApp existen en runtime/UI legacy y deben tratarse como consumidores a reconciliar, no como nueva fuente de verdad. Búsqueda inicial incluye `app/server.js`, `app/public/calls.js`, `app/public/agenda.js`, `app/src/pages/callcenter.js`, Apps Script backend, documentación y Electron.

## Código potencialmente afectado

- runtime provider-neutral para outbound;
- webhook ingress firmado/replay-safe;
- adapters WhatsApp/SMS por provider;
- Call Center / Agenda / CRM consumers;
- CI F17 y pruebas contractuales.

No se modificarán consumidores legacy hasta inventariar su contrato real y compatibilidad.

## Datos afectados — diseño previsto, no aplicado

- reutilizar Audience/Activation e identidades canónicas;
- contratos aditivos para channel/message/conversation/event facts;
- idempotency keys y provider event IDs;
- consent/opt-out/suppression canónicos;
- attribution linkage;
- audit trail.

Regla dura: **NO crear tablas de audiencias, clientes o leads duplicadas por canal**.

## Consumidores / dependencias

- F8 channel context/availability;
- F16 Email contracts y consent/suppression patterns;
- Call Center / assignment / routing;
- Agenda;
- Marketing attribution;
- KronIA / governed actions.

## Seguridad

- autorización server-authoritative y fail-closed;
- secretos únicamente por environment/provider secret store;
- webhooks con firma criptográfica, timestamp/replay window e idempotencia;
- ningún teléfono, contenido de mensajes, PII/PHI, token o secret en CI/issues/logs;
- RLS/GRANT progresivos y compatibles;
- ningún spend/provider activation sin configuración verificada y autorización cuando corresponda.

## Compatibilidad

- backward compatible: objetivo sí, por cambios aditivos y adapters;
- migration requerida: probablemente sí, solo después del gate F16→F17;
- datos históricos afectados: no durante discovery; cualquier backfill futuro será separado y gobernado.

## Plan de prueba

1. Inventory y contract mapping F8/F16 + consumers WhatsApp/SMS existentes.
2. Fixtures sintéticos para inbound/outbound, E.164/identity, idempotencia, consent y suppression.
3. Negativos de auth, firma, replay, duplicate event, opt-out y UNKNOWN consent.
4. Exact-head Zero-Cost/self-hosted CI.
5. Production read-only preflight.
6. Migraciones aditivas controladas y canary cuando F16 readiness sea autoritativamente verde.
7. Smoke inbound/outbound en providers realmente configurados.
8. Attribution linkage, rollback/recovery y zero-residue.

## Staging

- solo fixtures sintéticos, sin PII/PHI;
- tres carriles de CI pueden ejecutar en paralelo pruebas read-only/aisladas;
- escrituras a una misma rama se serializan para evitar carreras de branch HEAD.

## Rollback

1. Deshabilitar adapters/canary F17 manteniendo Audience Engine intacto.
2. Revertir migraciones F17 únicamente si son reversibles y sin destruir hechos previos; preferir desactivación lógica/additive rollback.
3. Confirmar zero-residue de fixtures y preservar consumidores legacy.

## Gate de salida F17

- mismo Audience Engine, sin audiencia paralela por canal;
- provider-neutral contracts;
- inbound/outbound facts auditables;
- consent/suppression/opt-out fail-closed;
- webhook firmado/replay-safe e idempotente;
- attribution y routing enlazados a identidades canónicas;
- exact-head CI verde;
- canary + rollback/recovery probados;
- readiness autoritativo para F18;
- PR limpio fusionado según governance;
- F17 = `100_COMPLETE / PRODUCTION CERTIFIED`.

## Resultado posterior

- CI: pendiente.
- staging: pendiente.
- producción: NO MUTADA.
- incidencias: F16 Issue #104 continúa bloqueando producción F17.
- documentación actualizada: este Impact Report.