# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

# REGLA DE ESTADO

Estados permitidos:

- `NOT_STARTED`
- `READY`
- `IN_PROGRESS`
- `BLOCKED`
- `VALIDATING`
- `100_COMPLETE`

Una fase solo puede pasar a `100_COMPLETE` cuando todos sus gates tienen evidencia y el checkpoint fue persistido en GitHub + `aos_memory`.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `READY` | 0% |
| 2 | Commercial Facts | `NOT_STARTED` | 0% |
| 3 | Segmentation Engine | `NOT_STARTED` | 0% |
| 4 | Audience Resolver | `NOT_STARTED` | 0% |
| 5 | Panel Central Skeleton | `NOT_STARTED` | 0% |
| 6 | Audience Library Persistence | `NOT_STARTED` | 0% |
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

# FASE 0 — GATES

| Gate | Estado |
|---|---|
| P0-G01 Baseline/fuentes | PASS |
| P0-G02 Inventario vivo/calidad | PASS |
| P0-G03 Mapa productivo integración | PASS |
| P0-G04 Fact Registry V1 | PASS |
| P0-G05 Normalización/enums | PASS |
| P0-G06 Permisos/ownership | PASS |
| P0-G07 Performance baseline | PASS |
| P0-G08 Frontend contract | PASS |
| P0-G09 Continuidad/checkpoint | PASS |

**Fase 0 cerrada al 100% el 2026-08-13.**

No hubo cambios de runtime, DDL, RLS ni datos comerciales/operativos. El único write en Supabase fue el checkpoint de continuidad solicitado en `aos_memory`.

---

# SIGUIENTE FASE

## FASE 1 — Identity Resolver = READY

Objetivo:

- `contact_key` V1;
- paciente canónico;
- exclusión lógica de `FUSIONADO` como identidad independiente;
- `identity_conflict`;
- `source_flags`;
- normalización read-only de claves legacy;
- preparación para `contact_id + aliases`;
- tests contra el universo vivo;
- benchmark;
- feature flag `AOS_CIA_IDENTITY_ENABLED`;
- cero reescritura masiva de `numero_limpio`.

Fase 1 debe iniciar con su propio Impact Report y gates antes de cualquier implementación.

---

# LOOP UNIVERSAL

Cada fase:

`baseline → alcance → impacto → branch → implementación aislada → checks → tests → comparación real → edge cases → roles → responsive → staging → E2E → rollback → rollout → observación → cierre docs → checkpoint memory`

---

# PRINCIPIO DE CONTINUIDAD

Cualquier nueva conversación debe recuperar en este orden:

1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`;
4. este `ROADMAP_STATUS.md`;
5. documento de la fase actual;
6. claves `cia_v3_*` / `cia_phase_*` en `aos_memory`;
7. código y Supabase vivos antes de ejecutar cambios.
