# ASCENDA OS — CIA MASTER ALIGNMENT CURRENT

**Estado:** CURRENT  
**Fecha:** 2026-08-14 (America/Lima)  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Estado dinámico:** `docs/control/commercial-intelligence/ROADMAP_STATUS.md`  
**Último merge funcional:** F14 `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`  
**Checkpoint de control actual:** consultar `staging` HEAD + `aos_memory.cia_v3_control_checkpoint`.

---

# 1. OBJETIVO

El Master V3 original continúa como arquitectura madre. Este documento alinea esa arquitectura con el estado real alcanzado después de cerrar F0–F14.

El Master sigue vigente para visión, separación de dominios, Fact Registry/DSL, Audience Engine, Assignment, governance, IA/Policy Gate, performance, compatibilidad de canales, rollback y roadmap conceptual F0–F18.

Sus secciones de estado inicial (`READY FOR PHASE 0`, estado de ejecución original y primera acción histórica) son **HISTORICAL / SUPERSEDED FOR CURRENT STATUS**.

Para estado actual prevalecen:
1. `CIA_AGENT_BOOTSTRAP_CURRENT.md`;
2. `ROADMAP_STATUS.md`;
3. último `PHASE_XX_VALIDATION_REPORT.md`;
4. `aos_memory`;
5. `staging` + Supabase live.

---

# 2. ROADMAP MAESTRO 0–18 — ALINEACIÓN ACTUAL

| # | Fase | Estado actual | Dependencia principal |
|---:|---|---|---|
| 0 | Baseline & Contracts | `100_COMPLETE` | inicio |
| 1 | Identity Resolver | `100_COMPLETE` | F0 |
| 2 | Commercial Facts | `100_COMPLETE` | F1 |
| 3 | Segmentation Engine | `100_COMPLETE` | F2 |
| 4 | Audience Resolver | `100_COMPLETE` | F1–F3 |
| 5 | Panel Central Skeleton | `100_COMPLETE` | F4 |
| 6 | Audience Library Persistence | `100_COMPLETE` | F4–F5 |
| 7 | Snapshots & Activation | `100_COMPLETE` | F6 |
| 8 | Channel Context & Availability | `100_COMPLETE` | F7 |
| 9 | Assignment Engine | `100_COMPLETE` | F8 |
| 10 | Advisor Control Center | `100_COMPLETE` | F9 |
| 11 | Call Center Integration V3 | `100_COMPLETE` | F9+F10 |
| 12 | Advisor Work Views | `100_COMPLETE` | F9+F11 |
| 13 | Requests & Approval Engine | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | F12 |
| 14 | Commercial Intelligence Shadow | `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED` | F13 + facts/segments |
| 15 | KronIA + Multiagent | `READY` | F13/F14 |
| 16 | Email Integration | `NOT_STARTED` | Audience/Activation central + F15 |
| 17 | SMS/WhatsApp/Future Channels | `NOT_STARTED` | F8/F16 patterns |
| 18 | Attribution/Learning/Hardening | `NOT_STARTED` | todas las anteriores |

---

# 3. CADENA IMPLEMENTADA Y CERTIFICADA

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval → Intelligence Shadow`

Decisiones demostradas:
- `aos_usuarios.id` UUID es identidad de ownership;
- `assignment_id` es referencia estable de work-item;
- F8 availability gobierna nuevas asignaciones;
- F9 lease/ownership gobierna trabajo activo;
- F11 routing consume ownership con fallback V2;
- F12 organiza work sin mutar owner;
- F13 separa Request, Approval y Execution y revalida antes de mutar;
- F14 calcula Recommendation objects SHADOW con evidence/confidence/freshness y no actúa;
- IA/F15 debe cruzar F13 Policy Gate y no obtiene SQL write arbitrario.

---

# 4. REFINAMIENTOS INSTITUCIONALIZADOS

## Datos / freshness
Caches y facts deben demostrar cobertura/freshness. Ausencia no equivale automáticamente a FALSE; UNKNOWN falla cerrado. F14 además demuestra que STALE debe permanecer etiquetado como stale, no maquillarse como fresh.

## Performance
No usar mega-views ni aumentar timeouts. F14 rechazó un join live facts+segments de ~44.4 s y lo reemplazó por refresh/coverage + snapshot SHADOW: top100 ~66.9 ms.

## Seguridad
RLS teórico no basta: auditar grants reales. Una tabla privada puede usar RLS + 0 policies + grants directos revocados y ser servida únicamente por RPC gobernada. SECURITY DEFINER con search_path restringido debe schema-qualify extensiones.

## Testing
Handshake anterior → actual y output actual → siguiente son gates obligatorios. QA mutante rollback-only; benchmarks mutantes también dentro de rollback.

## Replayability
Migration versionada implica reconciliación exacta con ledger live. F14 corrigió sus filenames de desarrollo antes del PR para coincidir 1:1 con `schema_migrations`.

## Timezone
“Hoy” operacional = `America/Lima`.

## Governance
`Work View ≠ Assignment ≠ Request ≠ Approval ≠ Execution`.  
`Recommendation ≠ Authority`.

F14 Recommendation puede ser interpretada o usada para una propuesta, pero no es permiso para ejecutar ownership/resources.

## CI
Un runner bloqueado por billing antes de checkout no es fallo de código ni SUCCESS. F13 y F14 registran `CI_INFRA_EXCEPTION_DOCUMENTED`, validación equivalente y smoke post-merge; la automatización debe restaurarse al resolver infraestructura.

---

# 5. F14 — CONTRATO CERRADO

F14 entrega:
- `aos_cia_intelligence_shadow_runs`;
- `aos_cia_intelligence_recommendations`;
- `aos_cia_intelligence_events`;
- `aos_cia_intelligence_shadow_refresh_v1(...)`;
- `aos_cia_intelligence_admin_gateway_v1(...)`;
- `aos_cia_intelligence_advisor_list_v1(...)`;
- `aos_cia_intelligence_f15_readiness_v1()`.

Semántica certificada:
- Opportunity types determinísticos;
- evidence/confidence/sample-size/freshness;
- explainability;
- observed affinity desde compras/servicios comerciales canónicos;
- identity conflicts excluidos;
- segment cache coverage exacta;
- state `SHADOW`;
- no autoassign/approve/execute;
- F13 Policy Gate permanece autoridad.

Live:
- 451 recommendations;
- 0 non-shadow states;
- 0 auto_execute violations;
- 0 missing GENERATED events;
- F15 readiness `READY_SHADOW_ACTIVE`, true.

Functional merge:
`ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`.

---

# 6. F15 — CAMINO EXACTO

**KronIA + Multiagent Orchestration** es la siguiente fase correcta.

Debe construir una capa de orquestación gobernada, no un agente con acceso abierto a la base.

Input:
- F14 Recommendation SHADOW objects;
- deterministic evidence/confidence/freshness;
- F9 advisor/assignment context;
- F13 Request lifecycle + Policy Gate;
- `aos_cia_intelligence_f15_readiness_v1()`.

Debe construir:
- Tool Registry estructurado/versionado;
- tool schemas tipados;
- agent roles/scopes;
- provenance/evidence por respuesta;
- Agent Run/Audit trace;
- rate/timeout/error boundaries;
- policy preflight obligatorio;
- flujo `OBSERVE → INTERPRET → PROPOSE → REQUEST → HUMAN DECISION → EXECUTE`;
- shadow-first rollout;
- output contract hacia F16 Email.

No debe:
- autoaprobar;
- autoejecutar;
- autoasignar;
- SQL write arbitrario;
- saltarse F13;
- usar datos clínicos sensibles como features comerciales ordinarias;
- convertir Recommendation F14 en autoridad;
- habilitar autonomía general en F15.

Output F15 → F16:
**KronIA/Multiagent con tools, Policy Gate, provenance y audit, capaz de consultar/interpretar/proponer sin autonomía de escritura, listo para integrar Email como canal central.**

---

# 7. ESTADO ACTUAL DE LA MISIÓN

F0–F14 constituyen el núcleo gobernado de datos → audiencias → activación → ownership → work → aprobación → inteligencia shadow.

La siguiente construcción no rehace ese núcleo. Añade orquestación IA gobernada sobre contratos ya certificados.

**Siguiente fase: F15 — KronIA + Multiagent Orchestration.**
