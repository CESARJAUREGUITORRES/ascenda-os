# KronIA V2 — Índice Maestro de Continuidad

Fecha base: 2026-08-13
Programa: ASCENDA OS / KronIA V2 Conversational Control Plane
Estado global: K0 cerrado documentalmente; K1 es la siguiente fase ejecutable.

## 1. Propósito

Este documento es la referencia canónica de continuidad técnica para KronIA V2. Debe permitir retomar el programa desde cualquier chat o sesión sin reconstruir decisiones previas. Notion actúa como tablero operativo; GitHub conserva la fuente versionada y auditable.

## 2. Regla de trabajo

Cada fase K0–K8 debe registrar como mínimo:
- objetivo;
- estado;
- riesgo;
- dependencias;
- scope / non-scope;
- branch;
- commits / PR;
- migraciones;
- tests;
- staging smoke/E2E;
- riesgos y hallazgos vinculados;
- rollback;
- último checkpoint;
- criterio de cierre;
- evidencia de cierre.

Un hallazgo nuevo no se deja como nota aislada: se clasifica por severidad, dominio, fase destino, evidencia, riesgo, solución propuesta, dependencias y criterio de cierre.

## 3. Orden maestro K0–K8

### K0 — Complete Audit & Baseline — CLOSED
Objetivo: inventariar arquitectura, seguridad, voz, agentes, telemetría y deuda; fijar baseline antes de modificar.
Evidencia:
- `docs/control/KRONIA_V2_COMPLETE_AUDIT_20260813.md`
- `docs/control/KRONIA_K1_IMPACT_REPORT_20260813.md`
Commits:
- `f0e99252b4ef87c2ca10626981021a065b3c80c1`
- `f76e3e020d32c885ecf8e187f062dfbba05514d4`

### K1 — Identity, Session & Secrets Hardening — NEXT / CRITICAL
Objetivo: eliminar confianza en claims sensibles del cliente, cerrar exposición de secretos/RPCs, proteger endpoints de agentes y preservar compatibilidad.
Gate: negative auth tests verdes; secretos inaccesibles a browser roles; identidad derivada server-side; RPC/agent endpoints sin bypass; rollback probado.
No-scope: realtime voice, Tool Registry V2, Modal Registry, Watch Engine, nueva autonomía.

### K2 — Tool Registry + Proposal/Approval Engine — PENDING / CRITICAL
Objetivo: herramientas tipadas, policy gate y propuestas persistidas/digest-bound.
Gate: allowlist + schemas + policy + `proposal_id` + expiration + digest + idempotency + optimistic concurrency + approval audit.

### K3 — UI Action Bridge + Modal Registry — PENDING / HIGH
Objetivo: abrir editores nativos de ASCENDA desde KronIA sin duplicar lógica o UI.
Gate: mismo editor funciona desde panel y KronIA; renderer registry tipado; approve/edit/reject enlazado a `proposal_id`.

### K4 — Unified Conversation + AI Gateway + Observability — PENDING / HIGH
Objetivo: `conversation_id` común para texto/voz/UI y ledger real de tokens, costos, latencia, tracing y evals.
Gate: session canonical + provider gateway + ledger reconciliado + observabilidad P50/P95.

### K5 — Brain/Brime Realtime Voice — PENDING / HIGH
Objetivo: conversación de voz realtime con turn detection, barge-in, reconnect y tools gobernadas.
Gate: benchmark aprobado, continuidad 10–20 turnos, interrupciones, ruido de clínica, tool reliability y confirmación visible para HIGH.

### K6 — Watch & Alarm Engine — PENDING / HIGH
Objetivo: reglas determinísticas de vigilancia, dedup, delivery y acknowledgement sin SQL arbitrario generado por IA.
Gate: create → activate → trigger → dedup → delivery → ack E2E.

### K7 — Agent Registry + KronIA Orchestrator — PENDING / HIGH
Objetivo: capability registry versionado, health real, permisos y coordinación KronIA.
Gate: IDs/versiones canónicos, allowed_tools, schemas, autonomy/escalation y liveness observable.

### K8 — Multimodal Rollout + Hardening — PENDING / CRITICAL
Objetivo: integrar y desplegar gradualmente KronIA V2 con seguridad, reconciliación, E2E, rollback y observación post-deploy.
Gate: 20 acceptance gates cumplidos, sin HIGH/CRITICAL abiertos en scope y release explícita.

## 4. Backlog inicial de hallazgos

### K1 blockers / CRITICAL
1. Role falsifiable en boundary legacy KronIA.
2. Direct RPC bypass en funciones SECURITY DEFINER.
3. `aos_kronia_tokens` expuesta a browser roles.
4. `aos_integraciones` como secret exposure boundary.
5. `aos_usuarios` debilita autoridad de identidad.
6. Audit tables con privilegios de mutación demasiado amplios.
7. `/api/agents/*` sin gate autoritativo equivalente.
8. Secrets/config sensibles heredados en `app/server.js`.

### K2 / HIGH
9. Proposal/approval no persistido ni digest-bound.

### K4 / HIGH
10. Telemetría KronIA no reconcilia conversaciones con tokens/costos.

### K5 / HIGH
11. Voice stack duplicado y no realtime.

### K7 / HIGH
12. Agent generation drift y `activo != liveness`.

## 5. Índice de mejora continua

Toda mejora nueva se evalúa con esta secuencia:
1. ¿Es bug, vulnerabilidad, deuda, oportunidad o cambio de arquitectura?
2. ¿Cuál es la severidad y blast radius?
3. ¿Qué dominio toca: Auth, Secrets, RPC, Agents, Voice, UI, Telemetry, Watch, Architecture, Data?
4. ¿En qué K se resuelve sin romper dependencias?
5. ¿Tiene impacto en consumidores existentes?
6. ¿Requiere migración, Impact Report, branch o release gate?
7. ¿Qué test negativo y positivo demuestra cierre?
8. ¿Cuál es el rollback?
9. ¿Qué evidencia exacta permite marcarlo Resuelto?

## 6. Plantilla de checkpoint por fase

Al terminar cada loop, registrar:

- Fase:
- Fecha:
- Estado anterior → estado nuevo:
- Objetivo del loop:
- Cambios realizados:
- Archivos/RPC/tablas afectados:
- Branch:
- Commits:
- PR:
- Migraciones:
- Tests ejecutados:
- Staging smoke/E2E:
- Hallazgos nuevos:
- Hallazgos cerrados:
- Riesgos abiertos:
- Rollback verificado:
- Decisiones de arquitectura:
- Próxima acción exacta:
- Bloqueos/dependencias:

## 7. Reglas de gobernanza

- No mezclar KronIA con otros workstreams en branches activas.
- No confiar en `rol`, `usuario`, `sede` u otros claims sensibles provenientes del browser.
- No permitir SQL arbitrario a agentes ni Watches.
- No introducir realtime voice antes de cerrar K1.
- No crear modales duplicados para KronIA; reutilizar editores de negocio mediante contratos compartidos.
- No considerar `activo=true` como evidencia de health.
- No declarar una fase cerrada sin pruebas, rollback y evidencia.
- HIGH/CRITICAL siguen `AGENTS.md` y `SECURITY.md`.

## 8. Fuentes canónicas

Orden de precedencia para retomar trabajo:
1. `AGENTS.md` y `SECURITY.md`.
2. Este `KRONIA_V2_MASTER_INDEX_20260813.md`.
3. Auditoría K0 e Impact Reports por fase.
4. Código/migraciones/tests de la branch activa.
5. Notion `ASCENDA OS → KronIA V2 — Control Maestro` como tablero operativo y backlog de hallazgos.

## 9. Próxima ejecución

Iniciar K1 desde un baseline limpio, construir primero la matriz de consumidores y el set de negative authorization tests, y solo después aplicar cierres de permisos/RPC/secrets. Cualquier cambio productivo deberá pasar staging y rollback conforme al Impact Report K1.
