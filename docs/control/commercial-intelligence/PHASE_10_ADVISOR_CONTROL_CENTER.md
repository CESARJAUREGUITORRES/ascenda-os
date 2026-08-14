# FASE 10 — ADVISOR CONTROL CENTER

**Estado:** IN_PROGRESS / PRE-DDL IMPACT REPORT  
**Fecha:** 2026-08-14 (America/Lima)  
**Branch:** `feature/commercial-intelligence-phase10-advisor-control-20260814`  
**Base staging:** `859954ab6d99b4b273b993daaeab4aebb017d035`  
**Input funcional F9:** `2e1116f07919fcf53bdac8cf61cbd23944863630`

---

## 1. Objetivo

Construir el **Advisor Control Center** como control plane administrativo sobre ownership ya producido por Fase 9.

Debe permitir observar y gobernar, sin reinterpretar calls/leads:

- carga activa por `aos_usuarios.id`;
- ASSIGNED / IN_PROGRESS / COMPLETED / RELEASED / EXPIRED;
- planes abiertos/activos;
- overdue-to-start;
- leases que expiran próximamente;
- capacidad y utilización con semántica explícita;
- source available, candidate remaining y depletion por plan;
- drill-down de ownership y deadlines;
- readiness estructural para F11.

---

## 2. INPUT CONTRACT — F9 → F10

Autoritativos:

- `aos_cia_assignment_advisor_workload_v1()`
- `aos_cia_assignment_plan_summary_v1(plan_id)`
- `aos_cia_assignment_plan_list_v1(...)`
- `aos_cia_assignment_list_v1(...)`
- `aos_cia_assignment_events_v1(...)`

Ownership continúa siendo exclusivamente F9.

---

## 3. OUTPUT CONTRACT — F10 → F11

F10 entregará un contrato read-only de readiness con, al menos:

- asesores activos;
- planes open/active/paused;
- leases activos;
- overdue-to-start;
- expiring leases;
- conflictos GLOBAL activos;
- leases activos con asesor inválido/inactivo;
- leases activos sin deadline requerido;
- planes activos cuyo Activation ya no está ACTIVE;
- estado `READY`, `READY_NO_ACTIVE_OWNERSHIP` o `BLOCKED`.

F11 deberá usar este control plane como preflight antes de conectar routing V3.

---

## 4. ANTI-SCOPE

F10 **NO**:

- modifica `aos_siguiente_lead` ni `aos_siguiente_lead_v2`;
- modifica `calls.js`, `aos_cola_config` o `aos_leads_en_curso`;
- reconstruye ownership desde llamadas/leads;
- crea otro Assignment Engine;
- crea Work Views personales para asesores;
- implementa routing Call Center V3;
- implementa approvals;
- usa afinidad IA como decisión real.

---

# 5. IMPACT REPORT

**Riesgo:** HIGH

### Código

Previsto:

- `app/public/admin-activaciones.html`
- nuevo `app/public/admin-activaciones-control.js`
- nuevo `app/public/admin-activaciones-control.css`
- migrations F10 read contracts + gateway.

No tocar `app/public/calls.js`.

### Datos

Lectura sobre:

- `aos_cia_assignment_plans`
- `aos_cia_assignment_targets`
- `aos_cia_assignment_assignments` / tabla real `aos_cia_assignments`
- `aos_cia_assignment_events`
- `aos_usuarios`
- Activation/context F7/F8 solo para health/readiness.

Persistencia nueva de negocio: **ninguna prevista**.

### RPC

Nuevos contratos F10 propuestos:

- `aos_cia_advisor_control_overview_v1()`
- `aos_cia_advisor_control_advisor_detail_v1(...)`
- `aos_cia_advisor_control_f11_readiness_v1()`
- `aos_cia_phase10_admin_gateway_v1(token, action, payload)`

El gateway F10 reutilizará mutaciones F9 certificadas; no escribirá directamente ownership.

### Seguridad

- browser solo vía gateway F10 con CIA admin token;
- read-models internos revocados a PUBLIC/anon/authenticated;
- `SECURITY DEFINER` solo en gateway si es necesario;
- `search_path=public` explícito;
- ninguna superficie asesor en F10.

### Performance

Targets:

- Overview P95 < 1.5 s;
- advisor detail 50 filas P95 < 1.5 s;
- F11 readiness P95 < 1.5 s;
- UI normal < 2.5 s incluso con planes múltiples.

### No-regresión operacional

Obligatorio verificar:

- hashes/definiciones de `aos_siguiente_lead*` sin cambios;
- `calls.js` sin diff;
- Call Center continúa guardando llamadas;
- 0 cambios en tablas operativas de calls/leads/agenda/ventas.

### Rollback

1. retirar módulo frontend F10;
2. revocar/drop únicamente RPC F10 nuevos si fuese necesario;
3. F9 permanece intacta;
4. no existe migración de datos fuente ni routing que revertir.

---

## 6. Semántica de capacidad

No presentar `0%` cuando la capacidad no está definida.

Por asesor:

- `BOUNDED`: todos sus targets abiertos tienen `capacity_limit` y se puede calcular utilization %;
- `UNBOUNDED`: ningún target abierto tiene capacity;
- `MIXED`: existen targets bounded + unbounded; utilization % global será `NULL`/no aplicable.

Capacidad conocida = suma de `capacity_limit` de targets en planes ACTIVE/PAUSED.

---

## 7. Gates F10

- P10-G01 recovery/preflight — IN_PROGRESS
- P10-G02 baseline F9/live — PASS (ownership live vacío)
- P10-G03 Impact Report / scope — PASS
- P10-G04 read-model overview — PENDING
- P10-G05 capacity/utilization semantics — PENDING
- P10-G06 advisor drill-down — PENDING
- P10-G07 plan health/depletion — PENDING
- P10-G08 deadline alerts — PENDING
- P10-G09 F11 readiness contract — PENDING
- P10-G10 gateway/admin authorization — PENDING
- P10-G11 empty-state real — PENDING
- P10-G12 populated QA rollback-only — PENDING
- P10-G13 security/ACL — PENDING
- P10-G14 performance — PENDING
- P10-G15 frontend/responsive/a11y — PENDING
- P10-G16 no-regression Call Center — PENDING
- P10-G17 replayability Git↔Supabase — PENDING
- P10-G18 PR/CI/staging smoke — PENDING
- P10-G19 docs/aos_memory/Notion — PENDING

**100_COMPLETE requiere P10-G01..G19 PASS.**
