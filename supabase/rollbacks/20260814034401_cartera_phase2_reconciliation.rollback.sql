-- ASCENDA OS — FASE 2 Cartera — rollback seguro de emergencia.
-- Ejecutar solo tras snapshot y aprobación productiva expresa.
-- No restaura acceso anonimo ni el RPC legacy a clientes.

begin;

drop trigger if exists trg_aos_cartera_sync_venta on public.aos_ventas;
drop trigger if exists trg_aos_cartera_sync_cotizacion on public.aos_cotizaciones;

revoke all on function public.aos_cartera_gateway(text,text,text,integer,integer)
  from public,anon,authenticated;
revoke all on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text)
  from public,anon,authenticated;
revoke all on function public.aos_caja_cotizaciones_gateway(text,text,text,text)
  from public,anon,authenticated;
revoke all on function public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text)
  from public,anon,authenticated;

drop function if exists public.aos_cartera_gateway(text,text,text,integer,integer);
drop function if exists public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text);
drop function if exists public.aos_caja_cotizaciones_gateway(text,text,text,text);
drop function if exists public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text);
drop function if exists public.aos_cartera_actor(text,text);
drop function if exists public.aos_cartera_sync_venta();
drop function if exists public.aos_cartera_sync_cotizacion();

delete from public.aos_paneles_disponibles where id='admin-cartera';

do $rollback$
begin
  if to_regclass('public.aos_cartera_reconciliacion') is not null
     and to_regclass('public.aos_cartera_reconciliacion_rollback_20260814') is null then
    alter table public.aos_cartera_reconciliacion
      rename to aos_cartera_reconciliacion_rollback_20260814;
  end if;
end;
$rollback$;

-- Conserva RLS, revocaciones de tablas financieras, columnas de trazabilidad,
-- request_id/request_hash y la restriccion service_role del RPC legacy.
commit;
