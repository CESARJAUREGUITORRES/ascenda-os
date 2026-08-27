-- WA-7A.4 — Marketing Eligibility Foundation V1
-- TEST-first / PROD-ready. No production apply is implied by this migration file.
-- Identity, reachability, attribution and marketing eligibility remain separate authorities.

begin;

create table if not exists public.aos_wa_marketing_eligibility_events_v1 (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique check (length(event_key) between 8 and 240),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  eligibility_scope text not null check (eligibility_scope in ('GLOBAL','MARKETING','UTILITY','AUTHENTICATION','CALL')),
  consent_status text not null check (consent_status in ('UNKNOWN','ALLOWED','DENIED')),
  suppression_status text not null check (suppression_status in ('UNKNOWN','CLEAR','SUPPRESSED')),
  source text not null check (length(source) between 2 and 80),
  source_ref text,
  policy_version text not null default 'WA_7A_4_V1',
  evidence jsonb not null default '{}'::jsonb,
  actor_user_id uuid,
  observed_at timestamptz not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check (consent_status <> 'UNKNOWN' or suppression_status <> 'UNKNOWN'),
  check (expires_at is null or expires_at > observed_at)
);

create index if not exists aos_wa_marketing_eligibility_events_conversation_idx
  on public.aos_wa_marketing_eligibility_events_v1(conversation_id,eligibility_scope,observed_at desc,created_at desc);

alter table public.aos_wa_marketing_eligibility_events_v1 enable row level security;
alter table public.aos_wa_marketing_eligibility_events_v1 force row level security;
revoke all on table public.aos_wa_marketing_eligibility_events_v1 from public,anon,authenticated;
revoke update,delete,truncate,references,trigger on table public.aos_wa_marketing_eligibility_events_v1 from service_role;
grant select,insert on table public.aos_wa_marketing_eligibility_events_v1 to service_role;

create or replace function public.aos_wa7a4_eligibility_immutable_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA7A4_ELIGIBILITY_EVIDENCE_IMMUTABLE' using errcode='55000';
end
$$;
revoke all on function public.aos_wa7a4_eligibility_immutable_guard_v1() from public,anon,authenticated;
grant execute on function public.aos_wa7a4_eligibility_immutable_guard_v1() to service_role;

drop trigger if exists trg_aos_wa7a4_eligibility_immutable_guard_v1 on public.aos_wa_marketing_eligibility_events_v1;
create trigger trg_aos_wa7a4_eligibility_immutable_guard_v1
before update or delete on public.aos_wa_marketing_eligibility_events_v1
for each row execute function public.aos_wa7a4_eligibility_immutable_guard_v1();

create or replace function public.aos_wa_marketing_eligibility_record_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_conversation_id uuid;
  v_event_key text := trim(coalesce(p_payload->>'event_key',''));
  v_scope text := upper(trim(coalesce(p_payload->>'eligibility_scope','')));
  v_consent text := upper(trim(coalesce(p_payload->>'consent_status','UNKNOWN')));
  v_suppression text := upper(trim(coalesce(p_payload->>'suppression_status','UNKNOWN')));
  v_source text := upper(trim(coalesce(p_payload->>'source','')));
  v_source_ref text := nullif(trim(coalesce(p_payload->>'source_ref','')),'');
  v_policy_version text := upper(trim(coalesce(p_payload->>'policy_version','WA_7A_4_V1')));
  v_evidence jsonb := coalesce(p_payload->'evidence','{}'::jsonb);
  v_actor_user_id uuid;
  v_observed_at timestamptz;
  v_expires_at timestamptz;
  v_existing public.aos_wa_marketing_eligibility_events_v1%rowtype;
  v_prior public.aos_wa_marketing_eligibility_events_v1%rowtype;
  v_id uuid;
begin
  if nullif(p_payload->>'conversation_id','') is null then raise exception 'WA7A4_CONVERSATION_REQUIRED' using errcode='22023'; end if;
  v_conversation_id := (p_payload->>'conversation_id')::uuid;
  if not exists(select 1 from public.aos_wa_conversations_v1 c where c.id=v_conversation_id) then raise exception 'WA7A4_CONVERSATION_NOT_FOUND' using errcode='23503'; end if;
  if length(v_event_key) not between 8 and 240 then raise exception 'WA7A4_EVENT_KEY_INVALID' using errcode='22023'; end if;
  if v_scope not in ('GLOBAL','MARKETING','UTILITY','AUTHENTICATION','CALL') then raise exception 'WA7A4_SCOPE_INVALID' using errcode='22023'; end if;
  if v_consent not in ('UNKNOWN','ALLOWED','DENIED') or v_suppression not in ('UNKNOWN','CLEAR','SUPPRESSED') then raise exception 'WA7A4_STATE_INVALID' using errcode='22023'; end if;
  if v_consent='UNKNOWN' and v_suppression='UNKNOWN' then raise exception 'WA7A4_EMPTY_DECISION' using errcode='22023'; end if;
  if length(v_source) not between 2 and 80 then raise exception 'WA7A4_SOURCE_REQUIRED' using errcode='22023'; end if;
  if nullif(p_payload->>'observed_at','') is null then raise exception 'WA7A4_OBSERVED_AT_REQUIRED' using errcode='22023'; end if;
  v_observed_at := (p_payload->>'observed_at')::timestamptz;
  if nullif(p_payload->>'expires_at','') is not null then v_expires_at := (p_payload->>'expires_at')::timestamptz; end if;
  if v_expires_at is not null and v_expires_at <= v_observed_at then raise exception 'WA7A4_EXPIRY_INVALID' using errcode='22023'; end if;
  if nullif(p_payload->>'actor_user_id','') is not null then v_actor_user_id := (p_payload->>'actor_user_id')::uuid; end if;

  -- Attribution/channel facts never grant consent by themselves.
  if v_consent='ALLOWED' and v_source in ('ATTRIBUTION','CTWA','TOUCHPOINT','PHONE','BSUID','USERNAME','MESSAGE_RECEIPT') then
    raise exception 'WA7A4_SOURCE_CANNOT_GRANT_CONSENT' using errcode='42501';
  end if;

  select * into v_existing from public.aos_wa_marketing_eligibility_events_v1 where event_key=v_event_key;
  if v_existing.id is not null then
    if v_existing.conversation_id=v_conversation_id
       and v_existing.eligibility_scope=v_scope
       and v_existing.consent_status=v_consent
       and v_existing.suppression_status=v_suppression
       and v_existing.source=v_source
       and coalesce(v_existing.source_ref,'')=coalesce(v_source_ref,'')
       and v_existing.policy_version=v_policy_version
       and v_existing.evidence=v_evidence
       and v_existing.observed_at=v_observed_at
       and v_existing.expires_at is not distinct from v_expires_at then
      return jsonb_build_object('ok',true,'idempotent',true,'event_id',v_existing.id,'event_key',v_existing.event_key);
    end if;
    raise exception 'WA7A4_REPLAY_CONFLICT' using errcode='23505';
  end if;

  select * into v_prior
  from public.aos_wa_marketing_eligibility_events_v1
  where conversation_id=v_conversation_id and eligibility_scope=v_scope
  order by observed_at desc,created_at desc limit 1;

  -- A previous explicit denial/suppression cannot be silently cleared.
  if v_prior.id is not null
     and (v_prior.consent_status='DENIED' or v_prior.suppression_status='SUPPRESSED')
     and (v_consent='ALLOWED' or v_suppression='CLEAR')
     and coalesce((v_evidence->>'explicit_reconsent')::boolean,false) is not true then
    raise exception 'WA7A4_EXPLICIT_RECONSENT_REQUIRED' using errcode='42501';
  end if;

  insert into public.aos_wa_marketing_eligibility_events_v1(
    event_key,conversation_id,eligibility_scope,consent_status,suppression_status,
    source,source_ref,policy_version,evidence,actor_user_id,observed_at,expires_at
  ) values (
    v_event_key,v_conversation_id,v_scope,v_consent,v_suppression,
    v_source,v_source_ref,v_policy_version,v_evidence,v_actor_user_id,v_observed_at,v_expires_at
  ) returning id into v_id;

  return jsonb_build_object('ok',true,'idempotent',false,'event_id',v_id,'event_key',v_event_key);
end
$$;

revoke all on function public.aos_wa_marketing_eligibility_record_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_wa_marketing_eligibility_record_v1(jsonb) to service_role;

create or replace view public.aos_wa_marketing_eligibility_v1
with (security_invoker=true,security_barrier=true)
as
with scopes(scope) as (
  values ('MARKETING'::text),('UTILITY'::text),('AUTHENTICATION'::text),('CALL'::text)
), latest as (
  select distinct on (e.conversation_id,e.eligibility_scope)
    e.*
  from public.aos_wa_marketing_eligibility_events_v1 e
  order by e.conversation_id,e.eligibility_scope,e.observed_at desc,e.created_at desc
), base as (
  select c.id as conversation_id,s.scope as eligibility_scope,
    g.consent_status as g_consent_raw,g.suppression_status as g_suppression_raw,g.source as g_source,g.event_key as g_event_key,g.expires_at as g_expires_at,
    e.consent_status as s_consent_raw,e.suppression_status as s_suppression_raw,e.source as s_source,e.event_key as s_event_key,e.expires_at as s_expires_at,
    coalesce((select count(*) from public.aos_wa_channel_aliases_v1 a where a.conversation_id=c.id and a.active is true and a.alias_type in ('PHONE','BSUID','PARENT_BSUID')),0)::int as reachability_alias_count,
    (select public.aos_cia_normalize_contact_key_v1(a.alias_value) from public.aos_wa_channel_aliases_v1 a where a.conversation_id=c.id and a.active is true and a.alias_type='PHONE' order by a.last_seen_at desc limit 1) as cia_contact_key
  from public.aos_wa_conversations_v1 c
  cross join scopes s
  left join latest g on g.conversation_id=c.id and g.eligibility_scope='GLOBAL'
  left join latest e on e.conversation_id=c.id and e.eligibility_scope=s.scope
), effective as (
  select b.*,
    case when g_expires_at is not null and g_expires_at<=now() then 'UNKNOWN' else coalesce(g_consent_raw,'UNKNOWN') end as g_consent,
    case when g_expires_at is not null and g_expires_at<=now() then 'UNKNOWN' else coalesce(g_suppression_raw,'UNKNOWN') end as g_suppression,
    case when s_expires_at is not null and s_expires_at<=now() then 'UNKNOWN' else coalesce(s_consent_raw,'UNKNOWN') end as s_consent,
    case when s_expires_at is not null and s_expires_at<=now() then 'UNKNOWN' else coalesce(s_suppression_raw,'UNKNOWN') end as s_suppression
  from base b
), guarded as (
  select e.*,
    c.consent_status as cia_consent_status,c.suppression_status as cia_suppression_status,c.source as cia_source,c.expires_at as cia_expires_at
  from effective e
  left join public.aos_cia_channel_recipient_controls_v1 c
    on c.contact_key=e.cia_contact_key and c.channel='WHATSAPP'
)
select
  conversation_id,eligibility_scope,
  case when reachability_alias_count>0 then 'REACHABLE' else 'UNREACHABLE' end::text as reachability_status,
  reachability_alias_count,
  case
    when g_consent='DENIED' or s_consent='DENIED' then 'DENIED'
    when s_consent='ALLOWED' then 'ALLOWED'
    when g_consent='ALLOWED' then 'ALLOWED'
    else 'UNKNOWN'
  end::text as consent_status,
  case
    when g_suppression='SUPPRESSED' or s_suppression='SUPPRESSED' then 'SUPPRESSED'
    when s_suppression='CLEAR' and s_consent='ALLOWED' then 'CLEAR'
    when g_suppression='CLEAR' and g_consent='ALLOWED' then 'CLEAR'
    else 'UNKNOWN'
  end::text as suppression_status,
  case
    when reachability_alias_count=0 then 'NOT_ELIGIBLE'
    when g_suppression='SUPPRESSED' or s_suppression='SUPPRESSED' then 'NOT_ELIGIBLE'
    when g_consent='DENIED' or s_consent='DENIED' then 'NOT_ELIGIBLE'
    when cia_expires_at is null or cia_expires_at>now() then
      case when cia_suppression_status='SUPPRESSED' or cia_consent_status='DENIED' then 'NOT_ELIGIBLE'
           when ((s_consent='ALLOWED' and s_suppression='CLEAR') or (s_consent='UNKNOWN' and g_consent='ALLOWED' and g_suppression='CLEAR')) then 'ELIGIBLE'
           else 'UNKNOWN' end
    when ((s_consent='ALLOWED' and s_suppression='CLEAR') or (s_consent='UNKNOWN' and g_consent='ALLOWED' and g_suppression='CLEAR')) then 'ELIGIBLE'
    else 'UNKNOWN'
  end::text as eligibility_status,
  case
    when reachability_alias_count=0 then 'UNREACHABLE'
    when g_suppression='SUPPRESSED' or s_suppression='SUPPRESSED' then 'WA_SUPPRESSED'
    when g_consent='DENIED' or s_consent='DENIED' then 'WA_DENIED'
    when (cia_expires_at is null or cia_expires_at>now()) and cia_suppression_status='SUPPRESSED' then 'CIA_SUPPRESSED'
    when (cia_expires_at is null or cia_expires_at>now()) and cia_consent_status='DENIED' then 'CIA_DENIED'
    when ((s_consent='ALLOWED' and s_suppression='CLEAR') or (s_consent='UNKNOWN' and g_consent='ALLOWED' and g_suppression='CLEAR')) then 'ELIGIBLE_EXPLICIT'
    else 'CONSENT_UNKNOWN'
  end::text as reason_code,
  g_event_key as global_event_key,s_event_key as scope_event_key,
  g_source as global_source,s_source as scope_source,
  cia_contact_key,cia_consent_status,cia_suppression_status,cia_source,
  (
    reachability_alias_count>0
    and not (g_suppression='SUPPRESSED' or s_suppression='SUPPRESSED' or g_consent='DENIED' or s_consent='DENIED')
    and not ((cia_expires_at is null or cia_expires_at>now()) and (cia_suppression_status='SUPPRESSED' or cia_consent_status='DENIED'))
    and ((s_consent='ALLOWED' and s_suppression='CLEAR') or (s_consent='UNKNOWN' and g_consent='ALLOWED' and g_suppression='CLEAR'))
  )::boolean as send_allowed
from guarded;

revoke all on public.aos_wa_marketing_eligibility_v1 from public,anon,authenticated;
grant select on public.aos_wa_marketing_eligibility_v1 to service_role;

create or replace function public.aos_wa_marketing_eligibility_check_v1(p_conversation_id uuid,p_scope text default 'MARKETING')
returns jsonb
language plpgsql
security definer
stable
set search_path='public','pg_temp'
as $$
declare
  v_scope text := upper(trim(coalesce(p_scope,'MARKETING')));
  v_row record;
begin
  if v_scope not in ('MARKETING','UTILITY','AUTHENTICATION','CALL') then raise exception 'WA7A4_SCOPE_INVALID' using errcode='22023'; end if;
  select * into v_row from public.aos_wa_marketing_eligibility_v1 where conversation_id=p_conversation_id and eligibility_scope=v_scope;
  if v_row.conversation_id is null then raise exception 'WA7A4_CONVERSATION_NOT_FOUND' using errcode='23503'; end if;
  return jsonb_build_object(
    'conversation_id',v_row.conversation_id,'eligibility_scope',v_row.eligibility_scope,
    'reachability_status',v_row.reachability_status,'consent_status',v_row.consent_status,
    'suppression_status',v_row.suppression_status,'eligibility_status',v_row.eligibility_status,
    'reason_code',v_row.reason_code,'send_allowed',v_row.send_allowed
  );
end
$$;
revoke all on function public.aos_wa_marketing_eligibility_check_v1(uuid,text) from public,anon,authenticated;
grant execute on function public.aos_wa_marketing_eligibility_check_v1(uuid,text) to service_role;

comment on table public.aos_wa_marketing_eligibility_events_v1 is 'WA-7A.4 immutable, conversation-scoped eligibility evidence. Not identity, reachability or attribution authority.';
comment on view public.aos_wa_marketing_eligibility_v1 is 'WA-7A.4 current fail-closed eligibility projection. CIA recipient controls can suppress/deny but never grant WhatsApp consent.';
comment on function public.aos_wa_marketing_eligibility_record_v1(jsonb) is 'WA-7A.4 service-only append-only evidence recorder with replay conflict and explicit re-consent guard.';
comment on function public.aos_wa_marketing_eligibility_check_v1(uuid,text) is 'WA-7A.4 service-only eligibility check; send_allowed requires reachability + explicit allowed/clear evidence and no suppression.';

select pg_notify('pgrst','reload schema');
commit;
