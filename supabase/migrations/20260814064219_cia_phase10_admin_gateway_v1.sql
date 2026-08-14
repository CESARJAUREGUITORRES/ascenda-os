create or replace function public.aos_cia_phase10_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare auth jsonb;uid uuid;usr text;act text:=upper(coalesce(p_action,''));payload jsonb:=coalesce(p_payload,'{}'::jsonb);res jsonb;t0 timestamptz:=clock_timestamp();dur integer;v_action text;v_state text;v_advisor uuid;
begin
 if jsonb_typeof(payload)<>'object' or octet_length(payload::text)>65536 then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');end if;
 auth:=public.aos_cia_verify_admin_session_v1(p_token);
 if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED');end if;
 uid:=(auth->>'user_id')::uuid;usr:=coalesce(auth->>'usuario','');

 if act='BOOTSTRAP' then
   res:=jsonb_build_object('ok',true,'version',1,
     'overview',public.aos_cia_advisor_control_overview_v1(),
     'plan_health',public.aos_cia_advisor_control_plan_health_v1(false,25,0)->'items',
     'alerts',public.aos_cia_advisor_control_alerts_v1(50)->'items',
     'f11_readiness',public.aos_cia_advisor_control_f11_readiness_v1(),
     'limits',jsonb_build_object('advisor_detail',100,'plan_health',50,'alerts',100,'payload_bytes',65536));
 elsif act='OVERVIEW' then res:=public.aos_cia_advisor_control_overview_v1();
 elsif act='ADVISOR_DETAIL' then
   v_advisor:=(payload->>'advisor_user_id')::uuid;v_state:=nullif(upper(coalesce(payload->>'state','')),'');
   res:=public.aos_cia_advisor_control_advisor_detail_v1(v_advisor,v_state,least(greatest(coalesce((payload->>'limit')::integer,50),1),100),greatest(coalesce((payload->>'offset')::integer,0),0));
 elsif act='PLAN_HEALTH' then
   res:=public.aos_cia_advisor_control_plan_health_v1(coalesce((payload->>'include_terminal')::boolean,false),least(greatest(coalesce((payload->>'limit')::integer,25),1),50),greatest(coalesce((payload->>'offset')::integer,0),0));
 elsif act='GET_PLAN' then res:=public.aos_cia_assignment_plan_summary_v1((payload->>'plan_id')::uuid);
 elsif act='ALERTS' then res:=public.aos_cia_advisor_control_alerts_v1(least(greatest(coalesce((payload->>'limit')::integer,50),1),100));
 elsif act='F11_READINESS' then res:=public.aos_cia_advisor_control_f11_readiness_v1();
 elsif act='PLAN_ACTION' then
   v_action:=upper(coalesce(payload->>'action',''));
   if v_action not in('PAUSE','RESUME') then res:=jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED_IN_PHASE10');
   else res:=public.aos_cia_assignment_plan_transition_admin_v1(p_token,(payload->>'plan_id')::uuid,v_action);end if;
 elsif act='RECONCILE' then res:=public.aos_cia_assignment_reconcile_admin_v1(p_token,(payload->>'plan_id')::uuid);
 elsif act='TOPUP' then res:=public.aos_cia_assignment_topup_admin_v1(p_token,(payload->>'plan_id')::uuid,payload->>'idempotency_key');
 elsif act='RELEASE_ASSIGNMENT' then res:=public.aos_cia_assignment_action_admin_v1(p_token,(payload->>'assignment_id')::uuid,'RELEASE',nullif(payload->>'reason',''));
 else res:=jsonb_build_object('ok',false,'error','UNSUPPORTED_ACTION');end if;

 dur:=greatest(0,round(extract(epoch from(clock_timestamp()-t0))*1000)::integer);
 insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
 values(uid,usr,'CIA_P10:'||act,coalesce((res->>'ok')::boolean,false),dur,jsonb_build_object('phase',10));
 return res;
exception when invalid_text_representation or numeric_value_out_of_range then
 return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
when others then
 begin
   dur:=greatest(0,round(extract(epoch from(clock_timestamp()-t0))*1000)::integer);
   if uid is not null then insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
   values(uid,coalesce(usr,''),'CIA_P10:'||act,false,dur,jsonb_build_object('phase',10,'error',left(sqlerrm,500)));end if;
 exception when others then null;end;
 return jsonb_build_object('ok',false,'error','PHASE10_GATEWAY_ERROR','detail',left(sqlerrm,500));
end;
$$;

revoke all on function public.aos_cia_phase10_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_phase10_admin_gateway_v1(text,text,jsonb) to anon,authenticated,service_role;
