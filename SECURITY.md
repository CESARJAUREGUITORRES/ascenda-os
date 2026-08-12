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

## Política para Codex / agentes de desarrollo

Antes de modificar código o base:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. identificar archivos, endpoints, RPC, tablas, triggers y consumidores;
4. clasificar riesgo;
5. para HIGH/CRITICAL, crear Impact Report y rollback;
6. trabajar en branch no productiva;
7. ejecutar CI y pruebas aplicables;
8. validar en staging antes de producción cuando el riesgo lo requiera.

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
- HIGH/CRITICAL requiere validación, Impact Report, branch, pruebas y staging.
- Hallazgos de secretos requieren rotación; eliminar el valor del HEAD no invalida exposición histórica.
- No se reduce un control de seguridad solo para hacer pasar pruebas.
- Los parches de seguridad deben preservar disponibilidad y compatibilidad mediante migración progresiva.

## Reporte responsable interno

Los hallazgos deben registrarse sin publicar secretos, PHI/PII ni pruebas ofensivas innecesarias. El repositorio corporativo futuro deberá ser privado y el anexo técnico confidencial de seguridad se mantendrá separado de documentación destinada a exposición general.

## Baseline

Repository: `CESARJAUREGUITORRES/ascenda-os`
Baseline date: `2026-08-12`
