# ASCENDA OS — FASE 8 VALIDATION REPORT

**Fase:** Channel Context & Availability  
**Estado:** VALIDATING  
**Fecha:** 2026-08-13  
**Baseline staging:** `6a422bfffcaaef610820633b50b6d2bf6c8e6429`

## Resultado ejecutivo

Fase 8 implementa el contrato:

`Audience Total → Eligible for Context → Available Now`

sin crear Assignment, sin ejecutar canales y sin modificar Call Center.

El handoff de Fase 9 queda definido por `aos_cia_activation_available_keys_v1(activation_id)`; UNKNOWN nunca entra en ese set.

## Continuidad Fase 7 → Fase 8

Phase 8 consume:
- Activation identity/config/state de Fase 7;
- BATCH desde snapshot inmutable;
- DYNAMIC desde la versión de audiencia fijada;
- Facts/segments/email actuales.

Durante el primer QA BATCH real se detectó una deuda de Fase 7: `pgcrypto` está en schema `extensions`, pero snapshot seal/create invocaban `digest()` bajo `search_path=public`.

Se corrigió mediante migration canónica:
- `20260814032421_cia_phase7_snapshot_pgcrypto_fix_v1.sql`

Solo se calificó `extensions.digest(...)`; no se modificó auth, Call Center ni semántica de snapshot.

Después del fix, BATCH y DYNAMIC pasaron paridad completa.

## Persistencia / políticas

Nuevos objetos:
- `aos_cia_context_policies`
- `aos_audiencia_activacion_context`

Policies V1:
- CALL_GENERAL
- CALL_PROVINCE
- EMAIL_GENERAL
- SMS_GENERAL
- WHATSAPP_GENERAL
- ANALYSIS_GENERAL
- AUTOMATION_GENERAL
- OTHER_GENERAL

Policy y binding son inmutables. Binding valida channel de activation contra channel de policy.

## Semántica

Estados por contacto:
- eligibility: ELIGIBLE / INELIGIBLE / UNKNOWN
- availability: AVAILABLE / UNAVAILABLE / UNKNOWN
- `is_assignable=true` solo con activation ACTIVE + ELIGIBLE + AVAILABLE.

UNKNOWN nunca se convierte en AVAILABLE.

Reason taxonomy incluye:
- PHONE_INVALID
- EMAIL_INVALID
- EMAIL_IDENTITY_UNKNOWN
- EMAIL_FRESHNESS_UNKNOWN
- CURRENTLY_DISQUALIFIED
- CURRENT_PROVINCE_ROUTE
- NOT_PROVINCE_ROUTE
- CALLED_TODAY
- EMAIL_SENT_TODAY
- FUTURE_APPOINTMENT
- LEGACY_WORK_IN_PROGRESS
- CHANNEL_HISTORY_NOT_INTEGRATED

Warnings:
- EMAIL_BOUNCE_HISTORY

## QA real con rollback — BATCH + DYNAMIC

Preset usado: `LEADS_UNWORKED_7D`.
Conteo live durante el QA: 116.

CALL_GENERAL DYNAMIC:
- total 116
- eligible 111
- ineligible 5
- available_now 103
- assignable_now 103
- available_keys 103

CALL_GENERAL BATCH:
- snapshot member_count 116
- total 116
- eligible 111
- ineligible 5
- available_now 103
- assignable_now 103
- available_keys 103

Asserts:
- DYNAMIC total = resolver live: PASS
- BATCH total = snapshot = resolver al congelar: PASS
- eligibility partitions = total: PASS
- available_now = Phase 9 available_keys: PASS

## CALL_PROVINCE

Sobre los mismos 116 contactos:
- eligible 5
- ineligible 111
- available_now 5
- available_keys 5

PASS: PROVINCIA es una ruta contextual específica; no una exclusión universal.

## EMAIL

Sobre los mismos 116 contactos durante QA:
- eligible 15
- ineligible 101
- available_now 13
- unavailable_now 2
- EMAIL_SENT_TODAY: 2
- EMAIL_BOUNCE_HISTORY: 3 warnings

Email validity de Phase 8 fue alineado exactamente con Profile Facts:
- Phase 8 valid: 1,579
- Profile Facts `email_valid=true`: 1,579

Historical bounce sigue siendo warning y no causal blocker V1.

## SMS / WhatsApp

SMS QA:
- eligible 116
- availability_unknown 116
- assignable_now 0
- reason CHANNEL_HISTORY_NOT_INTEGRATED = 116

PASS: falta de outbound history nunca se convierte en AVAILABLE.

## Freshness

Al iniciar Phase 8 el universo había crecido de 11,473 a 11,520, mientras Segment/Email caches seguían en 11,473.

Se ejecutó refresh controlado y el estado final pre-PR es:
- profile universe: 11,520
- segment cache: 11,520
- email cache: 11,520

Gateway Phase 8 expone `stale_dependencies` y UI refresca dependencias antes de evaluar si detecta drift.

## Seguridad / RLS

RLS activo en:
- `aos_cia_context_policies`
- `aos_audiencia_activacion_context`

Policies permisivas: 0.

Rol anon:
- policies visibles: 0
- bindings visibles: 0
- INSERT directo: rechazado por RLS.

Rol authenticated:
- policies visibles: 0
- bindings visibles: 0.

Gateway con token inválido → UNAUTHORIZED.
Bind mutator con token inválido → UNAUTHORIZED.

Inmutabilidad QA:
- policy UPDATE rechazado
- policy DELETE rechazado
- binding UPDATE rechazado
- binding DELETE rechazado
- policy/channel mismatch rechazado

## Performance

Audiencia representativa `LEADS_UNWORKED` durante benchmark: 1,277 contactos.

Warm measurements:
- context summary: ~445 ms
- preview 50: ~436 ms
- explain: ~434 ms
- available_keys: ~437 ms

PASS contra targets Phase 8.

No se agregaron nuevos índices ni triggers sobre tablas operativas.

## Call Center compatibility

No se modificaron:
- `aos_siguiente_lead`
- `aos_siguiente_lead_v2`
- `aos_cola_config`
- `aos_leads_en_curso` write path
- `calls.js`

Smoke pre-PR:
- 349 llamadas guardadas durante el día Lima
- última escritura observada posterior al despliegue Phase 8.

Reconciliación cita futura:
- CIA/Lima: 62 contactos
- legacy view/server CURRENT_DATE: 61
- diferencia: 1 cita PENDIENTE del día Lima que el servidor UTC ya consideraba día anterior.

Phase 8 conserva la interpretación Lima y bloquea conservadoramente ese contacto. Call Center legacy no fue modificado en esta fase.

## Email legacy compatibility

- `aos_email_audiencias`: 0
- `aos_email_campanias`: 0
- FK `aos_email_campanias.audiencia_id → aos_email_audiencias.id` intacta.

## QA residue

Final pre-PR:
- QA audiences: 0
- QA activation configs: 0
- context bindings: 0
- recent QA snapshots: 0

PASS.

## Frontend

Phase 8 se integra como módulo separado:
- `admin-activaciones-context.js`
- `admin-activaciones-context.css`
- tab Contexto & disponibilidad en `admin-activaciones.html`.

Capacidades:
- freshness visible y refresh controlado
- policy compatible por channel
- binding explícito/inmutable
- Total / Elegibles / Disponibles / Unknown
- reason counts y warning counts
- preview contextual
- explain por contacto
- indicador de handoff Phase 9

Audit del controller:
- 0 alert()
- 0 confirm()
- 0 prompt()
- 0 direct `/rest/v1/aos_*` table reads

Distribución/Assignment continúa fuera de Phase 8.

## Replayability

Git filenames fueron alineados con las versiones live reales de Supabase:
- `20260814031448_cia_phase8_context_schema_v1.sql`
- `20260814031521_cia_phase8_context_guards_v1.sql`
- `20260814031701_cia_phase8_context_engine_v1.sql`
- `20260814031808_cia_phase8_context_contracts_v1.sql`
- `20260814031847_cia_phase8_admin_gateway_v1.sql`
- `20260814032105_cia_phase8_dynamic_root_fix_v1.sql`
- `20260814032421_cia_phase7_snapshot_pgcrypto_fix_v1.sql`
- `20260814032849_cia_phase8_email_validity_fix_v1.sql`

## Phase 9 contract

Authoritative assignment input:
`aos_cia_activation_available_keys_v1(activation_id)`

Fase 9 must not independently reinterpret eligibility/availability.
It may distribute only this set and still must not change Call Center until Phase 11 feature-flagged integration.

## Gates

- P8-G01 baseline / Phase 7 continuity: PASS
- P8-G02 Impact Report pre-DDL: PASS
- P8-G03 policy registry / versioning: PASS
- P8-G04 activation context binding: PASS
- P8-G05 deterministic eligibility: PASS
- P8-G06 deterministic availability: PASS
- P8-G07 reason taxonomy / explain: PASS
- P8-G08 BATCH membership parity: PASS
- P8-G09 DYNAMIC membership parity: PASS
- P8-G10 UNKNOWN semantics: PASS
- P8-G11 security / RLS / gateway: PASS
- P8-G12 frontend / responsive contract: PASS
- P8-G13 performance: PASS
- P8-G14 Call Center / Email compatibility: PASS
- P8-G15 QA / no residue: PASS
- P8-G16 replayability + CI + PR: PENDING
- P8-G17 staging post-merge: PENDING
- P8-G18 roadmap + memory checkpoint: PENDING

Phase 8 remains VALIDATING until G16–G18 close.
