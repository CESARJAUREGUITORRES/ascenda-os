\set ON_ERROR_STOP on

-- REV-F6.6 synthetic-only compatibility additions.
-- No real PII/PHI; only deterministic test identifiers.

alter table public.aos_f5_source_batches_v1
  add column if not exists metadata jsonb not null default '{"staging_complete":true}'::jsonb;
update public.aos_f5_source_batches_v1
set metadata = coalesce(metadata,'{}'::jsonb) || '{"staging_complete":true}'::jsonb;

create table if not exists public.aos_f5_enrichment_preview_v1(
  cluster_id uuid not null,
  target_patient_id text not null,
  field_name text not null,
  proposed_value text,
  source_evidence_rows integer,
  source_distinct_values integer,
  source_row_ids bigint[],
  policy_state text,
  policy_risk_class text,
  policy_apply_allowed boolean,
  apply_eligible boolean,
  requires_human boolean,
  canonical_empty boolean,
  generated_at timestamptz default now(),
  review_decision text,
  review_reason text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  reviewed_snapshot_hash text,
  applied_at timestamptz,
  apply_event_id uuid,
  primary key(cluster_id,target_patient_id,field_name)
);

create table if not exists public.aos_f5_canonical_apply_events_v1(
  id uuid primary key default gen_random_uuid(),
  cluster_id uuid not null,
  target_patient_id text not null,
  actor_user_id uuid,
  before_patch jsonb default '{}'::jsonb,
  applied_patch jsonb default '{}'::jsonb,
  after_patch jsonb default '{}'::jsonb,
  preview_snapshot_hash text,
  applied_at timestamptz default now(),
  rolled_back_at timestamptz,
  rolled_back_by uuid,
  rollback_reason text,
  created_at timestamptz default now(),
  field_name text,
  canonical_before_hash text,
  canonical_after_hash text,
  rollback_after_hash text,
  apply_scope text
);

create table if not exists public.aos_product_identity_v1(
  product_key text primary key,
  canonical_name text not null
);
insert into public.aos_product_identity_v1(product_key,canonical_name)
select distinct product_key,coalesce(canonical_name,product_key)
from public.aos_product_sale_fact_base
where product_key is not null
on conflict(product_key) do nothing;

create table if not exists public.aos_pagos(
  id text primary key,
  cotizacion_id text,
  created_at timestamptz default now()
);
create table if not exists public.aos_cotizaciones(
  id text primary key,
  estado text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Create one fully governed synthetic apply to exercise the active-chain check.
do $$
declare
  v_event uuid:='66666666-6666-4666-8666-666666666601'::uuid;
  v_cluster uuid:='11111111-1111-1111-1111-111111111111'::uuid;
  v_actor uuid:='00000000-0000-0000-0000-000000000612'::uuid;
  v_hash text:='f66-synthetic-reviewed-snapshot';
begin
  insert into public.aos_f5_canonical_apply_events_v1(
    id,cluster_id,target_patient_id,actor_user_id,preview_snapshot_hash,field_name,apply_scope
  ) values(v_event,v_cluster,'P1',v_actor,v_hash,'Sexo','FIELD')
  on conflict(id) do nothing;

  insert into public.aos_f5_enrichment_preview_v1(
    cluster_id,target_patient_id,field_name,proposed_value,review_decision,reviewed_by,
    reviewed_at,reviewed_snapshot_hash,applied_at,apply_event_id
  ) values(
    v_cluster,'P1','Sexo','F','APPROVE_FIELD',v_actor,now(),v_hash,now(),v_event
  )
  on conflict(cluster_id,target_patient_id,field_name) do update
  set review_decision=excluded.review_decision,reviewed_by=excluded.reviewed_by,
      reviewed_at=excluded.reviewed_at,reviewed_snapshot_hash=excluded.reviewed_snapshot_hash,
      applied_at=excluded.applied_at,apply_event_id=excluded.apply_event_id;
end $$;
