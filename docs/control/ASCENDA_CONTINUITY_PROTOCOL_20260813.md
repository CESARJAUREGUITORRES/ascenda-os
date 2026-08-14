# ASCENDA OS — Cross-Chat Continuity & Tooling Protocol

Fecha: 2026-08-13
Estado: CURRENT / documental
Ámbito: Todo ASCENDA OS, no solo KronIA.

## 1. Objetivo

Garantizar que cualquier chat, agente o sesión nueva pueda continuar trabajo de ASCENDA OS desde evidencia versionada, sin depender de memoria informal del chat anterior.

## 2. Fuente de verdad

**GitHub `CESARJAUREGUITORRES/ascenda-os` es la autoridad técnica y de continuidad del proyecto.**

Notion, conectores, chats, Supabase, runtime y herramientas de observabilidad tienen funciones complementarias, pero no reemplazan la documentación, código, pruebas y decisiones versionadas en GitHub.

Si dos fuentes discrepan:
1. verificar código/runtime real;
2. corregir GitHub con evidencia mediante branch/PR cuando corresponda;
3. después sincronizar Notion u otras vistas derivadas.

## 3. Bootstrap obligatorio para todo chat/agente

Antes de modificar ASCENDA, el chat/agente debe:
1. identificar el workstream solicitado;
2. leer `AGENTS.md`;
3. leer `SECURITY.md`;
4. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
5. localizar el Índice Maestro/Impact Report específico del workstream;
6. verificar `main`, branch activa, PR y CI relevantes;
7. revisar el último checkpoint y riesgos abiertos;
8. solo entonces ejecutar desde la próxima acción exacta.

No reconstruir decisiones desde memoria si existe evidencia canónica.

## 4. Registro obligatorio al cerrar un loop

Todo trabajo material debe dejar en GitHub, según aplique:
- objetivo y scope/non-scope;
- estado anterior y nuevo;
- archivos/RPC/tablas/endpoints afectados;
- branch, commits y PR;
- migraciones;
- tests y resultados;
- staging/smoke/E2E;
- hallazgos nuevos y cerrados;
- seguridad y permisos;
- reconciliación de datos;
- rollback;
- decisiones arquitectónicas;
- deuda aceptada;
- próxima acción exacta.

Una fase o decisión no se considera preservada únicamente porque figure en una conversación o en Notion.

## 5. Estructura de herramientas

### A. GitHub — authority + execution evidence
Uso:
- código;
- `docs/control/*`;
- decisiones y ADR/Impact Reports;
- Issues/sub-issues/dependencias para unidades de trabajo;
- PRs para cambios verificables;
- Actions para CI/CD y gates automáticos;
- releases/tags para estados desplegables.

### B. Notion — visual mirror / executive control
Uso:
- roadmaps;
- boards;
- dashboards;
- resumen de checkpoints;
- vistas de hallazgos y progreso.

Regla: no almacenar allí como única copia una decisión o evidencia técnica crítica.

### C. Supabase + Railway/runtime — operational state
Uso:
- datos reales;
- funciones/policies/triggers;
- ejecución productiva;
- snapshots/telemetría operacional.

La evidencia relevante se captura de forma reproducible y se documenta/versiona en GitHub.

### D. Sentry — recommended observability layer
Evaluar/adoptar para:
- errores;
- traces;
- performance;
- incident investigation;
- AI/LLM monitoring cuando K4 lo habilite.

Sentry no reemplaza auditoría de negocio ni logs de autorización.

### E. MCP / connectors — controlled interoperability
MCP (Model Context Protocol) sirve para conectar agentes/clientes IA con servicios externos mediante herramientas estandarizadas.

Principios:
- preferir servidores oficiales/gestionados;
- mínimo privilegio;
- read-only por defecto para investigación;
- toolsets allowlisted;
- separar reads y mutations;
- no versionar secretos;
- aprobación humana para HIGH/CRITICAL;
- audit de tool calls;
- MCP nunca salta los gates de autorización de ASCENDA.

Candidatos relevantes:
- GitHub MCP oficial;
- Notion MCP oficial;
- Linear MCP, solo si GitHub Issues/Projects no cubre una necesidad concreta;
- otros MCP solo tras revisión de licencia, mantenimiento, permisos y threat model.

### F. Comunicación
Slack/email/notificaciones pueden recibir CI, incidentes y alertas. Son canales, no fuentes de verdad.

## 6. Regla anti-fragmentación

No introducir Jira, Linear, Airtable u otro gestor para duplicar el mismo backlog sin una limitación demostrada de GitHub Issues/Projects.

Cada herramienta nueva debe responder antes de adoptarse:
1. ¿qué problema concreto resuelve?;
2. ¿qué objeto controla?;
3. ¿cuál es su fuente autoritativa?;
4. ¿qué se sincroniza y en qué dirección?;
5. ¿qué permisos necesita?;
6. ¿qué ocurre si deja de estar disponible?;
7. ¿cómo se evita información divergente?

## 7. Workstreams e índices específicos

Cada frente complejo puede mantener su propio índice debajo de `docs/control/`, pero debe enlazar hacia este protocolo y hacia `ASCENDA_CONTROL_MASTER.md`.

Ejemplo actual:
- KronIA V2: `docs/control/KRONIA_V2_MASTER_INDEX_20260813.md`.

## 8. Contrato de continuidad entre chats

Un nuevo chat que trabaje ASCENDA debe poder responder con evidencia a:
- cuál es la baseline actual;
- qué workstream está tratando;
- cuál es su fase activa;
- cuál fue el último checkpoint;
- qué está bloqueado;
- qué branch/PR contiene el trabajo;
- qué riesgo y release gate aplica;
- cuál es la próxima acción exacta.

Si no puede responderlas, primero debe reconstruirlas desde GitHub antes de escribir o desplegar.

## 9. Orden de precedencia

1. código/runtime verificado para describir el estado real;
2. `AGENTS.md` / `SECURITY.md` para gobernanza;
3. `ASCENDA_CONTROL_MASTER.md`;
4. este protocolo de continuidad;
5. índice/Impact Report del workstream;
6. branch/PR/CI/checkpoints;
7. Notion como mirror visual;
8. conversaciones como contexto auxiliar.

## 10. Regla de actualización

GitHub se actualiza primero con la evidencia técnica duradera. Notion se actualiza después como proyección visual del estado confirmado.
