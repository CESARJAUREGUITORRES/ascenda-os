# Impact Report — Sales Intelligence V2 admin-only activation

**Fecha:** 2026-08-14  
**Clasificación:** CRITICAL  
**Aprobación:** autorización expresa del propietario en el chat operativo  
**Alcance:** activación general únicamente para administradores con 2FA y permiso explícito

## Snapshot previo

- Rama base: `main@6729d1756e1a9a553312b1d3db6b3be2a74ccace`.
- RPC financiera: `aos_sales_intelligence_summary(integer,text,text)`.
- Checksum previo de definición RPC: `f85499ddb464bf149301f8f9d395a8e4`.
- ACL previa: ejecución explícita para `anon`, `authenticated` y `service_role`.
- Panel de catálogo: inexistente.
- Usuarios con panel asignado: 0.
- Administradores activos nivel 1/2, rol admin y 2FA: 1.
- Sesiones administrativas activas al preflight: 0.
- Snapshot financiero read-only:
  - Todas: 1,279 ventas / S/556,097.27.
  - San Isidro: 691 ventas / S/351,414.65.
  - Pueblo Libre: 588 ventas / S/204,682.62.
  - Las sedes reconcilian exactamente con el total.

## Cambio

1. Crear `aos_sales_intelligence_access` como fuente autoritativa de grants.
2. Denegar lectura/escritura directa de esa tabla a `anon` y `authenticated`.
3. Crear una sesión opaca derivada de una prueba 2FA ya consumida.
4. Exponer las métricas únicamente mediante `aos_sales_intelligence_gateway`.
5. Revocar ejecución de la RPC financiera cruda a `anon` y `authenticated`.
6. Permitir que solo un administrador nivel 1 ya autorizado otorgue o revoque el panel.
7. Desactivar acceso y revocar sesiones al quitar 2FA, demover, desactivar o retirar el panel.
8. Añadir el panel al catálogo de Roles y Permisos.
9. Sembrar únicamente al administrador nivel 1 activo con 2FA.
10. Actualizar login, menú, gestión de equipo, shadow page y versión de caché.

## Impacto de datos

No modifica ventas, pacientes, caja, comisiones, productos, inventario ni metas. Las únicas escrituras son:

- una fila de catálogo;
- una fila inicial de autorización;
- el espejo del panel en el administrador inicial;
- sesiones opacas y eventos de auditoría.

## Gates

- pgTAP: prueba inválida, uso único de 2FA, grant, revoke, democión, ACL y filtros.
- UI contract: token en `sessionStorage`, permiso explícito y ausencia de la RPC cruda.
- Smoke: Todas, San Isidro y Pueblo Libre.
- Acceso directo sin token: debe mostrar `Acceso restringido` y cero métricas.
- CI general y Zero-Cost Staging: verdes.
- Postdeploy: checksum, ACL, panel, grant inicial y cifras reconciliadas.

## Riesgos y mitigación

- **Sesión anterior sin token:** el administrador debe cerrar sesión e ingresar nuevamente con 2FA.
- **Permiso visual falsificado por política legacy:** no otorga datos; la tabla autoritativa no es accesible por anon.
- **Retiro de permiso durante una sesión:** el trigger revoca las sesiones del usuario.
- **Fallo del gateway:** deniega acceso; no existe fallback a la RPC pública.
- **Rollback:** interrumpe únicamente el módulo; no afecta datos comerciales.

## Rollback de base de datos

Ejecutar solo junto con la reversión del frontend:

```sql
begin;

update public.aos_cia_admin_sessions s
set revoked=true
where exists (
  select 1
  from public.aos_sales_intelligence_access a
  where a.user_id=s.user_id
);

drop trigger if exists trg_aos_sales_intelligence_guard_user on public.aos_usuarios;
drop function if exists public.aos_sales_intelligence_set_access(text,uuid,boolean);
drop function if exists public.aos_sales_intelligence_gateway(text,integer,text,text);
drop function if exists public.aos_sales_intelligence_claim_session(text,text);
drop function if exists public.aos_sales_intelligence_guard_user();

update public.aos_usuarios
set paneles_acceso=array_remove(
  coalesce(paneles_acceso,'{}'::text[]),
  'admin-sales-intelligence'
);

delete from public.aos_paneles_disponibles
where id='admin-sales-intelligence';

drop table if exists public.aos_sales_intelligence_access;
drop index if exists public.aos_cia_admin_sessions_source_code_uidx;

grant execute on function public.aos_sales_intelligence_summary(integer,text,text)
  to anon,authenticated,service_role;

commit;
```

Después: revertir el commit de activación, desplegar el frontend anterior y confirmar que el módulo ya no aparece.
