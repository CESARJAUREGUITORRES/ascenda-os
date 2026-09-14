-- Restore pre-monotonic S14/S15 completion semantics.
begin;

create or replace function public.aos_push_dispatch_claim_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_sub uuid; v_user uuid; v_id bigint;
begin
  begin v_sub := (p_payload->>'subscription_id')::uuid; v_user := (p_payload->>'recipient_user_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'claimed',false,'error','INVALID_DISPATCH_IDS'); end;
  insert into public.aos_push_dispatches_v1(subscription_id,recipient_user_id,channel,event_type,entity_id,dedupe_key,status)
  values(v_sub,v_user,upper(left(coalesce(nullif(trim(p_payload->>'channel'),''),'UNKNOWN'),32)),left(coalesce(nullif(trim(p_payload->>'event_type'),''),'notification'),80),left(nullif(trim(coalesce(p_payload->>'entity_id','')),''),160),left(coalesce(nullif(trim(p_payload->>'dedupe_key'),''),'missing'),300),'PENDING')
  on conflict(subscription_id,dedupe_key) do nothing returning id into v_id;
  return jsonb_build_object('ok',true,'claimed',v_id is not null,'dispatch_id',v_id);
end $$;

create or replace function public.aos_notification_push_complete_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare nid uuid; st text:=upper(trim(coalesce(p_payload->>'status','FAILED'))); err text:=left(nullif(trim(coalesce(p_payload->>'error_code','')),''),160); attempts integer;
begin
  begin nid:=(p_payload->>'notification_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_NOTIFICATION_ID'); end;
  if st not in ('DELIVERED','PARTIAL','SKIPPED','FAILED') then st:='FAILED'; end if;
  update public.aos_notificaciones set push_status=st,push_claimed_at=null,updated_at=now(),metadata=case when err is null then metadata else jsonb_set(metadata,'{last_push_error}',to_jsonb(err),true) end where id=nid returning push_attempts into attempts;
  if attempts is null then return jsonb_build_object('ok',false,'error','NOTIFICATION_NOT_FOUND'); end if;
  return jsonb_build_object('ok',true,'status',st,'attempts',attempts);
end $$;

commit;
