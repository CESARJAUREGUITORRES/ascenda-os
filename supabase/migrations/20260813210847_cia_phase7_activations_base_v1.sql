-- REMOTE SYNC: already applied live as 20260813210847.
-- Additive identity table only. No DROP/ALTER/destructive operation.
create table if not exists public.aos_audiencia_activaciones (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null references public.aos_audiencia_versiones(id) on delete restrict,
  created_at timestamptz not null default now()
);