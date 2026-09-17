begin;

create or replace function public.aos_cia_control_center_app_v1(
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
  v_auth jsonb;
  v_uid uuid;
  v_name text;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_action text := upper(btrim(coalesce(p_action,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_session jsonb;
  v_cia_token text;
  v_out jsonb;
  v_activation jsonb;
  v_plan jsonb;
  v_route jsonb;
  v_activation_id uuid;
  v_plan_id uuid;
  v_advisor_id uuid;
  v_audience_id uuid;
  v_version integer;
  v_source_limit integer;
  v_key text;
begin
  v_auth := public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  v_uid := (v_auth->>'user_id')::uuid;
  v_name := coalesce(v_auth->>'nombre','');
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels from public.aos_usuarios u where u.id=v_uid and u.activo=true;
  if v_role <> 'ADMIN' or v_assurance <> 'PASSWORD_2FA' or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;
  if jsonb_typeof(v_payload) <> 'object' or pg_column_size(v_payload) > 65536 then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  v_session := public.aos_cia_issue_admin_session_v1(v_name);
  if not coalesce((v_session->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','CIA_SESSION_EXCHANGE_FAILED'); end if;
  v_cia_token := v_session->>'token';

  if v_action in ('BOOTSTRAP','VALIDATE','COUNT','PREVIEW','EXPLAIN','LIST_AUDIENCES','GET_AUDIENCE','CREATE_AUDIENCE','UPDATE_AUDIENCE','ARCHIVE_AUDIENCE','RESTORE_AUDIENCE','DUPLICATE_AUDIENCE') then
    v_out := public.aos_cia_admin_gateway_v1(v_cia_token,v_action,v_payload);
    if v_action='BOOTSTRAP' and coalesce((v_out->>'ok')::boolean,false) then
      v_out := v_out || jsonb_build_object(
        'advisors',public.aos_cia_assignment_advisors_v1(),
        'routing',public.aos_cia_call_routing_admin_v1(v_cia_token,'GET_STATUS','{}'::jsonb),
        'ux',jsonb_build_object('preview_page_size',25,'count_mode','EXPLICIT_APPLY','single_flight',true,'cancel_stale',true)
      );
    end if;
  elsif v_action='CANARY_PRECHECK' then
    v_out := jsonb_build_object(
      'ok',true,
      'routing',public.aos_cia_call_routing_admin_v1(v_cia_token,'GET_STATUS','{}'::jsonb),
      'advisors',public.aos_cia_assignment_advisors_v1(),
      'queue_config',public.aos_cia_queue_config_list_admin_v1(p_app_token),
      'f11',public.aos_cia_advisor_control_f11_readiness_v1(),
      'f12',public.aos_cia_call_routing_f12_readiness_v1(),
      'observed_at',statement_timestamp()
    );
  elsif v_action='START_CANARY_ASSIGNMENT' then
    begin
      v_audience_id := nullif(v_payload->>'audience_id','')::uuid;
      v_version := nullif(v_payload->>'version','')::integer;
      v_advisor_id := nullif(v_payload->>'advisor_user_id','')::uuid;
      v_source_limit := greatest(1,least(coalesce(nullif(v_payload->>'source_limit','')::integer,1),5));
    exception when others then v_out := jsonb_build_object('ok',false,'error','INVALID_CANARY_PAYLOAD'); end;
    if v_out is null then
      if not exists(select 1 from public.aos_usuarios u where u.id=v_advisor_id and u.activo=true and lower(coalesce(u.rol,''))='asesor') then
        v_out := jsonb_build_object('ok',false,'error','INVALID_ADVISOR');
      else
        v_activation := public.aos_cia_activation_create_admin_v1(v_cia_token,v_audience_id,v_version,left(coalesce(nullif(v_payload->>'name',''),'Canary Call Center'),120),'HUMAN_CANARY_PACK_B','CALL','BATCH',true,jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid));
        if not coalesce((v_activation->>'ok')::boolean,false) then v_out := v_activation;
        else
          v_activation_id := (v_activation->>'activation_id')::uuid;
          v_key := 'pack-b-canary-'||v_activation_id::text;
          v_plan := public.aos_cia_assignment_plan_create_admin_v1(v_cia_token,v_activation_id,'ONE',jsonb_build_array(jsonb_build_object('advisor_user_id',v_advisor_id)),'ACTIVATION',v_source_limit,480,120,'NONE',null,true,true,v_key,jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid));
          if not coalesce((v_plan->>'ok')::boolean,false) then perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL'); v_out := v_plan;
          else
            v_plan_id := (v_plan->>'plan_id')::uuid;
            v_plan := public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'ACTIVATE');
            if not coalesce((v_plan->>'ok')::boolean,false) then perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL'); v_out := v_plan;
            else
              v_route := public.aos_cia_call_routing_admin_v1(v_cia_token,'SET_GLOBAL',jsonb_build_object('enabled',true,'metadata',jsonb_build_object('pack','B','canary',1)));
              if coalesce((v_route->>'ok')::boolean,false) then v_route := public.aos_cia_call_routing_admin_v1(v_cia_token,'SET_ADVISOR',jsonb_build_object('advisor_user_id',v_advisor_id,'mode','V3_CANARY','metadata',jsonb_build_object('pack','B','canary',1))); end if;
              v_out := jsonb_build_object('ok',coalesce((v_route->>'ok')::boolean,false),'activation',v_activation,'plan',v_plan,'routing',v_route,'source_limit',v_source_limit,'instruction','HUMAN_CANARY_NOW_OPEN_CALL_CENTER_AS_SELECTED_ADVISOR');
            end if;
          end if;
        end if;
      end if;
    end if;
  elsif v_action='CANARY_READBACK' then
    begin
      v_plan_id := nullif(v_payload->>'plan_id','')::uuid;
      v_advisor_id := nullif(v_payload->>'advisor_user_id','')::uuid;
      v_out := jsonb_build_object(
        'ok',true,
        'plan',public.aos_cia_assignment_plan_summary_v1(v_plan_id),
        'assignments',public.aos_cia_assignment_list_v1(v_plan_id,v_advisor_id,null,25,0),
        'advisor_work',public.aos_cia_advisor_work_list_v1((select u.nombre from public.aos_usuarios u where u.id=v_advisor_id),(select u.codigo_asesor from public.aos_usuarios u where u.id=v_advisor_id),'ALL',25,0),
        'routing',public.aos_cia_call_routing_admin_v1(v_cia_token,'GET_STATUS','{}'::jsonb)
      );
    exception when others then v_out := jsonb_build_object('ok',false,'error','INVALID_READBACK_PAYLOAD'); end;
  else v_out := jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED'); end if;

  update public.aos_cia_admin_sessions set revoked=true where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
  return coalesce(v_out,jsonb_build_object('ok',false,'error','EMPTY_RESULT'));
exception when others then
  if v_cia_token is not null then update public.aos_cia_admin_sessions set revoked=true where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex'); end if;
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v1(text,text,jsonb) to anon, authenticated, service_role;

drop policy if exists aos_cola_config_all on public.aos_cola_config;
revoke insert, update, delete, truncate, references, trigger on table public.aos_cola_config from anon, authenticated;
revoke select on table public.aos_cola_config from anon, authenticated;

commit;
