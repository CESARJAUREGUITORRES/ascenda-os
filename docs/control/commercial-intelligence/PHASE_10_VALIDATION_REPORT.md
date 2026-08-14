# ASCENDA OS — FASE 10 VALIDATION REPORT

**Fase:** Advisor Control Center  
**Estado:** `VALIDATING`  
**Fecha:** 2026-08-14 (America/Lima)  
**Branch:** `feature/commercial-intelligence-phase10-advisor-control-20260814`  
**Baseline staging real:** `859954ab6d99b4b273b993daaeab4aebb017d035`  
**Input funcional F9:** `2e1116f07919fcf53bdac8cf61cbd23944863630`

---

## 1. Resultado funcional

F10 construye un **Advisor Control Center** administrativo sobre ownership ya producido por F9.

Cadena certificada:

`F9 Assignment → Advisor workload / plan summary / leases / events → F10 Control Center → F11 readiness preflight`

F10 **no reconstruye ownership** desde calls/leads y **no modifica routing**.

---

## 2. Estado live de entrada

Al iniciar F10:

- assignment plans = 0;
- targets = 0;
- runs = 0;
- assignments = 0;
- events = 0;
- asesores activos live = 6.

El estado vacío real fue tratado como contrato de primera clase, no como error.

---

## 3. Read-models F10

Nuevos contratos privados:

- `aos_cia_advisor_control_overview_v1()`
- `aos_cia_advisor_control_advisor_detail_v1(...)`
- `aos_cia_advisor_control_plan_health_v1(...)`
- `aos_cia_advisor_control_alerts_v1(...)`
- `aos_cia_advisor_control_f11_readiness_v1()`

Gateway browser:

- `aos_cia_phase10_admin_gateway_v1(token, action, payload)`

No se crearon tablas nuevas de negocio ni un segundo Assignment Engine.

---

## 4. Estado vacío real

Sobre producción live sin ownership:

- asesores = 6;
- active ownership = 0;
- assigned = 0;
- in progress = 0;
- plans open = 0;
- alerts = 0;
- todos los asesores → `capacity_mode=NO_OPEN_PLANS`;
- utilization = `NULL`, no 0% inventado.

F11 readiness:

- `f11_engineering_ready=true`;
- `status=READY_NO_ACTIVE_OWNERSHIP`;
- global conflicts = 0;
- invalid ownership advisor = 0;
- invalid open targets = 0;
- deadline errors = 0;
- active-plan/activation mismatch = 0;
- `routing_modified=false`.

PASS.

---

## 5. Capacity / utilization semantics

F10 distingue explícitamente:

- `NO_OPEN_PLANS`
- `BOUNDED`
- `UNBOUNDED`
- `MIXED`

Solo `BOUNDED` produce utilization global `%`.

QA poblado rollback-only:

- JHORDANO → `MIXED`, utilization `NULL`;
- JOSELO → `UNBOUNDED`, utilization `NULL`;
- MIREYA → `BOUNDED`, capacity 2, active 1, utilization 50%.

PASS.

---

## 6. QA poblado rollback-only

Se creó dentro de una subtransacción una cadena temporal completa usando:

- preset real `LEADS_UNWORKED`;
- Audience/version F6;
- dos Activations DYNAMIC F7;
- policy `CALL_GENERAL` F8;
- available keys reales F8;
- dos planes F9;
- targets seleccionados desde `aos_usuarios` live;
- 7 leases con estados/deadlines distintos.

Resultados F10:

- active ownership = 4;
- assigned = 3;
- in progress = 1;
- completed = 1;
- released = 1;
- expired = 1;
- overdue-to-start = 1;
- expiring ≤60m = 2;
- alerts = 2;
- plan health rows = 2;
- advisor detail rows = 2;
- F11 readiness = `READY`.

Todos los asserts PASS.

Después del rollback:

- plans = 0;
- targets = 0;
- runs = 0;
- assignments = 0;
- events = 0;
- audiences QA = 0;
- activations QA = 0.

**Zero residue PASS.**

---

## 7. Deadline alerts

F10 identifica:

- `OVERDUE_TO_START`: ASSIGNED cuyo `must_start_before` ya venció;
- `EXPIRING_60M`: ASSIGNED/IN_PROGRESS cuyo lease expira en ≤60 min.

QA:

1. ASSIGNED overdue + expiring;
2. IN_PROGRESS expiring.

Alert rows = 2.

PASS.

---

## 8. F11 readiness contract

Readiness valida estructuralmente:

- duplicate GLOBAL active ownership;
- ownership activo con usuario inexistente/inactivo/no asesor;
- target de plan abierto inválido;
- deadlines ausentes o incoherentes;
- plan F9 ACTIVE cuya Activation ya no está ACTIVE.

QA adversarial rollback-only:

- Activation ACTIVE + F9 plan ACTIVE;
- Activation cambia a PAUSED;
- readiness → `BLOCKED`;
- `f11_engineering_ready=false`;
- `active_plan_activation_not_active=1`;
- `routing_modified=false`.

Rollback dejó 0 residuos.

PASS.

---

## 9. Plan health: defecto encontrado y corrección

La primera versión de `plan_health` llamaba a `aos_cia_assignment_plan_summary_v1()` por cada plan.

Eso obligaba a re-resolver F8 repetidamente y producía un patrón N+1 potencialmente caro. Un benchmark poblado detectó `statement_timeout` durante montaje + health.

**No se aumentó el timeout.**

Corrección:

`20260814065732_cia_phase10_plan_health_scaling_fix_v1.sql`

Semántica final:

- lista general = `LAST_RUN_SNAPSHOT`;
- usa último run + estados actuales de leases;
- health/deadlines son actuales;
- source/candidate/depletion de la lista se etiquetan como estimación del último run;
- `GET_PLAN` sigue siendo el drill-down exacto live de F9 y revalida F8 para un plan seleccionado.

Así se evita N+1 sin fingir freshness.

PASS.

---

## 10. Performance

QA rollback-only con **1,000 ownership activos** sobre 3 asesores.

Resultados F10 después del scaling fix:

- Overview: **4.83 ms**;
- Advisor Detail 50: **10.76 ms**;
- Plan Health: **14.22 ms**;
- F11 Readiness: **6.09 ms**.

Asserts:

- active ownership = 1,000;
- advisor detail = 50 rows;
- plan health = `LAST_RUN_SNAPSHOT`;
- readiness = `READY`;
- todos los read-models <1.5 s.

Después del rollback: 0 plans/assignments/events/audiences QA.

El detalle exacto `GET_PLAN` permanece sobre el contrato F9 ya certificado (~903 ms con 1,000 assignments).

PASS.

---

## 11. Seguridad

Read-models F10:

- `SECURITY INVOKER`;
- `search_path=public`;
- anon EXECUTE = false;
- authenticated EXECUTE = false;
- service_role EXECUTE = true.

Gateway F10:

- `SECURITY DEFINER`;
- `search_path=public`;
- ejecutable por browser roles;
- CIA admin token obligatorio;
- invalid token → `UNAUTHORIZED`;
- payload ≤65,536 bytes.

F9 persistence:

- 5/5 tablas con RLS=true;
- 0 policies permisivas.

Server limits:

- advisor detail ≤100;
- plan health ≤50;
- alerts ≤100.

PASS.

---

## 12. Control actions permitidas en F10

Gateway F10 puede reutilizar únicamente contratos certificados F9 para:

- `PAUSE` / `RESUME` plan;
- `RECONCILE`;
- `TOPUP`;
- `RELEASE_ASSIGNMENT`.

No ofrece:

- CREATE_PLAN;
- ACTIVATE_PLAN;
- CLOSE/CANCEL;
- START/COMPLETE lease;
- routing Call Center.

F10 no se convierte en un segundo Assignment Engine ni adelanta Work Views.

PASS.

---

## 13. Frontend

Activaciones incorpora quinta pestaña:

**Control de asesores**

Archivos:

- `admin-activaciones-control.css`
- `admin-activaciones-control.js`
- actualización aditiva de `admin-activaciones.html`.

La UI muestra:

- KPIs de ownership;
- readiness F11;
- carga por asesor UUID;
- capacity mode/utilization;
- drill-down de leases;
- deadlines;
- health de planes;
- exact live detail por plan;
- alertas;
- controles administrativos limitados.

Controller audit:

- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 direct `/rest/v1/aos_*` table reads.

Responsive:

- desktop;
- tablet;
- mobile;
- tables con overflow horizontal.

CI/staging todavía pendientes al momento de crear este informe.

---

## 14. Replayability

Supabase live registra:

1. `20260814064201_cia_phase10_advisor_control_read_contracts_v1`
2. `20260814064219_cia_phase10_admin_gateway_v1`
3. `20260814065732_cia_phase10_plan_health_scaling_fix_v1`

Git contiene exactamente esos tres timestamps con el SQL ejecutado live.

Los nombres provisionales pre-aplicación permanecen únicamente como archivos comentario:

`SUPERSEDED / NEVER APPLIED`.

PASS.

---

## 15. Call Center / legacy compatibility

Hashes live F10 vs cierre F9:

- `aos_siguiente_lead` = `76412bac81e20ec6cfdc4f8c0db89e8c` — idéntico;
- `aos_siguiente_lead_v2` = `cb69781d1457ed73de8f8d52f0f83a00` — idéntico.

Último día operacional completo 2026-08-13:

- llamadas guardadas = **349**;
- última actividad observada incluye escrituras reales de WILMER/MIREYA antes del cambio de día Lima.

A las ~01:32 Lima del 14/08 todavía había 0 llamadas del nuevo día, coherente con la hora y no indicativo de fallo.

Diff F10 no toca:

- `calls.js`;
- `aos_siguiente_lead*`;
- `aos_cola_config`;
- `aos_leads_en_curso`;
- tablas operativas de calls/leads/agenda/ventas.

PASS.

---

## 16. Handoff F10 → F11

Output autoritativo nuevo:

`aos_cia_advisor_control_f11_readiness_v1()`

F11 deberá:

1. ejecutar este readiness como preflight;
2. permanecer bloqueada si `status=BLOCKED`;
3. construir routing V3 **paralelo**, no reemplazo big-bang;
4. usar feature flag / rollout controlado por usuarios;
5. conservar fallback V2;
6. mantener timezone `America/Lima`;
7. no reconstruir eligibility/ownership.

F10 deja explícitamente `routing_modified=false`.

---

# GATES

- P10-G01 recovery/preflight — PASS
- P10-G02 baseline F9/live — PASS
- P10-G03 Impact Report/scope — PASS
- P10-G04 read-model overview — PASS
- P10-G05 capacity/utilization semantics — PASS
- P10-G06 advisor drill-down — PASS
- P10-G07 plan health/depletion — PASS after scaling fix
- P10-G08 deadline alerts — PASS
- P10-G09 F11 readiness contract — PASS
- P10-G10 gateway/admin authorization — PASS
- P10-G11 empty-state real — PASS
- P10-G12 populated QA rollback-only — PASS
- P10-G13 security/ACL — PASS
- P10-G14 performance — PASS
- P10-G15 frontend/responsive/a11y contract — PASS static / CI pending
- P10-G16 no-regression Call Center — PASS
- P10-G17 replayability Git↔Supabase — PASS
- P10-G18 PR/CI/staging smoke — PENDING
- P10-G19 docs/aos_memory/Notion — PENDING

## Veredicto actual

**FASE 10 = VALIDATING.**

Solo faltan integración PR/CI/staging y cierre documental/memory/Notion. No hay feature funcional pendiente.
