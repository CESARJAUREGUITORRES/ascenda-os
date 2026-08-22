\set ON_ERROR_STOP on

update public.aos_usuarios
set paneles_acceso=(select array_agg(distinct x) from unnest(coalesce(paneles_acceso,'{}'::text[]) || array['whatsapp-agent']) x)
where id in ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555');

select public.aos_wa3_box_upsert_v1(
  '11111111-1111-4111-8111-111111111111',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'V2RACE','WA V2 Race','MANUAL','ACTIVE',false,40
);
select public.aos_wa3_box_member_set_v1(
  '11111111-1111-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '44444444-4444-4444-8444-444444444444',true,3,10
);
select public.aos_wa3_box_member_set_v1(
  '11111111-1111-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '55555555-5555-4555-8555-555555555555',true,3,5
);
select public.aos_wa3_agent_presence_touch_v1('44444444-4444-4444-8444-444444444444','AVAILABLE');
select public.aos_wa3_agent_presence_touch_v1('55555555-5555-4555-8555-555555555555','AVAILABLE');

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state)
values('30000000-0000-4000-8000-000000000001','wa3v2:race','51980000999','V2 Race','NEW')
on conflict(id) do nothing;

select public.aos_wa3_route_v1(
  '30000000-0000-4000-8000-000000000001','dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,
  '11111111-1111-4111-8111-111111111111','V2_CONCURRENCY_SETUP'
);
