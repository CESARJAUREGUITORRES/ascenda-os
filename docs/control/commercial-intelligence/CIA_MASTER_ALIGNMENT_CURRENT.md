# ASCENDA OS — CIA MASTER ALIGNMENT CURRENT

**Estado:** CURRENT  
**Fecha:** 2026-08-14 (America/Lima)  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Estado dinámico:** `docs/control/commercial-intelligence/ROADMAP_STATUS.md`  
**Último merge funcional:** F13 `594c2c77dae8513ff73a300e60f4caed1996efad`  
**Checkpoint de control actual:** consultar `staging` HEAD + `aos_memory.cia_v3_control_checkpoint`.

---

# 1. OBJETIVO

El Master V3 original continúa como arquitectura madre. Este documento alinea esa arquitectura con el estado real alcanzado después de cerrar F0–F13.

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
| 14 | Commercial Intelligence Shadow | `READY` | F13 + facts/outcomes |
| 15 | KronIA + Multiagent | `NOT_STARTED` | F13/F14 |
| 16 | Email Integration | `NOT_STARTED` | Audience/Activation central |
| 17 | SMS/WhatsApp/Future Channels | `NOT_STARTED` | F8/F16 patterns |
| 18 | Attribution/Learning/Hardening | `NOT_STARTED` | todas las anteriores |

---

# 3. CADENA IMPLEMENTADA Y CERTIFICADA

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Requests/Approval`

Decisiones demostradas:
- `aos_usuarios.id` UUID es identidad de ownership;
- `assignment_id` es referencia estable de work-item;
- F8 availability gobierna nuevas asignaciones;
- F9 lease/ownership gobierna trabajo activo;
- F11 routing consume ownership con fallback V2;
- F12 organiza work sin mutar owner;
- F13 separa Request, Approval y Execution y revalida antes de mutar;
- IA/F14/KronIA deben cruzar Policy Gate y no escriben arbitrariamente.

---

# 4. REFINAMIENTOS INSTITUCIONALIZADOS

## Datos / freshness
Caches y facts deben demostrar cobertura/freshness. Ausencia no equivale automáticamente a FALSE; UNKNOWN falla cerrado.

## Performance
No usar mega-views ni aumentar timeouts para ocultar N+1. Resolver por dominios, snapshots/listas y drill-down selectivo.

## Seguridad
RLS teórico no basta: auditar grants reales. SECURITY DEFINER con search_path restringido debe schema-qualify extensiones, como `extensions.digest`.

## Testing
Handshake anterior → actual y output actual → siguiente son gates obligatorios. QA mutante rollback-only; benchmarks mutantes también dentro de rollback.

## Replayability
Migration versionada implica reconciliación exacta con ledger live para migraciones del frente, distinguiendo cambios concurrentes legítimos.

## Timezone
“Hoy” operacional = `America/Lima`.

## Governance
`Work View ≠ Assignment ≠ Request ≠ Approval ≠ Execution`.
Retries idempotentes de estados terminales deben reconocerse antes de revalidar un recurso que la primera ejecución mutó intencionalmente.

## CI
Un runner bloqueado por billing antes de checkout no es un fallo de código ni un SUCCESS. F13 registró `CI_INFRA_EXCEPTION_DOCUMENTED`, validación equivalente aislada y smoke post-merge; la automatización debe restaurarse cuando se resuelva la infraestructura.

---

# 5. F13 — CONTRATO CERRADO

F13 entrega:
- `aos_cia_requests`;
- `aos_cia_request_events` append-only;
- state machine PENDING/APPROVED/REJECTED/EXPIRED/EXECUTED;
- advisor request RPCs;
- ADMIN gateway;
- revalidación atómica ownership/state/expiry;
- ejecución RELEASE usando lifecycle F9;
- Policy Gate determinístico;
- `aos_cia_request_f14_readiness_v1()`.

Policy actual:
- F14/KronIA `RELEASE_ASSIGNMENT` proposal → REQUIRE_APPROVAL;
- AUTO_ASSIGN/TRANSFER/AUTO_APPROVE/RAW_SQL → BLOCK;
- `auto_execute=false`.

Post-merge live:
- `ready_for_f14=true`;
- `status=READY_NO_REQUESTS`;
- zero F13 residue;
- F11 routing sigue global OFF / no rollout live.

---

# 6. F14 — CAMINO EXACTO

**Commercial Intelligence Shadow** es la siguiente fase correcta.

Debe iniciar SHADOW/read-only y construir:
- Opportunity objects determinísticos;
- afinidad/recompra/priorización;
- evidence, confidence, sample size y freshness;
- explainability;
- recommendations sin ejecución automática;
- read-models ADMIN/advisor gobernados;
- propuestas de acción únicamente vía F13 Policy Gate;
- trazabilidad recommendation → proposed request → human decision.

No debe:
- autoaprobar;
- autoejecutar;
- autoasignar;
- usar SQL write arbitrario;
- usar historia clínica/fotos/diagnósticos/notas clínicas como features comerciales ordinarias;
- saltarse F13;
- presentar inferencia IA como hecho determinístico.

Output F14 → F15:
**Commercial Intelligence Shadow explicable + tools/contracts gobernados, listo para KronIA/Multiagent sin autonomía de escritura.**

---

# 7. ESTADO ACTUAL DE LA MISIÓN

F0–F13 constituyen ya el núcleo comercial gobernado de datos → audiencia → activación → ownership → operación personal → aprobación.

La siguiente construcción no rehace ese núcleo. Añade una capa de inteligencia shadow sobre contratos existentes y prepara F15.

**Siguiente fase: F14 — Commercial Intelligence Shadow.**
