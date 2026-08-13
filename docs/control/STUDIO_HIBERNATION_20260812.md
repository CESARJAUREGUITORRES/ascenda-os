# ASCENDA OS — STUDIO HIBERNATION GUARD

**Fecha:** 2026-08-12  
**Estado objetivo:** HIBERNATED BY DEFAULT  
**Ámbito:** `app/server.js` / scheduler background de Studio  
**No afecta:** panel Studio, tablas `aos_studio_*`, assets, funciones/RPC, agentes generales de Marketing ni datos existentes.

## 1. Motivo

Durante la estabilización de Supabase se identificó que el scheduler de publicación automática de Studio consulta periódicamente `aos_studio_contenido` aun cuando el módulo no está en uso.

Evidencia observada antes de la hibernación:

- `aos_studio_contenido` actualmente contiene 0 filas.
- `pg_stat_statements` registra 136,263 llamadas históricas a la consulta de contenido `PROGRAMADO`.
- Tiempo medio aproximado de PostgreSQL: 0.254 ms por llamada.
- Tiempo acumulado aproximado: 34.59 s de PostgreSQL.

Conclusión: Studio no fue el cuello de botella principal de CPU; los RPC de paneles y snapshots fueron más costosos. Sin embargo, el polling de Studio es trabajo 100% evitable mientras el módulo no se utiliza y añade tráfico API, ruido operativo y superficie de error.

## 2. Implementación

El scheduler background queda controlado por la variable:

`AOS_STUDIO_BACKGROUND_ENABLED`

Comportamiento por defecto:

- variable ausente: OFF;
- `false`, `0` u otro valor: OFF;
- `true`, `1`, `yes` u `on`: ON.

Cuando está OFF:

- no se registra el `setInterval` de Studio;
- no se ejecuta el arranque diferido del scheduler;
- no se consulta `aos_studio_contenido` desde este worker;
- no se intenta publicar automáticamente en Instagram/Facebook/LinkedIn;
- el panel y la arquitectura de Studio permanecen intactos.

## 3. Reactivación futura

Solo reactivar cuando se retome el trabajo del panel Studio y después de validar sus flujos.

Procedimiento:

1. revisar integraciones/redes y credenciales;
2. validar contenido PROGRAMADO en staging/controlado;
3. establecer en Railway `AOS_STUDIO_BACKGROUND_ENABLED=true`;
4. redeploy;
5. confirmar log `[STUDIO-CRON] ACTIVE`;
6. observar Supabase y publicaciones;
7. mantener rollback inmediato cambiando el flag a false o retirándolo.

No requiere modificar ni recrear tablas.

## 4. GitHub ↔ Supabase

La integración nativa Supabase ↔ GitHub está conectada a `CESARJAUREGUITORRES/ascenda-os` con:

- working directory: `.` porque `supabase/` vive en la raíz;
- production branch: `main`;
- deploy to production: habilitado.

Regla operacional desde este punto: cualquier migration nueva bajo `supabase/migrations/` debe entrar únicamente por rama/PR/CI y merge deliberado a `main`. No crear migrations experimentales directamente en `main`.

El workflow histórico `Sync Supabase → GitHub` sincroniza contenido de `aos_codigo_fuente` hacia `src/` y `docs/`; no despliega migrations.

## 5. Invariantes

La hibernación de Studio no puede alterar:

- Ventas;
- Agenda;
- Pacientes;
- Marketing Attribution;
- Comisiones;
- agentes generales;
- reconciliación Enero–Julio;
- tablas o contenido histórico de Studio.

## 6. Rollback

Código: revertir el commit de Studio Hibernation Guard.

Operativo preferido: mantener el código y reactivar únicamente mediante `AOS_STUDIO_BACKGROUND_ENABLED=true`.
