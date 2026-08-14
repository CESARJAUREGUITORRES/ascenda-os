# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 7:** `d90b5ef7a4f960c86655ecb0712286f02d059b81`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

# REGLA DE ESTADO

Estados: `NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`.

Una fase solo es `100_COMPLETE` cuando sus gates tienen evidencia, el cambio está integrado en `staging` y existe checkpoint final en GitHub + `aos_memory`.

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
| 8 | Channel Context & Availability | `READY` | 0% |
| 9 | Assignment Engine | `NOT_STARTED` | 0% |
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

## Fase 0 — Baseline & Contracts
P0-G01…P0-G09 PASS. Product Spec/Impact Report V3, Fact Registry, Frontend Contract, baseline y continuidad establecidos.

## Fase 1 — Identity Resolver
P1-G01…P1-G11 PASS. Resolver transversal de identidad/contact key con conflictos explícitos. PR #50 / CI 274 SUCCESS.

## Fase 2 — Commercial Facts
P2-G01…P2-G14 PASS. Facts 1:1 por contacto para Leads, Calls, Agenda, Sales, Followups y Email. PR #55 / CI 293 SUCCESS.

## Fase 3 — Segmentation Engine
P3-G01…P3-G14 PASS. Customer Tier Engine SHADOW V1; tier económico separado de traits/lifecycle/engagement. PR #57 / CI 308 SUCCESS.

## Fase 4 — Audience Resolver
P4-G01…P4-G16 PASS. DSL whitelisted, AND/OR, Validate/Count/Preview/Explain, MATCH/MISS/UNKNOWN, Producto/Servicio y presets oficiales. PR #59 / CI 342 SUCCESS.

## Fase 5 — Panel Central Skeleton
`100_COMPLETE`. Panel ADMIN Bases & Audiencias, Resolver V2, CIA gateway/admin session, frontend contract y seguridad. PR #62 / CI #389; cierre documental PR #64.

## Fase 6 — Audience Library Persistence
`100_COMPLETE`. Biblioteca universal `aos_audiencias` + versiones inmutables + audit; optimistic concurrency, duplicate/archive/restore, UI y gateway. PR #65 / CI #418; cierre documental PR #67.

## Fase 7 — Snapshots & Activation
`100_COMPLETE`.

### Entrega
- snapshots inmutables de membership;
- `membership_hash` y `filter_hash` SHA-256;
- member identity status/conflict observado al congelar;
- Activation Aggregate separado en identity/config/state/events;
- BATCH = membership `FROZEN_SNAPSHOT`;
- DYNAMIC = membership `DYNAMIC_LIVE` sobre versión fijada;
- Commercial Facts permanecen LIVE en ambos modos;
- lifecycle DRAFT / ACTIVE / PAUSED / COMPLETED / CANCELLED;
- estados terminales no reabribles;
- event history append-only;
- DB trigger como única fuente de eventos lifecycle;
- gateway CIA Phase 7;
- panel `admin-activaciones.html/css/js` integrado desde Bases & Audiencias.

### Integridad
- snapshot header/members inmutables tras sello;
- BATCH exige snapshot READY y misma audience/version;
- DYNAMIC prohíbe snapshot;
- RLS activo en seis objetos sin policies permisivas;
- mutators verifican CIA admin token;
- preview/list server-side limitados a 100;
- payload gateway ≤64 KiB.

### QA certificado
Paridad Count V2 vs snapshot resolver:
- FOLLOWUP_OVERDUE 442=442;
- LEADS_UNWORKED 1292=1292;
- LEADS_UNWORKED_7D 126=126;
- NO_SHOW_NO_FUTURE 822=822.

Lifecycle event cardinality con rollback:
- CREATE=1;
- START=1;
- PAUSE=1;
- RESUME=1;
- COMPLETE=1;
- total=5;
- final=COMPLETED;
- residuos=0.

Performance:
- resolver 1,292 keys ~739 ms;
- list activations vacío ~75 ms;
- PASS objetivo normal <1.5 s.

Compatibilidad:
- `aos_siguiente_lead`, `aos_cola_config` y Call Center sin cambios;
- Email legacy/FK intactos;
- `aos_snapshot_global` legacy intacto;
- 349 llamadas guardadas el día del smoke post-merge.

Integración:
- PR #69 MERGED;
- Ascenda CI #510 SUCCESS;
- merge funcional staging `d90b5ef7a4f960c86655ecb0712286f02d059b81`;
- post-merge smoke PASS.

Documentos:
- `PHASE_07_SNAPSHOTS_ACTIVATION.md`;
- `PHASE_07_IMPLEMENTATION_ADDENDUM.md`;
- `PHASE_07_VALIDATION_REPORT.md`;
- `PHASE_07_DB_READ_CONTRACT.sql`.

---

# SIGUIENTE FASE

## FASE 8 — CHANNEL CONTEXT & AVAILABILITY = READY

Objetivo: calcular, por activation/contexto, **total audience ≠ eligible ≠ available now**, con razones determinísticas de exclusión y sin duplicar la audiencia.

Reglas de entrada:
- Phase 7 Activation es el contexto canónico de uso;
- BATCH/DYNAMIC deben conservar su semántica de membership;
- Channel Context no envía mensajes ni asigna asesores;
- elegibilidad y disponibilidad deben ser separadas y explicables;
- reglas Call Center históricas no se convierten automáticamente en supresión universal;
- Email/Call/SMS/WhatsApp deben tener adaptadores contextuales independientes;
- SMS/WhatsApp outbound continúan bloqueados donde falte infraestructura de preferencia/tracking;
- no modificar `aos_siguiente_lead` todavía;
- Impact Report antes de DDL.

---

# LOOP UNIVERSAL

`baseline → scope → impact → branch → isolated implementation → checks → tests → real-data comparison → edge cases → roles → responsive → staging → E2E → rollback → rollout → observation → closure docs → memory checkpoint`

---

# CONTINUIDAD

New chats recover in order:
1. `AGENTS.md`.
2. `docs/control/ASCENDA_CONTROL_MASTER.md`.
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`.
4. this roadmap.
5. current phase document.
6. `cia_v3_*` / `cia_phase_*` in `aos_memory`.
7. live staging/GitHub + Supabase before changes.
