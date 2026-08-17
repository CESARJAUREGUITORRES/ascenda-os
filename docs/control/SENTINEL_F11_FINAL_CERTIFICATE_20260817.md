# Sentinel F11 — Final Certificate

**Estado:** CERRADA / 100_COMPLETE  
**Fecha de ejecución:** 2026-08-17 (America/Lima)  
**PR:** #240 — MERGED  
**Merge commit:** `3e7faa2395462f3a8bee8674bfe3187f19e25df8`  
**Impact Report:** `docs/control/SENTINEL_F11_AI_TRIAGE_IMPACT_REPORT_20260817.md`  
**Functional head pre-merge:** `dda4a0c441d16a0a45dc51372e354c03bf46e8f1`

## Scope freeze

F11 entrega una frontera de triage asistido por IA, vendor-neutral y read-only, construida sobre el reporte sanitizado F10. No incorpora remediación, escritura productiva, deployment, SQL arbitrario, shell, paths/URLs arbitrarios ni credenciales de producción.

Flujo certificado:

`SEN-* -> F10 diagnostic report -> F11 sanitized triage packet -> MCP stdio read-only tools -> structured AI response -> evidence/confidence validator -> audit digest`

MCP expone exactamente seis herramientas cerradas:

- `sentinel.get_summary`
- `sentinel.list_evidence`
- `sentinel.get_evidence`
- `sentinel.list_hypotheses`
- `sentinel.get_correlation`
- `sentinel.get_triage_packet`

Las annotations MCP de read-only son informativas; el control real también se aplica mediante schemas cerrados, ausencia de herramientas de escritura y el static no-write gate.

## Privacy / evidence guarantees

- toda conclusión material requiere `evidence_refs` existentes;
- confidence labels se validan contra el contrato;
- `causality_confirmed` debe permanecer `false`;
- email, bearer/JWT, provider keys/secrets, query URLs y credential labels se rechazan en el paquete técnico;
- assessment/claims de lenguaje natural además rechazan teléfono peruano y DNI;
- negatives reales certificados: `+51 987654321`, `987654321`, `DNI 12345678`;
- secuencias numéricas dentro de hashes/identificadores técnicos no se clasifican falsamente como PII;
- no se transmite PHI/PII/secrets por diseño del contrato.

## Evidencia ejecutada

### Exact-head funcional

Head: `57e388ebc9ea8b7b6ad5215e961fd2636deb9b5f`

- F11 Certificate run `32058896402`: FAST PASS + Linux Zero-Cost PASS.
- Ascenda CI run `32058896409`: PASS.

### Certificado exact-head

Head: `dda4a0c441d16a0a45dc51372e354c03bf46e8f1`

- exact-head F11 push run `32059618598` reejecutado tras cancelación por concurrency: FAST PASS + Linux Zero-Cost PASS;
- PR merge-ref F11 run `32059622098`: FAST PASS + Linux Zero-Cost PASS;
- PR Ascenda CI run `32059622071`: PASS.

La cancelación inicial del push fue causada por el grupo de `concurrency` al dispararse simultáneamente push + pull_request; se reejecutó el mismo SHA sin cambios y pasó.

### Post-merge G15

Merge commit: `3e7faa2395462f3a8bee8674bfe3187f19e25df8`

- F11 post-merge run `32060081561`: FAST PASS + Linux Zero-Cost PASS;
- Ascenda CI post-merge run `32060081702`: PASS.

Markers certificados:

- `SENTINEL_F11_AI_TRIAGE_CONTRACT_PASS`
- `SENTINEL_F11_RUNTIME_REPLAY=PASS`
- `SENTINEL_F11_ZERO_COST_TRIAGE=PASS`
- `SENTINEL_F11_NO_WRITE_BOUNDARY=PASS`

El E2E sintético ejecuta dos veces el mismo triage y exige igualdad byte-for-byte de packet, validated response y audit artifact.

## Gate matrix

| Gate | Control | Estado |
|---|---|---|
| G01 | Impact Report / scope HIGH-risk congelado antes de implementación | PASS |
| G02 | input F10 schema + safety boundary | PASS |
| G03 | MCP stdio / JSON-RPC + exactamente 6 tools | PASS |
| G04 | schemas cerrados; sin path/URL/shell/SQL arbitrarios | PASS |
| G05 | evidence refs obligatorias y existentes | PASS |
| G06 | confidence labels contractuales | PASS |
| G07 | causalidad inventada bloqueada | PASS |
| G08 | secrets/email/JWT/query-url/credential scan | PASS |
| G09 | Peru phone + DNI real negatives | PASS |
| G10 | deterministic replay byte-for-byte | PASS |
| G11 | vendor-neutral / provider optional | PASS |
| G12 | no-write boundary / minimal permissions | PASS |
| G13 | exact-head FAST + Linux Zero-Cost | PASS |
| G14 | PR merge-ref F11 + Ascenda CI | PASS |
| G15 | post-merge F11 + Ascenda CI sobre `main` | PASS |

## Operational result

F11 permite que un agente investigue un `SEN-*` usando únicamente evidencia técnica sanitizada y herramientas de lectura. No existe en F11 una ruta para aplicar un fix, mutar producción, fusionar o desplegar.

## Terminal decision

**F11 = `CERRADA / 100_COMPLETE`.**

La promoción a F12 — Safe Remediation Loop queda habilitada. F12 debe empezar con Impact Report CRITICAL en branch aislada y conservar aprobación humana obligatoria para cualquier mutación productiva. F13 permanece bloqueada hasta el cierre de F12.
