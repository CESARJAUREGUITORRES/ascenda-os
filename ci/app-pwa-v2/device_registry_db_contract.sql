\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

do $$
declare
  u1 uuid := '11111111-1111-1111-1111-111111111111';
  u2 uuid := '22222222-2222-2222-2222-222222222222';
  inactive uuid := '33333333-3333-3333-3333-333333333333';
  installation uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  dev uuid;
  j jsonb;
begin
  j := public.aos_device_upsert_v1(jsonb_build_object(
    'user_id',u1,'installation_id',installation,'device_name','CI Device',
    'os_family','LINUX','form_factor','DESKTOP','runtime_surface','PWA',
    'notification_permission','granted','push_supported',true,'badge_supported',true,
    'tel_supported',true,'standalone',true,'native_bridge',false
  ));
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'device upsert failed: %',j; end if;
  dev := (j->>'device_id')::uuid;

  if (select count(*) from public.aos_devices_v1 where id=dev and user_id=u1 and active) <> 1 then
    raise exception 'device ownership persistence failed';
  end if;

  j := public.aos_device_upsert_v1(jsonb_build_object('user_id',inactive,'installation_id',gen_random_uuid()));
  if j->>'error' <> 'ACTIVE_USER_REQUIRED' then raise exception 'inactive user negative failed: %',j; end if;

  j := public.aos_devices_actor_v1(jsonb_build_object('actor_id',u2));
  if jsonb_array_length(j->'rows') <> 0 then raise exception 'cross-user device read leak: %',j; end if;

  j := public.aos_app_presence_touch_v1(jsonb_build_object('user_id',u2,'device_id',dev,'labor_state','ACTIVO'));
  if j->>'error' <> 'ACTIVE_DEVICE_REQUIRED' then raise exception 'cross-user presence write allowed: %',j; end if;

  j := public.aos_app_presence_touch_v1(jsonb_build_object(
    'user_id',u1,'device_id',dev,'labor_state','EN LLAMADA','focused',true,'visible',true,'runtime_surface','PWA'
  ));
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'presence touch failed: %',j; end if;

  j := public.aos_effective_presence_v1(jsonb_build_object('user_id',u1,'stale_seconds',120));
  if j->>'status' <> 'EN LLAMADA' or coalesce((j->>'stale')::boolean,true) then
    raise exception 'effective presence wrong: %',j;
  end if;

  j := public.aos_device_preferences_actor_v1(jsonb_build_object(
    'actor_id',u2,'device_id',dev,'channel_preferences',jsonb_build_object('SALES',false),'quiet_hours','{}'::jsonb
  ));
  if j->>'error' <> 'ACTIVE_DEVICE_REQUIRED' then raise exception 'cross-user preferences allowed: %',j; end if;

  j := public.aos_device_preferences_actor_v1(jsonb_build_object(
    'actor_id',u1,'device_id',dev,'channel_preferences',jsonb_build_object('SALES',false),'quiet_hours','{}'::jsonb
  ));
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'preferences failed: %',j; end if;

  j := public.aos_device_rename_actor_v1(jsonb_build_object('actor_id',u2,'device_id',dev,'device_name','LEAK'));
  if j->>'error' <> 'ACTIVE_DEVICE_REQUIRED' then raise exception 'cross-user rename allowed: %',j; end if;

  j := public.aos_device_rename_actor_v1(jsonb_build_object('actor_id',u1,'device_id',dev,'device_name','CI Renamed'));
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'rename failed: %',j; end if;

  insert into public.aos_push_subscriptions_v1(user_id,endpoint,active,device_id)
  values(u1,'https://ci.invalid/push',true,dev);

  j := public.aos_device_disable_actor_v1(jsonb_build_object('actor_id',u2,'device_id',dev));
  if j->>'error' <> 'ACTIVE_DEVICE_REQUIRED' then raise exception 'cross-user disable allowed: %',j; end if;

  j := public.aos_device_disable_actor_v1(jsonb_build_object('actor_id',u1,'device_id',dev));
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'disable failed: %',j; end if;

  if exists(select 1 from public.aos_devices_v1 where id=dev and active) then raise exception 'device still active'; end if;
  if exists(select 1 from public.aos_push_subscriptions_v1 where device_id=dev and active) then raise exception 'push subscription still active'; end if;
end $$;

do $$
begin
  if has_table_privilege('anon','public.aos_devices_v1','SELECT') then raise exception 'anon table SELECT leak'; end if;
  if has_table_privilege('authenticated','public.aos_devices_v1','SELECT') then raise exception 'authenticated table SELECT leak'; end if;
  if not has_table_privilege('service_role','public.aos_devices_v1','SELECT') then raise exception 'service_role table SELECT missing'; end if;

  if has_function_privilege('anon','public.aos_device_upsert_v1(jsonb)','EXECUTE') then raise exception 'anon function EXECUTE leak'; end if;
  if has_function_privilege('authenticated','public.aos_device_upsert_v1(jsonb)','EXECUTE') then raise exception 'authenticated function EXECUTE leak'; end if;
  if not has_function_privilege('service_role','public.aos_device_upsert_v1(jsonb)','EXECUTE') then raise exception 'service_role function EXECUTE missing'; end if;

  if not (select relrowsecurity from pg_class where oid='public.aos_devices_v1'::regclass) then raise exception 'devices RLS disabled'; end if;
  if not (select relrowsecurity from pg_class where oid='public.aos_app_presence_v1'::regclass) then raise exception 'presence RLS disabled'; end if;
end $$;

select 'APP_PWA_V2_DEVICE_REGISTRY_DB_CONTRACT=PASS';
