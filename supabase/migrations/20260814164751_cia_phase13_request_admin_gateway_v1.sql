create or replace function public.aos_cia_request_admin_gateway_v1(
  p_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_auth jsonb;
  v_admin uuid;
  v_action text := upper(trim(coalesce(p_action,'')));
  v_request_id uuid;
  v_state text;
  v_limit integer;
  v_offset integer;
  v_total integer;
  v_items jsonb;
  v_req jsonb;
  v_events jsonb;
  v_reason text;
  v_policy jsonb;
  r record;
  a record;
  v_transition jsonb;
begin
  v_auth := public.aos_cia_verify_admin_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_admin := (v_auth->>'user_id')::uuid;
  perform public.aos_cia_request_expire_due_internal_v1();

  if v_action='SUMMARY' then
    return (
      select jsonb_build_object(
        'ok',true,
        'total',count(*)::integer,
        'pending',count(*) filter(where state='PENDING')::integer,
        'approved',count(*) filter(where state='APPROVED')::integer,
        'rejected',count(*) filter(where state='REJECTED')::integer,
        'expired',count(*) filter(where state='EXPIRED')::integer,
        'executed',count(*) filter(where state='EXECUTED')::integer
      ) from public.aos_cia_requests
    );
  elsif v_action='LIST' then
    v_state := nullif(upper(trim(coalesce(p_payload->>'state',''))),'');
    if v_state is not null and v_state not in ('PENDING','APPROVED','REJECTED','EXPIRED','EXECUTED') then
      return jsonb_build_object('ok',false,'error','INVALID_STATE');
    end if;
    v_limit := greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    v_offset := greatest(0,coalesce((p_payload->>'offset')::integer,0));
    select count(*)::integer into v_total from public.aos_cia_requests r where v_state is null or r.state=v_state;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_items
    from (
      select r.id,r.request_type,r.state,r.requester_user_id,r.assignment_id,r.reason,
             r.request_expires_at,r.created_at,r.updated_at,r.approved_at,r.rejected_at,r.executed_at,r.decision_reason,
             u.nombre requester_name,u.codigo_asesor requester_code,
             a.state current_assignment_state,a.expires_at current_assignment_expires_at
      from public.aos_cia_requests r
      join public.aos_usuarios u on u.id=r.requester_user_id
      left join public.aos_cia_assignments a on a.id=r.assignment_id
      where v_state is null or r.state=v_state
      order by r.created_at desc
      limit v_limit offset v_offset
    ) q;
    return jsonb_build_object('ok',true,'total',v_total,'items',v_items);
  elsif v_action='GET' then
    begin v_request_id := (p_payload->>'request_id')::uuid;
    exception when others then return jsonb_build_object('ok',false,'error','INVALID_REQUEST_ID'); end;
    select to_jsonb(q) into v_req from (
      select r.*,u.nombre requester_name,u.codigo_asesor requester_code,
             a.state current_assignment_state,a.expires_at current_assignment_expires_at,a.advisor_user_id current_owner_user_id
      from public.aos_cia_requests r
      join public.aos_usuarios u on u.id=r.requester_user_id
      left join public.aos_cia_assignments a on a.id=r.assignment_id
      where r.id=v_request_id
    ) q;
    if v_req is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;
    select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at,e.id),'[]'::jsonb) into v_events
    from (
      select ev.id,ev.event_type,ev.from_state,ev.to_state,ev.actor_user_id,ev.payload,ev.occurred_at,
             u.nombre actor_name
      from public.aos_cia_request_events ev
      left join public.aos_usuarios u on u.id=ev.actor_user_id
      where ev.request_id=v_request_id
      order by ev.occurred_at,ev.id
    ) e;
    return jsonb_build_object('ok',true,'request',v_req,'events',v_events);
  elsif v_action in ('APPROVE','REJECT','EXECUTE') then
    begin v_request_id := (p_payload->>'request_id')::uuid;
    exception when others then return jsonb_build_object('ok',false,'error','INVALID_REQUEST_ID'); end;
    v_reason := nullif(btrim(coalesce(p_payload->>'reason','')),'');

    select x.* into r from public.aos_cia_requests x where x.id=v_request_id for update;
    if r.id is null then return jsonb_build_object('ok',false,'error','REQUEST_NOT_FOUND'); end if;

    v_policy := public.aos_cia_request_policy_gate_v1('ADMIN',v_action,r.request_type);
    if coalesce(v_policy->>'decision','BLOCK') <> 'ALLOW' then
      return jsonb_build_object('ok',false,'error','POLICY_BLOCKED','policy',v_policy);
    end if;

    if v_action='REJECT' then
      if r.state='REJECTED' then return jsonb_build_object('ok',true,'request_id',r.id,'state',r.state,'idempotent',true); end if;
      if r.state<>'PENDING' then return jsonb_build_object('ok',false,'error','REQUEST_NOT_PENDING','state',r.state); end if;
      if v_reason is null then return jsonb_build_object('ok',false,'error','DECISION_REASON_REQUIRED'); end if;
      update public.aos_cia_requests
         set state='REJECTED',rejected_by_user_id=v_admin,rejected_at=clock_timestamp(),decision_reason=v_reason
       where id=r.id;
      return jsonb_build_object('ok',true,'request_id',r.id,'state','REJECTED','policy',v_policy);
    end if;

    select x.* into a from public.aos_cia_assignments x where x.id=r.assignment_id for update;
    if r.request_expires_at<=statement_timestamp()
       or a.id is null
       or a.advisor_user_id is distinct from r.requester_user_id
       or a.advisor_user_id is distinct from r.owner_snapshot_user_id
       or a.state not in ('ASSIGNED','IN_PROGRESS')
       or a.expires_at<=statement_timestamp() then
      if r.state in ('PENDING','APPROVED') then
        update public.aos_cia_requests set state='EXPIRED',decision_reason='STALE_AT_'||v_action where id=r.id;
      end if;
      return jsonb_build_object('ok',false,'error','REQUEST_STALE','request_id',r.id,'state','EXPIRED');
    end if;

    if v_action='APPROVE' then
      if r.state='APPROVED' then return jsonb_build_object('ok',true,'request_id',r.id,'state',r.state,'idempotent',true); end if;
      if r.state<>'PENDING' then return jsonb_build_object('ok',false,'error','REQUEST_NOT_PENDING','state',r.state); end if;
      update public.aos_cia_requests
         set state='APPROVED',approved_by_user_id=v_admin,approved_at=clock_timestamp(),decision_reason=coalesce(v_reason,'APPROVED')
       where id=r.id;
      return jsonb_build_object('ok',true,'request_id',r.id,'state','APPROVED','policy',v_policy);
    end if;

    if r.state='EXECUTED' then return jsonb_build_object('ok',true,'request_id',r.id,'state',r.state,'idempotent',true); end if;
    if r.state<>'APPROVED' then return jsonb_build_object('ok',false,'error','REQUEST_NOT_APPROVED','state',r.state); end if;

    if r.request_type='RELEASE_ASSIGNMENT' then
      v_transition := public.aos_cia_assignment_lease_transition_internal_v1(
        r.assignment_id,'RELEASE',v_admin,coalesce(v_reason,'F13_APPROVED_RELEASE')
      );
      if coalesce((v_transition->>'ok')::boolean,false) is not true then
        return jsonb_build_object('ok',false,'error','EXECUTION_FAILED','transition',v_transition);
      end if;
    else
      return jsonb_build_object('ok',false,'error','REQUEST_TYPE_NOT_EXECUTABLE');
    end if;

    update public.aos_cia_requests
       set state='EXECUTED',executed_by_user_id=v_admin,executed_at=clock_timestamp(),
           execution_result=jsonb_build_object('action',r.request_type,'transition',v_transition),
           decision_reason=coalesce(v_reason,decision_reason,'EXECUTED')
     where id=r.id;
    return jsonb_build_object('ok',true,'request_id',r.id,'state','EXECUTED','execution',v_transition,'policy',v_policy);
  end if;

  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
end
$function$;

revoke all on function public.aos_cia_request_admin_gateway_v1(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_request_admin_gateway_v1(text,text,jsonb) to anon,authenticated;
