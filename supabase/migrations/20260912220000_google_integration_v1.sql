-- INT-GOOGLE-001 / Google Calendar + Contacts V1
-- Additive foundation. No external HTTP occurs in PostgreSQL.

create table if not exists public.aos_google_connections_v1 (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references public.aos_integraciones(id) on delete cascade,
  account_email text not null,
  google_account_id text,
  refresh_token_enc text,
  granted_scopes text[] not null default '{}'::text[],
  selected_calendar_id text not null default 'primary',
  selected_calendar_name text,
  calendar_enabled boolean not null default false,
  contacts_enabled boolean not null default false,
  is_primary boolean not null default false,
  status text not null default 'CONNECTED'
    check (status in ('CONNECTED','ERROR','REVOKED','DISCONNECTED')),
  connected_by text,
  token_version integer not null default 1 check (token_version > 0),
  last_success_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (integration_id, account_email)
);

create unique index if not exists uq_aos_google_connections_v1_primary
  on public.aos_google_connections_v1(integration_id)
  where is_primary and status = 'CONNECTED';

create index if not exists idx_aos_google_connections_v1_status
  on public.aos_google_connections_v1(status, integration_id);

alter table public.aos_google_connections_v1 enable row level security;
alter table public.aos_google_connections_v1 force row level security;
revoke all on public.aos_google_connections_v1 from anon, authenticated;
grant all on public.aos_google_connections_v1 to service_role;

create table if not exists public.aos_google_oauth_states_v1 (
  state_hash text primary key,
  integration_id uuid not null references public.aos_integraciones(id) on delete cascade,
  session_fingerprint text not null,
  requested_by text,
  return_to text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_aos_google_oauth_states_v1_expiry
  on public.aos_google_oauth_states_v1(expires_at)
  where consumed_at is null;

alter table public.aos_google_oauth_states_v1 enable row level security;
alter table public.aos_google_oauth_states_v1 force row level security;
revoke all on public.aos_google_oauth_states_v1 from anon, authenticated;
grant all on public.aos_google_oauth_states_v1 to service_role;

create table if not exists public.aos_google_calendar_links_v1 (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.aos_google_connections_v1(id) on delete cascade,
  appointment_id text not null references public.aos_agenda_citas(id) on delete cascade,
  calendar_id text not null,
  event_id text not null,
  html_link text,
  schedule_hash text,
  sync_status text not null default 'SYNCED'
    check (sync_status in ('PENDING','SYNCED','ERROR','DELETED')),
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(connection_id, appointment_id),
  unique(connection_id, calendar_id, event_id)
);

create index if not exists idx_aos_google_calendar_links_v1_appointment
  on public.aos_google_calendar_links_v1(appointment_id);

alter table public.aos_google_calendar_links_v1 enable row level security;
alter table public.aos_google_calendar_links_v1 force row level security;
revoke all on public.aos_google_calendar_links_v1 from anon, authenticated;
grant all on public.aos_google_calendar_links_v1 to service_role;

create table if not exists public.aos_google_contact_links_v1 (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.aos_google_connections_v1(id) on delete cascade,
  patient_id text not null references public.aos_pacientes("ID_PACIENTE") on delete cascade,
  resource_name text not null,
  etag text,
  payload_hash text,
  sync_status text not null default 'SYNCED'
    check (sync_status in ('PENDING','SYNCED','ERROR','DELETED','REVIEW')),
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(connection_id, patient_id),
  unique(connection_id, resource_name)
);

create index if not exists idx_aos_google_contact_links_v1_patient
  on public.aos_google_contact_links_v1(patient_id);

alter table public.aos_google_contact_links_v1 enable row level security;
alter table public.aos_google_contact_links_v1 force row level security;
revoke all on public.aos_google_contact_links_v1 from anon, authenticated;
grant all on public.aos_google_contact_links_v1 to service_role;

create table if not exists public.aos_google_sync_outbox_v1 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  connection_id uuid not null references public.aos_google_connections_v1(id) on delete cascade,
  entity_type text not null check (entity_type in ('APPOINTMENT','PATIENT')),
  entity_id text not null,
  action text not null check (action in ('CALENDAR_UPSERT','CALENDAR_DELETE','CONTACT_UPSERT')),
  payload jsonb not null default '{}'::jsonb,
  state text not null default 'READY'
    check (state in ('READY','CLAIMED','ACCEPTED','FAILED','SUPERSEDED','SKIPPED')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  accepted_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_aos_google_sync_outbox_v1_ready
  on public.aos_google_sync_outbox_v1(state, available_at, created_at)
  where state in ('READY','FAILED');

create index if not exists idx_aos_google_sync_outbox_v1_entity
  on public.aos_google_sync_outbox_v1(entity_type, entity_id, created_at desc);

alter table public.aos_google_sync_outbox_v1 enable row level security;
alter table public.aos_google_sync_outbox_v1 force row level security;
revoke all on public.aos_google_sync_outbox_v1 from anon, authenticated;
grant all on public.aos_google_sync_outbox_v1 to service_role;

create or replace function public.aos_google_claim_sync_v1(
  p_worker text,
  p_limit integer default 10
)
returns setof public.aos_google_sync_outbox_v1
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  with picked as (
    select q.id
    from public.aos_google_sync_outbox_v1 q
    where q.state in ('READY','FAILED')
      and q.available_at <= now()
      and q.attempt_count < 8
    order by q.created_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit,10),50))
  )
  update public.aos_google_sync_outbox_v1 q
     set state='CLAIMED',
         attempt_count=q.attempt_count+1,
         locked_at=now(),
         locked_by=left(coalesce(p_worker,'google-worker'),120),
         updated_at=now()
   where q.id in (select id from picked)
  returning q.*;
end
$$;

revoke all on function public.aos_google_claim_sync_v1(text,integer) from public, anon, authenticated;
grant execute on function public.aos_google_claim_sync_v1(text,integer) to service_role;

-- External Google side effects are intentionally NOT triggered directly from legacy
-- agenda/patient table writes. Legacy UI writes enqueue through the authenticated Node boundary.
-- Governed booking ledgers are browser-write-closed and may enqueue internally.

create or replace function public.aos_google_enqueue_authorized_appointment_v1(
  p_appointment_id text,
  p_action text default 'CALENDAR_UPSERT',
  p_source text default 'GOVERNED_BOOKING'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $
declare
  c record;
  a public.aos_agenda_citas%rowtype;
  v_revision text;
  v_action text := upper(coalesce(p_action,'CALENDAR_UPSERT'));
begin
  if nullif(btrim(coalesce(p_appointment_id,'')),'') is null then return; end if;
  if v_action not in ('CALENDAR_UPSERT','CALENDAR_DELETE') then
    raise exception 'GOOGLE_SYNC_INVALID_ACTION';
  end if;

  if v_action='CALENDAR_UPSERT' then
    select * into a from public.aos_agenda_citas where id=p_appointment_id limit 1;
    if not found then return; end if;
    if upper(coalesce(a.estado_cita,'')) in ('CANCELADA','REAGENDADA') then
      v_action:='CALENDAR_DELETE';
    end if;
  end if;

  v_revision := case
    when v_action='CALENDAR_DELETE' then md5(coalesce(p_appointment_id,'')||'|DELETE')
    else md5(concat_ws('|',
      coalesce(a.id,''),coalesce(a.fecha_cita::text,''),coalesce(a.hora_cita,''),
      coalesce(a.tratamiento,''),coalesce(a.sede,''),coalesce(a.nombre,''),
      coalesce(a.apellido,''),coalesce(a.correo,''),coalesce(a.numero_limpio,a.numero,''),
      coalesce(a.doctora,''),coalesce(a.estado_cita,'')
    ))
  end;

  for c in
    select id,calendar_enabled,contacts_enabled
    from public.aos_google_connections_v1
    where status='CONNECTED' and is_primary=true
      and (calendar_enabled=true or contacts_enabled=true)
  loop
    if c.calendar_enabled then
      insert into public.aos_google_sync_outbox_v1(
        idempotency_key,connection_id,entity_type,entity_id,action,payload
      ) values (
        'gcal-governed:'||c.id::text||':'||p_appointment_id||':'||v_action||':'||v_revision,
        c.id,'APPOINTMENT',p_appointment_id,v_action,
        jsonb_build_object('revision',v_revision,'source',coalesce(p_source,'GOVERNED_BOOKING'))
      )
      on conflict(idempotency_key) do nothing;
    end if;

    if c.contacts_enabled and v_action='CALENDAR_UPSERT' then
      insert into public.aos_google_sync_outbox_v1(
        idempotency_key,connection_id,entity_type,entity_id,action,payload
      ) values (
        'gcontact-governed:'||c.id::text||':'||p_appointment_id||':'||v_revision,
        c.id,'APPOINTMENT',p_appointment_id,'CONTACT_UPSERT',
        jsonb_build_object('revision',v_revision,'source',coalesce(p_source,'GOVERNED_BOOKING'))
      )
      on conflict(idempotency_key) do nothing;
    end if;
  end loop;
end
$;

revoke all on function public.aos_google_enqueue_authorized_appointment_v1(text,text,text) from public, anon, authenticated;
grant execute on function public.aos_google_enqueue_authorized_appointment_v1(text,text,text) to service_role;

create or replace function public.aos_google_booking_operation_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $
begin
  if new.operation_type in ('BOOK','REBOOK')
     and new.status in ('BOOKED','REBOOKED')
     and nullif(btrim(coalesce(new.appointment_id,'')),'') is not null then
    perform public.aos_google_enqueue_authorized_appointment_v1(
      new.appointment_id,'CALENDAR_UPSERT','BOOKING_OPERATIONS_V2'
    );
  end if;
  return new;
end
$;

drop trigger if exists trg_aos_google_booking_operation_v1 on public.aos_booking_operations_v2;
create trigger trg_aos_google_booking_operation_v1
after insert or update of status,appointment_id on public.aos_booking_operations_v2
for each row execute function public.aos_google_booking_operation_trigger_v1();

create or replace function public.aos_google_wa4_booking_action_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $
declare
  v_action text;
begin
  if nullif(btrim(coalesce(new.agenda_id,'')),'') is null then return new; end if;
  if new.status='BOOKED' then v_action:='CALENDAR_UPSERT';
  elsif new.status in ('CANCELLED','REPLACED') then v_action:='CALENDAR_DELETE';
  else return new;
  end if;

  perform public.aos_google_enqueue_authorized_appointment_v1(
    new.agenda_id,v_action,'WA4_BOOKING_ACTIONS_V1'
  );
  return new;
end
$;

drop trigger if exists trg_aos_google_wa4_booking_action_v1 on public.aos_wa4_booking_actions_v1;
create trigger trg_aos_google_wa4_booking_action_v1
after insert or update of status,agenda_id on public.aos_wa4_booking_actions_v1
for each row execute function public.aos_google_wa4_booking_action_trigger_v1();

update public.aos_integraciones
set descripcion='Google Calendar y Contactos mediante OAuth seguro; cuenta reemplazable desde ASCENDA',
    multi_cuenta=true,
    config=coalesce(config,'{}'::jsonb) || jsonb_build_object(
      'calendar_timezone','America/Lima',
      'contact_name_template','{nombre} {apellido} - {tag} - {mes}{yy}',
      'contact_tag_source','tratamiento',
      'contact_month_source','registro',
      'send_calendar_invites',true,
      'oauth_mode','server'
    ),
    pasos_guia=jsonb_build_array(
      jsonb_build_object('titulo','Conectar Google','texto','Autoriza una cuenta Google desde ASCENDA; no pegues contraseñas ni tokens.'),
      jsonb_build_object('titulo','Calendar','texto','Elige el calendario que recibirá las citas.'),
      jsonb_build_object('titulo','Contacts','texto','Activa la sincronización de contactos después del canary.')
    ),
    updated_at=now()
where tipo='google' and nombre='Google Calendar + Contacts';
