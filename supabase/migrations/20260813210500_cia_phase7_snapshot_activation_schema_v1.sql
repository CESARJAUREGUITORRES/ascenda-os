-- ASCENDA CIA Phase 7 — snapshot header table.
-- Applied live as schema_migrations version 20260813210630.

create table if not exists public.aos_audiencia_snapshots (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null references public.aos_audiencia_versiones(id) on delete restrict,
  estado text not null default 'BUILDING',
  member_count integer not null default 0,
  membership_hash text not null default '',
  filter_hash text not null,
  resolved_at timestamptz not null default now(),
  sealed_at timestamptz,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint aos_audiencia_snapshots_estado_chk check (estado in ('BUILDING','READY')),
  constraint aos_audiencia_snapshots_count_chk check (member_count between 0 and 100000),
  constraint aos_audiencia_snapshots_membership_hash_chk check (
    (estado='BUILDING' and membership_hash='') or
    (estado='READY' and membership_hash ~ '^[0-9a-f]{64}$')
  ),
  constraint aos_audiencia_snapshots_filter_hash_chk check (filter_hash ~ '^[0-9a-f]{64}$'),
  constraint aos_audiencia_snapshots_seal_chk check (
    (estado='BUILDING' and sealed_at is null) or
    (estado='READY' and sealed_at is not null)
  )
);