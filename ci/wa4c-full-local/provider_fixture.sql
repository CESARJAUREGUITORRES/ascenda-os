-- FULL LOCAL only: deterministic provider registry consumed by the real WA-4 runtime.
create extension if not exists pgcrypto;

create table if not exists public.aos_agentes(
  id text primary key,
  nombre text,
  modelo text,
  activo boolean default true
);

create table if not exists public.aos_integraciones(
  id uuid primary key default gen_random_uuid(),
  tipo text not null,
  nombre text not null,
  estado text,
  api_key text default '',
  api_secret text default '',
  config jsonb default '{}'::jsonb,
  updated_at timestamptz default now()
);
alter table public.aos_integraciones enable row level security;
grant all on public.aos_integraciones to anon,authenticated,service_role;

drop policy if exists anon_integ_read_non_auth_provider on public.aos_integraciones;
drop policy if exists anon_integ_write_non_auth_provider on public.aos_integraciones;
create policy anon_integ_read_non_auth_provider on public.aos_integraciones for select to anon using (true);
create policy anon_integ_write_non_auth_provider on public.aos_integraciones for all to anon using (true) with check (true);

insert into public.aos_agentes(id,nombre,modelo) values
  ('analista','Sofia','llama-3.3-70b-versatile'),
  ('analista_mkt','Valentina','llama-3.3-70b-versatile'),
  ('clasificador','Nico','llama-3.3-70b-versatile'),
  ('kronia','KronIA','llama-3.3-70b-versatile'),
  ('planificador','Marco','llama-3.3-70b-versatile'),
  ('recepcion','Maya','llama-3.3-70b-versatile'),
  ('resumidor','Luna','llama-3.3-70b-versatile')
on conflict(id) do update set modelo=excluded.modelo,activo=true;

insert into public.aos_integraciones(tipo,nombre,estado,api_key) values
  ('groq','Groq FULL LOCAL','conectado','local-groq-key-1234567890'),
  ('gemini','Gemini FULL LOCAL','conectado','local-gemini-key-1234567890'),
  ('resend','Resend FULL LOCAL','conectado','local-resend-key-1234567890');
