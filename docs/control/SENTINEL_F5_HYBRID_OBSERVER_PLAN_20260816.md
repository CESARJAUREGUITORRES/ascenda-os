# Sentinel F5 — Hybrid Observer Plan

**Fecha:** 2026-08-16 (America/Lima)  
**Estado:** `HYBRID_IMPLEMENTATION_IN_PROGRESS`  
**Baseline:** `main@d81863d46f4f4fe54deb4c017968aac5b19b310d`  
**Costo incremental objetivo:** `US$0/mes`

## Decisión

F5 adopta dos capas independientes:

1. **Cloud Coverage — Sentry Uptime**: un monitor cloud sobre `GET /health`, usando el monitor incluido en el plan Developer. Esta capa cubre períodos en los que CREACTIVE está apagada.
2. **Local Deep Observer — Uptime Kuma en CREACTIVE**: observador intermitente en Windows + WSL2 Ubuntu + Docker. Cuando CREACTIVE está apagada, la capa local es `UNKNOWN`; no se interpreta como caída de ASCENDA.

Sentinel Core no dependerá de la API de Sentry para operar. El historial cloud se conserva en Sentry; la correlación automática con incidentes pertenece a F7/F8/F11.

## Autoarranque CREACTIVE

Cadena objetivo:

`Windows logon → Task Scheduler → wsl.exe Ubuntu → wait Docker → Uptime Kuma → local observer agent`

Propiedades:

- tarea de usuario, sin privilegios elevados;
- una sola instancia (`IgnoreNew`);
- Kuma en `127.0.0.1:3001`;
- `restart: unless-stopped`;
- volumen Docker persistente `uptime-kuma-data`;
- si Docker tarda en iniciar, el script espera hasta 180 segundos;
- si CREACTIVE está apagada, ASCENDA continúa sin dependencia local.

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
| G10 | Sentry Uptime monitor configurado + local observer instalado/autoarranque | PENDING HUMAN UI/WORKSTATION |
| G11 | shutdown/resume + coverage-gap + outage/recovery sintético | PENDING |
| G12 | certificado final + Notion + F6 siguiente | PENDING |

**Progreso lógico:** `9/12 = 75%`.

## Human boundaries restantes

### F5-CLOUD-01
En Sentry → Monitors → Uptime, crear/verificar un único monitor sobre:

`https://ascenda-os-production.up.railway.app/health`

Sin headers, body, cookies ni credenciales.

### F5-LOCAL-01
En CREACTIVE ejecutar el installer Linux y registrar la tarea de autoarranque Windows. No requiere secretos.

### F5-RECOVERY-01
Validar:

- Kuma accesible solo en `localhost:3001`;
- apagado/reinicio del observer produce `UNKNOWN / coverage_gap`;
- retorno genera resume report;
- outage sintético del target/fixture atraviesa DEGRADED → DOWN y recuperación sin spam.

## Cost guard

No contratar VPS ni activar pay-as-you-go para cerrar esta baseline. Si Sentry cambia cuota/precio, se reevalúa antes de introducir gasto.
