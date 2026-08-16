# Sentinel F5 — Hybrid Observer Plan

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `HYBRID_IMPLEMENTATION_IN_PROGRESS`  
**Baseline:** `main@28dfdeafbf66cfa79f6fcec132e607d40529ee37`  
**Costo incremental objetivo:** `US$0/mes`

## Decisión

F5 adopta dos capas independientes:

1. **Cloud Coverage — Sentry Uptime**: un monitor cloud sobre `GET /health`, usando el monitor incluido en el plan Developer. Esta capa cubre períodos en los que CREACTIVE está apagada.
2. **Local Deep Observer — Docker en CREACTIVE**: Uptime Kuma + Sentinel Local Observer se ejecutan como contenedores persistentes `restart: unless-stopped`. Cuando CREACTIVE/Ubuntu/Docker está apagado, la capa local es `UNKNOWN`; no se interpreta como caída de ASCENDA.

Sentinel Core no dependerá de la API de Sentry para operar. El historial cloud se conserva en Sentry; la correlación automática con incidentes pertenece a F7/F8/F11.

## Autoarranque CREACTIVE

Baseline certificable:

`CREACTIVE encendida → Ubuntu/Docker disponible → Docker restart policy → Kuma + Local Observer`

Propiedades:

- no requiere `powershell.exe`, WSL interop ni Task Scheduler para la baseline;
- Kuma en `127.0.0.1:3001`;
- Kuma y observer con `restart: unless-stopped`;
- volumen Docker persistente para Kuma;
- estado/historial técnico persistente en `~/.local/share/ascenda-sentinel/availability/state`;
- observer en contenedor Python read-only, `cap-drop ALL`, no-new-privileges;
- si CREACTIVE está apagada, ASCENDA continúa sin dependencia local;
- una tarea Windows de logon puede añadirse después como comodidad, pero no es gate F5.

## Gap reconciliation

El local observer mantiene dos historiales separados:

- heartbeat del observer;
- muestras sanitizadas de `/health`.

Al reiniciar:

1. lee el último heartbeat local;
2. si la diferencia supera 120 s, crea `coverage_gap` con estado `UNKNOWN`;
3. prohíbe afirmar retrospectivamente que ASCENDA estuvo HEALTHY/DOWN durante el gap;
4. realiza un probe inmediato de `/health`;
5. crea `resume-report.json` con gap + estado actual + referencia al historial cloud Sentry.

Campos locales permitidos: timestamp, HTTP status, duración, booleanos de health y error técnico. Cero PHI/PII, bodies, tokens o auth headers.

## Gates revisados F5

| Gate | Resultado requerido | Estado |
|---|---|---|
| G01 | F4 100% | PASS |
| G02 | `/health` seguro | PASS |
| G03 | contrato availability | PASS |
| G04 | state machine + anti-flapping | PASS |
| G05 | Kuma compose privacy-safe | PASS |
| G06 | FAST contract | PASS |
| G07 | Linux disposable Kuma smoke | PASS |
| G08 | cleanup + zero-cost | PASS |
| G09 | arquitectura híbrida autorizada; CREACTIVE local + Sentry cloud | PASS |
| G10 | Sentry Uptime monitor configurado + observer Docker persistente desplegado | PENDING CLOUD UI / AUTO-DEPLOY |
| G11 | restart/gap + outage/recovery sintético | PENDING |
| G12 | certificado final + Notion + F6 siguiente | PENDING |

**Progreso lógico actual:** `9/12 = 75%`.

## Human boundary restante

### F5-CLOUD-01
En Sentry → Monitors → Uptime, crear/verificar un único monitor sobre:

`https://ascenda-os-production.up.railway.app/health`

Sin headers, body, cookies ni credenciales.

### F5-LOCAL-01
Se intenta automáticamente desde GitHub sobre CREACTIVE mediante `deploy-docker-observer.sh`. No requiere secretos ni cambios de Windows. Si Docker está disponible, el gate puede cerrarse sin intervención humana.

### F5-RECOVERY-01
Validar:

- Kuma accesible solo en `localhost:3001`;
- restart del observer produce/reconoce `UNKNOWN / coverage_gap` cuando corresponde;
- retorno genera resume report;
- outage sintético del target/fixture atraviesa DEGRADED → DOWN y recuperación sin spam.

## Cost guard

No contratar VPS ni activar pay-as-you-go para cerrar esta baseline. Si Sentry cambia cuota/precio, se reevalúa antes de introducir gasto.
