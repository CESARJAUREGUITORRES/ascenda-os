-- Rollback ASCENDA S15.4 retired Web Push recovery.
-- Restores the S14 upsert behavior that reactivates any matching endpoint.

create or replace function public.aos_push_subscription_upsert_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_endpoint text := trim(coalesce(p_payload->>'endpoint',''));
  v_p256dh text := trim(coalesce(p_payload->>'p256dh',''));
  v_auth text := trim(coalesce(p_payload->>'auth',''));
  v_id uuid;
begin
  begin v_user := (p_payload->>'user_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_USER_ID'); end;
  if length(v_endpoint) < 20 or length(v_endpoint) > 4096 or length(v_p256dh) < 20 or length(v_auth) < 8 then
    return jsonb_build_object('ok', false, 'error', 'INVALID_PUSH_SUBSCRIPTION');
  end if;
  if not exists(select 1 from public.aos_usuarios where id=v_user and activo=true) then
    return jsonb_build_object('ok', false, 'error', 'ACTIVE_USER_REQUIRED');
  end if;
  insert into public.aos_push_subscriptions_v1(user_id,endpoint,p256dh,auth,device_label,user_agent,active,failure_count,updated_at)
  values(
    v_user,v_endpoint,v_p256dh,v_auth,
    left(nullif(trim(coalesce(p_payload->>'device_label','')),''),160),
    left(nullif(trim(coalesce(p_payload->>'user_agent','')),''),500),
    true,0,now()
  )
  on conflict(endpoint) do update set
    user_id=excluded.user_id,
    p256dh=excluded.p256dh,
    auth=excluded.auth,
    device_label=excluded.device_label,
    user_agent=excluded.user_agent,
    active=true,
    failure_count=0,
    updated_at=now()
  returning id into v_id;
  return jsonb_build_object('ok',true,'subscription_id',v_id);
end;
$$;
