# ASCENDA OS — CI BASELINE

**Workflow:** `.github/workflows/ascenda-ci.yml`

## Estado actual

El workflow inicial fue ejecutado correctamente sobre la rama de auditoría y finalizó en verde.

## Qué valida hoy

- checkout del repositorio;
- Node 20;
- instalación de dependencias de `app/`;
- sintaxis de `app/server.js`;
- sintaxis de JavaScript bajo `app/public/`;
- JSON válido bajo `app/`;
- existencia de archivos productivos críticos.

## Qué NO valida todavía

- lógica SQL/RPC;
- migraciones;
- RLS/Auth;
- contratos frontend↔RPC;
- E2E navegador;
- Railway deploy;
- backups/restore;
- performance.

## Motivo

El CI inicial debe ser compatible con la arquitectura real actual y no bloquear por herramientas inexistentes. La aplicación productiva sirve `app/public/` mediante `node server.js`; `vite build` no forma parte del runtime Railway actual, por lo que no se utiliza todavía como gate de producción.

## Expansión prevista

1. Contract tests de RPC críticas.
2. Validación de migrations Supabase.
3. Tests unitarios de lógica extraída de `server.js`.
4. Smoke tests HTTP.
5. E2E con navegador en staging.
6. Security checks y secret scanning tras saneamiento de baseline.
7. Checks de schema drift Git↔Supabase.

## Última validación

Baseline CI ejecutada el 2026-08-12: `Runtime baseline` → **SUCCESS** en todos los steps configurados.
