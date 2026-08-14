# ASCENDA OS — FASE 7 IMPLEMENTATION ADDENDUM

**Fecha:** 2026-08-13  
**Baseline:** `d17eaa8cabfeae88c9442246f542b2e18b2a1691`  
**Estado:** VALIDATING

Este documento complementa y, cuando existe diferencia, **supersede la sección de diseño físico** de `PHASE_07_SNAPSHOTS_ACTIVATION.md`. El documento original se conserva como Impact Report pre-DDL.

## Arquitectura realmente desplegada

### Snapshot
- `aos_audiencia_snapshots`: header BUILDING/READY, count, filter SHA-256, membership SHA-256, resolved/sealed timestamps.
- `aos_audiencia_snapshot_miembros`: `snapshot_id + contact_key`, identity status/conflict observado al congelar.

Membership queda frozen. Los Commercial Facts mostrados al revisar miembros siguen siendo LIVE.

### Activation Aggregate
La activación se normalizó para evitar que una transición de estado pueda cambiar su definición:
- `aos_audiencia_activaciones`: identidad audience/version, inmutable.
- `aos_audiencia_activacion_config`: nombre, purpose, channel/context, mode, snapshot, baseline y metadata, inmutable.
- `aos_audiencia_activacion_estado`: lifecycle mutable.
- `aos_audiencia_activacion_eventos`: historial append-only.

Estados: `DRAFT | ACTIVE | PAUSED | COMPLETED | CANCELLED`.

Transiciones:
- DRAFT → ACTIVE | CANCELLED
- ACTIVE → PAUSED | COMPLETED | CANCELLED
- PAUSED → ACTIVE | COMPLETED | CANCELLED
- COMPLETED/CANCELLED terminales.

## BATCH vs DYNAMIC

**BATCH**
- crea snapshot transaccional;
- snapshot debe ser READY y corresponder a la misma audience/version;
- membership congelada;
- count semántico `FROZEN_SNAPSHOT`;
- facts mostrados = LIVE.

**DYNAMIC**
- prohíbe snapshot;
- fija la versión de audiencia;
- membership se resuelve live;
- count semántico `DYNAMIC_LIVE`;
- facts = LIVE.

`channel` es `context_only`; Fase 7 no envía mensajes, no calcula eligibility/availability y no asigna asesores.

## Integridad física

Snapshot header guard:
- solo BUILDING al crear;
- valida audience/version;
- única mutación válida BUILDING→READY;
- al sellar recalcula count y SHA-256 sobre contact keys ordenados;
- identidad/header y DELETE quedan bloqueados después del sello.

Snapshot members guard:
- INSERT solo mientras snapshot BUILDING;
- UPDATE/DELETE rechazados.

Activation guards:
- identity immutable;
- config immutable;
- config valida whitelist de channel/mode/metadata y contrato BATCH/DYNAMIC;
- BATCH snapshot debe READY y pertenecer a la misma audience/version;
- state machine impide no-op, DELETE y transiciones ilegales;
- eventos rechazan UPDATE/DELETE.

## Superficie administrativa

Mutators:
- `aos_cia_snapshot_create_admin_v1`
- `aos_cia_activation_create_admin_v1`
- `aos_cia_activation_transition_admin_v1`

Gateway:
- `aos_cia_phase7_admin_gateway_v1`

Todos los mutators y el gateway verifican una sesión CIA administrativa antes de escribir. El actor se deriva de esa sesión.

Read contracts:
- `aos_cia_activation_list_internal_v1`
- `aos_cia_activation_get_internal_v1`
- `aos_cia_activation_preview_internal_v1`
- `aos_cia_snapshot_list_internal_v1`

## Checkpoints canónicos live

- `20260813214724_cia_phase7_read_contract_checkpoint_v1`
- `20260813214912_cia_phase7_gateway_checkpoint_v1`
- `20260813215012_cia_phase7_hardening_checkpoint_v1`

El Git connector bloqueó el cuerpo de los read functions dentro de `supabase/migrations`; el SQL ejecutable exacto del checkpoint read está versionado en `PHASE_07_DB_READ_CONTRACT.sql`. El archivo de migration conserva el checkpoint remoto.

Existe un provisional `20260813210730...` no aplicado remotamente y una versión canónica `20260813210734...`; ambos usan `CREATE ... IF NOT EXISTS`, por lo que el replay del provisional es idempotente y no destructivo.

## Seguridad efectiva

RLS está habilitado en los seis objetos y no existen policies permisivas. Pruebas directas:
- `anon`: 0 filas visibles;
- `authenticated`: 0 filas visibles;
- INSERT directo como `anon`: rechazado;
- token administrativo inválido en gateway/mutators: `UNAUTHORIZED`.

Supabase conserva privilegios estándar del rol server-side `service_role`; el conector disponible no permitió DCL `REVOKE`. Por lo tanto, la certificación no declara `service_role` como SELECT-only. El navegador no dispone de ese rol.

## Paridad del resolver

Count V2 vs conjunto completo resuelto:
- FOLLOWUP_OVERDUE 442 = 442
- LEADS_UNWORKED 1,292 = 1,292
- LEADS_UNWORKED_7D 126 = 126
- NO_SHOW_NO_FUTURE 822 = 822

## Frontend

Nuevos archivos:
- `admin-activaciones.html`
- `admin-activaciones.css`
- `admin-activaciones.js`

`admin-audiencias.html` desbloquea la navegación a Activaciones; Distribución continúa reservada para F9 y Solicitudes para F13.

Checks del controller:
- 0 `alert()`
- 0 `confirm()`
- 0 `prompt()`
- 0 lecturas directas `/rest/v1/aos_*`

La sesión CIA se obtiene en Bases & Audiencias; Activaciones la reutiliza y no implementa una segunda autenticación.
