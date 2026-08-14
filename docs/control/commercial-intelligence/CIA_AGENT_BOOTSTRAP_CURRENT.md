# ASCENDA OS — CIA AGENT BOOTSTRAP CURRENT

**Estado:** CURRENT / RECOVERY ENTRYPOINT  
**Actualizado:** 2026-08-14 (America/Lima)  
**Fases cerradas:** 0–12 `100_COMPLETE`  
**Fase actual:** 13 — Requests & Approval Engine `READY`  
**Último merge funcional certificado:** F12 `dedbc80de9967a70c4cd7a1195a534496b245a2d`  
**Checkpoint de control/documentación actual:** consultar `aos_memory.cia_v3_control_checkpoint` + `staging` HEAD live.

---

# 1. MISIÓN

`Identity → Facts → Segmentation → Audience → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Center V3 → Advisor Work → Approval → Intelligence → KronIA → Channels → Attribution`

Misión global ASCENDA:

`CONTROLAR → ESTABILIZAR → MIGRAR A PROPIEDAD CORPORATIVA → PRODUCTIZAR COMO SaaS`

Principios:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View;
- Work View nunca cambia ownership;
- ownership = `aos_usuarios.id` UUID;
- `assignment_id` es la referencia estable de work-item para F13;
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
7. `PHASE_12_VALIDATION_REPORT.md`;
8. `aos_memory` claves `cia_v3_*`, `cia_phase12_*`, `cia_phase13_status`;
9. Notion CIA Control Maestro + Fases + Hallazgos;
10. verificar `staging` HEAD live;
11. verificar Supabase live/migrations;
12. recién entonces iniciar F13.

GitHub + Supabase/runtime prevalecen sobre Notion. Si existe drift visual, corregir Notion.

---

# 3. NOTION

- Control Maestro CIA: `https://app.notion.com/p/3bc0e4fe841481489c8ad11bb55acaf3?pvs=204`
- Fases CIA: `https://app.notion.com/p/1a24a1f7e7ab4a299f4848f1eaeff74d`
- Hallazgos CIA: `https://app.notion.com/p/4b3d3d6180ef4fb2b8d978f324e66dfd`
- Estándar ASCENDA: `https://app.notion.com/p/3bc0e4fe84148160ad18d30d380782db?pvs=204`
- KronIA V2: `https://app.notion.com/p/3bc0e4fe8414812db4b6f73e71e3c018?pvs=204`

Orden de cierre: GitHub/CI/staging → `aos_memory` → Notion.

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
| 12 | Advisor Work Views | `100_COMPLETE` |
| 13 | Requests & Approval Engine | `READY` |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` |
| 16 | Email Integration | `NOT_STARTED` |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` |

---

# 5. CONTRATOS CERTIFICADOS CLAVE

## F8 → F9
`aos_cia_activation_available_keys_v1(activation_id)`

## F9 Assignment
- ownership por advisor UUID;
- plans / targets / runs / leases / events;
- ONE / EQUAL / PERCENTAGE / FIXED;
- GLOBAL / ACTIVATION;
- capacity / top-up / concurrency / idempotency;
- lease lifecycle.

## F10 Advisor Control
Read-models administrativos sobre F9 ownership y readiness F11.

## F11 Call Center V3
- dispatcher V3 paralelo;
- global kill switch default OFF;
- V2_ONLY / V3_CANARY / V3_PREFERRED;
- fallback V2 obligatorio;
- ASSIGNED → IN_PROGRESS al claim;
- IN_PROGRESS propio se reanuda por F9 ownership;
- consume post-write → COMPLETED/idempotent;
- clinic-day `America/Lima`;
- `aos_cia_call_routing_f12_readiness_v1()`.

Estado actual esperado:
- global OFF;
- F12 readiness `READY_NO_LIVE_V3` / true cuando no hay rollout live.

### Routing concurrente legítimo
F11 cerró con hash histórico V2 `cb69781d1457ed73de8f8d52f0f83a00`.
Después, Marketing Attribution V2 añadió `20260814104500_marketing_attribution_v2_safe_origin_resolution.sql`, por lo que el hash live V2 pasó a `2b5b5707450df3bc648636936c02a0d4` sin intervención de F12.

## F12 Advisor Work Views

Persistencia no propietaria:
`aos_cia_advisor_work_preferences`

Read contracts:
- `aos_cia_advisor_work_summary_v1(...)`;
- `aos_cia_advisor_work_list_v1(...)`;
- `aos_cia_advisor_work_detail_v1(...)`;
- `aos_cia_advisor_work_preference_v1(...)`;
- private `aos_cia_advisor_work_universe_v1(...)`.

Output F13:
`aos_cia_advisor_work_f13_readiness_v1()`

F12 guarantees:
- work universe comes only from F9 assignments owned by advisor UUID;
- pin/snooze/priority never change ownership;
- cross-advisor preference is rejected;
- `requestable=true` only for own ASSIGNED/IN_PROGRESS unexpired lease;
- F11 claim/consume evidence is visible;
- `assignment_id` is the stable work-item reference for F13.

Frontend:
- `advisor-work.html/css/js` mounted in advisor-home left zone;
- no `app.html`/Call Center route changes;
- NOW / PINNED / SNOOZED / HISTORY;
- no Requests implementation yet.

Performance final:
- 1,000 work-items / page 100 equivalent ~874.8ms.

Functional integration:
- PR #89 MERGED;
- Ascenda CI #903 SUCCESS;
- merge `dedbc80de9967a70c4cd7a1195a534496b245a2d`;
- post-merge zero-work smoke PASS;
- F13 readiness `READY_NO_REQUESTABLE_WORK`, ready_for_f13=true;
- zero residues.

---

# 6. FASE 13 — MISIÓN EXACTA

Construir **Requests & Approval Engine**: solicitudes estructuradas que parten del universo propio F12 y requieren aprobación/revalidación antes de cualquier acción sobre recursos u ownership.

## Input autoritativo

F13 debe usar:
- `advisor_user_id` UUID;
- `assignment_id` como referencia estable;
- F9 lease state;
- plan/activation IDs;
- deadline/expiry;
- F12 work bucket / reasons;
- F11 routing evidence;
- `requestable=true`;
- `aos_cia_advisor_work_f13_readiness_v1()`.

F13 nunca debe aceptar `contact_key` crudo como autoridad de ownership.

## Debe construir

- request object tipado;
- requester advisor UUID;
- assignment/resource reference;
- PENDING / APPROVED / REJECTED / EXPIRED / EXECUTED;
- approver ADMIN verificable;
- revalidación atómica al aprobar/ejecutar;
- no double approval/execution;
- audit append-only;
- expiry;
- advisor status view;
- ADMIN queue/control plane;
- Policy Gate consumible por F14/F15.

## No debe

- permitir autoasignación directa;
- ejecutar si assignment cambió de owner o expiró;
- saltarse F9/F12;
- permitir aprobación basada solo en datos enviados por browser;
- introducir afinidad IA como decisión automática;
- retirar fallback/kill switch F11.

Output para F14:
un Approval Gate transaccional, auditable y revalidado que Intelligence pueda usar primero en shadow.

---

# 7. GUARDRAILS PERMANENTES

- write-path safety antes de tocar runtime operativo;
- QA mutante rollback-only;
- `EXPLAIN ANALYZE` mutante siempre dentro de rollback;
- zero residue;
- migrations Git ↔ `schema_migrations` 1:1;
- ACL reales post-DDL;
- no subir timeouts para ocultar arquitectura lenta;
- freshness explícita;
- una sola fuente autoritativa de audit events;
- verificar source real cargado por el shell;
- sincronizar staging concurrente antes del PR;
- handshake anterior + output siguiente antes de `100_COMPLETE`;
- PR + CI + staging smoke + Validation Report + `aos_memory` + Notion.

---

# 8. LECCIONES VIGENTES

1. Mega-view lenta → resolver/enriquecer por dominio/keys propias.
2. Índices CIA privados rompieron Call Center → write-path test real.
3. ACL defaults inesperados → auditar privileges.
4. Auth heredada no se reutiliza sin auditoría.
5. Drift migrations → ledger Git/live exacto.
6. Cache stale → UNKNOWN/freshness fail-closed.
7. Extensiones DB → schema-qualified.
8. Audit → una sola fuente autoritativa.
9. UTC vs Lima → timezone explícita.
10. Assignment top-up → probar ciclo completo.
11. F10 N+1 → snapshot list + exact drill-down.
12. F11 runtime real inline → verificar loader real.
13. Benchmark mutante → rollback-only.
14. F11 IN_PROGRESS → F9 ownership manda después del claim.
15. F12 list performance → no hacer last-call lookup por cada fila; mover enrichment costoso al DETAIL.
16. Concurrencia de ramas → sincronizar staging y distinguir cambios legítimos de regresiones antes de certificar.

---

# 9. SIGUIENTE ACCIÓN

**Iniciar F13 únicamente después de recovery/preflight completo.**

Primer paso F13:
1. verificar `aos_cia_advisor_work_f13_readiness_v1()`;
2. baseline de request/approval objects existentes para evitar colisión;
3. Impact Report CRITICAL;
4. diseñar request types + state machine + revalidation/atomic execution;
5. no habilitar writes reales hasta demostrar rollback/guard/no-double-approval.
