-- REMOTE SYNC: already applied live as 20260813210956. Additive state table only.
create table if not exists public.aos_audiencia_activacion_estado (
  activacion_id uuid primary key references public.aos_audiencia_activaciones(id) on delete restrict,
  estado text not null default 'DRAFT',
  updated_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  constraint aos_audiencia_activacion_estado_state_chk check (estado in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activacion_estado_timestamps_chk check (
    (estado='DRAFT' and started_at is null and ended_at is null) or
    (estado in ('ACTIVE','PAUSED') and started_at is not null and ended_at is null) or
    (estado='COMPLETED' and started_at is not null and ended_at is not null) or
    (estado='CANCELLED' and ended_at is not null)
  )
);