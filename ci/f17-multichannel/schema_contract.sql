\set ON_ERROR_STOP on

create role anon nologin;
create role authenticated nologin;

create table public.aos_plantillas_whatsapp (
  id bigint generated always as identity primary key,
  nombre text not null,
  contenido text not null,
  activo boolean not null default true,
  orden integer not null default 0
);

create table public.aos_whatsapp_mensajes (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now()
);

-- Reproduce the risky production baseline for the migration test.
grant all privileges on table public.aos_plantillas_whatsapp to anon, authenticated;
grant select on table public.aos_whatsapp_mensajes to anon, authenticated;