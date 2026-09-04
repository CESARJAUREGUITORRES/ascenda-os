-- WA-L10 C — durable event-driven autonomous bridge for a tiny governed CANARY.
-- L4 remains the sole send/activation authority; L8 remains mandatory preflight.
-- This layer only durably queues eligible inbound provider message ids, leases work,
-- records redacted run-scoped evidence and provides an explicit human->AI_CANARY return.
-- No raw message body, raw webhook, token or additional provider sender is stored here.

begin;

create table if not exists public.aos_wa_l10_bridge_jobs_v1 (
  provider_message_id text primary key check (char_length(provider_message_id) between 8 and 256),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  run_id uuid not null references public.aos_wa_l10_canary_runs_v1(id) on delete restrict,
  queued_at timestamptz not null default now()
);
create index if not exists aos_wa_l10_bridge_jobs_run_idx
  on public.aos_wa_l10_bridge_jobs_v1(run_id,queued_at,conversation_id);

create table if not exists public.aos_wa_l10_bridge_attempts_v1 (
  id uuid primary key default gen_random_uuid(),
  provider_message_id text not null references public.aos_wa_l10_bridge_jobs_v1(provider_message_id) on delete restrict,
  attempt_no smallint not null check (attempt_no between 1 and 2),
  claimed_at timestamptz not null default now(),
  unique(provider_message_id,attempt_no)
);
create index if not exists aos_wa_l10_bridge_attempts_claim_idx
  on public.aos_wa_l10_bridge_attempts_v1(provider_message_id,claimed_at desc);

create table if not exists public.aos_wa_l10_bridge_events_v1 (
  id bigint generated always as identity primary key,
  provider_message_id text not null references public.aos_wa_l10_bridge_jobs_v1(provider_message_id) on delete restrict,
  attempt_id uuid references public.aos_wa_l10_bridge_attempts_v1(id) on delete restrict,
  event_type text not null check (event_type in ('SUGGESTED','SENT','HANDOFF','BLOCKED','ERROR','SKIPPED')),
  reason_code text not null check (char_length(reason_code) between 2 and 128),
  authority_decision_id uuid references public.aos_wa_auto_decisions_v1(id) on delete restrict,
  outbound_provider_message_id text check (outbound_provider_message_id is null or char_length(outbound_provider_message_id) between 8 and 256),
  latency_ms integer check (latency_ms is null or latency_ms between 0 and 120000),
  created_at timestamptz not null default now(),
  unique(provider_message_id,attempt_id,event_type)
);
create index if not exists aos_wa_l10_bridge_events_job_idx
  on public.aos_wa_l10_bridge_events_v1(provider_message_id,created_at,event_type);

alter table public.aos_wa_l10_bridge_jobs_v1 enable row level security;
alter table public.aos_wa_l10_bridge_jobs_v1 force row level security;
alter table public.aos_wa_l10_bridge_attempts_v1 enable row level security;
alter table public.aos_wa_l10_bridge_attempts_v1 force row level security;
alter table public.aos_wa_l10_bridge_events_v1 enable row level security;
alter table public.aos_wa_l10_bridge_events_v1 force row level security;

revoke all on public.aos_wa_l10_bridge_jobs_v1 from public,anon,authenticated,service_role;
revoke all on public.aos_wa_l10_bridge_attempts_v1 from public,anon,authenticated,service_role;
revoke all on public.aos_wa_l10_bridge_events_v1 from public,anon,authenticated,service_role;
grant select on public.aos_wa_l10_bridge_jobs_v1 to service_role;
grant select on public.aos_wa_l10_bridge_attempts_v1 to service_role;
grant select on public.aos_wa_l10_bridge_events_v1 to service_role;

create or replace function public.aos_wa_l10_bridge_append_guard_v1()
returns trigger language plpgsql set search_path='' as $$
begin
  raise exception 'WA_L10_BRIDGE_APPEND_ONLY' using errcode='55000';
end
$$;

drop trigger if exists trg_aos_wa_l10_bridge_jobs_append_guard_v1 on public.aos_wa_l10_bridge_jobs_v1;
create trigger trg_aos_wa_l10_bridge_jobs_append_guard_v1
before update or delete on public.aos_wa_l10_bridge_jobs_v1
for each row execute function public.aos_wa_l10_bridge_append_guard_v1();

drop trigger if exists trg_aos_wa_l10_bridge_attempts_append_guard_v1 on public.aos_wa_l10_bridge_attempts_v1;
create trigger trg_aos_wa_l10_bridge_attempts_append_guard_v1
before update or delete on public.aos_wa_l10_bridge_attempts_v1
for each row execute function public.aos_wa_l10_bridge_append_guard_v1();

drop trigger if exists trg_aos_wa_l10_bridge_events_append_guard_v1 on public.aos_wa_l10_bridge_events_v1;
create trigger trg_aos_wa_l10_bridge_events_append_guard_v1
before update or delete on public.aos_wa_l10_bridge_events_v1
for each row execute function public.aos_wa_l10_bridge_append_guard_v1();

create or replace function public.aos_wa_l10_bridge_enqueue_v1(p_provider_message_id text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_msg record;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_scope public.aos_wa_l10_canary_scope_v1%rowtype;
  v_run public.aos_wa_l10_canary_runs_v1%rowtype;
  v_mode text; v_kill boolean; v_auto_reply boolean; v_ai_send boolean; v_auto_routing boolean; v_human_send boolean;
  v_hash text;
  v_inserted text;
begin
  select m.provider_message_id,m.conversation_id,m.direction,m.message_type,m.created_at
    into v_msg
  from public.aos_wa_messages_v1 m
  where m.provider_message_id=p_provider_message_id
  limit 1;
  if v_msg.provider_message_id is null then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_MESSAGE_NOT_FOUND');
  end if;
  if v_msg.direction<>'INBOUND' or lower(coalesce(v_msg.message_type,''))<>'text' then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_MESSAGE_NOT_AUTONOMOUS_TEXT');
  end if;
  if v_msg.created_at<now()-interval '10 minutes' then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_MESSAGE_STALE');
  end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=v_msg.conversation_id;
  if v_conv.id is null then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_CONVERSATION_NOT_FOUND');
  end if;

  select s.* into v_scope
  from public.aos_wa_l10_canary_scope_v1 s
  where s.conversation_id=v_conv.id
  order by s.created_at desc
  limit 1;
  if v_scope.id is null then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_SCOPE_REQUIRED');
  end if;
  select * into v_run from public.aos_wa_l10_canary_runs_v1 where id=v_scope.run_id;
  if v_run.id is null then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_RUN_REQUIRED');
  end if;

  v_hash:=encode(extensions.digest(convert_to(v_conv.contact_address_type||':'||v_conv.contact_address,'UTF8'),'sha256'),'hex');
  if v_scope.recipient_hash<>v_hash then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_SCOPE_RECIPIENT_MISMATCH');
  end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
    into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;

  if v_mode is distinct from 'CANARY' or v_kill is distinct from false
     or v_auto_reply is distinct from true or v_ai_send is distinct from true
     or v_auto_routing is distinct from false or v_human_send is distinct from true then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_CANARY_NOT_EFFECTIVE');
  end if;
  if v_conv.state<>'AI_ACTIVE' or v_conv.owner_user_id is not null
     or v_conv.human_takeover_at is not null or v_conv.handoff_requested_at is not null then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_HUMAN_BOUNDARY_ACTIVE');
  end if;
  if not exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.subject_kind='CONVERSATION' and a.subject_key=v_conv.id::text
      and a.active is true and (a.expires_at is null or a.expires_at>now())
  ) then
    return jsonb_build_object('ok',true,'queued',false,'reason','WA_L10_EXACT_CONVERSATION_ALLOWLIST_REQUIRED');
  end if;

  insert into public.aos_wa_l10_bridge_jobs_v1(provider_message_id,conversation_id,run_id)
  values(v_msg.provider_message_id,v_conv.id,v_run.id)
  on conflict(provider_message_id) do nothing
  returning provider_message_id into v_inserted;

  return jsonb_build_object(
    'ok',true,'queued',true,'replay',v_inserted is null,
    'provider_message_id',v_msg.provider_message_id,'conversation_id',v_conv.id,'run_key',v_run.run_key
  );
end
$$;

create or replace function public.aos_wa_l10_bridge_claim_v1(p_provider_message_id text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_job public.aos_wa_l10_bridge_jobs_v1%rowtype;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_run public.aos_wa_l10_canary_runs_v1%rowtype;
  v_attempts integer:=0;
  v_latest timestamptz;
  v_attempt public.aos_wa_l10_bridge_attempts_v1%rowtype;
  v_mode text; v_kill boolean; v_auto_reply boolean; v_ai_send boolean; v_auto_routing boolean; v_human_send boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(744,10);
  select * into v_job from public.aos_wa_l10_bridge_jobs_v1 where provider_message_id=p_provider_message_id;
  if v_job.provider_message_id is null then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_JOB_NOT_FOUND');
  end if;
  if exists(
    select 1 from public.aos_wa_l10_bridge_events_v1 e
    where e.provider_message_id=p_provider_message_id and e.event_type in ('SENT','HANDOFF','BLOCKED','ERROR','SKIPPED')
  ) then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_JOB_TERMINAL');
  end if;
  if v_job.queued_at<now()-interval '10 minutes' then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_JOB_STALE');
  end if;

  select count(*)::integer,max(claimed_at) into v_attempts,v_latest
  from public.aos_wa_l10_bridge_attempts_v1 where provider_message_id=p_provider_message_id;
  if v_attempts>=2 then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_MAX_ATTEMPTS');
  end if;
  if v_latest is not null and v_latest>now()-interval '90 seconds' then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_JOB_BUSY');
  end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=v_job.conversation_id;
  select * into v_run from public.aos_wa_l10_canary_runs_v1 where id=v_job.run_id;
  if v_conv.id is null or v_run.id is null then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_JOB_CONTEXT_MISSING');
  end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
    into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;
  if v_mode is distinct from 'CANARY' or v_kill is distinct from false
     or v_auto_reply is distinct from true or v_ai_send is distinct from true
     or v_auto_routing is distinct from false or v_human_send is distinct from true then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_CANARY_NOT_EFFECTIVE');
  end if;
  if v_conv.state<>'AI_ACTIVE' or v_conv.owner_user_id is not null
     or v_conv.human_takeover_at is not null or v_conv.handoff_requested_at is not null then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_HUMAN_BOUNDARY_ACTIVE');
  end if;
  if not exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.subject_kind='CONVERSATION' and a.subject_key=v_conv.id::text
      and a.active is true and (a.expires_at is null or a.expires_at>now())
  ) then
    return jsonb_build_object('ok',true,'claimed',false,'reason','WA_L10_EXACT_CONVERSATION_ALLOWLIST_REQUIRED');
  end if;

  insert into public.aos_wa_l10_bridge_attempts_v1(provider_message_id,attempt_no)
  values(p_provider_message_id,(v_attempts+1)::smallint)
  returning * into v_attempt;

  return jsonb_build_object(
    'ok',true,'claimed',true,'attempt_id',v_attempt.id,'attempt_no',v_attempt.attempt_no,
    'conversation_id',v_conv.id,'run_key',v_run.run_key,
    'recipient_kind',v_conv.contact_address_type,'recipient_address',v_conv.contact_address,
    'campaign_key',nullif(v_conv.campaign_source,'')
  );
end
$$;

create or replace function public.aos_wa_l10_bridge_event_v1(
  p_provider_message_id text,
  p_attempt_id uuid,
  p_event_type text,
  p_reason_code text,
  p_authority_decision_id uuid default null,
  p_outbound_provider_message_id text default null,
  p_latency_ms integer default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_type text:=upper(btrim(coalesce(p_event_type,'')));
  v_reason text:=left(regexp_replace(upper(btrim(coalesce(p_reason_code,'WA_L10_UNKNOWN'))),'[^A-Z0-9_.:-]','_','g'),128);
  v_id bigint;
begin
  if v_type not in ('SUGGESTED','SENT','HANDOFF','BLOCKED','ERROR','SKIPPED') then
    return jsonb_build_object('ok',false,'error','WA_L10_EVENT_TYPE_INVALID');
  end if;
  if not exists(
    select 1 from public.aos_wa_l10_bridge_attempts_v1 a
    where a.id=p_attempt_id and a.provider_message_id=p_provider_message_id
  ) then
    return jsonb_build_object('ok',false,'error','WA_L10_ATTEMPT_REQUIRED');
  end if;
  if p_latency_ms is not null and p_latency_ms not between 0 and 120000 then
    return jsonb_build_object('ok',false,'error','WA_L10_LATENCY_INVALID');
  end if;

  insert into public.aos_wa_l10_bridge_events_v1(
    provider_message_id,attempt_id,event_type,reason_code,authority_decision_id,outbound_provider_message_id,latency_ms
  ) values (
    p_provider_message_id,p_attempt_id,v_type,v_reason,p_authority_decision_id,
    nullif(btrim(coalesce(p_outbound_provider_message_id,'')),''),p_latency_ms
  )
  on conflict(provider_message_id,attempt_id,event_type) do nothing
  returning id into v_id;

  return jsonb_build_object('ok',true,'inserted',v_id is not null,'event_type',v_type);
end
$$;

create or replace function public.aos_wa_l10_bridge_pending_v1(p_limit integer default 5)
returns table(provider_message_id text)
language sql
stable
security definer
set search_path=''
as $$
  select j.provider_message_id
  from public.aos_wa_l10_bridge_jobs_v1 j
  where j.queued_at>=now()-interval '10 minutes'
    and not exists(
      select 1 from public.aos_wa_l10_bridge_events_v1 e
      where e.provider_message_id=j.provider_message_id
        and e.event_type in ('SENT','HANDOFF','BLOCKED','ERROR','SKIPPED')
    )
    and (select count(*) from public.aos_wa_l10_bridge_attempts_v1 a where a.provider_message_id=j.provider_message_id)<2
    and not exists(
      select 1 from public.aos_wa_l10_bridge_attempts_v1 a
      where a.provider_message_id=j.provider_message_id and a.claimed_at>now()-interval '90 seconds'
    )
  order by j.queued_at asc
  limit greatest(1,least(coalesce(p_limit,5),10))
$$;

create or replace function public.aos_wa_l10_return_to_autonomous_canary_v1(
  p_actor_id uuid,
  p_run_key text,
  p_conversation_id uuid,
  p_reason text default 'OWNER_AUTH_CANARY'
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_run public.aos_wa_l10_canary_runs_v1%rowtype;
  v_scope public.aos_wa_l10_canary_scope_v1%rowtype;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_mode text; v_kill boolean; v_auto_reply boolean; v_ai_send boolean; v_auto_routing boolean; v_human_send boolean;
  v_hash text;
  v_released integer:=0;
  v_reason text:=left(regexp_replace(upper(btrim(coalesce(p_reason,'OWNER_AUTH_CANARY'))),'[^A-Z0-9_.:-]','_','g'),128);
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then
    return jsonb_build_object('ok',false,'error','WA_L10_LEVEL1_ADMIN_REQUIRED');
  end if;
  select * into v_run from public.aos_wa_l10_canary_runs_v1 where run_key=p_run_key;
  if v_run.id is null then return jsonb_build_object('ok',false,'error','WA_L10_RUN_NOT_FOUND'); end if;
  select * into v_scope from public.aos_wa_l10_canary_scope_v1
    where run_id=v_run.id and conversation_id=p_conversation_id;
  if v_scope.id is null then return jsonb_build_object('ok',false,'error','WA_L10_SCOPE_REQUIRED'); end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA_L10_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.state in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA_L10_CONVERSATION_TERMINAL'); end if;

  v_hash:=encode(extensions.digest(convert_to(v_conv.contact_address_type||':'||v_conv.contact_address,'UTF8'),'sha256'),'hex');
  if v_scope.recipient_hash<>v_hash then return jsonb_build_object('ok',false,'error','WA_L10_SCOPE_RECIPIENT_MISMATCH'); end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
    into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;
  if v_mode is distinct from 'CANARY' or v_kill is distinct from false
     or v_auto_reply is distinct from true or v_ai_send is distinct from true
     or v_auto_routing is distinct from false or v_human_send is distinct from true then
    return jsonb_build_object('ok',false,'error','WA_L10_EFFECTIVE_CANARY_REQUIRED');
  end if;
  if not exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.subject_kind='CONVERSATION' and a.subject_key=p_conversation_id::text
      and a.active is true and (a.expires_at is null or a.expires_at>now())
  ) then
    return jsonb_build_object('ok',false,'error','WA_L10_EXACT_CONVERSATION_ALLOWLIST_REQUIRED');
  end if;

  if v_conv.state='AI_ACTIVE' and v_conv.owner_user_id is null
     and v_conv.human_takeover_at is null and v_conv.handoff_requested_at is null then
    return jsonb_build_object('ok',true,'idempotent',true,'state','AI_ACTIVE','released_assignments',0);
  end if;

  update public.aos_wa_assignments_v1
  set state='RELEASED',released_at=coalesce(released_at,now()),terminal_reason='L10_AUTONOMOUS_RETURN',updated_at=now()
  where conversation_id=p_conversation_id and state in ('ACTIVE','QUEUED');
  get diagnostics v_released = row_count;

  update public.aos_wa_conversations_v1
  set owner_user_id=null,state='AI_ACTIVE',human_takeover_at=null,handoff_requested_at=null,
      ownership_version=ownership_version+1,updated_at=now()
  where id=p_conversation_id;

  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,event_type,actor_id,payload)
  values(p_conversation_id,v_conv.box_id,'conversation.autonomous_canary_return',p_actor_id,
    jsonb_build_object('run_id',v_run.id,'reason',v_reason,'from_state',v_conv.state,'released_assignments',v_released));

  return jsonb_build_object('ok',true,'idempotent',false,'state','AI_ACTIVE','released_assignments',v_released,'run_id',v_run.id);
end
$$;

create or replace function public.aos_wa_l10_bridge_status_v1(p_run_key text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'ok',true,'version','WA-L10-BRIDGE-V1','run_key',r.run_key,
    'jobs',(select count(*) from public.aos_wa_l10_bridge_jobs_v1 j where j.run_id=r.id),
    'attempts',(select count(*) from public.aos_wa_l10_bridge_attempts_v1 a join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=a.provider_message_id where j.run_id=r.id),
    'suggested',(select count(*) from public.aos_wa_l10_bridge_events_v1 e join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=e.provider_message_id where j.run_id=r.id and e.event_type='SUGGESTED'),
    'sent',(select count(*) from public.aos_wa_l10_bridge_events_v1 e join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=e.provider_message_id where j.run_id=r.id and e.event_type='SENT'),
    'handoff',(select count(*) from public.aos_wa_l10_bridge_events_v1 e join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=e.provider_message_id where j.run_id=r.id and e.event_type='HANDOFF'),
    'blocked',(select count(*) from public.aos_wa_l10_bridge_events_v1 e join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=e.provider_message_id where j.run_id=r.id and e.event_type='BLOCKED'),
    'errors',(select count(*) from public.aos_wa_l10_bridge_events_v1 e join public.aos_wa_l10_bridge_jobs_v1 j on j.provider_message_id=e.provider_message_id where j.run_id=r.id and e.event_type='ERROR'),
    'authority_mode',a.mode,'kill_switch_engaged',a.kill_switch_engaged,
    'effective_autonomous_send',(a.mode='CANARY' and a.kill_switch_engaged is false and ai.auto_reply_enabled and rc.ai_send_enabled),
    'active_exact_scope',(select count(*) from public.aos_wa_auto_allowlist_v1 w join public.aos_wa_l10_canary_scope_v1 s on s.run_id=r.id and s.conversation_id::text=w.subject_key where w.subject_kind='CONVERSATION' and w.active is true and (w.expires_at is null or w.expires_at>now()))
  )
  from public.aos_wa_l10_canary_runs_v1 r
  cross join public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 rc
  where r.run_key=p_run_key and a.id=1 and ai.id=1 and rc.id=1
$$;

revoke all on function public.aos_wa_l10_bridge_append_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_wa_l10_bridge_enqueue_v1(text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_bridge_claim_v1(text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_bridge_event_v1(text,uuid,text,text,uuid,text,integer) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_bridge_pending_v1(integer) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_return_to_autonomous_canary_v1(uuid,text,uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_bridge_status_v1(text) from public,anon,authenticated;

grant execute on function public.aos_wa_l10_bridge_append_guard_v1() to service_role;
grant execute on function public.aos_wa_l10_bridge_enqueue_v1(text) to service_role;
grant execute on function public.aos_wa_l10_bridge_claim_v1(text) to service_role;
grant execute on function public.aos_wa_l10_bridge_event_v1(text,uuid,text,text,uuid,text,integer) to service_role;
grant execute on function public.aos_wa_l10_bridge_pending_v1(integer) to service_role;
grant execute on function public.aos_wa_l10_return_to_autonomous_canary_v1(uuid,text,uuid,text) to service_role;
grant execute on function public.aos_wa_l10_bridge_status_v1(text) to service_role;

comment on table public.aos_wa_l10_bridge_jobs_v1 is 'L10 durable inbound provider-message jobs for exact conversation CANARY only; no raw content/recipient stored.';
comment on table public.aos_wa_l10_bridge_attempts_v1 is 'L10 append-only bounded work leases; at most two attempts permits crash recovery without retry loops.';
comment on table public.aos_wa_l10_bridge_events_v1 is 'L10 append-only redacted bridge outcomes. Final provider dispatch remains L4/L8 + Meta runtime authority.';
comment on function public.aos_wa_l10_return_to_autonomous_canary_v1(uuid,text,uuid,text) is 'Explicit level-1 governed transition from human ownership to exact L10 CANARY AI_ACTIVE; preserves assignment/routing history.';

commit;
