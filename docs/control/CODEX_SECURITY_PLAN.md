# ASCENDA OS — CODEX SECURITY PLAN

## Objetivo

Usar Codex Security como segunda capa de validación independiente sobre el repositorio privado de ASCENDA.

## Estado

- Repositorio GitHub privado: **sí**.
- `SECURITY.md` repository-specific: **creado**.
- `AGENTS.md` con reglas de cambio: **creado**.
- CI baseline: **activo y validado en verde**.
- Activación de Codex Security en la interfaz de Codex: **pendiente de habilitar el repositorio `CESARJAUREGUITORRES/ascenda-os`**.

## Alcance inicial

- historial completo del repositorio;
- `app/server.js`;
- `app/public/`;
- autenticación y sesiones;
- endpoints de escritura;
- integraciones externas;
- secretos/configuración histórica;
- Supabase client usage;
- lógica KronIA/agentes;
- carga de archivos/Storage;
- acciones administrativas.

## Supuestos de threat model

La política canónica para el scan se encuentra en `SECURITY.md`. Como mínimo:

- aplicación clínica con datos personales y potencialmente sensibles;
- usuarios ADMIN, ASESOR y personal clínico;
- navegador cliente no confiable;
- Internet no confiable;
- secretos solo server-side/secret manager;
- producción usa Railway + Supabase;
- frontend productivo está en `app/public/`;
- Node productivo es `app/server.js`;
- varias operaciones usan RPC `SECURITY DEFINER`;
- el proyecto actual es single-tenant;
- futura versión SaaS será infraestructura separada.

## Prioridades de revisión

### P0

- autenticación/passwords/2FA;
- autorización basada en rol;
- RPC de escritura;
- RLS/privilegios indirectos;
- secretos hardcodeados o históricos;
- endpoints que envían email/publican contenido/ejecutan acciones;
- acceso a datos clínicos;
- Storage de pacientes/documentos.

### P1

- CORS;
- rate limiting;
- validación de entrada;
- SSRF/URL handling;
- SQL dinámico;
- XSS en HTML dinámico;
- CSRF donde aplique;
- logging de información sensible;
- dependencias vulnerables.

## Política de remediación

- Codex Security no debe fusionar parches automáticamente.
- Cada finding validado se convierte en issue/PR separado.
- HIGH/CRITICAL requiere Impact Report y staging.
- No cerrar un finding sin reproducción negativa/validación posterior.
- Secret findings implican rotación; borrar el string del HEAD no es suficiente si estuvo expuesto.
