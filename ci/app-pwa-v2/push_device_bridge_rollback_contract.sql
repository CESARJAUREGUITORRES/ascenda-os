\set ON_ERROR_STOP on
do $$
declare
  u1 uuid := '11111111-1111-1111-1111-111111111111';
  ep text := 'https://push.example.invalid/subscription/rollback-retired';
  k text := 'p256dh-key-material-rollback-111';
  a text := 'auth-rollback-11';
  j jsonb;
begin
  insert into public.aos_push_subscriptions_v1(user_id,endpoint,p256dh,auth,active,failure_count)
  values(u1,ep,k,a,false,1);

  j := public.aos_push_subscription_upsert_v1(jsonb_build_object(
    'user_id',u1,'endpoint',ep,'p256dh',k,'auth',a
  ));
  if j->>'reason' <> 'PUSH_SUBSCRIPTION_RETIRED' or coalesce((j->>'reset_required')::boolean,false) is not true then
    raise exception 'rollback S15.4 recovery missing: %',j;
  end if;
  if j ? 'device_id' then raise exception 'rollback function still exposes device bridge response'; end if;
end $$;
select 'APP_PWA_V2_PUSH_BRIDGE_ROLLBACK_CONTRACT=PASS';
