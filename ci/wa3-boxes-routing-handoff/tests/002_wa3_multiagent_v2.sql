begin;
create extension if not exists pgtap;
select no_plan();

select has_table('public','aos_wa_agent_presence_v1','WA3 V2 presence table exists');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_agent_presence_v1'::regclass),'presence FORCE RLS');
select ok(not has_table_privilege('anon','public.aos_wa_agent_presence_v1','SELECT'),'anon cannot read presence');
select ok(not has_table_privilege('authenticated','public.aos_wa_agent_presence_v1','SELECT'),'authenticated cannot read presence');
select ok(has_table_privilege('service_role','public.aos_wa_agent_presence_v1','SELECT'),'service role reads presence');
select ok(not has_function_privilege('anon','public.aos_wa3_agent_presence_touch_v1(uuid,text)','EXECUTE'),'anon cannot touch presence directly');
select ok(not has_function_privilege('authenticated','public.aos_wa3_queue_summary_v1(uuid)','EXECUTE'),'authenticated cannot query queues directly');
select ok(has_function_privilege('service_role','public.aos_wa3_claim_next_v2(uuid,uuid)','EXECUTE'),'service role can claim through V2');

select is(
  public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'error',
  'WA3_AGENT_PANEL_REQUIRED',
  'presence requires explicit whatsapp-agent access'
);

update public.aos_usuarios
set paneles_acceso=array_append(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent')
where id in ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555');

select ok((public.aos_wa3_box_upsert_v1(
  '11111111-1111-4111-8111-111111111111',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'V2QUEUE','WA V2 Queue','MANUAL','ACTIVE',false,30
)->>'ok')::boolean,'admin creates V2 manual box');

select ok((public.aos_wa3_box_member_set_v1(
  '11111111-1111-4111-8111-111111111111',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '44444444-4444-4444-8444-444444444444',true,2,10
)->>'ok')::boolean,'agent A becomes active V2 member');
select ok((public.aos_wa3_box_member_set_v1(
  '11111111-1111-4111-8111-111111111111',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '55555555-5555-4555-8555-555555555555',true,1,5
)->>'ok')::boolean,'agent B becomes active V2 member');

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state)
values
 ('20000000-0000-4000-8000-000000000001','wa3v2:1','51980000001','V2 Uno','NEW'),
 ('20000000-0000-4000-8000-000000000002','wa3v2:2','51980000002','V2 Dos','NEW');

select ok((public.aos_wa3_route_v1(
  '20000000-0000-4000-8000-000000000001','cccccccc-cccc-4ccc-8ccc-cccccccccccc',null,
  '11111111-1111-4111-8111-111111111111','V2_QUEUE_1'
)->>'ok')::boolean,'first V2 conversation queued');
select ok((public.aos_wa3_route_v1(
  '20000000-0000-4000-8000-000000000002','cccccccc-cccc-4ccc-8ccc-cccccccccccc',null,
  '11111111-1111-4111-8111-111111111111','V2_QUEUE_2'
)->>'ok')::boolean,'second V2 conversation queued');

select is(
  public.aos_wa3_claim_next_v2('cccccccc-cccc-4ccc-8ccc-cccccccccccc','44444444-4444-4444-8444-444444444444')->>'error',
  'WA3_AGENT_NOT_READY',
  'agent cannot claim before presence readiness'
);

select ok((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->>'ok')::boolean,'queue summary succeeds without exposing rows');
select is((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->>'total_queued')::integer,2,'queue summary counts two queued conversations');
select ok(not (public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->'presence'->>'ready')::boolean,'agent initially not ready');
select ok(position('contact_number' in public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')::text)=0,'queue summary contains no customer phone');
select ok(position('conversation_id' in public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')::text)=0,'queue summary contains no conversation identifiers');

select ok((public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'ok')::boolean,'agent A marks AVAILABLE');
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'status','AVAILABLE','AVAILABLE heartbeat is idempotent');
select ok((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->'presence'->>'ready')::boolean,'fresh AVAILABLE presence is ready');
select ok((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->'boxes'->0->>'can_claim')::boolean,'ready agent can claim from member box');

select ok((public.aos_wa3_claim_next_v2('cccccccc-cccc-4ccc-8ccc-cccccccccccc','44444444-4444-4444-8444-444444444444')->>'claimed')::boolean,'ready agent A claims next');
select is((select owner_user_id from public.aos_wa_conversations_v1 where id='20000000-0000-4000-8000-000000000001'),'44444444-4444-4444-8444-444444444444'::uuid,'claim V2 preserves exact owner semantics');
select is((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->>'total_queued')::integer,1,'queue count falls after claim');

select is(public.aos_wa3_agent_presence_touch_v1('55555555-5555-4555-8555-555555555555','AWAY')->>'status','AWAY','agent B can explicitly mark AWAY');
select is(
  public.aos_wa3_claim_next_v2('cccccccc-cccc-4ccc-8ccc-cccccccccccc','55555555-5555-4555-8555-555555555555')->>'error',
  'WA3_AGENT_NOT_READY',
  'AWAY agent cannot claim'
);

select ok((public.aos_wa3_agent_presence_touch_v1('55555555-5555-4555-8555-555555555555','AVAILABLE')->>'ok')::boolean,'agent B becomes available');
update public.aos_wa_agent_presence_v1 set last_seen_at=now()-interval '3 minutes' where user_id='55555555-5555-4555-8555-555555555555';
select is(
  public.aos_wa3_claim_next_v2('cccccccc-cccc-4ccc-8ccc-cccccccccccc','55555555-5555-4555-8555-555555555555')->>'error',
  'WA3_AGENT_NOT_READY',
  'stale presence fails closed'
);
select ok((public.aos_wa3_queue_summary_v1('55555555-5555-4555-8555-555555555555')->'presence'->>'stale')::boolean,'stale readiness is reported');

select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','INVALID')->>'error','WA3_INVALID_PRESENCE_STATUS','invalid presence status rejected');
select ok((select count(*)>=2 from public.aos_wa_routing_events_v1 where event_type='agent.presence_changed'),'presence changes are audited without heartbeat storms');
select is((select auto_routing_enabled from public.aos_wa_routing_control_v1 where id=1),false,'WA3 V2 does not enable auto routing');
select is((select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1),false,'WA3 V2 keeps AI send OFF');

select * from finish();
rollback;
