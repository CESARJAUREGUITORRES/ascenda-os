\set ON_ERROR_STOP on

-- Object and security contracts.
do $$
declare r text; c int;
begin
  select count(*) into c from pg_class x join pg_namespace n on n.oid=x.relnamespace
  where n.nspname='public' and x.relname in (
    'aos_cia_channel_recipient_controls_v1','aos_cia_channel_send_requests_v1','aos_cia_channel_send_events_v1','aos_cia_channel_inbound_facts_v1','aos_cia_channel_release_state'
  ) and x.relkind='r';
  if c <> 5 then raise exception 'F17_TABLE_COUNT_EXPECTED_5_GOT_%',c; end if;

  foreach r in array array[
    'aos_cia_channel_recipient_controls_v1','aos_cia_channel_send_requests_v1','aos_cia_channel_send_events_v1','aos_cia_channel_inbound_facts_v1','aos_cia_channel_release_state'
  ] loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid=('public.'||r)::regclass) then
      raise exception 'F17_RLS_FORCE_MISSING_%',r;
    end if;
    if has_table_privilege('anon','public.'||r,'SELECT') or has_table_privilege('anon','public.'||r,'INSERT') or has_table_privilege('anon','public.'||r,'UPDATE') or has_table_privilege('anon','public.'||r,'DELETE') then
      raise exception 'F17_ANON_DIRECT_ACCESS_%',r;
    end if;
    if has_table_privilege('authenticated','public.'||r,'SELECT') or has_table_privilege('authenticated','public.'||r,'INSERT') or has_table_privilege('authenticated','public.'||r,'UPDATE') or has_table_privilege('authenticated','public.'||r,'DELETE') then
      raise exception 'F17_AUTH_DIRECT_ACCESS_%',r;
    end if;
  end loop;

  if has_table_privilege('anon','public.aos_cia_whatsapp_bridge_v1','SELECT') or has_table_privilege('authenticated','public.aos_cia_whatsapp_bridge_v1','SELECT') then
    raise exception 'F17_BRIDGE_BROWSER_ACCESS';
  end if;
  if has_function_privilege('anon','public.aos_cia_channel_prepare_send_v1(jsonb)','EXECUTE') or has_function_privilege('authenticated','public.aos_cia_channel_prepare_send_v1(jsonb)','EXECUTE') then
    raise exception 'F17_PREPARE_BROWSER_EXECUTE';
  end if;
  if not has_function_privilege('service_role','public.aos_cia_channel_prepare_send_v1(jsonb)','EXECUTE') then
    raise exception 'F17_SERVICE_PREPARE_MISSING';
  end if;
end $$;

-- Bridge must exclude content/raw payload and preserve canonical identity semantics.
do $$
declare cols text[]; s text;
begin
  select array_agg(column_name order by ordinal_position) into cols
  from information_schema.columns where table_schema='public' and table_name='aos_cia_whatsapp_bridge_v1';
  if 'message_body'=any(cols) or 'raw_referral'=any(cols) then raise exception 'F17_BRIDGE_CONTENT_LEAK'; end if;
  select identity_status into s from public.aos_cia_whatsapp_bridge_v1 where provider_message_id='wamid.fixture.resolved';
  if s <> 'RESOLVED' then raise exception 'F17_BRIDGE_RESOLVED_EXPECTED_GOT_%',s; end if;
  select identity_status into s from public.aos_cia_whatsapp_bridge_v1 where provider_message_id='wamid.fixture.unresolved';
  if s <> 'UNRESOLVED' then raise exception 'F17_BRIDGE_UNRESOLVED_EXPECTED_GOT_%',s; end if;
end $$;

-- UNKNOWN consent/suppression must block.
do $$
declare r jsonb;
begin
  r := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','51999111222','purpose','fixture unknown','message_class','SESSION_TEXT',
    'idempotency_key','fixture-unknown-0001','activation_id','11111111-1111-4111-8111-111111111111'
  ));
  if r->>'state' <> 'BLOCKED' or coalesce((r->>'dispatch_allowed')::boolean,true) then
    raise exception 'F17_UNKNOWN_MUST_BLOCK_%',r;
  end if;
  if r->>'consent_status' <> 'UNKNOWN' or r->>'suppression_status' <> 'UNKNOWN' then
    raise exception 'F17_UNKNOWN_STATUS_MISMATCH_%',r;
  end if;
end $$;

-- Explicit ALLOWED+CLEAR makes request READY but still does not dispatch.
insert into public.aos_cia_channel_recipient_controls_v1(contact_key,channel,consent_status,suppression_status,source,evidence)
values ('999111222','WHATSAPP','ALLOWED','CLEAR','fixture','{"reason":"test"}')
on conflict(contact_key,channel) do update set consent_status='ALLOWED',suppression_status='CLEAR';

do $$
declare r1 jsonb; r2 jsonb; c int;
begin
  r1 := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','fixture allowed','message_class','SESSION_TEXT',
    'idempotency_key','fixture-allowed-0001','activation_id','11111111-1111-4111-8111-111111111111'
  ));
  if r1->>'state' <> 'READY' or coalesce((r1->>'dispatch_allowed')::boolean,false) is not true then
    raise exception 'F17_ALLOWED_NOT_READY_%',r1;
  end if;
  if exists(select 1 from public.aos_cia_channel_send_requests_v1 where id=(r1->>'request_id')::uuid and (provider is not null or provider_message_id is not null or dispatch_attempts<>0)) then
    raise exception 'F17_PREPARE_DISPATCHED_PROVIDER';
  end if;

  r2 := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','fixture changed retry','message_class','SESSION_TEXT',
    'idempotency_key','fixture-allowed-0001','activation_id','11111111-1111-4111-8111-111111111111'
  ));
  if r1->>'request_id' <> r2->>'request_id' then raise exception 'F17_IDEMPOTENCY_CHANGED_REQUEST'; end if;
  select count(*) into c from public.aos_cia_channel_send_requests_v1 where idempotency_key='fixture-allowed-0001';
  if c<>1 then raise exception 'F17_IDEMPOTENCY_ROW_COUNT_%',c; end if;
end $$;

-- SMS contract is provider-neutral and cannot spend/send merely by preparing.
insert into public.aos_cia_channel_recipient_controls_v1(contact_key,channel,consent_status,suppression_status,source)
values ('999111222','SMS','ALLOWED','CLEAR','fixture')
on conflict(contact_key,channel) do update set consent_status='ALLOWED',suppression_status='CLEAR';

do $$
declare r jsonb;
begin
  r := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','SMS','recipient_contact','999111222','purpose','fixture sms','message_class','TEXT',
    'idempotency_key','fixture-sms-allowed-01'
  ));
  if r->>'state'<>'READY' then raise exception 'F17_SMS_NOT_READY_%',r; end if;
  if exists(select 1 from public.aos_cia_channel_send_requests_v1 where id=(r->>'request_id')::uuid and (provider is not null or provider_message_id is not null or dispatch_attempts<>0)) then
    raise exception 'F17_SMS_PREPARE_SPEND_RISK';
  end if;
end $$;

-- Invalid inputs must fail closed.
do $$
begin
  begin
    perform public.aos_cia_channel_prepare_send_v1(jsonb_build_object('channel','WHATSAPP','recipient_contact','123','purpose','x','message_class','TEXT','idempotency_key','fixture-invalid-0001'));
    raise exception 'F17_INVALID_CONTACT_DID_NOT_FAIL';
  exception when sqlstate '22023' then null; end;

  begin
    perform public.aos_cia_channel_prepare_send_v1(jsonb_build_object('channel','TELEGRAM','recipient_contact','999111222','purpose','x','message_class','TEXT','idempotency_key','fixture-invalid-0002'));
    raise exception 'F17_INVALID_CHANNEL_DID_NOT_FAIL';
  exception when sqlstate '22023' then null; end;
end $$;

-- Provider event ingestion must be idempotent.
do $$
declare rid uuid; e1 jsonb; e2 jsonb; c int;
begin
  select id into rid from public.aos_cia_channel_send_requests_v1 where idempotency_key='fixture-allowed-0001';
  e1 := public.aos_cia_channel_record_event_v1(jsonb_build_object('request_id',rid,'channel','WHATSAPP','event_key','evt-fixture-0001','event_type','DELIVERED','provider_message_id','wamid.out.fixture','status','delivered'));
  e2 := public.aos_cia_channel_record_event_v1(jsonb_build_object('request_id',rid,'channel','WHATSAPP','event_key','evt-fixture-0001','event_type','DELIVERED','provider_message_id','wamid.out.fixture','status','delivered'));
  if coalesce((e1->>'inserted')::boolean,false) is not true then raise exception 'F17_EVENT_FIRST_NOT_INSERTED_%',e1; end if;
  if coalesce((e2->>'inserted')::boolean,true) is not false then raise exception 'F17_EVENT_REPLAY_INSERTED_%',e2; end if;
  select count(*) into c from public.aos_cia_channel_send_events_v1 where event_key='evt-fixture-0001';
  if c<>1 then raise exception 'F17_EVENT_REPLAY_COUNT_%',c; end if;
end $$;

-- Readiness starts fail-closed and can only become ready after all evidence gates.
do $$
declare r jsonb;
begin
  r := public.aos_cia_f18_readiness_v1();
  if r->>'status' <> 'IN_PROGRESS_MULTICHANNEL_GOVERNANCE' or coalesce((r->>'ready_for_f18')::boolean,true) then
    raise exception 'F17_READINESS_SHOULD_START_CLOSED_%',r;
  end if;
  if (r->>'governed_tables')::int<>5 or (r->>'rls_tables')::int<>5 or (r->>'illegal_send_states')::int<>0 then
    raise exception 'F17_READINESS_SECURITY_COUNTS_%',r;
  end if;
end $$;

select public.aos_cia_channel_set_release_gate_v1('WHATSAPP_BRIDGE_VALIDATED',true,'fixture bridge normalized without content duplication');
select public.aos_cia_channel_set_release_gate_v1('OUTBOUND_POLICY_VALIDATED',true,'fixture unknown blocked and allowed clear prepared idempotently');
select public.aos_cia_channel_set_release_gate_v1('WEBHOOK_REPLAY_VALIDATED',true,'fixture provider event replay deduplicated by event_key');
select public.aos_cia_channel_set_release_gate_v1('CANARY_PASSED',true,'synthetic fixed canary contract passed without provider dispatch');
select public.aos_cia_channel_set_release_gate_v1('ROLLBACK_VERIFIED',true,'synthetic rollback will be executed after this test');

do $$
declare r jsonb;
begin
  r := public.aos_cia_f18_readiness_v1();
  if r->>'status' <> 'READY_F18_MULTICHANNEL_CERTIFIED' or coalesce((r->>'ready_for_f18')::boolean,false) is not true then
    raise exception 'F17_READINESS_EXPECTED_READY_%',r;
  end if;
  if (r->'browser_direct_table_access'->>'anon')::boolean or (r->'browser_direct_table_access'->>'authenticated')::boolean then
    raise exception 'F17_READINESS_BROWSER_ACCESS_%',r;
  end if;
end $$;

select 'F17_MULTICHANNEL_CONTRACTS_PASS' as result;