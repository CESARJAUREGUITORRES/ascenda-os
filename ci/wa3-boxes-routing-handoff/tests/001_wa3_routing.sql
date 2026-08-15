begin;
create extension if not exists pgtap;
select no_plan();

select has_table('public','aos_wa_routing_control_v1','WA3 routing control exists');
select has_table('public','aos_wa_boxes_v1','WA3 boxes exist');
select has_table('public','aos_wa_box_members_v1','WA3 box members exist');
select has_table('public','aos_wa_assignments_v1','WA3 assignments exist');
select has_table('public','aos_wa_routing_events_v1','WA3 routing events exist');
select has_column('public','aos_wa_conversations_v1','box_id','conversation has box');
select has_column('public','aos_wa_conversations_v1','owner_user_id','conversation has owner');
select has_column('public','aos_wa_conversations_v1','ownership_version','conversation has ownership version');
select has_trigger('public','aos_wa_conversations_v1','trg_aos_wa3_auto_route_new_conversation_v1','auto routing trigger exists');
select has_trigger('public','aos_wa_routing_events_v1','trg_aos_wa3_routing_event_append_guard_v1','routing audit append guard exists');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_boxes_v1'::regclass),'boxes FORCE RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_assignments_v1'::regclass),'assignments FORCE RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_routing_events_v1'::regclass),'routing events FORCE RLS');
select ok(not has_table_privilege('anon','public.aos_wa_boxes_v1','SELECT'),'anon cannot read boxes');
select ok(not has_table_privilege('authenticated','public.aos_wa_assignments_v1','SELECT'),'authenticated cannot read assignments directly');
select ok(has_table_privilege('service_role','public.aos_wa_assignments_v1','SELECT'),'service role can read assignments');
select is((select auto_routing_enabled from public.aos_wa_routing_control_v1 where id=1),false,'auto routing defaults OFF');
select is((select human_send_enabled from public.aos_wa_routing_control_v1 where id=1),false,'human send defaults OFF');
select is((select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1),false,'AI send is OFF');
select throws_ok($$update public.aos_wa_routing_control_v1 set ai_send_enabled=true where id=1$$,'23514',null,'AI send cannot be enabled in WA3');
select is((select count(*)::bigint from public.aos_paneles_disponibles where id='whatsapp-agent'),1::bigint,'whatsapp-agent panel registered');
select is((select count(*)::bigint from public.aos_usuarios where 'whatsapp-agent'=any(coalesce(paneles_acceso,'{}'::text[]))),0::bigint,'WA3 does not auto-grant agent panel');

select ok((public.aos_wa3_actor_v1('admin-token-111111111111111111111111111111111111')->>'ok')::boolean,'level1 admin token accepted');
select ok((public.aos_wa3_actor_v1('admin-token-111111111111111111111111111111111111')->>'is_admin')::boolean,'level1 actor is admin');
select is(public.aos_wa3_actor_v1('agent-a-token-44444444444444444444444444444444444')->>'error','WA3_2FA_PANEL_REQUIRED','agent without panel denied');
update public.aos_usuarios set paneles_acceso=array_append(paneles_acceso,'admin-whatsapp') where id='33333333-3333-4333-8333-333333333333';
select is(public.aos_wa3_actor_v1('bad-token-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')->>'error','WA3_2FA_PANEL_REQUIRED','unknown token denied');

select ok((public.aos_wa3_box_upsert_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','VENTAS','Ventas WhatsApp','MANUAL','ACTIVE',true,10)->>'ok')::boolean,'admin creates default manual box');
select is(public.aos_wa3_box_upsert_v1('44444444-4444-4444-8444-444444444444','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','NOADMIN','No Admin','MANUAL','ACTIVE',false,0)->>'error','WA3_ADMIN_REQUIRED','nonadmin cannot create box');
select is(public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444',true,2,0)->>'error','WA3_AGENT_PANEL_REQUIRED','member requires explicit WA panel');

update public.aos_usuarios set paneles_acceso=array_append(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent') where id in ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555');
select ok((public.aos_wa3_actor_v1('agent-a-token-44444444444444444444444444444444444')->>'ok')::boolean,'agent A accepted after panel grant');
select ok(not (public.aos_wa3_actor_v1('agent-a-token-44444444444444444444444444444444444')->>'is_admin')::boolean,'agent A is not admin');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444',true,2,10)->>'ok')::boolean,'agent A added to box');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','55555555-5555-4555-8555-555555555555',true,1,5)->>'ok')::boolean,'agent B added to box');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111',true,5,20)->>'ok')::boolean,'admin can be canary box member');

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state) values
('10000000-0000-4000-8000-000000000001','wa3:conv1','51990000001','WA3 Uno','NEW'),
('10000000-0000-4000-8000-000000000002','wa3:conv2','51990000002','WA3 Dos','NEW'),
('10000000-0000-4000-8000-000000000003','wa3:conv3','51990000003','WA3 Tres','NEW');
select is((select count(*)::bigint from public.aos_wa_assignments_v1),0::bigint,'auto routing OFF leaves new conversations unassigned');

select ok((public.aos_wa3_route_v1('10000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'11111111-1111-4111-8111-111111111111','TEST_QUEUE')->>'ok')::boolean,'admin routes conversation to manual queue');
select is((select state from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000001'),'HUMAN_REQUESTED','queued conversation enters HUMAN_REQUESTED');
select is((select state from public.aos_wa_assignments_v1 where conversation_id='10000000-0000-4000-8000-000000000001' and state in ('QUEUED','ACTIVE')),'QUEUED','manual route creates queue episode');
select ok((public.aos_wa3_claim_next_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444')->>'claimed')::boolean,'agent A claims next queued conversation');
select is((select owner_user_id from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000001'),'44444444-4444-4444-8444-444444444444'::uuid,'claim sets exact owner');
select is((select state from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000001'),'HUMAN_ACTIVE','claim activates human mode');
select is(public.aos_wa3_set_mode_v1('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','AI_ACTIVE')->>'error','WA3_MODE_NOT_ALLOWED','WA3 forbids AI_ACTIVE');
select is(public.aos_wa3_set_mode_v1('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','AI_COPILOT')->>'state','AI_COPILOT','owner can enter AI copilot without AI send');
select is(public.aos_wa3_human_send_authorize_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'error','WA3_HUMAN_SEND_DISABLED','human send kill switch blocks owner');
select ok((public.aos_wa3_admin_set_control_v1('11111111-1111-4111-8111-111111111111',false,true)->>'ok')::boolean,'admin enables human canary');
select is((select ai_send_enabled from public.aos_wa_routing_control_v1 where id=1),false,'enabling human send does not enable AI');
select ok((public.aos_wa3_human_send_authorize_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'ok')::boolean,'active owner passes human send authorization');
select is(public.aos_wa3_human_send_authorize_v1('agent-b-token-55555555555555555555555555555555555','10000000-0000-4000-8000-000000000001')->>'error','WA3_NOT_OWNER','non-owner cannot send');
select is(public.aos_wa3_release_v1('10000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555','NOT_OWNER')->>'error','WA3_NOT_OWNER','non-owner cannot release');
select is(public.aos_wa3_release_v1('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','SHIFT_END')->>'state','QUEUED','owner release returns conversation to queue');
select ok((select owner_user_id is null from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000001'),'release clears owner');
select ok((public.aos_wa3_claim_next_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','55555555-5555-4555-8555-555555555555')->>'claimed')::boolean,'agent B claims released conversation');
select is((select count(*)::integer from public.aos_wa_assignments_v1 where conversation_id='10000000-0000-4000-8000-000000000001' and state in ('QUEUED','ACTIVE')),1,'only one current ownership episode exists');

select ok((public.aos_wa3_box_upsert_v1('11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','AUTO','Auto Ventas','LEAST_ACTIVE','ACTIVE',true,20)->>'ok')::boolean,'admin creates least-active default box');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','44444444-4444-4444-8444-444444444444',true,2,10)->>'ok')::boolean,'agent A added to auto box');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','55555555-5555-4555-8555-555555555555',true,1,5)->>'ok')::boolean,'agent B added to auto box');
select ok((public.aos_wa3_route_v1('10000000-0000-4000-8000-000000000002','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',null,'11111111-1111-4111-8111-111111111111','LEAST_ACTIVE_TEST')->>'ok')::boolean,'least-active routing succeeds');
select is((select owner_user_id from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000002'),'44444444-4444-4444-8444-444444444444'::uuid,'least-active chooses lower load agent A');
select is(public.aos_wa3_route_v1('10000000-0000-4000-8000-000000000003','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','CAPACITY_TEST')->>'error','WA3_CAPACITY_REACHED','explicit routing respects agent capacity');

select ok((public.aos_wa3_admin_set_control_v1('11111111-1111-4111-8111-111111111111',true,null)->>'auto_routing_enabled')::boolean,'admin enables auto routing');
insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state) values ('10000000-0000-4000-8000-000000000004','wa3:conv4','51990000004','WA3 Cuatro','NEW');
select is((select box_id from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000004'),'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,'auto route uses active default box');
select ok((select state in ('HUMAN_ACTIVE','HUMAN_REQUESTED') from public.aos_wa_conversations_v1 where id='10000000-0000-4000-8000-000000000004'),'auto route produces governed human state');
select ok(not exists(select 1 from public.aos_wa_conversations_v1 where state='AI_ACTIVE'),'WA3 never creates AI_ACTIVE conversation');

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state) values ('10000000-0000-4000-8000-000000000005','wa3:conv5','51990000005','WA3 Cinco','CLOSED');
select is(public.aos_wa3_route_v1('10000000-0000-4000-8000-000000000005','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',null,'11111111-1111-4111-8111-111111111111','TERMINAL')->>'error','WA3_CONVERSATION_TERMINAL','terminal conversation cannot be routed');

select ok((select count(*)>0 from public.aos_wa_routing_events_v1),'routing produces audit evidence');
select throws_ok($$update public.aos_wa_routing_events_v1 set event_type='tampered' where id=(select min(id) from public.aos_wa_routing_events_v1)$$,'55000','WA3_ROUTING_EVENT_APPEND_ONLY','routing audit is append-only');
select ok(not has_function_privilege('anon','public.aos_wa3_route_v1(uuid,uuid,uuid,uuid,text)','EXECUTE'),'anon cannot invoke routing mutation');
select ok(has_function_privilege('service_role','public.aos_wa3_route_v1(uuid,uuid,uuid,uuid,text)','EXECUTE'),'service role can invoke routing mutation');
select ok(has_function_privilege('anon','public.aos_wa3_actor_v1(text)','EXECUTE'),'token actor boundary is callable through anon RPC');
select ok(has_function_privilege('anon','public.aos_wa3_human_send_authorize_v1(text,uuid)','EXECUTE'),'owned-send authorization boundary is callable through anon RPC');

select * from finish();
rollback;
