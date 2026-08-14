# ASCENDA OS — ZERO-COST VALIDATION STANDARD V2

**Estado:** CURRENT / CANONICAL / V2  
**Fecha de adopción V2:** 2026-08-14  
**Ámbito:** todos los workstreams, chats, agentes, PR, CI y releases de ASCENDA OS  
**Objetivo:** mantener calidad, seguridad, rollback y evidencia reproducible con costo GitHub Actions pagado = **US$0 por defecto**.

---

## 1. PRINCIPIO V2

ASCENDA OS adopta **Zero-Cost CI V2** como arquitectura obligatoria de validación preproductiva.

Zero-Cost no significa omitir staging ni reducir controles. Significa ejecutar la mayor parte del CI sobre infraestructura local/autohospedada controlada, usando Docker + Supabase CLI/PostgreSQL + fixtures sintéticos, y reservar servicios cloud facturables únicamente para casos excepcionales previamente autorizados.

La regla económica es explícita:

> **Ningún agente, chat, workflow o workstream debe generar gasto adicional de GitHub Actions, Supabase staging, Railway staging u otra infraestructura cloud sin autorización expresa del propietario.**

El repositorio debe permanecer privado. Hacerlo público para obtener minutos de Actions no es una alternativa aceptable.

---

## 2. INVARIANTES DE COSTO

### 2.1 GitHub Actions

- Runner por defecto: **self-hosted, repo-level, Linux x64, label `ascenda-zero-cost-v2`**.
- Está prohibido introducir `ubuntu-latest`, `windows-latest`, `macos-*` u otro GitHub-hosted runner como ruta normal.
- Un GitHub-hosted runner solo puede usarse con autorización explícita del propietario para un gate concreto.
- Si el self-hosted runner está offline, el workflow debe **quedar en cola o fallar cerrado**; nunca cambiar automáticamente a runner facturable.
- `concurrency.cancel-in-progress: true` es obligatorio para jobs repetibles por branch/ref cuando sea seguro.
- Los workflows deben usar `paths`/`paths-ignore` para no ejecutar suites irrelevantes.
- La suite completa se reserva para cambios transversales, HIGH/CRITICAL y certificaciones finales.

### 2.2 Presupuesto

La política operativa objetivo de Billing es:

- **GitHub Actions additional paid usage: US$0**.
- Cualquier aumento requiere autorización expresa y debe documentarse en el Impact Report correspondiente.
- Otros chats/agentes no deben recomendar comprar minutos como primera solución; primero deben optimizar routing, self-hosted CI y frecuencia de ejecución.

### 2.3 Storage y artifacts

- No subir artifacts por defecto si un digest/checksum + logs reproducibles son suficientes.
- Artifacts solo cuando aporten evidencia material que no pueda reconstruirse fácilmente.
- Mantener retención mínima necesaria.

### 2.4 Cloud adicional

Supabase Cloud Development Branch, proyecto duplicado, staging Railway dedicado u otra infraestructura con costo son EXCEPCIONALES.

Antes de crear uno se debe:
1. identificar el riesgo que no puede reproducirse localmente;
2. explicar por qué Zero-Cost CI V2 + canary no es suficiente;
3. estimar costo y recurrencia;
4. definir borrado/rollback;
5. obtener autorización explícita.

---

## 3. ARQUITECTURA CANÓNICA

```text
GitHub privado
    │
    ├── PR / branch / commit
    │
    ▼
GitHub Actions scheduler
    │
    │  runs-on:
    │  [self-hosted, Linux, X64, ascenda-zero-cost-v2]
    ▼
ASCENDA self-hosted runner
(distro/usuario dedicado)
    │
    ├── Docker
    ├── Supabase CLI
    ├── PostgreSQL / psql
    ├── Node
    ├── Python
    ├── pgTAP
    └── runtime fixture
    │
    ▼
PASS / FAIL + logs + digest
    │
    ▼
GitHub gate
```

El scheduler de GitHub coordina; el cómputo pesado lo aporta el runner local.

---

## 4. TRUST BOUNDARY DEL SELF-HOSTED RUNNER

El runner forma parte de la superficie de seguridad de ASCENDA.

Obligatorio:

- runner **a nivel de repositorio**, no compartido indiscriminadamente con otros proyectos;
- label dedicado `ascenda-zero-cost-v2`;
- Linux x64, preferentemente dentro de WSL2/distro dedicada en la PC autorizada;
- usuario del sistema dedicado al runner;
- usuario del runner sin privilegios administrativos permanentes;
- workspace dedicado, separado de documentos personales;
- no guardar API keys, OTP, passwords o tokens en archivos del workspace;
- registration token de GitHub se usa solo durante alta/rotación y nunca se pega en chats, issues, commits o logs;
- workflows de PR externos/forks no deben ejecutar código sobre este runner;
- secrets solo se exponen al job que realmente los necesita;
- limpiar procesos y contenedores al finalizar (`if: always()`);
- no montar PII/PHI real como fixture;
- no montar carpetas personales de Windows dentro de jobs;
- no permitir fallback automático a GitHub-hosted runners.

Si se detecta compromiso del runner: detener servicio, revocar/eliminar runner en GitHub, rotar credenciales potencialmente expuestas y reinstalar desde baseline limpia.

---

## 5. TERMINOLOGÍA OBLIGATORIA

### GitHub `staging`
Rama de integración/preproducción de código. No implica una base Supabase adicional.

### Zero-Cost CI V2
Sistema completo de CI económico: scheduler GitHub + self-hosted runner + workflows selectivos + Zero-Cost Staging.

### Zero-Cost Staging
Entorno efímero local creado por CI con Supabase/PostgreSQL/Docker y fixtures sintéticos. Se destruye al terminar.

### Runtime staging / fixture
Runtime temporal de UI/E2E sin dependencia de datos productivos.

### Production read-only preflight
Comprobación real de producción sin mutación: definiciones, ACL, checksums, versiones, métricas y consumidores.

### Canary
Activación productiva de alcance mínimo y controlado antes de generalizar una capacidad HIGH/CRITICAL.

---

## 6. ROUTING INTELIGENTE DE WORKFLOWS

La regla es **ejecutar la mínima suite suficiente para el riesgo**.

### Cambios de documentación
- no levantar Supabase;
- no ejecutar runtime completo;
- validar estructura/diff cuando aplique.

### Frontend aislado
- sintaxis;
- UI contract;
- runtime fixture/smoke del módulo;
- no levantar DB si el contrato no cambia.

### SQL / RPC / RLS
- schema contract;
- migraciones exactas;
- Supabase local;
- pgTAP;
- lint;
- autorización positiva/negativa;
- rollback cuando aplique.

### Cambio de dominio
Ejecutar la suite del dominio afectado (Cartera, Sales Intelligence, etc.) y los contratos compartidos relevantes.

### HIGH/CRITICAL transversal
Ejecutar suite completa relevante + security review + rollback + preflight productivo + canary.

### Certificación final
La suite final debe validar el SHA exacto que se pretende certificar.

---

## 7. LOOP UNIVERSAL ZERO-COST V2

Todo cambio MEDIUM/HIGH/CRITICAL debe adaptar este circuito al riesgo real:

1. **Bootstrap / recovery**
   - leer `AGENTS.md`, `SECURITY.md`, `docs/control/ASCENDA_CONTROL_MASTER.md`;
   - leer este estándar V2;
   - localizar master/index/checkpoint CURRENT del workstream;
   - verificar GitHub y Supabase reales.

2. **Impact analysis**
   - localizar código productivo;
   - mapear RPC/tablas/triggers/consumidores;
   - clasificar riesgo;
   - identificar invariantes, costo esperado y rollback.

3. **Branch aislada**
   - `feature/*`, `fix/*`, `security/*`, `data/*`, `chore/*`, `infra/*`;
   - nunca experimentar en `main`.

4. **Contratos y tests antes del release**
   - sintaxis/static gates;
   - schema/consumer contracts;
   - pgTAP o equivalente;
   - autorización positiva/negativa;
   - performance cuando aplique;
   - zero-residue / rollback-only cuando aplique.

5. **Zero-Cost Staging**
   - self-hosted runner levanta Supabase/PostgreSQL local efímero;
   - fixtures sintéticos sin PII/PHI;
   - migraciones EXACTAS del release;
   - lint, tests, security y rollback;
   - ambiente destruido al finalizar.

6. **GitHub integration gate**
   - checks requeridos verdes sobre self-hosted runner;
   - PR revisable;
   - documentación/checkpoint actualizado.

7. **Production read-only preflight**
   - checksums/definiciones/ACL/consumidores/versiones;
   - confirmar que la baseline productiva no derivó inesperadamente.

8. **Canary / additive rollout**
   - backward-compatible cuando sea posible;
   - usuario/rol/sede/panel mínimo;
   - observabilidad/auditoría.

9. **Cutover**
   - cerrar legacy/bypass solo después de canary cuando la arquitectura lo permita;
   - HIGH/CRITICAL requiere autorización explícita antes de mutar producción.

10. **Post-deploy smoke**
    - flujos reales afectados;
    - negativas de seguridad;
    - reconciliación antes/después;
    - ausencia de regresiones laterales.

11. **Rollback / recovery**
    - ejecutable, no solo descrito;
    - probar en Zero-Cost Staging cuando sea seguro;
    - documentar estados irreversibles.

12. **Certification**
    - registrar SHA, runs, digest/checksum y cobertura;
    - diferenciar `ZERO-COST CERTIFIED`, `CANARY CERTIFIED`, `PRODUCTION CERTIFIED`;
    - no usar “100%” mientras exista un gate del alcance abierto.

---

## 8. GATES MÍNIMOS POR RIESGO

### LOW
- diff revisado;
- sintaxis/lint aplicable;
- smoke proporcional.

### MEDIUM
- CI selectivo;
- consumer contract;
- Zero-Cost Staging cuando toca DB/runtime compartido;
- rollback proporcional.

### HIGH
Además:
- Impact Report;
- migration versionada si aplica;
- autorización positiva/negativa;
- Zero-Cost Staging;
- rollback probado;
- preflight productivo read-only;
- smoke real tras release;
- reconciliación de datos.

### CRITICAL
Además:
- threat/trust-boundary review;
- pruebas negativas explícitas;
- secrets/ACL/RLS/SECURITY DEFINER review;
- artefacto/deploy equivalente al certificado;
- canary/additive rollout cuando sea posible;
- 0 HIGH/CRITICAL abiertos dentro del scope;
- autorización explícita antes del primer cambio productivo;
- recuperación inmediatamente ejecutable.

---

## 9. PROPIEDADES DEL ZERO-COST STAGING

El workflow debe procurar estas invariantes:

- no usar service-role/password de producción salvo gate explícito de solo lectura diseñado para ello;
- no copiar pacientes, DNI, teléfonos, emails, fotos, historia clínica ni PII/PHI como fixtures;
- pinnear versiones relevantes cuando la reproducibilidad lo requiera;
- aplicar migraciones de release EXACTAS;
- ejecutar `supabase db lint --level error` o equivalente;
- destruir el entorno temporal con `if: always()`;
- no modificar pruebas para ocultar un fallo;
- usar puertos aislados cuando varias suites puedan coexistir;
- imprimir digest/checksum de evidencia relevante.

---

## 10. EVIDENCIA Y RETENCIÓN

Por defecto, la evidencia mínima es:

- SHA exacto;
- workflow/run/job;
- PASS/FAIL;
- cobertura de tests;
- digest/checksum relevante;
- preflight/canary/post-smoke cuando corresponda.

No es obligatorio subir artifacts si la evidencia puede reconstruirse con el repo + logs + digest.

---

## 11. COMPORTAMIENTO CUANDO EL RUNNER ESTÁ OFFLINE

- Los jobs deben quedar pendientes/en cola.
- No sustituir por `ubuntu-latest`.
- No activar gasto adicional.
- Si una urgencia productiva exige validación inmediata, se usa validación local controlada + autorización de emergencia + posterior CI cuando el runner vuelva; nunca se falsifica un check verde.

---

## 12. SYNC HISTÓRICO SUPABASE → GITHUB

`sync-supabase.yml` trabaja con `aos_codigo_fuente`, que es histórico y no es la fuente canónica de producción.

Bajo V2:

- no debe ejecutarse cada hora por defecto;
- se mantiene manual/auditado mientras se complete su retiro o rediseño;
- nunca debe sobreescribir `app/` como fuente productiva;
- cualquier reactivación programada requiere justificación.

---

## 13. ESTADOS DE CERTIFICACIÓN

- `ZERO-COST CERTIFIED` = contratos/migraciones/tests/rollback certificados en entorno efímero.
- `CANARY CERTIFIED` = integración real mínima validada.
- `PRODUCTION CERTIFIED` = release autorizado + smoke real + reconciliación final.
- `100_COMPLETE` = todos los gates declarados del alcance cerrados.

No confundir “aplicación funcionando” con “fase certificada”.

---

## 14. PROHIBICIONES EXPLÍCITAS

No:

- cambiar un workflow a GitHub-hosted para “destrabar” CI sin autorización;
- comprar capacidad o crear infraestructura cloud por costumbre;
- publicar el repositorio para obtener minutos gratuitos;
- ejecutar código de forks no confiables sobre el self-hosted runner;
- guardar registration tokens/secrets en el repo;
- usar datos reales como fixtures;
- omitir rollback para ahorrar tiempo;
- ocultar fallos de tests;
- declarar `100%` si el SHA final no fue certificado según el riesgo.

---

## 15. RUNBOOK OPERATIVO

La instalación, hardening, healthcheck, alta/baja y recuperación del runner se documentan en:

`docs/control/ASCENDA_ZERO_COST_CI_V2_RUNBOOK.md`

Scripts auxiliares:

- `scripts/ci/register-self-hosted-runner.sh`
- `scripts/ci/runner-healthcheck.sh`

Este documento V2 sustituye cualquier interpretación anterior que asumiera GitHub-hosted runners como recurso normal de ASCENDA OS.
