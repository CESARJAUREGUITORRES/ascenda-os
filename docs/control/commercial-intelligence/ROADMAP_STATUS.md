# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging tras Fase 5:** `95cae1ca85e3bec252abbd7b03de80f3829a2ae3`  
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
| 6 | Audience Library Persistence | `READY` | 0% |
| 7 | Snapshots & Activation | `NOT_STARTED` | 0% |
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

## Entrega

Panel ADMIN read-only **Bases & Audiencias** integrado en `app/public/` con:
- Dashboard.
- Presets.
- Constructor DSL.
- Preview paginado.
- Explain por contacto.
- Segmentación.
- Frescura explícita de caches.
- Secciones futuras bloqueadas hasta sus fases correspondientes.

## Runtime V2

- `aos_cia_audience_count_v2`.
- `aos_cia_audience_preview_v2`.
- `aos_cia_audience_explain_v2`.
- Resolver set/domain-aware.
- Segment cache y Email cache: 11,473 contactos cada uno.
- Preview limitado server-side a 100 registros por request.

## Correctitud final

Validación live final:
- FOLLOWUP_OVERDUE: 442.
- LEADS_UNWORKED: 1,287.
- LEADS_UNWORKED_7D: 115.
- NO_SHOW_NO_FUTURE: 823 y coincide con cálculo directo actual.
- DSL campo inexistente → `FIELD_NOT_ALLOWED`.
- Operador no permitido → `OPERATOR_NOT_ALLOWED`.
- `never_contains BEAUTY MAKER` → `MISS / UNKNOWN / MATCH` según evidencia.

Las variaciones históricas en audiencias dinámicas responden a actividad operacional real y no a drift del resolver.

## Performance final

Último gate:
- COUNT representativo: ~763 ms.
- PREVIEW 50: ~838 ms.
- EXPLAIN representativo: ~183 ms.

PASS contra objetivo normal `< 1.5 s`.

## Seguridad / frontend

- Navegador consume datos comerciales mediante gateway CIA; no lee tablas operativas directamente.
- Resolver interno no está expuesto a `anon/authenticated`.
- Sesión CIA separada para ADMIN.
- Prueba 2FA usada queda vinculada de forma single-use a la sesión CIA.
- 0 `alert()`, 0 `confirm()`, 0 `prompt()` en el panel.
- Sin SQL arbitrario desde frontend.
- Future actions permanecen deshabilitadas.

## Compatibilidad Call Center

Incidente de write-path cerrado y documentado.
- Índices funcionales inseguros fueron retirados.
- Optimización final usa expresiones nativas compatibles con INSERT operacional.
- Insert como `anon` fue validado con rollback.
- Tráfico real posterior confirmó `POST /aos_llamadas → 201` y cola de llamadas operativa.
- Fase 5 final no modifica `aos_siguiente_lead`, `calls.js` ni reglas de cola.

## Integración

- PR #62: MERGED.
- Head auditado: `dea116acb80c55b27d782a493366ecdc5c065a1c`.
- Ascenda CI run #389: SUCCESS.
- Merge a staging: `95cae1ca85e3bec252abbd7b03de80f3829a2ae3`.
- Post-merge compare: feature tiene 0 commits/archivos pendientes frente a staging.
- Panel y migration final de hardening verificados físicamente en `staging`.

Detailed reports:
- `PHASE_05_PANEL_CENTRAL.md`.
- `PHASE_05_VALIDATION_REPORT.md`.
- `PHASE_05_CLOSURE_CHECKPOINT.md`.

---

# SIGUIENTE FASE

## FASE 6 — AUDIENCE LIBRARY PERSISTENCE = READY

Objetivo: convertir definiciones de audiencia validadas en objetos persistentes de ASCENDA sin mezclar todavía activación ni assignment.

Fase 6 debe diseñarse y validarse desde el estado final de Fase 5. Reglas de entrada:
- Audience sigue siendo universal y channel-agnostic.
- Audience no almacena ownership de asesor.
- Dynamic definition y Snapshot son conceptos distintos.
- Persistencia debe usar el DSL/registry ya certificado.
- No reescribir fuentes operativas.
- No tocar `aos_siguiente_lead`.
- Nuevos objetos seguros por defecto y auditables.
- Impact Report antes de DDL productivo.

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
