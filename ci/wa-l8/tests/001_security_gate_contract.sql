\set ON_ERROR_STOP on

-- WA-L8 TEST ONLY. Synthetic identities/numbers live only in isolated local CI.

-- Two deterministic conversations: one inside the 24h service window, one outside.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_address,contact_address_type,contact_name,phone_number_id,state,opened_at,updated_at
) values
('88888888-8888-4888-8888-888888888801'::uuid,'pn-l8:51970000001','51970000001','51970000001','PHONE','L8 WINDOW','pn-l8','NEW',now()-interval '2 hours',now()),
('88888888-8888-4888-8888-888888888802'::uuid,'pn-l8:51970000002','51970000002','51970000002','PHONE','L8 OUTSIDE','pn-l8','NEW',now()-interval '3 days',now())
on conflict(id) do nothing;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values
('wamid.l8.in.window','INBOUND','51970000001','519999111222','pn-l8','text','Hola, quiero información','received',now()-interval '1 hour',now()-interval '1 hour','88888888-8888-4888-8888-888888888801'::uuid),
('wamid.l8.in.old','INBOUND','51970000002','519999111222','pn-l8','text','Hola','received',now()-interval '2 days',now()-interval '2 days','88888888-8888-4888-8888-888888888802'::uuid)
on conflict(provider_message_id) do nothing;

-- Unauthorized consent administration fails closed.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_consent_record_v1('bad-token','88888888-8888-4888-8888-888888888801'::uuid,'OPT_IN','CUSTOMER_REQUEST','TEST:L8:BAD');
  if coalesce((r->>'ok')::boolean,false) or r->>'error'<>'WA_L8_ADMIN_2FA_REQUIRED' then raise exception 'WA_L8_UNAUTHORIZED_CONSENT_FAIL:%',r; end if;
end $$;

-- Service-window response passes the policy preflight, but L4 remains AUTO_OFF.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888801'::uuid,'PHONE','51970000001','text',null,'l8:window:preflight:00000001');
  if r->>'decision'<>'PASS' or r->>'reason'<>'WA_L8_SERVICE_WINDOW_OK' or (r->>'service_window_open')::boolean is not true then
    raise exception 'WA_L8_SERVICE_WINDOW_FAIL:%',r;
  end if;

  r:=public.aos_wa_l4_authorize_autonomous_send_v1(
    '88888888-8888-4888-8888-888888888801'::uuid,'PHONE','51970000001','text',null,
    'l8:window:wrapper:00000001',repeat('a',64),'ALLOW','NOT_REQUIRED',false,null);
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_AUTO_OFF' or r->>'l8_preflight'<>'PASS' then
    raise exception 'WA_L8_WRAPPER_DID_NOT_PRESERVE_L4_SAFE_OFF:%',r;
  end if;
end $$;

-- Explicit STOP has priority over the open service window.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values (
  'wamid.l8.stop','INBOUND','51970000001','519999111222','pn-l8','text','No más mensajes','received',now(),now(),
  '88888888-8888-4888-8888-888888888801'::uuid
) on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888801'::uuid,'PHONE','51970000001','text',null,'l8:stop:preflight:00000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L8_STOP_FAIL:%',r; end if;
end $$;

-- A later, evidence-backed opt-in can supersede the earlier STOP.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_consent_record_v1(
    'admin-token-111111111111111111111111111111111111',
    '88888888-8888-4888-8888-888888888801'::uuid,'OPT_IN','CUSTOMER_REQUEST','TEST:L8:CUSTOMER_REOPTIN');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_REOPTIN_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888801'::uuid,'PHONE','51970000001','text',null,'l8:reoptin:preflight:0001');
  if r->>'decision'<>'PASS' then raise exception 'WA_L8_REOPTIN_FAIL:%',r; end if;
end $$;

-- Outside 24h: free-form is blocked; template still requires explicit opt-in.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888802'::uuid,'PHONE','51970000002','text',null,'l8:outside:text:000000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H' then raise exception 'WA_L8_OUTSIDE_TEXT_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888802'::uuid,'PHONE','51970000002','template','recordatorio','l8:outside:tpl:000000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_BUSINESS_INITIATED_OPT_IN_REQUIRED' then raise exception 'WA_L8_OUTSIDE_TEMPLATE_NO_OPTIN_FAIL:%',r; end if;

  r:=public.aos_wa_l8_consent_record_v1(
    'admin-token-111111111111111111111111111111111111',
    '88888888-8888-4888-8888-888888888802'::uuid,'OPT_IN','PRIVACY_FORM','TEST:L8:FORM:CONSENT');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_OUTSIDE_OPTIN_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888802'::uuid,'PHONE','51970000002','template','recordatorio','l8:outside:tpl:optin:0001');
  if r->>'decision'<>'PASS' or r->>'reason'<>'WA_L8_BUSINESS_INITIATED_OPT_IN_OK' then raise exception 'WA_L8_OUTSIDE_OPTIN_FAIL:%',r; end if;
end $$;

-- Recipient mismatch is a handoff, never an autonomous send.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '88888888-8888-4888-8888-888888888801'::uuid,'PHONE','51970000999','text',null,'l8:mismatch:preflight:0001');
  if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L8_RECIPIENT_CONVERSATION_MISMATCH' then raise exception 'WA_L8_RECIPIENT_MISMATCH_FAIL:%',r; end if;
end $$;

-- Consent/preflight ledgers are immutable.
do $$ begin
  begin
    update public.aos_wa_l8_consent_events_v1 set source='ADMIN_EVIDENCE';
    raise exception 'WA_L8_CONSENT_UPDATE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
  begin
    delete from public.aos_wa_l8_preflight_decisions_v1;
    raise exception 'WA_L8_PREFLIGHT_DELETE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
end $$;

-- Meta 2026 evidence: pricing.type is read from sanitized status events, market is
-- resolved from recipient strong transport data, and non-billable remains KNOWN zero.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  pricing_category,pricing_model,billable,provider_timestamp,sent_at,delivered_at,conversation_id
) values
('wamid.l8.meta.free','OUTBOUND','519999111222','51970000001','pn-l8','text','free','delivered','service','PMP',false,now(),now(),now(),'88888888-8888-4888-8888-888888888801'::uuid),
('wamid.l8.meta.paid','OUTBOUND','519999111222','51970000001','pn-l8','template',null,'delivered','marketing','PMP',true,now(),now(),now(),'88888888-8888-4888-8888-888888888801'::uuid)
on conflict(provider_message_id) do nothing;

insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values
('status:wamid.l8.meta.free:delivered:l8','message.status','wamid.l8.meta.free','delivered',jsonb_build_object('pricing_category','service','pricing_model','PMP','pricing_type','free_customer_service','billable',false)),
('status:wamid.l8.meta.paid:delivered:l8','message.status','wamid.l8.meta.paid','delivered',jsonb_build_object('pricing_category','marketing','pricing_model','PMP','pricing_type','regular','billable',true))
on conflict(event_key) do nothing;

do $$ declare r jsonb; e record; begin
  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object('provider','META_WHATSAPP','pricing_kind','META_MESSAGE','pricing_category','marketing','pricing_model','PMP',
      'market_code','PE','currency','USD','flat_cost',0.03,'authority_grade','VERIFIED','evidence_ref','TEST:L8:PE_RATE','valid_from','2026-01-01T00:00:00Z'));
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_PE_RATE_APPEND_FAIL:%',r; end if;

  select * into e from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l8.meta.free';
  if e.cost_state<>'KNOWN' or e.cost_amount<>0 or e.pricing_type<>'free_customer_service' or e.billing_market_code<>'PE' then
    raise exception 'WA_L8_META_FREE_EVIDENCE_FAIL:%/%/%/%',e.cost_state,e.cost_amount,e.pricing_type,e.billing_market_code;
  end if;
  select * into e from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l8.meta.paid';
  if e.cost_state<>'KNOWN' or e.cost_amount<>0.03 or e.cost_currency<>'USD' or e.pricing_type<>'regular' or e.billing_market_code<>'PE' then
    raise exception 'WA_L8_META_MARKET_RATE_FAIL:%/%/%/%/%',e.cost_state,e.cost_amount,e.cost_currency,e.pricing_type,e.billing_market_code;
  end if;
end $$;

-- Meta GLOBAL authority is forbidden after L8; AI GLOBAL remains valid.
do $$ begin
  begin
    insert into public.aos_wa_l7_pricing_authority_v1(
      provider,pricing_kind,pricing_category,pricing_model,market_code,currency,flat_cost,authority_grade,evidence_ref,valid_from,created_by
    ) values ('META_WHATSAPP','META_MESSAGE','service','PMP','GLOBAL','USD',0.03,'VERIFIED','TEST:L8:INVALID_GLOBAL',now(),'11111111-1111-4111-8111-111111111111'::uuid);
    raise exception 'WA_L8_META_GLOBAL_UNEXPECTEDLY_ALLOWED';
  exception when check_violation then null; end;
end $$;

-- Monthly view is business-number/market scoped and uses provider-observed billable state.
do $$ declare n bigint; b bigint; nb bigint; begin
  select outbound_messages,provider_billable_messages,provider_nonbillable_messages
    into n,b,nb
  from public.aos_wa_l8_meta_monthly_usage_v1
  where business_phone_number_id='pn-l8' and billing_market_code='PE' and pricing_category='marketing';
  if n is null or n<1 or b<1 then raise exception 'WA_L8_MONTHLY_USAGE_PAID_FAIL:%/%/%',n,b,nb; end if;
end $$;

-- Least privilege: browser writes are absent; service role retains only runtime-needs.
do $$ begin
  if has_table_privilege('anon','public.aos_wa_l8_consent_events_v1','SELECT')
     or has_table_privilege('authenticated','public.aos_wa_l8_preflight_decisions_v1','SELECT') then raise exception 'WA_L8_BROWSER_AUDIT_LEAK'; end if;
  if has_table_privilege('service_role','public.aos_wa_messages_v1','DELETE')
     or has_table_privilege('service_role','public.aos_wa_messages_v1','TRUNCATE') then raise exception 'WA_L8_MESSAGE_DESTRUCTIVE_PRIVILEGE'; end if;
  if not has_table_privilege('service_role','public.aos_wa_messages_v1','INSERT')
     or not has_table_privilege('service_role','public.aos_wa_messages_v1','UPDATE') then raise exception 'WA_L8_GATEWAY_REQUIRED_PRIVILEGE_REMOVED'; end if;
  if has_table_privilege('service_role','public.aos_wa_ai_runs_v1','UPDATE')
     or has_table_privilege('service_role','public.aos_wa_ai_runs_v1','DELETE') then raise exception 'WA_L8_AI_LEDGER_MUTABLE'; end if;
  if has_table_privilege('service_role','public.aos_booking_operations_v2','INSERT')
     or has_table_privilege('service_role','public.aos_booking_operations_v2','UPDATE')
     or has_table_privilege('service_role','public.aos_booking_operations_v2','DELETE') then raise exception 'WA_L8_BOOKING_DIRECT_DML_STILL_OPEN'; end if;
  if not has_table_privilege('service_role','public.aos_booking_operations_v2','SELECT') then raise exception 'WA_L8_BOOKING_READ_REMOVED'; end if;
end $$;

-- AI audit table must remain metadata-only: no raw prompt/reply/body columns.
do $$ begin
  if exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='aos_wa_ai_runs_v1'
      and lower(column_name) in ('prompt','prompt_text','raw_prompt','response','reply','raw_reply','message_body','messages')
  ) then raise exception 'WA_L8_AI_TRACE_RAW_CONTENT_COLUMN'; end if;
end $$;

-- Safety remains dormant after every canary fixture.
do $$ declare s jsonb; begin
  s:=public.aos_wa_l8_security_status_v1();
  if s->>'mode'<>'AUTO_OFF' or (s->>'kill_switch_engaged')::boolean is not true
     or (s->>'auto_reply_enabled')::boolean or (s->>'ai_send_enabled')::boolean
     or (s->>'auto_routing_enabled')::boolean or (s->>'human_send_enabled')::boolean is not true then
    raise exception 'WA_L8_SAFE_OFF_FAIL:%',s;
  end if;
  if (s->>'autonomous_outbound')::integer<>0 then raise exception 'WA_L8_AUTONOMOUS_OUTBOUND_NOT_ZERO:%',s; end if;
end $$;

select 'WA_L8_SECURITY_GATE_CONTRACT_PASS' as result;
