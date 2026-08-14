# ASCENDA OS — FASE 15 IMPACT REPORT

**Fase:** F15 — KronIA + Multiagent Orchestration  
**Riesgo:** `CRITICAL`  
**Fecha:** 2026-08-14 (America/Lima)  
**Baseline staging:** `f1febeecd6706d172cbb6a5f2d35e35119fa9004`  
**Branch:** `feature/commercial-intelligence-phase15-kronia-governed-20260814`

## 1. Objetivo cerrado

Construir el plano canónico y gobernado de orquestación IA para CIA V3:

`F14 SHADOW → Agent/Tool Registry → typed invocation → provenance/audit → F13 Policy Gate → governed proposal/request boundary → F16 readiness`

F15 no convierte a KronIA ni a ningún agente en autoridad operacional. El flujo obligatorio es:

`OBSERVE → INTERPRET → PROPOSE → POLICY → REQUEST → HUMAN DECISION → EXECUTE`.

F15 implementa hasta el borde gobernado de propuesta/request; la aprobación y ejecución siguen siendo autoridad F13/humana.

## 2. Input handshake

`aos_cia_intelligence_f15_readiness_v1()` live:
- `ok=true`;
- `status=READY_SHADOW_ACTIVE`;
- `ready_for_f15=true`;
- 451 recomendaciones SHADOW;
- 0 violaciones F14;
- `RELEASE_ASSIGNMENT` = `REQUIRE_APPROVAL`;
- `AUTO_ASSIGN` = `BLOCK`;
- `auto_execute=false`.

**PASS.**

## 3. Hallazgo CRITICAL preexistente

El baseline legacy contiene `public.aos_execute_agent_query(p_query text)`, `SECURITY DEFINER`, ejecutable por `anon` y `authenticated`. Aunque filtra texto para aceptar solo cadenas que comienzan por `SELECT`, ejecuta SQL dinámico arbitrario. Ese modelo no satisface F15 porque:
- permite lectura no tipada fuera de un Tool Registry;
- un `SELECT` puede invocar funciones con efectos secundarios;
- el servidor legacy usa el `anon` key y llama esa RPC para tareas `sql_query` configuradas en DB;
- no existe provenance/policy por herramienta.

También existen RPCs KronIA legacy mutantes que confían en `p_usuario/p_rol` suministrados por caller. Su remediación global pertenece al programa KronIA V2/K1; F15 no las declarará seguras por asociación.

## 4. Estrategia de remediación sin big-bang

1. Crear namespace lógico nuevo `aos_cia_kronia_*`, separado de legacy.
2. RLS ON + 0 browser policies + revocar acceso directo `anon/authenticated` a tablas F15.
3. Tool Registry allowlist: ninguna herramienta `RAW_SQL`.
4. Agent Registry con allowed-tools explícitos.
5. Tool calls y agent runs append-only/auditables.
6. Sensitive tools consultan F13 Policy Gate; `auto_execute` no existe como camino permitido.
7. Crear reemplazo tipado para los `sql_query` legacy actualmente activos que sean necesarios para continuidad, y actualizar el server para no enviar SQL arbitrario a Supabase.
8. Revocar `EXECUTE` de `aos_execute_agent_query` a `anon` y `authenticated` solo después de sustituir el consumidor del servidor.
9. No alterar ni activar los cron/agentes legacy durante el cambio; F15 arranca SHADOW/read-only.
10. Mantener fuera del scope cualquier mutación clínica/KronIA legacy; queda explícitamente bloqueada en el nuevo registry.

## 5. Superficie nueva prevista

Persistencia derivada/control:
- `aos_cia_kronia_tool_registry`;
- `aos_cia_kronia_agent_registry`;
- `aos_cia_kronia_agent_runs`;
- `aos_cia_kronia_tool_calls`;
- `aos_cia_kronia_proposals`.

Contracts:
- registry/readiness;
- server tool gateway con tool-key + typed input;
- admin read gateway;
- policy-probe/proposal;
- F16 readiness.

## 6. Agentes canónicos iniciales

Se preservan nombres/cargos ya existentes en ASCENDA, sin inventar funciones nuevas:
- `kronia` — KronIA / Coordinadora General;
- `centinela` — Dante / Vigilante de Leads;
- `clasificador` — Nico / Clasificador de Leads;
- `analista_mkt` — Valentina / Analista de Marketing;
- `monitor` — León / Monitor de KPIs;
- `analista` — Sofía / Analista de Datos.

F15 registra capacidades gobernadas; no activa cron ni ejecución autónoma.

## 7. Anti-scope

No se autoriza en F15:
- arbitrary SQL;
- autoassign;
- autoapprove;
- autoexecute;
- transferencia de ownership por IA;
- escritura clínica;
- uso comercial ordinario de historia clínica/fotos/diagnósticos/notas;
- habilitar globalmente Call Center V3;
- declarar KronIA V2 K0–K8 completo: F15 CIA y KronIA V2 siguen siendo programas relacionados pero no equivalentes.

## 8. Gates de cierre

F15 solo podrá marcarse `100_COMPLETE` con:
- input handshake PASS;
- registry + orchestration + audit/provenance PASS;
- raw SQL bypass neutralizado para el runtime migrado;
- F13 Policy Gate obligatorio PASS;
- negative auth/allowlist/cross-agent tests PASS;
- rollback-only mutating QA + zero residue PASS;
- ACL/RLS reales PASS;
- performance PASS;
- server syntax/runtime-scope validation PASS;
- migrations Git ↔ live 1:1;
- `aos_cia_kronia_f16_readiness_v1().ready_for_f16=true`;
- PR/CI o excepción CI de infraestructura documentada + validación equivalente;
- staging smoke;
- Validation Report + `aos_memory` + Notion sincronizados.
