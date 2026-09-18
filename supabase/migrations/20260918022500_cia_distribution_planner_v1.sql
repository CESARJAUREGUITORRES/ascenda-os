-- ASCENDA OS · CIA Distribution Planner V1
-- Safe planning layer for Audience -> Distribution. Execution remains release-gated OFF.

begin;

create table if not exists public.aos_cia_distribution_release_state_v1 (
  channel text primary key,
  stage text not null,
  execution_enabled boolean not null default false,
  max_source_limit integer not null default 1,
  max_advisors integer not null default 1,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default statement_timestamp(),
  constraint aos_cia_distribution_release_stage_chk
    check (stage in ('HUMAN_CANARY_REQUIRED','SINGLE_ADVISOR','LIMITED_ROLLOUT','GENERAL')),
  constraint aos_cia_distribution_release_channel_chk
    check (channel in ('CALL','EMAIL','WHATSAPP')),
  constraint aos_cia_distribution_release_limits_chk
    check (max_source_limit between 1 and 100000 and max_advisors between 1 and 50)
);

insert into public.aos_cia_distribution_release_state_v1(channel,stage,execution_enabled,max_source_limit,max_advisors,metadata)
values
  ('CALL','HUMAN_CANARY_REQUIRED',false,1,1,'{"reason":"PACK_B_HUMAN_CANARY_NOT_EXECUTED"}'::jsonb),
  ('EMAIL','HUMAN_CANARY_REQUIRED',false,1,1,'{"reason":"SHARED_AUDIENCE_SOURCE_ONLY"}'::jsonb),
  ('WHATSAPP','HUMAN_CANARY_REQUIRED',false,1,1,'{"reason":"SHARED_AUDIENCE_SOURCE_ONLY"}'::jsonb)
on conflict(channel) do nothing;

revoke all on table public.aos_cia_distribution_release_state_v1 from public,anon,authenticated;

create or replace function public.aos_cia_control_center_app_v4(
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
  v_action text := upper(btrim(coalesce(p_action,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_auth jsonb;
  v_uid uuid;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_filter jsonb;
  v_validation jsonb;
  v_count_result jsonb;
  v_candidate_count integer := 0;
  v_source_limit integer;
  v_requested integer;
  v_strategy text;
  v_targets jsonb;
  v_target_count integer;
  v_valid_count integer;
  v_distinct_count integer;
  v_sum numeric;
  v_base integer := 0;
  v_remainder integer := 0;
  v_idx integer := 0;
  v_quota integer := 0;
  v_assigned integer := 0;
  v_quotas jsonb := '[]'::jsonb;
  e record;
  v_release jsonb;
begin
  if v_action not in ('DISTRIBUTION_RELEASE_STATE','DISTRIBUTION_PREVIEW') then
    return public.aos_cia_control_center_app_v3(p_app_token,v_action,v_payload);
  end if;

  v_auth := public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_uid := (v_auth->>'user_id')::uuid;
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));

  select coalesce(u.paneles_acceso,'{}'::text[])
    into v_panels
  from public.aos_usuarios u
  where u.id=v_uid and u.activo=true;

  if v_role <> 'ADMIN'
     or v_assurance <> 'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  if jsonb_typeof(v_payload) <> 'object' or pg_column_size(v_payload) > 65536 then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  if v_action='DISTRIBUTION_RELEASE_STATE' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'channel',r.channel,
      'stage',r.stage,
      'execution_enabled',r.execution_enabled,
      'max_source_limit',r.max_source_limit,
      'max_advisors',r.max_advisors,
      'metadata',r.metadata,
      'updated_at',r.updated_at
    ) order by r.channel),'[]'::jsonb)
    into v_release
    from public.aos_cia_distribution_release_state_v1 r;

    return jsonb_build_object(
      'ok',true,
      'channels',v_release,
      'observed_at',statement_timestamp()
    );
  end if;

  v_filter := v_payload->'filter';
  v_strategy := upper(coalesce(v_payload->>'strategy','EQUAL'));
  v_targets := coalesce(v_payload->'targets','[]'::jsonb);

  if v_strategy not in ('EQUAL','PERCENTAGE','FIXED') then
    return jsonb_build_object('ok',false,'error','INVALID_DISTRIBUTION_STRATEGY');
  end if;

  if jsonb_typeof(v_targets) <> 'array' then
    return jsonb_build_object('ok',false,'error','INVALID_TARGETS');
  end if;

  v_target_count := jsonb_array_length(v_targets);
  if v_target_count < 1 or v_target_count > 50 then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET_COUNT');
  end if;

  begin
    v_source_limit := nullif(v_payload->>'source_limit','')::integer;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
  end;

  if v_source_limit is null or v_source_limit < 1 or v_source_limit > 10000 then
    return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
  end if;

  v_validation := public.aos_cia_audience_validate_v1(v_filter);
  if not coalesce((v_validation->>'valid')::boolean,false) then
    return jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_FILTER','validation',v_validation);
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

  if v_distinct_count <> v_target_count then
    return jsonb_build_object('ok',false,'error','DUPLICATE_TARGET');
  end if;
  if v_valid_count <> v_target_count then
    return jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
  end if;

  if v_strategy='PERCENTAGE' then
    if exists(
      select 1
      from jsonb_array_elements(v_targets) x(value)
      where not (x.value ? 'weight_percent')
         or nullif(x.value->>'weight_percent','')::numeric <= 0
         or nullif(x.value->>'weight_percent','')::numeric > 100
    ) then
      return jsonb_build_object('ok',false,'error','INVALID_PERCENTAGE_TARGET');
    end if;
    select round(sum((x.value->>'weight_percent')::numeric),4)
      into v_sum
    from jsonb_array_elements(v_targets) x(value);
    if v_sum <> 100.0000 then
      return jsonb_build_object('ok',false,'error','PERCENTAGES_MUST_SUM_100','sum',v_sum);
    end if;
  end if;

  if v_strategy='FIXED' and exists(
    select 1
    from jsonb_array_elements(v_targets) x(value)
    where not (x.value ? 'fixed_quantity')
       or nullif(x.value->>'fixed_quantity','')::integer < 1
  ) then
    return jsonb_build_object('ok',false,'error','INVALID_FIXED_TARGET');
  end if;

  v_count_result := public.aos_cia_audience_count_v2(v_filter);
  if not coalesce((v_count_result->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error',coalesce(v_count_result->>'error','AUDIENCE_COUNT_FAILED'));
  end if;

  v_candidate_count := coalesce((v_count_result->>'count')::integer,0);
  v_requested := least(v_source_limit,v_candidate_count);

  if v_strategy='EQUAL' then
    v_base := floor(v_requested::numeric/v_target_count)::integer;
    v_remainder := v_requested-(v_base*v_target_count);
  end if;

  for e in
    select x.value, x.ordinality
    from jsonb_array_elements(v_targets) with ordinality x(value,ordinality)
    order by coalesce(nullif(x.value->>'priority','')::integer,(x.ordinality*10)::integer),x.ordinality
  loop
    v_idx := v_idx+1;
    if v_strategy='EQUAL' then
      v_quota := v_base + case when v_idx<=v_remainder then 1 else 0 end;
    elsif v_strategy='PERCENTAGE' then
      v_quota := floor(v_requested*((e.value->>'weight_percent')::numeric/100.0))::integer;
    else
      v_quota := least((e.value->>'fixed_quantity')::integer,greatest(v_requested-v_assigned,0));
    end if;

    if v_strategy='PERCENTAGE' and v_idx=v_target_count then
      v_quota := greatest(v_requested-v_assigned,0);
    end if;

    v_quota := greatest(least(v_quota,greatest(v_requested-v_assigned,0)),0);
    v_assigned := v_assigned+v_quota;

    v_quotas := v_quotas || jsonb_build_array(jsonb_build_object(
      'advisor_user_id',e.value->>'advisor_user_id',
      'priority',coalesce(nullif(e.value->>'priority','')::integer,(e.ordinality*10)::integer),
      'projected_quantity',v_quota,
      'weight_percent',case when v_strategy='PERCENTAGE' then (e.value->>'weight_percent')::numeric else null end,
      'fixed_quantity',case when v_strategy='FIXED' then (e.value->>'fixed_quantity')::integer else null end
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,
    'strategy',v_strategy,
    'candidate_count',v_candidate_count,
    'source_limit',v_source_limit,
    'projected_assigned',v_assigned,
    'unallocated',greatest(v_requested-v_assigned,0),
    'target_count',v_target_count,
    'quotas',v_quotas,
    'execution',jsonb_build_object(
      'enabled',false,
      'reason','HUMAN_CANARY_REQUIRED'
    ),
    'observed_at',statement_timestamp()
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return jsonb_build_object('ok',false,'error','INVALID_DISTRIBUTION_PAYLOAD');
  when others then
    return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V4_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v4(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v4(text,text,jsonb) to anon,authenticated;

comment on function public.aos_cia_control_center_app_v4(text,text,jsonb)
is 'CIA Distribution Planner V1. Adds read-only release state and multi-advisor distribution projection. All existing behavior delegates to V3. No bulk execution action exists.';

select pg_notify('pgrst','reload schema');

commit;
