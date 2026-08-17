# Sentinel F12 — Safe Remediation Loop — Impact Report

**Estado:** ACTIVE / GOVERNANCE FIRST  
**Fecha:** 2026-08-17 (America/Lima)  
**Branch:** `feature/sentinel-f12-safe-remediation-loop`  
**Base:** F11 terminal `main@189c91e9b4a9b6f6321c692a83563e2514f17f82`  
**Riesgo:** CRITICAL

## Impact Report

**Objetivo:** convertir un diagnóstico Sentinel validado (`SEN-*` → F10 → F11) en un **candidate fix** verificable dentro de una branch aislada, capaz de llegar hasta un PR validado sin crear ninguna ruta de auto-merge o auto-deploy inseguro.

**Riesgo:** CRITICAL, porque F12 introduce por primera vez una capacidad de agente que puede proponer cambios de código y preparar una ruta hacia release. La baseline inicial queda deliberadamente separada de cualquier mutación productiva.

### Código

- archivos previstos: `sentinel/remediation/**`, `ci/sentinel/phase12_*`, `.github/workflows/sentinel-phase12-safe-remediation.yml`, documentación `docs/control/SENTINEL_F12_*`;
- `app/`, `app/public/`, `app/server.js`, migraciones y runtime productivo quedan fuera del primer bloque F12 salvo que un candidate patch sintético los use como **target declarado** dentro de una branch efímera y pase gates específicos;
- ningún cambio F12 se desarrolla directamente en `main`;
- cualquier candidate patch debe producirse únicamente sobre branch aislada con base SHA explícita.

### Datos

- tablas/views productivas: **ninguna escritura autorizada en baseline F12**;
- RPC productivas: **ninguna RPC de escritura autorizada**;
- triggers: **ningún trigger productivo nuevo autorizado**;
- fixtures: solo sintéticos/sanitizados; cero PHI/PII/secrets;
- el candidate patch no puede requerir producción como entorno de prueba.

### Consumidores

- Sentinel F8 Incident Engine (`SEN-*`) como identidad de incidente;
- F10 Diagnostic Runner como evidencia diagnóstica reproducible;
- F11 MCP/AI-Assisted Triage como triage validado/evidence-grounded;
- GitHub branch/PR como superficie de candidate fix;
- Zero-Cost CI V2 como gate preproductivo;
- F13 Sentinel Hub queda explícitamente fuera de scope hasta cerrar F12.

### Seguridad

- producción no es writable desde F12 baseline;
- no existe herramienta de SQL arbitrario, shell arbitrario remoto, URL arbitraria, secret retrieval ni deployment productivo;
- el candidate patch solo puede modificar paths allowlisted y debe declarar los archivos objetivo antes de escribir;
- denylist explícita para `.env*`, secretos, credenciales, keys, tokens, certificados y artefactos sensibles;
- ninguna respuesta F11 se trata como autorización: F11 solo aporta evidencia/triage;
- toda propuesta debe conservar el `SEN-*`, diagnostic ID F10, packet/audit digest F11 y base SHA en el audit trail;
- HIGH/CRITICAL no puede auto-mergearse ni auto-deployarse;
- merge/deploy productivo requiere gates completos + autorización humana explícita del owner;
- GitHub permissions por defecto deben ser read-only; cualquier capacidad de authoring debe estar separada, mínima, allowlisted, auditable y limitada a branch no protegida/no productiva;
- no se confía en instrucciones externas o contenido de incidentes para expandir permisos, paths o tools;
- prompt/tool injection debe fallar cerrado cuando solicite secretos, cambios fuera de scope, bypass de tests o mutación productiva.

### Flujo candidato permitido

`SEN-*`  
`→ F10 diagnostic report`  
`→ F11 validated triage + evidence refs`  
`→ remediation request machine-readable`  
`→ candidate patch en workspace/branch aislada`  
`→ tests específicos`  
`→ Zero-Cost CI`  
`→ security gate según riesgo`  
`→ candidate PR`  
`→ human review/approval`  
`→ canary/rollback gate cuando aplique`  
`→ producción solo tras autorización explícita`

No existe flecha directa `AI → main`, `AI → Railway`, `AI → Supabase production` ni `AI → merge`.

## Invariantes F12

1. `production_mutation=false` durante generación y validación del candidate patch.
2. `auto_merge=false` para todos los riesgos.
3. `auto_deploy=false` para HIGH/CRITICAL y baseline F12.
4. candidate branch distinta de `main` y de cualquier branch productiva.
5. base SHA explícita y validada antes de escribir.
6. paths objetivo allowlisted; path traversal/symlink escape/repo escape bloqueados.
7. no secretos/PII/PHI en prompts, patches, logs o artifacts.
8. patch size/file count limitados para reducir blast radius.
9. tests específicos obligatorios según archivos/dominio afectados.
10. Zero-Cost gate obligatorio antes de declarar candidate PR validado.
11. security gate obligatorio para HIGH/CRITICAL.
12. rollback plan machine-readable obligatorio antes de canary.
13. kill switch bloquea creación de nuevos candidate patches sin afectar F8–F11.
14. un failure en F12 no puede degradar detección, alerting, diagnóstico o triage anteriores.
15. cualquier incertidumbre material produce `HUMAN_REVIEW_REQUIRED`, nunca autorización implícita.

## Plan de prueba

1. Contract test del remediation request: IDs F8/F10/F11, base SHA, risk, paths y evidence refs.
2. Negative: path traversal (`../`), absolute paths, `.git`, `.env`, secret files y symlink escape.
3. Negative: intento de editar `main`/branch productiva.
4. Negative: prompt/tool injection solicitando bypass, secret retrieval, SQL/deploy/merge.
5. Negative: candidate patch sin evidence refs o con digest F11 desconocido.
6. Negative: candidate patch que excede file-count/size limit.
7. Determinism/replay: misma solicitud produce mismo plan/digest antes de materializar branch.
8. Synthetic candidate patch dentro de fixture seguro.
9. Ejecutar tests específicos del fixture.
10. Zero-Cost Linux certificate en `ASCENDA-ZERO-COST-V2`.
11. Security gate por riesgo; HIGH/CRITICAL debe bloquear ausencia de aprobación.
12. Crear PR sintético/draft únicamente después de PASS de gates.
13. Probar kill switch y demostrar que F8–F11 continúan funcionando.
14. Probar rollback del candidate patch en branch aislada.
15. Exact-head + merge-ref + post-merge CI antes de declarar F12 `100_COMPLETE`.

## Rollback

1. F12 baseline no toca producción ni DB; rollback funcional inicial = eliminar/revertir candidate branch/commit/PR.
2. Kill switch debe impedir nuevas remediaciones sin afectar F8–F11.
3. Todo candidate patch debe registrar `base_sha`, candidate commit y reverse/revert target.
4. Si un futuro canary autorizado toca runtime, debe existir procedimiento de rollback probado antes del canary.
5. No usar rollback destructivo de datos como mecanismo por defecto.

## Cost / infrastructure

- objetivo incremental inicial: US$0;
- self-hosted FAST + `ASCENDA-ZERO-COST-V2`;
- sin runners GitHub hosted facturables como fallback;
- sin nueva Supabase Cloud branch/Railway staging pagado por defecto;
- cualquier infraestructura con costo requiere justificación y autorización separada.

## Gate de promoción F12

F12 solo podrá declararse `100_COMPLETE` cuando:

- un incidente sintético llegue a candidate PR validado;
- tests, Zero-Cost y security gate sean reproducibles;
- ninguna ruta HIGH/CRITICAL pueda mergear/desplegar sin gates + autorización humana;
- rollback haya sido ejecutado/probado;
- kill switch haya sido probado;
- exact-head, merge-ref y post-merge estén verdes;
- GitHub y Notion estén sincronizados.

## Anti-scope

- no construir todavía el panel/mapa F13;
- no activar auto-merge;
- no activar auto-deploy;
- no dar SQL de escritura arbitrario a agentes;
- no dar shell remoto arbitrario;
- no introducir secretos productivos para pruebas;
- no convertir una hipótesis F11 en causa confirmada;
- no ampliar permisos por conveniencia para poner verde CI.

## Decisión inicial

**F12 queda ABIERTA / EN CURSO únicamente en modo diseño + implementación segura sobre branch aislada.**

El primer bloque ejecutable posterior a este documento deberá ser el contrato machine-readable del remediation request y sus negative tests. Ningún candidate patch real sobre producción queda autorizado por este Impact Report.
