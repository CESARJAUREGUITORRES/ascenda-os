create or replace function public.aos_cia_request_policy_gate_v1(
  p_actor_class text,
  p_action text,
  p_request_type text
) returns jsonb
language plpgsql
immutable
set search_path=public
as $function$
declare
  v_actor text := upper(trim(coalesce(p_actor_class,'')));
  v_action text := upper(trim(coalesce(p_action,'')));
  v_type text := upper(trim(coalesce(p_request_type,'')));
  v_decision text := 'BLOCK';
begin
  if v_type in ('AUTO_ASSIGN','TRANSFER_ASSIGNMENT','AUTO_APPROVE','RAW_SQL')
     or v_action in ('AUTO_ASSIGN','TRANSFER_ASSIGNMENT','AUTO_APPROVE','RAW_SQL') then
    v_decision := 'BLOCK';
  elsif v_type='RELEASE_ASSIGNMENT' and v_actor in ('ADVISOR','F14_INTELLIGENCE','KRONIA') and v_action in ('CREATE','PROPOSE') then
    v_decision := 'REQUIRE_APPROVAL';
  elsif v_type='RELEASE_ASSIGNMENT' and v_actor='ADMIN' and v_action in ('APPROVE','REJECT','EXECUTE') then
    v_decision := 'ALLOW';
  end if;

  return jsonb_build_object(
    'ok',true,
    'actor_class',v_actor,
    'action',v_action,
    'request_type',v_type,
    'decision',v_decision,
    'auto_execute',false,
    'admin_auth_required',(v_actor='ADMIN'),
    'policy_version','F13_V1'
  );
end
$function$;

create or replace function public.aos_cia_request_expire_due_internal_v1()
returns integer
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_count integer := 0;
begin
  with stale as (
    select r.id
    from public.aos_cia_requests r
    left join public.aos_cia_assignments a on a.id=r.assignment_id
    where r.state in ('PENDING','APPROVED')
      and (
        r.request_expires_at <= statement_timestamp()
        or a.id is null
        or a.advisor_user_id is distinct from r.requester_user_id
        or a.state not in ('ASSIGNED','IN_PROGRESS')
        or a.expires_at <= statement_timestamp()
      )
    for update of r
  ), upd as (
    update public.aos_cia_requests r
       set state='EXPIRED', decision_reason='EXPIRED_REVALIDATION'
     where r.id in (select id from stale)
     returning 1
  )
  select count(*)::integer into v_count from upd;
  return v_count;
end
$function$;

create or replace function public.aos_cia_request_create_v1(
  p_asesor text,
  p_id_asesor text,
  p_assignment_id uuid,
  p_request_type text,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_advisor uuid;
  v_type text := upper(trim(coalesce(p_request_type,'')));
  v_reason text := btrim(coalesce(p_reason,''));
  v_policy jsonb;
  a record;
  v_exp timestamptz;
  v_id uuid;
begin
  perform public.aos_cia_request_expire_due_internal_v1();

  v_advisor := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_advisor is null then
    return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND');
  end if;
  if length(v_reason) < 3 or length(v_reason) > 1000 then
    return jsonb_build_object('ok',false,'error','INVALID_REASON');
  end if;

  v_policy := public.aos_cia_request_policy_gate_v1('ADVISOR','CREATE',v_type);
  if coalesce(v_policy->>'decision','BLOCK') <> 'REQUIRE_APPROVAL' then
    return jsonb_build_object('ok',false,'error','POLICY_BLOCKED','policy',v_policy);
  end if;

  select x.* into a
  from public.aos_cia_assignments x
  where x.id=p_assignment_id
  for update;

  if a.id is null then return jsonb_build_object('ok',false,'error','WORK_ITEM_NOT_FOUND'); end if;
  if a.advisor_user_id is distinct from v_advisor then return jsonb_build_object('ok',false,'error','WORK_ITEM_NOT_OWNED'); end if;
  if a.state not in ('ASSIGNED','IN_PROGRESS') or a.expires_at <= statement_timestamp() then
    return jsonb_build_object('ok',false,'error','WORK_ITEM_NOT_REQUESTABLE');
  end if;

  v_exp := least(a.expires_at, statement_timestamp()+interval '24 hours');
  if v_exp <= statement_timestamp()+interval '1 second' then
    return jsonb_build_object('ok',false,'error','WORK_ITEM_EXPIRING');
  end if;

  begin
    insert into public.aos_cia_requests(
      request_type,state,requester_user_id,assignment_id,plan_id,activation_id,
      owner_snapshot_user_id,assignment_state_snapshot,assignment_expires_at_snapshot,
      reason,request_payload,policy_snapshot,request_expires_at
    ) values (
      v_type,'PENDING',v_advisor,a.id,a.plan_id,a.activation_id,
      a.advisor_user_id,a.state,a.expires_at,
      v_reason,coalesce(p_metadata,'{}'::jsonb),v_policy,v_exp
    ) returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object('ok',false,'error','REQUEST_ALREADY_OPEN');
  end;

  return jsonb_build_object(
    'ok',true,'request_id',v_id,'state','PENDING','request_type',v_type,
    'request_expires_at',v_exp,'policy',v_policy
  );
end
$function$;

create or replace function public.aos_cia_request_advisor_summary_v1(
  p_asesor text,
  p_id_asesor text
) returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_advisor uuid;
  v_total integer;
  v_pending integer;
  v_approved integer;
  v_rejected integer;
  v_executed integer;
  v_expired integer;
begin
  perform public.aos_cia_request_expire_due_internal_v1();
  v_advisor := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_advisor is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;

  select count(*)::integer,
         count(*) filter(where state='PENDING')::integer,
         count(*) filter(where state='APPROVED')::integer,
         count(*) filter(where state='REJECTED')::integer,
         count(*) filter(where state='EXECUTED')::integer,
         count(*) filter(where state='EXPIRED')::integer
    into v_total,v_pending,v_approved,v_rejected,v_executed,v_expired
  from public.aos_cia_requests where requester_user_id=v_advisor;

  return jsonb_build_object('ok',true,'advisor_user_id',v_advisor,'total',v_total,
    'pending',v_pending,'approved',v_approved,'rejected',v_rejected,'executed',v_executed,'expired',v_expired);
end
$function$;

create or replace function public.aos_cia_request_list_advisor_v1(
  p_asesor text,
  p_id_asesor text,
  p_state text default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_advisor uuid;
  v_state text := nullif(upper(trim(coalesce(p_state,''))), '');
  v_limit integer := greatest(1,least(coalesce(p_limit,50),100));
  v_offset integer := greatest(0,coalesce(p_offset,0));
  v_total integer;
  v_items jsonb;
begin
  perform public.aos_cia_request_expire_due_internal_v1();
  v_advisor := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_advisor is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;
  if v_state is not null and v_state not in ('PENDING','APPROVED','REJECTED','EXPIRED','EXECUTED') then
    return jsonb_build_object('ok',false,'error','INVALID_STATE');
  end if;

  select count(*)::integer into v_total
  from public.aos_cia_requests r
  where r.requester_user_id=v_advisor and (v_state is null or r.state=v_state);

  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_items
  from (
    select r.id,r.request_type,r.state,r.assignment_id,r.reason,r.request_expires_at,
           r.created_at,r.updated_at,r.approved_at,r.rejected_at,r.executed_at,r.decision_reason,
           a.state as current_assignment_state,a.expires_at as current_assignment_expires_at
    from public.aos_cia_requests r
    left join public.aos_cia_assignments a on a.id=r.assignment_id
    where r.requester_user_id=v_advisor and (v_state is null or r.state=v_state)
    order by r.created_at desc
    limit v_limit offset v_offset
  ) q;

  return jsonb_build_object('ok',true,'advisor_user_id',v_advisor,'total',v_total,'items',v_items);
end
$function$;

create or replace function public.aos_cia_request_detail_advisor_v1(
  p_asesor text,
  p_id_asesor text,
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_advisor uuid;
  v_req jsonb;
  v_events jsonb;
begin
  perform public.aos_cia_request_expire_due_internal_v1();
  v_advisor := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if v_advisor is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND'); end if;

  select to_jsonb(q) into v_req from (
    select r.id,r.request_type,r.state,r.assignment_id,r.plan_id,r.activation_id,r.reason,
           r.request_expires_at,r.created_at,r.updated_at,r.approved_at,r.rejected_at,r.executed_at,
           r.decision_reason,r.execution_result,
           a.state current_assignment_state,a.expires_at current_assignment_expires_at
    from public.aos_cia_requests r
    left join public.aos_cia_assignments a on a.id=r.assignment_id
    where r.id=p_request_id and r.requester_user_id=v_advisor
  ) q;
  if v_req is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at,e.id),'[]'::jsonb) into v_events
  from (
    select id,event_type,from_state,to_state,occurred_at
    from public.aos_cia_request_events
    where request_id=p_request_id
    order by occurred_at,id
  ) e;

  return jsonb_build_object('ok',true,'request',v_req,'events',v_events);
end
$function$;

revoke all on function public.aos_cia_request_policy_gate_v1(text,text,text) from public,anon,authenticated;
revoke all on function public.aos_cia_request_expire_due_internal_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_request_create_v1(text,text,uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_request_advisor_summary_v1(text,text) from public,anon,authenticated;
revoke all on function public.aos_cia_request_list_advisor_v1(text,text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_cia_request_detail_advisor_v1(text,text,uuid) from public,anon,authenticated;
grant execute on function public.aos_cia_request_create_v1(text,text,uuid,text,text,jsonb) to anon,authenticated;
grant execute on function public.aos_cia_request_advisor_summary_v1(text,text) to anon,authenticated;
grant execute on function public.aos_cia_request_list_advisor_v1(text,text,text,integer,integer) to anon,authenticated;
grant execute on function public.aos_cia_request_detail_advisor_v1(text,text,uuid) to anon,authenticated;
