-- CIA F16 delivery/provider synthetic tests. Zero PII/PHI and zero provider network calls.

do $test$
declare
  j jsonb;
  v_tpl uuid;
  v_req uuid;
  v_req2 uuid;
begin
  j := public.aos_cia_email_template_version_create_v1(
    '00000000-0000-0000-0000-000000000001','synthetic.marketing.delivery','MARKETING',
    'Hello {{name}}','<p>Hello {{name}}</p>',array['name'],null
  );
  if coalesce((j->>'ok')::boolean,false) is not true then raise exception 'F16_DELIVERY_TEST_FAIL: template create %',j; end if;
  v_tpl := (j->>'template_version_id')::uuid;
  j := public.aos_cia_email_template_version_activate_v1('00000000-0000-0000-0000-000000000001',v_tpl);
  if j->>'state' <> 'ACTIVE' then raise exception 'F16_DELIVERY_TEST_FAIL: template activate %',j; end if;

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'synthetic-contact-1',v_tpl,jsonb_build_object('name','Synthetic Recipient')
  );
  if coalesce((j->>'ok')::boolean,false) is not true or j->>'state' <> 'PREPARED' then
    raise exception 'F16_DELIVERY_TEST_FAIL: prepare v2 %',j;
  end if;
  v_req := (j->>'request_id')::uuid;

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'synthetic-contact-1',v_tpl,jsonb_build_object('name','Synthetic Recipient')
  );
  v_req2 := (j->>'request_id')::uuid;
  if v_req2 <> v_req or coalesce((j->>'idempotent')::boolean,false) is not true then
    raise exception 'F16_DELIVERY_TEST_FAIL: prepare idempotency %',j;
  end if;

  j := public.aos_cia_email_queue_request_v2('00000000-0000-0000-0000-000000000001',v_req);
  if coalesce((j->>'ok')::boolean,false) is not true or j->>'state' <> 'QUEUED' then
    raise exception 'F16_DELIVERY_TEST_FAIL: queue %',j;
  end if;

  j := public.aos_cia_email_queue_request_v2('00000000-0000-0000-0000-000000000001',v_req);
  if coalesce((j->>'ok')::boolean,false) is not true or coalesce((j->>'idempotent')::boolean,false) is not true then
    raise exception 'F16_DELIVERY_TEST_FAIL: queue idempotency %',j;
  end if;

  j := public.aos_cia_email_claim_dispatch_v2(v_req);
  if coalesce((j->>'ok')::boolean,false) is not true or coalesce((j->>'send_allowed')::boolean,false) is not true
     or j->>'state' <> 'DISPATCHING' or j->>'recipient_email' <> 'alpha@example.test' then
    raise exception 'F16_DELIVERY_TEST_FAIL: dispatch claim %',j;
  end if;
  if j->'render_context'->>'name' <> 'Synthetic Recipient' then
    raise exception 'F16_DELIVERY_TEST_FAIL: immutable render context missing %',j;
  end if;

  j := public.aos_cia_email_claim_dispatch_v2(v_req);
  if coalesce((j->>'send_allowed')::boolean,true) is true or coalesce((j->>'in_progress')::boolean,false) is not true then
    raise exception 'F16_DELIVERY_TEST_FAIL: duplicate concurrent claim %',j;
  end if;

  j := public.aos_cia_email_record_dispatch_result_v2(
    v_req,true,'RESEND','synthetic-provider-message-001',null,jsonb_build_object('synthetic',true)
  );
  if j->>'state' <> 'ACCEPTED' then raise exception 'F16_DELIVERY_TEST_FAIL: provider accept %',j; end if;

  j := public.aos_cia_email_record_dispatch_result_v2(
    v_req,true,'RESEND','synthetic-provider-message-001',null,jsonb_build_object('synthetic',true)
  );
  if coalesce((j->>'idempotent')::boolean,false) is not true then
    raise exception 'F16_DELIVERY_TEST_FAIL: provider accept idempotency %',j;
  end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-delivered-001','synthetic-provider-message-001','email.delivered',now(),jsonb_build_object('synthetic',true)
  );
  if j->>'state' <> 'DELIVERED' then raise exception 'F16_DELIVERY_TEST_FAIL: delivered event %',j; end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-delivered-001','synthetic-provider-message-001','email.delivered',now(),jsonb_build_object('synthetic',true)
  );
  if coalesce((j->>'idempotent')::boolean,false) is not true then
    raise exception 'F16_DELIVERY_TEST_FAIL: webhook replay dedup %',j;
  end if;

  j := public.aos_cia_email_ingest_provider_event_v2(
    'synthetic-event-complaint-001','synthetic-provider-message-001','email.complained',now(),jsonb_build_object('synthetic',true)
  );
  if j->>'state' <> 'COMPLAINED' then
    raise exception 'F16_DELIVERY_TEST_FAIL: post-delivery complaint transition %',j;
  end if;
end
$test$;

do $test$
declare
  j jsonb;
  v_tpl uuid;
  v_req uuid;
begin
  j := public.aos_cia_email_template_version_create_v1(
    '00000000-0000-0000-0000-000000000001','synthetic.marketing.suppression-recheck','MARKETING',
    'Suppression test','<p>Suppression test</p>',array[]::text[],null
  );
  v_tpl := (j->>'template_version_id')::uuid;
  perform public.aos_cia_email_template_version_activate_v1('00000000-0000-0000-0000-000000000001',v_tpl);
  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','synthetic-contact-1',v_tpl,'{}'::jsonb
  );
  v_req := (j->>'request_id')::uuid;
  if v_req is null then raise exception 'F16_DELIVERY_TEST_FAIL: suppression request prepare %',j; end if;

  update public.aos_cia_email_recipient_controls
     set global_suppressed=true,suppression_reason='SYNTHETIC_TEST',updated_by_user_id='00000000-0000-0000-0000-000000000001'
   where contact_key='synthetic-contact-1';

  j := public.aos_cia_email_queue_request_v2('00000000-0000-0000-0000-000000000001',v_req);
  if coalesce((j->>'ok')::boolean,true) is true or j->>'state' <> 'CANCELLED' then
    raise exception 'F16_DELIVERY_TEST_FAIL: suppression was not rechecked at queue %',j;
  end if;

  update public.aos_cia_email_recipient_controls
     set global_suppressed=false,suppression_reason=null,updated_by_user_id='00000000-0000-0000-0000-000000000001'
   where contact_key='synthetic-contact-1';
end
$test$;

do $test$
declare j jsonb;
begin
  j := public.aos_cia_email_admin_gateway_v2('wrong-token','READINESS','{}'::jsonb);
  if j->>'error' <> 'UNAUTHORIZED' then raise exception 'F16_DELIVERY_TEST_FAIL: gateway v2 invalid token %',j; end if;

  j := public.aos_cia_email_admin_gateway_v2('synthetic-admin-token','READINESS','{}'::jsonb);
  if coalesce((j->>'ok')::boolean,false) is not true or coalesce((j->>'ready_for_f17')::boolean,true) is true then
    raise exception 'F16_DELIVERY_TEST_FAIL: readiness must remain false before production gates %',j;
  end if;
  if coalesce((j->'release_gates'->>'canary_passed')::boolean,true) is true
     or coalesce((j->'release_gates'->>'rollback_verified')::boolean,true) is true then
    raise exception 'F16_DELIVERY_TEST_FAIL: production evidence gates defaulted open %',j;
  end if;
end
$test$;

do $test$
begin
  if not has_function_privilege('anon','public.aos_cia_email_admin_gateway_v2(text,text,jsonb)','EXECUTE') then
    raise exception 'F16_DELIVERY_TEST_FAIL: browser gateway v2 missing';
  end if;
  if has_function_privilege('anon','public.aos_cia_email_claim_dispatch_v2(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_cia_email_claim_dispatch_v2(uuid)','EXECUTE') then
    raise exception 'F16_DELIVERY_TEST_FAIL: internal dispatch claim leaked';
  end if;
  if has_function_privilege('anon','public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb)','EXECUTE') then
    raise exception 'F16_DELIVERY_TEST_FAIL: provider event ingestion leaked';
  end if;
  if has_function_privilege('anon','public.aos_cia_email_release_mark_v1(text,boolean,text)','EXECUTE') then
    raise exception 'F16_DELIVERY_TEST_FAIL: release evidence mutator leaked';
  end if;
  if has_table_privilege('anon','public.aos_cia_email_release_state','SELECT')
     or has_table_privilege('authenticated','public.aos_cia_email_release_state','SELECT') then
    raise exception 'F16_DELIVERY_TEST_FAIL: release state table leaked';
  end if;
end
$test$;

select 'CIA_PHASE16_DELIVERY_CONTRACTS=PASS' as result;
select 'PROVIDER_NETWORK_CALLS=0' as provider_policy;
select 'F17_READINESS_DEFAULT=false' as readiness_policy;
