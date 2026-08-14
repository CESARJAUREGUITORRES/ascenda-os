-- ASCENDA OS CIA V3 — Phase 15 ADMIN read surface + F16 output handshake

create or replace function public.aos_cia_kronia_f16_readiness_v1()
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_f15 jsonb;
  v_tools integer:=0;
  v_agents integer:=0;
  v_bad_tools integer:=0;
  v_bad_agents integer:=0;
  v_missing_allowed integer:=0;
  v_auto_calls integer:=0;
  v_auto_props integer:=0;
  v_success_calls integer:=0;
  v_policy_release jsonb;
  v_policy_auto jsonb;
  v_direct_anon boolean:=false;
  v_direct_auth boolean:=false;
  v_legacy_guard boolean:=false;
  v_task_mut_anon boolean:=false;
  v_task_mut_auth boolean:=false;
  v_ready boolean;
  v_status text;
begin
  v_f15:=public.aos_cia_intelligence_f15_readiness_v1();
  select count(*)::integer into v_tools from public.aos_cia_kronia_tool_registry where active;
  select count(*)::integer into v_agents from public.aos_cia_kronia_agent_registry where active;
  select count(*)::integer into v_bad_tools from public.aos_cia_kronia_tool_registry where active and (operation_class not in ('READ','PROPOSE') or upper(tool_key) like '%RAW_SQL%' or upper(coalesce(request_type,'')) in ('RAW_SQL','AUTO_APPROVE','AUTO_ASSIGN','TRANSFER_ASSIGNMENT'));
  select count(*)::integer into v_bad_agents from public.aos_cia_kronia_agent_registry where active and execution_mode<>'SHADOW';
  select count(*)::integer into v_missing_allowed
  from public.aos_cia_kronia_agent_registry a, lateral unnest(a.allowed_tools) x(tool_key)
  where a.active and not exists(select 1 from public.aos_cia_kronia_tool_registry t where t.tool_key=x.tool_key and t.active);
  select count(*) filter(where status='SUCCEEDED')::integer,count(*) filter(where auto_execute)::integer
    into v_success_calls,v_auto_calls from public.aos_cia_kronia_tool_calls;
  select count(*) filter(where auto_execute)::integer into v_auto_props from public.aos_cia_kronia_proposals;

  v_policy_release:=public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT');
  v_policy_auto:=public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','AUTO_ASSIGN');

  v_direct_anon :=
    has_table_privilege('anon','public.aos_cia_kronia_tool_registry','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_tool_registry','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_tool_registry','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_tool_registry','DELETE') or
    has_table_privilege('anon','public.aos_cia_kronia_agent_registry','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_agent_registry','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_agent_registry','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_agent_registry','DELETE') or
    has_table_privilege('anon','public.aos_cia_kronia_agent_runs','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_agent_runs','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_agent_runs','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_agent_runs','DELETE') or
    has_table_privilege('anon','public.aos_cia_kronia_tool_calls','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_tool_calls','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_tool_calls','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_tool_calls','DELETE') or
    has_table_privilege('anon','public.aos_cia_kronia_proposals','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_proposals','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_proposals','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_proposals','DELETE') or
    has_table_privilege('anon','public.aos_cia_kronia_proposal_events','SELECT') or has_table_privilege('anon','public.aos_cia_kronia_proposal_events','INSERT') or has_table_privilege('anon','public.aos_cia_kronia_proposal_events','UPDATE') or has_table_privilege('anon','public.aos_cia_kronia_proposal_events','DELETE');
  v_direct_auth :=
    has_table_privilege('authenticated','public.aos_cia_kronia_tool_registry','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_registry','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_registry','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_registry','DELETE') or
    has_table_privilege('authenticated','public.aos_cia_kronia_agent_registry','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_registry','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_registry','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_registry','DELETE') or
    has_table_privilege('authenticated','public.aos_cia_kronia_agent_runs','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_runs','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_runs','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_agent_runs','DELETE') or
    has_table_privilege('authenticated','public.aos_cia_kronia_tool_calls','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_calls','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_calls','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_tool_calls','DELETE') or
    has_table_privilege('authenticated','public.aos_cia_kronia_proposals','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_proposals','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_proposals','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_proposals','DELETE') or
    has_table_privilege('authenticated','public.aos_cia_kronia_proposal_events','SELECT') or has_table_privilege('authenticated','public.aos_cia_kronia_proposal_events','INSERT') or has_table_privilege('authenticated','public.aos_cia_kronia_proposal_events','UPDATE') or has_table_privilege('authenticated','public.aos_cia_kronia_proposal_events','DELETE');

  v_legacy_guard := coalesce(obj_description('public.aos_execute_agent_query(text)'::regprocedure,'pg_proc'),'') like 'LEGACY F15_CONFIG_ALLOWLIST_V1:%';
  v_task_mut_anon := has_table_privilege('anon','public.aos_agente_tareas','INSERT') or has_table_privilege('anon','public.aos_agente_tareas','UPDATE') or has_table_privilege('anon','public.aos_agente_tareas','DELETE');
  v_task_mut_auth := has_table_privilege('authenticated','public.aos_agente_tareas','INSERT') or has_table_privilege('authenticated','public.aos_agente_tareas','UPDATE') or has_table_privilege('authenticated','public.aos_agente_tareas','DELETE');

  v_ready := coalesce((v_f15->>'ready_for_f15')::boolean,false)
    and v_tools>=6 and v_agents>=6 and v_bad_tools=0 and v_bad_agents=0 and v_missing_allowed=0
    and v_auto_calls=0 and v_auto_props=0 and not v_direct_anon and not v_direct_auth
    and coalesce(v_policy_release->>'decision','')='REQUIRE_APPROVAL' and coalesce((v_policy_release->>'auto_execute')::boolean,false)=false
    and coalesce(v_policy_auto->>'decision','')='BLOCK'
    and v_legacy_guard and not v_task_mut_anon and not v_task_mut_auth;
  v_status:=case when not coalesce((v_f15->>'ready_for_f15')::boolean,false) then 'BLOCKED_F14'
    when not v_ready then 'BLOCKED_INTEGRITY'
    when v_success_calls=0 then 'READY_GOVERNED_NO_SMOKE'
    else 'READY_GOVERNED_ORCHESTRATION' end;

  return jsonb_build_object(
    'ok',v_ready,'ready_for_f16',v_ready,'status',v_status,'mode','GOVERNED_SHADOW',
    'registry',jsonb_build_object('active_tools',v_tools,'active_agents',v_agents,'bad_tools',v_bad_tools,'bad_agents',v_bad_agents,'missing_allowed_tools',v_missing_allowed),
    'audit',jsonb_build_object('successful_tool_calls',v_success_calls,'auto_execute_calls',v_auto_calls,'auto_execute_proposals',v_auto_props),
    'browser_direct_table_access',jsonb_build_object('anon',v_direct_anon,'authenticated',v_direct_auth),
    'legacy_compatibility_guard',jsonb_build_object('config_allowlist',v_legacy_guard,'task_mutation_anon',v_task_mut_anon,'task_mutation_authenticated',v_task_mut_auth),
    'policy_release_assignment',v_policy_release,'policy_auto_assign',v_policy_auto,
    'f14_readiness',v_f15,
    'next_phase_note','F16 Email Integration must consume central Audience/Activation + governed F15 context. F15 preview never sends email; no clinical feature use, autoapprove, autoexecute or autoassign.');
end $$;

create or replace function public.aos_cia_kronia_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_auth jsonb;
  v_action text:=upper(trim(coalesce(p_action,'')));
  v_limit integer:=greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
  v_items jsonb;
  v_rec uuid;
  v_agent text;
  v_tool text;
  v_result jsonb;
begin
  v_auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  if v_action='READINESS' then return public.aos_cia_kronia_f16_readiness_v1();
  elsif v_action='SUMMARY' then
    return jsonb_build_object('ok',true,'mode','GOVERNED_SHADOW',
      'tools',(select count(*) from public.aos_cia_kronia_tool_registry where active),
      'agents',(select count(*) from public.aos_cia_kronia_agent_registry where active),
      'runs',(select count(*) from public.aos_cia_kronia_agent_runs),
      'tool_calls',(select count(*) from public.aos_cia_kronia_tool_calls),
      'proposals',(select count(*) from public.aos_cia_kronia_proposals),
      'readiness',public.aos_cia_kronia_f16_readiness_v1());
  elsif v_action='TOOLS' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.tool_key,x.version),'[]'::jsonb) into v_items from (
      select tool_key,version,display_name,description,operation_class,risk_class,request_type,input_schema,output_schema,active from public.aos_cia_kronia_tool_registry order by tool_key,version desc limit v_limit) x;
    return jsonb_build_object('ok',true,'items',v_items);
  elsif v_action='AGENTS' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.agent_key,x.version),'[]'::jsonb) into v_items from (
      select agent_key,version,display_name,purpose,agent_class,allowed_tools,execution_mode,active,metadata from public.aos_cia_kronia_agent_registry order by agent_key,version desc limit v_limit) x;
    return jsonb_build_object('ok',true,'items',v_items);
  elsif v_action='RUNS' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items from (
      select id,correlation_id,recommendation_id,orchestrator_agent_key,status,provenance,started_at,completed_at,created_at from public.aos_cia_kronia_agent_runs order by created_at desc limit v_limit) x;
    return jsonb_build_object('ok',true,'items',v_items);
  elsif v_action='PROPOSALS' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items from (
      select id,run_id,recommendation_id,agent_key,tool_key,request_type,assignment_id,advisor_user_id,policy_decision,state,auto_execute,created_at from public.aos_cia_kronia_proposals order by created_at desc limit v_limit) x;
    return jsonb_build_object('ok',true,'items',v_items);
  elsif v_action='DRY_RUN' then
    v_agent:=lower(trim(coalesce(nullif(p_payload->>'agent_key',''),'kronia')));
    v_tool:=lower(trim(coalesce(p_payload->>'tool_key','')));
    if v_tool='' then return jsonb_build_object('ok',false,'error','TOOL_REQUIRED'); end if;
    if nullif(p_payload->>'recommendation_id','') is not null then
      begin v_rec:=(p_payload->>'recommendation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_RECOMMENDATION_ID'); end;
    end if;
    v_result:=public.aos_cia_kronia_tool_invoke_v1(v_agent,v_tool,v_rec,coalesce(p_payload->'input','{}'::jsonb),null);
    return v_result||jsonb_build_object('admin_user_id',v_auth->>'user_id','operational_execution',false);
  end if;
  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end $$;

revoke all on function public.aos_cia_kronia_f16_readiness_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_kronia_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_kronia_admin_gateway_v1(text,text,jsonb) to anon,authenticated;
