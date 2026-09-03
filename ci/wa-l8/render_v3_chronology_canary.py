from pathlib import Path

src = Path('ci/wa-l8/tests/002_scoped_consent_cost_closeout.sql').read_text(encoding='utf-8')
start = '-- STOP persists even if the customer later sends an ordinary message.'
end = '-- Meta cost intelligence remains first-class after final consent hardening.'

if src.count(start) != 1 or src.count(end) != 1:
    raise SystemExit('WA_L8_V3_RENDER_MARKERS_INVALID')

prefix, tail = src.split(start, 1)
_, suffix = tail.split(end, 1)

replacement = r'''-- STOP V3 chronology: use a dedicated outside-24h conversation so an earlier
-- Marketing opt-in from another scenario cannot be misread as reconsent-after-STOP.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_address,contact_address_type,contact_name,phone_number_id,state,opened_at,updated_at
) values (
  '89888888-8888-4888-8888-888888888803'::uuid,'pn-l8v2:51971000003','51971000003','51971000003','PHONE',
  'L8 V3 STOP CHRONOLOGY','pn-l8v2','NEW',now()-interval '4 days',now()
) on conflict(id) do nothing;

insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at)
values('pn-l8v2','PHONE','51971000003','89888888-8888-4888-8888-888888888803'::uuid,true,now()-interval '4 days',now())
on conflict(business_scope,alias_type,alias_value) do update
set conversation_id=excluded.conversation_id,active=true,last_seen_at=excluded.last_seen_at;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values
('wamid.l8v3.base','INBOUND','51971000003','519999111222','pn-l8v2','text','Hola','received',now()-interval '72 hours',now()-interval '72 hours','89888888-8888-4888-8888-888888888803'::uuid),
('wamid.l8v3.stop','INBOUND','51971000003','519999111222','pn-l8v2','text','No más mensajes','received',now()-interval '48 hours',now()-interval '48 hours','89888888-8888-4888-8888-888888888803'::uuid),
('wamid.l8v3.afterstop','INBOUND','51971000003','519999111222','pn-l8v2','text','Gracias','received',now()-interval '47 hours',now()-interval '47 hours','89888888-8888-4888-8888-888888888803'::uuid)
on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; begin
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888803'::uuid,'PHONE','51971000003','template','l8v2_utility_reminder','l8v3:stop:utility:0000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then
    raise exception 'WA_L8_V3_PERSISTENT_STOP_UTILITY_FAIL:%',r;
  end if;
  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888803'::uuid,'PHONE','51971000003','template','l8v2_marketing_followup','l8v3:stop:marketing:000001');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then
    raise exception 'WA_L8_V3_PERSISTENT_STOP_MARKETING_FAIL:%',r;
  end if;
end $$;

-- Explicit Marketing reconsent after STOP reopens Marketing only.
do $$ declare r jsonb; begin
  r:=public.aos_wa_marketing_eligibility_record_v1(jsonb_build_object(
    'event_key','l8v3:marketing:reconsent:0001',
    'conversation_id','89888888-8888-4888-8888-888888888803',
    'eligibility_scope','MARKETING','consent_status','ALLOWED','suppression_status','CLEAR',
    'source','CUSTOMER_REQUEST','source_ref','TEST:L8V3:MARKETING_RECONSENT_AFTER_STOP',
    'policy_version','WA_L8_SCOPED_CONSENT_V1',
    'evidence',jsonb_build_object('explicit_reconsent',true,'raw_recipient_stored',false),
    'observed_at',clock_timestamp()
  ));
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L8_V3_RECONSENT_APPEND_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888803'::uuid,'PHONE','51971000003','template','l8v2_marketing_followup','l8v3:stop:marketing:reconsent:1');
  if r->>'decision'<>'PASS' or r->>'eligibility_scope'<>'MARKETING' then raise exception 'WA_L8_V3_MARKETING_RECONSENT_FAIL:%',r; end if;

  r:=public.aos_wa_l8_autonomous_preflight_v1(
    '89888888-8888-4888-8888-888888888803'::uuid,'PHONE','51971000003','template','l8v2_utility_reminder','l8v3:stop:utility:stillblock:1');
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L8_V3_MARKETING_RECONSENT_LEAKED_UTILITY:%',r; end if;
end $$;

'''

rendered = prefix + replacement + end + suffix
if 'WA_L8_V2_PERSISTENT_STOP_MARKETING_FAIL' in rendered:
    raise SystemExit('WA_L8_V3_OLD_STOP_BLOCK_REMAINS')
if rendered.count("select 'WA_L8_SCOPED_CONSENT_COST_CLOSEOUT_PASS' as result;") != 1:
    raise SystemExit('WA_L8_V3_PASS_MARKER_INVALID')

print(rendered, end='')
