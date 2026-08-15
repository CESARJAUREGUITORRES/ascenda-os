-- ASCENDA OS CIA V3 — F16 Email governed schema v1
-- Additive only. No legacy Email ACL changes and no provider delivery activation.

create table if not exists public.aos_cia_email_recipient_controls (
  contact_key text primary key,
  marketing_consent text not null default 'UNKNOWN'
    check (marketing_consent in ('ALLOWED','BLOCKED','UNKNOWN')),
  global_suppressed boolean not null default false,
  suppression_reason text,
  source text not null default 'UNKNOWN',
  source_updated_at timestamptz,
  updated_by_user_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_cia_email_recipient_control_events (
  id bigint generated always as identity primary key,
  contact_key text not null,
  event_type text not null check (event_type in ('CREATED','UPDATED')),
  old_value jsonb,
  new_value jsonb not null,
  actor_user_id uuid,
  occurred_at timestamptz not null default now()
);

create table if not exists public.aos_cia_email_template_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  template_key text not null,
  version integer not null check (version > 0),
  purpose text not null check (purpose in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL')),
  subject_template text not null,
  html_template text not null,
  variable_keys text[] not null default '{}'::text[],
  content_digest text not null,
  state text not null default 'SHADOW' check (state in ('SHADOW','ACTIVE','RETIRED')),
  legacy_template_id uuid,
  created_by_user_id uuid not null,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  retired_at timestamptz,
  unique (template_key, version)
);

create table if not exists public.aos_cia_email_send_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  correlation_id uuid not null default extensions.gen_random_uuid(),
  activation_id uuid not null references public.aos_audiencia_activaciones(id) on delete restrict,
  contact_key text not null,
  recipient_email text not null,
  purpose text not null check (purpose in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL')),
  template_version_id uuid not null references public.aos_cia_email_template_versions(id) on delete restrict,
  template_digest text not null,
  idempotency_key text not null unique,
  eligibility_status text not null check (eligibility_status in ('ELIGIBLE','BLOCKED','UNKNOWN')),
  consent_status text not null check (consent_status in ('ALLOWED','BLOCKED','UNKNOWN','NOT_REQUIRED')),
  state text not null default 'PREPARED'
    check (state in ('PREPARED','QUEUED','DISPATCHING','ACCEPTED','DELIVERED','BOUNCED','COMPLAINED','FAILED','CANCELLED')),
  provider text,
  provider_message_id text,
  dispatch_attempts integer not null default 0 check (dispatch_attempts >= 0),
  scheduled_at timestamptz,
  requested_by_user_id uuid not null,
  authorization_provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  delivered_at timestamptz,
  terminal_at timestamptz
);

create unique index if not exists aos_cia_email_send_requests_provider_message_uidx
  on public.aos_cia_email_send_requests(provider, provider_message_id)
  where provider is not null and provider_message_id is not null;

create index if not exists aos_cia_email_send_requests_state_schedule_idx
  on public.aos_cia_email_send_requests(state, scheduled_at, created_at);

create index if not exists aos_cia_email_send_requests_activation_idx
  on public.aos_cia_email_send_requests(activation_id, created_at desc);

create table if not exists public.aos_cia_email_send_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.aos_cia_email_send_requests(id) on delete restrict,
  event_type text not null,
  provider_event_id text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create unique index if not exists aos_cia_email_send_events_provider_event_uidx
  on public.aos_cia_email_send_events(provider_event_id)
  where provider_event_id is not null;

create index if not exists aos_cia_email_send_events_request_idx
  on public.aos_cia_email_send_events(request_id, occurred_at, id);

alter table public.aos_cia_email_recipient_controls enable row level security;
alter table public.aos_cia_email_recipient_control_events enable row level security;
alter table public.aos_cia_email_template_versions enable row level security;
alter table public.aos_cia_email_send_requests enable row level security;
alter table public.aos_cia_email_send_events enable row level security;

revoke all on table public.aos_cia_email_recipient_controls from public, anon, authenticated;
revoke all on table public.aos_cia_email_recipient_control_events from public, anon, authenticated;
revoke all on table public.aos_cia_email_template_versions from public, anon, authenticated;
revoke all on table public.aos_cia_email_send_requests from public, anon, authenticated;
revoke all on table public.aos_cia_email_send_events from public, anon, authenticated;

create or replace function public.aos_cia_email_control_audit_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    insert into public.aos_cia_email_recipient_control_events(contact_key,event_type,old_value,new_value,actor_user_id)
    values(new.contact_key,'CREATED',null,to_jsonb(new),new.updated_by_user_id);
    return new;
  end if;
  new.updated_at := now();
  insert into public.aos_cia_email_recipient_control_events(contact_key,event_type,old_value,new_value,actor_user_id)
  values(new.contact_key,'UPDATED',to_jsonb(old),to_jsonb(new),new.updated_by_user_id);
  return new;
end
$function$;

create or replace function public.aos_cia_email_append_only_guard_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception 'EMAIL_AUDIT_APPEND_ONLY';
end
$function$;

create or replace function public.aos_cia_email_template_guard_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.id is distinct from new.id
     or old.template_key is distinct from new.template_key
     or old.version is distinct from new.version
     or old.purpose is distinct from new.purpose
     or old.subject_template is distinct from new.subject_template
     or old.html_template is distinct from new.html_template
     or old.variable_keys is distinct from new.variable_keys
     or old.content_digest is distinct from new.content_digest
     or old.legacy_template_id is distinct from new.legacy_template_id
     or old.created_by_user_id is distinct from new.created_by_user_id
     or old.created_at is distinct from new.created_at then
    raise exception 'EMAIL_TEMPLATE_VERSION_IMMUTABLE';
  end if;
  if old.state = 'RETIRED' and new.state <> old.state then
    raise exception 'EMAIL_TEMPLATE_RETIRED_TERMINAL';
  end if;
  if old.state = 'SHADOW' and new.state not in ('SHADOW','ACTIVE','RETIRED') then
    raise exception 'EMAIL_TEMPLATE_INVALID_TRANSITION';
  end if;
  if old.state = 'ACTIVE' and new.state not in ('ACTIVE','RETIRED') then
    raise exception 'EMAIL_TEMPLATE_INVALID_TRANSITION';
  end if;
  return new;
end
$function$;

create or replace function public.aos_cia_email_request_guard_v1()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.id is distinct from new.id
     or old.correlation_id is distinct from new.correlation_id
     or old.activation_id is distinct from new.activation_id
     or old.contact_key is distinct from new.contact_key
     or old.recipient_email is distinct from new.recipient_email
     or old.purpose is distinct from new.purpose
     or old.template_version_id is distinct from new.template_version_id
     or old.template_digest is distinct from new.template_digest
     or old.idempotency_key is distinct from new.idempotency_key
     or old.eligibility_status is distinct from new.eligibility_status
     or old.consent_status is distinct from new.consent_status
     or old.requested_by_user_id is distinct from new.requested_by_user_id
     or old.authorization_provenance is distinct from new.authorization_provenance
     or old.created_at is distinct from new.created_at then
    raise exception 'EMAIL_SEND_REQUEST_IDENTITY_IMMUTABLE';
  end if;

  if old.state is distinct from new.state then
    if not (
      (old.state = 'PREPARED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'QUEUED' and new.state in ('DISPATCHING','CANCELLED')) or
      (old.state = 'DISPATCHING' and new.state in ('ACCEPTED','FAILED','QUEUED','CANCELLED')) or
      (old.state = 'FAILED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'ACCEPTED' and new.state in ('DELIVERED','BOUNCED','COMPLAINED','FAILED'))
    ) then
      raise exception 'EMAIL_SEND_REQUEST_INVALID_TRANSITION:%->%', old.state, new.state;
    end if;
  end if;

  new.updated_at := now();
  if new.state in ('DELIVERED','BOUNCED','COMPLAINED','CANCELLED') and new.terminal_at is null then
    new.terminal_at := now();
  end if;
  return new;
end
$function$;

drop trigger if exists trg_aos_cia_email_control_audit_v1 on public.aos_cia_email_recipient_controls;
create trigger trg_aos_cia_email_control_audit_v1
before insert or update on public.aos_cia_email_recipient_controls
for each row execute function public.aos_cia_email_control_audit_v1();

drop trigger if exists trg_aos_cia_email_control_events_append_only_v1 on public.aos_cia_email_recipient_control_events;
create trigger trg_aos_cia_email_control_events_append_only_v1
before update or delete on public.aos_cia_email_recipient_control_events
for each row execute function public.aos_cia_email_append_only_guard_v1();

drop trigger if exists trg_aos_cia_email_template_guard_v1 on public.aos_cia_email_template_versions;
create trigger trg_aos_cia_email_template_guard_v1
before update on public.aos_cia_email_template_versions
for each row execute function public.aos_cia_email_template_guard_v1();

drop trigger if exists trg_aos_cia_email_request_guard_v1 on public.aos_cia_email_send_requests;
create trigger trg_aos_cia_email_request_guard_v1
before update on public.aos_cia_email_send_requests
for each row execute function public.aos_cia_email_request_guard_v1();

drop trigger if exists trg_aos_cia_email_send_events_append_only_v1 on public.aos_cia_email_send_events;
create trigger trg_aos_cia_email_send_events_append_only_v1
before update or delete on public.aos_cia_email_send_events
for each row execute function public.aos_cia_email_append_only_guard_v1();

revoke all on function public.aos_cia_email_control_audit_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_email_append_only_guard_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_email_template_guard_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_email_request_guard_v1() from public, anon, authenticated;

comment on table public.aos_cia_email_send_requests is 'F16 governed Email request ledger. PREPARED is non-delivery intent; provider dispatch is a separate later gate.';
comment on table public.aos_cia_email_recipient_controls is 'F16 commercial Email control plane. Missing marketing consent remains UNKNOWN/fail-closed.';
