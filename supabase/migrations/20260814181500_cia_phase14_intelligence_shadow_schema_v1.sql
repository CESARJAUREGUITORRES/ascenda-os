-- ASCENDA OS CIA V3 — Phase 14 Commercial Intelligence Shadow
-- Additive derived persistence only. No operational source/write-path objects are modified.

create table if not exists public.aos_cia_intelligence_shadow_runs (
  id uuid primary key default gen_random_uuid(),
  engine_version text not null default 'F14_V1',
  status text not null default 'RUNNING' check (status in ('RUNNING','COMPLETE','FAILED')),
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  source_counts jsonb not null default '{}'::jsonb,
  source_freshness jsonb not null default '{}'::jsonb,
  recommendation_count integer not null default 0 check (recommendation_count >= 0),
  created_by_user_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.aos_cia_intelligence_recommendations (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.aos_cia_intelligence_shadow_runs(id) on delete cascade,
  contact_key text not null,
  assignment_id uuid references public.aos_cia_assignments(id),
  advisor_user_id uuid references public.aos_usuarios(id),
  opportunity_type text not null check (opportunity_type in (
    'UNWORKED_LEAD','FOLLOWUP_RECOVERY','REACTIVATION','REPURCHASE_SIGNAL','HIGH_VALUE_ATTENTION'
  )),
  priority_score integer not null check (priority_score between 0 and 100),
  confidence text not null check (confidence in ('LOW','MEDIUM','HIGH')),
  sample_size integer not null check (sample_size >= 0),
  freshness_status text not null check (freshness_status in ('FRESH','AGING','STALE','UNKNOWN')),
  evidence jsonb not null,
  explanation jsonb not null,
  observed_affinity jsonb not null default '{}'::jsonb,
  proposed_action text,
  policy_decision jsonb not null default '{"decision":"SHADOW_ONLY","auto_execute":false}'::jsonb,
  state text not null default 'SHADOW' check (state='SHADOW'),
  created_at timestamptz not null default clock_timestamp(),
  unique(run_id,contact_key,opportunity_type)
);

create table if not exists public.aos_cia_intelligence_events (
  id bigint generated always as identity primary key,
  recommendation_id uuid not null references public.aos_cia_intelligence_recommendations(id) on delete cascade,
  request_id uuid references public.aos_cia_requests(id),
  event_type text not null check (event_type in ('GENERATED','POLICY_EVALUATED','REQUEST_LINKED','REQUEST_DECIDED')),
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default clock_timestamp()
);

create index if not exists idx_cia_intelligence_runs_status_completed
  on public.aos_cia_intelligence_shadow_runs(status,completed_at desc);
create index if not exists idx_cia_intelligence_recs_run_priority
  on public.aos_cia_intelligence_recommendations(run_id,priority_score desc,created_at desc);
create index if not exists idx_cia_intelligence_recs_advisor
  on public.aos_cia_intelligence_recommendations(advisor_user_id,run_id,priority_score desc)
  where advisor_user_id is not null;
create index if not exists idx_cia_intelligence_recs_assignment
  on public.aos_cia_intelligence_recommendations(assignment_id)
  where assignment_id is not null;
create index if not exists idx_cia_intelligence_events_rec
  on public.aos_cia_intelligence_events(recommendation_id,occurred_at,id);
create index if not exists idx_cia_intelligence_events_request
  on public.aos_cia_intelligence_events(request_id,occurred_at,id)
  where request_id is not null;

alter table public.aos_cia_intelligence_shadow_runs enable row level security;
alter table public.aos_cia_intelligence_recommendations enable row level security;
alter table public.aos_cia_intelligence_events enable row level security;

revoke all on table public.aos_cia_intelligence_shadow_runs from public,anon,authenticated;
revoke all on table public.aos_cia_intelligence_recommendations from public,anon,authenticated;
revoke all on table public.aos_cia_intelligence_events from public,anon,authenticated;

comment on table public.aos_cia_intelligence_shadow_runs is 'F14 derived SHADOW runs. No operational authority.';
comment on table public.aos_cia_intelligence_recommendations is 'F14 explainable commercial recommendations. state is always SHADOW; never ownership authority.';
comment on table public.aos_cia_intelligence_events is 'Append-oriented trace linking a recommendation to future governed request lifecycle.';
