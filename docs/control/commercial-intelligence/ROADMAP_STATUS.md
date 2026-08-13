# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 6:** `78da0bf4561f53100df17717051d2ab3db621040`  
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
| 7 | Snapshots & Activation | `READY` | 0% |
| 8 | Channel Context & Availability | `NOT_STARTED` | 0% |
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

# FASES 0–4 — CIERRE

## Fase 0 — Baseline & Contracts

P0-G01…P0-G09 PASS. Product Spec/Impact Report V3, Fact Registry V1, Frontend Contract, baseline y continuidad establecidos.

## Fase 1 — Identity Resolver

P1-G01…P1-G11 PASS.
- 11,473 contact keys.
- 7,041 RESOLVED.
- 23 CONFLICT.
- 10 FUSED_ONLY.
- 4,399 NO_PATIENT_PROFILE.
- PR #50 / CI 274 SUCCESS.

## Fase 2 — Commercial Facts

P2-G01…P2-G14 PASS.
- Facts 1:1 por contacto para Leads, Calls, Agenda, Sales, Followups y Email.
- Email engagement consolidado con evidencia mapeada/no resuelta.
- PR #55 / CI 293 SUCCESS.

## Fase 3 — Segmentation Engine

P3-G01…P3-G14 PASS.
- Customer Tier Engine SHADOW V1.
- STANDARD / PREMIUM / GOLD / DIAMANTE separados de traits conductuales.
- Explicable y versionado.
- PR #57 / CI 308 SUCCESS.

## Fase 4 — Audience Resolver

P4-G01…P4-G16 PASS.
- Profile Facts + Audience Source.
- Filter Registry whitelisted.
- DSL V1, AND/OR, máximo 25 reglas y profundidad visual 2.
- Validate / Count / Preview / Explain determinísticos.
- `MATCH / MISS / UNKNOWN`.
- Separación Producto / Servicio.
- `never_contains` seguro ante evidencia no resuelta.
- Presets oficiales.
- No dynamic SQL.
- PR #59 / Ascenda CI 342 SUCCESS.

La deuda física que existía al cierre documental original de Fase 4 quedó eliminada durante Fase 5: los contratos necesarios fueron desplegados y revalidados físicamente en Supabase antes de habilitar el panel.

---

# FASE 5 — PANEL CENTRAL SKELETON = 100_COMPLETE

Panel ADMIN **Bases & Audiencias** integrado en `app/public/` con Dashboard, Presets, Constructor DSL, Preview, Explain, Segmentación y frescura explícita de caches.

Runtime V2:
- `aos_cia_audience_count_v2`;
- `aos_cia_audience_preview_v2`;
- `aos_cia_audience_explain_v2`;
- resolver set/domain-aware;
- Segment cache y Email cache: 11,473 contactos;
- Preview máximo 100 server-side.

Seguridad/frontend:
- gateway CIA ADMIN;
- resolver interno no público;
- sesión CIA separada;
- 2FA proof single-use para sesión CIA;
- 0 `alert/confirm/prompt`;
- sin SQL arbitrario ni lecturas directas de fuentes operativas desde el panel.

Integración:
- PR #62 MERGED;
- Ascenda CI #389 SUCCESS;
- merge funcional `95cae1ca85e3bec252abbd7b03de80f3829a2ae3`;
- cierre documental PR #64.

Reportes:
- `PHASE_05_PANEL_CENTRAL.md`;
- `PHASE_05_VALIDATION_REPORT.md`.

---

# FASE 6 — AUDIENCE LIBRARY PERSISTENCE = 100_COMPLETE

## Entrega

ASCENDA ya dispone de una biblioteca universal de definiciones de audiencia, independiente de canal y de asesor.

Objetos:
- `aos_audiencias`;
- `aos_audiencia_versiones`;
- `aos_audiencia_audit`.

Capacidades:
- crear audiencia dinámica;
- guardar definición DSL validada;
- crear nueva versión sin overwrite;
- historial inmutable;
- optimistic concurrency con `expected_version`;
- duplicar;
- archivar/restaurar;
- nombre activo único case-insensitive;
- conteo al guardar con `resolved_at`;
- LIST/GET paginados y limitados.

## Fronteras preservadas

Fase 6 **no** crea snapshots de miembros, activaciones ni asignaciones.

No se modificaron:
- `aos_siguiente_lead`;
- `aos_cola_config`;
- `calls.js` / Call Center;
- fuentes CRM, Agenda o Ventas;
- `aos_email_audiencias` ni su FK legacy.

## Seguridad

- RLS activo en las tres tablas;
- `anon/authenticated` sin acceso directo de tabla;
- RPC internos no públicos;
- `service_role` con SELECT directo solamente tras hardening;
- mutaciones detrás del gateway CIA ADMIN;
- versiones inmutables;
- audit append-only;
- FK diferible protege `current_version`;
- sin hard delete funcional.

## QA / Performance

QA transaccional con rollback:
- CREATE v1 PASS;
- DSL inválido rechazado;
- UPDATE → v2 PASS;
- stale update → `VERSION_CONFLICT`;
- duplicate PASS;
- archive/restore PASS;
- name conflict PASS;
- inmutabilidad PASS;
- residuos de QA = 0.

Performance:
- Library LIST ~58 ms;
- COUNT representativo cold ~1.238 s;
- COUNT warm ~142 ms;
- PASS contra objetivo normal `<1.5 s`.

## Replayability

Migrations Git alineadas 1:1 con versiones live de Supabase:
- `20260813190851_cia_audience_library_schema_v1.sql`;
- `20260813190951_cia_audience_library_rpcs_v1.sql`;
- `20260813191028_cia_admin_gateway_phase6_v1.sql`;
- `20260813192800_cia_audience_library_hardening_v1.sql`.

## Frontend

Panel actualizado con pestaña **Audiencias**:
- activas/archivadas;
- guardar desde Constructor;
- nueva versión;
- historial;
- duplicar;
- archivar/restaurar;
- feedback de conflictos;
- `Conteo al guardar` diferenciado del conteo live;
- modales ASCENDA, sin diálogos nativos.

## Integración

- PR #65: MERGED.
- Head auditado: `1c939652f2ee03eb5a17f67e23193385387393fd`.
- Ascenda CI #418: SUCCESS.
- Merge funcional a staging: `78da0bf4561f53100df17717051d2ab3db621040`.
- Post-merge compare: 0 archivos pendientes.
- Call Center observado operativo después del despliegue; 63 llamadas guardadas al último smoke.
- Email legacy intacto.

Detalle: `PHASE_06_AUDIENCE_LIBRARY.md` y `PHASE_06_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## FASE 7 — SNAPSHOTS & ACTIVATION = READY

Objetivo: convertir una audiencia persistente en un uso comercial trazable sin confundir definición dinámica con miembros congelados.

Reglas de entrada:
- `aos_audiencias` sigue siendo definición universal;
- snapshot debe ser inmutable y reproducible;
- activation debe registrar audiencia/version, propósito, canal/contexto, modo live/snapshot, creador, estado y timestamps;
- membership congelada pertenece a activation/snapshot, no a la audiencia base;
- no assignment todavía: la distribución a asesores permanece para Fase 9;
- no cambio temprano de `aos_siguiente_lead`;
- respetar total audience ≠ eligible ≠ available;
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
