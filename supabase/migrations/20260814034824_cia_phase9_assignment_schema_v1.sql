create table if not exists public.aos_cia_assignment_plans (
  id uuid primary key default gen_random_uuid(), activation_id uuid not null references public.aos_audiencia_activaciones(id) on delete restrict,
  strategy text not null check (strategy in ('ONE','EQUAL','PERCENTAGE','FIXED')), ownership_scope text not null default 'GLOBAL' check (ownership_scope in ('ACTIVATION','GLOBAL')),
  source_limit integer null check (source_limit between 1 and 100000), lease_minutes integer not null default 480 check (lease_minutes between 30 and 10080),
  must_start_minutes integer not null default 120 check (must_start_minutes between 5 and 10080), topup_policy text not null default 'NONE' check (topup_policy in ('NONE','MAINTAIN_TARGET','CONTINUOUS')),
  topup_target_per_advisor integer null check (topup_target_per_advisor between 1 and 100000), allow_reassign_released boolean not null default true, allow_reassign_expired boolean not null default true,
  state text not null default 'DRAFT' check (state in ('DRAFT','ACTIVE','PAUSED','CLOSED','CANCELLED')), idempotency_key text not null unique check (length(idempotency_key) between 12 and 128),
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict, updated_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  activated_at timestamptz null, paused_at timestamptz null, closed_at timestamptz null, cancelled_at timestamptz null,
  check (must_start_minutes <= lease_minutes), check ((topup_policy='MAINTAIN_TARGET' and topup_target_per_advisor is not null) or (topup_policy<>'MAINTAIN_TARGET')),
  check ((topup_policy<>'MAINTAIN_TARGET') or strategy in ('ONE','EQUAL'))
);
create unique index if not exists ux_cia_assignment_one_open_plan_per_activation on public.aos_cia_assignment_plans(activation_id) where state in ('DRAFT','ACTIVE','PAUSED');
create index if not exists idx_cia_assignment_plans_state on public.aos_cia_assignment_plans(state,created_at desc);

create table if not exists public.aos_cia_assignment_targets (
  plan_id uuid not null references public.aos_cia_assignment_plans(id) on delete restrict, advisor_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  priority integer not null default 100 check (priority between 1 and 100000), weight_percent numeric(7,4) null check (weight_percent > 0 and weight_percent <= 100),
  fixed_quantity integer null check (fixed_quantity between 1 and 100000), capacity_limit integer null check (capacity_limit between 1 and 100000), created_at timestamptz not null default now(),
  primary key(plan_id,advisor_user_id)
);
create index if not exists idx_cia_assignment_targets_advisor on public.aos_cia_assignment_targets(advisor_user_id,plan_id);

create table if not exists public.aos_cia_assignment_runs (
  id uuid primary key default gen_random_uuid(), plan_id uuid not null references public.aos_cia_assignment_plans(id) on delete restrict, run_type text not null check (run_type in ('INITIAL','TOPUP')),
  idempotency_key text not null unique check (length(idempotency_key) between 12 and 160), source_available_count integer not null default 0 check (source_available_count >= 0),
  candidate_count integer not null default 0 check (candidate_count >= 0), requested_count integer null check (requested_count is null or requested_count >= 0), assigned_count integer not null default 0 check (assigned_count >= 0),
  result jsonb not null default '{}'::jsonb check (jsonb_typeof(result)='object'), created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict, created_at timestamptz not null default now()
);
create index if not exists idx_cia_assignment_runs_plan on public.aos_cia_assignment_runs(plan_id,created_at desc);

create table if not exists public.aos_cia_assignments (
  id uuid primary key default gen_random_uuid(), run_id uuid not null references public.aos_cia_assignment_runs(id) on delete restrict, plan_id uuid not null references public.aos_cia_assignment_plans(id) on delete restrict,
  activation_id uuid not null references public.aos_audiencia_activaciones(id) on delete restrict, contact_key text not null check (length(contact_key) between 1 and 128),
  advisor_user_id uuid not null references public.aos_usuarios(id) on delete restrict, state text not null default 'RESERVED' check (state in ('RESERVED','ASSIGNED','IN_PROGRESS','COMPLETED','RELEASED','EXPIRED')),
  source_rank integer not null check (source_rank >= 1), assigned_at timestamptz not null default now(), must_start_before timestamptz not null, expires_at timestamptz not null,
  started_at timestamptz null, completed_at timestamptz null, released_at timestamptz null, expired_at timestamptz null, terminal_reason text null,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict, updated_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check (must_start_before <= expires_at)
);
create unique index if not exists ux_cia_assignment_active_activation_contact on public.aos_cia_assignments(activation_id,contact_key) where state in ('RESERVED','ASSIGNED','IN_PROGRESS');
create index if not exists idx_cia_assignments_advisor_state on public.aos_cia_assignments(advisor_user_id,state,assigned_at);
create index if not exists idx_cia_assignments_plan_state on public.aos_cia_assignments(plan_id,state,assigned_at);
create index if not exists idx_cia_assignments_contact_state on public.aos_cia_assignments(contact_key,state);
create index if not exists idx_cia_assignments_deadlines on public.aos_cia_assignments(state,must_start_before,expires_at);

create table if not exists public.aos_cia_assignment_events (
  id bigserial primary key, plan_id uuid null references public.aos_cia_assignment_plans(id) on delete restrict, assignment_id uuid null references public.aos_cia_assignments(id) on delete restrict,
  event_type text not null, actor_user_id uuid null references public.aos_usuarios(id) on delete restrict, payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload)='object'), occurred_at timestamptz not null default now()
);
create index if not exists idx_cia_assignment_events_plan on public.aos_cia_assignment_events(plan_id,occurred_at desc,id desc);
create index if not exists idx_cia_assignment_events_assignment on public.aos_cia_assignment_events(assignment_id,occurred_at,id);

alter table public.aos_cia_assignment_plans enable row level security;
alter table public.aos_cia_assignment_targets enable row level security;
alter table public.aos_cia_assignment_runs enable row level security;
alter table public.aos_cia_assignments enable row level security;
alter table public.aos_cia_assignment_events enable row level security;
comment on table public.aos_cia_assignment_plans is 'ASCENDA CIA Phase 9 assignment plans; no Call Center routing side effects.';
comment on table public.aos_cia_assignments is 'ASCENDA CIA Phase 9 lease ownership derived only from Phase 8 available_keys.';
