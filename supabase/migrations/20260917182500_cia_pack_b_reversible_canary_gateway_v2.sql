-- CIA-PANEL PACK-B · reversible Human Canary gateway V2
-- Additive over V1. Non-canary actions delegate to V1.

create or replace function public.aos_cia_control_center_app_v2(
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
  v_name text;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_session jsonb;
  v_cia_token text;
  v_out jsonb;
  v_activation jsonb;
  v_plan jsonb;
  v_advisor_route jsonb;
  v_global_route jsonb;
  v_activation_id uuid;
  v_plan_id uuid;
  v_advisor_id uuid;
  v_audience_id uuid;
  v_version integer;
  v_requested_limit integer;
  v_key text;
  v_plan_state text;
  v_activation_state text;
  v_plan_meta jsonb;
begin
  if v_action not in ('START_CANARY_ASSIGNMENT','STOP_CANARY_ASSIGNMENT') then
    return public.aos_cia_control_center_app_v1(p_app_token,v_action,v_payload);
  end if;

  v_auth := public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_uid := (v_auth->>'user_id')::uuid;
  v_name := coalesce(v_auth->>'nombre','');
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels
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

  v_session := public.aos_cia_issue_admin_session_v1(v_name);
  if not coalesce((v_session->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','CIA_SESSION_EXCHANGE_FAILED');
  end if;
  v_cia_token := v_session->>'token';

  if v_action='START_CANARY_ASSIGNMENT' then
    begin
      v_audience_id := nullif(v_payload->>'audience_id','')::uuid;
      v_version := nullif(v_payload->>'version','')::integer;
      v_advisor_id := nullif(v_payload->>'advisor_user_id','')::uuid;
      v_requested_limit := coalesce(nullif(v_payload->>'source_limit','')::integer,1);
    exception when others then
      v_out := jsonb_build_object('ok',false,'error','INVALID_CANARY_PAYLOAD');
    end;

    if v_out is null and v_requested_limit <> 1 then
      v_out := jsonb_build_object('ok',false,'error','CANARY_SOURCE_LIMIT_MUST_BE_ONE');
    end if;

    if v_out is null and exists(
      select 1
      from public.aos_cia_assignment_plans p
      where p.state in ('DRAFT','ACTIVE','PAUSED')
        and p.metadata @> jsonb_build_object('pack','B','canary',1)
    ) then
      v_out := jsonb_build_object('ok',false,'error','CANARY_ALREADY_ACTIVE');
    end if;

    if v_out is null and (
      coalesce((select c.global_enabled from public.aos_cia_call_routing_control c where c.id=1),false)
      or exists(select 1 from public.aos_cia_call_routing_advisors r where r.mode <> 'V2_ONLY')
    ) then
      v_out := jsonb_build_object('ok',false,'error','ROUTING_NOT_BASELINE');
    end if;

    if v_out is null and not exists(
      select 1
      from public.aos_usuarios u
      where u.id=v_advisor_id
        and u.activo=true
        and lower(coalesce(u.rol,''))='asesor'
        and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
    ) then
      v_out := jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
    end if;

    if v_out is null then
      v_activation := public.aos_cia_activation_create_admin_v1(
        v_cia_token,v_audience_id,v_version,
        left(coalesce(nullif(v_payload->>'name',''),'PACK-B Human Canary #1'),120),
        'HUMAN_CANARY_PACK_B','CALL','BATCH',true,
        jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid,'reversible',true)
      );
      if not coalesce((v_activation->>'ok')::boolean,false) then
        v_out := v_activation;
      else
        v_activation_id := (v_activation->>'activation_id')::uuid;
        v_key := 'pack-b-canary-'||v_activation_id::text;
        v_plan := public.aos_cia_assignment_plan_create_admin_v1(
          v_cia_token,v_activation_id,'ONE',
          jsonb_build_array(jsonb_build_object('advisor_user_id',v_advisor_id)),
          'ACTIVATION',1,480,120,'NONE',null,true,true,v_key,
          jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid,'reversible',true)
        );
        if not coalesce((v_plan->>'ok')::boolean,false) then
          perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
          v_out := v_plan;
        else
          v_plan_id := (v_plan->>'plan_id')::uuid;
          v_plan := public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'ACTIVATE');
          if not coalesce((v_plan->>'ok')::boolean,false) then
            perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
            perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
            v_out := v_plan;
          else
            -- Arm only the selected advisor while global routing is still OFF.
            v_advisor_route := public.aos_cia_call_routing_admin_v1(
              v_cia_token,'SET_ADVISOR',
              jsonb_build_object(
                'advisor_user_id',v_advisor_id,
                'mode','V3_CANARY',
                'metadata',jsonb_build_object('pack','B','canary',1,'plan_id',v_plan_id)
              )
            );
            if not coalesce((v_advisor_route->>'ok')::boolean,false) then
              perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
              perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
              v_out := v_advisor_route;
            else
              -- Only after the advisor route is ready do we enable the global V3 router.
              v_global_route := public.aos_cia_call_routing_admin_v1(
                v_cia_token,'SET_GLOBAL',
                jsonb_build_object('enabled',true,'metadata',jsonb_build_object('pack','B','canary',1,'plan_id',v_plan_id))
              );
              if not coalesce((v_global_route->>'ok')::boolean,false) then
                perform public.aos_cia_call_routing_admin_v1(v_cia_token,'CLEAR_ADVISOR',jsonb_build_object('advisor_user_id',v_advisor_id));
                perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
                perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
                v_out := v_global_route;
              else
                v_out := jsonb_build_object(
                  'ok',true,
                  'activation',v_activation,
                  'plan',v_plan,
                  'routing',jsonb_build_object('advisor',v_advisor_route,'global',v_global_route),
                  'source_limit',1,
                  'reversible',true,
                  'instruction','HUMAN_CANARY_NOW_OPEN_CALL_CENTER_AS_SELECTED_ADVISOR'
                );
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;

  elsif v_action='STOP_CANARY_ASSIGNMENT' then
    begin
      v_plan_id := nullif(v_payload->>'plan_id','')::uuid;
      v_advisor_id := nullif(v_payload->>'advisor_user_id','')::uuid;
    exception when others then
      v_out := jsonb_build_object('ok',false,'error','INVALID_CANARY_STOP_PAYLOAD');
    end;

    if v_out is null then
      select p.activation_id,p.state,p.metadata
      into v_activation_id,v_plan_state,v_plan_meta
      from public.aos_cia_assignment_plans p
      where p.id=v_plan_id;

      if v_activation_id is null
         or not coalesce(v_plan_meta,'{}'::jsonb) @> jsonb_build_object('pack','B','canary',1)
         or not exists(
           select 1 from public.aos_cia_assignment_targets t
           where t.plan_id=v_plan_id and t.advisor_user_id=v_advisor_id
         ) then
        v_out := jsonb_build_object('ok',false,'error','CANARY_PLAN_MISMATCH');
      end if;
    end if;

    if v_out is null then
      -- Fail closed first: global router OFF before any cleanup work.
      v_global_route := public.aos_cia_call_routing_admin_v1(
        v_cia_token,'SET_GLOBAL',
        jsonb_build_object('enabled',false,'metadata',jsonb_build_object('pack','B','canary',1,'rollback',true,'plan_id',v_plan_id))
      );
      v_advisor_route := public.aos_cia_call_routing_admin_v1(
        v_cia_token,'CLEAR_ADVISOR',jsonb_build_object('advisor_user_id',v_advisor_id)
      );

      if v_plan_state in ('DRAFT','ACTIVE','PAUSED') then
        v_plan := public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
      else
        v_plan := jsonb_build_object('ok',true,'plan_id',v_plan_id,'state',v_plan_state,'noop',true);
      end if;

      select s.estado into v_activation_state
      from public.aos_audiencia_activacion_estado s
      where s.activacion_id=v_activation_id;
      if v_activation_state in ('DRAFT','ACTIVE','PAUSED') then
        v_activation := public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
      else
        v_activation := jsonb_build_object('ok',true,'activation_id',v_activation_id,'state',v_activation_state,'noop',true);
      end if;

      v_out := jsonb_build_object(
        'ok',coalesce((v_global_route->>'ok')::boolean,false)
             and coalesce((v_advisor_route->>'ok')::boolean,false)
             and coalesce((v_plan->>'ok')::boolean,false)
             and coalesce((v_activation->>'ok')::boolean,false),
        'routing_global',v_global_route,
        'routing_advisor',v_advisor_route,
        'plan',v_plan,
        'activation',v_activation,
        'reverted_to_v2',true
      );
    end if;
  end if;

  update public.aos_cia_admin_sessions
  set revoked=true
  where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
  return coalesce(v_out,jsonb_build_object('ok',false,'error','EMPTY_RESULT'));
exception when others then
  if v_cia_token is not null then
    update public.aos_cia_admin_sessions
    set revoked=true
    where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
  end if;
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V2_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v2(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v2(text,text,jsonb) to anon, authenticated;

comment on function public.aos_cia_control_center_app_v2(text,text,jsonb)
is 'CIA PACK-B reversible Control Center gateway: all normal actions delegate to V1; Human Canary start/stop is one-contact, fail-closed and reversible.';

select pg_notify('pgrst','reload schema');
