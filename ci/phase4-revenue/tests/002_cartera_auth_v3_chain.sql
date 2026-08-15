\set ON_ERROR_STOP on

-- Synthetic contract only. No production business data.
do $contract$
declare
  v2_def text;
  legacy_def text;
  v_token text:=repeat('C',40);
  v_user uuid:='11111111-1111-4111-8111-111111111111'::uuid;
  v_before bigint;
  v_after bigint;
  v_result jsonb;
begin
  v2_def:=pg_get_functiondef('public.aos_cartera_gateway_v2(text,text,text,integer,integer)'::regprocedure);
  legacy_def:=pg_get_functiondef('public.aos_cartera_gateway(text,text,text,integer,integer)'::regprocedure);

  if position('aos_f4_actor' in v2_def)=0 then
    raise exception 'F4_CARTERA_V2_MISSING_AUTH_V3_ACTOR';
  end if;
  if position('aos_cartera_gateway(' in v2_def)>0 then
    raise exception 'F4_CARTERA_V2_DELEGATES_TO_LEGACY';
  end if;
  if position('aos_cartera_gateway_v2' in legacy_def)=0 then
    raise exception 'F4_CARTERA_LEGACY_READ_NOT_ALIASING_V2';
  end if;
  if position('aos_cia_admin_sessions' in legacy_def)>0
     or position('aos_cartera_actor' in legacy_def)>0 then
    raise exception 'F4_CARTERA_LEGACY_READ_RETAINS_FINANCE_AUTH';
  end if;

  insert into public.aos_rrhh(codigo_asesor,nombre,estado)
  values ('F4-CARTERA-CI','F4 Cartera CI','ACTIVO')
  on conflict (codigo_asesor) do update set estado='ACTIVO';

  insert into public.aos_usuarios(
    id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas
  ) values (
    v_user,'F4-CARTERA-CI','F4 Cartera CI','admin',1,true,true,
    array['admin-cartera']::text[],array['SAN ISIDRO','PUEBLO LIBRE']::text[]
  ) on conflict (id) do update set
    activo=true,two_factor=true,rol='admin',nivel_jerarquia=1,
    paneles_acceso=array['admin-cartera']::text[],
    sedes_permitidas=array['SAN ISIDRO','PUEBLO LIBRE']::text[];

  insert into public.aos_app_sessions_v3(
    token_hash,user_id,assurance_level,expires_at,revoked,last_used_at
  ) values (
    encode(extensions.digest(v_token,'sha256'),'hex'),v_user,'PASSWORD_2FA',now()+interval '30 minutes',false,now()
  ) on conflict (token_hash) do update set
    user_id=excluded.user_id,assurance_level='PASSWORD_2FA',
    expires_at=excluded.expires_at,revoked=false;

  select count(*) into v_before from public.aos_cartera_reconciliacion;

  v_result:=public.aos_cartera_gateway_v2(v_token,'','',100,0);
  if coalesce((v_result->>'ok')::boolean,false) is not true
     or v_result->>'contract'<>'F4_CARTERA_GATEWAY_V2'
     or coalesce((v_result->>'strongAuth')::boolean,false) is not true then
    raise exception 'F4_CARTERA_V2_VALID_APP_TOKEN_REJECTED: %',v_result;
  end if;

  v_result:=public.aos_cartera_gateway(v_token,'SAN ISIDRO',100,0);
  if coalesce((v_result->>'ok')::boolean,false) is not true then
    raise exception 'F4_CARTERA_LEGACY_READ_ALIAS_REJECTED_APP_TOKEN: %',v_result;
  end if;

  v_result:=public.aos_cartera_gateway(v_token,'','PUEBLO LIBRE',100,0);
  if coalesce((v_result->>'ok')::boolean,false) is not true then
    raise exception 'F4_CARTERA_PUEBLO_LIBRE_FILTER_FAILED: %',v_result;
  end if;

  v_result:=public.aos_cartera_gateway_v2(repeat('X',40),'','',100,0);
  if coalesce((v_result->>'ok')::boolean,true) is not false
     or v_result->>'error'<>'UNAUTHORIZED' then
    raise exception 'F4_CARTERA_INVALID_TOKEN_NOT_REJECTED: %',v_result;
  end if;

  select count(*) into v_after from public.aos_cartera_reconciliacion;
  if v_after<>v_before then
    raise exception 'F4_CARTERA_READ_CONTRACT_MUTATED_CASES';
  end if;
end
$contract$;

select 'F4_CARTERA_AUTH_V3_CHAIN=PASS' as result;
