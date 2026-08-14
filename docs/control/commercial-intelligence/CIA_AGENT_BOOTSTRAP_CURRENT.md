# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** 0–10 `100_COMPLETE`  
**Fase actual:** 11 — Call Center Integration V3 `READY`  
**Último merge funcional certificado:** F10 `2a74c3443bb600c1157b746349e1e85dac7f67fc`  
**Checkpoint de control/documentación actual:** consultar `aos_memory.cia_v3_control_checkpoint` + `staging` HEAD live.

---

# 1. MISIÓN

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Approval → Intelligence → KronIA → Channels → Attribution`

Misión global ASCENDA:

`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

Principios:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View;
- datos fuente operativos permanecen intactos;
- ownership = `aos_usuarios.id` UUID;
- UNKNOWN/freshness incompleta falla cerrado;
- SQL/RPC determinístico calcula; IA interpreta/recomienda;
- no big-bang;
- no romper producción para completar una fase.

---

# 2. RECOVERY OBLIGATORIO

Antes de cualquier cambio:

1. `AGENTS.md`;
2. `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. este Bootstrap;
4. `CIA_EXECUTION_PLAYBOOK_V1.md`;
5. `CIA_MASTER_ALIGNMENT_CURRENT.md`;
6. `ROADMAP_STATUS.md`;
7. `PHASE_10_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase10_*`, `cia_phase11_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. recién entonces iniciar F11.

GitHub + Supabase/runtime prevalecen sobre Notion. Si existe drift visual, corregir Notion.

---

# 3. NOTION

- Control Maestro CIA: `https://app.notion.com/p/3bc0e4fe841481489c8ad11bb55acaf3?pvs=204`
- Fases CIA: `https://app.notion.com/p/1a24a1f7e7ab4a299f4848f1eaeff74d`
- Hallazgos CIA: `https://app.notion.com/p/4b3d3d6180ef4fb2b8d978f324e66dfd`
- Estándar ASCENDA: `https://app.notion.com/p/3bc0e4fe84148160ad18d30d380782db?pvs=204`
- KronIA V2: `https://app.notion.com/p/3bc0e4fe8414812db4b6f73e71e3c018?pvs=204`

Al cierre de cada fase: GitHub/CI/staging → `aos_memory` → Notion.

---

# 4. ROADMAP F0–F18

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
| 10 | Advisor Control Center | `100_COMPLETE` |
| 11 | Call Center Integration V3 | `READY` |
| 12 | Advisor Work Views | `NOT_STARTED` |
| 13 | Requests & Approval Engine | `NOT_STARTED` |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` |
| 16 | Email Integration | `NOT_STARTED` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 5. CONTRATOS CERTIFICADOS HASTA F10

## F8 → F9

`aos_cia_activation_available_keys_v1(activation_id)`

solo devuelve contactos assignable según contexto/availability.

## F9 Assignment

- plans / targets / runs / leases / events;
- ONE / EQUAL / PERCENTAGE / FIXED;
- GLOBAL / ACTIVATION;
- capacity;
- top-up;
- lifecycle de leases;
- concurrency/idempotency;
- audit append-only.

## F10 Advisor Control

Read-models:

- `aos_cia_advisor_control_overview_v1()`
- `aos_cia_advisor_control_advisor_detail_v1(...)`
- `aos_cia_advisor_control_plan_health_v1(...)`
- `aos_cia_advisor_control_alerts_v1(...)`
- `aos_cia_advisor_control_f11_readiness_v1()`

Gateway:

`aos_cia_phase10_admin_gateway_v1(...)`

Readiness F11 valida:
- GLOBAL ownership conflicts;
- asesores/targets inválidos;
- deadlines inválidos;
- plan ACTIVE con Activation no ACTIVE.

Estado live tras cierre F10:
- 6 asesores activos;
- 0 ownership real;
- readiness `READY_NO_ACTIVE_OWNERSHIP`;
- `routing_modified=false`.

F10 performance con 1,000 leases:
- overview 4.83 ms;
- advisor detail 50 10.76 ms;
- plan health 14.22 ms;
- readiness 6.09 ms.

Plan health general usa `LAST_RUN_SNAPSHOT`; `GET_PLAN` entrega detalle live exacto para un plan seleccionado.

---

# 6. FASE 11 — MISIÓN EXACTA

Construir **Call Center Integration V3** como ruta paralela y reversible entre Assignment y el runtime operativo de llamadas.

F11 debe:

1. ejecutar `aos_cia_advisor_control_f11_readiness_v1()` como preflight;
2. bloquear rollout si readiness=`BLOCKED`;
3. crear routing V3 paralelo;
4. usar feature flag/canary por usuario;
5. conservar `aos_siguiente_lead_v2` como fallback;
6. respetar `America/Lima`;
7. consumir ownership F9, no reconstruir eligibility ni Assignment;
8. probar claim/consume/release/expiry y concurrencia;
9. demostrar rollback inmediato a V2;
10. preservar hashes/baseline V2 hasta el rollout explícito.

F11 NO debe:
- eliminar/reemplazar V2 en big-bang;
- crear otro Assignment Engine;
- redefinir availability F8;
- adelantar Advisor Work Views F12;
- activar a todos los asesores simultáneamente.

Output F11 → F12:
routing V3 estable, observable y con ownership canónico, listo para Work Views personales.

---

# 7. BASELINE DE ROUTING QUE F11 DEBE PRESERVAR

Antes de tocar Call Center verificar nuevamente:

- `aos_siguiente_lead` hash: `76412bac81e20ec6cfdc4f8c0db89e8c`
- `aos_siguiente_lead_v2` hash: `cb69781d1457ed73de8f8d52f0f83a00`

Cierre F10 no modificó:
- `calls.js`;
- `aos_siguiente_lead*`;
- `aos_cola_config`;
- `aos_leads_en_curso`.

Semántica diaria V3 debe ser `America/Lima`, no `CURRENT_DATE` server implícito.

---

# 8. GUARDRAILS PERMANENTES

- write-path safety obligatorio antes de tocar tablas/routing operativo;
- QA mutante rollback-only cuando sea posible;
- zero residue;
- migrations Git ↔ `schema_migrations` coherentes;
- ACL reales post-DDL;
- no subir timeout para ocultar una arquitectura lenta;
- freshness explícita;
- una sola fuente autoritativa de audit events;
- handshake fase anterior + output fase siguiente antes de `100_COMPLETE`;
- PR + CI + staging smoke + Validation Report + `aos_memory` + Notion.

---

# 9. INCIDENTES/LECCIONES QUE SIGUEN VIGENTES

1. Mega-view ~30.4 s → resolver por dominios.
2. Índices CIA privados rompieron Call Center 401 → write-path test real.
3. ACL defaults inesperados → auditar privileges.
4. Auth heredada no se reutiliza sin auditoría.
5. Drift de migrations → ledger Git/live 1:1.
6. Cache stale → UNKNOWN/freshness fail-closed.
7. `digest()` sin schema → extensiones schema-qualified.
8. Doble audit source → una sola fuente DB.
9. UTC vs Lima → timezone explícita.
10. CONTINUOUS top-up → probar ciclo completo.
11. F10 plan health N+1 → lista snapshot ligera + drill-down exacto live.

---

# 10. SIGUIENTE ACCIÓN

**Iniciar F11 únicamente después de recovery/preflight completo.**

Primer paso F11: baseline exhaustivo del Call Center V2 + readiness F10 + Impact Report CRITICAL antes de modificar routing.
