# ASCENDA OS — FASE 13 VALIDATION REPORT

**Fase:** Requests & Approval Engine  
**Estado actual:** `FUNCTIONAL_VALIDATED / PENDING_PR_CI_STAGING`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `545b7aca32ee649c891e53ce5f42ef48c9de73dd`  
**Branch:** `feature/commercial-intelligence-phase13-requests-approval-20260814`

---

## 1. Resultado funcional pre-merge

F13 implementa un Approval Gate gobernado entre F12 Advisor Work Views y F14 Commercial Intelligence Shadow.

Contrato:

`F12 work-item propio → Request PENDING → ADMIN decision → atomic revalidation → explicit execution → F14 governed proposal context`

Regla estructural:

**Request ≠ Approval ≠ Execution.**

El asesor puede solicitar `RELEASE_ASSIGNMENT`, pero la solicitud no altera ownership. APPROVE no ejecuta. EXECUTE vuelve a bloquear/revalidar el assignment y solo entonces usa el lifecycle F9 existente para liberar ownership.

F14 y KronIA pueden proponer `RELEASE_ASSIGNMENT`, pero el Policy Gate devuelve `REQUIRE_APPROVAL` y `auto_execute=false`.

---

## 2. Scope V1

Único request ejecutable:
- `RELEASE_ASSIGNMENT`.

Bloqueado por policy:
- `AUTO_ASSIGN`;
- `TRANSFER_ASSIGNMENT`;
- `AUTO_APPROVE`;
- `RAW_SQL`.

No se modificó:
- Call Center routing F11;
- `aos_siguiente_lead*`;
- ownership authority F9;
- tablas de llamadas;
- tablas clínicas;
- tablas financieras.

---

## 3. Persistencia y lifecycle

Tablas nuevas:
- `aos_cia_requests`;
- `aos_cia_request_events`.

State machine:
- `PENDING → APPROVED | REJECTED | EXPIRED`;
- `APPROVED → EXECUTED | EXPIRED`;
- estados terminales inmutables.

Guards DB:
- requester UUID + assignment ID + snapshots inmutables;
- solo advisor activo y work-item propio;
- assignment debe estar `ASSIGNED|IN_PROGRESS` y no expirado;
- request expiry ≤ lease expiry y ≤24h;
- unique open `(assignment_id, request_type)`;
- eventos append-only;
- emitter DB único para CREATED/APPROVED/REJECTED/EXPIRED/EXECUTED.

---

## 4. Advisor contracts

Browser RPCs:
- `aos_cia_request_create_v1(...)`;
- `aos_cia_request_advisor_summary_v1(...)`;
- `aos_cia_request_list_advisor_v1(...)`;
- `aos_cia_request_detail_advisor_v1(...)`.

Autoridad:
- advisor resuelto por contrato F11/F12;
- `assignment_id` estable;
- el RPC revalida `advisor_user_id` del assignment.

No acepta `contact_key` como autoridad de ownership.

---

## 5. Admin Approval Gate

Gateway:
`aos_cia_request_admin_gateway_v1(token, action, payload)`

Acciones:
- SUMMARY;
- LIST;
- GET;
- APPROVE;
- REJECT;
- EXECUTE.

Autorización:
- `aos_cia_verify_admin_session_v1()` server-side;
- no confía en rol enviado por browser.

APPROVE/EXECUTE:
- row lock del request;
- row lock del assignment;
- revalidación ownership/state/expiry;
- stale → `EXPIRED` fail-closed;
- ejecución RELEASE usa `aos_cia_assignment_lease_transition_internal_v1(...)`;
- assignment RELEASED + request EXECUTED dentro de la misma transacción.

Idempotencia:
- APPROVE ya APPROVED → PASS idempotente;
- EXECUTE ya EXECUTED → PASS idempotente;
- no existe doble ejecución.

---

## 6. Policy Gate F14/KronIA

`aos_cia_request_policy_gate_v1(...)`:
- ADVISOR + CREATE + RELEASE_ASSIGNMENT → REQUIRE_APPROVAL;
- F14_INTELLIGENCE + PROPOSE + RELEASE_ASSIGNMENT → REQUIRE_APPROVAL;
- KRONIA + PROPOSE + RELEASE_ASSIGNMENT → REQUIRE_APPROVAL;
- ADMIN + APPROVE/REJECT/EXECUTE + RELEASE_ASSIGNMENT → ALLOW;
- AUTO_ASSIGN / TRANSFER_ASSIGNMENT / AUTO_APPROVE / RAW_SQL → BLOCK;
- `auto_execute=false`.

---

## 7. F13 → F14 readiness

`aos_cia_request_f14_readiness_v1()` valida:
- handshake F12→F13;
- requests open stale;
- ownership mismatch;
- duplicate open;
- policy F14/KronIA;
- AUTO_ASSIGN bloqueado;
- RLS y ausencia de acceso directo browser.

Estado live pre-merge:
- `ready_for_f14=true`;
- `status=READY_NO_REQUESTS`;
- requests total=0;
- open=0;
- stale=0;
- owner mismatch=0;
- duplicate open=0;
- browser direct table access=false.

Admin UI consume readiness mediante `aos_cia_request_admin_readiness_v1(token)`.

---

## 8. Security / ACL

`aos_cia_requests` y `aos_cia_request_events`:
- RLS enabled;
- 0 policies;
- anon SELECT/INSERT/UPDATE/DELETE=false;
- authenticated SELECT/INSERT/UPDATE/DELETE=false.

Privados para browser:
- policy gate;
- expiry/internal lifecycle;
- F14 readiness;
- DB guards/event emitter.

Públicos controlados:
- advisor RPCs limitados al advisor resuelto;
- admin gateway/readiness protegidos por CIA ADMIN session.

Todas las funciones F13 auditadas usan `search_path=public`.

El Security Advisor de Supabase conserva advisories históricos del proyecto fuera del scope F13; la superficie F13 fue auditada directamente por RLS/ACL/search_path y no depende de declarar el proyecto completo libre de advisories.

---

## 9. QA E2E rollback-only

Harness temporal ejecutado y eliminado después de la prueba.

PASS:
- cross-advisor request rechazado;
- request válido → PENDING;
- request no cambia assignment;
- duplicado abierto rechazado;
- token ADMIN inválido → UNAUTHORIZED;
- APPROVE válido;
- segundo APPROVE idempotente;
- EXECUTE → assignment RELEASED + request EXECUTED;
- segundo EXECUTE idempotente;
- eventos = CREATED → APPROVED → EXECUTED;
- REJECT terminal sin mutar assignment;
- stale assignment antes de APPROVE → EXPIRED fail-closed;
- F14 policy REQUIRE_APPROVAL;
- KronIA policy REQUIRE_APPROVAL;
- AUTO_ASSIGN BLOCK;
- F14 readiness dentro del QA=true.

Resultado final harness:
- `ok=true`;
- `mode=ROLLBACK_ONLY`;
- `rollback_confirmed=true`;
- 3 requests sintéticos ejercitados.

Zero residue post-QA:
- QA audiences=0;
- activations=0;
- plans=0;
- runs=0;
- assignments=0;
- requests=0;
- request_events=0;
- QA admin sessions=0.

---

## 10. Defectos encontrados y corregidos

### A. CIA admin session digest con search_path restringido

El QA reveló que funciones CIA ADMIN con `search_path=public` llamaban `digest()` sin schema. `digest` vive en `extensions`, por lo que un token largo real fallaba con resolución de función.

Fix:
- `extensions.digest(...)` en verify/issue/claim de CIA admin session.

Post-fix:
- token inválido largo devuelve `{ok:false}` limpiamente;
- no error SQL.

Aprendizaje institucional:
**funciones SECURITY DEFINER con search_path restringido deben schema-qualify funciones de extensiones.**

### B. Idempotencia EXECUTE vs stale revalidation

La primera versión revalidaba el assignment antes de reconocer que el request ya estaba EXECUTED. Como la primera ejecución libera el assignment, una repetición podía responder `REQUEST_STALE` en lugar de idempotent PASS.

Fix:
- detectar APPROVED/EXECUTED ya decididos antes de revalidar recurso para la misma acción;
- mantener revalidación obligatoria para requests aún PENDING/APPROVED que van a mutar.

QA final confirmó idempotencia.

---

## 11. Performance

Target: <1.5 s.

Live `EXPLAIN ANALYZE`:
- advisor list, live empty: **21.655 ms**;
- advisor summary, live empty: **4.477 ms**;
- F13→F14 readiness: **250.167 ms**.

Cardinality model read-only:
- query shape equivalente a 1,000 requests, filtro PENDING, sort, page 100 y JSON aggregation: **5.394 ms total**;
- top-N page sort ~0.36 ms observado.

No se añadieron índices/triggers sobre tablas operativas de Call Center.

Performance gate: **PASS** con margen amplio sobre 1.5 s. El benchmark de 1,000 es read-only/synthetic-query-shape y se etiqueta como tal; el lifecycle mutante fue validado por QA rollback-only, no por `EXPLAIN ANALYZE` mutante.

---

## 12. Frontend

Advisor Work:
- solicitud RELEASE visible solo cuando `requestable=true`;
- modal custom con motivo;
- KPI de requests pendientes;
- historial/estado de propias solicitudes;
- request no cambia ownership.

ADMIN:
- nueva pestaña `Solicitudes F13`;
- KPIs;
- filtros;
- detail + audit events;
- APPROVE;
- REJECT con motivo;
- EXECUTE separado y explícito;
- F14 readiness visible.

Static audit:
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- advisor usa RPC helper;
- admin accede únicamente a RPC gateways, no a tablas F13 directamente.

---

## 13. Replayability

Migrations F13/hardening en Supabase live y versionadas en Git:
- `20260814164340_cia_phase13_request_schema_guards_v1.sql`;
- `20260814164639_cia_phase13_request_contracts_v1.sql`;
- `20260814164751_cia_phase13_request_admin_gateway_v1.sql`;
- `20260814164841_cia_phase13_f14_readiness_v1.sql`;
- `20260814165455_cia_admin_session_digest_schema_fix_v1.sql`;
- `20260814165749_cia_phase13_admin_idempotency_fix_v2.sql`;
- `20260814170410_cia_phase13_admin_readiness_v1.sql`.

Read-only audit:
`scripts/audit_cia_requests_phase13_readonly.sql`.

Durante F13 apareció una migración live concurrente ajena al scope CIA: `20260814165305_restore_2fa_email_branding`. No fue inventada ni absorbida por F13; debe preservarse como cambio concurrente de su propio frente.

---

## 14. Output contract F13 → F14

F14 puede consumir:
- request lifecycle auditable;
- request type/state;
- advisor UUID + assignment_id;
- decision/execution state;
- Policy Gate;
- `aos_cia_request_f14_readiness_v1()`.

F14 debe operar primero en SHADOW:
- detecta oportunidades;
- explica/recomienda;
- puede proponer request gobernado;
- no aprueba;
- no ejecuta;
- no autoasigna;
- no usa SQL arbitrario de escritura.

---

## 15. Gates pre-merge

- P13-G01 recovery/F12 handshake — PASS
- P13-G02 baseline request/approval collisions — PASS
- P13-G03 CRITICAL Impact Report — PASS
- P13-G04 schema/state machine — PASS
- P13-G05 ownership authority — PASS
- P13-G06 duplicate-open guard — PASS
- P13-G07 Policy Gate — PASS
- P13-G08 advisor contracts — PASS
- P13-G09 ADMIN auth boundary — PASS
- P13-G10 atomic revalidation/execution — PASS
- P13-G11 idempotency — PASS
- P13-G12 audit append-only/single-source — PASS
- P13-G13 security/RLS/ACL — PASS
- P13-G14 QA rollback-only/zero residue — PASS
- P13-G15 performance — PASS
- P13-G16 frontend/static audit — PASS
- P13-G17 replayability/audit script — PASS for F13-owned migrations
- P13-G18 F13→F14 readiness — PASS
- P13-G19 PR/CI/staging smoke — **PENDING**
- P13-G20 closure docs/aos_memory/Notion — **PENDING**

**No declarar F13 `100_COMPLETE` hasta G19–G20.**
