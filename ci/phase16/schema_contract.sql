-- Synthetic dependency contract for CIA F16 Zero-Cost CI.
-- No production data, emails, phone numbers, tokens or provider credentials.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end
$roles$;

create table public.aos_usuarios (
  id uuid primary key,
  nombre text not null
);

create table public.aos_audiencia_activaciones (
  id uuid primary key,
  audiencia_id uuid,
  audiencia_version_id uuid,
  created_at timestamptz not null default now()
);

create table public.aos_audiencia_activacion_config (
  activacion_id uuid primary key references public.aos_audiencia_activaciones(id),
  snapshot_id uuid,
  nombre text,
  purpose text,
  channel text,
  mode text,
  baseline_count integer,
  baseline_resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by_user_id uuid,
  created_at timestamptz not null default now()
);

create table public.aos_audiencia_activacion_estado (
  activacion_id uuid primary key references public.aos_audiencia_activaciones(id),
  estado text not null,
  updated_by_user_id uuid,
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz
);

create table public.aos_cia_activation_members_fixture (
  activation_id uuid not null,
  contact_key text not null,
  primary key (activation_id, contact_key)
);

create table public.aos_cia_audience_source_v1_1 (
  contact_key text primary key,
  identity_conflict boolean not null default false,
  canonical_email text,
  email_valid boolean,
  email_bounced_count integer not null default 0,
  facts_observed_at timestamptz,
  email_last_event_at timestamptz
);

create or replace function public.aos_cia_activation_member_keys_v1(p_activation_id uuid)
returns table(contact_key text)
language sql
stable
set search_path=''
as $function$
  select f.contact_key
  from public.aos_cia_activation_members_fixture f
  where f.activation_id=p_activation_id
  order by f.contact_key
$function$;

create or replace function public.aos_cia_verify_admin_session_v1(p_token text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $function$
  select case when p_token='synthetic-admin-token'
    then jsonb_build_object('ok',true,'user_id','00000000-0000-0000-0000-000000000001')
    else jsonb_build_object('ok',false,'error','UNAUTHORIZED') end
$function$;

create or replace function public.aos_cia_kronia_f16_readiness_v1()
returns jsonb
language sql
stable
set search_path=''
as $function$
  select jsonb_build_object(
    'ok',true,
    'status','READY_GOVERNED_ORCHESTRATION',
    'mode','GOVERNED_SHADOW',
    'ready_for_f16',true,
    'audit',jsonb_build_object('auto_execute_calls',0,'auto_execute_proposals',0),
    'registry',jsonb_build_object('active_tools',6,'active_agents',6,'bad_tools',0,'bad_agents',0)
  )
$function$;

revoke all on table public.aos_usuarios from anon, authenticated;
revoke all on table public.aos_audiencia_activaciones from anon, authenticated;
revoke all on table public.aos_audiencia_activacion_config from anon, authenticated;
revoke all on table public.aos_audiencia_activacion_estado from anon, authenticated;
revoke all on table public.aos_cia_activation_members_fixture from anon, authenticated;
revoke all on table public.aos_cia_audience_source_v1_1 from anon, authenticated;
