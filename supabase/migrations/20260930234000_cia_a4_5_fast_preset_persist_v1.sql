begin;

-- CIA A4.5 · fast persistence for live catalog presets.
-- Catalog selections already carry a governed DSL and a materialized runtime count.
-- Persisting them must not re-resolve the entire audience before a one-contact canary.

create or replace function public.aos_cia_audience_library_create_preset_fast_v1(
  p_user_id uuid,
  p_name text,
  p_description text,
  p_filter jsonb,
  p_reason text default 'CREATE_PRESET_FAST'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_name text:=btrim(coalesce(p_name,''));
  v_description text:=coalesce(p_description,'');
  v_reason text:=left(coalesce(p_reason,'CREATE_PRESET_FAST'),500);
  v_preset_key text;
  v_count integer;
  v_refreshed_at timestamptz;
  v_audience_id uuid;
  v_version_id uuid;
  v_existing record;
  v_existing_filter jsonb;
begin
  if not public.aos_cia_admin_user_ok_v1(p_user_id) then
    return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED');
  end if;

  if char_length(v_name) not between 3 and 120 then
    return jsonb_build_object('ok',false,'error','INVALID_NAME');
  end if;

  if char_length(v_description)>1000 then
    return jsonb_build_object('ok',false,'error','DESCRIPTION_TOO_LONG');
  end if;

  if p_filter is null or jsonb_typeof(p_filter)<>'object' then
    return jsonb_build_object('ok',false,'error','FILTER_REQUIRED');
  end if;

  select p.preset_key,c.count_cache,c.refreshed_at
    into v_preset_key,v_count,v_refreshed_at
  from public.aos_audience_presets p
  join public.aos_audience_preset_runtime_cache_v1 c
    on c.preset_key=p.preset_key
  where p.active=true
    and p.dsl=p_filter
  order by p.preset_key
  limit 1;

  if v_preset_key is null then
    return jsonb_build_object('ok',false,'error','NOT_CATALOG_PRESET');
  end if;

  select a.id,a.current_version
    into v_existing
  from public.aos_audiencias a
  where a.estado='ACTIVE'
    and lower(btrim(a.nombre))=lower(v_name)
  order by a.created_at
  limit 1;

  if v_existing.id is not null then
    select v.filter_dsl
      into v_existing_filter
    from public.aos_audiencia_versiones v
    where v.audiencia_id=v_existing.id
      and v.version=v_existing.current_version;

    if v_existing_filter=p_filter then
      return public.aos_cia_audience_library_get_v1(v_existing.id)
        || jsonb_build_object(
          'operation','REUSE',
          'source','CATALOG_PRESET_CACHE',
          'preset_key',v_preset_key,
          'count_cache',coalesce(v_count,0),
          'count_refreshed_at',v_refreshed_at
        );
    end if;

    return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
  end if;

  insert into public.aos_audiencias(
    nombre,descripcion,created_by_user_id,updated_by_user_id
  )
  values(
    v_name,v_description,p_user_id,p_user_id
  )
  returning id into v_audience_id;

  insert into public.aos_audiencia_versiones(
    audiencia_id,version,filter_dsl,reason,count_cache,resolved_at,created_by_user_id
  )
  values(
    v_audience_id,1,p_filter,v_reason,coalesce(v_count,0),coalesce(v_refreshed_at,now()),p_user_id
  )
  returning id into v_version_id;

  insert into public.aos_audiencia_audit(
    audiencia_id,audiencia_version_id,action,actor_user_id,after_state
  )
  values(
    v_audience_id,v_version_id,'CREATE',p_user_id,
    jsonb_build_object(
      'nombre',v_name,
      'version',1,
      'count_at_save',coalesce(v_count,0),
      'preset_key',v_preset_key,
      'source','CATALOG_PRESET_CACHE'
    )
  );

  return public.aos_cia_audience_library_get_v1(v_audience_id)
    || jsonb_build_object(
      'operation','CREATE',
      'source','CATALOG_PRESET_CACHE',
      'preset_key',v_preset_key,
      'count_cache',coalesce(v_count,0),
      'count_refreshed_at',v_refreshed_at
    );
exception
  when unique_violation then
    return jsonb_build_object('ok',false,'error','NAME_CONFLICT');
  when check_violation then
    return jsonb_build_object('ok',false,'error','CONSTRAINT_VIOLATION');
end
$function$;

revoke all on function public.aos_cia_audience_library_create_preset_fast_v1(uuid,text,text,jsonb,text) from public;

create or replace function public.aos_cia_control_center_app_v10(
  p_app_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_action text:=upper(btrim(coalesce(p_action,'')));
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_auth jsonb;
  v_uid uuid;
  v_name text;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_filter jsonb;
  v_preset_key text;
  v_out jsonb;
begin
  if v_action<>'CREATE_AUDIENCE' then
    return public.aos_cia_control_center_app_v9(p_app_token,p_action,v_payload);
  end if;

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_uid:=(v_auth->>'user_id')::uuid;
  v_name:=coalesce(v_auth->>'nombre','');
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));

  select coalesce(u.paneles_acceso,'{}'::text[])
    into v_panels
  from public.aos_usuarios u
  where u.id=v_uid and u.activo=true;

  if v_role<>'ADMIN'
     or v_assurance<>'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  if jsonb_typeof(v_payload)<>'object' or pg_column_size(v_payload)>65536 then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  v_filter:=v_payload->'filter';

  select p.preset_key
    into v_preset_key
  from public.aos_audience_presets p
  join public.aos_audience_preset_runtime_cache_v1 c
    on c.preset_key=p.preset_key
  where p.active=true
    and p.dsl=v_filter
  order by p.preset_key
  limit 1;

  -- Custom audiences continue through the governed full resolver.
  if v_preset_key is null then
    return public.aos_cia_control_center_app_v9(p_app_token,p_action,v_payload);
  end if;

  v_out:=public.aos_cia_audience_library_create_preset_fast_v1(
    v_uid,
    v_payload->>'name',
    coalesce(v_payload->>'description',''),
    v_filter,
    coalesce(v_payload->>'reason','CIA_WORKSPACE_V3_DISTRIBUTION')
  );

  insert into public.aos_cia_gateway_audit(
    user_id,usuario,action,ok,duration_ms,meta
  )
  values(
    v_uid,v_name,v_action,coalesce((v_out->>'ok')::boolean,false),
    greatest(0,round(extract(epoch from(clock_timestamp()-v_started))*1000)::integer),
    jsonb_build_object(
      'gateway_version',10,
      'preset_key',v_preset_key,
      'fast_persist',true,
      'source','CATALOG_PRESET_CACHE'
    )
  );

  return v_out;
exception
  when others then
    return jsonb_build_object(
      'ok',false,
      'error','CONTROL_CENTER_V10_ERROR',
      'code',sqlstate
    );
end
$function$;

revoke all on function public.aos_cia_control_center_app_v10(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v10(text,text,jsonb) to anon,authenticated,service_role;

comment on function public.aos_cia_control_center_app_v10(text,text,jsonb)
is 'CIA A4.5: live catalog presets persist from registry+runtime cache without audience re-resolution; non-create actions delegate to V9.';

select pg_notify('pgrst','reload schema');

commit;
