\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

do $$
declare
  u1 uuid := '11111111-1111-1111-1111-111111111111';
  u2 uuid := '22222222-2222-2222-2222-222222222222';
  inst1 uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  inst2 uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  d1 uuid;
  d2 uuid;
  j jsonb;
  ep1 text := 'https://push.example.invalid/subscription/one';
  ep2 text := 'https://push.example.invalid/subscription/two';
  ep3 text := 'https://push.example.invalid/subscription/legacy';
  epr text := 'https://push.example.invalid/subscription/retired';
  k1 text := 'p256dh-key-material-111111111111';
  k2 text := 'p256dh-key-material-222222222222';
  auth1 text := 'auth-key-1111';
  auth2 text := 'auth-key-2222';
begin
  j := public.aos_device_upsert_v1(jsonb_build_object('user_id',u1,'installation_id',inst1,'device_name','U1 Device'));
  d1 := (j->>'device_id')::uuid;
  j := public.aos_device_upsert_v1(jsonb_build_object('user_id',u2,'installation_id',inst2,'device_name','U2 Device'));
  d2 := (j->>'device_id')::uuid;

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',ep1,'p256dh',k1,'auth',auth1,'device_id',d1
  ));
  if coalesce((j->>'registered')::boolean,false) is not true or (j->>'device_id')::uuid <> d1 then
    raise exception 'direct device binding failed: %',j;
  end if;

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',ep2,'p256dh',k1,'auth',auth1,'installation_id',inst1
  ));
  if (j->>'device_id')::uuid <> d1 then raise exception 'installation fallback failed: %',j; end if;

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint','https://push.example.invalid/subscription/cross-owner',
    'p256dh',k1,'auth',auth1,'device_id',d2
  ));
  if j->>'error' <> 'ACTIVE_DEVICE_REQUIRED' then raise exception 'cross-owner device accepted: %',j; end if;

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',ep3,'p256dh',k1,'auth',auth1
  ));
  if coalesce((j->>'registered')::boolean,false) is not true or j->'device_id' <> 'null'::jsonb then
    raise exception 'legacy no-device subscription failed: %',j;
  end if;

  -- Existing device binding must survive a legacy client update that omits device identity.
  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',ep1,'p256dh',k1,'auth',auth1,'device_label','legacy-refresh'
  ));
  if (select device_id from public.aos_push_subscriptions_v1 where endpoint=ep1) <> d1 then
    raise exception 'legacy refresh erased device binding';
  end if;

  insert into public.aos_push_subscriptions_v1(
    user_id,endpoint,p256dh,auth,active,failure_count,device_id
  ) values(u1,epr,k1,auth1,false,2,d1);

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',epr,'p256dh',k1,'auth',auth1
  ));
  if coalesce((j->>'reset_required')::boolean,false) is not true
     or j->>'reason' <> 'PUSH_SUBSCRIPTION_RETIRED'
     or coalesce((j->>'registered')::boolean,true) is not false then
    raise exception 'retired subscription recovery changed: %',j;
  end if;
  if (select active from public.aos_push_subscriptions_v1 where endpoint=epr) is not false then
    raise exception 'retired endpoint reactivated with unchanged keys';
  end if;

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',epr,'p256dh',k2,'auth',auth2
  ));
  if coalesce((j->>'registered')::boolean,false) is not true then raise exception 'rotated retired subscription did not recover: %',j; end if;
  if not (select active and failure_count=0 and device_id=d1 from public.aos_push_subscriptions_v1 where endpoint=epr) then
    raise exception 'rotated retired subscription state wrong';
  end if;
end $$;

do $$
begin
  if has_function_privilege('anon','public.aos_push_subscription_upsert_v1(jsonb)','EXECUTE') then raise exception 'anon push upsert execute leak'; end if;
  if has_function_privilege('authenticated','public.aos_push_subscription_upsert_v1(jsonb)','EXECUTE') then raise exception 'authenticated push upsert execute leak'; end if;
  if not has_function_privilege('service_role','public.aos_push_subscription_upsert_v1(jsonb)','EXECUTE') then raise exception 'service_role push upsert execute missing'; end if;
end $$;

select 'APP_PWA_V2_PUSH_DEVICE_BRIDGE_DB_CONTRACT=PASS';
