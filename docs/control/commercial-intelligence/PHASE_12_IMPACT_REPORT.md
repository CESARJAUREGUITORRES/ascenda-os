# ASCENDA OS — FASE 12 IMPACT REPORT

**Fase:** Advisor Work Views  
**Estado inicial:** IN_PROGRESS  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `69deed08965fbe52058c590dc71110e9db6cd435`  
**Riesgo:** HIGH

---

## Objetivo

Construir vistas personales priorizadas para asesores **dentro del ownership ya creado por Fase 9 y servido/consumido por Fase 11**, sin crear, mover ni reescribir ownership.

Contrato:

`F9 assignment lease + F10 control + F11 routing state → F12 personal work universe/preferences → F13 requestable resource context`

---

## Input handshake obligatorio

- `aos_cia_call_routing_f12_readiness_v1().ready_for_f12 = true`;
- F9 assignments/lease lifecycle intacto;
- F10 advisor control read-models intactos;
- F11 fallback V2, kill switch y legacy hashes intactos;
- ownership siempre por `aos_usuarios.id` UUID.

Baseline observado:
- readiness F12: `READY_NO_LIVE_V3` / ready=true;
- F10 status: `READY_NO_ACTIVE_OWNERSHIP`;
- 6 asesores activos;
- 0 plans/targets/runs/assignments/events persistentes;
- 0 routing events/advisors persistentes;
- global V3 OFF.

---

## Alcance

### Sí

- Work Universe derivado únicamente de `aos_cia_assignments` del advisor UUID;
- estados propios ASSIGNED / IN_PROGRESS y terminales para historial;
- prioridad determinística y explicable;
- deadlines `must_start_before` / `expires_at`;
- señales de F11 routing sobre el assignment propio;
- enrichment comercial read-only desde facts/segmentación;
- preferencias personales no propietarias: pin, snooze, prioridad visual;
- summary/list/detail para advisor;
- readiness output F12→F13;
- nueva vista asesor dentro del shell ASCENDA;
- QA rollback-only y zero residue.

### No

- autoasignar contactos;
- cambiar `advisor_user_id`;
- crear/editar Assignment Plans;
- modificar `aos_siguiente_lead`, `aos_siguiente_lead_v2` o dispatcher F11;
- escribir `aos_llamadas`, leads, agenda, ventas o seguimientos;
- Requests/Approvals F13;
- afinidad/IA decisional F14/F15;
- retirar fallback V2.

---

## Diseño de prioridad V1

Orden base determinístico:

1. `IN_PROGRESS`;
2. `OVERDUE_TO_START`;
3. `EXPIRING_SOON` (≤60m);
4. `FOLLOWUP_OVERDUE`;
5. `FOLLOWUP_PENDING`;
6. Value Tier `DIAMANTE/GOLD/PREMIUM`;
7. resto de ownership activo.

Preferencias personales:
- `pinned=true` eleva visualmente dentro del universo propio;
- `snoozed_until` oculta de la cola default hasta vencer, pero nunca libera ownership;
- `priority_override` limitada a `HIGH/NORMAL/LOW` y solo reordena visualmente.

Work View ≠ Assignment.

---

## Datos / objetos nuevos previstos

Persistencia aditiva:
- `aos_cia_advisor_work_preferences` — solo preferencias del advisor sobre un assignment ya propio.

Read contracts:
- `aos_cia_advisor_work_summary_v1(...)`;
- `aos_cia_advisor_work_list_v1(...)`;
- `aos_cia_advisor_work_detail_v1(...)`;
- `aos_cia_advisor_work_f13_readiness_v1()`;
- action RPC para preferencias sin ownership mutation.

No se crearán triggers/índices sobre tablas operativas legacy.

---

## Seguridad

- nueva tabla con RLS enabled / deny-by-default;
- browser sin SELECT/INSERT/UPDATE directo;
- RPC advisor resuelve UUID con el mismo par `nombre + codigo_asesor` ya usado por F11;
- RPC solo devuelve/modifica filas donde `assignment.advisor_user_id = advisor_uuid`;
- ninguna preferencia puede cambiar assignment/plan/activation/contact/advisor;
- gateway ADMIN no es necesario para una preferencia personal read-only/non-ownership;
- F13 deberá reutilizar `assignment_id`/advisor UUID, no confiar en contact_key crudo.

La autenticación heredada del panel asesor no se rediseña en F12; F12 no amplía sus privilegios más allá del patrón F11 y no introduce escrituras sobre dominio operativo.

---

## Performance

Targets:
- summary/list/detail normales <1.5s;
- page size ≤100;
- no mega-join global;
- filtrar primero por advisor/assignment y enriquecer solo esas filas;
- benchmark con ownership sintético rollback-only.

---

## Frontend

Nueva vista:
- `advisor-work` / “Mi trabajo”;
- panel separado `advisor-work.html/css/js`;
- estados loading / empty / error;
- responsive;
- sin `alert/confirm/prompt`;
- sin lectura directa `/rest/v1/aos_*`;
- no reemplaza Call Center, Seguimientos ni Agenda;
- acciones de pin/snooze/prioridad no cambian ownership.

---

## Write-path safety

F12 no debe tocar write-path legacy. Aun así, antes y después del merge se verificará:
- hashes de `aos_siguiente_lead` y `_v2`;
- F11 readiness;
- INSERT rollback-only de `aos_llamadas` como rol real si el diff alcanza shell/routing;
- 0 residuos QA.

---

## Output contract F12 → F13

F13 deberá recibir un contexto personal gobernado con:
- advisor UUID;
- assignment/work item ID;
- ownership state;
- plan/activation IDs;
- deadline/expiry;
- work category/priority reasons;
- preference state;
- routing evidence F11;
- `requestable=true` únicamente si el assignment sigue siendo propio y no terminal.

F13 podrá crear solicitudes; **no podrá usar F12 para autoasignar**.

---

## Gates P12

- P12-G01 Recovery + F11 handshake
- P12-G02 Baseline ownership/advisors/UI
- P12-G03 Impact/scope/rollback
- P12-G04 Preference schema/RLS
- P12-G05 Work Universe ownership purity
- P12-G06 Priority semantics
- P12-G07 F11 routing evidence
- P12-G08 Preference mutation without ownership change
- P12-G09 Summary/list/detail contracts
- P12-G10 F12→F13 readiness contract
- P12-G11 Security/ACL
- P12-G12 Performance
- P12-G13 QA rollback-only / zero residue
- P12-G14 Frontend advisor work view
- P12-G15 Legacy/write-path no-regression
- P12-G16 Replayability Git↔Supabase
- P12-G17 PR/CI/staging smoke
- P12-G18 Validation/Memory/Notion closure

No se marca `100_COMPLETE` hasta P12-G01..G18 = PASS.
