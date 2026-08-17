# Sentinel F11 — MCP / AI-Assisted Triage — Impact Report

**Estado:** PRE-IMPLEMENTATION / REQUIRED FIRST ARTIFACT  
**Fecha:** 2026-08-17 America/Lima  
**Fase:** F11 — MCP / AI-Assisted Triage  
**Base:** F1–F10 `100_COMPLETE`  
**Riesgo:** HIGH

## 1. Objetivo
Permitir que ChatGPT/Codex/u otro agente compatible investigue un `SEN-*` usando exclusivamente el reporte diagnóstico sanitizado de F10 y herramientas read-only, y obligar a que toda conclusión material cite evidencia técnica existente.

F11 no elige un proveedor LLM obligatorio. La frontera será vendor-neutral: MCP stdio + triage packet + response validator. Un provider puede conectarse después sin ampliar permisos ni cambiar el contrato de privacidad.

## 2. Decisión MCP baseline
La baseline usa **MCP stdio**, no Streamable HTTP. Motivos:
- reduce superficie de red y autenticación;
- no publica un endpoint nuevo;
- el cliente lanza el proceso local/self-hosted;
- mensajes JSON-RPC UTF-8 via stdin/stdout;
- herramientas expuestas solo en modo lectura.

Protocolo objetivo: MCP revision publicada `2025-11-25`, con soporte mínimo de lifecycle + `tools/list` + `tools/call`. No sampling server-initiated, no elicitation, no tasks, no resources externos y no HTTP auth en la baseline.

Referencias oficiales:
- https://modelcontextprotocol.io/specification/2025-11-25
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
- https://modelcontextprotocol.io/specification/2025-11-25/server/tools

## 3. Anti-scope obligatorio
F11 NO puede:
- escribir Supabase/Railway/GitHub;
- modificar incidentes;
- abrir/fusionar PR;
- generar ni aplicar patches;
- ejecutar comandos de remediación;
- desplegar/rollback;
- acceder a PHI/PII/raw WhatsApp/email/clinical payloads;
- enviar secrets/tokens/cookies al LLM;
- presentar una hipótesis como causalidad confirmada;
- permitir tool names arbitrarios o file reads arbitrarios;
- exponer shell, SQL, HTTP genérico o filesystem genérico como MCP tools.

Remediation pertenece exclusivamente a F12.

## 4. Arquitectura baseline
`F10 diagnostic-report.json → F11 packet builder → sanitized triage packet → MCP stdio read-only tools → external AI/agent → structured triage response → F11 response validator → validated triage report/audit artifact`

Componentes:
1. `f11-contract.json` machine-readable.
2. `triage-packet.cjs` que consume solo `sentinel-diagnostic-report/v1`.
3. `mcp-stdio-server.cjs` minimalista y read-only.
4. `triage-response-validator.cjs` evidence-grounded.
5. synthetic F10 report + synthetic compliant AI response.
6. protocol/security/negative tests.
7. self-hosted workflow FAST + Zero-Cost Linux.

## 5. MCP tools permitidas
Baseline fija, sin tool discovery dinámico desde código externo:
- `sentinel.get_summary`
- `sentinel.list_evidence`
- `sentinel.get_evidence`
- `sentinel.list_hypotheses`
- `sentinel.get_correlation`
- `sentinel.get_triage_packet`

Todas leen el triage packet ya sanitizado. Ninguna acepta path, URL, SQL, shell command o token.

## 6. Input al agente
Solo se entrega:
- `incident_id`;
- severity/status/environment/domain/component/capability/failure_family;
- F10 diagnostic ID y affected SHA state;
- release/commit/deployment sanitizados cuando existan;
- evidence IDs, kind, source, result codes, confidence y refs sanitizadas;
- F10 hypotheses con `causality_confirmed=false`;
- allowed next-step codes;
- guardrails explícitos.

No se entrega el repositorio completo, raw logs, stack traces arbitrarios, DB rows ni textos de clientes/pacientes.

## 7. Response contract obligatorio
Toda respuesta IA aceptable debe ser JSON estructurado `sentinel-triage-response/v1` con:
- mismo `incident_id` y `diagnostic_id`;
- `assessment` breve y sanitizado;
- `claims[]` con `claim_id`, `type`, `statement`, `evidence_refs[]`, `confidence`;
- cada claim material debe citar >=1 evidence ID existente;
- confidence solo `SUPPORTED / PLAUSIBLE / WEAK / UNKNOWN`;
- `causality_confirmed=false` siempre en F11 baseline;
- next steps limitados a códigos read-only allowlisted;
- `provider`/`model` opcionales como metadata técnica no sensible;
- prompt/response digests para auditabilidad.

El validator rechaza:
- claim sin evidencia;
- evidence ref inexistente;
- causality true;
- secretos/PII-like output;
- URLs/query strings arbitrarios;
- remediation/deploy/write action codes;
- campos no allowlisted.

## 8. Audit trail
F11 baseline no crea DDL. El audit trail se materializa como artifact CI efímero:
- incident/diagnostic ID;
- packet digest;
- provider/model metadata opcional;
- validated response digest;
- evidence refs utilizadas;
- validation outcome;
- timestamp técnico.

No se almacena prompt libre ni raw provider response fuera del artifact controlado.

## 9. Zero-Cost gates
G01 — contract + MCP version/transport boundary.  
G02 — F10 report validation + packet builder.  
G03 — Zero-PHI/PII recursive sanitization.  
G04 — deterministic packet digest.  
G05 — MCP initialize/lifecycle.  
G06 — deterministic `tools/list`.  
G07 — six read-only `tools/call` paths.  
G08 — unknown tool/input negative handling.  
G09 — response validator evidence citations.  
G10 — confidence/causality enforcement.  
G11 — sensitive-output/remediation rejection.  
G12 — deterministic synthetic AI-response validation + audit digest.  
G13 — FAST + Linux Zero-Cost.  
G14 — rollback/removal leaves F1–F10 intact; zero DDL/runtime writes.  
G15 — controlled agent-style triage E2E + final certificate + post-merge CI + Notion.

## 10. Gate de salida
F11 solo puede marcarse `100_COMPLETE` si:
1. un packet derivado de F10 puede servirse por MCP stdio;
2. las herramientas son exclusivamente read-only y deterministas;
3. un agente/respuesta sintética evidence-grounded pasa el validator;
4. respuestas sin citas, con PII/secrets, causalidad inventada o acciones de write son rechazadas;
5. packet/response/audit digests son reproducibles;
6. FAST/Linux + exact-head + merge-ref + post-merge quedan verdes;
7. remover F11 no afecta F1–F10.

## 11. Rollback
Rollback baseline = remover/deshabilitar MCP server, packet builder, validator y workflow F11. No existe DDL ni runtime productivo que revertir.

## 12. Cost boundary
La certificación F11 usa provider fake/synthetic y self-hosted CI: **sin consumo de API LLM pagada**. Conectar OpenAI/Claude/u otro proveedor live será un gate separado de configuración, no requerido para certificar la frontera segura y vendor-neutral.
