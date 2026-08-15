begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

select ok(to_regclass('public.aos_wa_conversations_v1') is not null,'conversation table exists');
select ok(to_regclass('public.aos_wa_conversation_events_v1') is not null,'conversation event table exists');
select ok((select relrowsecurity from pg_class where oid='public.aos_wa_conversations_v1'::regclass),'conversation RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_conversations_v1'::regclass),'conversation FORCE RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_conversation_events_v1'::regclass),'event FORCE RLS enabled');
select ok(not has_table_privilege('anon','public.aos_wa_conversations_v1','SELECT'),'anon cannot read conversations directly');
select ok(not has_table_privilege('authenticated','public.aos_wa_conversations_v1','UPDATE'),'authenticated cannot update conversations directly');
select ok(not has_table_privilege('anon','public.aos_wa_conversation_events_v1','SELECT'),'anon cannot read conversation events directly');
select ok(has_table_privilege('service_role','public.aos_wa_conversations_v1','SELECT'),'service role can read conversation store');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='aos_wa_messages_v1' and column_name='conversation_id'),'WA message has conversation_id');
select ok(has_function_privilege('anon','public.aos_wa_inbox_v1(text,text,text,integer,timestamptz)','EXECUTE'),'anon can call governed inbox RPC');
select ok(has_function_privilege('authenticated','public.aos_wa_conversation_v1(text,uuid,integer)','EXECUTE'),'authenticated can call governed conversation RPC');

insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,phone_number_id,contact_name,message_type,message_body,status,campaign_source,ad_id,raw_referral,provider_timestamp,received_at)
values ('wamid.wa2test1','INBOUND','+51 999-111-222','biz-1','Paciente WA2','text','Hola, quiero una cita','received','META_AD','ad-123','{"source_type":"ad"}'::jsonb,now(),now());

select is((select count(*)::int from public.aos_wa_conversations_v1),1,'first inbound creates one conversation');
select is((select contact_number from public.aos_wa_conversations_v1),'51999111222','contact number normalized');
select is((select unread_count from public.aos_wa_conversations_v1),1,'inbound increments unread');
select is((select message_count from public.aos_wa_conversations_v1),1,'inbound increments message count');
select is((select state from public.aos_wa_conversations_v1),'OPEN','inbound opens conversation');
select ok((select customer_service_window_expires_at is not null from public.aos_wa_conversations_v1),'24h service candidate recorded');
select ok((select free_entry_candidate_expires_at is not null from public.aos_wa_conversations_v1),'ad referral candidate window recorded');
select is((select count(*)::int from public.aos_wa_conversation_events_v1 where event_type='MESSAGE_IN'),1,'message-in event appended');
select ok((select conversation_id is not null from public.aos_wa_messages_v1 where provider_message_id='wamid.wa2test1'),'message bound to conversation');

insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,phone_number_id,contact_name,message_type,message_body,status,provider_timestamp,received_at)
values ('wamid.wa2test1','INBOUND','51999111222','biz-1','Paciente WA2','text','Hola, quiero una cita','received',now(),now())
on conflict(provider_message_id) do update set status=excluded.status;
select is((select message_count from public.aos_wa_conversations_v1),1,'duplicate provider message does not double-count');
select is((select count(*)::int from public.aos_wa_conversation_events_v1 where event_type='MESSAGE_IN'),1,'duplicate provider message does not duplicate event');

insert into public.aos_wa_messages_v1(provider_message_id,direction,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,sent_at)
values ('wamid.wa2test2','OUTBOUND','51999111222','biz-1','text','Claro, te ayudo.','sent',now(),now());
select is((select count(*)::int from public.aos_wa_conversations_v1),1,'outbound reuses same conversation');
select is((select message_count from public.aos_wa_conversations_v1),2,'outbound increments message count');
select is((select state from public.aos_wa_conversations_v1),'WAITING_CUSTOMER','outbound moves to waiting customer');

insert into public.aos_usuarios(id,activo,rol,nivel_jerarquia,paneles_acceso) values ('11111111-1111-1111-1111-111111111111',true,'admin',1,array['admin-chats']);
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked)
values (encode(digest('wa2-valid-token-123456789012345678901234','sha256'),'hex'),'11111111-1111-1111-1111-111111111111','PASSWORD_2FA',now()+interval '1 hour',false);
select ok((public.aos_wa_inbox_v1('bad-token',null,null,60,null)->>'ok')::boolean=false,'invalid token denied by governed RPC');
select ok((public.aos_wa_inbox_v1('wa2-valid-token-123456789012345678901234',null,null,60,null)->>'ok')::boolean,'valid 2FA admin can read inbox RPC');
select ok((public.aos_wa_mark_inbox_read_v1('wa2-valid-token-123456789012345678901234',(select id from public.aos_wa_conversations_v1))->>'ok')::boolean,'mark inbox read succeeds');
select is((select unread_count from public.aos_wa_conversations_v1),0,'mark read clears unread');
select ok((public.aos_wa_close_conversation_v1('wa2-valid-token-123456789012345678901234',(select id from public.aos_wa_conversations_v1))->>'ok')::boolean,'close succeeds');
select is((select state from public.aos_wa_conversations_v1),'CLOSED','close persists state');

select * from finish();
rollback;
