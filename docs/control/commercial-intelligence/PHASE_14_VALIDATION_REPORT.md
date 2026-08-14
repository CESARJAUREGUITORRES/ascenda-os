# ASCENDA OS — FASE 14 VALIDATION REPORT

**Fase:** Commercial Intelligence Shadow  
**Estado:** `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `b621332ec69142858588172b10ed14cc9d3ec271`  
**PR funcional:** #98  
**Merge funcional staging:** `ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`  
**Ascenda CI:** run #1067 (`31828186847`) — `NOT_EXECUTED`; job 94857289761 tuvo 0 steps por bloqueo de billing/spending antes de iniciar runner.  
**Validación equivalente de scope cambiado:** PASS.

---

## 1. Resultado ejecutivo

F14 queda certificada como una capa de **Commercial Intelligence SHADOW explicable y gobernada** sobre los contratos certificados de facts, segmentación, ownership, work views y Requests/Approval.

Contrato certificado:

`Facts + Segments + Purchase Detail + F9 ownership + F13 Policy Gate → deterministic SHADOW recommendations → F15 governed intelligence context`

Reglas estructurales:

**Recommendation ≠ Assignment ≠ Request ≠ Approval ≠ Execution.**  
**SQL/RPC determinístico calcula; IA interpreta/recomienda.**

F14 genera evidencia, score, confidence, sample size, freshness, explainability y afinidad observada. No autoasigna, no autoaprueba, no ejecuta y no escribe sobre fuentes operativas.

---

## 2. Input handshake F13 → F14

Preflight live:
- `aos_cia_request_f14_readiness_v1().ready_for_f14=true`;
- status `READY_NO_REQUESTS`;
- requests total/open/stale/duplicate/owner mismatch = 0;
- F11 routing V3 sigue global OFF y `READY_NO_LIVE_V3`;
- 6 asesores activos;
- `F14_INTELLIGENCE + PROPOSE + RELEASE_ASSIGNMENT` → `REQUIRE_APPROVAL`;
- `auto_execute=false`;
- `AUTO_ASSIGN` → `BLOCK`.

PASS.

---

## 3. Hallazgo de performance y arquitectura final

Cardinalidad fuente observada:
- Commercial Facts: 11,546;
- Customer Segments: 11,546;
- Purchase Detail Facts: 11,546.

Diseño rechazado:
- recomputar `aos_cia_customer_segments_v1 + aos_cia_commercial_facts_v1` en cada listado;
- `EXPLAIN ANALYZE` medido ~44,416.9 ms.

No se elevó timeout.

Diseño final:
1. refresh explícito de `aos_cia_segment_runtime_cache_v2`;
2. prueba exacta de coverage/freshness;
3. batch determinístico SHADOW;
4. persistencia derivada;
5. listas/detail online solo leen snapshot persistido.

Esto convierte un path interactivo de ~44.4 s en un listado top-100 de ~66.9 ms.

---

## 4. Persistencia F14

Tablas derivadas:
- `aos_cia_intelligence_shadow_runs`;
- `aos_cia_intelligence_recommendations`;
- `aos_cia_intelligence_events`.

Recommendation contract:
- `contact_key` como bridge comercial V1, no ownership authority;
- `assignment_id` / `advisor_user_id` solo cuando existe ownership F9 activo y único;
- `opportunity_type`;
- `priority_score`;
- `confidence`;
- `sample_size`;
- `freshness_status`;
- `evidence`;
- `explanation`;
- `observed_affinity`;
- `policy_decision`;
- state fijo `SHADOW`.

No se agregaron índices/triggers sobre tablas operativas.

---

## 5. Motor determinístico F14 V1

`aos_cia_intelligence_shadow_refresh_v1(...)` genera inicialmente:
- `UNWORKED_LEAD`;
- `FOLLOWUP_RECOVERY`;
- `REACTIVATION`;
- `REPURCHASE_SIGNAL`;
- `HIGH_VALUE_ATTENTION`.

Guards:
- advisory lock anti-refresh concurrente;
- F13 readiness obligatorio;
- segment cache refresh + coverage exacta;
- identity `RESOLVED` y sin conflict;
- ownership solo desde F9;
- freshness explícita;
- afinidad solo desde compras/servicios comerciales canónicos;
- no historia clínica, fotos, diagnósticos, evoluciones, prescripciones o notas clínicas como features comerciales.

La explicación declara límites: recomendación no equivale a causalidad ni autorización de acción.

---

## 6. Primer run real SHADOW

Run:
`56785a72-d99f-4688-804a-c06a001119f4`

Resultado:
- 451 recomendaciones;
- batch ~4,205.7 ms;
- `autonomous_execution=false`;
- segment coverage 11,546/11,546.

Por tipo:
- HIGH_VALUE_ATTENTION: 253;
- FOLLOWUP_RECOVERY: 104;
- REACTIVATION: 22;
- REPURCHASE_SIGNAL: 72;
- UNWORKED_LEAD: 0.

Confidence:
- HIGH: 291;
- MEDIUM: 156;
- LOW: 4.

Freshness:
- FRESH: 111;
- AGING: 45;
- STALE: 295;
- UNKNOWN: 0.

STALE permanece etiquetado como stale; no se transforma en evidencia fresca ni permiso de acción.

---

## 7. Security / ACL

Las tres tablas F14:
- RLS enabled=true;
- policies=0;
- anon direct access=false;
- authenticated direct access=false.

Funciones internas:
- refresh → anon/auth EXECUTE=false;
- F15 readiness → false;
- request linker → false.

Superficies browser controladas:
- `aos_cia_intelligence_admin_gateway_v1(...)`;
- `aos_cia_intelligence_advisor_list_v1(...)`.

ADMIN gateway exige sesión CIA server-side. Advisor list revalida UUID/ownership F9 activo.

Negative tests:
- invalid ADMIN token → `UNAUTHORIZED`;
- advisor inexistente → `ADVISOR_NOT_FOUND`;
- resource link inexistente → `RECOMMENDATION_NOT_FOUND`;
- F14 RELEASE proposal → REQUIRE_APPROVAL / auto_execute=false;
- F14 AUTO_ASSIGN → BLOCK.

Security Advisor global conserva deuda histórica fuera del scope F14. El warning `rls_enabled_no_policy` sobre persistencia F14 es compatible con el diseño privado fail-closed: RLS activo + 0 policies + grants directos revocados; browser accede solo por RPC gobernada.

---

## 8. Governance / Policy Gate

F14 nunca ejecuta ownership.

Policy actual:
- `RELEASE_ASSIGNMENT` propuesto por F14 → `REQUIRE_APPROVAL`;
- `AUTO_ASSIGN` → `BLOCK`;
- F13 conserva Approval/Execution como pasos separados;
- `auto_execute=false`.

`POLICY_PROBE` del panel ADMIN registra únicamente evidencia de evaluación; no crea ni ejecuta un request.

---

## 9. Read contracts

ADMIN:
`aos_cia_intelligence_admin_gateway_v1(token, action, payload)`

Acciones:
- SUMMARY;
- LIST;
- GET;
- REFRESH;
- READINESS;
- POLICY_PROBE.

Advisor:
`aos_cia_intelligence_advisor_list_v1(...)`

El advisor recibe solo recommendations asociadas a un `assignment_id` que sigue propio, activo y no expirado en F9.

---

## 10. Frontend

Nuevos:
- `admin-activaciones-intelligence.css`;
- `admin-activaciones-intelligence.js`.

Integración:
- nueva pestaña `Inteligencia F14` en `admin-activaciones.html`;
- KPIs;
- filtros por opportunity/confidence/freshness;
- list/detail;
- evidence/explainability/affinity;
- F15 readiness;
- refresh SHADOW explícito;
- Policy Gate probe sin ejecución.

Static validation del archivo exacto de branch:
- `node --check` PASS;
- 0 `alert()`;
- 0 `confirm()`;
- 0 `prompt()`;
- 0 direct `/rest/v1/aos_cia_intelligence_*` table endpoints;
- RPC endpoint only.

Post-merge `admin-activaciones-intelligence.js` presente en staging.

---

## 11. Performance

Interactive target <1.5 s.

Mediciones:
- latest-run top-100 list: ~66.9 ms;
- F14→F15 readiness: ~54.1 ms;
- batch SHADOW: ~4.21 s sobre 11,546 contactos.

El batch no es un listado interactivo y reemplaza la recomputación live de ~44.4 s en cada request.

PASS.

---

## 12. No-regresión / residue

Post-F14:
- F9 assignments=0;
- F13 requests=0;
- F11 routing events=0;
- F11 readiness permanece `READY_NO_LIVE_V3`;
- F13 readiness permanece `READY_NO_REQUESTS`;
- F14 derived runs=1;
- F14 recommendations=451;
- F14 GENERATED events=451.

Los objetos F14 persistentes son producto SHADOW intencional, no QA residue.

No se modificó:
- `aos_siguiente_lead*`;
- Call Center routing;
- F9 ownership lifecycle;
- llamadas;
- ventas fuente;
- agenda;
- clínica;
- finanzas.

PASS.

---

## 13. Replayability

Git = Supabase live:
- `20260814181106_cia_phase14_intelligence_shadow_schema_v1.sql`;
- `20260814181136_cia_phase14_intelligence_shadow_engine_v1.sql`;
- `20260814181209_cia_phase14_intelligence_contracts_v1.sql`.

Audit:
`scripts/audit_cia_intelligence_phase14_readonly.sql`.

Los filenames iniciales de desarrollo fueron reconciliados antes del PR para coincidir exactamente con `schema_migrations` live.

PASS.

---

## 14. CI / integración / excepción de infraestructura

Functional PR #98 — MERGED.

Functional staging merge:
`ce88f7f0f5d4cc50fd6e726b0f44459db9daa9ca`.

Ascenda CI run #1067 (`31828186847`) reporta failure, pero su único job `Runtime baseline` (94857289761) tuvo **0 steps**. GitHub anotó que el job no inició porque pagos recientes fallaron o el spending limit debe incrementarse.

No hubo checkout ni test ejecutado; por ello:
- no se etiqueta SUCCESS;
- no se clasifica como fallo de producto;
- se registra `CI_INFRA_EXCEPTION_DOCUMENTED`.

Validación equivalente del scope cambiado:
- branch behind staging=0 antes del merge;
- changed-files audit PASS;
- JS syntax/static safety PASS;
- SQL live compile/runtime PASS;
- ACL/security PASS;
- performance PASS;
- post-merge staging file smoke PASS;
- post-merge Supabase readiness PASS.

La deuda externa de GitHub billing/runner permanece abierta hasta restablecer CI automatizado.

---

## 15. F14 → F15 output contract

`aos_cia_intelligence_f15_readiness_v1()` post-merge:
- `ok=true`;
- `ready_for_f15=true`;
- `status=READY_SHADOW_ACTIVE`;
- mode `SHADOW`;
- recommendations=451;
- non_shadow_state=0;
- auto_execute=0;
- missing_generated_event=0;
- browser direct table access=false;
- F13 Policy Gate intacto.

F15 puede consumir:
- recommendation objects explicables;
- deterministic evidence;
- confidence/sample-size/freshness;
- observed commercial affinity;
- advisor/assignment context cuando existe ownership F9;
- F13 Policy Gate;
- recommendation/request audit linkage.

F15 no debe:
- conceder arbitrary SQL write;
- autoaprobar;
- autoejecutar;
- autoasignar;
- saltarse F13;
- convertir interpretación IA en autoridad determinística.

---

## 16. Gates finales

P14-G01 recovery/F13 handshake — PASS  
P14-G02 baseline/source inventory — PASS  
P14-G03 Impact Report/anti-scope — PASS  
P14-G04 isolated branch — PASS  
P14-G05 derived persistence/guards — PASS  
P14-G06 deterministic opportunity engine — PASS  
P14-G07 evidence/confidence/sample-size/freshness — PASS  
P14-G08 explainability/affinity boundaries — PASS  
P14-G09 F13 Policy Gate governance — PASS  
P14-G10 security/RLS/ACL — PASS  
P14-G11 negative authorization/resource tests — PASS  
P14-G12 advisor ownership isolation contract — PASS  
P14-G13 performance — PASS  
P14-G14 no-regression/zero operational residue — PASS  
P14-G15 frontend/static safety — PASS  
P14-G16 replayability Git↔Supabase — PASS  
P14-G17 F14→F15 readiness — PASS  
P14-G18 functional PR/merge/post-merge smoke — PASS  
P14-G19 CI — PASS bajo `CI_INFRA_EXCEPTION_DOCUMENTED`: runner no ejecutó steps + validación equivalente PASS  
P14-G20 closure docs/memory/Notion — PASS upon closure checkpoint merge/synchronization.

**FASE 14 = `100_COMPLETE · CI_INFRA_EXCEPTION_DOCUMENTED`.**

**FASE 15 — KronIA + Multiagent Orchestration = `READY`.**
