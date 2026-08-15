begin;
create extension if not exists pgtap;
select plan(51);

select has_table('public','aos_wa_conversations_v1','conversation store exists');
select has_table('public','aos_wa_conversation_events_v1','conversation event ledger exists');
select has_column('public','aos_wa_messages_v1','conversation_id','WA-1 messages link to WA-2 conversation');
select has_trigger('public','aos_wa_messages_v1','trg_aos_wa2_bind_conversation_v1','bind trigger exists');
select has_trigger('public','aos_wa_messages_v1','trg_aos_wa2_project_insert_v1','insert projection trigger exists');
select has_trigger('public','aos_wa_messages_v1','trg_aos_wa2_project_backfill_v1','backfill projection trigger exists');
select ok(to_regprocedure('public.aos_wa2_bind_conversation_v1()') is not null,'bind function exists');
select ok(to_regprocedure('public.aos_wa2_project_message_v1()') is not null,'projection function exists');
select ok(not (select prosecdef from pg_proc where oid='public.aos_wa2_bind_conversation_v1()'::regprocedure),'bind function is not SECURITY DEFINER');
select ok(not (select prosecdef from pg_proc where oid='public.aos_wa2_project_message_v1()'::regprocedure),'projection function is not SECURITY DEFINER');
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

-- Provider retry: BEFORE INSERT still runs in PostgreSQL, but WA-2 bind must have no
-- projection side effect. ON CONFLICT update must not inflate counts.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,contact_name,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.inbound2','INBOUND','51999111222','phone-A','Paciente Sintético','text','Segundo mensaje reenviado','received','2026-08-15T12:01:00-05:00','2026-08-15T12:01:00-05:00'
)
on conflict (provider_message_id) do update
set message_body=excluded.message_body,status=excluded.status;

select is((select message_count from public.aos_wa_conversations_v1 limit 1),3,'duplicate provider retry does not inflate message count');
select is((select unread_count from public.aos_wa_conversations_v1 limit 1),2,'duplicate provider retry does not inflate unread count');

update public.aos_wa_conversations_v1
set state='CLOSED',closed_at='2026-08-15T12:02:30-05:00'::timestamptz;
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.reopen','INBOUND','51999111222','phone-A','text','Nueva consulta','received','2026-08-15T12:03:00-05:00','2026-08-15T12:03:00-05:00'
);

select is((select state from public.aos_wa_conversations_v1 limit 1),'NEW','new inbound after closure reopens conversation');
select ok((select closed_at is null from public.aos_wa_conversations_v1 limit 1),'reopened conversation clears closed_at');
select is((select count(*)::bigint from public.aos_paneles_disponibles where id='admin-whatsapp'),1::bigint,'admin-whatsapp permission is registered');
select ok((select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='11111111-1111-4111-8111-111111111111'),'level-1 2FA canary receives panel');
select ok(not (select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='22222222-2222-4222-8222-222222222222'),'level-2 admin is not auto-enabled');
select ok(not (select 'admin-whatsapp'=any(paneles_acceso) from public.aos_usuarios where id='33333333-3333-4333-8333-333333333333'),'advisor is not auto-enabled');
select ok(not has_function_privilege('anon','public.aos_wa2_bind_conversation_v1()','EXECUTE'),'anon cannot execute bind function directly');
select ok(not has_function_privilege('anon','public.aos_wa2_project_message_v1()','EXECUTE'),'anon cannot execute projection function directly');
select is((select conversation_key from public.aos_wa_conversations_v1 limit 1),'phone-A:51999111222','conversation key is deterministic');

-- Meta/provider events can arrive out of order. Older events remain part of history,
-- but must never replace the latest preview/timestamps.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.delayed1','INBOUND','51999111222','phone-A','text','Mensaje retrasado','received','2026-08-15T11:59:00-05:00','2026-08-15T12:05:00-05:00'
);

select is((select last_message_id from public.aos_wa_conversations_v1 limit 1),'wamid.synthetic.reopen','delayed event does not replace latest message id');
select is((select last_message_preview from public.aos_wa_conversations_v1 limit 1),'Nueva consulta','delayed event does not replace latest preview');
select is((select last_inbound_at from public.aos_wa_conversations_v1 limit 1),'2026-08-15T12:03:00-05:00'::timestamptz,'last inbound remains provider-time maximum');
select is((select first_inbound_at from public.aos_wa_conversations_v1 limit 1),'2026-08-15T11:59:00-05:00'::timestamptz,'first inbound uses provider-time minimum');

-- A delayed inbound older than the operator read/close boundary must neither reopen
-- the conversation nor create a false unread badge.
update public.aos_wa_conversations_v1
set state='CLOSED',
    closed_at='2026-08-15T12:04:00-05:00'::timestamptz,
    unread_count=0,
    last_read_at='2026-08-15T12:03:30-05:00'::timestamptz;

insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.synthetic.delayed2','INBOUND','51999111222','phone-A','text','Mensaje viejo posterior','received','2026-08-15T11:58:00-05:00','2026-08-15T12:06:00-05:00'
);

select is((select state from public.aos_wa_conversations_v1 limit 1),'CLOSED','old delayed inbound does not reopen closed conversation');
select is((select closed_at from public.aos_wa_conversations_v1 limit 1),'2026-08-15T12:04:00-05:00'::timestamptz,'old delayed inbound preserves closed_at');
select is((select unread_count from public.aos_wa_conversations_v1 limit 1),0,'old delayed inbound older than last_read_at stays read');
select is((select last_message_id from public.aos_wa_conversations_v1 limit 1),'wamid.synthetic.reopen','old delayed inbound still cannot replace latest message');

select * from finish();
rollback;
