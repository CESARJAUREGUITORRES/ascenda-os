-- ASCENDA OS CIA V3 — Phase 15 KronIA + Multiagent Orchestration
-- Canonical governed SHADOW plane. No operational source/write-path authority.

create table if not exists public.aos_cia_kronia_tool_registry (
  tool_key text not null,
  version integer not null default 1 check (version > 0),
  display_name text not null,
  description text not null,
  operation_class text not null check (operation_class in ('READ','PROPOSE')),
  risk_class text not null check (risk_class in ('LOW','MEDIUM','HIGH','CRITICAL')),
  request_type text,
  input_schema jsonb not null default '{}'::jsonb,
  output_schema jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (tool_key,version),
  check (upper(tool_key) not like '%RAW_SQL%'),
  check (request_type is null or upper(request_type) not in ('RAW_SQL','AUTO_APPROVE','AUTO_ASSIGN','TRANSFER_ASSIGNMENT'))
);

create table if not exists public.aos_cia_kronia_agent_registry (
  agent_key text not null,
  version integer not null default 1 check (version > 0),
  display_name text not null,
  purpose text not null,
  agent_class text not null,
  allowed_tools text[] not null default '{}'::text[],
  execution_mode text not null default 'SHADOW' check (execution_mode='SHADOW'),
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (agent_key,version)
);

create table if not exists public.aos_cia_kronia_agent_runs (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null default gen_random_uuid(),
  parent_run_id uuid references public.aos_cia_kronia_agent_runs(id),
  recommendation_id uuid references public.aos_cia_intelligence_recommendations(id),
  orchestrator_agent_key text not null,
  status text not null default 'STARTED' check (status in ('STARTED','COMPLETED','FAILED','BLOCKED')),
  input_context jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.aos_cia_kronia_tool_calls (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.aos_cia_kronia_agent_runs(id) on delete cascade,
  recommendation_id uuid references public.aos_cia_intelligence_recommendations(id),
  agent_key text not null,
  tool_key text not null,
  tool_version integer not null default 1,
  operation_class text not null check (operation_class in ('READ','PROPOSE')),
  request_type text,
  input_payload jsonb not null default '{}'::jsonb,
  output_payload jsonb not null default '{}'::jsonb,
  policy_decision jsonb not null default '{}'::jsonb,
  status text not null check (status in ('SUCCEEDED','BLOCKED','FAILED')),
  auto_execute boolean not null default false check (auto_execute=false),
  duration_ms numeric(12,3) not null default 0 check (duration_ms >= 0),
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.aos_cia_kronia_proposals (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.aos_cia_kronia_agent_runs(id) on delete cascade,
  recommendation_id uuid not null references public.aos_cia_intelligence_recommendations(id),
  agent_key text not null,
  tool_key text not null,
  request_type text not null,
  assignment_id uuid references public.aos_cia_assignments(id),
  advisor_user_id uuid references public.aos_usuarios(id),
  proposal_payload jsonb not null default '{}'::jsonb,
  policy_decision jsonb not null,
  state text not null check (state in ('REQUIRES_APPROVAL','BLOCKED')),
  auto_execute boolean not null default false check (auto_execute=false),
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists idx_cia_kronia_runs_created on public.aos_cia_kronia_agent_runs(created_at desc,id);
create index if not exists idx_cia_kronia_runs_rec on public.aos_cia_kronia_agent_runs(recommendation_id,created_at desc) where recommendation_id is not null;
create index if not exists idx_cia_kronia_calls_run on public.aos_cia_kronia_tool_calls(run_id,created_at,id);
create index if not exists idx_cia_kronia_calls_rec on public.aos_cia_kronia_tool_calls(recommendation_id,created_at) where recommendation_id is not null;
create index if not exists idx_cia_kronia_props_rec on public.aos_cia_kronia_proposals(recommendation_id,created_at desc);

create or replace function public.aos_cia_kronia_immutable_audit_guard_v1()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  raise exception 'F15 audit/proposal rows are append-only';
end $$;

drop trigger if exists trg_cia_kronia_tool_calls_immutable on public.aos_cia_kronia_tool_calls;
create trigger trg_cia_kronia_tool_calls_immutable before update or delete on public.aos_cia_kronia_tool_calls for each row execute function public.aos_cia_kronia_immutable_audit_guard_v1();
drop trigger if exists trg_cia_kronia_proposals_immutable on public.aos_cia_kronia_proposals;
create trigger trg_cia_kronia_proposals_immutable before update or delete on public.aos_cia_kronia_proposals for each row execute function public.aos_cia_kronia_immutable_audit_guard_v1();

alter table public.aos_cia_kronia_tool_registry enable row level security;
alter table public.aos_cia_kronia_agent_registry enable row level security;
alter table public.aos_cia_kronia_agent_runs enable row level security;
alter table public.aos_cia_kronia_tool_calls enable row level security;
alter table public.aos_cia_kronia_proposals enable row level security;
revoke all on table public.aos_cia_kronia_tool_registry from public,anon,authenticated;
revoke all on table public.aos_cia_kronia_agent_registry from public,anon,authenticated;
revoke all on table public.aos_cia_kronia_agent_runs from public,anon,authenticated;
revoke all on table public.aos_cia_kronia_tool_calls from public,anon,authenticated;
revoke all on table public.aos_cia_kronia_proposals from public,anon,authenticated;
revoke all on function public.aos_cia_kronia_immutable_audit_guard_v1() from public,anon,authenticated;

comment on table public.aos_cia_kronia_tool_registry is 'F15 canonical typed Tool Registry. No RAW_SQL/EXECUTE tool class.';
comment on table public.aos_cia_kronia_agent_registry is 'F15 governed agent capabilities; execution_mode is SHADOW only.';
comment on table public.aos_cia_kronia_agent_runs is 'F15 orchestration run provenance. No operational authority.';
comment on table public.aos_cia_kronia_tool_calls is 'F15 append-only tool-call audit with auto_execute permanently false.';
comment on table public.aos_cia_kronia_proposals is 'F15 immutable governed proposals. Approval/execution remain F13/human authority.';
