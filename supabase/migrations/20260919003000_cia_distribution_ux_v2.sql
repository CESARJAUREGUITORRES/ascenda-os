-- ASCENDA OS · CIA Distribution UX V2
-- Product improvement: arbitrary planning quantity up to the audience size, including "all available".
-- Planning remains read-only. Bulk execution remains fail-closed.

begin;

create or replace function public.aos_cia_control_center_app_v6(
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
  v_filter jsonb;
  v_validation jsonb;
  v_targets jsonb;
  v_target_count integer;
  v_valid_count integer;
  v_distinct_count integer;
  v_count_result jsonb;
  v_candidate_count integer:=0;
  v_requested integer:=0;
  v_source_limit integer:=0;
  v_all_available boolean:=false;
  v_base integer:=0;
  v_remainder integer:=0;
  v_idx integer:=0;
  v_quota integer:=0;
  v_assigned integer:=0;
  v_quotas jsonb:='[]'::jsonb;
  e record;
begin
  if v_action<>'DISTRIBUTION_PREVIEW' then
    return public.aos_cia_control_center_app_v5(p_app_token,v_action,v_payload);
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

  if jsonb_typeof(v_payload)<>'object' or pg_column_size(v_payload)>65536 then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  if upper(coalesce(v_payload->>'strategy','EQUAL'))<>'EQUAL' then
    return public.aos_cia_control_center_app_v5(p_app_token,v_action,v_payload);
  end if;

  v_filter:=v_payload->'filter';
  v_targets:=coalesce(v_payload->'targets','[]'::jsonb);
  v_all_available:=coalesce((v_payload->>'all_available')::boolean,false);

  if jsonb_typeof(v_targets)<>'array' then
    return jsonb_build_object('ok',false,'error','INVALID_TARGETS');
  end if;

  v_target_count:=jsonb_array_length(v_targets);
  if v_target_count<1 or v_target_count>50 then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET_COUNT');
  end if;

  if not v_all_available then
    begin
      v_source_limit:=nullif(v_payload->>'source_limit','')::integer;
    exception when others then
      return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
    end;
    if v_source_limit is null or v_source_limit<1 or v_source_limit>100000 then
      return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
    end if;
  end if;

  v_validation:=public.aos_cia_audience_validate_v1(v_filter);
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

  if v_distinct_count<>v_target_count then
    return jsonb_build_object('ok',false,'error','DUPLICATE_TARGET');
  end if;
  if v_valid_count<>v_target_count then
    return jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
  end if;

  v_count_result:=public.aos_cia_audience_count_v2(v_filter);
  if not coalesce((v_count_result->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error',coalesce(v_count_result->>'error','AUDIENCE_COUNT_FAILED'));
  end if;

  v_candidate_count:=coalesce((v_count_result->>'count')::integer,0);
  v_requested:=case
    when v_all_available then v_candidate_count
    else least(v_source_limit,v_candidate_count)
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

    v_quotas:=v_quotas || jsonb_build_array(jsonb_build_object(
      'advisor_user_id',e.value->>'advisor_user_id',
      'priority',coalesce(nullif(e.value->>'priority','')::integer,(e.ordinality*10)::integer),
      'projected_quantity',v_quota
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,
    'strategy','EQUAL',
    'quantity_mode',case when v_all_available then 'ALL_AVAILABLE' else 'FIXED' end,
    'candidate_count',v_candidate_count,
    'requested_count',v_requested,
    'source_limit',case when v_all_available then null else v_source_limit end,
    'projected_assigned',v_assigned,
    'remaining_after_plan',greatest(v_candidate_count-v_assigned,0),
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
    return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V6_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v6(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v6(text,text,jsonb) to anon,authenticated;

comment on function public.aos_cia_control_center_app_v6(text,text,jsonb)
is 'CIA Distribution UX V2. Read-only EQUAL planning accepts arbitrary quantity up to audience size or all available. All other actions delegate to V5.';

select pg_notify('pgrst','reload schema');

commit;
