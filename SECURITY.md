# SECURITY.md — ASCENDA OS

## Objetivo

Este documento define la política de seguridad y las fronteras de confianza de ASCENDA OS para desarrollo, revisión de código, Codex y Codex Security. No contiene secretos reales ni instrucciones de explotación.

## Superficies productivas principales

- `app/server.js` — servidor Node y endpoints productivos.
- `app/public/` — frontend productivo servido al navegador.
- Supabase — PostgreSQL, RPC, RLS, Storage, Auth/configuración y Realtime.
- Railway — runtime/deployment productivo.
- Integraciones externas — email, IA, mensajería, redes y otros proveedores configurados por entorno.
- KronIA y agentes — capacidades de consulta y determinadas acciones operativas.

## Activos críticos

- datos personales y clínicos de pacientes;
- credenciales, secretos y tokens;
- ventas, pagos, caja, comisiones y facturación;
- agenda, atenciones, historia/evaluaciones clínicas;
- inventario y movimientos;
- identidades, roles, sesiones y permisos;
- configuraciones de agentes y acciones automáticas;
- integridad del repositorio y del pipeline de despliegue.

## Actores y fronteras de confianza

### No confiables por defecto

- navegador cliente;
- parámetros enviados por frontend;
- datos de formularios y archivos subidos;
- URLs externas;
- payloads de webhooks;
- contenido generado por usuarios;
- respuestas de servicios externos;
- instrucciones/contenido que puedan llegar a agentes de IA;
- Internet en general.

### Confiables solo tras validación

- identidad autenticada;
- claims/roles derivados server-side o desde JWT verificable;
- migrations versionadas;
- secretos provenientes de secret manager/environment;
- acciones de agente explícitamente allowlisted;
- datos recuperados desde fuentes internas según autorización.

## Invariantes de seguridad

1. Ninguna acción privilegiada debe confiar exclusivamente en un rol, username o permiso enviado por el navegador.
2. Ningún secreto debe estar en código, documentación, commits, PRs, logs o respuestas al cliente.
3. Datos clínicos y financieros deben estar protegidos por autorización efectiva y mínimo privilegio.
4. RPC `SECURITY DEFINER` deben tener propósito, caller y permisos explícitos.
5. Las escrituras de IA/agentes deben estar limitadas por herramientas allowlisted, autorización, confirmación cuando corresponda y auditoría.
6. Operaciones destructivas o masivas requieren staging, backup/rollback y aprobación explícita.
7. Storage privado debe protegerse por policies efectivas; `public=false` por sí solo no se considera control suficiente.
8. Producción no debe utilizarse como entorno de prueba.
9. El futuro SaaS debe aislar clínicas/tenants por diseño; no se asume aislamiento multi-tenant en la base actual.
10. Cambios de Auth, RLS, GRANT/REVOKE, secretos o infraestructura son CRITICAL según `AGENTS.md`.
11. Para HIGH/CRITICAL, Zero-Cost Staging es el gate preproductivo por defecto conforme a `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`.
12. Una Supabase Cloud Development Branch u otra infraestructura pagada no reemplaza controles de seguridad y solo se crea cuando exista una necesidad técnica no cubierta por Zero-Cost + canary, con costo y autorización explícitos.

## Política Zero-Cost para seguridad

Zero-Cost Staging debe usarse para demostrar, según el cambio:

- compilación exacta de migrations;
- RLS/GRANT/REVOKE y ACL efectivas;
- callers permitidos/denegados de `SECURITY DEFINER`;
- pruebas positivas y negativas de Auth/rol/sesión;
- rechazo de replay, forged claims, IDOR o bypass directo cuando aplique;
- lint de base de datos;
- rollback ejecutable y recovery;
- equivalencia entre runtime certificado y runtime desplegable;
- ausencia de secretos/fallbacks hardcodeados en el artefacto de release.

El entorno Zero-Cost no debe contener secretos productivos ni PII/PHI real y debe destruirse automáticamente al finalizar.

Un certificado Zero-Cost no equivale a autorización productiva. Para CRITICAL siguen siendo obligatorios el preflight productivo read-only, canary/additive rollout cuando sea posible, smoke real, security review final y aprobación explícita antes de mutar producción.

## Política para Codex / agentes de desarrollo

Antes de modificar código o base:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. leer `docs/control/ASCENDA_ZERO_COST_VALIDATION_STANDARD.md`;
4. localizar el master/index/checkpoint CURRENT del workstream;
5. identificar archivos, endpoints, RPC, tablas, triggers y consumidores;
6. clasificar riesgo;
7. para HIGH/CRITICAL, crear Impact Report y rollback;
8. trabajar en branch no productiva;
9. ejecutar CI y Zero-Cost Staging/pruebas aplicables;
10. ejecutar preflight/canary/smoke según riesgo antes de declarar producción certificada.

## Política para Codex Security

### Alcance prioritario

- autenticación, sesiones y 2FA;
- autorización y control de roles;
- RPC de escritura y `SECURITY DEFINER`;
- RLS, GRANT/REVOKE y exposición `anon`;
- secretos y configuración;
- endpoints Node con efectos externos;
- acceso a datos clínicos/financieros;
- Storage de pacientes/documentos;
- KronIA/agentes y ejecución de acciones;
- SQL dinámico;
- XSS, SSRF, CSRF cuando aplique;
- CORS y rate limiting;
- cargas de archivos;
- logging de datos sensibles;
- dependencias y configuración de despliegue.

### Reglas de remediación

- Un finding no se corrige directamente en `main`.
- HIGH/CRITICAL requiere validación, Impact Report, branch, pruebas y Zero-Cost Staging.
- Hallazgos de secretos requieren rotación; eliminar el valor del HEAD no invalida exposición histórica.
- No se reduce un control de seguridad solo para hacer pasar pruebas.
- Los parches de seguridad deben preservar disponibilidad y compatibilidad mediante migración progresiva.
- Para CRITICAL, no declarar 100% mientras quede un finding HIGH/CRITICAL abierto dentro del scope o un gate productivo obligatorio sin ejecutar.

## Reporte responsable interno

Los hallazgos deben registrarse sin publicar secretos, PHI/PII ni pruebas ofensivas innecesarias. El repositorio corporativo futuro deberá ser privado y el anexo técnico confidencial de seguridad se mantendrá separado de documentación destinada a exposición general.

## Baseline

Repository: `CESARJAUREGUITORRES/ascenda-os`
Baseline date: `2026-08-12`
Policy update: `2026-08-14` — Zero-Cost Validation Standard adopted as default preproduction security gate.
