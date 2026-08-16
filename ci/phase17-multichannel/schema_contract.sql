\set ON_ERROR_STOP on
create extension if not exists pgcrypto;
create extension if not exists pgtap;

do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;

create or replace function public.aos_cia_normalize_contact_key_v1(p_raw text)
returns text language sql immutable parallel safe as $$
select case
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=9 then regexp_replace(coalesce(p_raw,''),'\D','','g')
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=11 and left(regexp_replace(coalesce(p_raw,''),'\D','','g'),2)='51'
    then right(regexp_replace(coalesce(p_raw,''),'\D','','g'),9)
  else null
end
$$;

create table public.aos_audiencia_activaciones(
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null default gen_random_uuid(),
  audiencia_version_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.aos_cia_contact_identity_v1(
  contact_key text primary key,
  identity_conflict boolean not null default false
);

create table public.aos_wa_conversations_v1(
  id uuid primary key default gen_random_uuid()
);

create table public.aos_wa_messages_v1(
  id uuid primary key default gen_random_uuid(),
  provider_message_id text not null unique,
  conversation_id uuid references public.aos_wa_conversations_v1(id),
  direction text not null,
  from_number text,
  to_number text,
  message_type text not null,
  message_body text,
  raw_referral jsonb,
  status text not null default 'received',
  campaign_source text,
  ad_id text,
  lead_id text,
  provider_timestamp timestamptz,
  received_at timestamptz,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.aos_wa_messages_v1 enable row level security;
alter table public.aos_wa_messages_v1 force row level security;
revoke all on table public.aos_wa_messages_v1 from public, anon, authenticated;
grant select,insert,update on table public.aos_wa_messages_v1 to service_role;

create or replace function public.aos_cia_email_f17_readiness_v1()
returns jsonb language sql stable as $$
  select jsonb_build_object('ok',true,'status','READY_F17_EMAIL_CERTIFIED','ready_for_f17',true)
$$;

revoke all on function public.aos_cia_email_f17_readiness_v1() from public,anon,authenticated;
grant execute on function public.aos_cia_email_f17_readiness_v1() to service_role;

insert into public.aos_audiencia_activaciones(id)
values ('11111111-1111-4111-8111-111111111111'::uuid);

insert into public.aos_cia_contact_identity_v1(contact_key,identity_conflict)
values ('999111222',false),('999333444',true);

insert into public.aos_wa_conversations_v1(id)
values ('22222222-2222-4222-8222-222222222222'::uuid);

insert into public.aos_wa_messages_v1(
  provider_message_id,conversation_id,direction,from_number,to_number,message_type,message_body,raw_referral,status,campaign_source,ad_id,lead_id,received_at
) values
  ('wamid.fixture.resolved','22222222-2222-4222-8222-222222222222','INBOUND','51999111222',null,'text','sensitive body must never appear in F17 bridge','{"secret":"must-not-project"}'::jsonb,'received','fixture','ad-1','lead-1',now()),
  ('wamid.fixture.unresolved','22222222-2222-4222-8222-222222222222','INBOUND','51999888777',null,'text','another body',null,'received',null,null,null,now());