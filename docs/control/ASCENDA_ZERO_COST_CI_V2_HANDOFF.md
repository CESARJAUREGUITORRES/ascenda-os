# ASCENDA OS — ZERO-COST CI V2 HANDOFF

**Estado:** CURRENT / OBLIGATORY BOOTSTRAP  
**Fecha:** 2026-08-14  
**Aplica a:** todos los chats, agentes, workstreams, PR y releases de ASCENDA OS.

## 1. Regla operativa vigente

ASCENDA OS usa **Zero-Cost CI V2** como ruta normal de validación.

- Repositorio: privado.
- Scheduler: GitHub Actions.
- Cómputo normal: runner self-hosted repo-level.
- Runner esperado: `ASCENDA-ZERO-COST-V2`.
- Labels obligatorios: `self-hosted`, `Linux`, `X64`, `ascenda-zero-cost-v2`.
- GitHub-hosted runners (`ubuntu-latest`, `windows-latest`, `macos-*`) están prohibidos como fallback normal.
- GitHub Actions additional paid usage objetivo: **US$0**.
- Si el runner está offline, los jobs deben quedar `queued/pending`; no se autoriza cambiar a infraestructura facturable para “destrabar” el trabajo.

## 2. Qué debe hacer cualquier chat/agente antes de continuar

Antes de escribir código, migraciones o ejecutar release:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. leer `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`;
4. leer este handoff;
5. leer el master/checkpoint CURRENT del workstream;
6. verificar estado real de `main`, branch, PR y checks;
7. verificar Supabase real si el trabajo depende de DB;
8. no asumir que un estado descrito por otro chat sigue vigente sin comprobarlo.

## 3. Operación del runner

El runner vive en una PC autorizada bajo WSL2/Ubuntu y usuario Linux dedicado `ascenda-runner`.

Ruta operativa actual:

```text
/home/ascenda-runner/actions-runner/actions-runner
```

Arranque interactivo después de reinicio de Windows/WSL:

```bash
sudo service docker start
sudo -iu ascenda-runner
cd ~/actions-runner/actions-runner
./run.sh
```

Estado correcto:

```text
Connected to GitHub
Listening for Jobs
```

No volver a ejecutar `config.sh` salvo que el runner haya sido eliminado/revocado en GitHub. No regenerar registration tokens por rutina. Nunca publicar tokens en chat, issue, commit, screenshot o log.

## 4. Qué ocurre si la PC se reinicia

- Producción NO depende del runner. Railway + Supabase siguen operativos.
- El CI sí se interrumpe si el runner se apaga durante un job.
- GitHub puede marcar ese intento como failed/cancelled por pérdida del runner.
- Al volver a arrancar `./run.sh`, reejecutar solamente los jobs fallidos/interrumpidos.
- No reinstalar WSL, Ubuntu, Docker o el runner salvo evidencia de corrupción.

## 5. Routing y economía

Cada workstream debe ejecutar la mínima suite suficiente para su riesgo:

- documentación: sin DB;
- frontend aislado: sintaxis + UI contract + runtime fixture;
- SQL/RPC/RLS: Supabase local + migraciones exactas + pgTAP/lint + negativas de autorización;
- HIGH/CRITICAL: suite completa relevante + rollback + preflight productivo + canary;
- certificación final: validar el SHA exacto que será certificado.

Usar `paths`/`paths-ignore` y `concurrency.cancel-in-progress` cuando sea seguro para evitar cómputo innecesario.

## 6. Datos y seguridad del runner

- fixtures sintéticos solamente;
- no PII/PHI real;
- no secrets persistidos en workspace;
- no montar carpetas personales de Windows en jobs;
- no ejecutar PR de forks externos en este runner;
- limpiar contenedores/procesos al finalizar;
- cualquier sospecha de compromiso obliga a detener/eliminar runner y rotar credenciales potencialmente expuestas.

## 7. Relación con producción

El runner NO es el servidor de ASCENDA.

```text
Usuarios -> Railway -> Supabase = producción
GitHub -> self-hosted runner -> Docker/Supabase local -> PASS/FAIL = CI
```

Apagar la PC no apaga ASCENDA. Solo deja los nuevos checks en espera.

## 8. Estado de adopción

La migración de workflows a Zero-Cost CI V2 se gestiona en PR #97 (`infra/zero-cost-ci-v2`). Antes de certificar o fusionar, todos los gates aplicables deben quedar verdes sobre el SHA exacto final.

No declarar `PRODUCTION CERTIFIED`, `100_COMPLETE` ni “100%” por un workstream mientras quede un gate de su alcance abierto.

## 9. Instrucción para chats concurrentes

Un chat que esté trabajando en otro frente de ASCENDA puede continuar su tarea sin detenerse por esta migración, pero debe:

- adoptar estas reglas de CI inmediatamente;
- no crear runners cloud pagados;
- no cambiar workflows a hosted runners;
- preparar sus tests para el label `ascenda-zero-cost-v2`;
- aceptar que con un solo runner los jobs se ejecutan secuencialmente;
- no interpretar `queued` como fallo si el runner está ocupado/offline;
- coordinar HIGH/CRITICAL mediante branch/PR y autorización productiva separada.

## 10. Fuente de verdad

Si existe conflicto entre documentación antigua y esta arquitectura, prevalecen en este orden:

1. `AGENTS.md` CURRENT;
2. `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md` CURRENT;
3. este handoff CURRENT;
4. master/checkpoint CURRENT del workstream;
5. documentación histórica.
