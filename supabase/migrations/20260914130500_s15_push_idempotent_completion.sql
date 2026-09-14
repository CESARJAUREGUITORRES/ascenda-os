-- S15 Push delivery monotonicity + idempotent dispatch readback.
begin;

create or replace function public.aos_push_dispatch_claim_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_sub uuid;
  v_user uuid;
  v_id bigint;
  v_key text;
  v_existing_status text;
begin
  begin
    v_sub := (p_payload->>'subscription_id')::uuid;
    v_user := (p_payload->>'recipient_user_id')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'claimed',false,'error','INVALID_DISPATCH_IDS');
  end;
  v_key := left(coalesce(nullif(trim(p_payload->>'dedupe_key'),''),'missing'),300);

  insert into public.aos_push_dispatches_v1(subscription_id,recipient_user_id,channel,event_type,entity_id,dedupe_key,status)
  values(
    v_sub,v_user,
    upper(left(coalesce(nullif(trim(p_payload->>'channel'),''),'UNKNOWN'),32)),
    left(coalesce(nullif(trim(p_payload->>'event_type'),''),'notification'),80),
    left(nullif(trim(coalesce(p_payload->>'entity_id','')),''),160),
    v_key,'PENDING'
  )
  on conflict(subscription_id,dedupe_key) do nothing
  returning id,status into v_id,v_existing_status;

  if v_id is null then
    select d.id,d.status into v_id,v_existing_status
    from public.aos_push_dispatches_v1 d
    where d.subscription_id=v_sub and d.dedupe_key=v_key
    limit 1;
    return jsonb_build_object('ok',true,'claimed',false,'dispatch_id',v_id,'status',v_existing_status,'deduped',true);
  end if;

  return jsonb_build_object('ok',true,'claimed',true,'dispatch_id',v_id,'status',v_existing_status,'deduped',false);
end
$$;

create or replace function public.aos_notification_push_complete_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  nid uuid;
  st text:=upper(trim(coalesce(p_payload->>'status','FAILED')));
  err text:=left(nullif(trim(coalesce(p_payload->>'error_code','')),''),160);
  attempts integer;
  final_st text;
begin
  begin nid:=(p_payload->>'notification_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','INVALID_NOTIFICATION_ID'); end;
  if st not in ('DELIVERED','PARTIAL','SKIPPED','FAILED') then st:='FAILED'; end if;

  update public.aos_notificaciones n
  set push_status=case
        when n.push_status='DELIVERED' then 'DELIVERED'
        when n.push_status='PARTIAL' and st in ('SKIPPED','FAILED') then 'PARTIAL'
        else st
      end,
      push_claimed_at=null,
      updated_at=now(),
      metadata=case
        when (case
          when n.push_status='DELIVERED' then 'DELIVERED'
          when n.push_status='PARTIAL' and st in ('SKIPPED','FAILED') then 'PARTIAL'
          else st end)='DELIVERED'
          then coalesce(n.metadata,'{}'::jsonb)-'last_push_error'
        when err is null then n.metadata
        else jsonb_set(coalesce(n.metadata,'{}'::jsonb),'{last_push_error}',to_jsonb(err),true)
      end
  where n.id=nid
  returning n.push_attempts,n.push_status into attempts,final_st;

  if attempts is null then return jsonb_build_object('ok',false,'error','NOTIFICATION_NOT_FOUND'); end if;
  return jsonb_build_object('ok',true,'status',final_st,'attempts',attempts,'requested_status',st);
end
$$;

revoke all on function public.aos_push_dispatch_claim_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_notification_push_complete_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_push_dispatch_claim_v1(jsonb) to service_role;
grant execute on function public.aos_notification_push_complete_v1(jsonb) to service_role;

commit;
