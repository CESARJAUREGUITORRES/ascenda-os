-- ASCENDA OS — F4 production canary P0.
-- Fixes runtime inheritance when hardened wrappers call legacy SECURITY DEFINER
-- functions that still resolve unqualified public relations.
-- Also introduces a strong-Auth V3 Cartera read bridge for the production panel.

begin;

-- Security precondition: public is a lookup schema for legacy relations only.
-- Untrusted API roles must not be able to create shadow objects in it.
do $guard$
begin
  if has_schema_privilege('anon','public','CREATE')
     or has_schema_privilege('authenticated','public','CREATE')
     or has_schema_privilege('public','public','CREATE') then
    raise exception 'F4_P0_PUBLIC_SCHEMA_CREATE_MUST_BE_REVOKED';
  end if;
end
$guard$;

-- F4 wrappers invoke legacy functions whose bodies use unqualified public tables.
-- pg_catalog is first; public is safe here because CREATE is revoked above.
alter function public.aos_sales_admin_gateway_v4(text,integer,integer,text,text,text)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_editar_venta_v4(text,bigint,timestamptz,jsonb,text)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_importar_ventas_v4(text,jsonb)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_grabar_venta_caja_v4(text,text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric)
  set search_path = pg_catalog, public, extensions;

-- Phase-2 Caja wrappers have the same nested-legacy requirement.
alter function public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_caja_cerrar_v2(text,text,numeric,numeric,numeric,numeric,text)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_caja_editar_pago_v2(text,text,text,text,numeric,text,text,text,text,text,uuid)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_caja_eliminar_venta_v2(text,text,text)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_caja_ingreso_extra_v2(text,text,text,date,text,numeric,text)
  set search_path = pg_catalog, public, extensions;
alter function public.aos_caja_registrar_gasto_v2(text,text,text,date,text,numeric,text,text)
  set search_path = pg_catalog, public, extensions;

-- Cartera read bridge: require the current strong Auth V3 contract first, then
-- reuse the already-audited reconciliation read query internally. Calling the
-- legacy gateway inside this SECURITY DEFINER function avoids exposing its
-- retired/legacy authorization surface to the browser.
create or replace function public.aos_cartera_gateway_v2(
  p_token text,
  p_estado text default '',
  p_sede text default '',
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_result jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-cartera');
  if v_actor is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_result:=public.aos_cartera_gateway(
    p_token,p_estado,p_sede,p_limit,p_offset
  );
  if coalesce((v_result->>'ok')::boolean,false)=false then
    return v_result;
  end if;

  update public.aos_app_sessions_v3
  set last_used_at=now()
  where user_id=v_actor and revoked=false;

  return v_result || jsonb_build_object(
    'contract','F4_CARTERA_GATEWAY_V2',
    'strongAuth',true
  );
end
$function$;

revoke all on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) from public;
grant execute on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) to anon,authenticated;

-- Force PostgREST to refresh function metadata after ALTER/CREATE.
notify pgrst, 'reload schema';

commit;
