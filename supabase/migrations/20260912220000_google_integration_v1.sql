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

create or replace function public.aos_google_enqueue_agenda_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c record;
  v_revision text;
  v_action text;
begin
  if tg_op = 'UPDATE' and
     new.fecha_cita is not distinct from old.fecha_cita and
     new.hora_cita is not distinct from old.hora_cita and
     new.tratamiento is not distinct from old.tratamiento and
     new.sede is not distinct from old.sede and
     new.nombre is not distinct from old.nombre and
     new.apellido is not distinct from old.apellido and
     new.correo is not distinct from old.correo and
     new.numero is not distinct from old.numero and
     new.numero_limpio is not distinct from old.numero_limpio and
     new.doctora is not distinct from old.doctora and
     new.estado_cita is not distinct from old.estado_cita
  then
    return new;
  end if;

  v_revision := md5(concat_ws('|',
    coalesce(new.id,''),
    coalesce(new.fecha_cita::text,''),
    coalesce(new.hora_cita,''),
    coalesce(new.tratamiento,''),
    coalesce(new.sede,''),
    coalesce(new.nombre,''),
    coalesce(new.apellido,''),
    coalesce(new.correo,''),
    coalesce(new.numero_limpio,new.numero,''),
    coalesce(new.doctora,''),
    coalesce(new.estado_cita,'')
  ));

  v_action := case when upper(coalesce(new.estado_cita,''))='CANCELADA'
                   then 'CALENDAR_DELETE' else 'CALENDAR_UPSERT' end;

  for c in
    select id, calendar_enabled, contacts_enabled
    from public.aos_google_connections_v1
    where status='CONNECTED' and is_primary=true
      and (calendar_enabled=true or contacts_enabled=true)
  loop
    if c.calendar_enabled then
      insert into public.aos_google_sync_outbox_v1(
        idempotency_key,connection_id,entity_type,entity_id,action,payload
      ) values (
        'gcal:'||c.id::text||':'||new.id||':'||v_action||':'||v_revision,
        c.id,'APPOINTMENT',new.id,v_action,
        jsonb_build_object('revision',v_revision,'source','aos_agenda_citas')
      )
      on conflict(idempotency_key) do nothing;
    end if;

    if c.contacts_enabled and v_action <> 'CALENDAR_DELETE' then
      insert into public.aos_google_sync_outbox_v1(
        idempotency_key,connection_id,entity_type,entity_id,action,payload
      ) values (
        'gcontact-appt:'||c.id::text||':'||new.id||':'||v_revision,
        c.id,'APPOINTMENT',new.id,'CONTACT_UPSERT',
        jsonb_build_object('revision',v_revision,'source','aos_agenda_citas')
      )
      on conflict(idempotency_key) do nothing;
    end if;
  end loop;

  return new;
end
$$;

drop trigger if exists trg_aos_google_enqueue_agenda_v1 on public.aos_agenda_citas;
create trigger trg_aos_google_enqueue_agenda_v1
after insert or update on public.aos_agenda_citas
for each row execute function public.aos_google_enqueue_agenda_v1();

create or replace function public.aos_google_enqueue_patient_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c record;
  v_revision text;
begin
  if tg_op = 'UPDATE' and
     new."Nombres" is not distinct from old."Nombres" and
     new."Apellidos" is not distinct from old."Apellidos" and
     new."Teléfono" is not distinct from old."Teléfono" and
     new."Email" is not distinct from old."Email" and
     new.numero_limpio is not distinct from old.numero_limpio and
     new.tratamiento_principal is not distinct from old.tratamiento_principal
  then
    return new;
  end if;

  v_revision := md5(concat_ws('|',
    coalesce(new."ID_PACIENTE",''),
    coalesce(new."Nombres",''),
    coalesce(new."Apellidos",''),
    coalesce(new."Teléfono",''),
    coalesce(new."Email",''),
    coalesce(new.numero_limpio,''),
    coalesce(new.tratamiento_principal,'')
  ));

  for c in
    select id
    from public.aos_google_connections_v1
    where status='CONNECTED' and is_primary=true and contacts_enabled=true
  loop
    insert into public.aos_google_sync_outbox_v1(
      idempotency_key,connection_id,entity_type,entity_id,action,payload
    ) values (
      'gcontact-patient:'||c.id::text||':'||new."ID_PACIENTE"||':'||v_revision,
      c.id,'PATIENT',new."ID_PACIENTE",'CONTACT_UPSERT',
      jsonb_build_object('revision',v_revision,'source','aos_pacientes')
    )
    on conflict(idempotency_key) do nothing;
  end loop;

  return new;
end
$$;

drop trigger if exists trg_aos_google_enqueue_patient_v1 on public.aos_pacientes;
create trigger trg_aos_google_enqueue_patient_v1
after insert or update on public.aos_pacientes
for each row execute function public.aos_google_enqueue_patient_v1();

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
