-- ASCENDA CIA Phase 7 — immutable snapshots + activation core schema.
-- Additive only. No operational source tables are modified.

alter table public.aos_audiencia_versiones
  drop constraint if exists aos_audiencia_versiones_id_audiencia_uidx;

alter table public.aos_audiencia_versiones
  add constraint aos_audiencia_versiones_id_audiencia_uidx unique (id,audiencia_id);

create table if not exists public.aos_audiencia_snapshots (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null,
  estado text not null default 'BUILDING',
  member_count integer not null default 0,
  membership_hash text not null default '',
  filter_hash text not null,
  resolved_at timestamptz not null default now(),
  sealed_at timestamptz,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint aos_audiencia_snapshots_version_fk
    foreign key (audiencia_version_id,audiencia_id)
    references public.aos_audiencia_versiones(id,audiencia_id) on delete restrict,
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
  ),
  constraint aos_audiencia_snapshots_identity_uidx unique (id,audiencia_version_id,audiencia_id)
);

create index if not exists aos_audiencia_snapshots_audience_created_idx
  on public.aos_audiencia_snapshots(audiencia_id,created_at desc);
create index if not exists aos_audiencia_snapshots_version_created_idx
  on public.aos_audiencia_snapshots(audiencia_version_id,created_at desc);

create table if not exists public.aos_audiencia_snapshot_miembros (
  snapshot_id uuid not null references public.aos_audiencia_snapshots(id) on delete restrict,
  contact_key text not null,
  identity_status text,
  identity_conflict boolean not null default false,
  resolved_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key(snapshot_id,contact_key),
  constraint aos_audiencia_snapshot_miembros_key_len_chk check (char_length(contact_key) between 3 and 128),
  constraint aos_audiencia_snapshot_miembros_identity_status_len_chk check (identity_status is null or char_length(identity_status)<=80)
);

create index if not exists aos_audiencia_snapshot_miembros_contact_idx
  on public.aos_audiencia_snapshot_miembros(contact_key,snapshot_id);

create table if not exists public.aos_audiencia_activaciones (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null,
  snapshot_id uuid,
  nombre text not null,
  purpose text not null,
  channel text not null,
  mode text not null,
  estado text not null default 'DRAFT',
  baseline_count integer not null default 0,
  baseline_resolved_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  updated_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  constraint aos_audiencia_activaciones_version_fk
    foreign key (audiencia_version_id,audiencia_id)
    references public.aos_audiencia_versiones(id,audiencia_id) on delete restrict,
  constraint aos_audiencia_activaciones_snapshot_fk
    foreign key (snapshot_id,audiencia_version_id,audiencia_id)
    references public.aos_audiencia_snapshots(id,audiencia_version_id,audiencia_id) on delete restrict,
  constraint aos_audiencia_activaciones_nombre_chk check (char_length(btrim(nombre)) between 3 and 120),
  constraint aos_audiencia_activaciones_purpose_chk check (char_length(btrim(purpose)) between 2 and 120),
  constraint aos_audiencia_activaciones_channel_chk check (channel in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER')),
  constraint aos_audiencia_activaciones_mode_chk check (mode in ('BATCH','DYNAMIC')),
  constraint aos_audiencia_activaciones_estado_chk check (estado in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activaciones_baseline_count_chk check (baseline_count between 0 and 100000),
  constraint aos_audiencia_activaciones_metadata_type_chk check (jsonb_typeof(metadata)='object'),
  constraint aos_audiencia_activaciones_metadata_size_chk check (pg_column_size(metadata)<=32768),
  constraint aos_audiencia_activaciones_mode_snapshot_chk check (
    (mode='BATCH' and snapshot_id is not null) or
    (mode='DYNAMIC' and snapshot_id is null)
  ),
  constraint aos_audiencia_activaciones_timestamps_chk check (
    (estado='DRAFT' and started_at is null and ended_at is null) or
    (estado in ('ACTIVE','PAUSED') and started_at is not null and ended_at is null) or
    (estado='COMPLETED' and started_at is not null and ended_at is not null) or
    (estado='CANCELLED' and ended_at is not null)
  )
);

create index if not exists aos_audiencia_activaciones_estado_updated_idx
  on public.aos_audiencia_activaciones(estado,updated_at desc);
create index if not exists aos_audiencia_activaciones_audience_created_idx
  on public.aos_audiencia_activaciones(audiencia_id,created_at desc);

create table if not exists public.aos_audiencia_activacion_eventos (
  id bigint generated by default as identity primary key,
  activacion_id uuid not null references public.aos_audiencia_activaciones(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  from_state text,
  to_state text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint aos_audiencia_activacion_eventos_type_chk check (event_type in ('CREATE','START','PAUSE','RESUME','COMPLETE','CANCEL')),
  constraint aos_audiencia_activacion_eventos_from_chk check (from_state is null or from_state in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activacion_eventos_to_chk check (to_state in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activacion_eventos_metadata_type_chk check (jsonb_typeof(metadata)='object'),
  constraint aos_audiencia_activacion_eventos_metadata_size_chk check (pg_column_size(metadata)<=16384)
);

create index if not exists aos_audiencia_activacion_eventos_activation_created_idx
  on public.aos_audiencia_activacion_eventos(activacion_id,created_at,id);

alter table public.aos_audiencia_snapshots enable row level security;
alter table public.aos_audiencia_snapshot_miembros enable row level security;
alter table public.aos_audiencia_activaciones enable row level security;
alter table public.aos_audiencia_activacion_eventos enable row level security;
