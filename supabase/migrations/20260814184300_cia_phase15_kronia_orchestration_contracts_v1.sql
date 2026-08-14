-- ASCENDA OS CIA V3 — Phase 15 governed orchestration contracts

create or replace function public.aos_cia_kronia_tool_invoke_v1(
  p_agent_key text,
  p_tool_key text,
  p_recommendation_id uuid default null,
  p_input jsonb default '{}'::jsonb,
  p_correlation_id uuid default null
) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_input_ready jsonb;
  v_agent record;
  v_tool record;
  v_rec record;
  v_assignment record;
  v_run uuid;
  v_corr uuid:=coalesce(p_correlation_id,gen_random_uuid());
  v_output jsonb:='{}'::jsonb;
  v_policy jsonb:='{}'::jsonb;
  v_call_status text:='SUCCEEDED';
  v_run_status text:='COMPLETED';
  v_prop uuid;
  v_reason text:=left(btrim(coalesce(p_input->>'reason','F15 governed intelligence proposal')),500);
  v_duration numeric(12,3);
begin
  v_input_ready:=public.aos_cia_intelligence_f15_readiness_v1();
  if coalesce((v_input_ready->>'ready_for_f15')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','F14_NOT_READY','readiness',v_input_ready);
  end if;

  select a.* into v_agent from public.aos_cia_kronia_agent_registry a
  where a.agent_key=lower(trim(coalesce(p_agent_key,''))) and a.active
  order by a.version desc limit 1;
  if v_agent.agent_key is null then return jsonb_build_object('ok',false,'error','AGENT_NOT_FOUND'); end if;
  if v_agent.execution_mode<>'SHADOW' then return jsonb_build_object('ok',false,'error','AGENT_NOT_SHADOW'); end if;

  select t.* into v_tool from public.aos_cia_kronia_tool_registry t
  where t.tool_key=lower(trim(coalesce(p_tool_key,''))) and t.active
  order by t.version desc limit 1;
  if v_tool.tool_key is null then return jsonb_build_object('ok',false,'error','TOOL_NOT_FOUND'); end if;
  if not (v_tool.tool_key = any(v_agent.allowed_tools)) then
    return jsonb_build_object('ok',false,'error','TOOL_NOT_ALLOWED_FOR_AGENT','agent_key',v_agent.agent_key,'tool_key',v_tool.tool_key);
  end if;

  if v_tool.tool_key in ('intelligence.get','intelligence.explain','proposal.release','f16.email.context.preview') then
    if p_recommendation_id is null then return jsonb_build_object('ok',false,'error','RECOMMENDATION_REQUIRED'); end if;
    select r.* into v_rec from public.aos_cia_intelligence_recommendations r where r.id=p_recommendation_id and r.state='SHADOW';
    if v_rec.id is null then return jsonb_build_object('ok',false,'error','RECOMMENDATION_NOT_FOUND'); end if;
  elsif p_recommendation_id is not null then
    select r.* into v_rec from public.aos_cia_intelligence_recommendations r where r.id=p_recommendation_id and r.state='SHADOW';
    if v_rec.id is null then return jsonb_build_object('ok',false,'error','RECOMMENDATION_NOT_FOUND'); end if;
  end if;

  insert into public.aos_cia_kronia_agent_runs(correlation_id,recommendation_id,orchestrator_agent_key,status,input_context,provenance)
  values(v_corr,p_recommendation_id,v_agent.agent_key,'STARTED',jsonb_build_object('tool_key',v_tool.tool_key),jsonb_build_object('phase','F15','mode','SHADOW','f14_run_id',v_input_ready->>'latest_run_id','policy_gate','F13_V1'))
  returning id into v_run;

  if v_tool.tool_key='intelligence.get' then
    v_output:=jsonb_build_object(
      'recommendation_id',v_rec.id,'opportunity_type',v_rec.opportunity_type,'priority_score',v_rec.priority_score,
      'confidence',v_rec.confidence,'sample_size',v_rec.sample_size,'freshness_status',v_rec.freshness_status,
      'assignment_present',(v_rec.assignment_id is not null),'advisor_present',(v_rec.advisor_user_id is not null),
      'state',v_rec.state,'authority','NONE_SHADOW_ONLY');

  elsif v_tool.tool_key='intelligence.explain' then
    v_output:=jsonb_build_object(
      'recommendation_id',v_rec.id,'evidence',v_rec.evidence,'explanation',v_rec.explanation,
      'observed_affinity',v_rec.observed_affinity,'freshness_status',v_rec.freshness_status,
      'limitations',jsonb_build_array('Recommendation is not authority.','No clinical notes/photos/diagnoses are exposed by this tool.','No autoassign/approve/execute.'));

  elsif v_tool.tool_key='policy.release.probe' then
    v_policy:=public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT');
    v_output:=jsonb_build_object('policy',v_policy,'executed',false);

  elsif v_tool.tool_key='policy.auto_assign.probe' then
    v_policy:=public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','AUTO_ASSIGN');
    v_output:=jsonb_build_object('policy',v_policy,'executed',false);

  elsif v_tool.tool_key='f16.email.context.preview' then
    v_output:=jsonb_build_object(
      'recommendation_id',v_rec.id,'channel','EMAIL','send_allowed',false,'requires_f16',true,
      'opportunity_type',v_rec.opportunity_type,'priority_score',v_rec.priority_score,'confidence',v_rec.confidence,
      'freshness_status',v_rec.freshness_status,'observed_affinity',v_rec.observed_affinity,
      'source','F14_COMMERCIAL_ONLY','clinical_features_used',false);

  elsif v_tool.tool_key='proposal.release' then
    v_policy:=public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT');
    if coalesce(v_policy->>'decision','BLOCK')<>'REQUIRE_APPROVAL' or coalesce((v_policy->>'auto_execute')::boolean,true) then
      v_call_status:='BLOCKED'; v_run_status:='BLOCKED';
      v_output:=jsonb_build_object('error','POLICY_BLOCKED','policy',v_policy,'executed',false);
    elsif v_rec.assignment_id is null or v_rec.advisor_user_id is null then
      v_call_status:='BLOCKED'; v_run_status:='BLOCKED';
      v_output:=jsonb_build_object('error','NO_ACTIVE_ASSIGNMENT_CONTEXT','policy',v_policy,'executed',false);
    else
      select a.* into v_assignment from public.aos_cia_assignments a where a.id=v_rec.assignment_id;
      if v_assignment.id is null or v_assignment.advisor_user_id is distinct from v_rec.advisor_user_id or v_assignment.state not in ('ASSIGNED','IN_PROGRESS') or v_assignment.expires_at<=statement_timestamp() then
        v_call_status:='BLOCKED'; v_run_status:='BLOCKED';
        v_output:=jsonb_build_object('error','OWNERSHIP_NOT_REQUESTABLE','policy',v_policy,'executed',false);
      else
        insert into public.aos_cia_kronia_proposals(run_id,recommendation_id,agent_key,tool_key,request_type,assignment_id,advisor_user_id,proposal_payload,policy_decision,state)
        values(v_run,v_rec.id,v_agent.agent_key,v_tool.tool_key,'RELEASE_ASSIGNMENT',v_rec.assignment_id,v_rec.advisor_user_id,jsonb_build_object('reason',case when length(v_reason)>=3 then v_reason else 'F15 governed intelligence proposal' end),v_policy,'REQUIRES_APPROVAL')
        returning id into v_prop;
        insert into public.aos_cia_kronia_proposal_events(proposal_id,event_type,payload)
        values(v_prop,'PROPOSED',jsonb_build_object('policy',v_policy,'executed',false));
        v_output:=jsonb_build_object('proposal_id',v_prop,'state','REQUIRES_APPROVAL','policy',v_policy,'request_created',false,'executed',false,'next_step','Advisor/human creates governed F13 request for the same owned work-item.');
      end if;
    end if;
  else
    v_call_status:='BLOCKED'; v_run_status:='BLOCKED';
    v_output:=jsonb_build_object('error','TOOL_IMPLEMENTATION_NOT_FOUND');
  end if;

  v_duration:=round((extract(epoch from (clock_timestamp()-v_started))*1000)::numeric,3);
  insert into public.aos_cia_kronia_tool_calls(run_id,recommendation_id,agent_key,tool_key,tool_version,operation_class,request_type,input_payload,output_payload,policy_decision,status,auto_execute,duration_ms)
  values(v_run,p_recommendation_id,v_agent.agent_key,v_tool.tool_key,v_tool.version,v_tool.operation_class,v_tool.request_type,'{}'::jsonb,v_output,v_policy,v_call_status,false,v_duration);
  update public.aos_cia_kronia_agent_runs set status=v_run_status,completed_at=clock_timestamp() where id=v_run;

  return jsonb_build_object('ok',(v_call_status='SUCCEEDED'),'run_id',v_run,'correlation_id',v_corr,'agent_key',v_agent.agent_key,'tool_key',v_tool.tool_key,'status',v_call_status,'output',v_output,'auto_execute',false,'duration_ms',v_duration);
exception when others then
  if v_run is not null then
    update public.aos_cia_kronia_agent_runs set status='FAILED',completed_at=clock_timestamp(),provenance=provenance||jsonb_build_object('failure_class','TOOL_RUNTIME') where id=v_run;
  end if;
  return jsonb_build_object('ok',false,'error','TOOL_RUNTIME_ERROR','sqlstate',sqlstate,'auto_execute',false);
end $$;

create or replace function public.aos_cia_kronia_link_request_v1(p_proposal_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare p record; q record; v_link jsonb;
begin
  select * into p from public.aos_cia_kronia_proposals where id=p_proposal_id;
  if p.id is null then return jsonb_build_object('ok',false,'error','PROPOSAL_NOT_FOUND'); end if;
  select * into q from public.aos_cia_requests where id=p_request_id;
  if q.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
  if q.assignment_id is distinct from p.assignment_id or q.requester_user_id is distinct from p.advisor_user_id or upper(q.request_type)<>upper(p.request_type) then
    return jsonb_build_object('ok',false,'error','RESOURCE_MISMATCH');
  end if;
  if exists(select 1 from public.aos_cia_kronia_proposal_events e where e.proposal_id=p.id and e.request_id=q.id and e.event_type='REQUEST_LINKED') then
    return jsonb_build_object('ok',true,'already_linked',true,'proposal_id',p.id,'request_id',q.id,'request_state',q.state);
  end if;
  v_link:=public.aos_cia_intelligence_link_request_v1(p.recommendation_id,q.id);
  if coalesce((v_link->>'ok')::boolean,false) is not true then return v_link; end if;
  insert into public.aos_cia_kronia_proposal_events(proposal_id,request_id,event_type,payload)
  values(p.id,q.id,'REQUEST_LINKED',jsonb_build_object('request_state',q.state,'request_type',q.request_type));
  return jsonb_build_object('ok',true,'proposal_id',p.id,'recommendation_id',p.recommendation_id,'request_id',q.id,'request_state',q.state,'executed',false);
end $$;

create or replace function public.aos_cia_kronia_request_outcome_sync_v1(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare e record; q record;
begin
  select * into e from public.aos_cia_kronia_proposal_events where proposal_id=p_proposal_id and event_type='REQUEST_LINKED' and request_id is not null order by occurred_at desc,id desc limit 1;
  if e.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_LINKED'); end if;
  select * into q from public.aos_cia_requests where id=e.request_id;
  if q.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
  if q.state in ('APPROVED','REJECTED','EXPIRED','EXECUTED') and not exists(select 1 from public.aos_cia_kronia_proposal_events x where x.proposal_id=p_proposal_id and x.request_id=q.id and x.event_type='HUMAN_DECISION_OBSERVED') then
    insert into public.aos_cia_kronia_proposal_events(proposal_id,request_id,event_type,payload) values(p_proposal_id,q.id,'HUMAN_DECISION_OBSERVED',jsonb_build_object('request_state',q.state,'observed_only',true));
  end if;
  return jsonb_build_object('ok',true,'proposal_id',p_proposal_id,'request_id',q.id,'request_state',q.state,'observed_only',true,'executed_by_f15',false);
end $$;

revoke all on function public.aos_cia_kronia_tool_invoke_v1(text,text,uuid,jsonb,uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_kronia_link_request_v1(uuid,uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_kronia_request_outcome_sync_v1(uuid) from public,anon,authenticated;
