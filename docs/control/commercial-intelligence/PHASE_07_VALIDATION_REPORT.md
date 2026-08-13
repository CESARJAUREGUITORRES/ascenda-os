# ASCENDA OS — FASE 7 VALIDATION REPORT

**Fase:** Snapshots & Activation  
**Estado:** VALIDATING  
**Fecha:** 2026-08-13  
**Baseline staging:** `d17eaa8cabfeae88c9442246f542b2e18b2a1691`

---

## Resultado ejecutivo

La capa Phase 7 está implementada de forma aditiva y mantiene las fronteras requeridas:

- Audience Definition ≠ Snapshot.
- Snapshot ≠ Activation.
- Activation ≠ Assignment.
- `channel` es contexto, no ejecución ni elegibilidad.
- Fase 7 no modifica Call Center, Email legacy, `aos_siguiente_lead`, `aos_cola_config` ni fuentes operativas.

---

## Persistencia desplegada

Snapshot:
- `aos_audiencia_snapshots`
- `aos_audiencia_snapshot_miembros`

Activation Aggregate:
- `aos_audiencia_activaciones`
- `aos_audiencia_activacion_config`
- `aos_audiencia_activacion_estado`
- `aos_audiencia_activacion_eventos`

El aggregate separa identidad/configuración inmutable de lifecycle mutable y audit append-only.

---

## Snapshot

Contrato certificado:
- audience/version exacta;
- BUILDING → READY;
- snapshot header inmutable tras sello;
- members inmutables;
- no members nuevos tras READY;
- count físico verificado al sellar;
- `membership_hash` SHA-256 de contact keys ordenados;
- `filter_hash` SHA-256;
- máximo 100,000 miembros.

El snapshot congela membership e identity status/conflict. Commercial Facts visualizados posteriormente siguen siendo LIVE y la API/UI lo declara.

### Paridad resolver

Count V2 = resolver completo:
- FOLLOWUP_OVERDUE: 442 = 442
- LEADS_UNWORKED: 1,292 = 1,292
- LEADS_UNWORKED_7D: 126 = 126
- NO_SHOW_NO_FUTURE: 822 = 822

PASS.

---

## Activation

### BATCH
- snapshot obligatorio;
- snapshot READY;
- misma audience/version;
- membership `FROZEN_SNAPSHOT`;
- facts `LIVE`.

### DYNAMIC
- snapshot prohibido;
- versión fijada;
- membership `DYNAMIC_LIVE`;
- facts `LIVE`.

### Lifecycle

Permitido:
- DRAFT → ACTIVE | CANCELLED
- ACTIVE → PAUSED | COMPLETED | CANCELLED
- PAUSED → ACTIVE | COMPLETED | CANCELLED

Terminal:
- COMPLETED
- CANCELLED

Harness TEMP con trigger productivo:
- DRAFT→ACTIVE→PAUSED→ACTIVE→COMPLETED: PASS
- COMPLETED→ACTIVE: rechazado
- `started_at`: presente
- `ended_at`: presente

---

## Inmutabilidad / validación

Harness TEMP con guard productivo de eventos:
- UPDATE: rechazado
- DELETE: rechazado
- payload original: intacto

Harness TEMP con config validator:
- DYNAMIC sin snapshot: aceptado
- DYNAMIC con snapshot: rechazado
- BATCH sin snapshot: rechazado
- channel fuera de whitelist: rechazado

Triggers físicos verificados en producción:
1. snapshot header guard
2. snapshot member guard
3. activation identity guard
4. activation config immutable
5. activation config validator
6. activation config relation
7. activation state guard
8. activation event immutable

---

## Autorización

Mutators y gateway son `SECURITY DEFINER` con `search_path=public`:
- snapshot create
- activation create
- activation transition
- Phase 7 gateway

Cada mutator verifica la sesión CIA administrativa antes de escribir y deriva el actor desde esa sesión.

Pruebas negativas reales:
- snapshot create con token inválido → `UNAUTHORIZED`
- activation create → `UNAUTHORIZED`
- transition → `UNAUTHORIZED`
- gateway → `UNAUTHORIZED`

No se fabricó una sesión CIA ni se extrajo credencial para forzar un E2E positivo. El verifier de sesión CIA fue certificado en Fases 5–6; Phase 7 lo ejecuta dentro de cada mutator. Los invariantes de negocio fueron probados mediante triggers productivos en tablas temporales y paridad del resolver, sin persistir datos de QA.

---

## RLS

RLS = `true` en los seis objetos.

No existen policies permisivas Phase 7.

Pruebas de rol:
- `anon`: 0 filas visibles
- `authenticated`: 0 filas visibles
- INSERT directo como anon: rechazado

Nota de plataforma: Supabase conserva los privilegios estándar de `service_role`; el conector bloqueó DCL `REVOKE`. No se afirma SELECT-only para ese rol. `service_role` es server-side y no forma parte de la superficie browser.

---

## Read contracts

- list activations
- get activation
- preview activation
- list snapshots

Límites server-side:
- list ≤ 100
- preview ≤ 100
- payload gateway ≤ 64 KiB

Semántica expuesta explícitamente:
- `FROZEN_SNAPSHOT`
- `DYNAMIC_LIVE`
- `facts_mode=LIVE`
- `context_only=true`

---

## Replayability

Checkpoints live canónicos:
- `20260813214724_cia_phase7_read_contract_checkpoint_v1`
- `20260813214912_cia_phase7_gateway_checkpoint_v1`
- `20260813215012_cia_phase7_hardening_checkpoint_v1`

Gateway y hardening tienen source ejecutable en migrations Git.

El read checkpoint tiene un history pointer en migrations y su source SQL exacto está en:
- `PHASE_07_DB_READ_CONTRACT.sql`

Los micro-pasos live previos se conservan como migrations reales o markers de historia según limitaciones del conector.

Un provisional `20260813210730...` nunca aplicado remotamente duplica idempotentemente `CREATE TABLE/INDEX IF NOT EXISTS` frente a la versión canónica `20260813210734...`; no introduce operación destructiva.

---

## Performance

Live:
- resolver completo de LEADS_UNWORKED (1,292 keys): ~739 ms
- list activations vacío: ~75 ms

PASS contra objetivo normal `<1.5 s`.

No se agregaron índices/triggers a tablas operativas.

---

## Frontend

Nuevos:
- `admin-activaciones.html`
- `admin-activaciones.css`
- `admin-activaciones.js`

Integración:
- Bases & Audiencias muestra Fase 7
- Activaciones desbloqueado
- Distribución continúa bloqueada hasta F9
- Solicitudes continúa bloqueada hasta F13

Controller:
- 0 `alert()`
- 0 `confirm()`
- 0 `prompt()`
- 0 `/rest/v1/aos_*` direct reads

Incluye BATCH/DYNAMIC, creación, DRAFT/start now, cards, transitions, detalle, preview, event history y snapshot hashes.

---

## Compatibilidad

Después de desplegar Phase 7:
- 177 llamadas guardadas el 13-08-2026 al momento del gate;
- última escritura de llamadas observada posterior al despliegue.

Email legacy:
- `aos_email_audiencias`: 0
- `aos_email_campanias`: 0
- FK sigue `aos_email_campanias.audiencia_id → aos_email_audiencias.id`

Legacy snapshot:
- `aos_snapshot_global`: 1 fila, intacto.

---

## Residuos QA

Estado final antes del PR:
- snapshots: 0
- snapshot members: 0
- activations: 0
- activation config: 0
- activation state: 0
- activation events: 0
- audiences: 0

PASS: cero residuos.

---

## Gates

- P7-G01 baseline Git/Supabase: PASS
- P7-G02 Impact Report pre-DDL: PASS
- P7-G03 schema/FKs/checks: PASS
- P7-G04 snapshot build/seal contract: PASS
- P7-G05 snapshot immutability/hash: PASS
- P7-G06 activation BATCH contract: PASS
- P7-G07 activation DYNAMIC contract: PASS
- P7-G08 state machine/history: PASS
- P7-G09 list/get/preview: PASS
- P7-G10 security/RLS: PASS
- P7-G11 gateway authorization: PASS
- P7-G12 frontend contract/responsive: PASS
- P7-G13 performance: PASS
- P7-G14 Call Center/Email compatibility: PASS
- P7-G15 QA/no residue: PASS
- P7-G16 replayability + CI + PR: PENDING
- P7-G17 staging post-merge: PENDING
- P7-G18 roadmap + memory checkpoint: PENDING

Phase 7 permanece `VALIDATING` hasta cerrar G16–G18.
