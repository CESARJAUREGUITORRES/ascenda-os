# AGENTS.md — ASCENDA OS

## Propósito

Este archivo define las reglas operativas obligatorias para cualquier agente de IA/Codex que trabaje sobre ASCENDA OS. El objetivo es permitir desarrollo rápido sin perder trazabilidad, seguridad ni estabilidad de producción.

## Fuente de verdad de arquitectura

Antes de proponer o ejecutar cambios, leer:

1. `docs/control/ASCENDA_CONTROL_MASTER.md`
2. `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`
3. el master/index/checkpoint CURRENT del workstream afectado
4. `SECURITY.md` para cambios de seguridad, Auth, RLS, secretos, agentes o infraestructura
5. `PROTOCOLO_DESARROLLO.md` como referencia histórica, no como verdad absoluta
6. los archivos productivos bajo `app/`
7. las migraciones/esquema vigentes de Supabase cuando estén disponibles en Git

Antes de continuar trabajo iniciado por otro chat/agente, verificar el estado real de GitHub (`main`, `staging`, branch, PR, checks) y de Supabase; no asumir que un checkpoint antiguo sigue vigente.

### Clasificación del repositorio

- `app/` = aplicación productiva actual.
- `app/public/` = frontend servido directamente en producción.
- `app/server.js` = servidor Node y APIs productivas.
- `src/` = arquitectura histórica/legacy hasta que se demuestre lo contrario.
- `docs/` = documentación; puede contener documentos históricos.
- `aos_codigo_fuente` en Supabase = fuente histórica, NO fuente canónica de producción.

Nunca modificar `src/` suponiendo que cambiará producción sin comprobar la ruta productiva equivalente en `app/`.

---

## Regla cero: analizar antes de escribir

Para cualquier bug, feature o cambio de datos:

1. identificar pantalla/flujo afectado;
2. localizar archivo productivo real;
3. localizar JS/endpoint/RPC utilizado;
4. identificar tablas/views relacionadas;
5. revisar triggers y efectos secundarios;
6. identificar consumidores adicionales de la misma RPC/tabla;
7. clasificar riesgo;
8. definir pruebas y rollback;
9. recién entonces modificar.

No arreglar síntomas modificando datos o columnas sin determinar primero la fuente de verdad.

---

## Entornos y ramas

### Producción

- `main` representa producción GitHub.
- No hacer desarrollo normal directamente sobre `main`.
- No hacer force push sobre `main`.
- No fusionar cambios de alto impacto sin revisión humana y validación.

### GitHub Staging

- `staging` es la rama de integración/preproducción de código.
- **No confundir `staging` de GitHub con una Supabase Cloud Development Branch.**
- Las nuevas features deben desarrollarse en `feature/*`, `fix/*`, `security/*`, `data/*` o `chore/*`.
- Flujo esperado: branch → checks → PR → staging cuando aplique → validación → PR/main.

### Zero-Cost Staging — estándar por defecto

ASCENDA usa `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md` como circuito preproductivo obligatorio por defecto.

- GitHub Actions + Supabase CLI/PostgreSQL/Docker levantan un entorno efímero y reproducible.
- No se usan credenciales productivas ni PII/PHI real como fixtures.
- Se compilan las migraciones EXACTAS del release, se ejecutan lint, contracts, pgTAP/pruebas equivalentes, seguridad, performance y rollback según riesgo.
- El entorno se destruye al finalizar, incluso cuando el workflow falla.
- Para HIGH/CRITICAL debe existir evidencia reproducible (run/artifact/digest/checkpoint) antes del gate productivo.
- Un CI verde no autoriza producción: siguen siendo obligatorios preflight, canary/cutover/smoke y autorización según riesgo.

### Infraestructura cloud pagada

- Supabase Cloud Development Branch, proyecto duplicado, staging Railway dedicado u otra infraestructura con costo **NO son requisitos automáticos**.
- Solo se crean si un riesgo material no puede validarse suficientemente mediante Zero-Cost Staging + preflight/canary.
- Antes de crear infraestructura con costo: explicar necesidad, alternativa cero-costo descartada, permisos/datos implicados, costo/recurrencia, rollback/borrado y obtener aprobación explícita del propietario.
- Por defecto, cualquier entorno cloud adicional debe ser efímero y eliminarse al terminar su gate.

### Auditoría

- `audit/*` se usa para documentación, investigación y cambios de control que no deben alterar runtime.

---

## Niveles de riesgo

### 🟢 LOW

- texto/estilo aislado;
- documentación;
- lectura sin side effects;
- cambios visuales que no cambian contratos de datos.

### 🟡 MEDIUM

- frontend funcional;
- filtros/reportes;
- nuevas consultas de lectura;
- cambios en un módulo con dependencias identificadas.

### 🔴 HIGH

Cualquier cambio que toque:

- `aos_ventas`
- `aos_pacientes`
- `aos_agenda_citas`
- `aos_llamadas`
- `aos_leads`
- `aos_atenciones`
- `aos_cotizaciones`
- `aos_pagos`
- inventario/movimientos
- comisiones
- historia clínica
- KronIA con acciones de escritura

Requiere Impact Report, pruebas específicas, Zero-Cost Staging y rollback.

### ⚫ CRITICAL

- Auth / sesiones / 2FA;
- RLS / GRANT / REVOKE;
- `SECURITY DEFINER`;
- Storage policies;
- secretos/tokens;
- migraciones destructivas;
- fusión/eliminación masiva de pacientes;
- borrados masivos;
- deploy/infraestructura;
- cambios multi-tenant.

No ejecutar directamente en producción sin Zero-Cost Staging certificado, preflight productivo, backup/restore o rollback conocido, canary/additive rollout cuando sea posible, security review y aprobación explícita.

---

## PostgreSQL / Supabase

### Cambios estructurales

- Toda DDL nueva debe representarse como migration versionada.
- No crear/alterar/drop tablas, índices, policies, funciones o triggers ad hoc en producción salvo incidente explícitamente aprobado.
- Preferir cambios backward-compatible durante migraciones.
- No renombrar/eliminar columnas hasta verificar todos sus consumidores.

### Datos

- Antes de UPDATE/DELETE masivo: ejecutar SELECT equivalente y reportar cantidad/ejemplos.
- Usar filtros determinísticos e idempotencia.
- Para correcciones de datos críticos: backup lógico o snapshot/branch primero.
- No borrar datos clínicos/financieros como mecanismo de “limpieza”.
- Registrar auditoría cuando el dominio la requiera.

### Identificadores críticos

Tratar `numero_limpio` como identificador transversal mientras no exista un ID canónico superior plenamente migrado.

No cambiar teléfonos/identificadores sin revisar:

- pacientes;
- leads;
- llamadas;
- citas;
- ventas;
- seguimientos;
- cotizaciones;
- atenciones;
- email/WhatsApp;
- predicciones/agentes.

### Funciones/RPC

Antes de modificar una RPC:

- identificar tablas que lee/escribe;
- identificar paneles/funciones que la llaman;
- verificar si es `SECURITY DEFINER`;
- verificar permisos/grants;
- verificar triggers que puede activar indirectamente;
- mantener contrato de retorno o versionar la RPC.

---

## Seguridad

- Nunca incluir secretos reales en código, documentación, commits, PRs, prompts o logs.
- Nunca imprimir tokens, passwords, API keys o service-role keys en respuestas.
- Usar variables de entorno/Vault/secret manager.
- No agregar fallbacks hardcodeados de secretos.
- No confiar en un rol enviado desde el navegador como autorización suficiente.
- La autorización debe derivarse de identidad autenticada y verificable.
- Aplicar mínimo privilegio.
- Cualquier corrección de seguridad debe preservar disponibilidad de la clínica mediante migración progresiva.

---

## KronIA y agentes

KronIA tiene capacidad de investigación y acciones operativas. Antes de ampliar herramientas:

1. definir acción permitida;
2. definir rol autorizado;
3. definir objetos/campos permitidos;
4. requerir confirmación humana para escrituras sensibles;
5. registrar auditoría;
6. limitar resultados/datos sensibles;
7. definir rollback cuando corresponda.

No otorgar a un agente SQL de escritura arbitrario sobre producción.

---

## Frontend

La interfaz productiva actual se sirve desde `app/public/`.

Al recibir una captura o petición visual:

1. localizar el panel exacto;
2. revisar responsive móvil/tablet/escritorio;
3. preservar navegación, sesión y shell común;
4. no duplicar lógica ya existente en otra pantalla;
5. reutilizar RPC/contratos cuando sea correcto;
6. validar estados loading/error/empty;
7. validar rol ADMIN/ASESOR/profesional según aplique.

No asumir que `app/src/` o Vite controla las pantallas productivas sin comprobarlo.

---

## Node / Railway

Runtime productivo actual:

- `app/server.js`
- comando: `node server.js`
- `app/public/` servido directamente

Antes de cambiar `server.js`:

- ejecutar `node --check server.js`;
- identificar endpoint consumidor;
- validar método HTTP, entrada, salida y errores;
- no introducir secretos hardcodeados;
- revisar CORS y autenticación;
- mantener compatibilidad de endpoints existentes.

Cuando CI materialice o genere un runtime, HIGH/CRITICAL exige demostrar que el artefacto certificado es equivalente al artefacto que Railway ejecutará.

---

## Pruebas mínimas por cambio

### Siempre

- sintaxis de archivos modificados;
- revisión de diff;
- smoke test del módulo afectado;
- comprobar que no se modificaron archivos no relacionados.

### HIGH/CRITICAL

Agregar además:

- consulta/datos antes y después;
- prueba de dependencias;
- prueba por rol relevante;
- prueba mobile si existe UI;
- flujo E2E relacionado;
- Zero-Cost Staging;
- rollback documentado y, cuando sea seguro, ejecutado dentro del staging efímero;
- production preflight read-only;
- evidencia reproducible de certificación.

### CRITICAL adicional

- pruebas negativas explícitas;
- trust-boundary/security review;
- canary/additive rollout cuando técnicamente sea posible;
- 0 HIGH/CRITICAL abiertos dentro del scope antes de certificar producción;
- autorización explícita del propietario antes del primer cambio productivo.

---

## Impact Report obligatorio para HIGH/CRITICAL

Usar este formato antes de implementar:

```md
## Impact Report

**Objetivo:**
**Riesgo:** HIGH / CRITICAL

### Código
- archivos:
- endpoints:

### Datos
- tablas/views:
- RPC:
- triggers:

### Consumidores
- paneles:
- agentes/automatizaciones:

### Seguridad
- roles/permisos:
- datos sensibles:

### Plan de prueba
1.
2.

### Rollback
1.
2.
```

---

## Definition of Done

Una tarea no está terminada solo porque “se ve bien”. Debe cumplir, según aplique:

- cambio en branch correcto;
- diff revisado;
- CI verde;
- migración versionada;
- pruebas ejecutadas;
- seguridad revisada;
- Zero-Cost Staging validado cuando aplique;
- preflight/canary productivo según riesgo;
- producción validada tras release;
- datos reconciliados;
- rollback conocido;
- documentación/checkpoint actualizado.

### Estados de certificación

No mezclar estados:

- `ZERO-COST CERTIFIED` = contratos/migraciones/tests/rollback certificados en entorno efímero.
- `CANARY CERTIFIED` = integración real mínima validada sin activación general.
- `PRODUCTION CERTIFIED` = release autorizado, smoke real y reconciliación final completados.
- `100_COMPLETE` solo puede utilizarse cuando todos los gates declarados del alcance están cerrados.

---

## Prohibiciones explícitas

No:

- modificar producción para experimentar;
- borrar tablas/columnas/filas masivamente sin plan;
- hacer `DROP`, `TRUNCATE` o `DELETE` amplio por conveniencia;
- hacer force push;
- reescribir historia Git sin proyecto específico de saneamiento;
- copiar secretos entre entornos;
- usar datos reales de Zi Vital como seed del futuro SaaS;
- convertir la base productiva actual a multi-tenant mediante cambios masivos;
- ocultar fallos de tests para “poner verde” el CI;
- crear infraestructura cloud pagada por costumbre cuando Zero-Cost Staging cubre el riesgo.

---

## Objetivo de largo plazo

ASCENDA Zi Vital debe estabilizarse como implementación de referencia y luego migrarse a infraestructura corporativa. El producto SaaS se desarrollará en repositorio e infraestructura separados, con aislamiento multi-tenant diseñado desde el inicio.
