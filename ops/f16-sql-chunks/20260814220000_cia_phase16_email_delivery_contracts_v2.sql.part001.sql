-- ASCENDA OS CIA V3 — F16 Email delivery/provider contracts v2
-- Additive and fail-closed. No provider call is performed by SQL.
-- Internal dispatch/provider functions are service_role-only; browser access remains through the admin gateway.

begin;

alter table public.aos_cia_email_send_requests
  add column if not exists render_context jsonb not null default '{}'::jsonb;

alter table public.aos_cia_email_send_requests
  drop constraint if exists aos_cia_email_send_requests_render_context_object;
alter table public.aos_cia_email_send_requests
  add constraint aos_cia_email_send_requests_render_context_object
  check (jsonb_typeof(render_context)='object');

create table if not exists public.aos_cia_email_release_state (
  singleton boolean primary key default true check (singleton),
  gateway_active boolean not null default false,
  provider_configured boolean not null default false,
  webhook_verified boolean not null default false,
  admin_ui_gateway_only boolean not null default false,
  legacy_acl_hardened boolean not null default false,
  canary_passed boolean not null default false,
  rollback_verified boolean not null default false,
  evidence jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.aos_cia_email_release_state(singleton)
values(true)
on conflict (singleton) do nothing;

alter table public.aos_cia_email_release_state enable row level security;
revoke all on table public.aos_cia_email_release_state from public,anon,authenticated;
grant select,insert,update on table public.aos_cia_email_release_state to service_role;

create or replace function public.aos_cia_email_request_guard_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.id is distinct from new.id
     or old.correlation_id is distinct from new.correlation_id
     or old.activation_id is distinct from new.activation_id
