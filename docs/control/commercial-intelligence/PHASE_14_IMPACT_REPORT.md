# ASCENDA OS — FASE 14 IMPACT REPORT

**Fase:** F14 — Commercial Intelligence Shadow  
**Riesgo:** HIGH  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `b621332ec69142858588172b10ed14cc9d3ec271`  
**Branch:** `feature/commercial-intelligence-phase14-shadow-20260814`

## Objetivo
Construir una capa de inteligencia comercial explicable en SHADOW MODE sobre los contratos certificados F2/F3/F9/F12/F13, sin convertirse en actor autónomo ni modificar ownership, routing, llamadas, ventas, agenda, clínica o finanzas.

## Input handshake
- `aos_cia_request_f14_readiness_v1()` = `ready_for_f14=true`, status `READY_NO_REQUESTS`.
- F13 Policy Gate: `F14_INTELLIGENCE + PROPOSE + RELEASE_ASSIGNMENT => REQUIRE_APPROVAL`, `auto_execute=false`.
- `AUTO_ASSIGN`, `TRANSFER_ASSIGNMENT`, `AUTO_APPROVE`, `RAW_SQL` permanecen BLOCK.
- 11,546 commercial facts / segments / purchase-detail facts observados.
- F9 assignments = 0; F13 requests = 0 al baseline.

## Hallazgo de performance obligatorio
Se rechazó el diseño ingenuo de listar oportunidades mediante join live repetido `aos_cia_customer_segments_v1 + aos_cia_commercial_facts_v1`: `EXPLAIN ANALYZE` midió ~44.4 s por recomputación/materialización pesada. F14 no elevará timeouts. El diseño usa cache de segmentación con coverage/freshness verificados y persiste un snapshot SHADOW; las lecturas UI consultan únicamente la persistencia F14.

## Alcance
- Runs inmutables/auditables de inteligencia SHADOW.
- Recommendations con `evidence`, `confidence`, `sample_size`, `freshness_status`, `explanation` y `policy_decision`.
- Tipos determinísticos iniciales: `UNWORKED_LEAD`, `FOLLOWUP_RECOVERY`, `REACTIVATION`, `REPURCHASE_SIGNAL`, `HIGH_VALUE_ATTENTION`.
- Afinidad observada desde compras/servicios canónicos; no causalidad inventada.
- Gateway ADMIN con sesión CIA server-side.
- Vista advisor limitada a ownership F9 activo y UUID resuelto.
- F15 readiness con guards de integridad, seguridad y Policy Gate.

## Anti-scope
- No autoasignación, transferencia, autoaprobación ni ejecución automática.
- No escritura SQL arbitraria desde IA/browser.
- No historia clínica, fotos, diagnósticos, evoluciones, prescripciones o notas clínicas como features comerciales ordinarias.
- No modificación de `aos_siguiente_lead*`, Call Center V3, F9 ownership, ventas, agenda, llamadas ni tablas clínicas.
- No reemplazo de `aos_sales_intelligence_*` legacy; F14 es paralelo con namespace `aos_cia_intelligence_*`.

## Riesgos y mitigaciones
1. **Performance:** snapshot/materialización; listas nunca recalculan mega-views.
2. **Stale facts/cache:** refresh + coverage exacta + freshness gate; UNKNOWN falla cerrado.
3. **Identidad conflictiva:** recomendaciones con `identity_conflict=true` no se materializan.
4. **Acción autónoma:** recomendaciones son `SHADOW`; acciones sensibles solo se etiquetan con Policy Gate F13, nunca se ejecutan.
5. **Acceso browser:** tablas privadas con RLS y 0 policies; acceso solo por RPC gobernada.
6. **Regression:** DDL aditivo, sin índices/triggers sobre write-path operacional.

## Rollback
- Deshabilitar consumo UI del módulo F14.
- Revocar EXECUTE de RPCs F14 si fuese necesario.
- Las tablas F14 son derivadas y pueden truncarse/eliminarse sin alterar datos fuente.
- Ningún rollback requiere revertir F0–F13 ni modificar ownership/routing.

## Gate de salida
F14 solo puede cerrar `100_COMPLETE` con: handshake F13 PASS; refresh determinístico PASS; explicabilidad/freshness PASS; Policy Gate PASS; RLS/ACL PASS; advisor ownership isolation PASS; performance list/detail <1.5 s; QA/zero operational residue PASS; replayability Git↔Supabase PASS; PR/integration evidence; F15 readiness PASS; `aos_memory` + Notion sincronizados.
