-- F16 synthetic render-context hardening regression tests.

do $test$
declare
  j jsonb;
  v_tpl uuid;
  v_req uuid;
begin
  j := public.aos_cia_email_template_version_create_v1(
    '00000000-0000-0000-0000-000000000001','synthetic.render.required','MARKETING',
    'Hello {{name}}','<p>Hello {{name}} — {{code}}</p>',array['name','code'],null
  );
  v_tpl := (j->>'template_version_id')::uuid;
  perform public.aos_cia_email_template_version_activate_v1('00000000-0000-0000-0000-000000000001',v_tpl);

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'synthetic-contact-1',v_tpl,jsonb_build_object('name','Synthetic')
  );
  if j->>'error' <> 'RENDER_CONTEXT_MISSING' or coalesce((j->>'send_performed')::boolean,true) is true then
    raise exception 'F16_RENDER_CONTEXT_TEST_FAIL: missing variable did not fail closed %',j;
  end if;
  if exists(select 1 from public.aos_cia_email_send_requests where template_version_id=v_tpl) then
    raise exception 'F16_RENDER_CONTEXT_TEST_FAIL: malformed immutable request was persisted';
  end if;

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'synthetic-contact-1',v_tpl,jsonb_build_object('name','Synthetic','code','A1')
  );
  if coalesce((j->>'ok')::boolean,false) is not true then
    raise exception 'F16_RENDER_CONTEXT_TEST_FAIL: complete context rejected %',j;
  end if;
  v_req := (j->>'request_id')::uuid;

  j := public.aos_cia_email_prepare_request_v2(
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'synthetic-contact-1',v_tpl,jsonb_build_object('name','Synthetic','code','DIFFERENT')
  );
  if j->>'error' <> 'IDEMPOTENCY_CONTEXT_MISMATCH' or (j->>'request_id')::uuid <> v_req then
    raise exception 'F16_RENDER_CONTEXT_TEST_FAIL: context mismatch did not fail closed %',j;
  end if;
end
$test$;

select 'CIA_PHASE16_RENDER_CONTEXT_HARDENING=PASS' as result;
