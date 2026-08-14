# ASCENDA OS — FASE 13 IMPACT REPORT

**Fase:** Requests & Approval Engine  
**Riesgo:** `CRITICAL`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `545b7aca32ee649c891e53ce5f42ef48c9de73dd`  
**Branch:** `feature/commercial-intelligence-phase13-requests-approval-20260814`

## Objetivo

Construir un Approval Gate transaccional entre F12 Advisor Work Views y F14 Commercial Intelligence Shadow. El asesor puede solicitar una acción sobre un work-item propio, pero la acción sensible solo puede ejecutarse después de decisión ADMIN verificable y revalidación atómica del ownership/lease F9.

F13 V1 habilita únicamente el request ejecutable `RELEASE_ASSIGNMENT`. No implementa transferencias, autoasignación, ampliación de deadlines, SQL libre ni autoaprobación IA.

## Input contract

Autoridad de entrada:
- `advisor_user_id` UUID resuelto con el contrato F11/F12;
- `assignment_id` F9 como referencia estable del work-item;
- estado y deadlines del lease F9;
- `requestable=true` desde F12;
- `aos_cia_advisor_work_f13_readiness_v1()` como preflight.

`contact_key` no se acepta como autoridad de ownership.

## Código

### Nuevos objetos DB
- `aos_cia_requests`;
- `aos_cia_request_events`;
- guards de lifecycle e inmutabilidad;
- emitter de auditoría single-source;
- Policy Gate F13;
- RPCs advisor create/list/summary/detail;
- gateway ADMIN approve/reject/execute;
- readiness F13→F14.

### Frontend
- `app/public/advisor-work.html|css|js`: creación y estado de solicitudes desde work-items propios;
- `app/public/admin-activaciones.html`: nueva pestaña F13;
- `app/public/admin-activaciones-requests.css|js`: cola administrativa, decisión y ejecución.

### Documentación / auditoría
- `scripts/audit_cia_requests_phase13_readonly.sql`;
- `PHASE_13_VALIDATION_REPORT.md` al cierre.

## Datos

### Nuevas tablas
Solo persistencia CIA nueva. No se añaden columnas, índices ni triggers a tablas clínicas/financieras/Call Center.

### Tablas existentes consultadas
- `aos_cia_assignments`;
- `aos_cia_assignment_plans`;
- `aos_usuarios`;
- F12 work contracts;
- F11/F12 readiness.

### Escritura operacional permitida
Únicamente al ejecutar una solicitud `RELEASE_ASSIGNMENT` ya aprobada, mediante el contrato F9 existente `aos_cia_assignment_lease_transition_internal_v1(...)`. F13 no reimplementa el lifecycle del assignment.

## Invariantes

1. Request nace `PENDING`.
2. Requester UUID y `assignment_id` son inmutables.
3. Solo work-item propio `ASSIGNED/IN_PROGRESS`, no expirado, puede generar request.
4. Un mismo assignment no puede tener dos requests abiertos del mismo tipo.
5. `PENDING → APPROVED|REJECTED|EXPIRED`.
6. `APPROVED → EXECUTED|EXPIRED`.
7. Estados terminales no vuelven atrás.
8. APPROVE y EXECUTE requieren ADMIN session server-side.
9. APPROVE y EXECUTE revalidan ownership/state/expiry bajo row lock.
10. EXECUTE y cambio a `EXECUTED` ocurren dentro de la misma transacción.
11. Auditoría de lifecycle tiene un único productor DB y es append-only.
12. IA/F14 puede proponer, pero nunca aprobar ni ejecutar automáticamente.

## Seguridad

- RLS habilitado en tablas F13.
- 0 policies; sin SELECT/INSERT/UPDATE/DELETE directos para `anon`/`authenticated`.
- RPC internas sin EXECUTE para browser roles.
- RPC advisor solo crea/lee requests del advisor UUID resuelto y no ejecuta recursos.
- Gateway ADMIN usa `aos_cia_verify_admin_session_v1()`; no confía en rol enviado por browser.
- Policy Gate clasifica `RELEASE_ASSIGNMENT` como `REQUIRE_APPROVAL` para advisor/F14/KronIA y bloquea `AUTO_ASSIGN`, `TRANSFER_ASSIGNMENT`, `AUTO_APPROVE`, `RAW_SQL`.
- `SECURITY DEFINER` con `search_path=public` y grants auditados post-DDL.

## Consumidores

- Advisor Work View F12.
- Control ADMIN Commercial Intelligence.
- F14 Commercial Intelligence Shadow como futuro consumidor read/proposal.
- F15 KronIA/Multiagent a través de Policy Gate, no SQL arbitrario.

No se modifica el dispatcher F11, su kill switch ni fallback V2.

## Plan de prueba

1. Preflight F12→F13 = PASS.
2. Baseline de objetos request/approval = 0 colisiones.
3. ACL/RLS deny-by-default.
4. Request de work-item ajeno → rechazo.
5. Request terminal/expirado → rechazo.
6. Request válido → PENDING sin cambiar assignment.
7. Duplicado abierto → rechazo.
8. ADMIN token inválido → `UNAUTHORIZED`.
9. APPROVE válido → APPROVED; segundo approve → no-op/error controlado.
10. Cambio/expiración de lease antes de approve/execute → fail-closed/EXPIRED.
11. EXECUTE RELEASE → assignment RELEASED + request EXECUTED atómicamente.
12. Segundo execute → no doble ejecución.
13. REJECT → terminal sin tocar assignment.
14. Eventos append-only y secuencia correcta.
15. Policy Gate F14/KronIA = REQUIRE_APPROVAL; acciones prohibidas = BLOCK.
16. F14 readiness = true sin violaciones.
17. QA mutante rollback-only y cero residuos.
18. Benchmark list/summary/admin/readiness bajo target 1.5 s.
19. Frontend syntax/loading/empty/error/responsive; 0 `alert/confirm/prompt`.
20. PR + CI + merge staging + smoke post-merge.

## Rollback

### Operativo inmediato
- Eliminar/ocultar integración UI F13 mediante revert del commit frontend.
- Revocar EXECUTE de gateways públicos F13 si se requiere kill inmediato.
- Los objetos F13 pueden permanecer dormidos sin afectar Assignment/Call Center.

### DB
La migración es aditiva. No se utiliza DROP como rollback normal. Si F13 no ha sido utilizado por negocio, una reversión posterior puede retirar objetos F13 de forma versionada; si existen requests reales, conservar tablas/auditoría y desactivar superficies públicas.

### Garantía de no regresión
F13 no altera identidad del assignment, no añade trigger/índice al write-path de `aos_llamadas`, no modifica `aos_siguiente_lead*`, y no cambia F11 routing.

## Output contract F13 → F14

F14 recibe:
- lifecycle de request auditable;
- Policy Gate determinístico;
- estado de approvals/execution;
- readiness `aos_cia_request_f14_readiness_v1()`;
- capacidad de proponer `RELEASE_ASSIGNMENT` en SHADOW con `REQUIRE_APPROVAL`, sin autoacción.

F14 solo pasa a `READY` cuando estos contratos estén integrados, auditados y el smoke post-merge sea PASS.
