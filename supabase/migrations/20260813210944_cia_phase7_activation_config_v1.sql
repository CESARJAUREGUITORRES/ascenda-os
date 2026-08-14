-- REMOTE SYNC: already applied live as 20260813210944. Additive only.
create table if not exists public.aos_audiencia_activacion_config (
  activacion_id uuid primary key references public.aos_audiencia_activaciones(id) on delete restrict,
  snapshot_id uuid references public.aos_audiencia_snapshots(id) on delete restrict,
  nombre text not null,
  purpose text not null,
  channel text not null,
  mode text not null,
  baseline_count integer not null default 0,
  baseline_resolved_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now()
);