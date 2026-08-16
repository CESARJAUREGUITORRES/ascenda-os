\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END
$$;

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
