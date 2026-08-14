# ASCENDA OS — FASE 7 VALIDATION REPORT

**Fase:** Snapshots & Activation  
**Estado:** 100_COMPLETE  
**Fecha:** 2026-08-13  
**Baseline de entrada:** `d17eaa8cabfeae88c9442246f542b2e18b2a1691`  
**Merge funcional staging:** `d90b5ef7a4f960c86655ecb0712286f02d059b81`

## Resultado ejecutivo

Fase 7 queda certificada. Mantiene las fronteras:
- Audience Definition ≠ Snapshot.
- Snapshot ≠ Activation.
- Activation ≠ Assignment.
- `channel` es contexto; Fase 7 no ejecuta envíos ni llamadas.
- no modifica `aos_siguiente_lead`, `aos_cola_config`, Call Center, Email legacy ni fuentes operativas.

## Persistencia

Snapshot:
- `aos_audiencia_snapshots`
- `aos_audiencia_snapshot_miembros`

Activation Aggregate:
- `aos_audiencia_activaciones`
- `aos_audiencia_activacion_config`
- `aos_audiencia_activacion_estado`
- `aos_audiencia_activacion_eventos`

Identidad/configuración son inmutables; lifecycle es mutable únicamente por máquina de estados; eventos son append-only.

## Snapshot contract

- audience/version exacta;
- BUILDING → READY;
- header y members inmutables tras sello;
- count físico validado al sellar;
- `membership_hash` SHA-256 de contact keys ordenados;
- `filter_hash` SHA-256;
- máximo 100,000 miembros;
- membership congelada; Commercial Facts posteriores continúan LIVE y la API/UI lo declara.

Paridad resolver:
- FOLLOWUP_OVERDUE: 442 = 442
- LEADS_UNWORKED: 1,292 = 1,292
- LEADS_UNWORKED_7D: 126 = 126
- NO_SHOW_NO_FUTURE: 822 = 822

PASS.

## Activation semantics

BATCH:
- snapshot obligatorio y READY;
- misma audience/version;
- `membership_mode=FROZEN_SNAPSHOT`;
- `facts_mode=LIVE`.

DYNAMIC:
- snapshot prohibido;
- versión fijada;
- `membership_mode=DYNAMIC_LIVE`;
- `facts_mode=LIVE`.

Lifecycle:
- DRAFT → ACTIVE | CANCELLED
- ACTIVE → PAUSED | COMPLETED | CANCELLED
- PAUSED → ACTIVE | COMPLETED | CANCELLED
- COMPLETED/CANCELLED terminales.

## Audit lifecycle — single source

Hardening final:
- `20260813220108_cia_phase7_state_event_emitter_v2`
- `20260813220123_cia_phase7_state_event_emitter_trigger_v2`
- `20260814024344_cia_phase7_rpc_event_single_source_v2`

La base de datos es la única fuente de eventos lifecycle. Los RPC `CREATE` y `TRANSITION` ya no insertan eventos manualmente.

QA real con rollback:
- CREATE = 1
- START = 1
- PAUSE = 1
- RESUME = 1
- COMPLETE = 1
- total = 5
- final state = COMPLETED
- residuos = 0

PASS: exactamente un evento por transición.

## Integridad y seguridad

Triggers físicos:
1. snapshot header guard
2. snapshot member guard
3. activation identity guard
4. activation config immutable
5. activation config validator
6. activation config relation
7. activation state guard
8. activation event immutable
9. activation state event emitter

Harness:
- terminal reopen rechazado;
- UPDATE/DELETE de eventos rechazados;
- DYNAMIC+snapshot rechazado;
- BATCH sin snapshot rechazado;
- channel fuera de whitelist rechazado.

Mutators/gateway `SECURITY DEFINER` con `search_path=public` y verificación CIA admin token:
- snapshot create
- activation create
- activation transition
- Phase 7 gateway

Pruebas negativas:
- snapshot create token inválido → UNAUTHORIZED
- activation create → UNAUTHORIZED
- transition → UNAUTHORIZED
- gateway → UNAUTHORIZED

RLS activo en los seis objetos y 0 policies permisivas Phase 7.
- anon: 0 filas visibles
- authenticated: 0 filas visibles
- INSERT directo anon: rechazado

Supabase conserva privilegios estándar de `service_role`; no se afirma SELECT-only para ese rol. La superficie browser permanece anon/authenticated + CIA gateway.

## Read contracts / límites

- list activations
- get activation
- preview activation
- list snapshots
- list/preview ≤ 100
- gateway payload ≤ 64 KiB

## Replayability

Checkpoints live:
- `20260813214724_cia_phase7_read_contract_checkpoint_v1`
- `20260813214912_cia_phase7_gateway_checkpoint_v1`
- `20260813215012_cia_phase7_hardening_checkpoint_v1`
- `20260813220108_cia_phase7_state_event_emitter_v2`
- `20260813220123_cia_phase7_state_event_emitter_trigger_v2`
- `20260814024344_cia_phase7_rpc_event_single_source_v2`

Read source adicional: `PHASE_07_DB_READ_CONTRACT.sql`.

## Performance

- resolver completo LEADS_UNWORKED (1,292 keys): ~739 ms
- list activations vacío: ~75 ms

PASS contra objetivo normal `<1.5 s`.

## Frontend

- `admin-activaciones.html`
- `admin-activaciones.css`
- `admin-activaciones.js`
- acceso desde Bases & Audiencias.

Controller:
- 0 `alert()`
- 0 `confirm()`
- 0 `prompt()`
- 0 lecturas directas `/rest/v1/aos_*`

## Integración / compatibilidad

- PR #69 MERGED.
- Ascenda CI #510 SUCCESS.
- staging merge: `d90b5ef7a4f960c86655ecb0712286f02d059b81`.
- post-merge smoke: PASS.
- 349 llamadas guardadas hoy (Lima) al smoke.
- Email legacy/FK intactos.
- `aos_snapshot_global` legacy intacto.

Post-merge residues:
- snapshots: 0
- snapshot members: 0
- activations: 0
- activation events: 0
- audiences: 0

## Gates

- P7-G01 baseline Git/Supabase: PASS
- P7-G02 Impact Report pre-DDL: PASS
- P7-G03 schema/FKs/checks: PASS
- P7-G04 snapshot build/seal: PASS
- P7-G05 snapshot immutability/hash: PASS
- P7-G06 BATCH: PASS
- P7-G07 DYNAMIC: PASS
- P7-G08 state machine/history/single-event-source: PASS
- P7-G09 list/get/preview: PASS
- P7-G10 security/RLS: PASS
- P7-G11 gateway authorization: PASS
- P7-G12 frontend contract/responsive: PASS
- P7-G13 performance: PASS
- P7-G14 Call Center/Email compatibility: PASS
- P7-G15 QA/no residue: PASS
- P7-G16 replayability + CI + PR: PASS
- P7-G17 staging post-merge: PASS
- P7-G18 roadmap + memory checkpoint: PASS al completar el cierre documental y sincronizar `aos_memory` en este mismo loop.

**Resultado:** FASE 7 = `100_COMPLETE`; FASE 8 = `READY`.
