begin;
create extension if not exists pgtap;
select no_plan();

alter table public.aos_usuarios add column if not exists codigo_asesor text;
create table if not exists public.aos_estado_equipo(
  asesor text,
  estado text,
  inicio timestamptz,
  fin timestamptz,
  minutos_en_estado numeric,
  updated_at timestamptz,
  sede text,
  codigo_asesor text
);

select has_function('public','aos_wa3_effective_presence_v2',array['uuid'],'effective presence helper exists');
select has_function('public','aos_wa3_handoff_request_v1',array['uuid','uuid','uuid','text'],'explicit handoff request exists');
select ok(not has_function_privilege('anon','public.aos_wa3_handoff_request_v1(uuid,uuid,uuid,text)','EXECUTE'),'anon cannot request handoff directly');
select ok(has_function_privilege('service_role','public.aos_wa3_handoff_request_v1(uuid,uuid,uuid,text)','EXECUTE'),'service role can request governed handoff');

update public.aos_usuarios
set paneles_acceso=array_append(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent'),codigo_asesor='WA3-A'
where id='44444444-4444-4444-8444-444444444444';

insert into public.aos_estado_equipo(asesor,estado,inicio,updated_at,codigo_asesor)
values('Agent A','LOGEADO',now(),now(),'WA3-A');

select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'status','AVAILABLE','global heartbeat + LOGEADO derives AVAILABLE');
select ok((public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'automatic')::boolean,'presence is explicitly automatic');

update public.aos_estado_equipo set estado='BREAK',updated_at=now() where codigo_asesor='WA3-A';
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'status','AWAY','labor BREAK derives AWAY without WA button');
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AWAY')->>'status','AWAY','legacy AWAY signal cannot override canonical labor state');

update public.aos_estado_equipo set estado='BAÑO',updated_at=now() where codigo_asesor='WA3-A';
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE')->>'status','AWAY','labor BAÑO derives AWAY');

update public.aos_estado_equipo set estado='LOGEADO',updated_at=now() where codigo_asesor='WA3-A';
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','HEARTBEAT')->>'status','AVAILABLE','HEARTBEAT restores AVAILABLE from canonical state');

update public.aos_wa_agent_presence_v1 set last_seen_at=now()-interval '70 seconds' where user_id='44444444-4444-4444-8444-444444444444';
select is(public.aos_wa3_effective_presence_v2('44444444-4444-4444-8444-444444444444')->>'status','OFFLINE','stale global heartbeat derives OFFLINE');
select ok((public.aos_wa3_effective_presence_v2('44444444-4444-4444-8444-444444444444')->>'stale')::boolean,'stale presence is explicit');
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','HEARTBEAT')->>'status','AVAILABLE','fresh global heartbeat reconnects agent');
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','OFFLINE')->>'status','OFFLINE','pagehide can mark OFFLINE immediately');
select is(public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','HEARTBEAT')->>'status','AVAILABLE','next app heartbeat returns ONLINE');

select ok((public.aos_wa3_box_upsert_v1(
  '11111111-1111-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'FINALQ','Human Handoff Queue','MANUAL','ACTIVE',false,40
)->>'ok')::boolean,'admin creates final human handoff box');
select ok((public.aos_wa3_box_member_set_v1(
  '11111111-1111-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '44444444-4444-4444-8444-444444444444',true,2,10
)->>'ok')::boolean,'agent belongs to final queue');

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state)
values
 ('30000000-0000-4000-8000-000000000001','wa3final:bot','51981111111','Bot Normal','NEW'),
 ('30000000-0000-4000-8000-000000000002','wa3final:human','51982222222','Needs Human','NEW'),
 ('30000000-0000-4000-8000-000000000003','wa3final:admin','51983333333','Admin Intervenes','NEW');

-- Deliberately create a malformed queued assignment for a normal BOT/NEW conversation.
-- V3 must still never expose or claim it because the conversation lacks explicit handoff state.
insert into public.aos_wa_assignments_v1(conversation_id,box_id,owner_user_id,state,assigned_by,metadata)
values('30000000-0000-4000-8000-000000000001','dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'QUEUED','11111111-1111-4111-8111-111111111111','{"test":"bot_normal_should_not_claim"}'::jsonb);

select ok((public.aos_wa3_handoff_request_v1(
  '30000000-0000-4000-8000-000000000002','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111','CUSTOMER_REQUESTED_HUMAN'
)->>'ok')::boolean,'explicit handoff queues customer for human');
select is((select state from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000002'),'HUMAN_REQUESTED','handoff state is HUMAN_REQUESTED');
select ok((select handoff_requested_at is not null from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000002'),'handoff timestamp recorded');
select ok((public.aos_wa3_handoff_request_v1(
  '30000000-0000-4000-8000-000000000002','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111','RETRY'
)->>'idempotent')::boolean,'repeat handoff is idempotent');

select is((public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->>'total_queued')::integer,1,'queue counts only explicit HUMAN_REQUESTED work');
select is(public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')->>'queue_contract','HUMAN_HANDOFF_ONLY','queue contract is explicit');
select ok(position('conversation_id' in public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')::text)=0,'aggregate queue exposes no conversation id');
select ok(position('contact_number' in public.aos_wa3_queue_summary_v1('44444444-4444-4444-8444-444444444444')::text)=0,'aggregate queue exposes no customer phone');

select ok((public.aos_wa3_claim_next_v2('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444')->>'claimed')::boolean,'eligible agent claims explicit human handoff');
select is((select owner_user_id from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000002'),'44444444-4444-4444-8444-444444444444'::uuid,'human handoff becomes exact agent owner');
select is((select state from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000001'),'NEW','normal bot conversation stays NEW');
select is((select owner_user_id from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000001'),null::uuid,'normal bot conversation remains unowned');
select is((select state from public.aos_wa_assignments_v1 where conversation_id='30000000-0000-4000-8000-000000000001'),'QUEUED','malformed bot queue row was not consumed');

-- Admin/supervisor retains explicit intervention authority even when the chat was not in handoff queue.
select ok((public.aos_wa3_route_v1(
  '30000000-0000-4000-8000-000000000003','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','ADMIN_INTERVENTION'
)->>'ok')::boolean,'admin can explicitly intervene and assign a normal conversation');

update public.aos_estado_equipo set estado='BREAK',updated_at=now() where codigo_asesor='WA3-A';
select perform from (select public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','HEARTBEAT') as perform) s;
select is(public.aos_wa3_claim_next_v2('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444')->>'error','WA3_AGENT_NOT_READY','AWAY advisor cannot claim handoff');

select is((select auto_routing_enabled from public.aos_wa_routing_control_v1 where id=1),false,'final contract keeps auto-routing OFF');
select is((select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1),false,'final contract keeps AI send OFF');
select ok((select count(*)>=1 from public.aos_wa_routing_events_v1 where event_type='conversation.handoff_requested'),'human handoff request is audited');

select * from finish();
rollback;
