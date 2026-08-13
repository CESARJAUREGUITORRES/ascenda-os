# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-13  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 4:** `26971547d22eccd496aa5fea67a61f109bec21ee`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

# REGLA DE ESTADO

Estados: `NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`.

Una fase solo es `100_COMPLETE` cuando todos sus gates tienen evidencia y existe checkpoint final en GitHub + `aos_memory`.

---

# PROGRESO GLOBAL

| # | Fase | Estado | Progreso |
|---:|---|---|---:|
| 0 | Baseline & Contracts | `100_COMPLETE` | 100% |
| 1 | Identity Resolver | `100_COMPLETE` | 100% |
| 2 | Commercial Facts | `100_COMPLETE` | 100% |
| 3 | Segmentation Engine | `100_COMPLETE` | 100% |
| 4 | Audience Resolver | `100_COMPLETE` | 100% |
| 5 | Panel Central Skeleton | `READY` | 0% |
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

# FASE 0 — CIERRE

P0-G01…P0-G09 PASS. Product Spec/Impact Report V3, Fact Registry V1, Frontend Contract, baseline y continuidad establecidos.

---

# FASE 1 — CIERRE

P1-G01…P1-G11 PASS.

Identity V1:
- 11,473 contact keys;
- 7,041 RESOLVED;
- 23 CONFLICT;
- 10 FUSED_ONLY;
- 4,399 NO_PATIENT_PROFILE.

PR #50, CI 274 SUCCESS. Merge funcional `e7746797c9b8fa407eb25c7b81afcb7179f62e6a`.

---

# FASE 2 — CIERRE

P2-G01…P2-G14 PASS.

Commercial Facts 1:1:
- Leads 5,391 / 5,076 contacts;
- Calls 33,999 / 5,885;
- Appointments 2,918 / 1,157;
- Sales 1,268 / 296;
- Followups 523 / 456;
- lead unworked since latest entry 1,287;
- Email 1,942 sends / 1,623 mapped / 319 unresolved;
- full representative composition ~474 ms.

PR #55, CI 293 SUCCESS. Merge `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`.

---

# FASE 3 — CIERRE

P3-G01…P3-G14 PASS.

Segmentation SHADOW V1:
- STANDARD 11,344;
- PREMIUM 95;
- GOLD 21;
- DIAMANTE 13;
- 794 terminal-history contacts rescued by newer lead;
- Engagement LOW 11,220 / MEDIUM 176 / HIGH 77;
- explainable/versioned policy;
- benchmark ~404.553 ms.

PR #57, CI 308 SUCCESS. Merge funcional `cd00090ad7a949f15d6b90422ec2bedf775a26dd`.

---

# FASE 4 — CIERRE

P4-G01…P4-G16 PASS al persistir checkpoint final.

## Contratos

- Profile Facts V1;
- Audience Source V1/V1.1;
- Filter Registry whitelisted;
- DSL V1, max 2 group levels / 25 rules;
- deterministic validate/count/preview/explain;
- MATCH/MISS/UNKNOWN;
- official presets;
- Product/Service purchase-detail reconciliation;
- safe `never_contains`;
- future-window numeric facts;
- no dynamic SQL;
- private/service_role only.

## Data quality / purchase detail

Producto full:
- 404 rows;
- 270 mapped high-confidence;
- 134 UNKNOWN;
- 66.8% mapped.

Producto Identity-valid:
- 403 rows;
- 269 mapped;
- 134 UNKNOWN;
- 66.7% mapped.

146 product-buyer contacts; 75 have unresolved product evidence.

Services:
- 871 rows;
- 773 categorized;
- 98 UNKNOWN;
- 88.7% mapped.

Safe negatives:
- BEAUTY MAKER 26 bought / 11,387 never-safe / 60 UNKNOWN;
- ISDIN 20 / 11,392 / 61;
- ENZIMAS service category 21 / 11,404 / 48.

## Presets / windows

- Leads unworked 1,287;
- Leads unworked 7d 115;
- No-show without future appointment 826;
- Followup overdue 442;
- future appointment 54; within next 7d 34.

## Performance / integration

- product reconciliation equivalent ~204 ms;
- complex audience equivalent ~346 ms;
- PASS vs normal P95 <1.5 s;
- no speculative cache/materialization/indexes.

PR #59. Ascenda CI run 342 = SUCCESS. Functional staging merge `26971547d22eccd496aa5fea67a61f109bec21ee`.

Production verified after merge:
- Phase 4 physical tables = 0;
- Phase 4 physical views = 0.

Certification scope: SQL contracts/migrations/tests versioned and semantics validated read-only on live data; no claim of physical Phase 4 DDL deployment or exact PL/pgSQL runtime benchmark before a deployable DB gate.

Detailed report: `PHASE_04_VALIDATION_REPORT.md`.

---

# SIGUIENTE FASE

## FASE 5 — PANEL CENTRAL SKELETON = READY

Goal: introduce the ADMIN-only, read-only **Bases & Audiencias** shell into the production frontend architecture without exposing source tables or duplicating resolver logic.

Phase 5 must:

- use `app/public/` and ASCENDA shell, never `src/` legacy;
- follow `FRONTEND_CONTRACT_V1.md` exactly;
- add Admin navigation entry;
- build responsive shell/navigation for Dashboard · Audiencias · Constructor · Distribución · Asesores · Oportunidades IA · Solicitudes · Segmentación · Activaciones · Historial/Auditoría;
- initially enable only read-only sections backed by controlled resolver contracts / safe placeholders where later engines are not built;
- no native alert/confirm/prompt;
- no raw Supabase source-table reads from browser;
- no audience persistence yet;
- no assignments/activations yet;
- preserve current Call/Email/Marketing panels unchanged;
- feature flag / safe rollback;
- responsive + accessibility + CI/staging validation.

---

# LOOP UNIVERSAL

`baseline → scope → impact → branch → isolated implementation → checks → tests → real-data comparison → edge cases → roles → responsive → staging → E2E → rollback → rollout → observation → closure docs → memory checkpoint`

---

# CONTINUIDAD

New chats recover in order:

1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`;
4. this roadmap;
5. current phase document;
6. `cia_v3_*` / `cia_phase_*` in `aos_memory`;
7. live staging/GitHub + Supabase before changes.
