# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 8:** `6f1fdf5668ad067da58d9b1df37060f0ced4d429`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

## Regla de estado

Estados: `NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`.

Una fase solo es `100_COMPLETE` con gates verificados, integración a `staging` y checkpoint final GitHub + `aos_memory`.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `100_COMPLETE` | 100% |
| 2 | Commercial Facts | `100_COMPLETE` | 100% |
| 3 | Segmentation Engine | `100_COMPLETE` | 100% |
| 4 | Audience Resolver | `100_COMPLETE` | 100% |
| 5 | Panel Central Skeleton | `100_COMPLETE` | 100% |
| 6 | Audience Library Persistence | `100_COMPLETE` | 100% |
| 7 | Snapshots & Activation | `100_COMPLETE` | 100% |
| 8 | Channel Context & Availability | `100_COMPLETE` | 100% |
| 9 | Assignment Engine | `READY` | 0% |
| 10 | Advisor Control Center | `NOT_STARTED` | 0% |
| 11 | Call Center Integration V3 | `NOT_STARTED` | 0% |
| 12 | Advisor Work Views | `NOT_STARTED` | 0% |
| 13 | Requests & Approvals | `NOT_STARTED` | 0% |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | 0% |
| 15 | KronIA + Multiagent | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CIERRES CERTIFICADOS

## Fases 0–4

- F0 Baseline & Contracts: P0-G01…G09 PASS.
- F1 Identity Resolver: P1-G01…G11 PASS; PR #50 / CI 274.
- F2 Commercial Facts: P2-G01…G14 PASS; PR #55 / CI 293.
- F3 Segmentation: P3-G01…G14 PASS; PR #57 / CI 308.
- F4 Audience Resolver: P4-G01…G16 PASS; DSL whitelisted, Count/Preview/Explain, MATCH/MISS/UNKNOWN; PR #59 / CI 342.

## Fase 5 — Panel Central Skeleton

`100_COMPLETE`. Bases & Audiencias, Resolver V2, CIA gateway/admin session, frontend nativo y seguridad. PR #62 / CI #389; cierre PR #64.

## Fase 6 — Audience Library Persistence

`100_COMPLETE`. `aos_audiencias` + versiones inmutables + audit; optimistic concurrency, duplicate/archive/restore. PR #65 / CI #418; cierre PR #67.

## Fase 7 — Snapshots & Activation

`100_COMPLETE`.

Entrega:
- snapshot membership inmutable + SHA-256;
- BATCH = FROZEN_SNAPSHOT;
- DYNAMIC = DYNAMIC_LIVE sobre versión fijada;
- facts LIVE;
- Activation Aggregate identity/config/state/events;
- lifecycle protegido;
- event audit append-only, DB como única fuente lifecycle;
- admin Activaciones.

Integración:
- PR #69 / CI #510;
- functional merge `d90b5ef7a4f960c86655ecb0712286f02d059b81`;
- closure PR #70 / CI #516;
- closure `6a422bfffcaaef610820633b50b6d2bf6c8e6429`.

## Fase 8 — Channel Context & Availability

`100_COMPLETE` — P8-G01…P8-G18 PASS.

### Entrega

Contrato canónico:
`Audience Total → Eligible for Context → Available Now`.

Objetos:
- `aos_cia_context_policies`;
- `aos_audiencia_activacion_context`.

Policies V1:
- CALL_GENERAL / CALL_PROVINCE;
- EMAIL_GENERAL;
- SMS_GENERAL / WHATSAPP_GENERAL;
- ANALYSIS_GENERAL / AUTOMATION_GENERAL / OTHER_GENERAL.

Semántica:
- eligibility: ELIGIBLE / INELIGIBLE / UNKNOWN;
- availability: AVAILABLE / UNAVAILABLE / UNKNOWN;
- `is_assignable=true` únicamente con Activation ACTIVE + ELIGIBLE + AVAILABLE;
- UNKNOWN nunca es asignable.

Handoff autoritativo Fase 9:
`aos_cia_activation_available_keys_v1(activation_id)`.

### Integración F7→F8

Primer BATCH real detectó deuda de F7: pgcrypto está en `extensions` pero snapshot usaba `digest()` bajo `search_path=public`.

Corregido por:
`20260814032421_cia_phase7_snapshot_pgcrypto_fix_v1.sql`.

Después del fix BATCH/DYNAMIC aprobaron paridad.

### QA

Preset LEADS_UNWORKED_7D durante QA: 116.

CALL_GENERAL:
- total 116;
- eligible 111;
- available 103;
- available_keys 103;
- BATCH snapshot 116 y DYNAMIC 116.

CALL_PROVINCE:
- eligible 5;
- available 5.

EMAIL:
- eligible 15;
- available 13;
- EMAIL_SENT_TODAY 2;
- bounce = warning.

SMS:
- eligible 116;
- availability UNKNOWN 116;
- assignable 0.

Freshness certificado:
- universe 11,520;
- segment cache 11,520;
- email cache 11,520.

Performance representativa sobre 1,277 contactos:
- summary ~445 ms;
- preview 50 ~436 ms;
- explain ~434 ms;
- available_keys ~437 ms.

Seguridad:
- RLS deny-by-default;
- 0 policies permisivas;
- anon/authenticated ven 0 rows;
- gateway + binding mutator requieren CIA admin token;
- policies/bindings inmutables.

Compatibilidad:
- `aos_siguiente_lead`, V2, `aos_cola_config`, `calls.js` intactos;
- 349 llamadas observadas en smoke;
- Email legacy/FK intactos;
- 0 QA residue.

Frontend:
- tab Contexto & disponibilidad;
- policy binding;
- Total/Eligible/Available/Unknown;
- reasons/warnings;
- preview + explain;
- Phase 9 handoff visible;
- no Assignment todavía.

Integración:
- functional PR #72;
- Ascenda CI #553 SUCCESS;
- staging merge `6f1fdf5668ad067da58d9b1df37060f0ced4d429`;
- post-merge smoke PASS.

Detalle:
- `PHASE_08_CHANNEL_CONTEXT_AVAILABILITY.md`;
- `PHASE_08_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## FASE 9 — ASSIGNMENT ENGINE = READY

Entrada autoritativa:
`aos_cia_activation_available_keys_v1(activation_id)`.

Reglas de entrada:
- Assignment es objeto separado de Audience, Snapshot y Activation;
- solo contactos Phase 8 `is_assignable=true` pueden asignarse;
- IDs de asesor = `aos_usuarios.id`, nunca nombres hardcoded;
- no doble ownership activo cuando policy lo prohíba;
- lifecycle mínimo: RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED / RELEASED / EXPIRED;
- distribución: 100% uno, equal, percentages, fixed quantities, remainder, priority;
- top-up: NONE / MAINTAIN_TARGET / CONTINUOUS;
- capacidad/frescura explícitas;
- no modificar `aos_siguiente_lead` todavía: integración Call Center V3 sigue en Fase 11 detrás de feature flag;
- Impact Report antes de DDL.

---

# LOOP UNIVERSAL

`baseline → scope → impact → branch → isolated implementation → checks → tests → real-data comparison → edge cases → roles → responsive → staging → E2E → rollback → rollout → observation → closure docs → memory checkpoint`

---

# CONTINUIDAD

Recuperar en orden:
1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`;
4. este roadmap;
5. `PHASE_08_VALIDATION_REPORT.md`;
6. `cia_v3_*` / `cia_phase_*` en `aos_memory`;
7. verificar `staging` + Supabase live antes de Fase 9.
