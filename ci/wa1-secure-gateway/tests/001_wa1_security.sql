begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select ok(to_regclass('public.aos_wa_messages_v1') is not null,'messages table exists');
select ok(to_regclass('public.aos_wa_events_v1') is not null,'events table exists');
select ok((select relrowsecurity from pg_class where oid='public.aos_wa_messages_v1'::regclass),'messages RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_messages_v1'::regclass),'messages FORCE RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.aos_wa_events_v1'::regclass),'events RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_events_v1'::regclass),'events FORCE RLS enabled');
select ok(not has_table_privilege('anon','public.aos_wa_messages_v1','SELECT'),'anon cannot read canonical WA messages');
select ok(not has_table_privilege('anon','public.aos_wa_messages_v1','INSERT'),'anon cannot insert canonical WA messages');
select ok(not has_table_privilege('authenticated','public.aos_wa_messages_v1','UPDATE'),'authenticated cannot update canonical WA messages');
select ok(has_table_privilege('service_role','public.aos_wa_messages_v1','INSERT'),'service role can ingest canonical WA messages');
select ok(not has_table_privilege('anon','public.aos_wa_events_v1','SELECT'),'anon cannot read WA events');
select ok(has_table_privilege('service_role','public.aos_wa_events_v1','INSERT'),'service role can append WA events');
select ok(not has_table_privilege('anon','public.aos_whatsapp_mensajes','INSERT'),'legacy anon insert closed');
select ok(not has_table_privilege('authenticated','public.aos_whatsapp_mensajes','UPDATE'),'legacy authenticated update closed');

select * from finish();
rollback;
