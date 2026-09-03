-- ASCENDA Conversations · WA-L4 Autonomous Authority + Kill Switch V1
-- Deployment contract: installs dormant authority only. Effective production state remains AUTO_OFF / SAFE-OFF.
-- CANARY/PROD transitions require explicit level-1 administration plus an authorization reference.

begin;

-- WA-4/WA-3 historically made autonomous sends structurally impossible. L4 replaces
-- those one-way CHECK constraints with a stronger centralized state machine.
alter table public.aos_wa_ai_control_v1
  drop constraint if exists aos_wa_ai_control_v1_auto_reply_enabled_check;
alter table public.aos_wa_routing_control_v1
  drop constraint if exists aos_wa_routing_control_v1_ai_send_enabled_check;

create table if not exists public.aos_wa_auto_authority_v1 (
  id smallint primary key default 1 check (id=1),
  mode text not null default 'AUTO_OFF' check (mode in ('AUTO_OFF','CANARY','PROD')),
  kill_switch_engaged boolean not null default true,
  daily_message_limit integer not null default 20 check (daily_message_limit between 1 and 500),
  max_turns_per_conversation integer not null default 8 check (max_turns_per_conversation between 1 and 50),
  global_rate_per_minute integer not null default 6 check (global_rate_per_minute between 1 and 120),
  conversation_rate_per_minute integer not null default 2 check (conversation_rate_per_minute between 1 and 30),
  cooldown_seconds integer not null default 15 check (cooldown_seconds between 0 and 3600),
  duplicate_window_seconds integer not null default 120 check (duplicate_window_seconds between 0 and 86400),
  autonomous_actor_id uuid not null default '00000000-0000-4000-8000-000000000004'::uuid,
  authorization_ref text,
  authorized_by uuid references public.aos_usuarios(id) on delete set null,
  authorized_at timestamptz,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.aos_wa_auto_authority_v1(id,mode,kill_switch_engaged)
values(1,'AUTO_OFF',true)
on conflict(id) do update
set mode='AUTO_OFF',kill_switch_engaged=true,authorization_ref=null,authorized_by=null,authorized_at=null,updated_at=now();
alter table public.aos_wa_auto_authority_v1 enable row level security;
alter table public.aos_wa_auto_authority_v1 force row level security;
revoke all on table public.aos_wa_auto_authority_v1 from public,anon,authenticated;
grant select,update on table public.aos_wa_auto_authority_v1 to service_role;

create table if not exists public.aos_wa_auto_allowlist_v1 (
  id uuid primary key default gen_random_uuid(),
  subject_kind text not null check (subject_kind in ('PHONE','BSUID','CONVERSATION','CAMPAIGN')),
  subject_key text not null check (char_length(btrim(subject_key)) between 1 and 256),
  active boolean not null default true,
  expires_at timestamptz,
  reason text,
  created_by uuid references public.aos_usuarios(id) on delete set null,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_kind,subject_key)
);
create index if not exists aos_wa_auto_allowlist_v1_active_idx
  on public.aos_wa_auto_allowlist_v1(subject_kind,subject_key)
  where active is true;
alter table public.aos_wa_auto_allowlist_v1 enable row level security;
alter table public.aos_wa_auto_allowlist_v1 force row level security;
revoke all on table public.aos_wa_auto_allowlist_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_wa_auto_allowlist_v1 to service_role;

create table if not exists public.aos_wa_auto_decisions_v1 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique check (idempotency_key ~ '^[A-Za-z0-9._:-]{16,120}$'),
  conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict,
  recipient_kind text not null check (recipient_kind in ('PHONE','BSUID')),
  recipient_hash text not null check (recipient_hash ~ '^[a-f0-9]{64}$'),
  message_type text not null,
  template_name text,
  content_hash text not null check (content_hash ~ '^[a-f0-9]{64}$'),
  decision text not null check (decision in ('ALLOW','BLOCK','HANDOFF')),
  reason_code text not null,
  authority_mode text not null check (authority_mode in ('AUTO_OFF','CANARY','PROD')),
  kill_switch_engaged boolean not null,
  identity_state text,
  safety_action text,
  requires_identity boolean not null default false,
  daily_count_before integer not null default 0,
  global_rate_count_before integer not null default 0,
  conversation_rate_count_before integer not null default 0,
  turns_count_before integer not null default 0,
  cooldown_remaining_seconds integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists aos_wa_auto_decisions_v1_daily_idx on public.aos_wa_auto_decisions_v1(created_at,decision);
create index if not exists aos_wa_auto_decisions_v1_conv_idx on public.aos_wa_auto_decisions_v1(conversation_id,created_at desc,decision);
create index if not exists aos_wa_auto_decisions_v1_duplicate_idx on public.aos_wa_auto_decisions_v1(conversation_id,content_hash,created_at desc) where decision='ALLOW';
alter table public.aos_wa_auto_decisions_v1 enable row level security;
alter table public.aos_wa_auto_decisions_v1 force row level security;
revoke all on table public.aos_wa_auto_decisions_v1 from public,anon,authenticated;
grant select,insert on table public.aos_wa_auto_decisions_v1 to service_role;

create table if not exists public.aos_wa_auto_control_events_v1 (
  id bigint generated always as identity primary key,
  event_type text not null,
  actor_id uuid references public.aos_usuarios(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists aos_wa_auto_control_events_v1_created_idx on public.aos_wa_auto_control_events_v1(created_at desc,event_type);
alter table public.aos_wa_auto_control_events_v1 enable row level security;
alter table public.aos_wa_auto_control_events_v1 force row level security;
revoke all on table public.aos_wa_auto_control_events_v1 from public,anon,authenticated;
grant select,insert on table public.aos_wa_auto_control_events_v1 to service_role;

-- Additive lineage only. Existing HUMAN rows remain untouched.
alter table public.aos_wa_outbound_requests_v1
  add column if not exists send_origin text not null default 'HUMAN' check (send_origin in ('HUMAN','AUTO')),
  add column if not exists conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict,
  add column if not exists authority_decision_id uuid references public.aos_wa_auto_decisions_v1(id) on delete restrict;
create index if not exists aos_wa_outbound_requests_v1_auto_idx
  on public.aos_wa_outbound_requests_v1(send_origin,created_at desc)
  where send_origin='AUTO';

alter table public.aos_wa_messages_v1
  add column if not exists send_origin text not null default 'HUMAN' check (send_origin in ('HUMAN','AUTO')),
  add column if not exists authority_decision_id uuid references public.aos_wa_auto_decisions_v1(id) on delete restrict;
create index if not exists aos_wa_messages_v1_auto_idx
  on public.aos_wa_messages_v1(send_origin,created_at desc)
  where send_origin='AUTO';

create or replace function public.aos_wa_l4_append_guard_v1()
returns trigger language plpgsql set search_path='' as $$
begin
  raise exception 'WA_L4_APPEND_ONLY' using errcode='55000';
end
$$;
drop trigger if exists trg_aos_wa_l4_decision_append_guard_v1 on public.aos_wa_auto_decisions_v1;
create trigger trg_aos_wa_l4_decision_append_guard_v1
before update or delete on public.aos_wa_auto_decisions_v1
for each row execute function public.aos_wa_l4_append_guard_v1();
drop trigger if exists trg_aos_wa_l4_control_event_append_guard_v1 on public.aos_wa_auto_control_events_v1;
create trigger trg_aos_wa_l4_control_event_append_guard_v1
before update or delete on public.aos_wa_auto_control_events_v1
for each row execute function public.aos_wa_l4_append_guard_v1();

create or replace function public.aos_wa_l4_is_level1_admin_v1(p_actor_id uuid)
returns boolean language sql stable set search_path='' as $$
  select exists(
    select 1 from public.aos_usuarios u
    where u.id=p_actor_id and u.activo is true and coalesce(u.nivel_jerarquia,99)=1
      and coalesce(u.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[]
  )
$$;

create or replace function public.aos_wa_l4_normalize_subject_v1(p_kind text,p_key text)
returns text language plpgsql immutable set search_path='' as $$
declare v_kind text:=upper(btrim(coalesce(p_kind,''))); v_key text:=btrim(coalesce(p_key,'')); v_phone text;
begin
  if v_kind='PHONE' then
    if v_key ~ '[A-Za-z]' then return null; end if;
    v_phone:=regexp_replace(v_key,'[^0-9]','','g');
    if char_length(v_phone) not between 8 and 20 then return null; end if;
    return v_phone;
  elsif v_kind in ('BSUID','CONVERSATION','CAMPAIGN') then
    if v_key='' or char_length(v_key)>256 then return null; end if;
    return v_key;
  end if;
  return null;
end
$$;

create or replace function public.aos_wa_l4_allowlist_set_v1(
  p_actor_id uuid,
  p_subject_kind text,
  p_subject_key text,
  p_active boolean default true,
  p_expires_at timestamptz default null,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_kind text:=upper(btrim(coalesce(p_subject_kind,''))); v_key text; v_row public.aos_wa_auto_allowlist_v1%rowtype;
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA_L4_LEVEL1_ADMIN_REQUIRED'); end if;
  v_key:=public.aos_wa_l4_normalize_subject_v1(v_kind,p_subject_key);
  if v_key is null then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_ALLOWLIST_SUBJECT'); end if;
  if p_expires_at is not null and p_expires_at<=now() and coalesce(p_active,true) then return jsonb_build_object('ok',false,'error','WA_L4_ALLOWLIST_EXPIRY_INVALID'); end if;
  insert into public.aos_wa_auto_allowlist_v1(subject_kind,subject_key,active,expires_at,reason,created_by,updated_by)
  values(v_kind,v_key,coalesce(p_active,true),p_expires_at,nullif(btrim(coalesce(p_reason,'')),''),p_actor_id,p_actor_id)
  on conflict(subject_kind,subject_key) do update
  set active=excluded.active,expires_at=excluded.expires_at,reason=excluded.reason,updated_by=p_actor_id,updated_at=now()
  returning * into v_row;
  insert into public.aos_wa_auto_control_events_v1(event_type,actor_id,payload)
  values('ALLOWLIST_SET',p_actor_id,jsonb_build_object('subject_kind',v_kind,'subject_hash',encode(extensions.digest(convert_to(v_key,'UTF8'),'sha256'),'hex'),'active',v_row.active,'expires_at',v_row.expires_at));
  return jsonb_build_object('ok',true,'subject_kind',v_kind,'active',v_row.active,'expires_at',v_row.expires_at);
end
$$;

create or replace function public.aos_wa_l4_set_control_v1(
  p_actor_id uuid,
  p_mode text default null,
  p_kill_switch_engaged boolean default null,
  p_daily_message_limit integer default null,
  p_max_turns_per_conversation integer default null,
  p_global_rate_per_minute integer default null,
  p_conversation_rate_per_minute integer default null,
  p_cooldown_seconds integer default null,
  p_duplicate_window_seconds integer default null,
  p_authorization_ref text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_current public.aos_wa_auto_authority_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_auth text:=nullif(btrim(coalesce(p_authorization_ref,'')),'');
  v_row public.aos_wa_auto_authority_v1%rowtype;
  v_effective_on boolean;
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA_L4_LEVEL1_ADMIN_REQUIRED'); end if;
  select * into v_current from public.aos_wa_auto_authority_v1 where id=1 for update;
  if v_current.id is null then return jsonb_build_object('ok',false,'error','WA_L4_CONTROL_MISSING'); end if;
  v_mode:=upper(coalesce(nullif(btrim(p_mode),''),v_current.mode));
  v_kill:=coalesce(p_kill_switch_engaged,v_current.kill_switch_engaged);
  if v_mode not in ('AUTO_OFF','CANARY','PROD') then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_MODE'); end if;
  if p_daily_message_limit is not null and p_daily_message_limit not between 1 and 500 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_DAILY_LIMIT'); end if;
  if p_max_turns_per_conversation is not null and p_max_turns_per_conversation not between 1 and 50 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_MAX_TURNS'); end if;
  if p_global_rate_per_minute is not null and p_global_rate_per_minute not between 1 and 120 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_GLOBAL_RATE'); end if;
  if p_conversation_rate_per_minute is not null and p_conversation_rate_per_minute not between 1 and 30 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_CONVERSATION_RATE'); end if;
  if p_cooldown_seconds is not null and p_cooldown_seconds not between 0 and 3600 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_COOLDOWN'); end if;
  if p_duplicate_window_seconds is not null and p_duplicate_window_seconds not between 0 and 86400 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_DUPLICATE_WINDOW'); end if;

  if v_mode in ('CANARY','PROD') then
    if v_auth is null or char_length(v_auth)<12 then return jsonb_build_object('ok',false,'error','WA_L4_EXPLICIT_AUTHORIZATION_REF_REQUIRED'); end if;
    if v_mode='CANARY' and not exists(
      select 1 from public.aos_wa_auto_allowlist_v1 a where a.active is true and (a.expires_at is null or a.expires_at>now())
    ) then return jsonb_build_object('ok',false,'error','WA_L4_CANARY_ALLOWLIST_REQUIRED'); end if;
    if v_mode='PROD' and v_current.mode<>'CANARY' then return jsonb_build_object('ok',false,'error','WA_L4_PROD_REQUIRES_CANARY_STATE'); end if;
  end if;

  update public.aos_wa_auto_authority_v1
  set mode=v_mode,
      kill_switch_engaged=v_kill,
      daily_message_limit=coalesce(p_daily_message_limit,daily_message_limit),
      max_turns_per_conversation=coalesce(p_max_turns_per_conversation,max_turns_per_conversation),
      global_rate_per_minute=coalesce(p_global_rate_per_minute,global_rate_per_minute),
      conversation_rate_per_minute=coalesce(p_conversation_rate_per_minute,conversation_rate_per_minute),
      cooldown_seconds=coalesce(p_cooldown_seconds,cooldown_seconds),
      duplicate_window_seconds=coalesce(p_duplicate_window_seconds,duplicate_window_seconds),
      authorization_ref=case when v_mode='AUTO_OFF' then null else v_auth end,
      authorized_by=case when v_mode='AUTO_OFF' then null else p_actor_id end,
      authorized_at=case when v_mode='AUTO_OFF' then null else now() end,
      updated_by=p_actor_id,updated_at=now()
  where id=1 returning * into v_row;

  v_effective_on:=(v_row.mode in ('CANARY','PROD') and v_row.kill_switch_engaged is false);

  update public.aos_wa_ai_control_v1
  set auto_reply_enabled=v_effective_on,updated_by=p_actor_id,updated_at=now()
  where id=1;
  update public.aos_wa_routing_control_v1
  set ai_send_enabled=v_effective_on,
      auto_routing_enabled=false,
      human_send_enabled=true,
      updated_by=p_actor_id,updated_at=now()
  where id=1;

  insert into public.aos_wa_auto_control_events_v1(event_type,actor_id,payload)
  values('CONTROL_SET',p_actor_id,jsonb_build_object(
    'mode',v_row.mode,'kill_switch_engaged',v_row.kill_switch_engaged,'effective_autonomous_send',v_effective_on,
    'daily_message_limit',v_row.daily_message_limit,'max_turns_per_conversation',v_row.max_turns_per_conversation,
    'global_rate_per_minute',v_row.global_rate_per_minute,'conversation_rate_per_minute',v_row.conversation_rate_per_minute,
    'cooldown_seconds',v_row.cooldown_seconds,'duplicate_window_seconds',v_row.duplicate_window_seconds,
    'authorization_ref_present',v_row.authorization_ref is not null));

  return jsonb_build_object('ok',true,'mode',v_row.mode,'kill_switch_engaged',v_row.kill_switch_engaged,'effective_autonomous_send',v_effective_on,
    'auto_reply_enabled',v_effective_on,'ai_send_enabled',v_effective_on,'auto_routing_enabled',false,'human_send_enabled',true);
end
$$;

create or replace function public.aos_wa_l4_authorize_autonomous_send_v1(
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
  v_control public.aos_wa_auto_authority_v1%rowtype;
  v_ai public.aos_wa_ai_control_v1%rowtype;
  v_route public.aos_wa_routing_control_v1%rowtype;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_existing public.aos_wa_auto_decisions_v1%rowtype;
  v_kind text:=upper(btrim(coalesce(p_recipient_kind,'')));
  v_address text;
  v_type text:=lower(btrim(coalesce(p_message_type,'')));
  v_template text:=nullif(btrim(coalesce(p_template_name,'')),'');
  v_safety text:=upper(coalesce(nullif(btrim(p_safety_action),''),'ALLOW'));
  v_identity text:=upper(coalesce(nullif(btrim(p_identity_state),''),'NOT_REQUIRED'));
  v_campaign text:=nullif(btrim(coalesce(p_campaign_key,'')),'');
  v_decision text:='ALLOW';
  v_reason text:='WA_L4_ALLOWED';
  v_daily integer:=0;
  v_global integer:=0;
  v_conv_rate integer:=0;
  v_turns integer:=0;
  v_cooldown integer:=0;
  v_last_allowed timestamptz;
  v_day_start timestamptz;
  v_recipient_hash text;
  v_decision_id uuid;
  v_allowlisted boolean:=false;
begin
  perform pg_catalog.pg_advisory_xact_lock(744,4);

  if coalesce(p_idempotency_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L4_INVALID_IDEMPOTENCY_KEY');
  end if;
  if coalesce(p_content_hash,'') !~ '^[a-f0-9]{64}$' then
    return jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L4_INVALID_CONTENT_HASH');
  end if;

  select * into v_existing from public.aos_wa_auto_decisions_v1 where idempotency_key=p_idempotency_key;
  if v_existing.id is not null then
    return jsonb_build_object('ok',v_existing.decision='ALLOW','replay',true,'decision_id',v_existing.id,'decision',v_existing.decision,
      'reason',v_existing.reason_code,'mode',v_existing.authority_mode,'autonomous_actor_id',(select autonomous_actor_id from public.aos_wa_auto_authority_v1 where id=1));
  end if;

  v_address:=public.aos_wa_l4_normalize_subject_v1(v_kind,p_recipient_address);
  if v_kind not in ('PHONE','BSUID') or v_address is null then
    return jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L4_INVALID_RECIPIENT');
  end if;
  if v_type='' or char_length(v_type)>64 then
    return jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L4_INVALID_MESSAGE_TYPE');
  end if;

  select * into v_control from public.aos_wa_auto_authority_v1 where id=1;
  select * into v_ai from public.aos_wa_ai_control_v1 where id=1;
  select * into v_route from public.aos_wa_routing_control_v1 where id=1;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;

  v_recipient_hash:=encode(extensions.digest(convert_to(v_kind||':'||v_address,'UTF8'),'sha256'),'hex');
  v_day_start:=date_trunc('day',now() at time zone 'America/Lima') at time zone 'America/Lima';
  select count(*)::integer into v_daily from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and created_at>=v_day_start;
  select count(*)::integer into v_global from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and created_at>=now()-interval '1 minute';
  select count(*)::integer into v_conv_rate from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and conversation_id=p_conversation_id and created_at>=now()-interval '1 minute';
  select count(*)::integer into v_turns from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and conversation_id=p_conversation_id and created_at>=now()-interval '24 hours';
  select max(created_at) into v_last_allowed from public.aos_wa_auto_decisions_v1 where decision='ALLOW' and conversation_id=p_conversation_id;
  if v_last_allowed is not null and v_control.cooldown_seconds>0 then
    v_cooldown:=greatest(0,ceil(extract(epoch from (v_last_allowed + make_interval(secs=>v_control.cooldown_seconds) - now())))::integer);
  end if;

  if v_control.id is null then v_decision:='BLOCK';v_reason:='WA_L4_CONTROL_MISSING';
  elsif v_control.mode='AUTO_OFF' then v_decision:='BLOCK';v_reason:='WA_L4_AUTO_OFF';
  elsif v_control.kill_switch_engaged then v_decision:='BLOCK';v_reason:='WA_L4_KILL_SWITCH';
  elsif v_ai.id is null or v_ai.copilot_enabled is not true or v_ai.auto_reply_enabled is not true then v_decision:='BLOCK';v_reason:='WA_L4_AI_CONTROL_NOT_READY';
  elsif v_route.id is null or v_route.ai_send_enabled is not true then v_decision:='BLOCK';v_reason:='WA_L4_AI_SEND_DISABLED';
  elsif v_conv.id is null then v_decision:='BLOCK';v_reason:='WA_L4_CONVERSATION_NOT_FOUND';
  elsif v_conv.state in ('CLOSED','WON','LOST') then v_decision:='BLOCK';v_reason:='WA_L4_CONVERSATION_TERMINAL';
  elsif v_conv.state in ('HUMAN_REQUESTED','HUMAN_ACTIVE','AI_COPILOT') or v_conv.human_takeover_at is not null then v_decision:='HANDOFF';v_reason:='WA_L4_HUMAN_OWNERSHIP_BOUNDARY';
  elsif v_conv.contact_address_type<>v_kind or v_conv.contact_address<>v_address then v_decision:='HANDOFF';v_reason:='WA_L4_RECIPIENT_CONVERSATION_MISMATCH';
  elsif v_safety in ('BLOCK','DENY') then v_decision:='BLOCK';v_reason:='WA_L4_SAFETY_BLOCK';
  elsif v_safety in ('HANDOFF','HUMAN','CLINICAL','ESCALATE') then v_decision:='HANDOFF';v_reason:='WA_L4_SAFETY_HANDOFF';
  elsif v_identity='CONFLICT' then v_decision:='HANDOFF';v_reason:='WA_L4_IDENTITY_CONFLICT';
  elsif coalesce(p_requires_identity,false) and v_identity not in ('CANONICAL','VERIFIED') then v_decision:='HANDOFF';v_reason:='WA_L4_IDENTITY_REQUIRED';
  elsif v_type='template' and (v_template is null or not exists(
    select 1 from public.aos_agenda_delivery_template_registry_v3 t
    where t.channel='WHATSAPP' and t.provider='META_CLOUD_API' and t.active is true and t.provider_verified is true
      and t.provider_template_name=v_template
  )) then v_decision:='BLOCK';v_reason:='WA_L4_TEMPLATE_NOT_PROVIDER_VERIFIED';
  elsif v_control.mode='CANARY' then
    select exists(
      select 1 from public.aos_wa_auto_allowlist_v1 a
      where a.active is true and (a.expires_at is null or a.expires_at>now()) and (
        (a.subject_kind=v_kind and a.subject_key=v_address)
        or (a.subject_kind='CONVERSATION' and a.subject_key=p_conversation_id::text)
        or (v_campaign is not null and a.subject_kind='CAMPAIGN' and a.subject_key=v_campaign)
      )
    ) into v_allowlisted;
    if not v_allowlisted then v_decision:='BLOCK';v_reason:='WA_L4_CANARY_NOT_ALLOWLISTED'; end if;
  end if;

  if v_decision='ALLOW' then
    if v_daily>=v_control.daily_message_limit then v_decision:='BLOCK';v_reason:='WA_L4_DAILY_MESSAGE_LIMIT';
    elsif v_turns>=v_control.max_turns_per_conversation then v_decision:='HANDOFF';v_reason:='WA_L4_MAX_TURNS_HANDOFF';
    elsif v_global>=v_control.global_rate_per_minute then v_decision:='BLOCK';v_reason:='WA_L4_GLOBAL_RATE_LIMIT';
    elsif v_conv_rate>=v_control.conversation_rate_per_minute then v_decision:='BLOCK';v_reason:='WA_L4_CONVERSATION_RATE_LIMIT';
    elsif v_cooldown>0 then v_decision:='BLOCK';v_reason:='WA_L4_COOLDOWN';
    elsif v_control.duplicate_window_seconds>0 and exists(
      select 1 from public.aos_wa_auto_decisions_v1 d where d.decision='ALLOW' and d.conversation_id=p_conversation_id and d.content_hash=p_content_hash
        and d.created_at>=now()-make_interval(secs=>v_control.duplicate_window_seconds)
    ) then v_decision:='BLOCK';v_reason:='WA_L4_DUPLICATE_GUARD';
    end if;
  end if;

  insert into public.aos_wa_auto_decisions_v1(
    idempotency_key,conversation_id,recipient_kind,recipient_hash,message_type,template_name,content_hash,decision,reason_code,
    authority_mode,kill_switch_engaged,identity_state,safety_action,requires_identity,daily_count_before,global_rate_count_before,
    conversation_rate_count_before,turns_count_before,cooldown_remaining_seconds,metadata)
  values(p_idempotency_key,p_conversation_id,v_kind,v_recipient_hash,v_type,v_template,p_content_hash,v_decision,v_reason,
    coalesce(v_control.mode,'AUTO_OFF'),coalesce(v_control.kill_switch_engaged,true),v_identity,v_safety,coalesce(p_requires_identity,false),
    v_daily,v_global,v_conv_rate,v_turns,v_cooldown,
    jsonb_build_object('campaign_key_present',v_campaign is not null,'canary_allowlisted',v_allowlisted,'raw_content_stored',false))
  returning id into v_decision_id;

  return jsonb_build_object(
    'ok',v_decision='ALLOW','replay',false,'decision_id',v_decision_id,'decision',v_decision,'reason',v_reason,
    'mode',coalesce(v_control.mode,'AUTO_OFF'),'kill_switch_engaged',coalesce(v_control.kill_switch_engaged,true),
    'autonomous_actor_id',v_control.autonomous_actor_id,'daily_count_before',v_daily,'turns_count_before',v_turns,
    'global_rate_count_before',v_global,'conversation_rate_count_before',v_conv_rate,'cooldown_remaining_seconds',v_cooldown
  );
end
$$;

create or replace function public.aos_wa_l4_status_v1()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'ok',true,'mode',a.mode,'kill_switch_engaged',a.kill_switch_engaged,
    'effective_autonomous_send',(a.mode in ('CANARY','PROD') and a.kill_switch_engaged is false and ai.auto_reply_enabled and r.ai_send_enabled),
    'copilot_enabled',ai.copilot_enabled,'auto_reply_enabled',ai.auto_reply_enabled,'ai_send_enabled',r.ai_send_enabled,
    'auto_routing_enabled',r.auto_routing_enabled,'human_send_enabled',r.human_send_enabled,
    'daily_message_limit',a.daily_message_limit,'max_turns_per_conversation',a.max_turns_per_conversation,
    'global_rate_per_minute',a.global_rate_per_minute,'conversation_rate_per_minute',a.conversation_rate_per_minute,
    'cooldown_seconds',a.cooldown_seconds,'duplicate_window_seconds',a.duplicate_window_seconds,
    'active_allowlist',(select count(*) from public.aos_wa_auto_allowlist_v1 w where w.active is true and (w.expires_at is null or w.expires_at>now())),
    'allowed_today',(select count(*) from public.aos_wa_auto_decisions_v1 d where d.decision='ALLOW' and d.created_at>=date_trunc('day',now() at time zone 'America/Lima') at time zone 'America/Lima'),
    'handoffs_today',(select count(*) from public.aos_wa_auto_decisions_v1 d where d.decision='HANDOFF' and d.created_at>=date_trunc('day',now() at time zone 'America/Lima') at time zone 'America/Lima'),
    'blocks_today',(select count(*) from public.aos_wa_auto_decisions_v1 d where d.decision='BLOCK' and d.created_at>=date_trunc('day',now() at time zone 'America/Lima') at time zone 'America/Lima')
  )
  from public.aos_wa_auto_authority_v1 a cross join public.aos_wa_ai_control_v1 ai cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

-- Privileges: all L4 authority/control functions are server-side only.
revoke all on function public.aos_wa_l4_append_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_wa_l4_is_level1_admin_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_normalize_subject_v1(text,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_allowlist_set_v1(uuid,text,text,boolean,timestamptz,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_set_control_v1(uuid,text,boolean,integer,integer,integer,integer,integer,integer,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_status_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l4_append_guard_v1() to service_role;
grant execute on function public.aos_wa_l4_is_level1_admin_v1(uuid) to service_role;
grant execute on function public.aos_wa_l4_normalize_subject_v1(text,text) to service_role;
grant execute on function public.aos_wa_l4_allowlist_set_v1(uuid,text,text,boolean,timestamptz,text) to service_role;
grant execute on function public.aos_wa_l4_set_control_v1(uuid,text,boolean,integer,integer,integer,integer,integer,integer,text) to service_role;
grant execute on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) to service_role;
grant execute on function public.aos_wa_l4_status_v1() to service_role;

comment on table public.aos_wa_auto_authority_v1 is 'WA-L4 centralized autonomous authority. Deployment defaults AUTO_OFF + kill switch engaged; CANARY/PROD require explicit level-1 authorization.';
comment on table public.aos_wa_auto_allowlist_v1 is 'WA-L4 server-only canary allowlist. PHONE/BSUID/CONVERSATION/CAMPAIGN subjects; no browser access.';
comment on table public.aos_wa_auto_decisions_v1 is 'WA-L4 append-only authority decisions. Stores hashes/decision metadata, never raw model prompt/reply.';
comment on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) is 'Serialized fail-closed authority decision before any autonomous Meta dispatch: mode/kill/flags/ownership/identity/safety/template/allowlist/budget/rate/cooldown/duplicate gates.';

select pg_notify('pgrst','reload schema');
commit;
