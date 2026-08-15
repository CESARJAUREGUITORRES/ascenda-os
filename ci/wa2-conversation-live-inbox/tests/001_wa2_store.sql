begin;
create extension if not exists pgtap;
select plan(36);

select has_table('public','aos_wa_conversations_v1','conversation store exists');
select has_table('public','aos_wa_conversation_events_v1','conversation event ledger exists');
select has_column('public','aos_wa_messages_v1','conversation_id','WA-1 messages link to WA-2 conversation');
select has_trigger('public','aos_wa_messages_v1','trg_aos_wa2_bind_conversation_v1','projection trigger exists');
select ok(to_regprocedure('public.aos_wa2_bind_conversation_v1()') is not null,'projection function exists');
select ok(not (select prosecdef from pg_proc where oid='public.aos_wa2_bind_conversation_v1()'::regprocedure),'projection function is not SECURITY DEFINER');
select ok((select relrowsecurity from pg_class where oid='public.aos_wa_conversations_v1'::regclass),'conversation store has RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_conversations_v1'::regclass),'conversation store FORCE RLS');
select ok((select relrowsecurity from pg_class where oid='public.aos_wa_conversation_events_v1'::regclass),'event ledger has RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_conversation_events_v1'::regclass),'event ledger FORCE RLS');
select ok(not has_table_privilege('anon','public.aos_wa_conversations_v1','SELECT'),'anon cannot read conversations');
select ok(not has_table_privilege('authenticated','public.aos_wa_conversations_v1','SELECT'),'authenticated cannot read conversations directly');
select ok(not has_table_privilege('anon','public.aos_wa_conversations_v1','INSERT'),'anon cannot insert conversations');
select ok(has_table_privilege('service_role','public.aos_wa_conversations_v1','SELECT'),'service role can read conversations server-side');
select ok(not has_table_privilege('authenticated','public.aos_wa_conversation_events_v1','INSERT'),'authenticated cannot forge conversation events');
select ok(has_table_privilege('service_role','public.aos_wa_conversation_events_v1','INSERT'),'service role can append conversation events');

select ok((select conversation_id is not null from public.aos_wa_messages_v1 where provider_message_id='wamid.synthetic.preexisting'),'pre-existing WA-1 message was backfilled');
select is((select count(*)::bigint from public.aos_wa_conversations_v1),1::bigint,'backfill creates one conversation');
select is((select unread_count from public.aos_wa_conversations_v1 limit 1),1,'backfill sets one unread inbound');
select is((select message_count from public.aos_wa_conversations_v1 limit 1),1,'backfill sets message count');
select is((select contact_number from public.aos_wa_conversations_v1 limit 1),'51999111222','contact number is normalized to digits');
select is((select campaign_source from public.aos_wa_conversations_v1 limit 1),'META_SYNTHETIC','campaign provenance is preserved');

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,contact_name,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.inbound2','INBOUND','51999111222','phone-A','Paciente Sintético','text','Segundo mensaje','received','2026-08-15T12:01:00-05:00','2026-08-15T12:01:00-05:00'
);

select is((select count(*)::bigint from public.aos_wa_conversations_v1),1::bigint,'second inbound reuses conversation');
select is((select message_count from public.aos_wa_conversations_v1 limit 1),2,'second inbound increments message count');
select is((select unread_count from public.aos_wa_conversations_v1 limit 1),2,'second inbound increments unread count');

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,sent_at
) values (
  'wamid.synthetic.outbound1','OUTBOUND','51999111222','phone-A','text','Respuesta humana','accepted','2026-08-15T12:02:00-05:00','2026-08-15T12:02:00-05:00'
);

select is((select message_count from public.aos_wa_conversations_v1 limit 1),3,'outbound increments total message count');
select is((select unread_count from public.aos_wa_conversations_v1 limit 1),2,'outbound does not increment unread');
select is((select count(distinct conversation_id)::bigint from public.aos_wa_messages_v1),1::bigint,'all messages bind to one canonical conversation');

update public.aos_wa_conversations_v1 set state='CLOSED',closed_at=now();
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.reopen','INBOUND','51999111222','phone-A','text','Nueva consulta','received','2026-08-15T12:03:00-05:00','2026-08-15T12:03:00-05:00'
);

select is((select state from public.aos_wa_conversations_v1 limit 1),'NEW','new inbound reopens a closed conversation');
select ok((select closed_at is null from public.aos_wa_conversations_v1 limit 1),'reopened conversation clears closed_at');
select is((select count(*)::bigint from public.aos_paneles_disponibles where id='admin-whatsapp'),1::bigint,'admin-whatsapp permission is registered');
select ok((select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='11111111-1111-4111-8111-111111111111'),'level-1 2FA canary receives panel');
select ok(not (select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='22222222-2222-4222-8222-222222222222'),'level-2 admin is not auto-enabled');
select ok(not (select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='33333333-3333-4333-8333-333333333333'),'advisor is not auto-enabled');
select ok(not has_function_privilege('anon','public.aos_wa2_bind_conversation_v1()','EXECUTE'),'anon cannot execute projection function directly');
select is((select conversation_key from public.aos_wa_conversations_v1 limit 1),'phone-A:51999111222','conversation key is deterministic');

select * from finish();
rollback;
