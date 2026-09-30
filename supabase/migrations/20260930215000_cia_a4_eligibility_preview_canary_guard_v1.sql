begin;

-- CIA A4.1 · eligibility-aware distribution preview + fail-closed WEB canary.
-- Read-only planning now mirrors CALL_GENERAL availability gates before any assignment.
-- Bulk distribution remains disabled.

create or replace function public.aos_cia_call_preview_rows_v1(
  p_preset_key text default null,
  p_filter jsonb default null
)
returns table(
  contact_key text,
  eligibility_status text,
  availability_status text,
  is_assignable boolean,
  reasons text[]
)
language sql
stable
security definer
set search_path to ''
as $function$
with src as (
  select c.contact_key
  from public.aos_cia_workspace_catalog_members_v1(upper(coalesce(p_preset_key,''))) c
  where nullif(btrim(coalesce(p_preset_key,'')),'') is not null

  union

  select k
  from unnest(
    public.aos_cia_audience_resolve_node_v2(
      coalesce(p_filter,'{}'::jsonb)->'root',
      1
    )
  ) k
  where nullif(btrim(coalesce(p_preset_key,'')),'') is null
),
base as (
  select
    s.contact_key,
    c.latest_call_status,
    coalesce(c.called_today,false) as called_today,
    coalesce(c.has_future_appointment,false) as future_appointment,
    c.lifecycle,
    exists(
      select 1
      from public.aos_leads_en_curso l
      where l.fecha=(now() at time zone 'America/Lima')::date
        and l.numero_limpio in (s.contact_key,'51'||s.contact_key)
    ) as legacy_in_progress
  from src s
  left join public.aos_cia_contact_runtime_cache_v1 c
    on c.contact_key=s.contact_key
),
classified as (
  select
    b.*,
    case
      when b.contact_key !~ '^[0-9]{9}$' then 'INELIGIBLE'
      when b.lifecycle is null then 'UNKNOWN'
      when b.lifecycle='DISQUALIFIED_PROSPECT' then 'INELIGIBLE'
      when b.latest_call_status in ('PROVINCIA','PROVINCIAS') then 'INELIGIBLE'
      else 'ELIGIBLE'
    end as elig,
    array_remove(array[
      case when b.contact_key !~ '^[0-9]{9}$' then 'PHONE_INVALID' end,
      case when b.lifecycle is null then 'SEGMENT_FRESHNESS_UNKNOWN' end,
      case when b.lifecycle='DISQUALIFIED_PROSPECT' then 'CURRENTLY_DISQUALIFIED' end,
      case when b.latest_call_status in ('PROVINCIA','PROVINCIAS') then 'CURRENT_PROVINCE_ROUTE' end,
      case when b.called_today then 'CALLED_TODAY' end,
      case when b.future_appointment then 'FUTURE_APPOINTMENT' end,
      case when b.legacy_in_progress then 'LEGACY_WORK_IN_PROGRESS' end
    ],null) as rs
  from base b
)
select
  d.contact_key,
  d.elig,
  case
    when d.elig='UNKNOWN' then 'UNKNOWN'
    when d.elig='INELIGIBLE' then 'UNAVAILABLE'
    when d.called_today or d.future_appointment or d.legacy_in_progress then 'UNAVAILABLE'
    else 'AVAILABLE'
  end,
  (
    d.elig='ELIGIBLE'
    and not d.called_today
    and not d.future_appointment
    and not d.legacy_in_progress
  ),
  d.rs
from classified d
order by d.contact_key
$function$;

revoke all on function public.aos_cia_call_preview_rows_v1(text,jsonb) from public,anon,authenticated;


create or replace function public.aos_cia_distribution_preview_app_v3(
  p_app_token text,
  p_preset_key text default null,
  p_filter jsonb default null,
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
  v_key text:=upper(btrim(coalesce(p_preset_key,'')));
  v_filter jsonb:=coalesce(p_filter,'{}'::jsonb);
  v_validation jsonb;
  v_targets jsonb:=coalesce(p_targets,'[]'::jsonb);
  v_target_count integer;
  v_valid_count integer;
  v_distinct_count integer;
  v_audience_count integer:=0;
  v_assignable integer:=0;
  v_requested integer:=0;
  v_base integer:=0;
  v_remainder integer:=0;
  v_idx integer:=0;
  v_quota integer:=0;
  v_assigned integer:=0;
  v_quotas jsonb:='[]'::jsonb;
  v_blocked jsonb:='{}'::jsonb;
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

  if v_key<>'' then
    if not exists(
      select 1
      from public.aos_audience_presets p
      where p.active=true and p.preset_key=v_key
    ) then
      return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
    end if;
  else
    v_validation:=public.aos_cia_audience_validate_v1(v_filter);
    if not coalesce((v_validation->>'valid')::boolean,false) then
      return jsonb_build_object(
        'ok',false,
        'error','INVALID_AUDIENCE_FILTER',
        'validation',v_validation
      );
    end if;
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

  select
    count(*)::integer,
    count(*) filter(where r.is_assignable)::integer,
    jsonb_build_object(
      'invalid_phone',count(*) filter(where 'PHONE_INVALID'=any(r.reasons)),
      'freshness_unknown',count(*) filter(where 'SEGMENT_FRESHNESS_UNKNOWN'=any(r.reasons)),
      'disqualified',count(*) filter(where 'CURRENTLY_DISQUALIFIED'=any(r.reasons)),
      'province_route',count(*) filter(where 'CURRENT_PROVINCE_ROUTE'=any(r.reasons)),
      'called_today',count(*) filter(where 'CALLED_TODAY'=any(r.reasons)),
      'future_appointment',count(*) filter(where 'FUTURE_APPOINTMENT'=any(r.reasons)),
      'legacy_in_progress',count(*) filter(where 'LEGACY_WORK_IN_PROGRESS'=any(r.reasons))
    )
  into v_audience_count,v_assignable,v_blocked
  from public.aos_cia_call_preview_rows_v1(
    nullif(v_key,''),
    case when v_key='' then v_filter else null end
  ) r;

  v_requested:=case
    when coalesce(p_all_available,false) then v_assignable
    else least(p_source_limit,v_assignable)
  end;

  v_base:=case when v_target_count>0 then floor(v_requested::numeric/v_target_count)::integer else 0 end;
  v_remainder:=v_requested-(v_base*v_target_count);

  for e in
    select x.value,x.ordinality
    from jsonb_array_elements(v_targets) with ordinality x(value,ordinality)
    order by coalesce(nullif(x.value->>'priority','')::integer,(x.ordinality*10)::integer),x.ordinality
  loop
    v_idx:=v_idx+1;
    v_quota:=v_base+case when v_idx<=v_remainder then 1 else 0 end;
    v_assigned:=v_assigned+v_quota;
    v_quotas:=v_quotas||jsonb_build_array(jsonb_build_object(
      'advisor_user_id',e.value->>'advisor_user_id',
      'priority',coalesce(nullif(e.value->>'priority','')::integer,(e.ordinality*10)::integer),
      'projected_quantity',v_quota
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,
    'strategy','EQUAL',
    'quantity_mode',case when coalesce(p_all_available,false) then 'ALL_AVAILABLE' else 'FIXED' end,
    'audience_count',v_audience_count,
    'candidate_count',v_audience_count,
    'assignable_now',v_assignable,
    'requested_count',v_requested,
    'source_limit',case when coalesce(p_all_available,false) then null else p_source_limit end,
    'projected_assigned',v_assigned,
    'remaining_after_plan',greatest(v_assignable-v_assigned,0),
    'target_count',v_target_count,
    'quotas',v_quotas,
    'blocked',v_blocked,
    'policy',jsonb_build_object(
      'channel','CALL',
      'policy_key','CALL_GENERAL',
      'availability_support','FULL'
    ),
    'execution',jsonb_build_object(
      'enabled',false,
      'reason','HUMAN_CANARY_REQUIRED'
    ),
    'source','CIA_CALL_PREVIEW_V1',
    'observed_at',statement_timestamp()
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return jsonb_build_object('ok',false,'error','INVALID_DISTRIBUTION_PAYLOAD');
  when others then
    return jsonb_build_object('ok',false,'error','DISTRIBUTION_PREVIEW_V3_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_distribution_preview_app_v3(text,text,jsonb,integer,boolean,jsonb) from public;
grant execute on function public.aos_cia_distribution_preview_app_v3(text,text,jsonb,integer,boolean,jsonb) to anon,authenticated;


create or replace function public.aos_cia_control_center_app_v7(
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
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_auth jsonb;
  v_uid uuid;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_audience_id uuid;
  v_version integer;
  v_filter jsonb;
  v_audience_count integer:=0;
  v_assignable integer:=0;
  v_blocked jsonb:='{}'::jsonb;
  v_out jsonb;
  v_plan_id uuid;
  v_advisor_id uuid;
  v_rollback jsonb;
begin
  if v_action<>'START_CANARY_ASSIGNMENT' then
    return public.aos_cia_control_center_app_v6(p_app_token,p_action,p_payload);
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

  begin
    v_audience_id:=nullif(v_payload->>'audience_id','')::uuid;
    v_version:=nullif(v_payload->>'version','')::integer;
    v_advisor_id:=nullif(v_payload->>'advisor_user_id','')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_CANARY_PAYLOAD');
  end;

  select v.filter_dsl
    into v_filter
  from public.aos_audiencias a
  join public.aos_audiencia_versiones v
    on v.audiencia_id=a.id
   and v.version=coalesce(v_version,a.current_version)
  where a.id=v_audience_id
    and a.estado='ACTIVE';

  if v_filter is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  select
    count(*)::integer,
    count(*) filter(where r.is_assignable)::integer,
    jsonb_build_object(
      'invalid_phone',count(*) filter(where 'PHONE_INVALID'=any(r.reasons)),
      'freshness_unknown',count(*) filter(where 'SEGMENT_FRESHNESS_UNKNOWN'=any(r.reasons)),
      'disqualified',count(*) filter(where 'CURRENTLY_DISQUALIFIED'=any(r.reasons)),
      'province_route',count(*) filter(where 'CURRENT_PROVINCE_ROUTE'=any(r.reasons)),
      'called_today',count(*) filter(where 'CALLED_TODAY'=any(r.reasons)),
      'future_appointment',count(*) filter(where 'FUTURE_APPOINTMENT'=any(r.reasons)),
      'legacy_in_progress',count(*) filter(where 'LEGACY_WORK_IN_PROGRESS'=any(r.reasons))
    )
  into v_audience_count,v_assignable,v_blocked
  from public.aos_cia_call_preview_rows_v1(null,v_filter) r;

  if v_assignable<1 then
    return jsonb_build_object(
      'ok',false,
      'error','CANARY_NO_ASSIGNABLE_CONTACTS',
      'audience_count',v_audience_count,
      'assignable_now',v_assignable,
      'blocked',v_blocked,
      'routing_unchanged',true
    );
  end if;

  v_out:=public.aos_cia_control_center_app_v6(p_app_token,p_action,p_payload);

  if coalesce((v_out->>'ok')::boolean,false)
     and coalesce((v_out#>>'{plan,source_available_now}')::integer,0)<1 then
    begin
      v_plan_id:=nullif(v_out#>>'{plan,plan_id}','')::uuid;
    exception when others then
      v_plan_id:=null;
    end;

    if v_plan_id is not null and v_advisor_id is not null then
      v_rollback:=public.aos_cia_control_center_app_v6(
        p_app_token,
        'STOP_CANARY_ASSIGNMENT',
        jsonb_build_object(
          'plan_id',v_plan_id,
          'advisor_user_id',v_advisor_id
        )
      );
    end if;

    return jsonb_build_object(
      'ok',false,
      'error','CANARY_NO_ASSIGNABLE_CONTACTS',
      'audience_count',v_audience_count,
      'assignable_now',0,
      'routing_unchanged',true,
      'rollback',coalesce(v_rollback,'{}'::jsonb)
    );
  end if;

  return v_out;
exception when others then
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V7_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v7(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v7(text,text,jsonb) to anon,authenticated;

select pg_notify('pgrst','reload schema');

commit;
