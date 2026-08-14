# ASCENDA OS — FASE 13 VALIDATION REPORT

**Fase:** Requests & Approval Engine  
**Estado:** `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `545b7aca32ee649c891e53ce5f42ef48c9de73dd`  
**PR funcional:** #95  
**Merge funcional staging:** `594c2c77dae8513ff73a300e60f4caed1996efad`  
**GitHub Actions:** Ascenda CI #997 — `NOT_EXECUTED` por bloqueo de billing/spending del runner; no llegó a checkout ni ejecutó steps.  
**Validación equivalente de scope cambiado:** PASS, documentada abajo.

---

## 1. Resultado ejecutivo

F13 queda certificada como Approval Gate gobernado entre F12 Advisor Work Views y F14 Commercial Intelligence Shadow.

Contrato certificado:

`F12 work-item propio → Request PENDING → ADMIN decision → revalidación atómica → ejecución explícita → F14 governed proposal context`

Regla estructural:

**Work View ≠ Assignment ≠ Request ≠ Approval ≠ Execution.**

El asesor puede solicitar `RELEASE_ASSIGNMENT`, pero la solicitud no altera ownership. APPROVE no ejecuta. EXECUTE vuelve a bloquear/revalidar el assignment y solo entonces utiliza el lifecycle F9 existente para liberar ownership.

F14 y KronIA pueden proponer `RELEASE_ASSIGNMENT`, pero Policy Gate devuelve `REQUIRE_APPROVAL` y `auto_execute=false`.

---

## 2. Scope V1 y anti-scope

Único request ejecutable:
- `RELEASE_ASSIGNMENT`.

Bloqueado por Policy Gate:
- `AUTO_ASSIGN`;
- `TRANSFER_ASSIGNMENT`;
- `AUTO_APPROVE`;
- `RAW_SQL`.

F13 no modificó:
- routing F11;
- `aos_siguiente_lead*`;
- autoridad de ownership F9;
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

Guards:
- requester UUID + `assignment_id` + snapshots inmutables;
- solo advisor activo y work-item propio;
- assignment `ASSIGNED|IN_PROGRESS` y no expirado;
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
- RPC revalida `advisor_user_id` del assignment.

`contact_key` no se acepta como autoridad de ownership.

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
- row lock request;
- row lock assignment;
- revalidación ownership/state/expiry;
- stale → `EXPIRED` fail-closed;
- RELEASE usa `aos_cia_assignment_lease_transition_internal_v1(...)`;
- assignment RELEASED + request EXECUTED dentro de la misma transacción.

Idempotencia:
- APPROVE ya APPROVED → PASS idempotente;
- EXECUTE ya EXECUTED → PASS idempotente;
- no doble ejecución.

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
- Policy Gate F14/KronIA;
- AUTO_ASSIGN bloqueado;
- RLS y ausencia de acceso directo browser.

Post-merge smoke live:
- `ready_for_f14=true`;
- `status=READY_NO_REQUESTS`;
- requests total=0;
- open=0;
- stale=0;
- owner mismatch=0;
- duplicate open=0;
- browser direct table access=false;
- F12→F13 continúa `READY_NO_REQUESTABLE_WORK` / true;
- F11 continúa `READY_NO_LIVE_V3`, global OFF, 0 routing events.

---

## 8. Security / ACL

`aos_cia_requests` y `aos_cia_request_events`:
- RLS enabled;
- 0 policies;
- anon SELECT/INSERT/UPDATE/DELETE=false;
- authenticated SELECT/INSERT/UPDATE/DELETE=false.

Privados para browser:
- Policy Gate;
- expiry/internal lifecycle;
- F14 readiness;
- guards/event emitter.

Públicos controlados:
- advisor RPCs limitados al advisor resuelto;
- admin gateway/readiness protegidos por CIA ADMIN session.

Funciones F13 auditadas con `search_path=public`.

El Security Advisor global conserva deuda histórica fuera del scope F13; esta certificación no declara el proyecto completo libre de advisories.

---

## 9. QA E2E rollback-only

PASS:
- cross-advisor request rechazado;
- request válido → PENDING sin cambiar assignment;
- duplicado abierto rechazado;
- token ADMIN inválido → UNAUTHORIZED;
- APPROVE válido + retry idempotente;
- EXECUTE → assignment RELEASED + request EXECUTED;
- segundo EXECUTE idempotente;
- eventos CREATED → APPROVED → EXECUTED;
- REJECT terminal sin mutar assignment;
- stale assignment antes de APPROVE → EXPIRED fail-closed;
- F14/KronIA REQUIRE_APPROVAL;
- AUTO_ASSIGN BLOCK;
- F14 readiness dentro de QA=true.

Harness:
- `ok=true`;
- `mode=ROLLBACK_ONLY`;
- `rollback_confirmed=true`;
- 3 requests sintéticos ejercitados.

Zero residue post-QA y post-merge:
- audiences QA=0;
- activations=0;
- plans=0;
- runs=0;
- assignments=0;
- requests=0;
- request_events=0;
- routing events=0;
- QA admin sessions=0.

---

## 10. Defectos encontrados y corregidos

### A. CIA admin session digest

Funciones CIA ADMIN con `search_path=public` llamaban `digest()` sin schema; la extensión vive en `extensions`.

Fix:
- `extensions.digest(...)` en verify/issue/claim.

Post-fix:
- token inválido largo devuelve `{ok:false}` sin error SQL.

### B. EXECUTE idempotency

La primera versión revalidaba el assignment antes de reconocer un request ya EXECUTED. Como la primera ejecución libera el assignment, el retry podía parecer stale.

Fix:
- reconocer retries terminales/idempotentes antes de revalidar el recurso ya mutado;
- mantener revalidación obligatoria antes de toda mutación nueva.

QA final PASS.

---

## 11. Performance

Target <1.5s.

Live `EXPLAIN ANALYZE`:
- advisor list: ~21.655 ms;
- advisor summary: ~4.477 ms;
- F13→F14 readiness: ~250.167 ms.

Modelo read-only equivalente 1,000 requests / page 100:
- total ~5.394 ms;
- top-N sort ~0.36 ms.

Performance PASS. El benchmark 1,000 es synthetic read-only query-shape; lifecycle mutante se validó rollback-only.

---

## 12. Frontend

Advisor Work:
- botón RELEASE solo cuando `requestable=true`;
- modal custom + motivo;
- KPI pendientes;
- historial/estado de solicitudes propias.

ADMIN:
- pestaña `Solicitudes F13`;
- KPIs/filtros/detail/audit;
- APPROVE;
- REJECT con motivo;
- EXECUTE separado;
- readiness F14 visible.

Static audit:
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- advisor usa RPC helper;
- admin usa gateways, no tablas F13 directas.

---

## 13. Replayability

Git = Supabase para migraciones F13-owned:
- `20260814164340_cia_phase13_request_schema_guards_v1.sql`;
- `20260814164639_cia_phase13_request_contracts_v1.sql`;
- `20260814164751_cia_phase13_request_admin_gateway_v1.sql`;
- `20260814164841_cia_phase13_f14_readiness_v1.sql`;
- `20260814165455_cia_admin_session_digest_schema_fix_v1.sql`;
- `20260814165749_cia_phase13_admin_idempotency_fix_v2.sql`;
- `20260814170410_cia_phase13_admin_readiness_v1.sql`.

Audit:
`scripts/audit_cia_requests_phase13_readonly.sql`.

Migración concurrente externa `20260814165305_restore_2fa_email_branding` se preservó como cambio de otro frente y no fue falsamente absorbida por F13.

---

## 14. CI / integración / excepción de infraestructura

Functional PR #95 — MERGED.

Functional staging merge:
`594c2c77dae8513ff73a300e60f4caed1996efad`.

Ascenda CI run #997 (`31822630155`) aparece `failure`, pero GitHub registró que el job **no fue iniciado** porque pagos recientes de la cuenta fallaron o el spending limit debía incrementarse. Runtime baseline tuvo 0 steps; no hubo checkout ni test fallido.

Por tanto, no se etiqueta el run como CI PASS ni como fallo de producto.

Validación equivalente aislada del scope cambiado:
- CI workflow revisado: server syntax, public JS syntax, JSON y archivos críticos;
- `app/server.js` no cambió;
- no se modificaron JSON de app;
- archivos críticos base no fueron removidos;
- `node --check` manual aislado PASS para los JS nuevos/modificados F13;
- SQL live compila y fue ejercitado por QA rollback-only;
- post-merge smoke Supabase PASS.

Excepción registrada como `CI_INFRA_EXCEPTION_DOCUMENTED`. La deuda de billing/runner debe resolverse para restaurar CI automatizado; no se falsifica un `SUCCESS` inexistente.

---

## 15. Output F13 → F14

F14 puede consumir:
- lifecycle de request auditable;
- advisor UUID + assignment_id;
- decision/execution state;
- Policy Gate;
- `aos_cia_request_f14_readiness_v1()`.

F14 debe operar primero en SHADOW:
- detectar oportunidades/afinidad;
- explicar/recomendar con evidence/confidence/sample size;
- proponer request gobernado;
- no aprobar;
- no ejecutar;
- no autoasignar;
- no SQL arbitrario de escritura.

---

## 16. Gates finales

P13-G01..G18 = PASS.  
P13-G19 = PASS bajo `CI_INFRA_EXCEPTION_DOCUMENTED`: PR merged + manual CI-equivalent scope validation + post-merge staging smoke; GitHub Actions no ejecutó por billing.  
P13-G20 = PASS al fusionar este closure checkpoint y sincronizar `aos_memory` + Notion.

**FASE 13 = `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.**

**FASE 14 — Commercial Intelligence Shadow = `READY`.**
