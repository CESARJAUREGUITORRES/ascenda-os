-- ASCENDA OS — Monthly reconciliation ledger
-- Purpose: persist month-by-month evidence, identity resolution, inferred visits and applied changes.
-- These tables are internal control-plane data. RLS is enabled and no client policies are created.

create table if not exists public.aos_recon_meses (
  id uuid primary key default gen_random_uuid(),
  anio integer not null,
  mes integer not null check (mes between 1 and 12),
  status text not null default 'AUDITING',
  source_label text,
  source_rows integer,
  source_total numeric(14,2),
  db_rows_before integer,
  db_total_before numeric(14,2),
  db_rows_after integer,
  db_total_after numeric(14,2),
  patient_visits integer,
  web_sales_excluded integer not null default 0,
  staff_sales_excluded integer not null default 0,
  notes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (anio, mes)
);

create table if not exists public.aos_recon_identidades (
  id bigserial primary key,
  recon_mes_id uuid not null references public.aos_recon_meses(id) on delete cascade,
  source_person_key text not null,
  source_name text,
  source_dni text,
  source_phone text,
  canonical_patient_id text,
  canonical_name text,
  resolution text not null default 'REVIEW',
  confidence text,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recon_mes_id, source_person_key)
);

create table if not exists public.aos_recon_visitas (
  id bigserial primary key,
  recon_mes_id uuid not null references public.aos_recon_meses(id) on delete cascade,
  fecha date not null,
  sede text not null,
  source_person_key text not null,
  canonical_patient_id text,
  patient_name text,
  sales_count integer not null default 0,
  sales_total numeric(14,2) not null default 0,
  sale_ids bigint[] not null default '{}'::bigint[],
  attendance_rule text,
  classification text not null,
  agenda_id text,
  state_before text,
  state_after text,
  proposed_action text,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recon_mes_id, fecha, sede, source_person_key)
);

create table if not exists public.aos_recon_cambios (
  id uuid primary key default gen_random_uuid(),
  recon_mes_id uuid not null references public.aos_recon_meses(id) on delete cascade,
  entity_type text not null,
  target_table text not null,
  target_pk text,
  operation text not null,
  status text not null default 'PLANNED',
  before_data jsonb,
  after_data jsonb,
  rollback_data jsonb,
  validation jsonb,
  applied_at timestamptz,
  applied_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_aos_recon_identidades_mes_patient
  on public.aos_recon_identidades(recon_mes_id, canonical_patient_id);
create index if not exists idx_aos_recon_visitas_mes_fecha
  on public.aos_recon_visitas(recon_mes_id, fecha, sede);
create index if not exists idx_aos_recon_visitas_patient
  on public.aos_recon_visitas(canonical_patient_id, fecha);
create index if not exists idx_aos_recon_cambios_mes_status
  on public.aos_recon_cambios(recon_mes_id, status);

alter table public.aos_recon_meses enable row level security;
alter table public.aos_recon_identidades enable row level security;
alter table public.aos_recon_visitas enable row level security;
alter table public.aos_recon_cambios enable row level security;

revoke all on table public.aos_recon_meses from anon, authenticated;
revoke all on table public.aos_recon_identidades from anon, authenticated;
revoke all on table public.aos_recon_visitas from anon, authenticated;
revoke all on table public.aos_recon_cambios from anon, authenticated;
revoke all on sequence public.aos_recon_identidades_id_seq from anon, authenticated;
revoke all on sequence public.aos_recon_visitas_id_seq from anon, authenticated;

comment on table public.aos_recon_meses is 'Control-plane ledger for certified month-by-month historical reconciliation.';
comment on table public.aos_recon_identidades is 'Identity resolution evidence per monthly reconciliation; not exposed to client roles.';
comment on table public.aos_recon_visitas is 'Visit reconstruction evidence derived from certified sales and Agenda cross-checks.';
comment on table public.aos_recon_cambios is 'Before/after/rollback evidence for reconciliation changes.';
