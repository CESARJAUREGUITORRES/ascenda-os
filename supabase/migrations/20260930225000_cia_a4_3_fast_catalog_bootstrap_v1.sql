begin;

-- CIA A4.3 · fast read gateway for Audience Workspace.
-- Only CATALOG_META and BOOTSTRAP are intercepted.
-- All mutations, canary guards, planner actions and library operations remain on V7.

create or replace function public.aos_cia_control_center_app_v8(
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
  v_action text:=upper(btrim(coalesce(p_action,'')));
  v_auth jsonb;
  v_uid uuid;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_presets jsonb:='[]'::jsonb;
  v_filters jsonb:='[]'::jsonb;
  v_categories jsonb:='[]'::jsonb;
  v_advisors jsonb:='[]'::jsonb;
  v_total integer:=0;
  v_refreshed timestamptz;
begin
  if v_action not in ('CATALOG_META','BOOTSTRAP') then
    return public.aos_cia_control_center_app_v7(p_app_token,p_action,p_payload);
  end if;

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_uid:=(v_auth->>'user_id')::uuid;
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

  if v_action='BOOTSTRAP' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,
      'name',u.nombre,
      'nombre',u.nombre,
      'code',u.codigo_asesor,
      'codigo_asesor',u.codigo_asesor,
      'panels',coalesce(to_jsonb(u.paneles_acceso),'[]'::jsonb)
    ) order by u.nombre),'[]'::jsonb)
    into v_advisors
    from public.aos_usuarios u
    where u.activo=true
      and lower(coalesce(u.rol,''))='asesor'
      and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[];

    return jsonb_build_object(
      'ok',true,
      'advisors',v_advisors,
      'routing',null,
      'ux',jsonb_build_object(
        'preview_page_size',25,
        'count_mode','EXPLICIT_APPLY',
        'single_flight',true,
        'cancel_stale',true
      ),
      'source','CIA_FAST_BOOTSTRAP_V1',
      'observed_at',statement_timestamp()
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'preset_key',p.preset_key,
    'name',p.name,
    'description',p.description,
    'category',p.category,
    'dsl',p.dsl,
    'registry_version',p.registry_version,
    'count_cache',c.count_cache,
    'count_refreshed_at',c.refreshed_at,
    'count_status',coalesce(c.status,'EMPTY')
  ) order by p.category,p.name),'[]'::jsonb)
  into v_presets
  from public.aos_audience_presets p
  left join public.aos_audience_preset_runtime_cache_v1 c
    on c.preset_key=p.preset_key
  where p.active=true;

  select coalesce(jsonb_agg(jsonb_build_object(
    'field_key',r.field_key,
    'label',r.label,
    'category',r.category,
    'data_type',r.data_type,
    'allowed_operators',r.allowed_operators,
    'enum_values',r.enum_values,
    'description',r.description
  ) order by r.category,r.label),'[]'::jsonb)
  into v_filters
  from public.aos_audience_filter_registry r
  where r.active=true and r.ui_visible=true;

  select coalesce(jsonb_agg(jsonb_build_object(
    'category',x.category,
    'field_count',x.field_count
  ) order by x.category),'[]'::jsonb)
  into v_categories
  from (
    select r.category,count(*)::integer as field_count
    from public.aos_audience_filter_registry r
    where r.active=true and r.ui_visible=true
    group by r.category
  ) x;

  select coalesce(c.count_cache,0)::integer,c.refreshed_at
    into v_total,v_refreshed
  from public.aos_audience_preset_runtime_cache_v1 c
  where c.preset_key='__ALL__';

  return jsonb_build_object(
    'ok',true,
    'total_contacts',v_total,
    'preset_count',jsonb_array_length(v_presets),
    'presets',v_presets,
    'filters',v_filters,
    'categories',v_categories,
    'catalog_refreshed_at',v_refreshed,
    'freshness',jsonb_build_object(
      'segments',v_refreshed,
      'email',v_refreshed,
      'mode','CACHE_ONLY'
    ),
    'source','CIA_FAST_CATALOG_V1',
    'observed_at',statement_timestamp()
  );
exception when others then
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V8_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v8(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v8(text,text,jsonb) to anon,authenticated,service_role;

commit;
