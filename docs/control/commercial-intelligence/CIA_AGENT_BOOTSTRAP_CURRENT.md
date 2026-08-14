# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-13 (America/Lima)  
**Checkpoint canónico de staging:** `2e1116f07919fcf53bdac8cf61cbd23944863630`  
**Fases cerradas:** 0–9 `100_COMPLETE`  
**Fase actual:** 10 — Advisor Control Center `READY`

---

# 1. MISIÓN

Commercial Intelligence & Audience OS transforma los datos operativos vivos de ASCENDA en:

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Work → Approval → Intelligence → KronIA → Channels → Attribution`

Principios:

- una audiencia pertenece a ASCENDA, no a un canal;
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View;
- datos fuente operativos permanecen intactos;
- `numero_limpio/contact_key` es bridge V1, no identidad eterna;
- SQL/RPC determinístico calcula; IA interpreta/recomienda;
- human-in-the-loop para ownership/recursos sensibles;
- UNKNOWN falla cerrado;
- toda capa material es versionada/auditable;
- no big-bang;
- no romper producción para completar una fase.

Misión global ASCENDA:

`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

---

# 2. RECOVERY OBLIGATORIO

Antes de cualquier cambio:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. leer este archivo;
4. leer `CIA_EXECUTION_PLAYBOOK_V1.md`;
5. leer `ROADMAP_STATUS.md`;
6. leer `PHASE_09_VALIDATION_REPORT.md`;
7. leer `aos_memory` claves `cia_v3_*`, `cia_phase9_*`, `cia_phase10_status`;
8. verificar `staging` HEAD live;
9. verificar Supabase live/migrations;
10. solo entonces ejecutar Fase 10.

No usar como estado actual la sección histórica “Estado de ejecución actual” del Master V3 original. El estado vivo está en este Bootstrap + Roadmap + `aos_memory`.

---

# 3. ESTADO DE LAS 19 FASES

| # | Fase | Estado |
|---:|---|---|
| 0 | Baseline & Contracts | `100_COMPLETE` |
| 1 | Identity Resolver | `100_COMPLETE` |
| 2 | Commercial Facts | `100_COMPLETE` |
| 3 | Segmentation Engine | `100_COMPLETE` |
| 4 | Audience Resolver | `100_COMPLETE` |
| 5 | Panel Central Skeleton | `100_COMPLETE` |
| 6 | Audience Library Persistence | `100_COMPLETE` |
| 7 | Snapshots & Activation | `100_COMPLETE` |
| 8 | Channel Context & Availability | `100_COMPLETE` |
| 9 | Assignment Engine | `100_COMPLETE` |
| 10 | Advisor Control Center | `READY` |
| 11 | Call Center Integration V3 | `NOT_STARTED` |
| 12 | Advisor Work Views | `NOT_STARTED` |
| 13 | Requests & Approval Engine | `NOT_STARTED` |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` |
| 16 | Email Integration | `NOT_STARTED` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 4. CONTRATOS YA CERTIFICADOS

## F0–F4

- Identity resolver con conflictos explícitos.
- Commercial Facts 1:1.
- Segmentation separada de legacy `etiqueta_vip`.
- Audience DSL whitelisted con MATCH/MISS/UNKNOWN y `never_contains`.

## F5–F6

- Panel ADMIN Bases & Audiencias.
- CIA admin session/gateway.
- Biblioteca universal de audiencias versionada y auditable.

## F7–F8

- Snapshots inmutables.
- Activation BATCH/DYNAMIC.
- `Audience Total → Eligible → Available Now`.
- UNKNOWN no assignable.

## F9

Input autoritativo:

`aos_cia_activation_available_keys_v1(activation_id)`

Assignment:

- ownership por `aos_usuarios.id` UUID;
- ONE / EQUAL / PERCENTAGE / FIXED;
- GLOBAL / ACTIVATION;
- `RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`;
- capacity;
- NONE / MAINTAIN_TARGET / CONTINUOUS;
- idempotency;
- advisory lock;
- anti-double-ownership;
- audit append-only.

Output autoritativo para F10:

`aos_cia_assignment_advisor_workload_v1()`

`aos_cia_assignment_plan_summary_v1(plan_id)`

Complementarios:

`aos_cia_assignment_list_v1(...)`

`aos_cia_assignment_events_v1(...)`

---

# 5. FASE 10 — MISIÓN EXACTA

Construir **Advisor Control Center**, un read/control plane administrativo sobre ownership ya creado por Fase 9.

Debe mostrar, por `aos_usuarios.id`:

- carga activa;
- ASSIGNED;
- IN_PROGRESS;
- COMPLETED;
- RELEASED;
- EXPIRED;
- active plans;
- overdue-to-start;
- expiring leases;
- candidate remaining;
- source available;
- depletion;
- capacity/utilization;
- drill-down de ownership/deadlines.

Fase 10 **no** debe:

- reconstruir ownership desde calls/leads;
- crear otro Assignment Engine;
- modificar `aos_siguiente_lead`;
- entregar Work Views a asesores;
- hacer routing Call Center V3;
- implementar approvals;
- introducir afinidad IA como decisión real.

Output requerido para F11:

un control plane confiable que permita observar y gobernar Assignment antes de conectarlo al runtime de Call Center.

---

# 6. CAMINO RESTANTE 10–18

**F10 Advisor Control Center** → observar/controlar ownership F9.  
**F11 Call Center Integration V3** → ruta paralela + feature flag + fallback V2.  
**F12 Advisor Work Views** → vistas personales dentro del ownership.  
**F13 Requests & Approval** → requests estructuradas y ejecución atómica.  
**F14 Intelligence Shadow** → oportunidades/afinidad/agotamiento sin autoacción.  
**F15 KronIA + Multiagent** → tools estructuradas + Policy Gate.  
**F16 Email** → consumir Audience/Activation central conservando flows actuales.  
**F17 SMS/WhatsApp** → mismos contratos, provider específico.  
**F18 Attribution/Learning/Hardening** → outcomes end-to-end, resiliencia, observabilidad y paquete reusable.

No adelantar capacidades entre fases salvo deuda bloqueante demostrada; si se adelanta una corrección, documentar por qué y mantener la frontera funcional.

---

# 7. GUARDRAILS ADQUIRIDOS

Antes de tocar una tabla operativa:

- revisar write-path;
- revisar funciones usadas por índices/triggers;
- probar INSERT/UPDATE como rol real;
- confirmar tráfico real posterior.

Antes de optimizar:

- EXPLAIN/benchmark;
- no subir timeout como solución;
- no mega-join de dominios innecesarios.

Antes de certificar:

- migration replayability;
- grants reales;
- timezone Lima;
- cache coverage/freshness;
- QA rollback-only;
- zero residue;
- handshake fase anterior;
- output siguiente fase;
- PR + CI + staging smoke;
- docs + `aos_memory`.

---

# 8. INCIDENTES QUE TODO AGENTE DEBE RECORDAR

1. Mega-view del resolver llegó a ~30.4 s → Resolver V2 domain-aware.
2. Índices CIA con función privada rompieron INSERT de Call Center con 401 → write-path safety obligatorio.
3. Default EXECUTE de funciones fue más amplio de lo supuesto → revisar ACL post-DDL.
4. Auth KronIA existente no era apta para panel ADMIN → no reutilizar auth sin auditoría.
5. Drift de timestamps de migrations → Git ↔ `schema_migrations` debe ser 1:1.
6. Segment/Email caches quedaron detrás del universo → absence no es FALSE si freshness no cuadra.
7. Snapshot BATCH falló por `digest()` sin schema → calificar extensiones y probar handshake real.
8. Event emitter DB + RPC manual duplicaba potencialmente eventos → una sola fuente de audit.
9. `CURRENT_DATE` server divergió de Lima → timezone explícita.
10. CONTINUOUS top-up inicial se desbalanceó → probar ciclo completo, no solo primera asignación.

---

# 9. CURRENT CHECKPOINT

Canonical staging closure:

`2e1116f07919fcf53bdac8cf61cbd23944863630`

Último cierre:

`docs/control/commercial-intelligence/PHASE_09_VALIDATION_REPORT.md`

Siguiente acción:

**Iniciar Fase 10 únicamente después de recovery/preflight.**