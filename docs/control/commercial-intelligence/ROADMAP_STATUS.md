# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Estado:** CURRENT / DYNAMIC SOURCE OF PHASE STATUS  
**Última actualización:** 2026-08-14 (America/Lima)  
**Staging funcional F12:** `dedbc80de9967a70c4cd7a1195a534496b245a2d`  
**Master arquitectónico:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`  
**Bootstrap actual:** `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`

---

## Regla de estado

Estados válidos:
`NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`

Una fase solo es `100_COMPLETE` cuando:
- input handshake desde la fase anterior está probado;
- todos sus gates están sustentados;
- implementación está integrada en `staging`;
- CI pasa;
- smoke post-merge pasa;
- output contract para la fase siguiente está probado;
- Validation Report final existe;
- GitHub, `aos_memory` y Notion quedan sincronizados.

El detalle histórico vive en cada `PHASE_XX_VALIDATION_REPORT.md`; este documento mantiene solo estado vivo, contratos y siguiente acción.

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
| 7 | Snapshots & Activation | `100_COMPLETE` | 100% |
| 8 | Channel Context & Availability | `100_COMPLETE` | 100% |
| 9 | Assignment Engine | `100_COMPLETE` | 100% |
| 10 | Advisor Control Center | `100_COMPLETE` | 100% |
| 11 | Call Center Integration V3 | `100_COMPLETE` | 100% |
| 12 | Advisor Work Views | `100_COMPLETE` | 100% |
| 13 | Requests & Approval Engine | `READY` | 0% |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | 0% |
| 15 | KronIA + Multiagent Orchestration | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CADENA CERTIFICADA F0–F12

`Identity → Commercial Facts → Segmentation → Audience Resolver → Panel → Audience Library → Snapshot/Activation → Context/Availability → Assignment → Advisor Control → Call Routing V3 → Advisor Work Views`

Separaciones no negociables:
- Audience ≠ Eligibility ≠ Activation ≠ Assignment ≠ Work View;
- Work View nunca cambia ownership;
- Requests/Approvals todavía no existen en F12;
- IA no decide ownership;
- Call Center V3 conserva fallback V2 y kill switch global OFF salvo rollout explícito.

---

## F0–F4 — Data/semantic foundation

`100_COMPLETE`.

Entregan:
- Identity Resolver con conflictos explícitos;
- Commercial Facts 1:1;
- Value Tier / Lifecycle / Engagement / Traits;
- Audience DSL whitelisted;
- Count/Preview/Explain;
- MATCH/MISS/UNKNOWN;
- `never_contains` seguro.

Validation Reports:
- `PHASE_01_IDENTITY_RESOLVER.md`
- `PHASE_02_VALIDATION_REPORT.md`
- `PHASE_03_VALIDATION_REPORT.md`
- documentación F4 / Roadmap checkpoints.

---

## F5–F8 — Control/Audience/Activation

`100_COMPLETE`.

Entregan:
- panel ADMIN Bases & Audiencias;
- CIA admin gateway/session;
- Audience Library versionada;
- snapshots inmutables SHA-256;
- Activation BATCH/DYNAMIC;
- `Audience Total → Eligible → Available Now`;
- `aos_cia_activation_available_keys_v1(activation_id)` como input autoritativo para Assignment.

---

## F9 — Assignment Engine

`100_COMPLETE`.

Contrato:
`F8 available_keys → Assignment Plan → Assignment Lease → F10 read-models`

Entregas:
- ownership por `aos_usuarios.id` UUID;
- ONE / EQUAL / PERCENTAGE / FIXED;
- GLOBAL / ACTIVATION;
- `RESERVED → ASSIGNED → IN_PROGRESS → COMPLETED | RELEASED | EXPIRED`;
- capacity;
- top-up NONE / MAINTAIN_TARGET / CONTINUOUS;
- concurrency/idempotency;
- audit append-only;
- read-models F10.

Cierre funcional F9:
`2e1116f07919fcf53bdac8cf61cbd23944863630`

Documento:
`docs/control/commercial-intelligence/PHASE_09_VALIDATION_REPORT.md`

---

## F10 — Advisor Control Center

`100_COMPLETE`.

Contrato:
`F9 ownership/read-models → F10 administrative control plane → F11 readiness`

Entregas:
- workload por advisor UUID;
- plan health;
- capacity/utilization;
- overdue/expiring;
- advisor drill-down;
- readiness estructural F11.

Documento:
`docs/control/commercial-intelligence/PHASE_10_VALIDATION_REPORT.md`

---

## F11 — Call Center Integration V3

`100_COMPLETE`.

Contrato:
`F8 availability → F9 ownership → F10 readiness → F11 dispatcher/claim/consume → F12`

Entregas:
- dispatcher V3 paralelo;
- kill switch global default OFF;
- V2_ONLY / V3_CANARY / V3_PREFERRED;
- fallback V2 obligatorio;
- claim `ASSIGNED → IN_PROGRESS`;
- resume de IN_PROGRESS propio;
- post-write consume → COMPLETED;
- F12 readiness;
- America/Lima explícito;
- wrapper/adapter frontend rollback-safe.

Cierre F11 original preservó:
- `aos_siguiente_lead` hash `76412bac81e20ec6cfdc4f8c0db89e8c`;
- `aos_siguiente_lead_v2` hash histórico `cb69781d1457ed73de8f8d52f0f83a00`.

Cambio concurrente posterior, fuera de F12:
- Marketing Attribution V2 reemplazó legítimamente `aos_siguiente_lead_v2` mediante `20260814104500_marketing_attribution_v2_safe_origin_resolution.sql`;
- hash live posterior: `2b5b5707450df3bc648636936c02a0d4`;
- F12 sincronizó ese `staging` antes de integración y no reescribió routing.

Documento:
`docs/control/commercial-intelligence/PHASE_11_VALIDATION_REPORT.md`

---

## F12 — Advisor Work Views

`100_COMPLETE`.

Contrato certificado:

`F9 assignment lease + F11 routing evidence → F12 personal work universe/preferences → F13 requestable context`

### Entregas

Persistencia no propietaria:
- `aos_cia_advisor_work_preferences`;
- pin;
- snooze ≤30 días;
- prioridad visual HIGH/NORMAL/LOW;
- RLS deny-by-default;
- guard DB exige que preference advisor = assignment owner.

Read contracts:
- `aos_cia_advisor_work_universe_v1(...)` — privado;
- `aos_cia_advisor_work_summary_v1(...)`;
- `aos_cia_advisor_work_list_v1(...)`;
- `aos_cia_advisor_work_detail_v1(...)`;
- `aos_cia_advisor_work_preference_v1(...)`;
- `aos_cia_advisor_work_f13_readiness_v1()` — privado.

Priority V1:
1. IN_PROGRESS;
2. OVERDUE_TO_START;
3. EXPIRING_SOON ≤60m;
4. FOLLOWUP_OVERDUE;
5. FOLLOWUP_PENDING;
6. DIAMANTE/GOLD/PREMIUM;
7. resto del ownership activo.

Reglas:
- `pinned` solo eleva visualmente;
- snooze solo oculta temporalmente;
- priority override solo reordena;
- ninguna acción F12 cambia `advisor_user_id`, plan, activation o assignment state.

Frontend:
- `advisor-work.html/css/js`;
- montado en la zona izquierda reservada de `advisor-home.html`;
- no modifica `app.html` ni Call Center;
- NOW / PINNED / SNOOZED / HISTORY;
- KPIs, deadlines, reasons, routing evidence y detail;
- badge F13 `solicitable`, sin implementar requests.

QA rollback-only:
- 5 leases propios;
- IN_PROGRESS/ASSIGNED;
- CLAIM F11;
- pin/snooze/priority;
- cross-advisor mutation rechazada;
- ownership unchanged;
- F13 readiness true;
- zero residue.

Performance:
- primera mega-enrichment con call facts: ~1.63s → rechazada;
- 1,000 per-row call lookups: ~1.89s → rechazada;
- contrato final LIST/SUMMARY sin last-call bulk + DETAIL single-call lookup;
- 1,000 work-items / page 100: ~874.8ms → PASS <1.5s.

Security:
- preferences RLS enabled / 0 policies;
- anon/auth sin SELECT directo;
- public advisor RPCs filtran por advisor UUID resuelto con el contrato F11;
- internal universe/readiness no ejecutables por anon/auth;
- SECURITY DEFINER con `search_path=public`.

Replayability Git↔Supabase:
- `20260814153444_cia_phase12_work_preferences_v1.sql`;
- `20260814153657_cia_phase12_work_universe_v1.sql`;
- `20260814153814_cia_phase12_work_contracts_v1.sql`;
- `20260814154524_cia_phase12_work_universe_call_lookup_v2.sql`;
- `20260814155611_cia_phase12_list_detail_split_v2.sql`.

Integration:
- Functional PR #89 — MERGED;
- Ascenda CI #903 — SUCCESS;
- functional staging merge `dedbc80de9967a70c4cd7a1195a534496b245a2d`;
- post-merge summary/list empty-state PASS;
- F11 readiness `READY_NO_LIVE_V3` / ready_for_f12=true;
- F13 readiness `READY_NO_REQUESTABLE_WORK` / ready_for_f13=true;
- zero residues PASS.

Documento:
`docs/control/commercial-intelligence/PHASE_12_VALIDATION_REPORT.md`

---

# SIGUIENTE FASE

## FASE 13 — REQUESTS & APPROVAL ENGINE = READY

Objetivo:
gobernar solicitudes que parten del universo personal F12 y requieren aprobación antes de cualquier cambio de recursos/ownership.

### Input contract F12 → F13

F13 debe consumir:
- `advisor_user_id` UUID;
- `assignment_id` como work-item/ownership reference estable;
- plan/activation IDs;
- assignment state;
- deadlines/expiry;
- work bucket / priority reasons;
- preference state;
- F11 routing evidence;
- `requestable=true` solo si el assignment sigue siendo propio, ASSIGNED/IN_PROGRESS y no expiró;
- `aos_cia_advisor_work_f13_readiness_v1()`.

### F13 debe construir

- Request lifecycle estructurado;
- tipos de request permitidos;
- requester advisor UUID;
- target resource / assignment reference;
- PENDING / APPROVED / REJECTED / EXPIRED / EXECUTED;
- revalidación atómica al aprobar/ejecutar;
- no double approval;
- audit append-only;
- ADMIN control plane;
- advisor request status.

### F13 no debe

- permitir autoasignación directa;
- aceptar `contact_key` crudo como ownership authority;
- saltarse F9 assignment state;
- ejecutar si ownership cambió/expiró;
- introducir affinity IA como aprobación automática;
- retirar fallback V2/F11 safeguards.

Output esperado para F14:

un Approval Gate transaccional, auditable y revalidado que Intelligence/KronIA pueda usar sin escribir recursos arbitrariamente.

---

# LOOP UNIVERSAL V2

`recovery → baseline → input handshake → scope/Impact → branch → implementation → guards → QA rollback-only → security → performance → write-path safety → frontend → output handshake → PR/CI → staging smoke → Validation Report → aos_memory → Notion`

No se habilita F14 hasta F13 = `100_COMPLETE`.

---

# CONTINUIDAD / RECOVERY

En un nuevo chat/agente:

1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md`
5. `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md`
6. este Roadmap
7. `PHASE_12_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase12_*`, `cia_phase13_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. verificar `staging` + Supabase live antes de cualquier cambio.
