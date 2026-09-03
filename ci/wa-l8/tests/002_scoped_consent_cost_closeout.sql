\set ON_ERROR_STOP on

-- WA-L8 final TEST ONLY canary. Synthetic numbers/identities never leave local CI.

-- Two conversations: one active service window, one deliberately outside 24h.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_address,contact_address_type,contact_name,phone_number_id,state,opened_at,updated_at
) values
('89888888-8888-4888-8888-888888888801'::uuid,'pn-l8v2:51971000001','51971000001','51971000001','PHONE','L8 V2 WINDOW','pn-l8v2','NEW',now()-interval '2 hours',now()),
('89888888-8888-4888-8888-888888888802'::uuid,'pn-l8v2:51971000002','51971000002','51971000002','PHONE','L8 V2 OUTSIDE','pn-l8v2','NEW',now()-interval '4 days',now())
on conflict(id) do nothing;

insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at)
values
('pn-l8v2','PHONE','51971000001','89888888-8888-4888-8888-888888888801'::uuid,true,now()-interval '2 hours',now()),
('pn-l8v2','PHONE','51971000002','89888888-8888-4888-8888-888888888802'::uuid,true,now()-interval '4 days',now())
on conflict(business_scope,alias_type,alias_value) do update set conversation_id=excluded.conversation_id,active=true,last_seen_at=excluded.last_seen_at;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values
('wamid.l8v2.window','INBOUND','51971000001','519999111222','pn-l8v2','text','Quiero información','received',now()-interval '1 hour',now()-interval '1 hour','89888888-8888-4888-8888-888888888801'::uuid),
('wamid.l8v2.old','INBOUND','51971000002','519999111222','pn-l8v2','text','Hola','received',now()-interval '3 days',now()-interval '3 days','89888888-8888-4888-8888-888888888802'::uuid)
on conflict(provider_message_id) do nothing;

-- Final authority invariant: the draft L8 table is inert; WA-7A.4 is sole authority.
do $$ begin
  if to_regclass('public.aos_wa_marketing_eligibility_events_v1') is null then raise exception 'WA_L8_V2_WA7A4_AUTHORITY_MISSING'; end if;
  if has_table_privilege('service_role','public.aos_wa_l8_consent_events_v1','INSERT') then raise exception 'WA_L8_V2_LEGACY_CONSENT_STILL_WRITABLE'; end if;
  if (select count(*) from public.aos_wa_l8_consent_events_v1)<>0 then raise exception 'WA_L8_V2_LEGACY_CONSENT_NOT_EMPTY'; end if;
end $$;

-- Inside the customer-service window the conversation remains natural: no extra
-- consent question is injected, while L4 still owns SAFE-OFF and final authority.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888801'::uuid,'PHONE','51971000001','text',null,'l8v2:window:preflight:0001');
  if r->>'decision'<>'PASS' or r->>'reason'<>'WA_L8_SERVICE_WINDOW_OK' or r->>'eligibility_scope'<>'SERVICE_WINDOW' then
    raise exception 'WA_L8_V2_SERVICE_WINDOW_FAIL:%',r;
  end if;
  r:=public.aos_wa_l4_authorize_autonomous_send_v1(
    '89888888-8888-4888-8888-888888888801'::uuid,'PHONE','51971000001','text',null,
    'l8v2:window:wrapper:000001',repeat('a',64),'ALLOW','NOT_REQUIRED',false,null);
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_AUTO_OFF' or r->>'l8_preflight'<>'PASS' then
    raise exception 'WA_L8_V2_L4_SAFE_OFF_FAIL:%',r;
  end if;
end $$;

-- Outside 24h free-form is impossible.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','text',null,'l8v2:outside:text:000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H' then
    raise exception 'WA_L8_V2_OUTSIDE_FREEFORM_FAIL:%',r;
  end if;
end $$;

-- Make one synthetic appointment template provider-verified in TEST so L8 can
-- classify it as UTILITY. Unknown templates remain conservatively MARKETING.
update public.aos_agenda_delivery_template_registry_v3
set provider_template_name='l8v2_utility_reminder',provider_verified=true,evidence_ref='TEST:L8V2:META_VERIFIED',updated_at=now()
where delivery_kind='REMINDER_TODAY' and channel='WHATSAPP' and site_scope='SAN ISIDRO';

do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_utility_reminder','l8v2:utility:no-consent:001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_SCOPED_ELIGIBILITY_REQUIRED' or r->>'eligibility_scope'<>'UTILITY' then
    raise exception 'WA_L8_V2_UTILITY_SCOPE_FAIL:%',r;
  end if;
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_marketing_followup','l8v2:marketing:no-consent:1');
  if r->>'decision'<>'BLOCK' or r->>'eligibility_scope'<>'MARKETING' then
    raise exception 'WA_L8_V2_MARKETING_SCOPE_FAIL:%',r;
  end if;
end $$;

-- Booking consent without extra UX: same affirmative confirming the booking is
-- accepted only when a versioned Utility disclosure was shown.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values (
  'wamid.l8v2.booking.confirm','INBOUND','51971000002','519999111222','pn-l8v2','text','Sí, confirmo','received',
  now()-interval '50 hours',now()-interval '50 hours','89888888-8888-4888-8888-888888888802'::uuid
) on conflict(provider_message_id) do nothing;

insert into public.aos_booking_operations_v2(
  id,idempotency_key,request_hash,operation_type,channel,actor_id,conversation_id,appointment_id,treatment_id,
  professional_ref,site,appointment_date,appointment_time,identity_state,status,response,created_at
)
select
  '89888888-8888-4888-8888-888888888810'::uuid,'l8v2-booking-op-000001',repeat('b',64),'BOOK','WHATSAPP',
  '11111111-1111-4111-8111-111111111111'::uuid,'89888888-8888-4888-8888-888888888802'::uuid,'L8V2-APT-1',s.id,
  'L8V2-PROF','SAN ISIDRO',current_date+2,'15:00'::time,'MATCH','BOOKED','{}'::jsonb,now()-interval '49 hours'
from public.aos_catalogo_servicios s
where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO' and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
order by s.id limit 1
on conflict(id) do nothing;

insert into public.aos_wa_l5_booking_events_v1(
  conversation_id,event_type,flow,state,revision,appointment_id,operation_id,metadata,created_at
) values
('89888888-8888-4888-8888-888888888802'::uuid,'CONFIRMED','BOOK','CONFIRMED',10,'L8V2-APT-1',null,
 jsonb_build_object('provider_message_id','wamid.l8v2.booking.confirm','raw_text_stored',false),now()-interval '50 hours'),
('89888888-8888-4888-8888-888888888802'::uuid,'COMMITTED','BOOK','COMMITTED',11,'L8V2-APT-1','89888888-8888-4888-8888-888888888810'::uuid,
 jsonb_build_object('status','BOOKED'),now()-interval '49 hours');

do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_record_booking_utility_optin_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'wamid.l8v2.booking.confirm','WA_L8_BOOKING_UTILITY_V1','TEST:L8V2:BOOKING_DISCLOSURE');
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'scope'<>'UTILITY' or r->>'authority'<>'WA7A4' then
    raise exception 'WA_L8_V2_BOOKING_UTILITY_OPTIN_FAIL:%',r;
  end if;
  r:=public.aos_wa_marketing_eligibility_check_v1('89888888-8888-4888-8888-888888888802'::uuid,'UTILITY');
  if coalesce((r->>'send_allowed')::boolean,false) is not true then raise exception 'WA_L8_V2_UTILITY_NOT_ELIGIBLE:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_utility_reminder','l8v2:utility:consented:0001');
  if r->>'decision'<>'PASS' or r->>'reason'<>'WA_L8_SCOPED_ELIGIBILITY_OK' or r->>'eligibility_scope'<>'UTILITY' then
    raise exception 'WA_L8_V2_UTILITY_AFTER_BOOKING_FAIL:%',r;
  end if;
end $$;

-- Utility consent must never silently grant Marketing.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_marketing_followup','l8v2:marketing:still-blocked:1');
  if r->>'decision'<>'BLOCK' or r->>'eligibility_scope'<>'MARKETING' then raise exception 'WA_L8_V2_SCOPE_LEAK_FAIL:%',r; end if;

  r:=public.aos_wa_l8_consent_record_v2(
    'admin-token-111111111111111111111111111111111111','89888888-8888-4888-8888-888888888802'::uuid,
    'MARKETING','OPT_IN','PRIVACY_FORM','TEST:L8V2:MARKETING_FORM');
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'scope'<>'MARKETING' then raise exception 'WA_L8_V2_MARKETING_OPTIN_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_marketing_followup','l8v2:marketing:consented:001');
  if r->>'decision'<>'PASS' or r->>'eligibility_scope'<>'MARKETING' then raise exception 'WA_L8_V2_MARKETING_PASS_FAIL:%',r; end if;
end $$;

-- STOP persists even if the customer later sends an ordinary message. Both messages
-- are >24h old so category-specific reconsent behavior is visible deterministically.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values
('wamid.l8v2.stop','INBOUND','51971000002','519999111222','pn-l8v2','text','No más mensajes','received',now()-interval '48 hours',now()-interval '48 hours','89888888-8888-4888-8888-888888888802'::uuid),
('wamid.l8v2.afterstop','INBOUND','51971000002','519999111222','pn-l8v2','text','Gracias','received',now()-interval '47 hours',now()-interval '47 hours','89888888-8888-4888-8888-888888888802'::uuid)
on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_utility_reminder','l8v2:stop:utility:0000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L8_V2_PERSISTENT_STOP_UTILITY_FAIL:%',r; end if;
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_marketing_followup','l8v2:stop:marketing:000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L8_V2_PERSISTENT_STOP_MARKETING_FAIL:%',r; end if;
end $$;

-- Explicit MARKETING reconsent after STOP only reopens Marketing; Utility remains blocked.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_consent_record_v2(
    'admin-token-111111111111111111111111111111111111','89888888-8888-4888-8888-888888888802'::uuid,
    'MARKETING','OPT_IN','CUSTOMER_REQUEST','TEST:L8V2:MARKETING_RECONSENT_AFTER_STOP');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_V2_RECONSENT_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_marketing_followup','l8v2:stop:marketing:reconsent:1');
  if r->>'decision'<>'PASS' or r->>'eligibility_scope'<>'MARKETING' then raise exception 'WA_L8_V2_MARKETING_RECONSENT_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888802'::uuid,'PHONE','51971000002','template','l8v2_utility_reminder','l8v2:stop:utility:stillblock:1');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L8_V2_MARKETING_RECONSENT_LEAKED_UTILITY:%',r; end if;
end $$;

-- Meta cost intelligence remains first-class after final consent hardening.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  pricing_category,pricing_model,billable,provider_timestamp,sent_at,delivered_at,conversation_id
) values
('wamid.l8v2.cost.free','OUTBOUND','519999111222','51971000001','pn-l8v2','text','free','delivered','service','PMP',false,now(),now(),now(),'89888888-8888-4888-8888-888888888801'::uuid),
('wamid.l8v2.cost.paid','OUTBOUND','519999111222','51971000001','pn-l8v2','template',null,'delivered','marketing','PMP',true,now(),now(),now(),'89888888-8888-4888-8888-888888888801'::uuid)
on conflict(provider_message_id) do nothing;

insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values
('status:wamid.l8v2.cost.free:delivered','message.status','wamid.l8v2.cost.free','delivered',jsonb_build_object('pricing_category','service','pricing_model','PMP','pricing_type','free_customer_service','billable',false)),
('status:wamid.l8v2.cost.paid:delivered','message.status','wamid.l8v2.cost.paid','delivered',jsonb_build_object('pricing_category','marketing','pricing_model','PMP','pricing_type','regular','billable',true))
on conflict(event_key) do nothing;

do $$ declare r jsonb; c record; begin
  r:=public.aos_wa_l7_pricing_authority_append_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object('provider','META_WHATSAPP','pricing_kind','META_MESSAGE','pricing_category','marketing','pricing_model','PMP',
      'market_code','PE','currency','USD','flat_cost',0.03,'authority_grade','VERIFIED','evidence_ref','TEST:L8V2:PE_RATE','valid_from','2026-01-01T00:00:00Z'));
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_V2_RATE_APPEND_FAIL:%',r; end if;

  select * into c from public.aos_wa_l7_meta_cost_events_v1 where provider_message_id='wamid.l8v2.cost.paid';
  if c.cost_state<>'KNOWN' or c.cost_amount<>0.03 or c.billing_market_code<>'PE' or c.pricing_type<>'regular' then
    raise exception 'WA_L8_V2_COST_EVENT_FAIL:%/%/%/%',c.cost_state,c.cost_amount,c.billing_market_code,c.pricing_type;
  end if;
  select * into c from public.aos_wa_l8_meta_monthly_usage_v1
  where business_phone_number_id='pn-l8v2' and billing_market_code='PE' and pricing_category='marketing';
  if c.provider_billable_messages<1 or c.known_cost_amount<0.03 then raise exception 'WA_L8_V2_MONTHLY_COST_FAIL:%',row_to_json(c); end if;
end $$;

-- Final SAFE-OFF / privilege invariants.
do $$ declare s jsonb; begin
  s:=public.aos_wa_l8_security_status_v1();
  if s->>'mode'<>'AUTO_OFF' or (s->>'kill_switch_engaged')::boolean is not true
     or (s->>'auto_reply_enabled')::boolean or (s->>'ai_send_enabled')::boolean
     or (s->>'auto_routing_enabled')::boolean or (s->>'human_send_enabled')::boolean is not true then
    raise exception 'WA_L8_V2_SAFE_OFF_FAIL:%',s;
  end if;
  if (s->>'autonomous_outbound')::integer<>0 then raise exception 'WA_L8_V2_AUTO_OUTBOUND_NOT_ZERO:%',s; end if;
  if (s->>'deprecated_l8_consent_events')::integer<>0 then raise exception 'WA_L8_V2_DEPRECATED_CONSENT_DIRTY:%',s; end if;
end $$;

do $$ begin
  begin
    delete from public.aos_wa_l8_preflight_decisions_v1;
    raise exception 'WA_L8_V2_PREFLIGHT_DELETE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
end $$;

select 'WA_L8_SCOPED_CONSENT_COST_CLOSEOUT_PASS' as result;
