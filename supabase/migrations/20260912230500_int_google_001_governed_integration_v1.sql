-- ASCENDA OS · INT-GOOGLE-001 — Google Calendar + Contacts governed integration V1
-- Additive, dormant by default. Google remains a projection; ASCENDA Agenda/Patient Identity stay canonical.

begin;

create table if not exists public.aos_google_oauth_states_v1 (
  state_hash text primary key,
  actor_id uuid not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now()
);

create table if not exists public.aos_google_connections_v1 (
  id uuid primary key default gen_random_uuid(),
  tenant_key text not null default 'ZIVITAL',
  owner_actor_id uuid not null,
  provider_account_id text not null,
  account_email text not null,
  refresh_token_ciphertext text not null,
  token_iv text not null,
  token_tag text not null,
  token_expires_at timestamptz null,
  granted_scopes text[] not null default '{}'::text[],
  calendar_id text not null default 'primary',
  calendar_summary text null,
  status text not null default 'CONNECTED' check (status in ('CONNECTED','DISCONNECTED','ERROR')),
  connected_at timestamptz not null default now(),
  disconnected_at timestamptz null,
  last_verified_at timestamptz null,
  last_error_code text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_aos_google_connections_v1_active_tenant
  on public.aos_google_connections_v1(tenant_key)
  where status='CONNECTED';

create table if not exists public.aos_google_calendar_links_v1 (
  appointment_id text primary key,
  connection_id uuid not null references public.aos_google_connections_v1(id),
  calendar_id text not null,
  google_event_id text not null,
  html_link text null,
  schedule_revision text not null,
  etag text null,
  state text not null default 'ACTIVE' check (state in ('ACTIVE','DELETED','ERROR')),
  last_synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_google_contact_links_v1 (
  patient_ref text primary key,
  connection_id uuid not null references public.aos_google_connections_v1(id),
  resource_name text not null,
  etag text null,
  source_fingerprint text not null,
  state text not null default 'ACTIVE' check (state in ('ACTIVE','REVIEW','ERROR')),
  conflict_reason text null,
  last_synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_google_sync_outbox_v1 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  entity_kind text not null check (entity_kind in ('APPOINTMENT','PATIENT')),
  entity_ref text not null,
  operation text not null check (operation in ('CALENDAR_UPSERT','CALENDAR_DELETE','CONTACT_UPSERT')),
  source_revision text not null,
  state text not null default 'DORMANT' check (state in ('DORMANT','CLAIMED','DONE','FAILED','SKIPPED','REVIEW')),
  attempt_count integer not null default 0 check (attempt_count>=0),
  available_at timestamptz not null default now(),
  lease_until timestamptz null,
  provider_ref text null,
  last_error_code text null,
  last_attempt_at timestamptz null,
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_aos_google_sync_outbox_v1_work
  on public.aos_google_sync_outbox_v1(state,available_at,created_at)
  where state in ('DORMANT','FAILED');
create index if not exists idx_aos_google_sync_outbox_v1_entity
  on public.aos_google_sync_outbox_v1(entity_kind,entity_ref,created_at desc);

create index if not exists idx_aos_google_sync_outbox_v1_claim_lease
  on public.aos_google_sync_outbox_v1(lease_until)
  where state='CLAIMED';


alter table public.aos_google_oauth_states_v1 enable row level security;
alter table public.aos_google_oauth_states_v1 force row level security;
alter table public.aos_google_connections_v1 enable row level security;
alter table public.aos_google_connections_v1 force row level security;
alter table public.aos_google_calendar_links_v1 enable row level security;
alter table public.aos_google_calendar_links_v1 force row level security;
alter table public.aos_google_contact_links_v1 enable row level security;
alter table public.aos_google_contact_links_v1 force row level security;
alter table public.aos_google_sync_outbox_v1 enable row level security;
alter table public.aos_google_sync_outbox_v1 force row level security;

revoke all on table public.aos_google_oauth_states_v1 from public,anon,authenticated;
revoke all on table public.aos_google_connections_v1 from public,anon,authenticated;
revoke all on table public.aos_google_calendar_links_v1 from public,anon,authenticated;
revoke all on table public.aos_google_contact_links_v1 from public,anon,authenticated;
revoke all on table public.aos_google_sync_outbox_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_google_oauth_states_v1 to service_role;
grant select,insert,update,delete on table public.aos_google_connections_v1 to service_role;
grant select,insert,update,delete on table public.aos_google_calendar_links_v1 to service_role;
grant select,insert,update,delete on table public.aos_google_contact_links_v1 to service_role;
grant select,insert,update,delete on table public.aos_google_sync_outbox_v1 to service_role;

create or replace function public.aos_google_enqueue_agenda_event_v1()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_rev text:=new.id::text;
begin
  if new.event_type not in ('BOOKED','RESCHEDULED') then return new; end if;

  insert into public.aos_google_sync_outbox_v1(
    idempotency_key,entity_kind,entity_ref,operation,source_revision,state
  ) values (
    'google:calendar:'||new.appointment_id||':'||v_rev,
    'APPOINTMENT',new.appointment_id,'CALENDAR_UPSERT',v_rev,'DORMANT'
  ) on conflict(idempotency_key) do nothing;

  insert into public.aos_google_sync_outbox_v1(
    idempotency_key,entity_kind,entity_ref,operation,source_revision,state
  ) values (
    'google:contact:'||new.appointment_id||':'||v_rev,
    'PATIENT',new.appointment_id,'CONTACT_UPSERT',v_rev,'DORMANT'
  ) on conflict(idempotency_key) do nothing;

  return new;
exception when others then
  -- Google projection must never block canonical booking.
  return new;
end
$$;

drop trigger if exists trg_aos_google_enqueue_agenda_event_v1 on public.aos_agenda_events_v2;
create trigger trg_aos_google_enqueue_agenda_event_v1
after insert on public.aos_agenda_events_v2
for each row execute function public.aos_google_enqueue_agenda_event_v1();

create or replace function public.aos_google_enqueue_cancel_v1()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_old text:=upper(btrim(coalesce(old.estado_cita,'')));
  v_new text:=upper(btrim(coalesce(new.estado_cita,'')));
  v_rev text:=coalesce(new.ts_actualizado,now())::text;
begin
  if v_new='CANCELADA' and v_old is distinct from 'CANCELADA' then
    insert into public.aos_google_sync_outbox_v1(
      idempotency_key,entity_kind,entity_ref,operation,source_revision,state
    ) values (
      'google:calendar-delete:'||new.id||':'||md5(v_rev),
      'APPOINTMENT',new.id,'CALENDAR_DELETE',v_rev,'DORMANT'
    ) on conflict(idempotency_key) do nothing;
  end if;
  return new;
exception when others then
  return new;
end
$$;

drop trigger if exists trg_aos_google_enqueue_cancel_v1 on public.aos_agenda_citas;
create trigger trg_aos_google_enqueue_cancel_v1
after update of estado_cita on public.aos_agenda_citas
for each row execute function public.aos_google_enqueue_cancel_v1();

create or replace function public.aos_google_sync_claim_v1(
  p_limit integer default 5,
  p_calendar boolean default false,
  p_contacts boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $
declare
  v_limit integer:=greatest(1,least(coalesce(p_limit,5),20));
  v_items jsonb;
begin
  with candidates as (
    select o.id
    from public.aos_google_sync_outbox_v1 o
    where (
      (o.state in ('DORMANT','FAILED') and o.available_at<=now())
      or (o.state='CLAIMED' and o.lease_until<now())
    )
      and (
        (coalesce(p_calendar,false) and o.operation in ('CALENDAR_UPSERT','CALENDAR_DELETE'))
        or (coalesce(p_contacts,false) and o.operation='CONTACT_UPSERT')
      )
    order by o.created_at,o.id
    for update skip locked
    limit v_limit
  ), claimed as (
    update public.aos_google_sync_outbox_v1 o
    set state='CLAIMED',
        attempt_count=o.attempt_count+1,
        last_attempt_at=now(),
        lease_until=now()+interval '90 seconds',
        updated_at=now()
    from candidates c
    where o.id=c.id
    returning to_jsonb(o.*) as item
  )
  select coalesce(jsonb_agg(item),'[]'::jsonb) into v_items from claimed;

  return jsonb_build_object('ok',true,'items',coalesce(v_items,'[]'::jsonb));
end
$;

create or replace function public.aos_google_future_backfill_v1(p_limit integer default 500)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_limit integer:=greatest(1,least(coalesce(p_limit,500),2000));
  v_c record;
  v_inserted integer:=0;
  v_key text;
begin
  for v_c in
    select c.id,c.fecha_cita,left(coalesce(c.hora_cita,''),5) as hora_cita,c.ts_actualizado
    from public.aos_agenda_citas c
    where c.fecha_cita>=current_date
      and upper(coalesce(c.estado_cita,'PENDIENTE')) in ('PENDIENTE','CITA CONFIRMADA')
    order by c.fecha_cita,left(coalesce(c.hora_cita,''),5),c.id
    limit v_limit
  loop
    v_key:='backfill:'||v_c.id||':'||v_c.fecha_cita::text||':'||coalesce(v_c.hora_cita,'');
    insert into public.aos_google_sync_outbox_v1(
      idempotency_key,entity_kind,entity_ref,operation,source_revision,state
    ) values (
      'google:calendar:'||v_key,'APPOINTMENT',v_c.id,'CALENDAR_UPSERT',v_key,'DORMANT'
    ) on conflict(idempotency_key) do nothing;
    if found then v_inserted:=v_inserted+1; end if;

    insert into public.aos_google_sync_outbox_v1(
      idempotency_key,entity_kind,entity_ref,operation,source_revision,state
    ) values (
      'google:contact:'||v_key,'PATIENT',v_c.id,'CONTACT_UPSERT',v_key,'DORMANT'
    ) on conflict(idempotency_key) do nothing;
    if found then v_inserted:=v_inserted+1; end if;
  end loop;
  return jsonb_build_object('ok',true,'queued',v_inserted,'state','DORMANT','limit',v_limit);
end
$$;

create or replace function public.aos_google_integration_audit_v1()
returns jsonb
language sql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
select jsonb_build_object(
  'connections_connected',(select count(*) from public.aos_google_connections_v1 where status='CONNECTED'),
  'calendar_links_active',(select count(*) from public.aos_google_calendar_links_v1 where state='ACTIVE'),
  'contact_links_active',(select count(*) from public.aos_google_contact_links_v1 where state='ACTIVE'),
  'contact_links_review',(select count(*) from public.aos_google_contact_links_v1 where state='REVIEW'),
  'outbox_dormant',(select count(*) from public.aos_google_sync_outbox_v1 where state='DORMANT'),
  'outbox_claimed',(select count(*) from public.aos_google_sync_outbox_v1 where state='CLAIMED'),
  'outbox_done',(select count(*) from public.aos_google_sync_outbox_v1 where state='DONE'),
  'outbox_failed',(select count(*) from public.aos_google_sync_outbox_v1 where state='FAILED'),
  'outbox_review',(select count(*) from public.aos_google_sync_outbox_v1 where state='REVIEW'),
  'dispatch_boundary','GOOGLE_SERVER_FLAGS_AND_OAUTH_REQUIRED'
);
$$;

revoke all on function public.aos_google_sync_claim_v1(integer,boolean,boolean) from public,anon,authenticated;
revoke all on function public.aos_google_future_backfill_v1(integer) from public,anon,authenticated;
revoke all on function public.aos_google_integration_audit_v1() from public,anon,authenticated;
revoke all on function public.aos_google_enqueue_agenda_event_v1() from public,anon,authenticated;
revoke all on function public.aos_google_enqueue_cancel_v1() from public,anon,authenticated;
grant execute on function public.aos_google_sync_claim_v1(integer,boolean,boolean) to service_role;
grant execute on function public.aos_google_future_backfill_v1(integer) to service_role;
grant execute on function public.aos_google_integration_audit_v1() to service_role;

comment on table public.aos_google_connections_v1 is 'INT-GOOGLE-001 encrypted server-only OAuth connection metadata. Refresh token bytes are encrypted by the ASCENDA server before storage.';
comment on table public.aos_google_sync_outbox_v1 is 'INT-GOOGLE-001 durable dormant projection queue. No Google HTTP occurs in database triggers or booking transactions.';

commit;
