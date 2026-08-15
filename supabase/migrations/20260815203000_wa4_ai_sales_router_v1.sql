-- ASCENDA Conversations — WA-4 AI Sales Copilot & Multi-Model Router V1
-- Copilot-only. Automatic WhatsApp AI sending remains impossible in this phase.
begin;

create table if not exists public.aos_wa_ai_control_v1 (
  id smallint primary key default 1 check (id = 1),
  provider text not null default 'groq' check (provider = 'groq'),
  fast_model text not null default 'openai/gpt-oss-20b' check (fast_model = 'openai/gpt-oss-20b'),
  reasoning_model text not null default 'openai/gpt-oss-120b' check (reasoning_model = 'openai/gpt-oss-120b'),
  safety_model text not null default 'openai/gpt-oss-safeguard-20b' check (safety_model = 'openai/gpt-oss-safeguard-20b'),
  copilot_enabled boolean not null default false,
  auto_reply_enabled boolean not null default false check (auto_reply_enabled = false),
  daily_budget_usd numeric(10,4) not null default 0.5000 check (daily_budget_usd between 0.1000 and 25.0000),
  max_context_messages integer not null default 24 check (max_context_messages between 4 and 40),
  max_catalog_items integer not null default 12 check (max_catalog_items between 4 and 24),
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.aos_wa_ai_control_v1(id) values (1) on conflict (id) do nothing;
alter table public.aos_wa_ai_control_v1 enable row level security;
alter table public.aos_wa_ai_control_v1 force row level security;
revoke all on table public.aos_wa_ai_control_v1 from public, anon, authenticated;
grant select, update on table public.aos_wa_ai_control_v1 to service_role;

create table if not exists public.aos_wa_ai_runs_v1 (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict,
  actor_id uuid references public.aos_usuarios(id) on delete set null,
  task text not null check (task in ('SALES_COPILOT','MODEL_EVAL')),
  provider text not null check (provider in ('groq','deterministic')),
  model text,
  safety_model text,
  outcome text not null check (outcome in ('SUGGESTED','HUMAN_REQUIRED','BLOCKED','ERROR','EVAL_PASS','EVAL_FAIL')),
  input_messages integer not null default 0 check (input_messages >= 0),
  input_chars integer not null default 0 check (input_chars >= 0),
  output_chars integer not null default 0 check (output_chars >= 0),
  prompt_tokens integer not null default 0 check (prompt_tokens >= 0),
  completion_tokens integer not null default 0 check (completion_tokens >= 0),
  total_tokens integer not null default 0 check (total_tokens >= 0),
  estimated_cost_usd numeric(12,8) not null default 0 check (estimated_cost_usd >= 0),
  latency_ms integer not null default 0 check (latency_ms >= 0),
  safety_action text,
  safety_category text,
  error_code text,
  created_at timestamptz not null default now()
);
create index if not exists aos_wa_ai_runs_v1_conv_idx on public.aos_wa_ai_runs_v1(conversation_id,created_at desc);
create index if not exists aos_wa_ai_runs_v1_actor_idx on public.aos_wa_ai_runs_v1(actor_id,created_at desc);
create index if not exists aos_wa_ai_runs_v1_cost_idx on public.aos_wa_ai_runs_v1(created_at,estimated_cost_usd);
alter table public.aos_wa_ai_runs_v1 enable row level security;
alter table public.aos_wa_ai_runs_v1 force row level security;
revoke all on table public.aos_wa_ai_runs_v1 from public, anon, authenticated;
grant select, insert on table public.aos_wa_ai_runs_v1 to service_role;

create or replace function public.aos_wa4_ai_run_append_guard_v1()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  raise exception 'WA4_AI_RUN_APPEND_ONLY' using errcode='55000';
end
$$;
drop trigger if exists trg_aos_wa4_ai_run_append_guard_v1 on public.aos_wa_ai_runs_v1;
create trigger trg_aos_wa4_ai_run_append_guard_v1
before update or delete on public.aos_wa_ai_runs_v1
for each row execute function public.aos_wa4_ai_run_append_guard_v1();

create or replace function public.aos_wa4_authorize_copilot_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_actor jsonb;
  v_uid uuid;
  v_conv record;
  v_control public.aos_wa_ai_control_v1%rowtype;
  v_spend numeric;
  v_day_start timestamptz;
begin
  v_actor := public.aos_wa3_actor_v1(p_token);
  if coalesce((v_actor->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','WA4_2FA_PANEL_REQUIRED');
  end if;
  v_uid := (v_actor->>'actor_id')::uuid;

  select * into v_control from public.aos_wa_ai_control_v1 where id=1;
  if v_control.id is null or v_control.copilot_enabled is not true then
    return jsonb_build_object('ok',false,'error','WA4_COPILOT_DISABLED');
  end if;
  if v_control.auto_reply_enabled is true then
    return jsonb_build_object('ok',false,'error','WA4_AUTO_REPLY_FORBIDDEN');
  end if;

  select id,owner_user_id,state into v_conv
  from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA4_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from v_uid then return jsonb_build_object('ok',false,'error','WA4_NOT_OWNER'); end if;
  if v_conv.state not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA4_HUMAN_OWNERSHIP_REQUIRED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=v_uid and a.state='ACTIVE') then
    return jsonb_build_object('ok',false,'error','WA4_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;

  v_day_start := date_trunc('day', now() at time zone 'America/Lima') at time zone 'America/Lima';
  select coalesce(sum(estimated_cost_usd),0) into v_spend from public.aos_wa_ai_runs_v1 where created_at>=v_day_start;
  if v_spend >= v_control.daily_budget_usd then return jsonb_build_object('ok',false,'error','WA4_DAILY_BUDGET_REACHED','spent_usd',v_spend,'budget_usd',v_control.daily_budget_usd); end if;

  return jsonb_build_object(
    'ok',true,'actor_id',v_uid,'conversation_id',p_conversation_id,
    'fast_model',v_control.fast_model,'reasoning_model',v_control.reasoning_model,'safety_model',v_control.safety_model,
    'max_context_messages',v_control.max_context_messages,'max_catalog_items',v_control.max_catalog_items,
    'spent_usd',v_spend,'budget_usd',v_control.daily_budget_usd,'auto_reply_enabled',false
  );
end
$$;

create or replace function public.aos_wa4_admin_set_control_v1(
  p_actor_id uuid,
  p_copilot_enabled boolean default null,
  p_daily_budget_usd numeric default null
)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_row public.aos_wa_ai_control_v1%rowtype;
begin
  if not public.aos_wa3_is_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA4_ADMIN_REQUIRED'); end if;
  if p_daily_budget_usd is not null and (p_daily_budget_usd<0.1000 or p_daily_budget_usd>25.0000) then
    return jsonb_build_object('ok',false,'error','WA4_INVALID_BUDGET');
  end if;
  update public.aos_wa_ai_control_v1
  set copilot_enabled=coalesce(p_copilot_enabled,copilot_enabled),
      auto_reply_enabled=false,
      daily_budget_usd=coalesce(p_daily_budget_usd,daily_budget_usd),
      updated_by=p_actor_id,updated_at=now()
  where id=1 returning * into v_row;
  return jsonb_build_object('ok',true,'copilot_enabled',v_row.copilot_enabled,'auto_reply_enabled',false,'daily_budget_usd',v_row.daily_budget_usd,'fast_model',v_row.fast_model,'reasoning_model',v_row.reasoning_model,'safety_model',v_row.safety_model);
end
$$;

revoke all on function public.aos_wa4_ai_run_append_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_wa4_authorize_copilot_v1(text,uuid) from public;
revoke all on function public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric) from public,anon,authenticated;
grant execute on function public.aos_wa4_ai_run_append_guard_v1() to service_role;
grant execute on function public.aos_wa4_authorize_copilot_v1(text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric) to service_role;

comment on table public.aos_wa_ai_control_v1 is 'WA-4 Groq model/control registry. Copilot defaults OFF; automatic AI reply is structurally forbidden.';
comment on table public.aos_wa_ai_runs_v1 is 'WA-4 append-only metadata audit. Does not store raw prompt or raw model reply.';
comment on function public.aos_wa4_authorize_copilot_v1(text,uuid) is '2FA + panel + exact conversation ownership + active assignment + daily budget gate for AI copilot.';

commit;
