-- WA-L8 — Security Gate for Autonomous Canary + Meta 2026 pricing/policy hardening
-- Additive security release. Installs policy/preflight authority while production remains SAFE-OFF.
-- No CANARY transition, no synthetic provider rates, no business-ledger mutation.

begin;

-- ---------------------------------------------------------------------------
-- 1. Meta pricing evidence / market-aware reconciliation
-- ---------------------------------------------------------------------------
-- Meta message prices are recipient-market specific. GLOBAL remains valid for AI
-- providers, but must not be accepted as authoritative Meta-message pricing.
alter table public.aos_wa_l7_pricing_authority_v1
  add constraint aos_wa_l8_meta_market_specific_ck
  check (provider<>'META_WHATSAPP' or market_code<>'GLOBAL');

-- `pricing.type` is provider evidence (for example free-service/free-entry semantics)
-- carried by sanitized message.status events. It is intentionally not added to the
-- hot message row: no new synchronous enrichment write is introduced.
create or replace view public.aos_wa_l8_meta_pricing_evidence_v1
with (security_invoker=true,security_barrier=true)
as
select
  m.id as message_id,
  m.provider_message_id,
  m.conversation_id,
  m.phone_number_id as business_phone_number_id,
  coalesce(m.delivered_at,m.sent_at,m.provider_timestamp,m.created_at) as cost_event_at,
  m.pricing_category,
  m.pricing_model,
  m.billable,
  pe.pricing_type,
  case
    when m.to_number ~ '^51[0-9]{8,12}$' then 'PE'
    when m.to_number is not null then 'UNMAPPED'
    else 'UNRESOLVED'
  end::text as billing_market_code
from public.aos_wa_messages_v1 m
left join lateral (
  select nullif(pg_catalog.btrim(e.payload->>'pricing_type'),'') as pricing_type
  from public.aos_wa_events_v1 e
  where e.provider_message_id=m.provider_message_id
    and e.event_type='message.status'
    and nullif(pg_catalog.btrim(e.payload->>'pricing_type'),'') is not null
  order by e.created_at desc
  limit 1
) pe on true
where m.direction='OUTBOUND';

revoke all on public.aos_wa_l8_meta_pricing_evidence_v1 from public,anon,authenticated;
grant select on public.aos_wa_l8_meta_pricing_evidence_v1 to service_role;

-- Preserve every existing L7 column in the same order, then append L8 evidence.
create or replace view public.aos_wa_l7_meta_cost_events_v1
with (security_invoker=true,security_barrier=true)
as
select
  e.message_id,
  e.provider_message_id,
  e.conversation_id,
  e.cost_event_at,
  e.pricing_category,
  e.pricing_model,
  e.billable,
  r.id as pricing_authority_id,
  r.authority_grade,
  r.evidence_ref as pricing_evidence_ref,
  case
    when e.billable is false then 'KNOWN'
    when e.billable is true and r.id is not null and r.authority_grade='VERIFIED' then 'KNOWN'
    when e.billable is true and r.id is not null then 'PARTIAL'
    else 'UNKNOWN'
  end::text as cost_state,
  case
    when e.billable is false then 'PROVIDER_NON_BILLABLE'
    when e.billable is true and (e.pricing_category is null or e.pricing_model is null) then 'PROVIDER_PRICING_METADATA_INCOMPLETE'
    when e.billable is true and e.billing_market_code in ('UNMAPPED','UNRESOLVED') then 'PROVIDER_MARKET_UNRESOLVED'
    when e.billable is true and r.id is null then 'VERIFIED_RATE_NOT_FOUND'
    when r.authority_grade='LEGACY_ESTIMATE' then 'LEGACY_ESTIMATE_RATE'
    else 'VERIFIED_PROVIDER_RATE'
  end::text as cost_reason,
  case
    when e.billable is false then 0::numeric
    when e.billable is true and r.id is not null then r.flat_cost
    else null::numeric
  end as cost_amount,
  case
    when e.billable is true and r.id is not null then r.currency
    else null::text
  end as cost_currency,
  e.pricing_type,
  e.billing_market_code,
  e.business_phone_number_id
from public.aos_wa_l8_meta_pricing_evidence_v1 e
left join lateral (
  select p.*
  from public.aos_wa_l7_pricing_authority_v1 p
  where p.provider='META_WHATSAPP'
    and p.pricing_kind='META_MESSAGE'
    and pg_catalog.lower(p.pricing_model)=pg_catalog.lower(coalesce(e.pricing_model,''))
    and pg_catalog.lower(coalesce(p.pricing_category,''))=pg_catalog.lower(coalesce(e.pricing_category,''))
    and p.market_code=e.billing_market_code
    and e.billing_market_code not in ('UNMAPPED','UNRESOLVED')
    and p.valid_from<=e.cost_event_at
    and (p.valid_to is null or e.cost_event_at<p.valid_to)
  order by p.valid_from desc,p.created_at desc
  limit 1
) r on e.billable is true;

revoke all on public.aos_wa_l7_meta_cost_events_v1 from public,anon,authenticated;
grant select on public.aos_wa_l7_meta_cost_events_v1 to service_role;

-- Invoice/reconciliation observability. This deliberately reports provider-observed
-- billable/non-billable counts and does NOT hardcode a monthly free allowance.
-- A free-tier entitlement becomes a forecast rule only after WABA/account evidence
-- is loaded through a separately governed authority.
create or replace view public.aos_wa_l8_meta_monthly_usage_v1
with (security_invoker=true,security_barrier=true)
as
select
  e.business_phone_number_id,
  (pg_catalog.date_trunc('month',e.cost_event_at at time zone 'UTC'))::date as billing_month_utc,
  e.billing_market_code,
  e.pricing_category,
  e.pricing_model,
  e.pricing_type,
  pg_catalog.count(*)::bigint as outbound_messages,
  pg_catalog.count(*) filter(where e.billable is true)::bigint as provider_billable_messages,
  pg_catalog.count(*) filter(where e.billable is false)::bigint as provider_nonbillable_messages,
  pg_catalog.count(*) filter(where e.cost_state='KNOWN')::bigint as known_cost_events,
  pg_catalog.count(*) filter(where e.cost_state='PARTIAL')::bigint as partial_cost_events,
  pg_catalog.count(*) filter(where e.cost_state='UNKNOWN')::bigint as unknown_cost_events,
  pg_catalog.sum(e.cost_amount) filter(where e.cost_state='KNOWN') as known_cost_amount,
  case
    when pg_catalog.count(distinct e.cost_currency) filter(where e.cost_amount<>0 and e.cost_currency is not null)=1
      then pg_catalog.max(e.cost_currency) filter(where e.cost_amount<>0 and e.cost_currency is not null)
    else null::text
  end as known_cost_currency
from public.aos_wa_l7_meta_cost_events_v1 e
group by e.business_phone_number_id,(pg_catalog.date_trunc('month',e.cost_event_at at time zone 'UTC'))::date,
         e.billing_market_code,e.pricing_category,e.pricing_model,e.pricing_type;

revoke all on public.aos_wa_l8_meta_monthly_usage_v1 from public,anon,authenticated;
grant select on public.aos_wa_l8_meta_monthly_usage_v1 to service_role;

-- ---------------------------------------------------------------------------
-- 2. Consent / opt-out evidence and autonomous policy preflight
-- ---------------------------------------------------------------------------
create table public.aos_wa_l8_consent_events_v1 (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  recipient_kind text not null check (recipient_kind in ('PHONE','BSUID')),
  recipient_hash text not null check (recipient_hash ~ '^[a-f0-9]{64}$'),
  action text not null check (action in ('OPT_IN','OPT_OUT')),
  source text not null check (source in ('ADMIN_EVIDENCE','CUSTOMER_REQUEST','PRIVACY_FORM','OTHER_VERIFIED')),
  evidence_ref text not null check (char_length(btrim(evidence_ref)) between 8 and 1000),
  actor_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index aos_wa_l8_consent_recipient_idx
  on public.aos_wa_l8_consent_events_v1(recipient_hash,created_at desc);
create index aos_wa_l8_consent_conversation_idx
  on public.aos_wa_l8_consent_events_v1(conversation_id,created_at desc);

alter table public.aos_wa_l8_consent_events_v1 enable row level security;
alter table public.aos_wa_l8_consent_events_v1 force row level security;
revoke all on public.aos_wa_l8_consent_events_v1 from public,anon,authenticated;
grant select,insert on public.aos_wa_l8_consent_events_v1 to service_role;

create or replace function public.aos_wa_l8_append_guard_v1()
returns trigger language plpgsql set search_path='' as $$
begin
  raise exception 'WA_L8_APPEND_ONLY' using errcode='55000';
end
$$;

drop trigger if exists trg_aos_wa_l8_consent_append_guard_v1 on public.aos_wa_l8_consent_events_v1;
create trigger trg_aos_wa_l8_consent_append_guard_v1
before update or delete on public.aos_wa_l8_consent_events_v1
for each row execute function public.aos_wa_l8_append_guard_v1();

create table public.aos_wa_l8_preflight_decisions_v1 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique check (idempotency_key ~ '^[A-Za-z0-9._:-]{16,120}$'),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  recipient_hash text not null check (recipient_hash ~ '^[a-f0-9]{64}$'),
  message_type text not null,
  template_name text,
  decision text not null check (decision in ('PASS','BLOCK','HANDOFF')),
  reason_code text not null,
  service_window_open boolean not null default false,
  last_inbound_at timestamptz,
  latest_stop_at timestamptz,
  consent_action text,
  consent_at timestamptz,
  created_at timestamptz not null default now()
);
create index aos_wa_l8_preflight_conversation_idx
  on public.aos_wa_l8_preflight_decisions_v1(conversation_id,created_at desc);

alter table public.aos_wa_l8_preflight_decisions_v1 enable row level security;
alter table public.aos_wa_l8_preflight_decisions_v1 force row level security;
revoke all on public.aos_wa_l8_preflight_decisions_v1 from public,anon,authenticated;
grant select,insert on public.aos_wa_l8_preflight_decisions_v1 to service_role;

drop trigger if exists trg_aos_wa_l8_preflight_append_guard_v1 on public.aos_wa_l8_preflight_decisions_v1;
create trigger trg_aos_wa_l8_preflight_append_guard_v1
before update or delete on public.aos_wa_l8_preflight_decisions_v1
for each row execute function public.aos_wa_l8_append_guard_v1();

create or replace function public.aos_wa_l8_consent_record_v1(
  p_token text,
  p_conversation_id uuid,
  p_action text,
  p_source text,
  p_evidence_ref text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_action text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_action,'')));
  v_source text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_source,'')));
  v_evidence text:=nullif(pg_catalog.btrim(coalesce(p_evidence_ref,'')),'');
  v_hash text;
  v_id uuid;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-whatsapp',true);
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_ADMIN_2FA_REQUIRED'); end if;
  if v_action not in ('OPT_IN','OPT_OUT') then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_ACTION_INVALID'); end if;
  if v_source not in ('ADMIN_EVIDENCE','CUSTOMER_REQUEST','PRIVACY_FORM','OTHER_VERIFIED') then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_SOURCE_INVALID'); end if;
  if v_evidence is null or pg_catalog.length(v_evidence) not between 8 and 1000 then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONSENT_EVIDENCE_REQUIRED'); end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if v_conv.id is null then return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.contact_address_type not in ('PHONE','BSUID') or nullif(pg_catalog.btrim(coalesce(v_conv.contact_address,'')),'') is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L8_RECIPIENT_UNRESOLVED');
  end if;

  v_hash:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_conv.contact_address_type||':'||v_conv.contact_address,'UTF8'),'sha256'),'hex');
  insert into public.aos_wa_l8_consent_events_v1(conversation_id,recipient_kind,recipient_hash,action,source,evidence_ref,actor_id)
  values(v_conv.id,v_conv.contact_address_type,v_hash,v_action,v_source,v_evidence,v_actor)
  returning id into v_id;

  return pg_catalog.jsonb_build_object('ok',true,'status','APPENDED','consent_event_id',v_id,'conversation_id',v_conv.id,'action',v_action,'source',v_source);
end
$$;

create or replace function public.aos_wa_l8_autonomous_preflight_v1(
  p_conversation_id uuid,
  p_recipient_kind text,
  p_recipient_address text,
  p_message_type text,
  p_template_name text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_kind text:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_recipient_kind,'')));
  v_address text:=public.aos_wa_l4_normalize_subject_v1(v_kind,p_recipient_address);
  v_type text:=pg_catalog.lower(pg_catalog.btrim(coalesce(p_message_type,'')));
  v_template text:=nullif(pg_catalog.btrim(coalesce(p_template_name,'')),'');
  v_hash text;
  v_existing public.aos_wa_l8_preflight_decisions_v1%rowtype;
  v_last_inbound timestamptz;
  v_stop_at timestamptz;
  v_consent_action text;
  v_consent_at timestamptz;
  v_window boolean:=false;
  v_decision text:='PASS';
  v_reason text:='WA_L8_SERVICE_WINDOW_OK';
  v_id uuid;
begin
  if coalesce(p_idempotency_key,'') !~ '^[A-Za-z0-9._:-]{16,120}$' then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_IDEMPOTENCY_KEY');
  end if;
  select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
  if v_existing.id is not null then
    return pg_catalog.jsonb_build_object('ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,'service_window_open',v_existing.service_window_open);
  end if;

  if v_kind not in ('PHONE','BSUID') or v_address is null then
    return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_INVALID_RECIPIENT');
  end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if v_conv.id is null then return pg_catalog.jsonb_build_object('ok',false,'decision','BLOCK','reason','WA_L8_CONVERSATION_NOT_FOUND'); end if;
  v_hash:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(v_kind||':'||v_address,'UTF8'),'sha256'),'hex');

  select pg_catalog.max(coalesce(m.provider_timestamp,m.received_at,m.created_at))
    into v_last_inbound
  from public.aos_wa_messages_v1 m
  where m.conversation_id=p_conversation_id and m.direction='INBOUND';

  select pg_catalog.max(coalesce(m.provider_timestamp,m.received_at,m.created_at))
    into v_stop_at
  from public.aos_wa_messages_v1 m
  where m.conversation_id=p_conversation_id and m.direction='INBOUND'
    and pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.translate(pg_catalog.lower(pg_catalog.btrim(coalesce(m.message_body,''))),'áéíóúüñ','aeiouun'),
            '[[:punct:]]',' ','g'),
          '[[:space:]]+',' ','g')
        ~ '^(stop|baja|cancelar suscripcion|no quiero mensajes|no me escriban|no mas mensajes)$';

  select c.action,c.created_at into v_consent_action,v_consent_at
  from public.aos_wa_l8_consent_events_v1 c
  where c.recipient_hash=v_hash
  order by c.created_at desc
  limit 1;

  v_window:=(v_last_inbound is not null and v_last_inbound>=pg_catalog.now()-interval '24 hours');

  if v_conv.contact_address_type<>v_kind or v_conv.contact_address<>v_address then
    v_decision:='HANDOFF';v_reason:='WA_L8_RECIPIENT_CONVERSATION_MISMATCH';
  elsif (v_consent_action='OPT_OUT' and (v_stop_at is null or v_consent_at>=v_stop_at))
     or (v_stop_at is not null and (v_consent_at is null or v_consent_action<>'OPT_IN' or v_consent_at<=v_stop_at)) then
    v_decision:='BLOCK';v_reason:='WA_L8_OPT_OUT_ACTIVE';
  elsif v_window then
    v_decision:='PASS';v_reason:='WA_L8_SERVICE_WINDOW_OK';
  elsif v_type<>'template' or v_template is null then
    v_decision:='BLOCK';v_reason:='WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H';
  elsif v_consent_action='OPT_IN' and (v_stop_at is null or v_consent_at>v_stop_at) then
    v_decision:='PASS';v_reason:='WA_L8_BUSINESS_INITIATED_OPT_IN_OK';
  else
    v_decision:='BLOCK';v_reason:='WA_L8_BUSINESS_INITIATED_OPT_IN_REQUIRED';
  end if;

  begin
    insert into public.aos_wa_l8_preflight_decisions_v1(
      idempotency_key,conversation_id,recipient_hash,message_type,template_name,decision,reason_code,
      service_window_open,last_inbound_at,latest_stop_at,consent_action,consent_at)
    values(p_idempotency_key,p_conversation_id,v_hash,v_type,v_template,v_decision,v_reason,
      v_window,v_last_inbound,v_stop_at,v_consent_action,v_consent_at)
    returning id into v_id;
  exception when unique_violation then
    select * into v_existing from public.aos_wa_l8_preflight_decisions_v1 where idempotency_key=p_idempotency_key;
    return pg_catalog.jsonb_build_object('ok',v_existing.decision='PASS','replay',true,'preflight_id',v_existing.id,
      'decision',v_existing.decision,'reason',v_existing.reason_code,'service_window_open',v_existing.service_window_open);
  end;

  return pg_catalog.jsonb_build_object('ok',v_decision='PASS','replay',false,'preflight_id',v_id,'decision',v_decision,
    'reason',v_reason,'service_window_open',v_window,'last_inbound_at',v_last_inbound,
    'consent_action',v_consent_action,'consent_at',v_consent_at,'latest_stop_at',v_stop_at);
end
$$;

-- Wrap the already-certified L4 authority instead of duplicating/reimplementing it.
-- Server/runtime continues to call the same public function signature.
alter function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)
  rename to aos_wa_l4_authorize_autonomous_send_pre_l8_v1;

revoke all on function public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) to service_role;

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
  v_pre jsonb;
  v_l4 jsonb;
  v_decision text;
begin
  v_pre:=public.aos_wa_l8_autonomous_preflight_v1(
    p_conversation_id,p_recipient_kind,p_recipient_address,p_message_type,p_template_name,p_idempotency_key
  );
  v_decision:=coalesce(v_pre->>'decision','BLOCK');
  if v_decision<>'PASS' then
    return pg_catalog.jsonb_build_object(
      'ok',false,'decision',case when v_decision='HANDOFF' then 'HANDOFF' else 'BLOCK' end,
      'reason',coalesce(v_pre->>'reason','WA_L8_PREFLIGHT_BLOCKED'),
      'l8_preflight_id',v_pre->>'preflight_id','l8_preflight',v_decision,'l8',v_pre
    );
  end if;

  v_l4:=public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1(
    p_conversation_id,p_recipient_kind,p_recipient_address,p_message_type,p_template_name,p_idempotency_key,
    p_content_hash,p_safety_action,p_identity_state,p_requires_identity,p_campaign_key
  );
  return coalesce(v_l4,'{}'::jsonb)||pg_catalog.jsonb_build_object(
    'l8_preflight_id',v_pre->>'preflight_id','l8_preflight','PASS'
  );
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Least privilege on the exact autonomous path only
-- ---------------------------------------------------------------------------
-- Gateway needs SELECT/INSERT/UPDATE on messages/outbound reservation; it never
-- needs destructive/table-management privileges.
revoke delete,truncate,references,trigger on public.aos_wa_messages_v1 from service_role;
revoke delete,truncate,references,trigger on public.aos_wa_outbound_requests_v1 from service_role;
revoke delete,truncate,references,trigger on public.aos_wa_conversations_v1 from service_role;

-- AI run ledger is append-only metadata. Booking operations are written by the
-- certified SECURITY DEFINER booking core; direct service-role DML is unnecessary.
revoke update,delete,truncate,references,trigger on public.aos_wa_ai_runs_v1 from service_role;
revoke insert,update,delete,truncate,references,trigger on public.aos_booking_operations_v2 from service_role;
grant select on public.aos_booking_operations_v2 to service_role;

-- L8 functions are server-side except the authenticated consent-admin RPC, whose
-- own token+2FA check remains authoritative.
revoke all on function public.aos_wa_l8_append_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l8_consent_record_v1(text,uuid,text,text,text) from public;
grant execute on function public.aos_wa_l8_append_guard_v1() to service_role;
grant execute on function public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text) to service_role;
grant execute on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) to service_role;
grant execute on function public.aos_wa_l8_consent_record_v1(text,uuid,text,text,text) to anon,authenticated,service_role;

-- Security/readback surface; no PII or raw content is returned.
create or replace function public.aos_wa_l8_security_status_v1()
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
    'consent_events',(select pg_catalog.count(*) from public.aos_wa_l8_consent_events_v1),
    'preflight_decisions',(select pg_catalog.count(*) from public.aos_wa_l8_preflight_decisions_v1),
    'pricing_type_events',(select pg_catalog.count(*) from public.aos_wa_events_v1 e where e.event_type='message.status' and nullif(e.payload->>'pricing_type','') is not null),
    'pricing_authority_rows',(select pg_catalog.count(*) from public.aos_wa_l7_pricing_authority_v1),
    'autonomous_outbound',(select pg_catalog.count(*) from public.aos_wa_messages_v1 m where m.direction='OUTBOUND' and m.send_origin='AUTO'),
    'browser_message_write',(
      pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','INSERT,UPDATE,DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','INSERT,UPDATE,DELETE')
    ),
    'browser_booking_write',(
      pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','INSERT,UPDATE,DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','INSERT,UPDATE,DELETE')
    )
  )
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

revoke all on function public.aos_wa_l8_security_status_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l8_security_status_v1() to service_role;

comment on table public.aos_wa_l8_consent_events_v1 is 'WA-L8 append-only consent evidence. Recipient stored only as SHA-256 hash; no raw address.';
comment on table public.aos_wa_l8_preflight_decisions_v1 is 'WA-L8 append-only autonomous policy preflight. No message body, phone or raw prompt stored.';
comment on view public.aos_wa_l8_meta_monthly_usage_v1 is 'Provider-observed monthly Meta usage/cost reconciliation by business phone and market. No fabricated free-tier entitlement.';
comment on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) is 'WA-L8 wrapper: consent/service-window preflight first, then certified L4 send authority. SAFE-OFF remains external control state.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
