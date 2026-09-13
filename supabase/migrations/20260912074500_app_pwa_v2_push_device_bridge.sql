-- APP-PWA-V2 #517 — bind Web Push subscription to authenticated device.
-- PREPARED ONLY. Requires Device Registry migration first.

create or replace function public.aos_push_subscription_upsert_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_device uuid;
  v_installation uuid;
  v_endpoint text := trim(coalesce(p_payload->>'endpoint',''));
  v_p256dh text := trim(coalesce(p_payload->>'p256dh',''));
  v_auth text := trim(coalesce(p_payload->>'auth',''));
  v_id uuid;
  v_existing_id uuid;
  v_existing_active boolean;
  v_existing_failures integer;
  v_existing_p256dh text;
  v_existing_auth text;
begin
  begin v_user := (p_payload->>'user_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','INVALID_USER_ID'); end;

  if length(v_endpoint) < 20 or length(v_endpoint) > 4096 or length(v_p256dh) < 20 or length(v_auth) < 8 then
    return jsonb_build_object('ok', false, 'error', 'INVALID_PUSH_SUBSCRIPTION');
  end if;

  if not exists(select 1 from public.aos_usuarios where id=v_user and activo=true) then
    return jsonb_build_object('ok', false, 'error', 'ACTIVE_USER_REQUIRED');
  end if;

  begin v_device := nullif(p_payload->>'device_id','')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','INVALID_DEVICE_ID'); end;

  if v_device is null then
    begin v_installation := nullif(p_payload->>'installation_id','')::uuid;
    exception when others then v_installation := null; end;
    if v_installation is not null then
      select d.id into v_device
      from public.aos_devices_v1 d
      where d.user_id=v_user and d.installation_id=v_installation and d.active=true
      limit 1;
    end if;
  end if;

  if v_device is not null and not exists(
    select 1 from public.aos_devices_v1 d where d.id=v_device and d.user_id=v_user and d.active=true
  ) then
    return jsonb_build_object('ok',false,'error','ACTIVE_DEVICE_REQUIRED');
  end if;

  select id,active,failure_count,p256dh,auth
    into v_existing_id,v_existing_active,v_existing_failures,v_existing_p256dh,v_existing_auth
  from public.aos_push_subscriptions_v1
  where endpoint=v_endpoint
  for update;

  if found
     and v_existing_active=false
     and coalesce(v_existing_failures,0)>0
     and v_existing_p256dh=v_p256dh
     and v_existing_auth=v_auth then
    return jsonb_build_object(
      'ok',true,
      'registered',false,
      'reset_required',true,
      'reason','PUSH_SUBSCRIPTION_RETIRED',
      'subscription_id',v_existing_id,
      'device_id',v_device
    );
  end if;

  insert into public.aos_push_subscriptions_v1(
    user_id,endpoint,p256dh,auth,device_label,user_agent,device_id,active,failure_count,updated_at
  )
  values(
    v_user,v_endpoint,v_p256dh,v_auth,
    left(nullif(trim(coalesce(p_payload->>'device_label','')),''),160),
    left(nullif(trim(coalesce(p_payload->>'user_agent','')),''),500),
    v_device,
    true,0,now()
  )
  on conflict(endpoint) do update set
    user_id=excluded.user_id,
    p256dh=excluded.p256dh,
    auth=excluded.auth,
    device_label=excluded.device_label,
    user_agent=excluded.user_agent,
    device_id=coalesce(excluded.device_id,aos_push_subscriptions_v1.device_id),
    active=true,
    failure_count=0,
    updated_at=now()
  returning id into v_id;

  return jsonb_build_object(
    'ok',true,'registered',true,'reset_required',false,
    'subscription_id',v_id,'device_id',v_device
  );
end
$$;

revoke all on function public.aos_push_subscription_upsert_v1(jsonb) from public, anon, authenticated;
grant execute on function public.aos_push_subscription_upsert_v1(jsonb) to service_role;
