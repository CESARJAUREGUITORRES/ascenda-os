begin;

create or replace function public.aos_cia_snapshot_create_admin_v1(
  p_token text,
  p_audience_id uuid,
  p_version integer default null::integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  auth jsonb;
  uid uuid;
  a record;
  v record;
  keys text[];
  sid uuid;
  t timestamptz:=statement_timestamp();
  mc integer;
  mh text;
  fh text;
  v_preset_key text;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=(auth->>'user_id')::uuid;

  select id,estado,current_version into a
  from public.aos_audiencias
  where id=p_audience_id;

  if a.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND');
  end if;
  if a.estado<>'ACTIVE' then
    return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED');
  end if;

  select id,version,filter_dsl into v
  from public.aos_audiencia_versiones
  where audiencia_id=a.id
    and version=coalesce(p_version,a.current_version);

  if v.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  select p.preset_key into v_preset_key
  from public.aos_audience_presets p
  where p.active=true
    and p.dsl=v.filter_dsl
  order by p.preset_key
  limit 1;

  if v_preset_key is not null then
    select coalesce(array_agg(c.contact_key order by c.contact_key),array[]::text[])
      into keys
    from public.aos_cia_workspace_catalog_members_v1(v_preset_key) c;
  else
    select coalesce(array_agg(k order by k),array[]::text[])
      into keys
    from (
      select distinct unnest(
        public.aos_cia_audience_resolve_node_v2(v.filter_dsl->'root',1)
      ) k
    ) q;
  end if;

  mc:=coalesce(cardinality(keys),0);
  if mc>100000 then
    return jsonb_build_object('ok',false,'error','SNAPSHOT_TOO_LARGE','count',mc);
  end if;

  fh:=encode(extensions.digest(v.filter_dsl::text,'sha256'),'hex');

  select encode(
    extensions.digest(coalesce(string_agg(k,E'\\n' order by k),''),'sha256'),
    'hex'
  ) into mh
  from unnest(keys) k;

  insert into public.aos_audiencia_snapshots(
    audiencia_id,audiencia_version_id,filter_hash,resolved_at,created_by_user_id
  )
  values(a.id,v.id,fh,t,uid)
  returning id into sid;

  if v_preset_key is not null then
    insert into public.aos_audiencia_snapshot_miembros(
      snapshot_id,contact_key,identity_status,identity_conflict,resolved_at
    )
    select
      sid,
      k,
      null,
      coalesce(c.identity_conflict,false),
      t
    from unnest(keys) k
    left join public.aos_cia_contact_runtime_cache_v1 c
      on c.contact_key=k;
  else
    insert into public.aos_audiencia_snapshot_miembros(
      snapshot_id,contact_key,identity_status,identity_conflict,resolved_at
    )
    select
      sid,
      k,
      i.identity_status,
      coalesce(i.identity_conflict,false),
      t
    from unnest(keys) k
    left join public.aos_cia_contact_identity_v1 i
      on i.contact_key=k;
  end if;

  update public.aos_audiencia_snapshots
  set estado='READY',
      member_count=mc,
      membership_hash=mh,
      sealed_at=clock_timestamp()
  where id=sid;

  return jsonb_build_object(
    'ok',true,
    'snapshot',jsonb_build_object(
      'id',sid,
      'audience_id',a.id,
      'audience_version_id',v.id,
      'audience_version',v.version,
      'member_count',mc,
      'membership_hash',mh,
      'filter_hash',fh,
      'resolved_at',t,
      'estado','READY'
    )
  );
end;
$function$;

create or replace function public.aos_cia_activation_create_admin_v1(
  p_token text,
  p_audience_id uuid,
  p_version integer,
  p_name text,
  p_purpose text,
  p_channel text,
  p_mode text,
  p_start_now boolean default false,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  auth jsonb;
  uid uuid;
  a record;
  v record;
  cntj jsonb;
  cnt integer;
  t timestamptz:=statement_timestamp();
  snap jsonb;
  sid uuid;
  actid uuid;
  md jsonb:=coalesce(p_metadata,'{}'::jsonb);
  ch text:=upper(btrim(coalesce(p_channel,'')));
  mo text:=upper(btrim(coalesce(p_mode,'')));
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=(auth->>'user_id')::uuid;

  if char_length(btrim(coalesce(p_name,''))) not between 3 and 120 then
    return jsonb_build_object('ok',false,'error','INVALID_NAME');
  end if;
  if char_length(btrim(coalesce(p_purpose,''))) not between 2 and 120 then
    return jsonb_build_object('ok',false,'error','INVALID_PURPOSE');
  end if;
  if ch not in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER') then
    return jsonb_build_object('ok',false,'error','INVALID_CHANNEL');
  end if;
  if mo not in ('BATCH','DYNAMIC') then
    return jsonb_build_object('ok',false,'error','INVALID_MODE');
  end if;
  if jsonb_typeof(md)<>'object' or pg_column_size(md)>32768 then
    return jsonb_build_object('ok',false,'error','INVALID_METADATA');
  end if;

  select id,estado,current_version into a
  from public.aos_audiencias
  where id=p_audience_id;

  if a.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND');
  end if;
  if a.estado<>'ACTIVE' then
    return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED');
  end if;

  select id,version,filter_dsl into v
  from public.aos_audiencia_versiones
  where audiencia_id=a.id
    and version=coalesce(p_version,a.current_version);

  if v.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  sid:=null;

  if mo='BATCH' then
    snap:=public.aos_cia_snapshot_create_admin_v1(p_token,a.id,v.version);
    if not coalesce((snap->>'ok')::boolean,false) then
      return snap;
    end if;
    sid:=(snap#>>'{snapshot,id}')::uuid;
    cnt:=coalesce((snap#>>'{snapshot,member_count}')::integer,0);
  else
    cntj:=public.aos_cia_audience_count_v2(v.filter_dsl);
    if not coalesce((cntj->>'ok')::boolean,false) then
      return jsonb_build_object('ok',false,'error','COUNT_FAILED');
    end if;
    cnt:=coalesce((cntj->>'count')::integer,0);
  end if;

  insert into public.aos_audiencia_activaciones(audiencia_id,audiencia_version_id)
  values(a.id,v.id)
  returning id into actid;

  insert into public.aos_audiencia_activacion_config(
    activacion_id,snapshot_id,nombre,purpose,channel,mode,
    baseline_count,baseline_resolved_at,metadata,created_by_user_id
  )
  values(
    actid,sid,btrim(p_name),btrim(p_purpose),ch,mo,cnt,t,
    md||jsonb_build_object('context_only',true,'phase',7),
    uid
  );

  insert into public.aos_audiencia_activacion_estado(
    activacion_id,estado,updated_by_user_id
  )
  values(actid,'DRAFT',uid);

  if coalesce(p_start_now,false) then
    update public.aos_audiencia_activacion_estado
    set estado='ACTIVE',
        updated_by_user_id=uid,
        started_at=clock_timestamp(),
        ended_at=null
    where activacion_id=actid;
  end if;

  return jsonb_build_object(
    'ok',true,
    'activation_id',actid,
    'snapshot_id',sid,
    'mode',mo,
    'state',case when p_start_now then 'ACTIVE' else 'DRAFT' end,
    'baseline_count',cnt,
    'baseline_resolved_at',t,
    'context_only',true
  );
end;
$function$;

comment on function public.aos_cia_snapshot_create_admin_v1(text,uuid,integer)
is 'CIA snapshot creator. Catalog-equivalent audiences use the runtime-cache membership fast path; custom audiences retain the canonical resolver fallback.';

comment on function public.aos_cia_activation_create_admin_v1(text,uuid,integer,text,text,text,text,boolean,jsonb)
is 'CIA activation creator. BATCH activations derive baseline_count from the sealed snapshot and avoid duplicate audience resolution.';



create or replace function public.aos_cia_distribution_preview_app_v2(
  p_app_token text,
  p_preset_key text,
  p_source_limit integer default 100,
  p_all_available boolean default false,
  p_targets jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;
  v_uid uuid;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_key text:=upper(coalesce(p_preset_key,''));
  v_targets jsonb:=coalesce(p_targets,'[]'::jsonb);
  v_target_count integer;
  v_valid_count integer;
  v_distinct_count integer;
  v_audience_count integer:=0;
  v_eligible_count integer:=0;
  v_ineligible_count integer:=0;
  v_unknown_count integer:=0;
  v_candidate_count integer:=0;
  v_called_today integer:=0;
  v_future_appointment integer:=0;
  v_legacy_in_progress integer:=0;
  v_disqualified integer:=0;
  v_province_route integer:=0;
  v_invalid_phone integer:=0;
  v_requested integer;
  v_base integer;
  v_remainder integer;
  v_idx integer:=0;
  v_quota integer;
  v_assigned integer:=0;
  v_quotas jsonb:='[]'::jsonb;
  e record;
begin
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

  if not exists(
    select 1
    from public.aos_audience_presets p
    where p.active=true and upper(p.preset_key)=v_key
  ) then
    return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
  end if;

  if jsonb_typeof(v_targets)<>'array' then
    return jsonb_build_object('ok',false,'error','INVALID_TARGETS');
  end if;

  v_target_count:=jsonb_array_length(v_targets);
  if v_target_count<1 or v_target_count>50 then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET_COUNT');
  end if;

  if not coalesce(p_all_available,false)
     and (p_source_limit is null or p_source_limit<1 or p_source_limit>100000) then
    return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
  end if;

  begin
    select
      count(distinct (x.value->>'advisor_user_id')::uuid),
      count(*) filter(
        where u.id is not null
          and u.activo=true
          and lower(coalesce(u.rol,''))='asesor'
          and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
      )
      into v_distinct_count,v_valid_count
    from jsonb_array_elements(v_targets) x(value)
    left join public.aos_usuarios u
      on u.id=(x.value->>'advisor_user_id')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET_PAYLOAD');
  end;

  if v_distinct_count<>v_target_count then
    return jsonb_build_object('ok',false,'error','DUPLICATE_TARGET');
  end if;

  if v_valid_count<>v_target_count then
    return jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
  end if;

  with m as materialized (
    select
      c.contact_key,
      c.lifecycle,
      c.latest_call_status,
      coalesce(c.called_today,false) as called_today,
      coalesce(c.has_future_appointment,false) as has_future_appointment
    from public.aos_cia_workspace_catalog_members_v1(v_key) c
  ),
  legacy as (
    select distinct l.numero_limpio
    from public.aos_leads_en_curso l
    where l.fecha=(now() at time zone 'America/Lima')::date
  ),
  d as (
    select
      m.*,
      (l.numero_limpio is not null) as legacy_in_progress,
      case
        when m.contact_key !~ '^[0-9]{9}$' then 'INELIGIBLE'
        when m.lifecycle is null then 'UNKNOWN'
        when m.lifecycle='DISQUALIFIED_PROSPECT' then 'INELIGIBLE'
        when m.latest_call_status in ('PROVINCIA','PROVINCIAS') then 'INELIGIBLE'
        else 'ELIGIBLE'
      end as eligibility
    from m
    left join legacy l on l.numero_limpio=m.contact_key
  )
  select
    count(*)::integer,
    count(*) filter(where eligibility='ELIGIBLE')::integer,
    count(*) filter(where eligibility='INELIGIBLE')::integer,
    count(*) filter(where eligibility='UNKNOWN')::integer,
    count(*) filter(
      where eligibility='ELIGIBLE'
        and not called_today
        and not has_future_appointment
        and not legacy_in_progress
    )::integer,
    count(*) filter(where called_today)::integer,
    count(*) filter(where has_future_appointment)::integer,
    count(*) filter(where legacy_in_progress)::integer,
    count(*) filter(where lifecycle='DISQUALIFIED_PROSPECT')::integer,
    count(*) filter(where latest_call_status in ('PROVINCIA','PROVINCIAS'))::integer,
    count(*) filter(where contact_key !~ '^[0-9]{9}$')::integer
  into
    v_audience_count,
    v_eligible_count,
    v_ineligible_count,
    v_unknown_count,
    v_candidate_count,
    v_called_today,
    v_future_appointment,
    v_legacy_in_progress,
    v_disqualified,
    v_province_route,
    v_invalid_phone
  from d;

  v_requested:=case
    when coalesce(p_all_available,false) then v_candidate_count
    else least(p_source_limit,v_candidate_count)
  end;

  v_base:=floor(v_requested::numeric/v_target_count)::integer;
  v_remainder:=v_requested-(v_base*v_target_count);

  for e in
    select x.value,x.ordinality
    from jsonb_array_elements(v_targets) with ordinality x(value,ordinality)
    order by coalesce(
      nullif(x.value->>'priority','')::integer,
      (x.ordinality*10)::integer
    ),x.ordinality
  loop
    v_idx:=v_idx+1;
    v_quota:=v_base+case when v_idx<=v_remainder then 1 else 0 end;
    v_assigned:=v_assigned+v_quota;
    v_quotas:=v_quotas||jsonb_build_array(jsonb_build_object(
      'advisor_user_id',e.value->>'advisor_user_id',
      'priority',coalesce(
        nullif(e.value->>'priority','')::integer,
        (e.ordinality*10)::integer
      ),
      'projected_quantity',v_quota
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,
    'strategy','EQUAL',
    'quantity_mode',case
      when coalesce(p_all_available,false) then 'ALL_AVAILABLE'
      else 'FIXED'
    end,
    'audience_count',v_audience_count,
    'eligible_count',v_eligible_count,
    'ineligible_count',v_ineligible_count,
    'eligibility_unknown',v_unknown_count,
    'candidate_count',v_candidate_count,
    'assignable_now',v_candidate_count,
    'requested_count',v_requested,
    'source_limit',case
      when coalesce(p_all_available,false) then null
      else p_source_limit
    end,
    'projected_assigned',v_assigned,
    'remaining_after_plan',greatest(v_candidate_count-v_assigned,0),
    'blocked',jsonb_build_object(
      'called_today',v_called_today,
      'future_appointment',v_future_appointment,
      'legacy_in_progress',v_legacy_in_progress,
      'disqualified',v_disqualified,
      'province_route',v_province_route,
      'invalid_phone',v_invalid_phone
    ),
    'target_count',v_target_count,
    'quotas',v_quotas,
    'execution',jsonb_build_object(
      'enabled',false,
      'reason','HUMAN_CANARY_REQUIRED'
    ),
    'source','CATALOG_CALL_ELIGIBILITY_CACHE_V3',
    'observed_at',statement_timestamp()
  );
exception when others then
  return jsonb_build_object(
    'ok',false,
    'error','DISTRIBUTION_PREVIEW_V3_ERROR',
    'code',sqlstate
  );
end
$function$;

comment on function public.aos_cia_distribution_preview_app_v2(text,text,integer,boolean,jsonb)
is 'CIA Call Center distribution preview. Uses catalog runtime membership plus cached CALL_GENERAL eligibility and live legacy in-progress leases; candidate_count means assignable now, not raw audience size.';

commit;
