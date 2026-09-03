-- WA-L9 — AUTONOMOUS DEMO READY shadow authority.
-- Reuses the certified L4 authority wrapped by L8, but executes it inside a
-- rollback-only subtransaction. No provider dispatch, outbound reservation,
-- booking mutation, business-ledger mutation or durable L4/L8 decision is created.

begin;

create table public.aos_wa_l9_demo_runs_v1 (
  id uuid primary key default gen_random_uuid(),
  demo_key text not null unique check (demo_key ~ '^[A-Za-z0-9._:-]{16,120}$'),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  recipient_hash text not null check (recipient_hash ~ '^[a-f0-9]{64}$'),
  payload_hash text not null check (payload_hash ~ '^[a-f0-9]{64}$'),
  message_type text not null check (char_length(btrim(message_type)) between 1 and 64),
  template_name text,
  authority_decision text not null check (authority_decision in ('ALLOW','BLOCK','HANDOFF')),
  authority_reason text not null check (char_length(btrim(authority_reason)) between 1 and 160),
  authority_mode text,
  l8_preflight text,
  would_send boolean not null,
  provider_dispatch boolean not null default false check (provider_dispatch is false),
  raw_content_stored boolean not null default false check (raw_content_stored is false),
  created_at timestamptz not null default now()
);

create index aos_wa_l9_demo_runs_conversation_idx
  on public.aos_wa_l9_demo_runs_v1(conversation_id,created_at desc);

alter table public.aos_wa_l9_demo_runs_v1 enable row level security;
alter table public.aos_wa_l9_demo_runs_v1 force row level security;
revoke all on public.aos_wa_l9_demo_runs_v1 from public,anon,authenticated;
grant select,insert on public.aos_wa_l9_demo_runs_v1 to service_role;

create or replace function public.aos_wa_l9_append_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA_L9_APPEND_ONLY' using errcode='55000';
end
$$;

drop trigger if exists trg_aos_wa_l9_demo_runs_append_guard_v1 on public.aos_wa_l9_demo_runs_v1;
create trigger trg_aos_wa_l9_demo_runs_append_guard_v1
before update or delete on public.aos_wa_l9_demo_runs_v1
for each row execute function public.aos_wa_l9_append_guard_v1();

-- Execute the exact certified L4+L8 authority and intentionally roll back every
-- side effect it creates. PL/pgSQL variables retain the returned JSON across the
-- subtransaction rollback, while DB writes/advisory decision rows do not persist.
create or replace function public.aos_wa_l9_shadow_authorize_v1(
  p_conversation_id uuid,
  p_recipient_kind text,
  p_recipient_address text,
  p_message_type text,
  p_template_name text,
  p_idempotency_key text,
  p_content_hash text,
  p_safety_action text default null,
  p_identity_state text default 'NOT_REQUIRED',
  p_requires_identity boolean default false,
  p_campaign_key text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_result jsonb;
  v_mode text;
  v_kill boolean;
  v_auto_reply boolean;
  v_ai_send boolean;
  v_auto_routing boolean;
  v_human_send boolean;
  v_would_send boolean:=false;
begin
  begin
    v_result:=public.aos_wa_l4_authorize_autonomous_send_v1(
      p_conversation_id,
      p_recipient_kind,
      p_recipient_address,
      p_message_type,
      p_template_name,
      p_idempotency_key,
      p_content_hash,
      p_safety_action,
      p_identity_state,
      p_requires_identity,
      p_campaign_key
    );
    raise exception 'WA_L9_SHADOW_ROLLBACK' using errcode='P0901';
  exception when sqlstate 'P0901' then
    null;
  end;

  if v_result is null then
    return pg_catalog.jsonb_build_object(
      'ok',false,'shadow',true,'decision','BLOCK','reason','WA_L9_SHADOW_AUTHORITY_EMPTY',
      'would_send',false,'provider_dispatch',false,'side_effects_rolled_back',true
    );
  end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
    into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;

  v_would_send:=coalesce(v_result->>'decision','BLOCK')='ALLOW';

  return (v_result - 'decision_id' - 'l8_preflight_id' - 'autonomous_actor_id')
    || pg_catalog.jsonb_build_object(
      'shadow',true,
      'would_send',v_would_send,
      'provider_dispatch',false,
      'side_effects_rolled_back',true,
      'production_mode',v_mode,
      'production_kill_switch_engaged',v_kill,
      'production_auto_reply_enabled',v_auto_reply,
      'production_ai_send_enabled',v_ai_send,
      'production_auto_routing_enabled',v_auto_routing,
      'production_human_send_enabled',v_human_send
    );
end
$$;

revoke all on function public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)
  from public,anon,authenticated;
grant execute on function public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)
  to service_role;

create or replace function public.aos_wa_l9_demo_record_v1(
  p_demo_key text,
  p_conversation_id uuid,
  p_recipient_hash text,
  p_payload_hash text,
  p_message_type text,
  p_template_name text,
  p_shadow_result jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_existing public.aos_wa_l9_demo_runs_v1%rowtype;
  v_row public.aos_wa_l9_demo_runs_v1%rowtype;
  v_decision text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_shadow_result->>'decision','BLOCK')));
  v_reason text:=pg_catalog.left(coalesce(nullif(pg_catalog.btrim(p_shadow_result->>'reason'),''),'WA_L9_SHADOW_UNSPECIFIED'),160);
  v_mode text:=nullif(pg_catalog.btrim(coalesce(p_shadow_result->>'mode',p_shadow_result->>'production_mode','')),'');
  v_l8 text:=nullif(pg_catalog.btrim(coalesce(p_shadow_result->>'l8_preflight','')),'');
  v_would boolean:=coalesce((p_shadow_result->>'would_send')::boolean,false);
begin
  if coalesce(p_demo_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L9_DEMO_KEY_INVALID');
  end if;
  if coalesce(p_recipient_hash,'') !~ '^[a-f0-9]{64}$' or coalesce(p_payload_hash,'') !~ '^[a-f0-9]{64}$' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L9_HASH_REQUIRED');
  end if;
  if v_decision not in ('ALLOW','BLOCK','HANDOFF') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L9_DECISION_INVALID');
  end if;
  if coalesce((p_shadow_result->>'provider_dispatch')::boolean,false) is true then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L9_PROVIDER_DISPATCH_FORBIDDEN');
  end if;

  select * into v_existing from public.aos_wa_l9_demo_runs_v1 where demo_key=p_demo_key;
  if v_existing.id is not null then
    if v_existing.conversation_id<>p_conversation_id
       or v_existing.recipient_hash<>p_recipient_hash
       or v_existing.payload_hash<>p_payload_hash then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L9_DEMO_KEY_CONFLICT');
    end if;
    return pg_catalog.jsonb_build_object(
      'ok',true,'replay',true,'demo_run_id',v_existing.id,'demo_key',v_existing.demo_key,
      'decision',v_existing.authority_decision,'reason',v_existing.authority_reason,
      'would_send',v_existing.would_send,'provider_dispatch',false
    );
  end if;

  insert into public.aos_wa_l9_demo_runs_v1(
    demo_key,conversation_id,recipient_hash,payload_hash,message_type,template_name,
    authority_decision,authority_reason,authority_mode,l8_preflight,would_send,
    provider_dispatch,raw_content_stored
  ) values (
    p_demo_key,p_conversation_id,p_recipient_hash,p_payload_hash,
    pg_catalog.lower(pg_catalog.btrim(coalesce(p_message_type,''))),nullif(pg_catalog.btrim(coalesce(p_template_name,'')),''),
    v_decision,v_reason,v_mode,v_l8,v_would,false,false
  ) returning * into v_row;

  return pg_catalog.jsonb_build_object(
    'ok',true,'replay',false,'demo_run_id',v_row.id,'demo_key',v_row.demo_key,
    'decision',v_row.authority_decision,'reason',v_row.authority_reason,
    'would_send',v_row.would_send,'provider_dispatch',false
  );
end
$$;

revoke all on function public.aos_wa_l9_demo_record_v1(text,uuid,text,text,text,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.aos_wa_l9_demo_record_v1(text,uuid,text,text,text,text,jsonb)
  to service_role;

create or replace function public.aos_wa_l9_status_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'ok',true,
    'mode',a.mode,
    'kill_switch_engaged',a.kill_switch_engaged,
    'auto_reply_enabled',ai.auto_reply_enabled,
    'ai_send_enabled',r.ai_send_enabled,
    'auto_routing_enabled',r.auto_routing_enabled,
    'human_send_enabled',r.human_send_enabled,
    'demo_runs',(select pg_catalog.count(*) from public.aos_wa_l9_demo_runs_v1),
    'would_send_runs',(select pg_catalog.count(*) from public.aos_wa_l9_demo_runs_v1 where would_send is true),
    'provider_dispatch_runs',(select pg_catalog.count(*) from public.aos_wa_l9_demo_runs_v1 where provider_dispatch is true),
    'autonomous_outbound',(select pg_catalog.count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and send_origin='AUTO')
  )
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

revoke all on function public.aos_wa_l9_status_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l9_status_v1() to service_role;

comment on function public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) is
  'WA-L9 rollback-safe shadow execution of the exact L4 authority wrapped by L8. Returns would-send evidence but persists no L4/L8 decision and never dispatches provider traffic.';
comment on table public.aos_wa_l9_demo_runs_v1 is
  'WA-L9 immutable redacted demo evidence. Stores hashes/decisions only; provider_dispatch is structurally false.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;