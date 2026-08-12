# ASCENDA OS — SECURITY REMEDIATION BACKLOG

**Baseline:** 2026-08-12  
**Estado:** Plan de remediación — NO ejecutar cambios críticos directamente en producción  
**Objetivo:** endurecer ASCENDA por etapas sin interrumpir la operación clínica ni romper contratos existentes.

## Principio de ejecución

Cada corrección de seguridad se implementará con este orden:

1. comprobar comportamiento actual y consumidores;
2. crear Impact Report;
3. implementar cambio backward-compatible cuando sea posible;
4. ejecutar CI y pruebas específicas;
5. validar comportamiento funcional;
6. recién después retirar el mecanismo inseguro anterior;
7. documentar rollback.

No se habilitará RLS globalmente, no se revocarán todos los permisos `anon` de una vez y no se reemplazará Auth en un solo cambio masivo.

---

## P0 — CRÍTICOS / PRIMERA CONTENCIÓN

### SEC-001 — Inventario y rotación de secretos

**Riesgo:** CRITICAL  
**Estado:** Confirmado como área de riesgo.

Problema:
- existen credenciales/configuraciones históricas que deben considerarse potencialmente expuestas;
- hacer privado el repositorio reduce exposición futura, pero no invalida secretos que hayan sido utilizados históricamente;
- configuración sensible no debe estar accesible desde frontend ni almacenada en tablas/memorias generales.

Plan seguro:
1. inventariar secretos sin imprimir valores;
2. identificar proveedor y consumidor;
3. crear variable equivalente en Railway/Supabase Vault/secret manager;
4. actualizar consumidor;
5. probar;
6. rotar/revocar credencial anterior;
7. verificar que ningún frontend/log la expone.

No reescribir historial Git todavía; la rotación tiene prioridad sobre la limpieza histórica.

### SEC-002 — Autenticación y password handling

**Riesgo:** CRITICAL  
**Estado:** Arquitectura legacy identificada.

Problema:
- ASCENDA mantiene un esquema de autenticación propio que debe migrarse hacia identidad verificable y password hashing/managed auth moderno;
- los usuarios actuales no deben quedar bloqueados por una migración abrupta.

Plan seguro:
1. mapear login actual, sesiones, roles, 2FA y recuperación;
2. definir Auth V3 compatible con Supabase Auth/JWT o capa server-side equivalente;
3. crear vínculo identidad actual → identidad nueva;
4. migrar usuarios progresivamente;
5. mantener fallback temporal auditado;
6. validar ADMIN/ASESOR/personal clínico;
7. retirar mecanismo legacy solo cuando cobertura sea completa.

### SEC-003 — 2FA real y server-side

**Riesgo:** CRITICAL  
**Estado:** Requiere remediación coordinada con SEC-002.

Objetivo:
- OTP nunca debe ser retornado al cliente como prueba del propio segundo factor;
- expiración, intentos, rate limit y consumo deben validarse server-side;
- secretos/OTP no deben registrarse en logs.

### SEC-004 — Autorización derivada de identidad, no de parámetros del navegador

**Riesgo:** CRITICAL

Problema:
- acciones privilegiadas no deben aceptar como prueba suficiente parámetros como `p_rol`, username o flags enviados por cliente.

Plan:
1. inventariar RPC/endpoints de escritura;
2. identificar caller actual;
3. crear helper de autorización basado en JWT/sesión verificada;
4. migrar RPC por dominio;
5. probar cada rol;
6. retirar confianza en rol enviado desde navegador.

### SEC-005 — RPC `SECURITY DEFINER` y privilegios de ejecución

**Riesgo:** CRITICAL

Baseline conocida:
- gran cantidad de RPC `aos_*`;
- muchas son `SECURITY DEFINER`;
- la superficie de ejecución del rol público/anónimo debe reducirse por allowlist, no mediante revocación masiva improvisada.

Orden:
1. clasificar RPC READ / WRITE / ADMIN / AGENT / INTERNAL;
2. mapear frontend/endpoints consumidores;
3. identificar owner y search_path seguro;
4. añadir autorización interna donde corresponda;
5. revocar EXECUTE por grupos pequeños;
6. probar flujo funcional tras cada lote.

### SEC-006 — RLS por dominio

**Riesgo:** CRITICAL

Problema:
- RLS no protege actualmente todo el esquema operativo;
- activar RLS masivamente rompería módulos que hoy consumen Supabase directamente.

Estrategia:
1. comenzar por tablas sin escrituras críticas y con caller claramente identificado;
2. definir matriz usuario/rol/operación;
3. crear policies explícitas;
4. probar SELECT/INSERT/UPDATE/DELETE;
5. habilitar RLS tabla por tabla o por dominio;
6. monitorizar errores;
7. continuar con el siguiente dominio.

Orden sugerido de dominios: configuración no sensible → catálogo → marketing lectura → agenda → ventas/caja → clínica/pacientes, ajustado tras dependency map.

---

## P1 — ALTO RIESGO

### SEC-007 — Storage de pacientes/documentos

**Riesgo:** HIGH

Objetivo:
- revisar buckets y `storage.objects`;
- separar lectura pública legítima de documentos clínicos/privados;
- utilizar autorización real por usuario/rol/propiedad;
- probar upload/read/update/delete por bucket.

### SEC-008 — Endpoints Node/Railway con efectos externos

**Riesgo:** HIGH

Revisar especialmente:
- envío de email/mensajería;
- ejecución de agentes;
- publicación/conexiones externas;
- endpoints administrativos;
- cargas de archivos;
- operaciones que usan secretos server-side.

Controles objetivo:
- autenticación;
- autorización;
- validación de input;
- CORS limitado;
- rate limiting;
- límites de payload;
- manejo seguro de errores;
- auditoría.

### SEC-009 — KronIA / ejecución de agentes

**Riesgo:** HIGH

Objetivo:
- herramienta allowlist;
- autorización por acción;
- confirmación humana para escrituras sensibles;
- límites de filas/objetos;
- auditoría;
- no permitir SQL arbitrario de escritura en producción;
- proteger prompt/tool boundary contra instrucciones provenientes de datos no confiables.

### SEC-010 — Consulta dinámica de agentes

**Riesgo:** HIGH

La capacidad dinámica de consulta debe mantener:
- solo lectura efectiva;
- límites de tablas/columnas sensibles;
- autenticación del caller;
- timeout/límite de filas;
- validación robusta de la consulta;
- logging sin PHI/secretos innecesarios.

### SEC-011 — Integraciones y configuración sensible

**Riesgo:** HIGH

Objetivo:
- frontend nunca recibe `api_secret` ni claves privadas;
- `aos_integraciones` conserva solo metadatos/configuración no secreta cuando sea posible;
- secretos viven server-side;
- rotación y ownership documentados.

### SEC-012 — Logging, auditoría y PII/PHI

**Riesgo:** HIGH

Revisar:
- `aos_log_auditoria`;
- security logs;
- logs de agentes;
- Railway logs;
- payloads de webhooks;
- errores enviados al cliente.

Objetivo: trazabilidad suficiente sin almacenar passwords, OTP, tokens, secretos o datos clínicos innecesarios.

---

## P2 — ENDURECIMIENTO Y RESILIENCIA

### SEC-013 — GitHub ↔ Supabase Database as Code

**Riesgo:** HIGH operacional

Problema:
- Supabase contiene migraciones/cambios más recientes que la baseline de `main`;
- un repositorio que no puede reconstruir la DB no ofrece recuperación determinística.

Objetivo:
- versionar migrations/schema/functions/policies;
- detectar schema drift;
- toda nueva DDL entra por migration;
- poder reconstruir una base limpia desde Git.

### SEC-014 — Branch protection / PR obligatorio

**Riesgo:** MEDIUM/HIGH operacional

Objetivo:
- proteger `main`;
- checks obligatorios;
- PR antes de producción;
- evitar force push;
- revisión adicional para HIGH/CRITICAL.

### SEC-015 — Expandir CI

El baseline actual ya verifica sintaxis/runtime mínimo.

Siguiente nivel:
- contract tests de RPC críticas;
- migration validation;
- smoke HTTP;
- pruebas por rol;
- E2E de flujos madre;
- secret scanning después de rotación/saneamiento;
- dependency/security checks compatibles con baseline.

### SEC-016 — Backup / restore / rollback

Objetivo:
- documentar backup DB + Storage;
- probar restore;
- definir RPO/RTO;
- cada cambio HIGH/CRITICAL debe tener rollback verificable.

### SEC-017 — Headers/CORS/rate limiting global

Objetivo:
- política uniforme de CORS;
- headers de seguridad aplicables;
- límites de requests;
- límites de body/upload;
- protección de endpoints sensibles.

### SEC-018 — Dependencias y supply chain

Objetivo:
- inventario de dependencias;
- lockfile reproducible;
- revisión de vulnerabilidades;
- actualización controlada;
- acciones GitHub versionadas y restringidas.

---

## P3 — ERRORES FUNCIONALES / CONSISTENCIA A VALIDAR

Estos elementos no se corregirán como “seguridad” hasta reproducirlos funcionalmente.

### BUG-001 — Marketing: atribución histórica por tratamiento

Candidato identificado durante auditoría. Reproducir datos y comparar resultados esperados antes de tocar SQL.

### BUG-002 — Comisiones: regla configurable vs porcentaje embebido

Verificar si `aos_comisiones_admin` y `aos_tabla_comisiones` usan una única fuente de verdad. No modificar mientras los resultados actuales no hayan sido reconciliados.

### BUG-003 — Datos legacy vs valores calculados

No actualizar columnas como contadores/VIP solo porque parezcan desincronizadas; identificar si el panel actual usa cálculo dinámico (`Paciente 360`) o valor persistido.

---

## ORDEN DE TRABAJO RECOMENDADO

### Carril A — Seguridad / arquitectura

SEC-001 → SEC-008 (inventario y contención de endpoints) → SEC-002/003/004 → SEC-005 → SEC-006 → SEC-007 → SEC-009/010/011 → SEC-012 → SEC-013/014/015/016/017/018.

La secuencia puede cambiar tras findings validados de Codex Security.

### Carril B — Producto / mejoras

Cambios LOW/MEDIUM de interfaz y funcionalidad pueden continuar en paralelo usando:

feature/fix branch → análisis de impacto → CI → revisión → producción.

Cambios HIGH/CRITICAL que toquen Auth, RLS, ventas/caja, datos clínicos o permisos siguen el Carril A y no se mezclan con mejoras visuales.

---

## DEFINITION OF DONE DE UN FINDING DE SEGURIDAD

Un finding solo puede cerrarse cuando:
- causa raíz validada;
- caller/dependencias identificados;
- parche en branch;
- CI y pruebas específicas verdes;
- no existe regresión en flujos afectados;
- secreto rotado si aplica;
- validación negativa posterior demuestra que el vector ya no funciona;
- rollback conocido;
- documentación actualizada.
