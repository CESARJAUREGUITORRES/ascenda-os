create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.aos_usuarios(
  id uuid primary key,
  rol text,
  activo boolean default true,
  paneles_acceso text[] default '{}'::text[],
  nivel_jerarquia integer default 3
);
create table if not exists public.aos_app_sessions_v3(
  token_hash text primary key,
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  assurance_level text not null,
  expires_at timestamptz not null,
  revoked boolean not null default false
);
