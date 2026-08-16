-- CIA V3 F17 — provider-neutral multichannel contracts v1
-- Additive only. No provider spend or broad send activation.

create table if not exists public.aos_cia_channel_recipient_controls_v1 (
  contact_key text not null,
  channel text not null check (channel in ('WHATSAPP','SMS')),
  consent_status text not null default 'UNKNOWN' check (consent_status in ('UNKNOWN','ALLOWED','DENIED')),
  suppression_status text not null default 'UNKNOWN' check (suppression_status in ('UNKNOWN','CLEAR','SUPPRESSED')),
  source text not null default 'UNSET',
  evidence jsonb not null default '{}'::jsonb,
  updated_by_user_id uuid,
  updated_at timestamptz not null default now(),
  primary key (contact_key, channel),
  check (public.aos_cia_normalize_contact_key_v1(contact_key) = contact_key)
);

create table if not exists public.aos_cia_channel_send_requests_v1 (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null default gen_random_uuid(),
  activation_id uuid references public.aos_audiencia_activaciones(id) on delete restrict,
  contact_key text not null,
  channel text not null check (channel in ('WHATSAPP','SMS')),
  purpose text not null,
  message_class text not null,
  idempotency_key text not null unique,
  eligibility_status text not null check (eligibility_status in ('ALLOWED','BLOCKED')),
  consent_status text not null check (consent_status in ('UNKNOWN','ALLOWED','DENIED')),
  suppression_status text not null check (suppression_status in ('UNKNOWN','CLEAR','SUPPRESSED')),
  state text not null check (state in ('BLOCKED','READY','DISPATCHING','ACCEPTED','FAILED','CANCELLED')),
  provider text,
  provider_message_id text,
  dispatch_attempts integer not null default 0 check (dispatch_attempts >= 0),
  requested_by_user_id uuid,
  authorization_provenance jsonb not null default '{}'::jsonb,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  terminal_at timestamptz,
  check (public.aos_cia_normalize_contact_key_v1(contact_key) = contact_key),
  check (length(idempotency_key) between 16 and 200),
  check ((eligibility_status='ALLOWED' and consent_status='ALLOWED' and suppression_status='CLEAR' and state <> 'BLOCKED')
      or (eligibility_status='BLOCKED' and state='BLOCKED'))
);

create index if not exists aos_cia_channel_send_requests_contact_idx
  on public.aos_cia_channel_send_requests_v1(contact_key, channel, created_at desc);
create index if not exists aos_cia_channel_send_requests_state_idx
  on public.aos_cia_channel_send_requests_v1(state, created_at desc);
create index if not exists aos_cia_channel_send_requests_activation_idx
  on public.aos_cia_channel_send_requests_v1(activation_id, created_at desc)
  where activation_id is not null;

create table if not exists public.aos_cia_channel_send_events_v1 (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.aos_cia_channel_send_requests_v1(id) on delete restrict,
  channel text not null check (channel in ('WHATSAPP','SMS')),
  event_key text not null unique,
  event_type text not null,
  provider_message_id text,
  status text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (length(event_key) between 8 and 240)
);

create index if not exists aos_cia_channel_send_events_request_idx
  on public.aos_cia_channel_send_events_v1(request_id, occurred_at desc);
create index if not exists aos_cia_channel_send_events_provider_idx
  on public.aos_cia_channel_send_events_v1(provider_message_id, occurred_at desc)
  where provider_message_id is not null;

create table if not exists public.aos_cia_channel_inbound_facts_v1 (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('WHATSAPP','SMS')),
  provider_message_id text not null,
  contact_key text,
  identity_status text not null default 'UNRESOLVED' check (identity_status in ('RESOLVED','CONFLICT','UNRESOLVED')),
  conversation_ref text,
  message_type text not null,
  provider_timestamp timestamptz,
  attribution_ref jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(channel, provider_message_id),
  check (contact_key is null or public.aos_cia_normalize_contact_key_v1(contact_key) = contact_key)
);

create index if not exists aos_cia_channel_inbound_contact_idx
  on public.aos_cia_channel_inbound_facts_v1(contact_key, created_at desc)
  where contact_key is not null;

create table if not exists public.aos_cia_channel_release_state (
  singleton boolean primary key default true check (singleton),
  contracts_active boolean not null default true,
  whatsapp_bridge_validated boolean not null default false,
  outbound_policy_validated boolean not null default false,
  webhook_replay_validated boolean not null default false,
  canary_passed boolean not null default false,
  rollback_verified boolean not null default false,
  evidence jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.aos_cia_channel_release_state(singleton,contracts_active,evidence)
values (true,true,jsonb_build_object('CONTRACTS_ACTIVE',jsonb_build_object('value',true,'evidence','F17 additive provider-neutral schema installed')))
on conflict (singleton) do update set contracts_active=true, updated_at=now();

-- Read-only, provider-neutral projection over existing WA facts. Deliberately excludes message_body/raw_referral.
create or replace view public.aos_cia_whatsapp_bridge_v1
with (security_invoker=true)
as
select
  m.id as wa_message_id,
  m.provider_message_id,
  m.conversation_id,
  public.aos_cia_normalize_contact_key_v1(case when m.direction='INBOUND' then m.from_number else m.to_number end) as contact_key,
  case
    when i.identity_conflict is true then 'CONFLICT'
    when i.contact_key is not null then 'RESOLVED'
    else 'UNRESOLVED'
  end as identity_status,
  m.direction,
  m.message_type,
  m.status,
  m.campaign_source,
  m.ad_id,
  m.lead_id,
  m.provider_timestamp,
  m.received_at,
  m.sent_at,
  m.delivered_at,
  m.read_at,
  m.failed_at,
  m.created_at
from public.aos_wa_messages_v1 m
left join public.aos_cia_contact_identity_v1 i
  on i.contact_key = public.aos_cia_normalize_contact_key_v1(case when m.direction='INBOUND' then m.from_number else m.to_number end);

-- Fail-closed request preparation. It reserves idempotency and never dispatches to a provider.
create or replace function public.aos_cia_channel_prepare_send_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_f16 jsonb;
  v_channel text;
  v_contact_key text;
  v_purpose text;
  v_message_class text;
  v_idempotency_key text;
  v_activation_id uuid;
  v_requested_by uuid;
  v_consent text := 'UNKNOWN';
  v_suppression text := 'UNKNOWN';
  v_eligibility text;
  v_state text;
  v_row public.aos_cia_channel_send_requests_v1%rowtype;
begin
  v_f16 := public.aos_cia_email_f17_readiness_v1();
  if coalesce((v_f16->>'ready_for_f17')::boolean,false) is not true then
    raise exception 'F17_DEPENDENCY_NOT_READY' using errcode='55000';
  end if;

  v_channel := upper(trim(coalesce(p_payload->>'channel','')));
  if v_channel not in ('WHATSAPP','SMS') then
    raise exception 'CHANNEL_NOT_SUPPORTED' using errcode='22023';
  end if;

  v_contact_key := public.aos_cia_normalize_contact_key_v1(p_payload->>'recipient_contact');
  if v_contact_key is null then
    raise exception 'CONTACT_KEY_INVALID' using errcode='22023';
  end if;

  v_purpose := trim(coalesce(p_payload->>'purpose',''));
  v_message_class := upper(trim(coalesce(p_payload->>'message_class','')));
  v_idempotency_key := trim(coalesce(p_payload->>'idempotency_key',''));
  if v_purpose='' or v_message_class='' or length(v_idempotency_key) not between 16 and 200 then
    raise exception 'REQUEST_CONTRACT_INVALID' using errcode='22023';
  end if;

  if nullif(p_payload->>'activation_id','') is not null then
    v_activation_id := (p_payload->>'activation_id')::uuid;
    if not exists(select 1 from public.aos_audiencia_activaciones a where a.id=v_activation_id) then
      raise exception 'ACTIVATION_NOT_FOUND' using errcode='23503';
    end if;
  end if;

  if nullif(p_payload->>'requested_by_user_id','') is not null then
    v_requested_by := (p_payload->>'requested_by_user_id')::uuid;
  end if;

  select c.consent_status,c.suppression_status
    into v_consent,v_suppression
  from public.aos_cia_channel_recipient_controls_v1 c
  where c.contact_key=v_contact_key and c.channel=v_channel;

  v_consent := coalesce(v_consent,'UNKNOWN');
  v_suppression := coalesce(v_suppression,'UNKNOWN');
  v_eligibility := case when v_consent='ALLOWED' and v_suppression='CLEAR' then 'ALLOWED' else 'BLOCKED' end;
  v_state := case when v_eligibility='ALLOWED' then 'READY' else 'BLOCKED' end;

  insert into public.aos_cia_channel_send_requests_v1(
    activation_id,contact_key,channel,purpose,message_class,idempotency_key,
    eligibility_status,consent_status,suppression_status,state,requested_by_user_id,
    authorization_provenance,context
  ) values (
    v_activation_id,v_contact_key,v_channel,v_purpose,v_message_class,v_idempotency_key,
    v_eligibility,v_consent,v_suppression,v_state,v_requested_by,
    coalesce(p_payload->'authorization_provenance','{}'::jsonb),
    coalesce(p_payload->'context','{}'::jsonb)
  )
  on conflict (idempotency_key) do nothing
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.aos_cia_channel_send_requests_v1 where idempotency_key=v_idempotency_key;
  end if;

  return jsonb_build_object(
    'ok',true,
    'request_id',v_row.id,
    'state',v_row.state,
    'eligibility_status',v_row.eligibility_status,
    'consent_status',v_row.consent_status,
    'suppression_status',v_row.suppression_status,
    'channel',v_row.channel,
    'contact_key',v_row.contact_key,
    'dispatch_allowed',v_row.state='READY'
  );
end
$$;

create or replace function public.aos_cia_channel_record_event_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request_id uuid;
  v_channel text;
  v_event_key text;
  v_event_type text;
  v_provider_message_id text;
  v_status text;
  v_event_id uuid;
begin
  v_request_id := (p_payload->>'request_id')::uuid;
  v_channel := upper(trim(coalesce(p_payload->>'channel','')));
  v_event_key := trim(coalesce(p_payload->>'event_key',''));
  v_event_type := upper(trim(coalesce(p_payload->>'event_type','')));
  v_provider_message_id := nullif(trim(coalesce(p_payload->>'provider_message_id','')),'');
  v_status := nullif(trim(coalesce(p_payload->>'status','')),'');

  if v_channel not in ('WHATSAPP','SMS') or length(v_event_key) not between 8 and 240 or v_event_type='' then
    raise exception 'EVENT_CONTRACT_INVALID' using errcode='22023';
  end if;
  if not exists(select 1 from public.aos_cia_channel_send_requests_v1 r where r.id=v_request_id and r.channel=v_channel) then
    raise exception 'REQUEST_NOT_FOUND' using errcode='23503';
  end if;

  insert into public.aos_cia_channel_send_events_v1(request_id,channel,event_key,event_type,provider_message_id,status,payload,occurred_at)
  values(v_request_id,v_channel,v_event_key,v_event_type,v_provider_message_id,v_status,coalesce(p_payload->'payload','{}'::jsonb),coalesce((p_payload->>'occurred_at')::timestamptz,now()))
  on conflict(event_key) do nothing
  returning id into v_event_id;

  return jsonb_build_object('ok',true,'inserted',v_event_id is not null,'event_id',v_event_id,'event_key',v_event_key);
end
$$;

create or replace function public.aos_cia_channel_set_release_gate_v1(p_gate text,p_value boolean,p_evidence text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_gate text := upper(trim(coalesce(p_gate,'')));
begin
  if v_gate not in ('WHATSAPP_BRIDGE_VALIDATED','OUTBOUND_POLICY_VALIDATED','WEBHOOK_REPLAY_VALIDATED','CANARY_PASSED','ROLLBACK_VERIFIED') then
    raise exception 'UNKNOWN_RELEASE_GATE' using errcode='22023';
  end if;
  if p_value is true and length(trim(coalesce(p_evidence,''))) < 12 then
    raise exception 'RELEASE_EVIDENCE_REQUIRED' using errcode='22023';
  end if;

  update public.aos_cia_channel_release_state
  set whatsapp_bridge_validated = case when v_gate='WHATSAPP_BRIDGE_VALIDATED' then p_value else whatsapp_bridge_validated end,
      outbound_policy_validated = case when v_gate='OUTBOUND_POLICY_VALIDATED' then p_value else outbound_policy_validated end,
      webhook_replay_validated = case when v_gate='WEBHOOK_REPLAY_VALIDATED' then p_value else webhook_replay_validated end,
      canary_passed = case when v_gate='CANARY_PASSED' then p_value else canary_passed end,
      rollback_verified = case when v_gate='ROLLBACK_VERIFIED' then p_value else rollback_verified end,
      evidence = evidence || jsonb_build_object(v_gate,jsonb_build_object('value',p_value,'evidence',coalesce(p_evidence,''),'at',now())),
      updated_at = now()
  where singleton=true;

  return jsonb_build_object('ok',true,'gate',v_gate,'value',p_value);
end
$$;

create or replace function public.aos_cia_f18_readiness_v1()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_f16 jsonb;
  v_state public.aos_cia_channel_release_state%rowtype;
  v_governed integer;
  v_rls integer;
  v_anon_direct boolean;
  v_auth_direct boolean;
  v_illegal integer;
  v_ready boolean;
begin
  v_f16 := public.aos_cia_email_f17_readiness_v1();
  select * into v_state from public.aos_cia_channel_release_state where singleton=true;

  select count(*)::int into v_governed from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname in ('aos_cia_channel_recipient_controls_v1','aos_cia_channel_send_requests_v1','aos_cia_channel_send_events_v1','aos_cia_channel_inbound_facts_v1','aos_cia_channel_release_state') and c.relkind='r';
  select count(*)::int into v_rls from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname in ('aos_cia_channel_recipient_controls_v1','aos_cia_channel_send_requests_v1','aos_cia_channel_send_events_v1','aos_cia_channel_inbound_facts_v1','aos_cia_channel_release_state') and c.relrowsecurity and c.relforcerowsecurity;

  select exists(
    select 1 from (values
      ('aos_cia_channel_recipient_controls_v1'),('aos_cia_channel_send_requests_v1'),('aos_cia_channel_send_events_v1'),('aos_cia_channel_inbound_facts_v1'),('aos_cia_channel_release_state')
    ) t(rel) where has_table_privilege('anon','public.'||rel,'SELECT') or has_table_privilege('anon','public.'||rel,'INSERT') or has_table_privilege('anon','public.'||rel,'UPDATE') or has_table_privilege('anon','public.'||rel,'DELETE')
  ) into v_anon_direct;
  select exists(
    select 1 from (values
      ('aos_cia_channel_recipient_controls_v1'),('aos_cia_channel_send_requests_v1'),('aos_cia_channel_send_events_v1'),('aos_cia_channel_inbound_facts_v1'),('aos_cia_channel_release_state')
    ) t(rel) where has_table_privilege('authenticated','public.'||rel,'SELECT') or has_table_privilege('authenticated','public.'||rel,'INSERT') or has_table_privilege('authenticated','public.'||rel,'UPDATE') or has_table_privilege('authenticated','public.'||rel,'DELETE')
  ) into v_auth_direct;

  select count(*)::int into v_illegal
  from public.aos_cia_channel_send_requests_v1
  where (state in ('READY','DISPATCHING','ACCEPTED') and (consent_status<>'ALLOWED' or suppression_status<>'CLEAR' or eligibility_status<>'ALLOWED'))
     or (eligibility_status='BLOCKED' and state<>'BLOCKED');

  v_ready := coalesce((v_f16->>'ready_for_f17')::boolean,false)
    and v_governed=5 and v_rls=5 and not v_anon_direct and not v_auth_direct and v_illegal=0
    and coalesce(v_state.contracts_active,false)
    and coalesce(v_state.whatsapp_bridge_validated,false)
    and coalesce(v_state.outbound_policy_validated,false)
    and coalesce(v_state.webhook_replay_validated,false)
    and coalesce(v_state.canary_passed,false)
    and coalesce(v_state.rollback_verified,false);

  return jsonb_build_object(
    'ok',true,
    'status',case when v_ready then 'READY_F18_MULTICHANNEL_CERTIFIED' else 'IN_PROGRESS_MULTICHANNEL_GOVERNANCE' end,
    'ready_for_f18',v_ready,
    'f16_ready',coalesce((v_f16->>'ready_for_f17')::boolean,false),
    'governed_tables',v_governed,
    'rls_tables',v_rls,
    'illegal_send_states',v_illegal,
    'browser_direct_table_access',jsonb_build_object('anon',v_anon_direct,'authenticated',v_auth_direct),
    'release_gates',jsonb_build_object(
      'contracts_active',v_state.contracts_active,
      'whatsapp_bridge_validated',v_state.whatsapp_bridge_validated,
      'outbound_policy_validated',v_state.outbound_policy_validated,
      'webhook_replay_validated',v_state.webhook_replay_validated,
      'canary_passed',v_state.canary_passed,
      'rollback_verified',v_state.rollback_verified
    )
  );
end
$$;

-- New governed objects are service-only. No browser direct table/view/function access.
do $$
declare r text;
begin
  foreach r in array array[
    'aos_cia_channel_recipient_controls_v1','aos_cia_channel_send_requests_v1','aos_cia_channel_send_events_v1','aos_cia_channel_inbound_facts_v1','aos_cia_channel_release_state'
  ] loop
    execute format('alter table public.%I enable row level security',r);
    execute format('alter table public.%I force row level security',r);
    execute format('revoke all on table public.%I from public, anon, authenticated',r);
    execute format('grant select,insert,update,delete on table public.%I to service_role',r);
  end loop;
end
$$;

revoke all on table public.aos_cia_whatsapp_bridge_v1 from public, anon, authenticated;
grant select on table public.aos_cia_whatsapp_bridge_v1 to service_role;

revoke all on function public.aos_cia_channel_prepare_send_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_channel_record_event_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_cia_channel_set_release_gate_v1(text,boolean,text) from public, anon, authenticated;
revoke all on function public.aos_cia_f18_readiness_v1() from public, anon, authenticated;
grant execute on function public.aos_cia_channel_prepare_send_v1(jsonb) to service_role;
grant execute on function public.aos_cia_channel_record_event_v1(jsonb) to service_role;
grant execute on function public.aos_cia_channel_set_release_gate_v1(text,boolean,text) to service_role;
grant execute on function public.aos_cia_f18_readiness_v1() to service_role;

comment on table public.aos_cia_channel_send_requests_v1 is 'F17 provider-neutral outbound request ledger. Eligibility/consent/suppression are fail-closed before any adapter dispatch.';
comment on table public.aos_cia_channel_inbound_facts_v1 is 'F17 minimal inbound channel facts linked by canonical contact_key when resolvable; no message body stored here.';
comment on view public.aos_cia_whatsapp_bridge_v1 is 'F17 read-only bridge from existing WA transport facts into canonical CIA identity semantics; excludes message body/raw referral.';
comment on function public.aos_cia_channel_prepare_send_v1(jsonb) is 'F17 service-only idempotent prepare step. Never calls a provider.';
comment on function public.aos_cia_f18_readiness_v1() is 'Authoritative F17-to-F18 readiness; fail-closed until bridge/policy/replay/canary/rollback gates are evidenced.';