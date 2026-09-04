-- WA-L10 A3 — minimum SAFE-OFF canary observability.
--
-- This migration adds evidence only. It DOES NOT create an activation authority,
-- sender, allowlist writer, pricing authority, identity authority or booking path.
-- L4 remains the sole AUTO_OFF/CANARY/PROD state machine. L5-L9 remain canonical.
-- No provider dispatch, browser write, polling, retry, timeout inflation or global
-- synchronous analytical status is introduced.

begin;

create table public.aos_wa_l10_canary_runs_v1 (
  id uuid primary key default gen_random_uuid(),
  run_key text not null unique check (run_key ~ '^[A-Za-z0-9._:-]{16,120}$'),
  pre_fingerprint jsonb not null,
  policy_state text not null check (policy_state in ('VERIFIED_CURRENT','STALE','UNKNOWN','BLOCKED')),
  policy_evidence_ref text not null check (policy_evidence_ref ~ '^[A-Za-z0-9._:/#-]{8,180}$'),
  provider_state text not null check (provider_state in ('VERIFIED_CURRENT','STALE_EVIDENCE','UNKNOWN','BLOCKED')),
  provider_evidence_ref text not null check (provider_evidence_ref ~ '^[A-Za-z0-9._:/#-]{8,180}$'),
  template_state text not null check (template_state in ('VERIFIED_CURRENT','UNKNOWN','BLOCKED')),
  template_evidence_ref text not null check (template_evidence_ref ~ '^[A-Za-z0-9._:/#-]{8,180}$'),
  billing_state text not null check (billing_state in ('VERIFIED_CURRENT','UNKNOWN','BLOCKED')),
  billing_evidence_ref text not null check (billing_evidence_ref ~ '^[A-Za-z0-9._:/#-]{8,180}$'),
  consent_state text not null check (consent_state in ('READY','UNKNOWN','BLOCKED')),
  consent_evidence_ref text not null check (consent_evidence_ref ~ '^[A-Za-z0-9._:/#-]{8,180}$'),
  cohort_method text check (cohort_method is null or cohort_method ~ '^[A-Za-z0-9._:-]{8,120}$'),
  created_by uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.aos_wa_l10_canary_scope_v1 (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.aos_wa_l10_canary_runs_v1(id) on delete restrict,
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  recipient_hash text not null check (recipient_hash ~ '^[a-f0-9]{64}$'),
  scope_reason text not null check (scope_reason ~ '^[A-Za-z0-9._:-]{3,80}$'),
  created_by uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(run_id,conversation_id)
);

create index aos_wa_l10_scope_run_idx
  on public.aos_wa_l10_canary_scope_v1(run_id,created_at,conversation_id);

alter table public.aos_wa_l10_canary_runs_v1 enable row level security;
alter table public.aos_wa_l10_canary_runs_v1 force row level security;
alter table public.aos_wa_l10_canary_scope_v1 enable row level security;
alter table public.aos_wa_l10_canary_scope_v1 force row level security;

revoke all on public.aos_wa_l10_canary_runs_v1 from public,anon,authenticated,service_role;
revoke all on public.aos_wa_l10_canary_scope_v1 from public,anon,authenticated,service_role;
grant select on public.aos_wa_l10_canary_runs_v1 to service_role;
grant select on public.aos_wa_l10_canary_scope_v1 to service_role;

create or replace function public.aos_wa_l10_append_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA_L10_APPEND_ONLY' using errcode='55000';
end
$$;

drop trigger if exists trg_aos_wa_l10_runs_append_guard_v1 on public.aos_wa_l10_canary_runs_v1;
create trigger trg_aos_wa_l10_runs_append_guard_v1
before update or delete on public.aos_wa_l10_canary_runs_v1
for each row execute function public.aos_wa_l10_append_guard_v1();

drop trigger if exists trg_aos_wa_l10_scope_append_guard_v1 on public.aos_wa_l10_canary_scope_v1;
create trigger trg_aos_wa_l10_scope_append_guard_v1
before update or delete on public.aos_wa_l10_canary_scope_v1
for each row execute function public.aos_wa_l10_append_guard_v1();

create or replace function public.aos_wa_l10_prepare_run_v1(
  p_actor_id uuid,
  p_run_key text,
  p_pre_fingerprint jsonb,
  p_policy_state text,
  p_policy_evidence_ref text,
  p_provider_state text,
  p_provider_evidence_ref text,
  p_template_state text,
  p_template_evidence_ref text,
  p_billing_state text,
  p_billing_evidence_ref text,
  p_consent_state text,
  p_consent_evidence_ref text,
  p_cohort_method text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_existing public.aos_wa_l10_canary_runs_v1%rowtype;
  v_row public.aos_wa_l10_canary_runs_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_auto_reply boolean;
  v_ai_send boolean;
  v_auto_routing boolean;
  v_human_send boolean;
  v_allowed_keys text[]:=array[
    'agenda','llamadas','leads','ventas','pacientes','wa_events','wa_messages',
    'wa_l6_journeys','wa_l9_demo_runs','active_allowlist','wa_auto_outbound',
    'wa_auto_decisions','wa_l5_booking_events','wa_l7_ai_cost_events',
    'wa_outbound_requests','wa_l7_meta_cost_events','wa_l9_provider_dispatch'
  ];
  v_policy text:=upper(btrim(coalesce(p_policy_state,'')));
  v_provider text:=upper(btrim(coalesce(p_provider_state,'')));
  v_template text:=upper(btrim(coalesce(p_template_state,'')));
  v_billing text:=upper(btrim(coalesce(p_billing_state,'')));
  v_consent text:=upper(btrim(coalesce(p_consent_state,'')));
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then
    return jsonb_build_object('ok',false,'error','WA_L10_LEVEL1_ADMIN_REQUIRED');
  end if;
  if coalesce(p_run_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return jsonb_build_object('ok',false,'error','WA_L10_RUN_KEY_INVALID');
  end if;
  if p_pre_fingerprint is null or jsonb_typeof(p_pre_fingerprint)<>'object' then
    return jsonb_build_object('ok',false,'error','WA_L10_PRE_FINGERPRINT_INVALID');
  end if;
  if exists(select 1 from unnest(v_allowed_keys) k where not (p_pre_fingerprint ? k))
     or exists(select 1 from jsonb_object_keys(p_pre_fingerprint) k where not (k=any(v_allowed_keys))) then
    return jsonb_build_object('ok',false,'error','WA_L10_PRE_FINGERPRINT_KEYS_INVALID');
  end if;
  if exists(
    select 1 from jsonb_each(p_pre_fingerprint) e
    where jsonb_typeof(e.value)<>'number'
       or (e.value#>>'{}')::numeric<0
       or (e.value#>>'{}')::numeric<>trunc((e.value#>>'{}')::numeric)
  ) then
    return jsonb_build_object('ok',false,'error','WA_L10_PRE_FINGERPRINT_VALUES_INVALID');
  end if;
  if v_policy not in ('VERIFIED_CURRENT','STALE','UNKNOWN','BLOCKED')
     or v_provider not in ('VERIFIED_CURRENT','STALE_EVIDENCE','UNKNOWN','BLOCKED')
     or v_template not in ('VERIFIED_CURRENT','UNKNOWN','BLOCKED')
     or v_billing not in ('VERIFIED_CURRENT','UNKNOWN','BLOCKED')
     or v_consent not in ('READY','UNKNOWN','BLOCKED') then
    return jsonb_build_object('ok',false,'error','WA_L10_READINESS_STATE_INVALID');
  end if;
  if coalesce(p_policy_evidence_ref,'') !~ '^[A-Za-z0-9._:/#-]{8,180}$'
     or coalesce(p_provider_evidence_ref,'') !~ '^[A-Za-z0-9._:/#-]{8,180}$'
     or coalesce(p_template_evidence_ref,'') !~ '^[A-Za-z0-9._:/#-]{8,180}$'
     or coalesce(p_billing_evidence_ref,'') !~ '^[A-Za-z0-9._:/#-]{8,180}$'
     or coalesce(p_consent_evidence_ref,'') !~ '^[A-Za-z0-9._:/#-]{8,180}$' then
    return jsonb_build_object('ok',false,'error','WA_L10_EVIDENCE_REF_INVALID');
  end if;
  if p_cohort_method is not null and p_cohort_method !~ '^[A-Za-z0-9._:-]{8,120}$' then
    return jsonb_build_object('ok',false,'error','WA_L10_COHORT_METHOD_INVALID');
  end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
  into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;

  if v_mode is distinct from 'AUTO_OFF'
     or v_kill is distinct from true
     or v_auto_reply is distinct from false
     or v_ai_send is distinct from false
     or v_auto_routing is distinct from false
     or v_human_send is distinct from true then
    return jsonb_build_object('ok',false,'error','WA_L10_SAFE_OFF_REQUIRED');
  end if;
  if exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.active is true and (a.expires_at is null or a.expires_at>now())
    limit 1
  ) then
    return jsonb_build_object('ok',false,'error','WA_L10_ACTIVE_ALLOWLIST_MUST_BE_EMPTY_DURING_PREP');
  end if;

  select * into v_existing from public.aos_wa_l10_canary_runs_v1 where run_key=p_run_key;
  if v_existing.id is not null then
    if v_existing.pre_fingerprint<>p_pre_fingerprint then
      return jsonb_build_object('ok',false,'error','WA_L10_RUN_KEY_CONFLICT');
    end if;
    return jsonb_build_object(
      'ok',true,'replay',true,'run_id',v_existing.id,'run_key',v_existing.run_key,
      'readiness_complete',(
        v_existing.policy_state='VERIFIED_CURRENT'
        and v_existing.provider_state='VERIFIED_CURRENT'
        and v_existing.template_state='VERIFIED_CURRENT'
        and v_existing.billing_state='VERIFIED_CURRENT'
        and v_existing.consent_state='READY'
      ),
      'activation_authorized',false
    );
  end if;

  insert into public.aos_wa_l10_canary_runs_v1(
    run_key,pre_fingerprint,
    policy_state,policy_evidence_ref,provider_state,provider_evidence_ref,
    template_state,template_evidence_ref,billing_state,billing_evidence_ref,
    consent_state,consent_evidence_ref,cohort_method,created_by
  ) values (
    p_run_key,p_pre_fingerprint,
    v_policy,p_policy_evidence_ref,v_provider,p_provider_evidence_ref,
    v_template,p_template_evidence_ref,v_billing,p_billing_evidence_ref,
    v_consent,p_consent_evidence_ref,p_cohort_method,p_actor_id
  ) returning * into v_row;

  return jsonb_build_object(
    'ok',true,'replay',false,'run_id',v_row.id,'run_key',v_row.run_key,
    'readiness_complete',(
      v_row.policy_state='VERIFIED_CURRENT'
      and v_row.provider_state='VERIFIED_CURRENT'
      and v_row.template_state='VERIFIED_CURRENT'
      and v_row.billing_state='VERIFIED_CURRENT'
      and v_row.consent_state='READY'
    ),
    'activation_authorized',false
  );
end
$$;

create or replace function public.aos_wa_l10_attach_scope_v1(
  p_actor_id uuid,
  p_run_key text,
  p_conversation_id uuid,
  p_recipient_hash text,
  p_scope_reason text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_run public.aos_wa_l10_canary_runs_v1%rowtype;
  v_existing public.aos_wa_l10_canary_scope_v1%rowtype;
  v_row public.aos_wa_l10_canary_scope_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_auto_reply boolean;
  v_ai_send boolean;
  v_auto_routing boolean;
  v_human_send boolean;
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then
    return jsonb_build_object('ok',false,'error','WA_L10_LEVEL1_ADMIN_REQUIRED');
  end if;
  if coalesce(p_recipient_hash,'') !~ '^[a-f0-9]{64}$' then
    return jsonb_build_object('ok',false,'error','WA_L10_RECIPIENT_HASH_REQUIRED');
  end if;
  if coalesce(p_scope_reason,'') !~ '^[A-Za-z0-9._:-]{3,80}$' then
    return jsonb_build_object('ok',false,'error','WA_L10_SCOPE_REASON_INVALID');
  end if;
  select * into v_run from public.aos_wa_l10_canary_runs_v1 where run_key=p_run_key;
  if v_run.id is null then return jsonb_build_object('ok',false,'error','WA_L10_RUN_NOT_FOUND'); end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 where id=p_conversation_id) then
    return jsonb_build_object('ok',false,'error','WA_L10_CONVERSATION_NOT_FOUND');
  end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
  into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;
  if v_mode is distinct from 'AUTO_OFF'
     or v_kill is distinct from true
     or v_auto_reply is distinct from false
     or v_ai_send is distinct from false
     or v_auto_routing is distinct from false
     or v_human_send is distinct from true then
    return jsonb_build_object('ok',false,'error','WA_L10_SAFE_OFF_REQUIRED');
  end if;
  if exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.active is true and (a.expires_at is null or a.expires_at>now())
    limit 1
  ) then
    return jsonb_build_object('ok',false,'error','WA_L10_ACTIVE_ALLOWLIST_MUST_BE_EMPTY_DURING_PREP');
  end if;

  select * into v_existing
  from public.aos_wa_l10_canary_scope_v1
  where run_id=v_run.id and conversation_id=p_conversation_id;
  if v_existing.id is not null then
    if v_existing.recipient_hash<>p_recipient_hash then
      return jsonb_build_object('ok',false,'error','WA_L10_SCOPE_CONFLICT');
    end if;
    return jsonb_build_object('ok',true,'replay',true,'scope_id',v_existing.id,'activation_authorized',false);
  end if;

  insert into public.aos_wa_l10_canary_scope_v1(
    run_id,conversation_id,recipient_hash,scope_reason,created_by
  ) values (
    v_run.id,p_conversation_id,p_recipient_hash,p_scope_reason,p_actor_id
  ) returning * into v_row;

  return jsonb_build_object('ok',true,'replay',false,'scope_id',v_row.id,'activation_authorized',false);
end
$$;

create or replace function public.aos_wa_l10_status_v1(p_run_key text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_run public.aos_wa_l10_canary_runs_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_auto_reply boolean;
  v_ai_send boolean;
  v_auto_routing boolean;
  v_human_send boolean;
  v_auth_ref_present boolean;
  v_scope_count bigint:=0;
  v_scope_allowlist_matches bigint:=0;
  v_any_active_allowlist boolean:=false;
  v_decisions bigint:=0;
  v_allow_decisions bigint:=0;
  v_auto_outbound bigint:=0;
  v_sent bigint:=0;
  v_delivered bigint:=0;
  v_read bigint:=0;
  v_failed bigint:=0;
  v_safe_off boolean:=false;
  v_readiness boolean:=false;
begin
  select * into v_run from public.aos_wa_l10_canary_runs_v1 where run_key=p_run_key;
  if v_run.id is null then return jsonb_build_object('ok',false,'error','WA_L10_RUN_NOT_FOUND'); end if;

  select a.mode,a.kill_switch_engaged,ai.auto_reply_enabled,r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled,(a.authorization_ref is not null)
  into v_mode,v_kill,v_auto_reply,v_ai_send,v_auto_routing,v_human_send,v_auth_ref_present
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;

  select count(*) into v_scope_count
  from public.aos_wa_l10_canary_scope_v1 s where s.run_id=v_run.id;

  select count(*) into v_scope_allowlist_matches
  from public.aos_wa_l10_canary_scope_v1 s
  join public.aos_wa_auto_allowlist_v1 a
    on a.subject_kind='CONVERSATION' and a.subject_key=s.conversation_id::text
   and a.active is true and (a.expires_at is null or a.expires_at>now())
  where s.run_id=v_run.id;

  select exists(
    select 1 from public.aos_wa_auto_allowlist_v1 a
    where a.active is true and (a.expires_at is null or a.expires_at>now())
    limit 1
  ) into v_any_active_allowlist;

  select count(*),count(*) filter(where d.decision='ALLOW')
  into v_decisions,v_allow_decisions
  from public.aos_wa_l10_canary_scope_v1 s
  join public.aos_wa_auto_decisions_v1 d
    on d.conversation_id=s.conversation_id and d.created_at>=v_run.created_at
  where s.run_id=v_run.id;

  select
    count(*) filter(where m.direction='OUTBOUND' and m.send_origin='AUTO'),
    count(*) filter(where m.direction='OUTBOUND' and m.send_origin='AUTO' and m.status='sent'),
    count(*) filter(where m.direction='OUTBOUND' and m.send_origin='AUTO' and m.status='delivered'),
    count(*) filter(where m.direction='OUTBOUND' and m.send_origin='AUTO' and m.status='read'),
    count(*) filter(where m.direction='OUTBOUND' and m.send_origin='AUTO' and m.status='failed')
  into v_auto_outbound,v_sent,v_delivered,v_read,v_failed
  from public.aos_wa_l10_canary_scope_v1 s
  join public.aos_wa_messages_v1 m
    on m.conversation_id=s.conversation_id and m.created_at>=v_run.created_at
  where s.run_id=v_run.id;

  v_safe_off:=(
    v_mode='AUTO_OFF' and v_kill is true and v_auto_reply is false
    and v_ai_send is false and v_auto_routing is false and v_human_send is true
  );
  v_readiness:=(
    v_run.policy_state='VERIFIED_CURRENT'
    and v_run.provider_state='VERIFIED_CURRENT'
    and v_run.template_state='VERIFIED_CURRENT'
    and v_run.billing_state='VERIFIED_CURRENT'
    and v_run.consent_state='READY'
  );

  return jsonb_build_object(
    'ok',true,
    'readback_class','RUN_SCOPED_BOUNDED_V1',
    'run_key',v_run.run_key,
    'run_created_at',v_run.created_at,
    'pre_fingerprint',v_run.pre_fingerprint,
    'policy_state',v_run.policy_state,
    'provider_state',v_run.provider_state,
    'template_state',v_run.template_state,
    'billing_state',v_run.billing_state,
    'consent_state',v_run.consent_state,
    'cohort_method_present',v_run.cohort_method is not null,
    'readiness_complete',v_readiness,
    'mode',v_mode,
    'kill_switch_engaged',v_kill,
    'auto_reply_enabled',v_auto_reply,
    'ai_send_enabled',v_ai_send,
    'auto_routing_enabled',v_auto_routing,
    'human_send_enabled',v_human_send,
    'authorization_ref_present',v_auth_ref_present,
    'safe_off_intact',v_safe_off,
    'any_active_allowlist',v_any_active_allowlist,
    'scope_count',v_scope_count,
    'scope_allowlist_matches',v_scope_allowlist_matches,
    'run_scoped_decisions',v_decisions,
    'run_scoped_allow_decisions',v_allow_decisions,
    'run_scoped_auto_outbound',v_auto_outbound,
    'run_scoped_sent',v_sent,
    'run_scoped_delivered',v_delivered,
    'run_scoped_read',v_read,
    'run_scoped_failed',v_failed,
    'unexpected_auto_outbound_while_auto_off',(v_safe_off and v_auto_outbound>0),
    'activation_authorized',(v_mode in ('CANARY','PROD') and v_auth_ref_present)
  );
end
$$;

revoke all on function public.aos_wa_l10_prepare_run_v1(uuid,text,jsonb,text,text,text,text,text,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_attach_scope_v1(uuid,text,uuid,text,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_status_v1(text) from public,anon,authenticated;
grant execute on function public.aos_wa_l10_prepare_run_v1(uuid,text,jsonb,text,text,text,text,text,text,text,text,text,text,text) to service_role;
grant execute on function public.aos_wa_l10_attach_scope_v1(uuid,text,uuid,text,text) to service_role;
grant execute on function public.aos_wa_l10_status_v1(text) to service_role;

comment on table public.aos_wa_l10_canary_runs_v1 is
  'WA-L10 immutable SAFE-OFF preparation evidence. Readiness snapshot only; grants no send/activation authority.';
comment on table public.aos_wa_l10_canary_scope_v1 is
  'WA-L10 immutable hash-only candidate scope. Does not write the L4 CANARY allowlist and does not authorize dispatch.';
comment on function public.aos_wa_l10_status_v1(text) is
  'WA-L10 bounded run-scoped observability. Reads existing L4 authority + run scope only; no global analytical audit and no activation side effects.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
