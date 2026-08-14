# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## ROADMAP / PHASE STATUS

**Última actualización:** 2026-08-14 (America/Lima)  
**Baseline inicial:** `82d5115fe240b97464850d942b368a982e8e2258`  
**Staging funcional tras Fase 10:** `2a74c3443bb600c1157b746349e1e85dac7f67fc`  
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
| 11 | Call Center Integration V3 | `READY` | 0% |
| 12 | Advisor Work Views | `NOT_STARTED` | 0% |
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
- capacity modes `NO_OPEN_PLANS / BOUNDED / UNBOUNDED / MIXED`;
- utilization solo cuando existe capacidad global determinable;
- advisor drill-down;
- overdue-to-start;
- expiring ≤60m;
- plan health;
- lista general `LAST_RUN_SNAPSHOT` para evitar N+1;
- exact `GET_PLAN` live para detalle de plan;
- readiness estructural F11;
- gateway ADMIN F10 con controles limitados;
- quinta pestaña `Control de asesores`.

### QA certificado

Empty live:
- 6 asesores activos;
- 0 ownership;
- 0 planes;
- 0 alertas;
- readiness `READY_NO_ACTIVE_OWNERSHIP`.

Populated rollback-only:
- 4 active ownership;
- 3 assigned;
- 1 in progress;
- 1 completed;
- 1 released;
- 1 expired;
- 1 overdue;
- 2 expiring;
- capacity MIXED/UNBOUNDED/BOUNDED 50% correctamente diferenciada;
- readiness `READY`;
- 0 residuos.

Adversarial:
- plan ACTIVE + Activation PAUSED → readiness `BLOCKED`;
- violation `active_plan_activation_not_active=1`;
- rollback 0 residuos.

Performance con 1,000 ownership activos:
- overview 4.83 ms;
- advisor detail 50 10.76 ms;
- plan health 14.22 ms;
- F11 readiness 6.09 ms.

Scaling correction:
- primera versión de plan health tenía N+1 sobre F8;
- no se aumentó timeout;
- se reemplazó por `LAST_RUN_SNAPSHOT` en lista + detalle live seleccionado.

Security:
- read-models privados;
- gateway CIA tokenizado;
- F9 RLS intacto;
- límites server-side;
- 0 tablas nuevas de ownership.

Compatibility:
- `aos_siguiente_lead` hash `76412bac81e20ec6cfdc4f8c0db89e8c` intacto;
- `aos_siguiente_lead_v2` hash `cb69781d1457ed73de8f8d52f0f83a00` intacto;
- Call Center 13/08 = 349 llamadas;
- 0 cambios en routing/calls.js.

Integración funcional:
- PR #82 MERGED;
- Ascenda CI #701 SUCCESS;
- merge staging `2a74c3443bb600c1157b746349e1e85dac7f67fc`;
- post-merge smoke PASS.

Documento:
`docs/control/commercial-intelligence/PHASE_10_VALIDATION_REPORT.md`

---

# SIGUIENTE FASE

## FASE 11 — CALL CENTER INTEGRATION V3 = READY

Objetivo:
conectar Assignment F9/F10 con el runtime de Call Center de forma **paralela, reversible y por feature flag**, conservando V2 como fallback.

### Input contracts obligatorios

- F8 availability: `aos_cia_activation_available_keys_v1(activation_id)`
- F9 ownership/leases
- F10 preflight: `aos_cia_advisor_control_f11_readiness_v1()`

### F11 debe

1. ejecutar readiness F10 antes de habilitar routing V3;
2. crear ruta V3 paralela, nunca reemplazar V2 en big-bang;
3. hacer rollout controlado por usuario/flag;
4. preservar `aos_siguiente_lead_v2` como fallback;
5. trabajar con ownership canónico `aos_usuarios.id`;
6. respetar `America/Lima` para semántica de día;
7. probar reserve/claim/consume/release/expiry contra Call Center real;
8. demostrar rollback inmediato a V2;
9. mantener hashes/baseline de routing previos antes de cambios.

### F11 no debe

- redefinir eligibility de F8;
- crear otro Assignment Engine;
- entregar todavía Work Views F12;
- hacer rollout global sin canary.

Output esperado:

routing V3 estable y observable, listo para F12 Advisor Work Views.

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
7. `PHASE_10_VALIDATION_REPORT.md`
8. `aos_memory` claves `cia_v3_*`, `cia_phase10_*`, `cia_phase11_status`
9. Notion CIA Control Maestro / Fases / Hallazgos
10. verificar `staging` + Supabase live antes de cualquier cambio.
