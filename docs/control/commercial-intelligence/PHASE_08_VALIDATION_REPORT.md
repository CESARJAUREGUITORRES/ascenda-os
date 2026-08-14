# ASCENDA OS — FASE 8 VALIDATION REPORT

**Fase:** Channel Context & Availability  
**Estado:** `100_COMPLETE`  
**Fecha:** 2026-08-13  
**Baseline de entrada:** `6a422bfffcaaef610820633b50b6d2bf6c8e6429`  
**Merge funcional staging:** `6f1fdf5668ad067da58d9b1df37060f0ced4d429`  
**Functional PR:** #72  
**Ascenda CI:** #553 SUCCESS

## Resultado

Fase 8 queda certificada con el contrato:

`Audience Total → Eligible for Context → Available Now`

Fase 9 debe consumir exclusivamente `aos_cia_activation_available_keys_v1(activation_id)` y no reinterpretar por su cuenta elegibilidad/disponibilidad.

UNKNOWN nunca es asignable.

## Conexión Fase 7 → Fase 8

Phase 8 consume correctamente:
- Activation identity/config/state de Fase 7;
- BATCH desde snapshot inmutable;
- DYNAMIC desde la versión fijada;
- facts, segmentation y email current-state.

Durante el primer QA BATCH se detectó y corrigió una deuda real de Fase 7: `pgcrypto` está en schema `extensions`, mientras snapshot create/seal usaban `digest()` con `search_path=public`.

Fix certificado:
- `20260814032421_cia_phase7_snapshot_pgcrypto_fix_v1.sql`
- `extensions.digest(...)` explícito en snapshot create + seal guard.

Después del fix:
- BATCH snapshot real sella correctamente;
- DYNAMIC resolver usa `filter_dsl->'root'` igual que Fase 7;
- paridad BATCH/DYNAMIC aprobada.

## Policy registry / binding

Objetos:
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

Policy y binding son inmutables y versionados. Binding valida compatibilidad exacta entre channel de Activation y channel de Policy.

## Semántica

Per-contact:
- eligibility: `ELIGIBLE | INELIGIBLE | UNKNOWN`
- availability: `AVAILABLE | UNAVAILABLE | UNKNOWN`
- `is_assignable=true` solo con Activation ACTIVE + ELIGIBLE + AVAILABLE.

Razones determinísticas incluyen:
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

Warning V1:
- EMAIL_BOUNCE_HISTORY

## QA real rollback-only

Preset: `LEADS_UNWORKED_7D`, total live del momento = 116.

### CALL_GENERAL — DYNAMIC
- total 116
- eligible 111
- ineligible 5
- available 103
- assignable 103
- available_keys 103

### CALL_GENERAL — BATCH
- snapshot members 116
- total 116
- eligible 111
- ineligible 5
- available 103
- assignable 103
- available_keys 103

Asserts:
- DYNAMIC total = resolver live: PASS
- BATCH total = snapshot membership: PASS
- eligibility partition = total: PASS
- `available_now = available_keys`: PASS

### CALL_PROVINCE
Mismos 116 contactos:
- eligible 5
- ineligible 111
- available 5
- available_keys 5

PASS: `PROVINCIA` es routing contextual, no exclusión universal.

### EMAIL
- eligible 15
- ineligible 101
- available 13
- unavailable 2
- EMAIL_SENT_TODAY 2
- EMAIL_BOUNCE_HISTORY 3 warnings

Email validity quedó 1:1 con Fact Registry:
- Phase 8 = 1,579 válidos
- Profile Facts = 1,579 válidos

### SMS
- eligible 116
- availability UNKNOWN 116
- assignable 0
- CHANNEL_HISTORY_NOT_INTEGRATED 116

PASS: ausencia de channel history nunca se convierte en AVAILABLE.

## Freshness

Universe creció durante desarrollo de 11,473 a 11,520. Antes de evaluar se detectó stale cache y se refrescó controladamente.

Estado certificado:
- universe: 11,520
- segment cache: 11,520
- email cache: 11,520

Gateway/UI exponen `stale_dependencies` y pueden ejecutar refresh controlado.

## Seguridad

RLS activo en policy registry y activation context binding; 0 policies permisivas.

Rol anon:
- policies visibles 0
- bindings visibles 0
- INSERT directo rechazado por RLS.

Rol authenticated:
- policies visibles 0
- bindings visibles 0.

- gateway bad token → UNAUTHORIZED
- bind bad token → UNAUTHORIZED
- policy UPDATE/DELETE rechazados
- binding UPDATE/DELETE rechazados
- channel mismatch rechazado

## Performance

Audiencia representativa `LEADS_UNWORKED`: 1,277 contactos durante benchmark.

Warm:
- summary ~445 ms
- preview 50 ~436 ms
- explain ~434 ms
- available_keys ~437 ms

PASS.

No se agregaron índices ni triggers en operational write paths.

## Compatibilidad

No se modificaron:
- `aos_siguiente_lead`
- `aos_siguiente_lead_v2`
- `aos_cola_config`
- `aos_leads_en_curso` write path
- `calls.js`
- Agenda/Ventas/CRM writes
- Email legacy FK/tables.

Call Center post-merge:
- 349 llamadas guardadas en el día Lima al último smoke.

Email legacy:
- `aos_email_audiencias` 0
- `aos_email_campanias` 0
- FK legacy intacta.

Cita futura reconciliation:
- CIA/Lima 62
- legacy CURRENT_DATE server 61
- diferencia = 1 cita PENDIENTE del día Lima que UTC ya había desplazado al día anterior.

Phase 8 conserva timezone Lima y bloquea conservadoramente ese contacto; Call Center legacy no fue modificado.

## Frontend

Nuevos:
- `admin-activaciones-context.js`
- `admin-activaciones-context.css`
- tab Contexto & disponibilidad en `admin-activaciones.html`.

Funciones:
- freshness + refresh
- selección de policy compatible
- binding explícito
- Total / Eligible / Available / Unknown
- reasons/warnings
- preview contextual
- explain per-contact
- Phase 9 handoff count.

Frontend audit:
- 0 `alert()`
- 0 `confirm()`
- 0 `prompt()`
- 0 direct `/rest/v1/aos_*` reads.

## Replayability

Git filenames = Supabase live migration versions:
- `20260814031448_cia_phase8_context_schema_v1.sql`
- `20260814031521_cia_phase8_context_guards_v1.sql`
- `20260814031701_cia_phase8_context_engine_v1.sql`
- `20260814031808_cia_phase8_context_contracts_v1.sql`
- `20260814031847_cia_phase8_admin_gateway_v1.sql`
- `20260814032105_cia_phase8_dynamic_root_fix_v1.sql`
- `20260814032421_cia_phase7_snapshot_pgcrypto_fix_v1.sql`
- `20260814032849_cia_phase8_email_validity_fix_v1.sql`

## No-residue

Post-QA/post-merge:
- QA audiences 0
- QA activations 0
- QA snapshots 0
- context bindings 0 (no real activation bound yet)
- 8 system policies persist intentionally.

## Gates

P8-G01…P8-G18: **PASS**.

- functional PR #72 MERGED
- CI #553 SUCCESS
- staging merge `6f1fdf5668ad067da58d9b1df37060f0ced4d429`
- post-merge smoke PASS
- closure docs + `aos_memory` complete this certification.

## Phase 9 handoff

**Authoritative input:**
`aos_cia_activation_available_keys_v1(activation_id)`

Fase 9 may allocate only those keys. It must preserve Assignment as a separate object and still must not alter Call Center routing until Phase 11 feature-flagged integration.
