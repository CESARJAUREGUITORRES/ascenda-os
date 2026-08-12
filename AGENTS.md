# AGENTS.md — ASCENDA OS

## Propósito

Este archivo define las reglas operativas obligatorias para cualquier agente de IA/Codex que trabaje sobre ASCENDA OS. El objetivo es permitir desarrollo rápido sin perder trazabilidad, seguridad ni estabilidad de producción.

## Fuente de verdad de arquitectura

Antes de proponer o ejecutar cambios, leer:

1. `docs/control/ASCENDA_CONTROL_MASTER.md`
2. `PROTOCOLO_DESARROLLO.md` como referencia histórica, no como verdad absoluta
3. Los archivos productivos bajo `app/`
4. Las migraciones/esquema vigentes de Supabase cuando estén disponibles en Git

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

### Staging

- `staging` es la rama de integración/preproducción.
- Las nuevas features deben desarrollarse en `feature/*`, `fix/*`, `security/*`, `data/*` o `chore/*`.
- Flujo esperado: branch → checks → PR → staging → validación → PR/main.

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

Requiere Impact Report, pruebas específicas y rollback.

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

No ejecutar directamente en producción sin staging, backup/restore conocido y aprobación explícita.

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
- rollback documentado.

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
- staging validado;
- producción validada tras merge;
- datos reconciliados;
- rollback conocido;
- documentación actualizada.

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
- ocultar fallos de tests para “poner verde” el CI.

---

## Objetivo de largo plazo

ASCENDA Zi Vital debe estabilizarse como implementación de referencia y luego migrarse a infraestructura corporativa. El producto SaaS se desarrollará en repositorio e infraestructura separados, con aislamiento multi-tenant diseñado desde el inicio.
