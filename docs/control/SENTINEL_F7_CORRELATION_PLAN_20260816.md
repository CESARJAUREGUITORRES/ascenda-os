# Sentinel F7 — Release, Deploy & Correlation Layer

**Estado:** EN CURSO  
**Fecha:** 2026-08-16 (America/Lima)  
**Baseline:** `main@c1a857fc515397ad9b9b9b6dcbadc6e53df30341`  
**Branch:** `feature/sentinel-f7-correlation`  
**Riesgo:** MEDIUM. Baseline F7 es read-only y no activa cambios runtime.

## 1. Objetivo

Responder de manera demostrable:

- qué SHA/release estaba asociado a una señal;
- qué deployment y ambiente corresponden;
- qué `request_id` / `trace_id` permiten seguir evidencia técnica;
- qué cambio GitHub coincide exactamente o aparece solo como candidato temporal;
- cuál es el último deployment previo **conocido como sano** que podría servir de rollback target;
- cuándo la evidencia es insuficiente y el resultado debe ser `UNKNOWN`.

F7 no afirma causalidad y no ejecuta rollback.

## 2. Recovery técnico

### F3 — Telemetry

Ya existe:

- `service.version` obligatorio;
- `deployment.environment.name` obligatorio;
- `request_id` UUID v4;
- W3C Trace Context;
- `trace_id` de 32 hex;
- propagación portable y sanitizada.

### F4 — Sentry

Ya existe:

- release `ascenda-os@<commit_sha>`;
- fuente principal `RAILWAY_GIT_COMMIT_SHA`;
- environment normalizado;
- Sentry permanece sensor, no fuente canónica de correlación.

### Railway

Railway documenta como system environment variables disponibles en builds/deployments:

- `RAILWAY_GIT_COMMIT_SHA`;
- `RAILWAY_DEPLOYMENT_ID`;
- `RAILWAY_ENVIRONMENT_NAME`;
- `RAILWAY_SERVICE_NAME`;
- `RAILWAY_REPLICA_ID`.

F7 usa solo IDs técnicos. No captura `RAILWAY_GIT_AUTHOR` ni `RAILWAY_GIT_COMMIT_MESSAGE` porque son free text innecesario para correlación.

Railway API no es requisito de F7. Si en fases futuras se añade un conector/API, será una fuente adicional y no una dependencia estructural.

## 3. Correlation Envelope

Campos baseline:

- `system=ascenda-os`;
- `environment`;
- `service_name`;
- `release`;
- `commit_sha`;
- `deployment_id`;
- `replica_id`;
- `request_id`;
- `trace_id`;
- `observed_at`;
- `source`.

No incluye bodies, mensajes, datos de usuario, author/commit message ni secretos.

## 4. Confidence model

### EXACT

`deployment_id` explícito y `commit_sha` coinciden con el deployment del mismo ambiente/servicio.

### STRONG

El SHA/release exacto coincide con un deployment del mismo ambiente/servicio, aunque la señal no traiga `deployment_id`.

### WEAK

Solo existe proximidad temporal dentro de la regression window. Puede mostrarse como **candidate**, nunca como causa.

### UNKNOWN

Falta evidencia, hay contradicción o el scope no coincide.

## 5. Regla de causalidad

Sentinel F7 nunca escribe:

`deployment X caused incident Y`

Solo puede representar:

- exact correlated deployment;
- suspect change candidate;
- deployment in regression window;
- causality `NOT_ESTABLISHED`.

## 6. Rollback target

F7 puede **determinar** un target; no puede ejecutarlo.

Target exacto = deployment más reciente anterior al deployment sospechoso que cumpla simultáneamente:

- mismo environment;
- mismo service;
- `status=SUCCESS`;
- `health_state=HEALTHY`;
- SHA válido;
- fecha anterior al deployment sospechoso.

Si no existe evidencia suficiente: `UNKNOWN`.

La ejecución de rollback pertenece a F12 y requiere sus gates/autorización.

## 7. Gates

| Gate | Criterio |
|---|---|
| F7-G01 Recovery | F3/F4/Railway metadata contracts auditados |
| F7-G02 Privacy | solo IDs técnicos/enums/timestamps; free text y secretos fuera |
| F7-G03 Runtime extractor | fake Railway env produce SHA/release/deployment/env sin free text |
| F7-G04 Exact correlation | incidente sintético identifica SHA + environment + deployment exactos |
| F7-G05 Request/trace | UUID/trace_id válidos pasan sin payload |
| F7-G06 GitHub change | commit exacto puede mapear a PR metadata sanitizada |
| F7-G07 Temporal inference | candidate temporal se marca WEAK y `causality=NOT_ESTABLISHED` |
| F7-G08 Contradiction | release/SHA contradictorios producen UNKNOWN |
| F7-G09 Rollback | target previo known-good se determina; ausencia produce UNKNOWN |
| F7-G10 Cross-platform | Windows FAST + Linux Zero-Cost PASS |
| F7-G11 Scope | sin app runtime mutation, Railway API/token, DB DDL ni secretos |
| F7-G12 Closure | exact-head PASS + certificado + merge + post-merge PASS + Notion |

## 8. Artefactos

- `sentinel/correlation/f7-contract.json`
- `sentinel/correlation/runtime-metadata.cjs`
- `sentinel/correlation/correlation-engine.cjs`
- `ci/sentinel/phase7_correlation_contract.js`
- `ci/sentinel/phase7_correlation_synthetic.js`
- `.github/workflows/sentinel-phase7-correlation.yml`

## 9. Próximo tramo

1. ejecutar CI cross-platform;
2. corregir cualquier contradicción del motor;
3. abrir PR;
4. revisar diff exacto y exact-head CI;
5. generar certificado terminal;
6. merge y post-merge;
7. Notion F7 `Cerrada / 100%` y F8 como única siguiente.
