\set ON_ERROR_STOP on

do $assert$
declare
  v_cfg text;
  v_uid uuid:='00000000-0000-0000-0000-000000000401'::uuid;
  v_token text:='F4_CANARY_P0_SYNTHETIC_TOKEN_20260815_ABCDEF';
  v_result jsonb;
begin
  select array_to_string(p.proconfig,',') into v_cfg
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='aos_sales_admin_gateway_v4';
  if coalesce(v_cfg,'') not like '%search_path=pg_catalog, public, extensions%' then
    raise exception 'sales gateway safe nested search_path missing: %',v_cfg;
  end if;

  select array_to_string(p.proconfig,',') into v_cfg
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='aos_caja_abrir_v2';
  if coalesce(v_cfg,'') not like '%search_path=pg_catalog, public, extensions%' then
    raise exception 'caja open v2 safe nested search_path missing: %',v_cfg;
  end if;

  insert into public.aos_rrhh(codigo_asesor,nombre,estado)
  values('F4P0','F4 P0','ACTIVO') on conflict(codigo_asesor) do update set estado='ACTIVO';
  insert into public.aos_usuarios(id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas)
  values(v_uid,'F4P0','F4 P0','admin',1,true,true,array['admin-sales','admin-cartera','admin-caja','admin-import-ventas'],array['SAN ISIDRO','PUEBLO LIBRE'])
  on conflict(id) do update set activo=true,two_factor=true,paneles_acceso=excluded.paneles_acceso;
  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked,last_used_at)
  values(encode(extensions.digest(v_token,'sha256'),'hex'),v_uid,'PASSWORD_2FA',now()+interval '1 hour',false,null)
  on conflict(token_hash) do update set revoked=false,expires_at=excluded.expires_at,last_used_at=null;

  v_result:=public.aos_cartera_gateway_v2(v_token,'','',50,0);
  if coalesce((v_result->>'ok')::boolean,false) is not true
     or v_result->>'contract'<>'F4_CARTERA_GATEWAY_V2'
     or coalesce((v_result->>'strongAuth')::boolean,false) is not true then
    raise exception 'cartera v2 strong bridge contract failed: %',v_result;
  end if;
  if (select last_used_at is null from public.aos_app_sessions_v3 where user_id=v_uid) then
    raise exception 'cartera v2 did not mark strong app session used';
  end if;

  v_result:=public.aos_cartera_gateway_v2('INVALID_TOKEN_INVALID_TOKEN_INVALID_TOKEN','','',50,0);
  if v_result->>'error'<>'UNAUTHORIZED' then
    raise exception 'cartera v2 invalid token must fail closed: %',v_result;
  end if;

  if not has_function_privilege('anon','public.aos_cartera_gateway_v2(text,text,text,integer,integer)','EXECUTE') then
    raise exception 'anon cannot reach strong Cartera v2 wrapper';
  end if;
end
$assert$;
