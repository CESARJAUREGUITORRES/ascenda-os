begin;

create table if not exists public.aos_wa4_campaign_context_map_v1 (
  ad_id text primary key,
  campaign_id text,
  treatment_entity_id uuid references public.aos_catalogo_servicios(id) on delete restrict,
  treatment_code text,
  promotion_id uuid references public.aos_promociones(id) on delete set null,
  booking_goal text,
  media_strategy jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  evidence_ref text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint aos_wa4_campaign_context_map_v1_treatment_ck
    check (treatment_entity_id is not null or nullif(btrim(treatment_code),'') is not null),
  constraint aos_wa4_campaign_context_map_v1_evidence_ck
    check (nullif(btrim(evidence_ref),'') is not null)
);

comment on table public.aos_wa4_campaign_context_map_v1 is
  'WA-4C governed campaign provenance mapping. Empty/fail-closed by default. No treatment may be inferred from ad/campaign names.';

alter table public.aos_wa4_campaign_context_map_v1 enable row level security;
revoke all on table public.aos_wa4_campaign_context_map_v1 from anon, authenticated;
grant select on table public.aos_wa4_campaign_context_map_v1 to service_role;

create index if not exists aos_wa4_campaign_context_map_v1_active_idx
  on public.aos_wa4_campaign_context_map_v1(active, campaign_id);

commit;
