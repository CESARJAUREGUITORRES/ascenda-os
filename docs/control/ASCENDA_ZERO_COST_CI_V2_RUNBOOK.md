# ASCENDA OS — ZERO-COST CI V2 RUNBOOK

**Estado:** CURRENT / CANONICAL  
**Fecha:** 2026-08-14  
**Runner objetivo:** repo-level self-hosted / Linux / X64 / `ascenda-zero-cost-v2`  
**Costo objetivo de GitHub Actions adicional:** US$0

---

## 1. OBJETIVO

Operar el CI de ASCENDA OS sin consumir GitHub-hosted minutes como ruta normal, conservando checks de PR, Zero-Cost Staging, pgTAP, lint, runtime smoke, rollback y certificación.

La PC autorizada ejecuta el cómputo; GitHub conserva scheduler, PR, logs y estado PASS/FAIL.

---

## 2. REGLAS NO NEGOCIABLES

1. El runner es **solo para `CESARJAUREGUITORRES/ascenda-os`**.
2. No compartirlo como runner de organización con repositorios no auditados.
3. Custom label obligatorio: `ascenda-zero-cost-v2`.
4. No pegar registration tokens, PAT, API keys, passwords u OTP en chats, issues o commits.
5. No ejecutar PR externos/forks no confiables.
6. No usar datos reales de pacientes como fixtures.
7. No cambiar automáticamente a GitHub-hosted runner si el runner local está offline.
8. Mantener el repositorio privado.
9. GitHub Actions additional paid usage debe permanecer en US$0 salvo autorización explícita.

---

## 3. HOST RECOMENDADO EN WINDOWS

ASCENDA usa workflows Linux/bash/Supabase/Docker. En una PC Windows, el host recomendado es:

- Windows 10/11;
- WSL2;
- Ubuntu LTS;
- usuario Linux dedicado `ascenda-runner`;
- Docker Engine o Docker Desktop con integración WSL;
- runner GitHub Linux x64.

No instalar el runner dentro de carpetas personales como Desktop/Documents/OneDrive.

Workspace recomendado:

`/home/ascenda-runner/actions-runner`

---

## 4. PREPARAR WSL2

En PowerShell como Administrador, si WSL2 todavía no existe:

```powershell
wsl --install -d Ubuntu
```

Reiniciar Windows si lo solicita.

Dentro de Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git jq python3 postgresql-client docker.io
sudo systemctl enable --now docker || sudo service docker start
sudo useradd -m -s /bin/bash ascenda-runner 2>/dev/null || true
sudo usermod -aG docker ascenda-runner
```

Cerrar y volver a abrir Ubuntu para que el grupo Docker sea efectivo.

Verificar:

```bash
docker version
git --version
python3 --version
psql --version
```

---

## 5. REGISTRAR EL RUNNER EN GITHUB

En GitHub:

`ascenda-os → Settings → Actions → Runners → New self-hosted runner`

Seleccionar:

- **Linux**
- **x64**

GitHub mostrará comandos y un registration token temporal.

**El token se usa únicamente en la PC. No compartirlo en ChatGPT.**

Abrir Ubuntu y entrar al usuario dedicado:

```bash
sudo -iu ascenda-runner
```

Ejecutar los comandos de descarga mostrados por GitHub dentro de:

```bash
mkdir -p ~/actions-runner
cd ~/actions-runner
```

Al ejecutar `./config.sh`, usar:

- Repository: el repo `ascenda-os`;
- Runner name: `ASCENDA-ZERO-COST-V2`;
- Additional label: `ascenda-zero-cost-v2`;
- Work folder: `_work`.

Ejemplo conceptual (el TOKEN real lo entrega GitHub):

```bash
./config.sh \
  --url https://github.com/CESARJAUREGUITORRES/ascenda-os \
  --token '<TOKEN_TEMPORAL_LOCAL>' \
  --name 'ASCENDA-ZERO-COST-V2' \
  --labels 'ascenda-zero-cost-v2' \
  --work '_work'
```

No copiar el token fuera de la terminal local.

---

## 6. EJECUCIÓN COMO SERVICIO

Después de configurar el runner:

```bash
cd ~/actions-runner
sudo ./svc.sh install ascenda-runner
sudo ./svc.sh start
sudo ./svc.sh status
```

En GitHub → Settings → Actions → Runners debe aparecer **Idle** con labels:

- `self-hosted`
- `Linux`
- `X64`
- `ascenda-zero-cost-v2`

Si WSL no mantiene `systemd`, puede ejecutarse temporalmente en foreground:

```bash
./run.sh
```

Para operación estable se recomienda servicio.

---

## 7. HEALTHCHECK

Desde el workspace del repo, cuando exista checkout local:

```bash
bash scripts/ci/runner-healthcheck.sh
```

Debe validar:

- Linux x64;
- Docker disponible;
- Python 3;
- PostgreSQL client;
- espacio en disco;
- ausencia de variables productivas obvias en el entorno;
- capacidad de iniciar un contenedor de prueba.

---

## 8. WORKFLOW LABEL CANÓNICO

Todos los jobs normales de ASCENDA deben usar:

```yaml
runs-on: [self-hosted, Linux, X64, ascenda-zero-cost-v2]
```

Está prohibido agregar fallback como:

```yaml
runs-on: ubuntu-latest
```

para resolver una cola/offline sin autorización expresa.

---

## 9. SEGURIDAD DEL RUNNER

### Usuario dedicado

El proceso runner debe operar como `ascenda-runner`, no como root.

### Docker

El usuario puede pertenecer a `docker`; esto equivale a privilegio elevado sobre el host Linux. Por eso:

- el runner se limita al repo privado ASCENDA;
- no se ejecuta código no confiable;
- no se reutiliza para repositorios públicos;
- no se cargan fixtures PII/PHI.

### Secrets

- registration token: solo alta/rotación;
- no guardar token en archivos;
- no imprimir secrets en logs;
- no usar secrets productivos en Zero-Cost Staging;
- production preflight debe ser read-only y explícito si alguna vez necesita credenciales.

### Workspace

Antes de usar el runner para otro propósito, detenerlo. El host no es una estación genérica de ejecución arbitraria.

---

## 10. OPERACIÓN DIARIA

Cuando la PC/WSL está encendida y runner activo:

1. commit/PR llega a GitHub;
2. GitHub selecciona solo workflow(s) afectados por `paths`;
3. el job entra al runner local;
4. Docker/Supabase se levantan localmente;
5. se ejecutan tests;
6. `if: always()` destruye procesos/contenedores;
7. GitHub recibe PASS/FAIL.

Cuando la PC está apagada:

- el job queda en cola;
- no consume GitHub-hosted minutes;
- no se genera fallback facturable.

---

## 11. CONTROL DE GASTO

En GitHub:

`Settings → Billing and licensing → Budgets and alerts`

Mantener Actions additional paid usage en US$0 / bloqueo de gasto adicional cuando la UI lo permita.

Esta configuración de Billing es una barrera administrativa complementaria; el control técnico principal es que todos los workflows normales usan self-hosted.

---

## 12. OPTIMIZACIÓN DE WORKFLOWS

Obligatorio:

- `paths` o `paths-ignore`;
- `concurrency.cancel-in-progress: true`;
- un runner → ejecución secuencial de suites pesadas;
- suites de dominio solo cuando cambia su dominio;
- suite completa únicamente para release/cambio transversal;
- sync histórico manual, no horario;
- artifacts mínimos.

---

## 13. PHASE 2 — CERTIFICACIÓN FINAL

Una vez el runner figure **Idle**, los workflows pendientes de la rama/PR V2 pueden ejecutarse sin costo adicional.

Para cerrar Fase 2 se exige sobre el SHA final:

1. `Ascenda CI`;
2. `ASCENDA Zero-Cost Staging`;
3. `ASCENDA Cartera Phase 2`;
4. `ASCENDA Cartera Phase 2 Hardening`;
5. `ASCENDA Cartera Phase 2 Final Release`;
6. Sales Intelligence contract si `login.html`/Auth compartido cambió;
7. producción read-only smoke;
8. login/2FA real confirmado;
9. reconciliación Cartera sin deuda automática;
10. documento final `PRODUCTION CERTIFIED`.

---

## 14. DETENER / RETIRAR EL RUNNER

Detener:

```bash
cd ~/actions-runner
sudo ./svc.sh stop
```

Retirar correctamente:

1. GitHub → Settings → Actions → Runners → seleccionar runner → Remove;
2. usar removal token solo localmente si GitHub lo solicita;
3. detener/eliminar servicio;
4. borrar workspace si se retira permanentemente.

---

## 15. INCIDENT RESPONSE

Si se sospecha compromiso:

1. detener runner inmediatamente;
2. quitarlo de GitHub;
3. no volver a ejecutar jobs;
4. rotar secrets que pudieron tocar el runner;
5. destruir distro/host de CI si el compromiso no puede delimitarse;
6. reconstruir desde baseline limpia;
7. documentar incidente.

---

## 16. FUENTE DE VERDAD

La política superior está en:

`docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`

Este runbook implementa esa política; no puede relajarla.
