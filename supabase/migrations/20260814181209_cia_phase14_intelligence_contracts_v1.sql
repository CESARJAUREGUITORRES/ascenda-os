-- ASCENDA OS CIA V3 — Phase 14 governed read contracts + F15 handshake.
create or replace function public.aos_cia_intelligence_link_request_v1(p_recommendation_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $function$
declare r record; q record;
begin
  select * into r from public.aos_cia_intelligence_recommendations where id=p_recommendation_id;
  if r.id is null then return jsonb_build_object('ok',false,'error','RECOMMENDATION_NOT_FOUND'); end if;
  select * into q from public.aos_cia_requests where id=p_request_id;
  if q.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
  if r.assignment_id is null or q.assignment_id is distinct from r.assignment_id then return jsonb_build_object('ok',false,'error','RESOURCE_MISMATCH'); end if;
  insert into public.aos_cia_intelligence_events(recommendation_id,request_id,event_type,payload) values(r.id,q.id,'REQUEST_LINKED',jsonb_build_object('request_state',q.state,'request_type',q.request_type));
  return jsonb_build_object('ok',true,'recommendation_id',r.id,'request_id',q.id,'request_state',q.state);
end $function$;
revoke all on function public.aos_cia_intelligence_link_request_v1(uuid,uuid) from public,anon,authenticated;

create or replace function public.aos_cia_intelligence_advisor_list_v1(p_asesor text,p_id_asesor text,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path=public as $function$
declare v_uid uuid; v_run uuid; v_limit integer:=greatest(1,least(coalesce(p_limit,50),100)); v_offset integer:=greatest(0,coalesce(p_offset,0)); v_total integer; v_items jsonb;
begin
  v_uid:=public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_uid is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  select id into v_run from public.aos_cia_intelligence_shadow_runs where status='COMPLETE' order by completed_at desc nulls last,created_at desc limit 1;
  if v_run is null then return jsonb_build_object('ok',true,'advisor_user_id',v_uid,'run_id',null,'total',0,'items','[]'::jsonb,'mode','SHADOW'); end if;
  select count(*)::integer into v_total from public.aos_cia_intelligence_recommendations r join public.aos_cia_assignments a on a.id=r.assignment_id where r.run_id=v_run and r.advisor_user_id=v_uid and a.advisor_user_id=v_uid and a.state in ('ASSIGNED','IN_PROGRESS') and a.expires_at>statement_timestamp();
  select coalesce(jsonb_agg(to_jsonb(x) order by x.priority_score desc,x.created_at desc),'[]'::jsonb) into v_items from (
    select r.id,r.opportunity_type,r.priority_score,r.confidence,r.sample_size,r.freshness_status,r.evidence,r.explanation,r.observed_affinity,r.state,r.created_at,r.assignment_id
    from public.aos_cia_intelligence_recommendations r join public.aos_cia_assignments a on a.id=r.assignment_id
    where r.run_id=v_run and r.advisor_user_id=v_uid and a.advisor_user_id=v_uid and a.state in ('ASSIGNED','IN_PROGRESS') and a.expires_at>statement_timestamp()
    order by r.priority_score desc,r.created_at desc limit v_limit offset v_offset) x;
  return jsonb_build_object('ok',true,'advisor_user_id',v_uid,'run_id',v_run,'total',v_total,'items',v_items,'mode','SHADOW');
end $function$;
revoke all on function public.aos_cia_intelligence_advisor_list_v1(text,text,integer,integer) from public,anon,authenticated;
grant execute on function public.aos_cia_intelligence_advisor_list_v1(text,text,integer,integer) to anon,authenticated;

create or replace function public.aos_cia_intelligence_f15_readiness_v1()
returns jsonb language plpgsql security definer set search_path=public as $function$
declare v_f13 jsonb; v_run uuid; v_rec_count integer:=0; v_bad_state integer:=0; v_auto_execute integer:=0; v_generated_missing integer:=0; v_policy_release jsonb; v_policy_autoassign jsonb; v_anon boolean; v_auth boolean; v_ready boolean; v_status text;
begin
  v_f13:=public.aos_cia_request_f14_readiness_v1();
  v_policy_release:=public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','RELEASE_ASSIGNMENT');
  v_policy_autoassign:=public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','AUTO_ASSIGN');
  select id into v_run from public.aos_cia_intelligence_shadow_runs where status='COMPLETE' order by completed_at desc nulls last,created_at desc limit 1;
  if v_run is not null then
    select count(*)::integer,count(*) filter(where state<>'SHADOW')::integer,count(*) filter(where coalesce((policy_decision->>'auto_execute')::boolean,false))::integer into v_rec_count,v_bad_state,v_auto_execute from public.aos_cia_intelligence_recommendations where run_id=v_run;
    select count(*)::integer into v_generated_missing from public.aos_cia_intelligence_recommendations r where r.run_id=v_run and not exists(select 1 from public.aos_cia_intelligence_events e where e.recommendation_id=r.id and e.event_type='GENERATED');
  end if;
  v_anon:=has_table_privilege('anon','public.aos_cia_intelligence_recommendations','SELECT') or has_table_privilege('anon','public.aos_cia_intelligence_recommendations','INSERT') or has_table_privilege('anon','public.aos_cia_intelligence_recommendations','UPDATE') or has_table_privilege('anon','public.aos_cia_intelligence_recommendations','DELETE');
  v_auth:=has_table_privilege('authenticated','public.aos_cia_intelligence_recommendations','SELECT') or has_table_privilege('authenticated','public.aos_cia_intelligence_recommendations','INSERT') or has_table_privilege('authenticated','public.aos_cia_intelligence_recommendations','UPDATE') or has_table_privilege('authenticated','public.aos_cia_intelligence_recommendations','DELETE');
  v_ready:=coalesce((v_f13->>'ready_for_f14')::boolean,false) and v_run is not null and v_bad_state=0 and v_auto_execute=0 and v_generated_missing=0 and not v_anon and not v_auth and coalesce(v_policy_release->>'decision','')='REQUIRE_APPROVAL' and coalesce((v_policy_release->>'auto_execute')::boolean,false)=false and coalesce(v_policy_autoassign->>'decision','')='BLOCK';
  v_status:=case when not coalesce((v_f13->>'ready_for_f14')::boolean,false) then 'BLOCKED_F13' when v_run is null then 'READY_NO_SHADOW_RUN' when not v_ready then 'BLOCKED_INTEGRITY' when v_rec_count=0 then 'READY_SHADOW_EMPTY' else 'READY_SHADOW_ACTIVE' end;
  return jsonb_build_object('ok',v_ready,'ready_for_f15',v_ready,'status',v_status,'mode','SHADOW','latest_run_id',v_run,'recommendations',v_rec_count,'violations',jsonb_build_object('non_shadow_state',v_bad_state,'auto_execute',v_auto_execute,'missing_generated_event',v_generated_missing),'browser_direct_table_access',jsonb_build_object('anon',v_anon,'authenticated',v_auth),'f13_readiness',v_f13,'policy_release_assignment',v_policy_release,'policy_auto_assign',v_policy_autoassign,'next_phase_note','F15 may interpret/propose through structured tools, but every sensitive action remains governed by F13 Policy Gate; no arbitrary SQL writes.');
end $function$;
revoke all on function public.aos_cia_intelligence_f15_readiness_v1() from public,anon,authenticated;

create or replace function public.aos_cia_intelligence_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $function$
declare v_auth jsonb; v_admin uuid; v_action text:=upper(trim(coalesce(p_action,''))); v_run uuid; v_rec uuid; v_type text; v_conf text; v_fresh text; v_limit integer; v_offset integer; v_total integer; v_items jsonb; v_detail jsonb; v_events jsonb; v_policy jsonb;
begin
  v_auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  v_admin:=(v_auth->>'user_id')::uuid;
  if v_action='READINESS' then return public.aos_cia_intelligence_f15_readiness_v1(); elsif v_action='REFRESH' then return public.aos_cia_intelligence_shadow_refresh_v1(v_admin); end if;
  select id into v_run from public.aos_cia_intelligence_shadow_runs where status='COMPLETE' order by completed_at desc nulls last,created_at desc limit 1;
  if v_action='SUMMARY' then
    if v_run is null then return jsonb_build_object('ok',true,'run_id',null,'total',0,'mode','SHADOW'); end if;
    return (select jsonb_build_object('ok',true,'run_id',v_run,'mode','SHADOW','total',count(*)::integer,'high_confidence',count(*) filter(where confidence='HIGH')::integer,'fresh',count(*) filter(where freshness_status='FRESH')::integer,'unworked_lead',count(*) filter(where opportunity_type='UNWORKED_LEAD')::integer,'followup_recovery',count(*) filter(where opportunity_type='FOLLOWUP_RECOVERY')::integer,'reactivation',count(*) filter(where opportunity_type='REACTIVATION')::integer,'repurchase_signal',count(*) filter(where opportunity_type='REPURCHASE_SIGNAL')::integer,'high_value_attention',count(*) filter(where opportunity_type='HIGH_VALUE_ATTENTION')::integer) from public.aos_cia_intelligence_recommendations where run_id=v_run);
  elsif v_action='LIST' then
    if v_run is null then return jsonb_build_object('ok',true,'run_id',null,'total',0,'items','[]'::jsonb,'mode','SHADOW'); end if;
    v_type:=nullif(upper(trim(coalesce(p_payload->>'opportunity_type',''))),''); v_conf:=nullif(upper(trim(coalesce(p_payload->>'confidence',''))),''); v_fresh:=nullif(upper(trim(coalesce(p_payload->>'freshness',''))),'');
    if v_type is not null and v_type not in ('UNWORKED_LEAD','FOLLOWUP_RECOVERY','REACTIVATION','REPURCHASE_SIGNAL','HIGH_VALUE_ATTENTION') then return jsonb_build_object('ok',false,'error','INVALID_OPPORTUNITY_TYPE'); end if;
    if v_conf is not null and v_conf not in ('LOW','MEDIUM','HIGH') then return jsonb_build_object('ok',false,'error','INVALID_CONFIDENCE'); end if;
    if v_fresh is not null and v_fresh not in ('FRESH','AGING','STALE','UNKNOWN') then return jsonb_build_object('ok',false,'error','INVALID_FRESHNESS'); end if;
    v_limit:=greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100)); v_offset:=greatest(0,coalesce((p_payload->>'offset')::integer,0));
    select count(*)::integer into v_total from public.aos_cia_intelligence_recommendations r where r.run_id=v_run and (v_type is null or r.opportunity_type=v_type) and (v_conf is null or r.confidence=v_conf) and (v_fresh is null or r.freshness_status=v_fresh);
    select coalesce(jsonb_agg(to_jsonb(x) order by x.priority_score desc,x.created_at desc),'[]'::jsonb) into v_items from (select r.id,r.contact_key,r.opportunity_type,r.priority_score,r.confidence,r.sample_size,r.freshness_status,r.evidence,r.explanation,r.observed_affinity,r.assignment_id,r.advisor_user_id,r.created_at from public.aos_cia_intelligence_recommendations r where r.run_id=v_run and (v_type is null or r.opportunity_type=v_type) and (v_conf is null or r.confidence=v_conf) and (v_fresh is null or r.freshness_status=v_fresh) order by r.priority_score desc,r.created_at desc limit v_limit offset v_offset) x;
    return jsonb_build_object('ok',true,'run_id',v_run,'total',v_total,'items',v_items,'mode','SHADOW');
  elsif v_action='GET' then
    begin v_rec:=(p_payload->>'recommendation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_RECOMMENDATION_ID'); end;
    select to_jsonb(r) into v_detail from public.aos_cia_intelligence_recommendations r where r.id=v_rec;
    if v_detail is null then return jsonb_build_object('ok',false,'error','RECOMMENDATION_NOT_FOUND'); end if;
    select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at,e.id),'[]'::jsonb) into v_events from public.aos_cia_intelligence_events e where e.recommendation_id=v_rec;
    return jsonb_build_object('ok',true,'recommendation',v_detail,'events',v_events,'mode','SHADOW');
  elsif v_action='POLICY_PROBE' then
    begin v_rec:=(p_payload->>'recommendation_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_RECOMMENDATION_ID'); end;
    if not exists(select 1 from public.aos_cia_intelligence_recommendations where id=v_rec) then return jsonb_build_object('ok',false,'error','RECOMMENDATION_NOT_FOUND'); end if;
    v_policy:=public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE',coalesce(nullif(upper(trim(p_payload->>'request_type')),''),'RELEASE_ASSIGNMENT'));
    insert into public.aos_cia_intelligence_events(recommendation_id,event_type,payload) values(v_rec,'POLICY_EVALUATED',jsonb_build_object('policy',v_policy,'actor_user_id',v_admin));
    return jsonb_build_object('ok',true,'recommendation_id',v_rec,'policy',v_policy,'executed',false);
  end if;
  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end $function$;
revoke all on function public.aos_cia_intelligence_admin_gateway_v1(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_intelligence_admin_gateway_v1(text,text,jsonb) to anon,authenticated;
comment on function public.aos_cia_intelligence_admin_gateway_v1(text,text,jsonb) is 'F14 ADMIN gateway. REFRESH persists SHADOW-derived recommendations only; POLICY_PROBE never executes actions.';
