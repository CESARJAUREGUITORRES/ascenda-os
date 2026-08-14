-- ASCENDA OS — Phase 2 production hardening / final cutover
-- Requires 20260814030000, 20260814034401 and 20260814050000.

begin;

-- Strict panel semantics: no hierarchy bypass when a panel is explicitly requested.
create or replace function public.aos_app_actor_v3(
  p_token text,
  p_required_panel text default null,
  p_require_2fa boolean default false
) returns uuid
language sql
stable
security definer
set search_path=''
as $function$
  select au.id
  from public.aos_app_sessions_v3 s
  join public.aos_usuarios au on au.id=s.user_id
  where s.token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
    and s.revoked=false
    and s.expires_at>now()
    and au.activo=true
    and (not coalesce(p_require_2fa,false) or s.assurance_level='PASSWORD_2FA')
    and (
      coalesce(trim(p_required_panel),'')=''
      or coalesce(au.paneles_acceso,'{}'::text[]) @> array[p_required_panel]::text[]
    )
  limit 1
$function$;

-- Controlled REST replacement for the legacy catalog and plan write paths.
create or replace function public.aos_secure_write_v2(
  p_token text,
  p_table text,
  p_action text,
  p_match jsonb default '{}'::jsonb,
  p_data jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid;
  v_user record;
  v_family text;
  v_action text:=upper(trim(coalesce(p_action,'')));
  v_allowed_match text[];
  v_key text;
  v_where text:='';
  v_set text:='';
  v_row jsonb;
  v_rows jsonb:='[]'::jsonb;
  v_sql text;
  v_all_keys integer;
  v_real_keys integer;
begin
  v_uid:=public.aos_app_actor_v3(p_token,null,false);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  select id,rol,nivel_jerarquia,paneles_acceso into v_user
  from public.aos_usuarios where id=v_uid and activo=true;

  if p_table in ('aos_catalogo_categorias','aos_catalogo_servicios','aos_catalogo_toppings','aos_catalogo_productos_detalle') then
    v_family:='CATALOG';
    if lower(coalesce(v_user.rol,''))<>'admin'
       or not (coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-config']::text[]) then
      return jsonb_build_object('ok',false,'error','CATALOG_ADMIN_REQUIRED');
    end if;
    v_allowed_match:=case when p_table='aos_catalogo_servicios' then array['id','categoria','tipo']::text[] else array['id']::text[] end;
  elsif p_table in ('aos_planes_trabajo','aos_plan_trabajo_items') then
    v_family:='PLAN';
    if not (
      coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['advisor-attendance']::text[]
      or coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-agenda']::text[]
    ) then
      return jsonb_build_object('ok',false,'error','PLAN_ACCESS_REQUIRED');
    end if;
    v_allowed_match:=case when p_table='aos_planes_trabajo' then array['id','numero_limpio','fecha']::text[] else array['id','plan_id','numero_limpio','fecha']::text[] end;
  else
    return jsonb_build_object('ok',false,'error','TABLE_NOT_ALLOWED');
  end if;

  if v_action not in ('INSERT','PATCH','DELETE') then
    return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;

  if v_action in ('PATCH','DELETE') and coalesce(jsonb_object_length(p_match),0)=0 then
    return jsonb_build_object('ok',false,'error','MATCH_REQUIRED');
  end if;

  -- Filters are equality-only and table-specific. Values are quoted; keys are allow-listed.
  for v_key in select jsonb_object_keys(coalesce(p_match,'{}'::jsonb)) loop
    if not (v_key=any(v_allowed_match)) then
      return jsonb_build_object('ok',false,'error','MATCH_NOT_ALLOWED','field',v_key);
    end if;
    if v_where<>'' then v_where:=v_where||' and '; end if;
    v_where:=v_where||format('%I::text=%L',v_key,p_match->>v_key);
  end loop;

  if v_action in ('INSERT','PATCH') then
    select count(*) into v_all_keys from jsonb_object_keys(coalesce(p_data,'{}'::jsonb));
    select count(*) into v_real_keys
    from jsonb_object_keys(coalesce(p_data,'{}'::jsonb)) k
    join information_schema.columns c
      on c.table_schema='public' and c.table_name=p_table and c.column_name=k;
    if v_all_keys=0 or v_all_keys<>v_real_keys then
      return jsonb_build_object('ok',false,'error','FIELD_NOT_ALLOWED');
    end if;
  end if;

  if v_action='INSERT' then
    v_sql:=format(
      'with ins as (insert into public.%I as t select * from jsonb_populate_record(null::public.%I,$1) returning t.*) select coalesce(jsonb_agg(to_jsonb(ins)),''[]''::jsonb) from ins',
      p_table,p_table
    );
    execute v_sql using p_data into v_rows;
  elsif v_action='PATCH' then
    for v_key in select jsonb_object_keys(p_data) loop
      if v_set<>'' then v_set:=v_set||','; end if;
      v_set:=v_set||format('%I=(jsonb_populate_record(t,$1)).%I',v_key,v_key);
    end loop;
    v_sql:=format(
      'with upd as (update public.%I as t set %s where %s returning t.*) select coalesce(jsonb_agg(to_jsonb(upd)),''[]''::jsonb) from upd',
      p_table,v_set,v_where
    );
    execute v_sql using p_data into v_rows;
  else
    v_sql:=format(
      'with del as (delete from public.%I as t where %s returning t.*) select coalesce(jsonb_agg(to_jsonb(del)),''[]''::jsonb) from del',
      p_table,v_where
    );
    execute v_sql into v_rows;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  select au.nombre,'SECURED_WRITE_V2',jsonb_build_object('family',v_family,'table',p_table,'action',v_action,'rows',jsonb_array_length(v_rows))
  from public.aos_usuarios au where au.id=v_uid;

  return jsonb_build_object('ok',true,'rows',v_rows);
exception when others then
  return jsonb_build_object('ok',false,'error','WRITE_REJECTED','detail',sqlstate);
end
$function$;

-- Finance actor and wrappers. Caller-supplied usernames are discarded.
create or replace function public.aos_caja_abrir_v2(
  p_token text,p_sede text,p_efectivo_soles numeric default 0,p_efectivo_dolares numeric default 0,
  p_tipo_cambio numeric default 3.70,p_fecha date default null
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_u record; v_res jsonb; v_sid text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select id,nombre,nivel_jerarquia,sedes_permitidas into v_u from public.aos_usuarios where id=v_uid;
  if v_u.nivel_jerarquia<>1 and not (upper(trim(p_sede))=any(select upper(x) from unnest(coalesce(v_u.sedes_permitidas,'{}'::text[])) x)) then
    return jsonb_build_object('ok',false,'error','SEDE_FORBIDDEN');
  end if;
  v_res:=public.aos_caja_abrir(p_sede,v_u.nombre,p_efectivo_soles,p_efectivo_dolares,p_tipo_cambio,p_fecha);
  if coalesce((v_res->>'ok')::boolean,false) then
    v_sid:=v_res->>'sesion_id';
    update public.aos_caja_sesiones set abierto_por_user_id=v_uid where id=v_sid;
  end if;
  return v_res;
end
$function$;

create or replace function public.aos_caja_cerrar_v2(
  p_token text,p_sesion_id text,p_efectivo_declarado_soles numeric,p_efectivo_declarado_dolares numeric,
  p_retiro_soles numeric default 0,p_retiro_dolares numeric default 0,p_observaciones text default ''
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_name text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select nombre into v_name from public.aos_usuarios where id=v_uid;
  if not exists(select 1 from public.aos_caja_sesiones where id=p_sesion_id and abierto_por_user_id=v_uid and estado='ABIERTA') then
    return jsonb_build_object('ok',false,'error','CAJA_SESSION_FORBIDDEN');
  end if;
  return public.aos_caja_cerrar(p_sesion_id,v_name,p_efectivo_declarado_soles,p_efectivo_declarado_dolares,p_retiro_soles,p_retiro_dolares,p_observaciones);
end
$function$;

create or replace function public.aos_caja_editar_pago_v2(
  p_token text,p_venta_id text,p_sesion_id text,p_nuevo_metodo text,p_nuevo_monto numeric,p_nuevo_estado text,
  p_nueva_moneda text,p_nuevo_comprobante text,p_nuevo_asesor text,p_nuevo_atendio text,p_razon_social_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_name text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if not exists(select 1 from public.aos_caja_sesiones where id=p_sesion_id and abierto_por_user_id=v_uid and estado='ABIERTA') then return jsonb_build_object('ok',false,'error','CAJA_SESSION_FORBIDDEN'); end if;
  select nombre into v_name from public.aos_usuarios where id=v_uid;
  return public.aos_caja_editar_pago(p_venta_id,p_sesion_id,v_name,p_nuevo_metodo,p_nuevo_monto,p_nuevo_estado,p_nueva_moneda,p_nuevo_comprobante,p_nuevo_asesor,p_nuevo_atendio,p_razon_social_id);
end
$function$;

create or replace function public.aos_caja_eliminar_venta_v2(
  p_token text,p_venta_id text,p_sesion_id text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_name text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if not exists(select 1 from public.aos_caja_sesiones where id=p_sesion_id and abierto_por_user_id=v_uid and estado='ABIERTA') then return jsonb_build_object('ok',false,'error','CAJA_SESSION_FORBIDDEN'); end if;
  select nombre into v_name from public.aos_usuarios where id=v_uid;
  return public.aos_caja_eliminar_venta(p_venta_id,p_sesion_id,v_name);
end
$function$;

create or replace function public.aos_caja_ingreso_extra_v2(
  p_token text,p_sesion_id text,p_sede text,p_fecha date,p_concepto text,p_monto numeric,p_moneda text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_name text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if not exists(select 1 from public.aos_caja_sesiones where id=p_sesion_id and abierto_por_user_id=v_uid and estado='ABIERTA' and upper(sede)=upper(p_sede)) then return jsonb_build_object('ok',false,'error','CAJA_SESSION_FORBIDDEN'); end if;
  select nombre into v_name from public.aos_usuarios where id=v_uid;
  return public.aos_caja_ingreso_extra(p_sesion_id,p_sede,p_fecha,p_concepto,p_monto,p_moneda,v_name);
end
$function$;

create or replace function public.aos_caja_registrar_gasto_v2(
  p_token text,p_sesion_id text,p_sede text,p_fecha date,p_concepto text,p_monto numeric,p_moneda text,p_metodo text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_name text;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-caja',true);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if not exists(select 1 from public.aos_caja_sesiones where id=p_sesion_id and abierto_por_user_id=v_uid and estado='ABIERTA' and upper(sede)=upper(p_sede)) then return jsonb_build_object('ok',false,'error','CAJA_SESSION_FORBIDDEN'); end if;
  select nombre into v_name from public.aos_usuarios where id=v_uid;
  return public.aos_caja_registrar_gasto(p_sesion_id,p_sede,p_fecha,p_concepto,p_monto,p_moneda,p_metodo,v_name);
end
$function$;

-- New browser-facing gateways are callable only with opaque session proof.
revoke all on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) from public;
grant execute on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) to anon,authenticated,service_role;

revoke all on function public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date) from public;
revoke all on function public.aos_caja_cerrar_v2(text,text,numeric,numeric,numeric,numeric,text) from public;
revoke all on function public.aos_caja_editar_pago_v2(text,text,text,text,numeric,text,text,text,text,text,uuid) from public;
revoke all on function public.aos_caja_eliminar_venta_v2(text,text,text) from public;
revoke all on function public.aos_caja_ingreso_extra_v2(text,text,text,date,text,numeric,text) from public;
revoke all on function public.aos_caja_registrar_gasto_v2(text,text,text,date,text,numeric,text,text) from public;
grant execute on function public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date) to anon,authenticated,service_role;
grant execute on function public.aos_caja_cerrar_v2(text,text,numeric,numeric,numeric,numeric,text) to anon,authenticated,service_role;
grant execute on function public.aos_caja_editar_pago_v2(text,text,text,text,numeric,text,text,text,text,text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_caja_eliminar_venta_v2(text,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_caja_ingreso_extra_v2(text,text,text,date,text,numeric,text) to anon,authenticated,service_role;
grant execute on function public.aos_caja_registrar_gasto_v2(text,text,text,date,text,numeric,text,text) to anon,authenticated,service_role;

-- Final cutover: weak/legacy token minting and caller-trusting financial mutators are no longer client callable.
revoke execute on function public.aos_login_v2(text,text) from public,anon,authenticated;
revoke execute on function public.aos_verificar_2fa(text,text) from public,anon,authenticated;
revoke execute on function public.aos_cia_claim_admin_session_v1(text,text) from public,anon,authenticated;
revoke execute on function public.aos_sales_intelligence_claim_session(text,text,text,text) from public,anon,authenticated;

revoke execute on function public.aos_caja_abrir(text,text,numeric,numeric,numeric,date) from public,anon,authenticated;
revoke execute on function public.aos_caja_cerrar(text,text,numeric,numeric,numeric,numeric,text) from public,anon,authenticated;
revoke execute on function public.aos_caja_editar_pago(text,text,text,text,numeric,text,text,text,text,text,uuid) from public,anon,authenticated;
revoke execute on function public.aos_caja_eliminar_venta(text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_caja_ingreso_extra(text,text,date,text,numeric,text,text) from public,anon,authenticated;
revoke execute on function public.aos_caja_registrar_gasto(text,text,date,text,numeric,text,text,text) from public,anon,authenticated;

-- Direct writes are closed; SELECT remains for current read-only consumers until their read gateways are migrated.
revoke insert,update,delete,truncate,references,trigger on table public.aos_ventas from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_categorias from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_servicios from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_toppings from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_productos_detalle from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_planes_trabajo from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_plan_trabajo_items from anon,authenticated;

commit;
