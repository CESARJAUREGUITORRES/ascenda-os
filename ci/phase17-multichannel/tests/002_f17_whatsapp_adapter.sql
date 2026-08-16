\set ON_ERROR_STOP on

-- Adapter functions are service-only.
do $$
begin
  if has_function_privilege('anon','public.aos_cia_channel_register_canary_recipient_v1(jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_cia_channel_register_canary_recipient_v1(jsonb)','EXECUTE') then
    raise exception 'F17_CANARY_REGISTER_BROWSER_EXECUTE';
  end if;
  if not has_function_privilege('service_role','public.aos_cia_channel_mark_dispatch_v1(jsonb)','EXECUTE') then
    raise exception 'F17_DISPATCH_SERVICE_EXECUTE_MISSING';
  end if;
end $$;

-- Canary registration MUST require server-verified allowlist evidence.
do $$
begin
  begin
    perform public.aos_cia_channel_register_canary_recipient_v1(jsonb_build_object(
      'channel','WHATSAPP','recipient_contact','999111222','allowlist_verified',false
    ));
    raise exception 'F17_CANARY_REGISTER_WITHOUT_ALLOWLIST';
  exception when sqlstate '42501' then null; end;
end $$;

select public.aos_cia_channel_register_canary_recipient_v1(jsonb_build_object(
  'channel','WHATSAPP','recipient_contact','999111222','allowlist_verified',true,
  'requested_by_user_id','33333333-3333-4333-8333-333333333333','ttl_minutes',30
));

-- SYSTEM_CANARY may authorize an explicit canary, but MUST NOT authorize ordinary traffic.
do $$
declare c jsonb; n jsonb;
begin
  c := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','fixed synthetic canary','message_class','SESSION_TEXT',
    'idempotency_key','fixture-wa-canary-0001','requested_by_user_id','33333333-3333-4333-8333-333333333333',
    'context',jsonb_build_object('canary',true),
    'authorization_provenance',jsonb_build_object('allowlist_verified',true)
  ));
  if c->>'state'<>'READY' or coalesce((c->>'dispatch_allowed')::boolean,false) is not true then
    raise exception 'F17_CANARY_NOT_READY_%',c;
  end if;

  n := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','ordinary traffic must block','message_class','SESSION_TEXT',
    'idempotency_key','fixture-wa-normal-0001','requested_by_user_id','33333333-3333-4333-8333-333333333333',
    'context',jsonb_build_object('canary',false)
  ));
  if n->>'state'<>'BLOCKED' or coalesce((n->>'dispatch_allowed')::boolean,true) then
    raise exception 'F17_SYSTEM_CANARY_LEAKED_TO_NORMAL_%',n;
  end if;
end $$;

-- Expired canary must fail closed even in canary context.
update public.aos_cia_channel_recipient_controls_v1
set expires_at=now()-interval '1 minute'
where contact_key='999111222' and channel='WHATSAPP';

do $$
declare r jsonb;
begin
  r := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','expired canary','message_class','SESSION_TEXT',
    'idempotency_key','fixture-wa-expired-001','context',jsonb_build_object('canary',true)
  ));
  if r->>'state'<>'BLOCKED' or coalesce((r->>'dispatch_allowed')::boolean,true) then
    raise exception 'F17_EXPIRED_CANARY_NOT_BLOCKED_%',r;
  end if;
end $$;

-- Refresh canary and certify dispatch transition + idempotency.
select public.aos_cia_channel_register_canary_recipient_v1(jsonb_build_object(
  'channel','WHATSAPP','recipient_contact','999111222','allowlist_verified',true,'ttl_minutes',30
));

do $$
declare p jsonb; a1 jsonb; a2 jsonb; rid uuid; attempts int;
begin
  p := public.aos_cia_channel_prepare_send_v1(jsonb_build_object(
    'channel','WHATSAPP','recipient_contact','999111222','purpose','dispatch fixture','message_class','SESSION_TEXT',
    'idempotency_key','fixture-wa-dispatch-001','context',jsonb_build_object('canary',true)
  ));
  rid := (p->>'request_id')::uuid;
  a1 := public.aos_cia_channel_mark_dispatch_v1(jsonb_build_object(
    'request_id',rid,'outcome','ACCEPTED','provider','META_WHATSAPP','provider_message_id','wamid.fixture.accepted'
  ));
  a2 := public.aos_cia_channel_mark_dispatch_v1(jsonb_build_object(
    'request_id',rid,'outcome','ACCEPTED','provider','META_WHATSAPP','provider_message_id','wamid.fixture.accepted'
  ));
  if a1->>'state'<>'ACCEPTED' or coalesce((a1->>'idempotent')::boolean,true) then raise exception 'F17_DISPATCH_FIRST_BAD_%',a1; end if;
  if coalesce((a2->>'idempotent')::boolean,false) is not true then raise exception 'F17_DISPATCH_REPLAY_NOT_IDEMPOTENT_%',a2; end if;
  select dispatch_attempts into attempts from public.aos_cia_channel_send_requests_v1 where id=rid;
  if attempts<>1 then raise exception 'F17_DISPATCH_ATTEMPTS_EXPECTED_1_GOT_%',attempts; end if;
end $$;

-- Provider event linkage is idempotent; unknown provider messages are not fabricated.
do $$
declare e1 jsonb; e2 jsonb; u jsonb; c int;
begin
  e1 := public.aos_cia_channel_record_provider_event_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.fixture.accepted','event_key','status:fixture:delivered:1',
    'event_type','message.status','status','delivered','payload',jsonb_build_object('billable',false)
  ));
  e2 := public.aos_cia_channel_record_provider_event_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.fixture.accepted','event_key','status:fixture:delivered:1',
    'event_type','message.status','status','delivered','payload',jsonb_build_object('billable',false)
  ));
  if coalesce((e1->>'linked')::boolean,false) is not true or coalesce((e1->>'inserted')::boolean,false) is not true then raise exception 'F17_PROVIDER_EVENT_FIRST_BAD_%',e1; end if;
  if coalesce((e2->>'linked')::boolean,false) is not true or coalesce((e2->>'inserted')::boolean,true) is not false then raise exception 'F17_PROVIDER_EVENT_REPLAY_BAD_%',e2; end if;
  select count(*) into c from public.aos_cia_channel_send_events_v1 where event_key='status:fixture:delivered:1';
  if c<>1 then raise exception 'F17_PROVIDER_EVENT_COUNT_%',c; end if;

  u := public.aos_cia_channel_record_provider_event_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.unlinked','event_key','status:unlinked:1','event_type','message.status','status','delivered'
  ));
  if coalesce((u->>'linked')::boolean,true) is not false then raise exception 'F17_UNLINKED_EVENT_FABRICATED_%',u; end if;
end $$;

-- Inbound facts dedupe and identity status without message content.
do $$
declare r1 jsonb; r2 jsonb; u jsonb; c int;
begin
  r1 := public.aos_cia_channel_ingest_inbound_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.inbound.resolved','sender_contact','51999111222',
    'conversation_ref','22222222-2222-4222-8222-222222222222','message_type','text',
    'attribution_ref',jsonb_build_object('ad_id','ad-fixture')
  ));
  r2 := public.aos_cia_channel_ingest_inbound_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.inbound.resolved','sender_contact','51999111222',
    'conversation_ref','22222222-2222-4222-8222-222222222222','message_type','text'
  ));
  if r1->>'identity_status'<>'RESOLVED' or coalesce((r1->>'inserted')::boolean,false) is not true then raise exception 'F17_INBOUND_RESOLVED_BAD_%',r1; end if;
  if coalesce((r2->>'inserted')::boolean,true) is not false then raise exception 'F17_INBOUND_REPLAY_INSERTED_%',r2; end if;

  u := public.aos_cia_channel_ingest_inbound_v1(jsonb_build_object(
    'channel','WHATSAPP','provider_message_id','wamid.inbound.unknown','sender_contact','51999888777','message_type','text'
  ));
  if u->>'identity_status'<>'UNRESOLVED' then raise exception 'F17_INBOUND_UNKNOWN_NOT_UNRESOLVED_%',u; end if;

  select count(*) into c from information_schema.columns
  where table_schema='public' and table_name='aos_cia_channel_inbound_facts_v1' and column_name in ('message_body','raw_referral');
  if c<>0 then raise exception 'F17_INBOUND_CONTENT_COLUMN_LEAK'; end if;
end $$;

-- Governance remains structurally safe.
do $$
declare r jsonb;
begin
  r := public.aos_cia_f18_readiness_v1();
  if (r->>'illegal_send_states')::int<>0 then raise exception 'F17_ILLEGAL_SEND_STATE_AFTER_ADAPTER_TEST_%',r; end if;
  if (r->'browser_direct_table_access'->>'anon')::boolean or (r->'browser_direct_table_access'->>'authenticated')::boolean then raise exception 'F17_BROWSER_ACCESS_AFTER_ADAPTER_TEST_%',r; end if;
end $$;

select 'F17_WHATSAPP_ADAPTER_DB_PASS' as result;