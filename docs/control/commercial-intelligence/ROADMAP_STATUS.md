# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-14 (America/Lima)  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 11:** `f439f8d33cad841dd6745b07462aec7a264ea6b2`  
**Master:** `docs/control/COMMERCIAL_INTELLIGENCE_AUDIENCE_OS_V3_MASTER.md`

---

## Regla de estado

Estados:
`NOT_STARTED | READY | IN_PROGRESS | BLOCKED | VALIDATING | 100_COMPLETE`

Una fase solo es `100_COMPLETE` cuando:
- todos sus gates están sustentados;
- implementación está integrada en `staging`;
- CI pasa;
- smoke post-merge pasa;
- Validation Report final existe;
- GitHub, `aos_memory` y Notion guardan el checkpoint.

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
| 12 | Advisor Work Views | `READY` | 0% |
| 13 | Requests & Approvals | `NOT_STARTED` | 0% |
| 14 | Commercial Intelligence Shadow | `NOT_STARTED` | 0% |
| 15 | KronIA + Multiagent | `NOT_STARTED` | 0% |
| 16 | Email Integration | `NOT_STARTED` | 0% |
| 17 | SMS / WhatsApp / Future Channels | `NOT_STARTED` | 0% |
| 18 | Attribution, Learning & Hardening | `NOT_STARTED` | 0% |

---

# CIERRES CERTIFICADOS

## Fases 0–4

- F0 `100_COMPLETE`: baseline, contratos, Fact Registry y protocolo.
- F1 `100_COMPLETE`: Identity Resolver y conflictos explícitos.
- F2 `100_COMPLETE`: Commercial Facts 1:1 por contacto.
- F3 `100_COMPLETE`: Value Tier / Lifecycle / Engagement / Traits.
- F4 `100_COMPLETE`: Audience Resolver DSL, Count/Preview/Explain y UNKNOWN.

## Fases 5–8

- F5 `100_COMPLETE`: Panel ADMIN Bases & Audiencias + CIA admin gateway.
- F6 `100_COMPLETE`: Audience Library versionada/auditable.
- F7 `100_COMPLETE`: Snapshots SHA-256 + Activation BATCH/DYNAMIC.
- F8 `100_COMPLETE`: `Audience Total → Eligible → Available Now` y `available_keys`.

## Fase 9 — Assignment Engine

`100_COMPLETE`.

Contrato:
`available_keys F8 → Assignment Plan → Assignment Lease → F10 read-models`

Entrega principal:
- ownership por `aos_usuarios.id` UUID;
- ONE / EQUAL / PERCENTAGE / FIXED;
- GLOBAL / ACTIVATION;
- lease lifecycle;
- capacity;
- top-up NONE / MAINTAIN_TARGET / CONTINUOUS;
- concurrency/idempotency;
- audit append-only;
- panel Distribución;
- read-models para F10.

Functional PR #75 / CI #576 SUCCESS. Closure PR #76 / CI #586 SUCCESS.

Documento:
`docs/control/commercial-intelligence/PHASE_09_VALIDATION_REPORT.md`

## Fase 10 — Advisor Control Center

`100_COMPLETE`.

Contrato:
`F9 ownership/read-models → F10 Advisor Control Center → F11 readiness preflight`

Entrega:
- overview global y por asesor UUID;
- ASSIGNED / IN_PROGRESS / COMPLETED / RELEASED / EXPIRED;
- capacity/utilization;
- advisor drill-down;
- overdue-to-start;
- expiring ≤60m;
- plan health;
- lista general `LAST_RUN_SNAPSHOT`;
- exact `GET_PLAN` live;
- readiness estructural F11;
- gateway ADMIN F10;
- pestaña `Control de asesores`.

Functional PR #82 / CI #701 SUCCESS. Closure PR #83 / CI #708 SUCCESS.

Documento:
`docs/control/commercial-intelligence/PHASE_10_VALIDATION_REPORT.md`

## Fase 11 — Call Center Integration V3

`100_COMPLETE`.

Contrato:

`F8 available_now → F9 ownership/lease → F10 readiness → F11 dispatcher/claim/consume → F12 Work Views`

Entrega:
- `aos_siguiente_lead_v3` como dispatcher paralelo;
- kill switch global default OFF;
- rollout por `aos_usuarios.id`: `V2_ONLY / V3_CANARY / V3_PREFERRED`;
- fallback V2 obligatorio durante toda F11;
- `aos_siguiente_lead` y `aos_siguiente_lead_v2` intactos;
- ASSIGNED → IN_PROGRESS al claim V3;
- IN_PROGRESS reanudable por el mismo ownership F9;
- compatibility claim `aos_leads_en_curso`;
- consume post-write → COMPLETED + idempotencia;
- RLS/ACL y audit append-only;
- America/Lima explícito;
- admin tab `Routing V3`;
- readiness F11→F12;
- Call Center legacy preservado byte-idéntico como `calls-v2.html` y wrapper/adapter rollback-safe.

### QA certificado

Rollback-only real F6→F11:
- audience `LEADS_UNWORKED`;
- Activation CALL_GENERAL;
- F9 plan ONE/GLOBAL;
- ownership MIREYA;
- foreign legacy claim → fallback V2;
- first claim → V3;
- assignment → IN_PROGRESS;
- repeat request → mismo assignment IN_PROGRESS;
- consume → COMPLETED;
- second consume → idempotent;
- post-complete → fallback V2;
- unflagged advisor → V2_ONLY;
- F10 blocked → fallback V2;
- 0 residuos.

Defecto encontrado y corregido:
- primera versión revalidaba F8 sobre un lease ya IN_PROGRESS;
- eso podía provocar fallback V2 tras refresh;
- corrección: F8 gobierna antes del claim; F9 ownership gobierna IN_PROGRESS hasta terminal/release/expiry.

Security:
- 3 tablas F11 RLS enabled / 0 policies;
- anon/auth sin SELECT directo;
- internals privados;
- browser solo dispatcher/consume y gateway ADMIN tokenizado;
- invalid admin token → UNAUTHORIZED;
- server bloquea `SET_GLOBAL=true` si F10 readiness no está sano.

Write-path safety:
- no DDL/índices/triggers en `aos_llamadas` ni otras tablas operativas;
- INSERT `aos_llamadas` como rol `anon` PASS dentro de rollback antes y después del merge;
- 0 residuos QA.

Performance:
- V2 warm ~393 ms;
- V3 core sin ownership ~98 ms;
- V3 dispatcher kill OFF ~249 ms observado;
- fallback conservador core+V2 ~491 ms;
- todos bajo 1.5 s.

Legacy hashes al cierre:
- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c`;
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00`.

Integración:
- PR #84 MERGED;
- Ascenda CI #743 SUCCESS;
- merge staging `f439f8d33cad841dd6745b07462aec7a264ea6b2`;
- post-merge smoke PASS;
- live kill switch permanece OFF;
- F12 readiness = `READY_NO_LIVE_V3`, `ready_for_f12=true`.

Documento:
`docs/control/commercial-intelligence/PHASE_11_VALIDATION_REPORT.md`

---

# SIGUIENTE FASE

## FASE 12 — ADVISOR WORK VIEWS = READY

Objetivo:
dar al asesor vistas personales priorizadas **dentro de ownership ya autorizado**, sin crear ownership nuevo ni autoasignación.

### Input contracts obligatorios

- F9 ownership/leases;
- F10 Advisor Control read-models;
- F11 routing/claim/consume audit;
- `aos_cia_call_routing_f12_readiness_v1()`.

### F12 debe

1. construir universo personal por `aos_usuarios.id`;
2. mostrar ASSIGNED / IN_PROGRESS / pendientes propios;
3. priorizar callbacks/seguimientos/clientes propios sin cambiar ownership;
4. conservar deadline/expiry visibles;
5. distinguir work view de assignment;
6. usar routing F11 para reflejar trabajo servido/consumido;
7. mantener fallback/compatibilidad de Call Center.

### F12 no debe

- autoasignar contactos;
- leer ownership desde llamadas crudas;
- saltarse F9/F11;
- implementar requests/approvals F13;
- introducir decisiones IA reales F14/F15.

Output esperado:

Work Views personales gobernadas y auditables, listas para Requests & Approval F13.

---

# LOOP UNIVERSAL V2

`recovery → baseline → input handshake → scope/Impact → branch → implementation → guards → QA rollback-only → security → performance → write-path safety → frontend → output handshake → PR/CI → staging smoke → Validation Report → aos_memory → Notion`

No se habilita la siguiente fase hasta tener la fase actual en `100_COMPLETE`.

---

# CONTINUIDAD / RECOVERY

En un nuevo chat/agente recuperar:

1. `AGENTS.md`
2. `docs/control/ASCENDA_CONTROL_MASTER.md`
3. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md`
5. `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md`
6. este Roadmap
7. `PHASE_11_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase11_*`, `cia_phase12_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. verificar `staging` + Supabase live antes de cualquier cambio.
