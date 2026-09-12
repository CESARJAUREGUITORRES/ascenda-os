\set ON_ERROR_STOP on
do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then execute 'create role anon nologin'; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then execute 'create role authenticated nologin'; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then execute 'create role service_role nologin'; end if;
end $$;

create table public.aos_integraciones (
  id uuid primary key,
  tipo text,
  nombre text,
  cuenta text default '',
  config jsonb default '{}'::jsonb,
  estado text default 'pendiente',
  principal boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  categoria text,
  icono text,
  descripcion text,
  api_key text,
  api_secret text,
  webhook_url text,
  pasos_guia jsonb default '[]'::jsonb,
  uso_para text[] default '{}',
  orden integer,
  url_api text,
  url_docs text,
  url_signup text,
  multi_cuenta boolean default false,
  logo_url text
);

create table public.aos_agenda_citas (
  id text primary key default gen_random_uuid()::text,
  fecha_cita date,
  tratamiento text,
  tipo_cita text,
  sede text,
  numero text,
  nombre text,
  apellido text,
  dni text,
  correo text,
  asesor text,
  id_asesor text,
  estado_cita text,
  venta_id_match text,
  obs text,
  ts_creado timestamptz default now(),
  ts_actualizado timestamptz default now(),
  hora_cita text,
  etiqueta_campana text,
  doctora text,
  tipo_atencion text,
  gcal_event_id text,
  origen_cita text,
  numero_limpio text,
  origen text,
  plan_item_id text,
  cotizacion_item_id text,
  sesion_numero integer,
  lead_id_origen bigint,
  llamada_id_origen bigint
);

create table public.aos_pacientes (
  "ID_PACIENTE" text primary key,
  "Nombres" text,
  "Apellidos" text,
  "Teléfono" text,
  "Email" text,
  "N° documento" text,
  numero_limpio text,
  tratamiento_principal text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.aos_booking_operations_v2 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  request_hash text not null,
  operation_type text not null,
  channel text not null,
  actor_id uuid,
  conversation_id uuid,
  appointment_id text,
  treatment_id uuid,
  professional_ref text,
  site text,
  appointment_date date,
  appointment_time time,
  identity_state text,
  campaign_source text,
  ad_id text,
  lead_id text,
  status text not null,
  response jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table public.aos_wa4_booking_actions_v1 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  request_hash text not null,
  conversation_id uuid,
  actor_id uuid,
  agenda_id text,
  treatment_id uuid,
  professional_id text,
  site text,
  appointment_date date,
  appointment_time time,
  identity_state text,
  source_channel text,
  campaign_source text,
  ad_id text,
  lead_id text,
  status text not null,
  created_at timestamptz default now()
);

insert into public.aos_integraciones(
 id,tipo,nombre,categoria,descripcion,estado,cuenta,config,pasos_guia,multi_cuenta
) values (
 '8587b7fa-96cd-409c-b814-e7d2261cd0c8','google','Google Calendar + Contacts','google',
 'Calendario, contactos y Drive integrados con el sistema','pendiente','',
 '{}'::jsonb,'[]'::jsonb,true
);
