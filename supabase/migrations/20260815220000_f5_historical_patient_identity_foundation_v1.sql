-- ASCENDA OS — F5 Historical Client & Sales + Patient Identity foundation v1
-- CRITICAL/PII boundary: additive private staging only. No mutation of aos_pacientes.

create extension if not exists pgcrypto;

create table if not exists public.aos_f5_source_batches_v1 (
  id uuid primary key default gen_random_uuid(),
  source_sha256 text not null unique,
  source_filename text not null,
  source_sede text not null check (source_sede in ('SAN ISIDRO','PUEBLO LIBRE')),
  source_year integer not null check (source_year between 2000 and 2100),
  source_rows integer not null check (source_rows >= 0),
  source_columns integer not null check (source_columns >= 0),
  schema_hash text not null,
  status text not null default 'STAGED' check (status in ('STAGED','PROFILED','CLUSTERED','MATCHED','APPROVED','APPLIED','FAILED')),
  metadata jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_f5_patient_source_rows_v1 (
  id bigserial primary key,
  batch_id uuid not null references public.aos_f5_source_batches_v1(id) on delete restrict,
  source_row_num integer not null check (source_row_num >= 2),
  source_patient_id text not null,
  source_created_date date,
  phone_raw text,
  phone_key text,
  phone_type text,
  names_raw text,
  surnames_raw text,
  name_key text,
  email_raw text,
  email_key text,
  document_raw text,
  document_key text,
  document_type text,
  sex_raw text,
  birth_date_raw text,
  birth_date date,
  birth_quality text,
  address_raw text,
  address_street text,
  district text,
  province text,
  department text,
  address_parse_status text,
  occupation text,
  guardian text,
  acquisition_channel text,
  acquisition_reference text,
  clinical_note text,
  allergies text,
  business_line text,
  hc_raw text,
  inactive_raw text,
  tags_raw text,
  last_appointment date,
  next_appointment date,
  task_raw text,
  last_budget_raw text,
  budget_num_a numeric,
  budget_num_b numeric,
  row_content_hash text not null,
  identity_seed_hash text,
  raw_payload jsonb not null,
  ingested_at timestamptz not null default now(),
  unique(batch_id, source_row_num)
);

create index if not exists aos_f5_source_rows_phone_idx on public.aos_f5_patient_source_rows_v1(phone_key) where phone_key is not null;
create index if not exists aos_f5_source_rows_document_idx on public.aos_f5_patient_source_rows_v1(document_key) where document_key is not null;
create index if not exists aos_f5_source_rows_email_idx on public.aos_f5_patient_source_rows_v1(email_key) where email_key is not null;
create index if not exists aos_f5_source_rows_name_idx on public.aos_f5_patient_source_rows_v1(name_key) where name_key is not null;
create index if not exists aos_f5_source_rows_created_idx on public.aos_f5_patient_source_rows_v1(source_created_date);
create index if not exists aos_f5_source_rows_last_appt_idx on public.aos_f5_patient_source_rows_v1(last_appointment);
create index if not exists aos_f5_source_rows_identity_seed_idx on public.aos_f5_patient_source_rows_v1(identity_seed_hash) where identity_seed_hash is not null;

create table if not exists public.aos_f5_identity_clusters_v1 (
  id uuid primary key default gen_random_uuid(),
  cluster_key text not null unique,
  status text not null default 'PROPOSED' check (status in ('PROPOSED','REVIEW_REQUIRED','READY_TO_LINK','NEW_CANDIDATE','LINKED','REJECTED')),
  confidence text not null check (confidence in ('HIGH','MEDIUM','LOW','REVIEW','SINGLETON')),
  source_row_count integer not null check (source_row_count > 0),
  canonical_preview jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  conflicts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_f5_identity_cluster_members_v1 (
  cluster_id uuid not null references public.aos_f5_identity_clusters_v1(id) on delete restrict,
  source_row_id bigint not null references public.aos_f5_patient_source_rows_v1(id) on delete restrict,
  match_rule text not null,
  match_score numeric,
  created_at timestamptz not null default now(),
  primary key(cluster_id, source_row_id),
  unique(source_row_id)
);

create index if not exists aos_f5_cluster_members_source_idx on public.aos_f5_identity_cluster_members_v1(source_row_id);

create table if not exists public.aos_f5_patient_link_preview_v1 (
  cluster_id uuid primary key references public.aos_f5_identity_clusters_v1(id) on delete restrict,
  target_patient_id text,
  match_status text not null check (match_status in ('UNMATCHED','AUTO_CANDIDATE','REVIEW_REQUIRED','APPROVED','REJECTED','APPLIED')),
  match_method text,
  match_score numeric,
  evidence jsonb not null default '{}'::jsonb,
  conflicts jsonb not null default '{}'::jsonb,
  current_snapshot jsonb not null default '{}'::jsonb,
  proposed_patch jsonb not null default '{}'::jsonb,
  requires_human boolean not null default true,
  reviewed_by uuid,
  reviewed_at timestamptz,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_f5_link_preview_patient_idx on public.aos_f5_patient_link_preview_v1(target_patient_id) where target_patient_id is not null;
create index if not exists aos_f5_link_preview_status_idx on public.aos_f5_patient_link_preview_v1(match_status);

create table if not exists public.aos_f5_audit_v1 (
  id bigserial primary key,
  action text not null,
  entity_type text not null,
  entity_key text,
  actor_user_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Private-by-default PII/PHI boundary. No browser role gets table access.
alter table public.aos_f5_source_batches_v1 enable row level security;
alter table public.aos_f5_patient_source_rows_v1 enable row level security;
alter table public.aos_f5_identity_clusters_v1 enable row level security;
alter table public.aos_f5_identity_cluster_members_v1 enable row level security;
alter table public.aos_f5_patient_link_preview_v1 enable row level security;
alter table public.aos_f5_audit_v1 enable row level security;

revoke all on table public.aos_f5_source_batches_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_patient_source_rows_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_identity_clusters_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_identity_cluster_members_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_patient_link_preview_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_audit_v1 from public, anon, authenticated;

revoke all on sequence public.aos_f5_patient_source_rows_v1_id_seq from public, anon, authenticated;
revoke all on sequence public.aos_f5_audit_v1_id_seq from public, anon, authenticated;

comment on table public.aos_f5_source_batches_v1 is 'F5 immutable source manifest. File hashes make historical intake idempotent.';
comment on table public.aos_f5_patient_source_rows_v1 is 'F5 private patient source evidence: raw payload plus normalized keys; never canonical by itself.';
comment on table public.aos_f5_identity_clusters_v1 is 'F5 proposed source identity clusters. Human review remains mandatory for ambiguous evidence.';
comment on table public.aos_f5_patient_link_preview_v1 is 'F5 preview of source cluster to canonical aos_pacientes link/enrichment. No auto-apply in v1.';

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_IDENTITY_FOUNDATION_SCHEMA',jsonb_build_object('version','v1','mode','PRIVATE_ADDITIVE','at',now()));
