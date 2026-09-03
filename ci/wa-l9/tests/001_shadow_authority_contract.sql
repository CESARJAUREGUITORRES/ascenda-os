\set ON_ERROR_STOP on

-- WA-L9 TEST ONLY. Synthetic recipient/conversation exists only in isolated local CI.

update public.aos_usuarios
set nivel_jerarquia=1,
    paneles_acceso=case when 'admin-whatsapp'=any(coalesce(paneles_acceso,'{}'::text[])) then paneles_acceso else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-whatsapp') end,
    activo=true
where id='11111111-1111-4111-8111-111111111111'::uuid;

insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_address,contact_address_type,contact_name,phone_number_id,state,opened_at,updated_at
) values (
  '99999999-9999-4999-8999-999999999901'::uuid,
  'pn-l9:51970000091','51970000091','51970000091','PHONE','L9 SHADOW','pn-l9','NEW',now()-interval '2 hours',now()
) on conflict(id) do nothing;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values (
  'wamid.l9.inbound.open','INBOUND','51970000091','519999111222','pn-l9','text','Quiero reservar','received',
  now()-interval '20 minutes',now()-interval '20 minutes','99999999-9999-4999-8999-999999999901'::uuid
) on conflict(provider_message_id) do nothing;

-- 1) AUTO_OFF is observed exactly, while the L4/L8 durable decision ledgers stay unchanged.
do $$
declare b_l4 bigint; a_l4 bigint; b_l8 bigint; a_l8 bigint; r jsonb;
begin
  select count(*) into b_l4 from public.aos_wa_auto_decisions_v1;
  select count(*) into b_l8 from public.aos_wa_l8_preflight_decisions_v1;
  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','text',null,
    'l9:autooff:shadow:000001',repeat('a',64),'ALLOW','VERIFIED',false,null
  );
  select count(*) into a_l4 from public.aos_wa_auto_decisions_v1;
  select count(*) into a_l8 from public.aos_wa_l8_preflight_decisions_v1;
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_AUTO_OFF' or (r->>'shadow')::boolean is not true
     or (r->>'provider_dispatch')::boolean or (r->>'side_effects_rolled_back')::boolean is not true then
    raise exception 'WA_L9_AUTO_OFF_SHADOW_FAIL:%',r;
  end if;
  if a_l4<>b_l4 or a_l8<>b_l8 then raise exception 'WA_L9_SHADOW_SIDE_EFFECT_LEAK:%/%/%/%',b_l4,a_l4,b_l8,a_l8; end if;
end $$;

-- 2) In isolated CI only, temporarily configure a synthetic CANARY authority so the
-- exact L4+L8 path can produce ALLOW. The shadow function must still roll it all back.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l4_allowlist_set_v1(
    '11111111-1111-4111-8111-111111111111'::uuid,'CONVERSATION','99999999-9999-4999-8999-999999999901',true,now()+interval '1 hour','WA-L9 isolated CI');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L9_ALLOWLIST_SETUP_FAIL:%',r; end if;

  r:=public.aos_wa_l4_set_control_v1(
    '11111111-1111-4111-8111-111111111111'::uuid,'CANARY',false,50,20,60,20,0,30,'WA-L9-LOCAL-CI-AUTH');
  if coalesce((r->>'ok')::boolean,false) is not true or r->>'mode'<>'CANARY' or (r->>'effective_autonomous_send')::boolean is not true then
    raise exception 'WA_L9_LOCAL_CANARY_SETUP_FAIL:%',r;
  end if;
end $$;

do $$
declare b_l4 bigint; a_l4 bigint; b_l8 bigint; a_l8 bigint; r jsonb;
begin
  select count(*) into b_l4 from public.aos_wa_auto_decisions_v1;
  select count(*) into b_l8 from public.aos_wa_l8_preflight_decisions_v1;
  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','text',null,
    'l9:allow:shadow:0000001',repeat('b',64),'ALLOW','VERIFIED',false,null
  );
  select count(*) into a_l4 from public.aos_wa_auto_decisions_v1;
  select count(*) into a_l8 from public.aos_wa_l8_preflight_decisions_v1;
  if r->>'decision'<>'ALLOW' or (r->>'would_send')::boolean is not true or r->>'l8_preflight'<>'PASS'
     or (r->>'provider_dispatch')::boolean or (r->>'side_effects_rolled_back')::boolean is not true then
    raise exception 'WA_L9_WOULD_SEND_FAIL:%',r;
  end if;
  if a_l4<>b_l4 or a_l8<>b_l8 then raise exception 'WA_L9_ALLOW_SHADOW_SIDE_EFFECT_LEAK:%/%/%/%',b_l4,a_l4,b_l8,a_l8; end if;
end $$;

-- 3) L4/L8 negative matrix is preserved by the same shadow path.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000999','text',null,
    'l9:mismatch:shadow:00001',repeat('c',64),'ALLOW','VERIFIED',false,null);
  if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L8_RECIPIENT_CONVERSATION_MISMATCH' then
    raise exception 'WA_L9_RECIPIENT_MISMATCH_FAIL:%',r;
  end if;

  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','text',null,
    'l9:identity:shadow:000001',repeat('d',64),'ALLOW','CONFLICT',true,null);
  if r->>'decision'<>'HANDOFF' or r->>'reason'<>'WA_L4_IDENTITY_CONFLICT' then
    raise exception 'WA_L9_IDENTITY_CONFLICT_FAIL:%',r;
  end if;

  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','template','not-provider-verified',
    'l9:template:shadow:000001',repeat('e',64),'ALLOW','VERIFIED',false,null);
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_TEMPLATE_NOT_PROVIDER_VERIFIED' then
    raise exception 'WA_L9_TEMPLATE_FAIL:%',r;
  end if;
end $$;

-- 4) Kill-switch stays authoritative even when mode is CANARY.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l4_set_control_v1(
    '11111111-1111-4111-8111-111111111111'::uuid,'CANARY',true,null,null,null,null,null,null,'WA-L9-LOCAL-CI-KILL');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L9_KILL_SETUP_FAIL:%',r; end if;
  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','text',null,
    'l9:kill:shadow:00000001',repeat('f',64),'ALLOW','VERIFIED',false,null);
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L4_KILL_SWITCH' then raise exception 'WA_L9_KILL_SWITCH_FAIL:%',r; end if;
end $$;

-- Restore local CANARY to allow STOP precedence test, then inject explicit STOP.
do $$ declare r jsonb; begin
  r:=public.aos_wa_l4_set_control_v1(
    '11111111-1111-4111-8111-111111111111'::uuid,'CANARY',false,null,null,null,null,null,null,'WA-L9-LOCAL-CI-STOP');
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L9_STOP_SETUP_FAIL:%',r; end if;
end $$;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,
  provider_timestamp,received_at,conversation_id
) values (
  'wamid.l9.stop','INBOUND','51970000091','519999111222','pn-l9','text','STOP','received',now(),now(),
  '99999999-9999-4999-8999-999999999901'::uuid
) on conflict(provider_message_id) do nothing;

do $$ declare r jsonb; begin
  r:=public.aos_wa_l9_shadow_authorize_v1(
    '99999999-9999-4999-8999-999999999901'::uuid,'PHONE','51970000091','text',null,
    'l9:stop:shadow:00000001',repeat('1',64),'ALLOW','VERIFIED',false,null);
  if r->>'decision'<>'BLOCK' or r->>'reason'<>'WA_L8_OPT_OUT_ACTIVE' then raise exception 'WA_L9_STOP_FAIL:%',r; end if;
end $$;

-- 5) Redacted immutable demo ledger is idempotent and cannot record provider dispatch.
do $$ declare s jsonb; a jsonb; b jsonb; begin
  -- Use a synthetic shadow result independent of the STOP inserted above.
  s:=pg_catalog.jsonb_build_object('decision','ALLOW','reason','WA_L4_ALLOWED','mode','CANARY','l8_preflight','PASS','would_send',true,'provider_dispatch',false);
  a:=public.aos_wa_l9_demo_record_v1(
    'l9:demo:record:00000001','99999999-9999-4999-8999-999999999901'::uuid,repeat('a',64),repeat('b',64),'text',null,s);
  b:=public.aos_wa_l9_demo_record_v1(
    'l9:demo:record:00000001','99999999-9999-4999-8999-999999999901'::uuid,repeat('a',64),repeat('b',64),'text',null,s);
  if coalesce((a->>'ok')::boolean,false) is not true or (a->>'replay')::boolean is true or (a->>'would_send')::boolean is not true then raise exception 'WA_L9_DEMO_RECORD_FAIL:%',a; end if;
  if coalesce((b->>'ok')::boolean,false) is not true or (b->>'replay')::boolean is not true then raise exception 'WA_L9_DEMO_REPLAY_FAIL:%',b; end if;
end $$;

do $$ begin
  begin
    update public.aos_wa_l9_demo_runs_v1 set authority_reason='tamper';
    raise exception 'WA_L9_UPDATE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
  begin
    delete from public.aos_wa_l9_demo_runs_v1;
    raise exception 'WA_L9_DELETE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
  if exists(select 1 from public.aos_wa_l9_demo_runs_v1 where provider_dispatch is true or raw_content_stored is true) then
    raise exception 'WA_L9_REDACTION_OR_DISPATCH_FAIL';
  end if;
end $$;

-- 6) Return isolated DB to the production-shaped SAFE-OFF posture.
do $$ declare r jsonb; s jsonb; begin
  r:=public.aos_wa_l4_set_control_v1(
    '11111111-1111-4111-8111-111111111111'::uuid,'AUTO_OFF',true,null,null,null,null,null,null,null);
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L9_SAFE_OFF_RESTORE_FAIL:%',r; end if;
  s:=public.aos_wa_l9_status_v1();
  if s->>'mode'<>'AUTO_OFF' or (s->>'kill_switch_engaged')::boolean is not true
     or (s->>'auto_reply_enabled')::boolean or (s->>'ai_send_enabled')::boolean
     or (s->>'auto_routing_enabled')::boolean or (s->>'human_send_enabled')::boolean is not true
     or (s->>'provider_dispatch_runs')::bigint<>0
     or (s->>'autonomous_outbound')::bigint<>0 then
    raise exception 'WA_L9_FINAL_SAFE_OFF_FAIL:%',s;
  end if;
end $$;

select 'WA_L9_SHADOW_AUTHORITY_CONTRACT_PASS' as result;