# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** 0–11 `100_COMPLETE`  
**Fase actual:** 12 — Advisor Work Views `READY`  
**Último merge funcional certificado:** F11 `f439f8d33cad841dd6745b07462aec7a264ea6b2`  
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
7. `PHASE_11_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase11_*`, `cia_phase12_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. recién entonces iniciar F12.

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
| 11 | Call Center Integration V3 | `100_COMPLETE` |
| 12 | Advisor Work Views | `READY` |
| 13 | Requests & Approval Engine | `NOT_STARTED` |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` |
| 16 | Email Integration | `NOT_STARTED` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 5. CONTRATOS CERTIFICADOS HASTA F11

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

## F11 Call Center V3

Dispatcher:
`aos_siguiente_lead_v3(p_asesor,p_id_asesor,p_hoy)`

Consume:
`aos_cia_call_routing_consume_v1(...)`

Admin:
`aos_cia_call_routing_admin_v1(...)`

Output F12:
`aos_cia_call_routing_f12_readiness_v1()`

Contrato:
- global kill switch default OFF;
- per-advisor `V2_ONLY / V3_CANARY / V3_PREFERRED`;
- fallback V2 obligatorio;
- F10 readiness antes de V3;
- ASSIGNED requiere F8 availability y pasa a IN_PROGRESS;
- IN_PROGRESS se reanuda desde F9 ownership;
- legacy claim compatibility via `aos_leads_en_curso`;
- post-write consume → COMPLETED/idempotent;
- clinic-day `America/Lima`;
- `aos_siguiente_lead` y `aos_siguiente_lead_v2` permanecen sin modificar.

Estado live tras cierre F11:
- kill switch OFF;
- 0 advisors V3 persistentes;
- 0 routing events persistentes;
- 0 CALL ownership real;
- F12 readiness `READY_NO_LIVE_V3` con `ready_for_f12=true`.

Legacy hashes:
- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c`;
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`.

Frontend:
- legacy Call Center byte-idéntico en `calls-v2.html`;
- `calls.html` wrapper mínimo;
- `calls-loader-v3.js` + `calls-routing-v3.js`;
- admin tab `Routing V3`.

---

# 6. FASE 12 — MISIÓN EXACTA

Construir **Advisor Work Views**: vistas personales priorizadas dentro de ownership ya autorizado.

F12 debe:
1. usar `aos_usuarios.id` como advisor ownership;
2. consumir F9 leases, no inferir ownership desde calls/leads;
3. incorporar estado/routing F11 para saber qué trabajo fue servido/consumido;
4. mostrar ASSIGNED / IN_PROGRESS / deadlines/expiry propios;
5. crear vistas temporales/priorizadas como callbacks, seguimientos y clientes propios;
6. permitir reordenar/priorizar solo dentro del universo propio;
7. mantener Work View ≠ Assignment;
8. demostrar que ninguna vista personal cambia ownership;
9. dejar output gobernado para Requests & Approval F13.

F12 NO debe:
- autoasignar contactos;
- mover ownership entre asesores;
- saltarse F9/F11;
- implementar Requests/Approvals F13;
- introducir afinidad IA como acción real;
- retirar fallback V2 de F11.

Input handshake mínimo:
- `aos_cia_call_routing_f12_readiness_v1()` = ready;
- F9 ownership contracts intactos;
- F11 hashes/fallback intactos.

Output F12 → F13:
universo personal gobernado y auditado sobre el cual un asesor puede solicitar recursos/cambios sin autoasignarse.

---

# 7. GUARDRAILS PERMANENTES

- write-path safety obligatorio antes de tocar tablas/routing operativo;
- QA mutante rollback-only cuando sea posible;
- benchmarks de RPC mutantes siempre dentro de rollback;
- verificar el runtime realmente cargado por el shell; no asumir que un sibling JS es productivo;
- zero residue;
- migrations Git ↔ `schema_migrations` coherentes;
- ACL reales post-DDL;
- no subir timeout para ocultar una arquitectura lenta;
- freshness explícita;
- una sola fuente autoritativa de audit events;
- handshake fase anterior + output fase siguiente antes de `100_COMPLETE`;
- PR + CI + staging smoke + Validation Report + `aos_memory` + Notion.

---

# 8. INCIDENTES/LECCIONES QUE SIGUEN VIGENTES

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
12. F11 runtime real estaba inline en `calls.html`; `calls.js` no era la fuente ejecutada → verificar loader real antes de tocar frontend.
13. `EXPLAIN ANALYZE` de RPC mutante puede generar side effects → siempre rollback-only.
14. F11 repeat route tras START → F8 gates ASSIGNED; F9 ownership gobierna IN_PROGRESS.

---

# 9. SIGUIENTE ACCIÓN

**Iniciar F12 únicamente después de recovery/preflight completo.**

Primer paso F12: baseline de F9 leases + F11 routing/readiness + advisor UI actual; diseñar Work View sin mutar ownership.
