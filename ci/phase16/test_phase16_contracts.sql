-- CIA F16 synthetic contract tests. Zero PII/PHI and zero provider calls.

insert into public.aos_usuarios(id,nombre) values
('00000000-0000-0000-0000-000000000001','Synthetic Admin')
on conflict (id) do update set nombre=excluded.nombre;

insert into public.aos_audiencia_activaciones(id,audiencia_id,audiencia_version_id) values
('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003');

insert into public.aos_audiencia_activacion_config(activacion_id,nombre,purpose,channel,mode,baseline_count,created_by_user_id) values
('10000000-0000-0000-0000-000000000001','Synthetic Email Active','MARKETING','EMAIL','BATCH',4,'00000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002','Synthetic Email Draft','MARKETING','EMAIL','BATCH',1,'00000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000003','Synthetic SMS Active','MARKETING','SMS','BATCH',1,'00000000-0000-0000-0000-000000000001');

insert into public.aos_audiencia_activacion_estado(activacion_id,estado,updated_by_user_id,started_at) values
('10000000-0000-0000-0000-000000000001','ACTIVE','00000000-0000-0000-0000-000000000001',now()),
('10000000-0000-0000-0000-000000000002','DRAFT','00000000-0000-0000-0000-000000000001',null),
('10000000-0000-0000-0000-000000000003','ACTIVE','00000000-0000-0000-0000-000000000001',now());

insert into public.aos_cia_activation_members_fixture(activation_id,contact_key) values
('10000000-0000-0000-0000-000000000001','synthetic-contact-1'),
('10000000-0000-0000-0000-000000000001','synthetic-contact-2'),
('10000000-0000-0000-0000-000000000001','synthetic-contact-3'),
('10000000-0000-0000-0000-000000000001','synthetic-contact-4'),
('10000000-0000-0000-0000-000000000002','synthetic-contact-1'),
('10000000-0000-0000-0000-000000000003','synthetic-contact-1');

insert into public.aos_cia_audience_source_v1_1(contact_key,identity_conflict,canonical_email,email_valid,email_bounced_count,facts_observed_at,email_last_event_at) values
('synthetic-contact-1',false,'alpha@example.test',true,0,now(),null),
('synthetic-contact-2',false,'bounce@example.test',true,1,now(),now()),
('synthetic-contact-3',true,'conflict@example.test',true,0,now(),null),
('synthetic-contact-4',false,null,false,0,now(),null);

do $test$
declare
  j jsonb;
begin
  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','synthetic-contact-1','MARKETING');
  if j->>'eligibility_status' <> 'UNKNOWN' or j->>'reason_code' <> 'MARKETING_CONSENT_UNKNOWN' or (j->>'send_allowed')::boolean then
    raise exception 'F16_TEST_FAIL: missing marketing consent must fail closed: %',j;
  end if;

  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000003','synthetic-contact-1','MARKETING');
  if j->>'eligibility_status' <> 'BLOCKED' or j->>'reason_code' <> 'CHANNEL_NOT_EMAIL' then
    raise exception 'F16_TEST_FAIL: non-email activation must block: %',j;
  end if;

  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','not-a-member','MARKETING');
  if j->>'reason_code' <> 'NOT_ACTIVATION_MEMBER' then
    raise exception 'F16_TEST_FAIL: non-member must block: %',j;
  end if;

  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','synthetic-contact-2','MARKETING');
  if j->>'eligibility_status' <> 'UNKNOWN' or j->>'reason_code' <> 'BOUNCE_REVIEW_REQUIRED' then
    raise exception 'F16_TEST_FAIL: bounce history must fail closed: %',j;
  end if;

  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','synthetic-contact-3','MARKETING');
  if j->>'eligibility_status' <> 'BLOCKED' or j->>'reason_code' <> 'IDENTITY_CONFLICT' then
    raise exception 'F16_TEST_FAIL: identity conflict must block: %',j;
  end if;

  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','synthetic-contact-4','MARKETING');
  if j->>'eligibility_status' <> 'BLOCKED' or j->>'reason_code' <> 'EMAIL_MISSING' then
    raise exception 'F16_TEST_FAIL: missing email must block: %',j;
  end if;
end
$test$;

insert into public.aos_cia_email_recipient_controls(contact_key,marketing_consent,global_suppressed,source,source_updated_at,updated_by_user_id)
values('synthetic-contact-1','ALLOWED',false,'SYNTHETIC_FIXTURE',now(),'00000000-0000-0000-0000-000000000001');

do $test$
declare j jsonb;
begin
  j := public.aos_cia_email_eligibility_v1('10000000-0000-0000-0000-000000000001','synthetic-contact-1','MARKETING');
  if j->>'eligibility_status' <> 'ELIGIBLE' or j->>'consent_status' <> 'ALLOWED' or (j->>'send_allowed')::boolean then
    raise exception 'F16_TEST_FAIL: allowed marketing preview wrong: %',j;
  end if;
  if (select count(*) from public.aos_cia_email_recipient_control_events where contact_key='synthetic-contact-1' and event_type='CREATED') <> 1 then
    raise exception 'F16_TEST_FAIL: control audit event missing';
  end if;
end
$test$;

do $test$
declare
  j jsonb;
  v_tpl uuid;
  v_req uuid;
  v_req2 uuid;
begin
  j := public.aos_cia_email_template_version_create_v1(
    '00000000-0000-0000-0000-000000000001','synthetic.marketing.welcome','MARKETING',
    'Synthetic subject {{name}}','<p>Synthetic {{name}}</p>',array['name'],null
  );
  if coalesce((j->>'ok')::boolean,false) is not true or j->>'state' <> 'SHADOW' then
    raise exception 'F16_TEST_FAIL: template create failed: %',j;
  end if;
  v_tpl := (j->>'template_version_id')::uuid;

  j := public.aos_cia_email_template_version_activate_v1('00000000-0000-0000-0000-000000000001',v_tpl);
  if j->>'state' <> 'ACTIVE' then raise exception 'F16_TEST_FAIL: template activate failed: %',j; end if;

  j := public.aos_cia_email_prepare_request_v1(
    '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','synthetic-contact-1',v_tpl
  );
  if coalesce((j->>'ok')::boolean,false) or j->>'error' <> 'ACTIVATION_NOT_ACTIVE' then
    raise exception 'F16_TEST_FAIL: draft activation prepared request: %',j;
  end if;

  j := public.aos_cia_email_prepare_request_v1(
    '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','synthetic-contact-1',v_tpl
  );
  if coalesce((j->>'ok')::boolean,false) is not true or j->>'state' <> 'PREPARED' or (j->>'send_performed')::boolean then
    raise exception 'F16_TEST_FAIL: prepare request failed: %',j;
  end if;
  v_req := (j->>'request_id')::uuid;

  j := public.aos_cia_email_prepare_request_v1(
    '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','synthetic-contact-1',v_tpl
  );
  v_req2 := (j->>'request_id')::uuid;
  if v_req2 <> v_req or coalesce((j->>'idempotent')::boolean,false) is not true then
    raise exception 'F16_TEST_FAIL: idempotency failed: %',j;
  end if;

  if (select count(*) from public.aos_cia_email_send_requests) <> 1 then
    raise exception 'F16_TEST_FAIL: duplicate request persisted';
  end if;
  if (select count(*) from public.aos_cia_email_send_events where request_id=v_req and event_type='PREPARED') <> 1 then
    raise exception 'F16_TEST_FAIL: prepared audit event count wrong';
  end if;
end
$test$;

do $test$
declare j jsonb;
begin
  j := public.aos_cia_email_admin_gateway_v1('wrong-token','READINESS','{}'::jsonb);
  if j->>'error' <> 'UNAUTHORIZED' then raise exception 'F16_TEST_FAIL: invalid admin token not blocked: %',j; end if;

  j := public.aos_cia_email_admin_gateway_v1('synthetic-admin-token','PREVIEW',jsonb_build_object(
    'activation_id','10000000-0000-0000-0000-000000000001','purpose','MARKETING','limit',10,'offset',0
  ));
  if coalesce((j->>'ok')::boolean,false) is not true or (j->>'send_allowed')::boolean then
    raise exception 'F16_TEST_FAIL: gateway preview must be non-sending: %',j;
  end if;

  j := public.aos_cia_email_admin_gateway_v1('synthetic-admin-token','READINESS','{}'::jsonb);
  if coalesce((j->>'ok')::boolean,false) is not true or coalesce((j->>'ready_for_f17')::boolean,true) is true or coalesce((j->>'delivery_enabled')::boolean,true) is true then
    raise exception 'F16_TEST_FAIL: interim readiness semantics wrong: %',j;
  end if;
end
$test$;

do $test$
begin
  if has_table_privilege('anon','public.aos_cia_email_send_requests','SELECT')
     or has_table_privilege('anon','public.aos_cia_email_send_requests','INSERT')
     or has_table_privilege('authenticated','public.aos_cia_email_send_requests','SELECT')
     or has_table_privilege('authenticated','public.aos_cia_email_send_requests','INSERT') then
    raise exception 'F16_TEST_FAIL: direct request table privilege leaked';
  end if;
  if has_table_privilege('anon','public.aos_cia_email_recipient_controls','SELECT')
     or has_table_privilege('authenticated','public.aos_cia_email_recipient_controls','SELECT') then
    raise exception 'F16_TEST_FAIL: direct control table privilege leaked';
  end if;
  if not has_function_privilege('anon','public.aos_cia_email_admin_gateway_v1(text,text,jsonb)','EXECUTE') then
    raise exception 'F16_TEST_FAIL: governed browser gateway not executable';
  end if;
  if has_function_privilege('anon','public.aos_cia_email_prepare_request_v1(uuid,uuid,text,uuid)','EXECUTE') then
    raise exception 'F16_TEST_FAIL: internal prepare function exposed';
  end if;
end
$test$;

do $test$
declare v_id uuid;
begin
  select id into v_id from public.aos_cia_email_send_requests limit 1;
  begin
    update public.aos_cia_email_send_requests set state='DELIVERED' where id=v_id;
    raise exception 'F16_TEST_FAIL: illegal transition unexpectedly accepted';
  exception when others then
    if sqlerrm like 'F16_TEST_FAIL:%' then raise; end if;
    if sqlerrm not like 'EMAIL_SEND_REQUEST_INVALID_TRANSITION:%' then raise; end if;
  end;

  begin
    update public.aos_cia_email_send_requests set contact_key='mutated-contact' where id=v_id;
    raise exception 'F16_TEST_FAIL: immutable request identity unexpectedly changed';
  exception when others then
    if sqlerrm like 'F16_TEST_FAIL:%' then raise; end if;
    if sqlerrm <> 'EMAIL_SEND_REQUEST_IDENTITY_IMMUTABLE' then raise; end if;
  end;

  begin
    update public.aos_cia_email_send_events set event_type='MUTATED' where request_id=v_id;
    raise exception 'F16_TEST_FAIL: append-only event unexpectedly changed';
  exception when others then
    if sqlerrm like 'F16_TEST_FAIL:%' then raise; end if;
    if sqlerrm <> 'EMAIL_AUDIT_APPEND_ONLY' then raise; end if;
  end;
end
$test$;

select 'CIA_PHASE16_CONTRACTS=PASS' as result;
select 'SYNTHETIC_ONLY=PASS' as fixture_policy;
select 'PROVIDER_CALLS=0' as provider_policy;
select 'DELIVERY_ENABLED=false' as delivery_policy;
