-- WA-L7 — WhatsApp / AI Cost Intelligence V1
-- Reproducible, conversation-scoped cost read model over existing WA ledgers.
-- No provider price fabrication, no soft-identity joins, no synchronous write-path analytics.

begin;

create table if not exists public.aos_wa_l7_pricing_authority_v1 (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('META_WHATSAPP','GROQ')),
  pricing_kind text not null check (pricing_kind in ('META_MESSAGE','AI_TOKEN')),
  pricing_category text,
  pricing_model text not null,
  market_code text not null default 'GLOBAL' check (market_code ~ '^[A-Z0-9_-]{2,32}$'),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  flat_cost numeric(18,8),
  input_cost_per_million numeric(18,8),
  output_cost_per_million numeric(18,8),
  authority_grade text not null check (authority_grade in ('VERIFIED','LEGACY_ESTIMATE')),
  evidence_ref text not null,
  valid_from timestamptz not null,
  valid_to timestamptz,
  created_by uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint aos_wa_l7_pricing_provider_kind_ck check (
    (provider='META_WHATSAPP' and pricing_kind='META_MESSAGE')
    or (provider='GROQ' and pricing_kind='AI_TOKEN')
  ),
  constraint aos_wa_l7_pricing_shape_ck check (
    (
      pricing_kind='META_MESSAGE'
      and nullif(btrim(pricing_category),'') is not null
      and flat_cost is not null and flat_cost>=0
      and input_cost_per_million is null
      and output_cost_per_million is null
    )
    or
    (
      pricing_kind='AI_TOKEN'
      and pricing_category is null
      and flat_cost is null
      and input_cost_per_million is not null and input_cost_per_million>=0
      and output_cost_per_million is not null and output_cost_per_million>=0
    )
  ),
  constraint aos_wa_l7_pricing_window_ck check (valid_to is null or valid_to>valid_from),
  constraint aos_wa_l7_pricing_evidence_ck check (nullif(btrim(evidence_ref),'') is not null)
);

create unique index if not exists aos_wa_l7_pricing_version_uq
  on public.aos_wa_l7_pricing_authority_v1(
    provider,pricing_kind,coalesce(pricing_category,''),lower(pricing_model),market_code,valid_from
  );
create index if not exists aos_wa_l7_pricing_lookup_idx
  on public.aos_wa_l7_pricing_authority_v1(
    provider,pricing_kind,lower(pricing_model),coalesce(pricing_category,''),market_code,valid_from desc
  );

alter table public.aos_wa_l7_pricing_authority_v1 enable row level security;
alter table public.aos_wa_l7_pricing_authority_v1 force row level security;
revoke all on public.aos_wa_l7_pricing_authority_v1 from public,anon,authenticated;
grant select on public.aos_wa_l7_pricing_authority_v1 to service_role;

create or replace function public.aos_wa_l7_pricing_append_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA_L7_PRICING_APPEND_ONLY' using errcode='55000';
end
$$;

revoke all on function public.aos_wa_l7_pricing_append_guard_v1() from public,anon,authenticated;
grant execute on function public.aos_wa_l7_pricing_append_guard_v1() to service_role;

drop trigger if exists trg_aos_wa_l7_pricing_append_guard_v1 on public.aos_wa_l7_pricing_authority_v1;
create trigger trg_aos_wa_l7_pricing_append_guard_v1
before update or delete on public.aos_wa_l7_pricing_authority_v1
for each row execute function public.aos_wa_l7_pricing_append_guard_v1();

-- Effective-dated versions are append-only. A newer valid_from supersedes an older
-- open-ended version for future events without rewriting historical evidence.
create or replace function public.aos_wa_l7_pricing_authority_append_v1(
  p_token text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_provider text;
  v_kind text;
  v_category text;
  v_model text;
  v_market text;
  v_currency text;
  v_grade text;
  v_evidence text;
  v_flat numeric;
  v_input numeric;
  v_output numeric;
  v_from timestamptz;
  v_to timestamptz;
  v_id uuid;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-whatsapp',true);
  if v_actor is null then
    v_actor:=public.aos_app_actor_v3(p_token,'admin-marketing',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_UNAUTHORIZED');
  end if;
  if p_payload is null or pg_catalog.jsonb_typeof(p_payload)<>'object' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PAYLOAD_INVALID');
  end if;

  v_provider:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_payload->>'provider','')));
  v_kind:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_payload->>'pricing_kind','')));
  v_category:=nullif(pg_catalog.lower(pg_catalog.btrim(coalesce(p_payload->>'pricing_category',''))),'');
  v_model:=nullif(pg_catalog.lower(pg_catalog.btrim(coalesce(p_payload->>'pricing_model',''))),'');
  v_market:=pg_catalog.upper(pg_catalog.btrim(coalesce(nullif(p_payload->>'market_code',''),'GLOBAL')));
  v_currency:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_payload->>'currency','')));
  v_grade:=pg_catalog.upper(pg_catalog.btrim(coalesce(p_payload->>'authority_grade','')));
  v_evidence:=nullif(pg_catalog.btrim(coalesce(p_payload->>'evidence_ref','')),'');

  if v_provider not in ('META_WHATSAPP','GROQ') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PROVIDER_INVALID');
  end if;
  if v_kind not in ('META_MESSAGE','AI_TOKEN') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PRICING_KIND_INVALID');
  end if;
  if (v_provider='META_WHATSAPP' and v_kind<>'META_MESSAGE') or (v_provider='GROQ' and v_kind<>'AI_TOKEN') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PROVIDER_KIND_MISMATCH');
  end if;
  if v_model is null or pg_catalog.length(v_model)>160 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PRICING_MODEL_REQUIRED');
  end if;
  if v_market !~ '^[A-Z0-9_-]{2,32}$' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_MARKET_INVALID');
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_CURRENCY_INVALID');
  end if;
  if v_grade not in ('VERIFIED','LEGACY_ESTIMATE') then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_AUTHORITY_GRADE_REQUIRED');
  end if;
  if v_evidence is null or pg_catalog.length(v_evidence)>1000 then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_EVIDENCE_REQUIRED');
  end if;

  begin
    v_from:=(p_payload->>'valid_from')::timestamptz;
  exception when others then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_VALID_FROM_REQUIRED');
  end;
  if nullif(pg_catalog.btrim(coalesce(p_payload->>'valid_to','')),'') is not null then
    begin
      v_to:=(p_payload->>'valid_to')::timestamptz;
    exception when others then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_VALID_TO_INVALID');
    end;
    if v_to<=v_from then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_VALID_WINDOW_INVALID');
    end if;
  end if;

  begin
    if nullif(pg_catalog.btrim(coalesce(p_payload->>'flat_cost','')),'') is not null then
      v_flat:=(p_payload->>'flat_cost')::numeric;
    end if;
    if nullif(pg_catalog.btrim(coalesce(p_payload->>'input_cost_per_million','')),'') is not null then
      v_input:=(p_payload->>'input_cost_per_million')::numeric;
    end if;
    if nullif(pg_catalog.btrim(coalesce(p_payload->>'output_cost_per_million','')),'') is not null then
      v_output:=(p_payload->>'output_cost_per_million')::numeric;
    end if;
  exception when others then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_RATE_NUMERIC_INVALID');
  end;

  if v_kind='META_MESSAGE' then
    if v_category is null or v_flat is null or v_flat<0 or v_input is not null or v_output is not null then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_META_RATE_SHAPE_INVALID');
    end if;
  else
    if v_category is not null or v_flat is not null or v_input is null or v_output is null or v_input<0 or v_output<0 then
      return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_AI_RATE_SHAPE_INVALID');
    end if;
  end if;

  begin
    insert into public.aos_wa_l7_pricing_authority_v1(
      provider,pricing_kind,pricing_category,pricing_model,market_code,currency,
      flat_cost,input_cost_per_million,output_cost_per_million,authority_grade,
      evidence_ref,valid_from,valid_to,created_by,created_at
    ) values (
      v_provider,v_kind,v_category,v_model,v_market,v_currency,
      v_flat,v_input,v_output,v_grade,v_evidence,v_from,v_to,v_actor,pg_catalog.now()
    ) returning id into v_id;
  exception when unique_violation then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_PRICING_VERSION_EXISTS');
  end;

  return pg_catalog.jsonb_build_object(
    'ok',true,'status','APPENDED','pricing_id',v_id,'provider',v_provider,
    'pricing_kind',v_kind,'pricing_category',v_category,'pricing_model',v_model,
    'market_code',v_market,'currency',v_currency,'authority_grade',v_grade,
    'valid_from',v_from,'valid_to',v_to,'evidence_ref',v_evidence
  );
end
$$;

revoke all on function public.aos_wa_l7_pricing_authority_append_v1(text,jsonb) from public;
grant execute on function public.aos_wa_l7_pricing_authority_append_v1(text,jsonb) to anon,authenticated,service_role;

-- Provider-observed outbound cost events. Non-billable is an explicit known zero.
-- Billable=true becomes monetary KNOWN only when an effective VERIFIED rate exists.
create or replace view public.aos_wa_l7_meta_cost_events_v1
with (security_invoker=true,security_barrier=true)
as
select
  m.id as message_id,
  m.provider_message_id,
  m.conversation_id,
  coalesce(m.delivered_at,m.sent_at,m.provider_timestamp,m.created_at) as cost_event_at,
  m.pricing_category,
  m.pricing_model,
  m.billable,
  r.id as pricing_authority_id,
  r.authority_grade,
  r.evidence_ref as pricing_evidence_ref,
  case
    when m.billable is false then 'KNOWN'
    when m.billable is true and r.id is not null and r.authority_grade='VERIFIED' then 'KNOWN'
    when m.billable is true and r.id is not null then 'PARTIAL'
    else 'UNKNOWN'
  end::text as cost_state,
  case
    when m.billable is false then 'PROVIDER_NON_BILLABLE'
    when m.billable is true and (m.pricing_category is null or m.pricing_model is null) then 'PROVIDER_PRICING_METADATA_INCOMPLETE'
    when m.billable is true and r.id is null then 'VERIFIED_RATE_NOT_FOUND'
    when r.authority_grade='LEGACY_ESTIMATE' then 'LEGACY_ESTIMATE_RATE'
    else 'VERIFIED_PROVIDER_RATE'
  end::text as cost_reason,
  case
    when m.billable is false then 0::numeric
    when m.billable is true and r.id is not null then r.flat_cost
    else null::numeric
  end as cost_amount,
  case
    when m.billable is true and r.id is not null then r.currency
    else null::text
  end as cost_currency
from public.aos_wa_messages_v1 m
left join lateral (
  select p.*
  from public.aos_wa_l7_pricing_authority_v1 p
  where p.provider='META_WHATSAPP'
    and p.pricing_kind='META_MESSAGE'
    and pg_catalog.lower(p.pricing_model)=pg_catalog.lower(coalesce(m.pricing_model,''))
    and pg_catalog.lower(coalesce(p.pricing_category,''))=pg_catalog.lower(coalesce(m.pricing_category,''))
    and p.market_code='GLOBAL'
    and p.valid_from<=coalesce(m.delivered_at,m.sent_at,m.provider_timestamp,m.created_at)
    and (p.valid_to is null or coalesce(m.delivered_at,m.sent_at,m.provider_timestamp,m.created_at)<p.valid_to)
  order by p.valid_from desc,p.created_at desc
  limit 1
) r on m.billable is true
where m.direction='OUTBOUND';

revoke all on public.aos_wa_l7_meta_cost_events_v1 from public,anon,authenticated;
grant select on public.aos_wa_l7_meta_cost_events_v1 to service_role;

-- AI run cost verification. Existing WA-4 rows aggregate main+safety token counts.
-- Exact governed recalculation is possible when only one model is present, or both
-- models share the exact same effective token rate. Otherwise the historical
-- estimated_cost_usd remains visible as PARTIAL rather than being mislabeled KNOWN.
create or replace view public.aos_wa_l7_ai_cost_events_v1
with (security_invoker=true,security_barrier=true)
as
select
  a.id as ai_run_id,
  a.conversation_id,
  a.created_at as cost_event_at,
  a.provider,
  a.model,
  a.safety_model,
  a.prompt_tokens,
  a.completion_tokens,
  a.total_tokens,
  a.estimated_cost_usd as legacy_estimated_cost_usd,
  main_rate.id as main_pricing_authority_id,
  safety_rate.id as safety_pricing_authority_id,
  case
    when a.provider='deterministic' then 'KNOWN'
    when a.total_tokens=0 and a.estimated_cost_usd=0 then 'KNOWN'
    when main_rate.id is not null
      and main_rate.authority_grade='VERIFIED'
      and (
        a.safety_model is null
        or (
          safety_rate.id is not null
          and safety_rate.authority_grade='VERIFIED'
          and main_rate.currency=safety_rate.currency
          and main_rate.input_cost_per_million=safety_rate.input_cost_per_million
          and main_rate.output_cost_per_million=safety_rate.output_cost_per_million
        )
      ) then 'KNOWN'
    when a.estimated_cost_usd>0 or main_rate.id is not null then 'PARTIAL'
    else 'UNKNOWN'
  end::text as cost_state,
  case
    when a.provider='deterministic' then 'DETERMINISTIC_NO_PROVIDER_COST'
    when a.total_tokens=0 and a.estimated_cost_usd=0 then 'NO_BILLED_AI_USAGE'
    when main_rate.id is null then case when a.estimated_cost_usd>0 then 'LEGACY_RUNTIME_ESTIMATE_RATE_MISSING' else 'VERIFIED_RATE_NOT_FOUND' end
    when main_rate.authority_grade<>'VERIFIED' then 'LEGACY_ESTIMATE_RATE'
    when a.safety_model is null then 'VERIFIED_SINGLE_MODEL_RATE'
    when safety_rate.id is null then 'AI_SAFETY_RATE_MISSING'
    when safety_rate.authority_grade<>'VERIFIED' then 'AI_SAFETY_RATE_NOT_VERIFIED'
    when main_rate.currency<>safety_rate.currency
      or main_rate.input_cost_per_million<>safety_rate.input_cost_per_million
      or main_rate.output_cost_per_million<>safety_rate.output_cost_per_million
      then 'AI_USAGE_NOT_SPLIT_BY_MODEL'
    else 'VERIFIED_EQUAL_RATE_COMBINED_USAGE'
  end::text as cost_reason,
  case
    when a.provider='deterministic' then 0::numeric
    when a.total_tokens=0 and a.estimated_cost_usd=0 then 0::numeric
    when main_rate.id is not null
      and (
        a.safety_model is null
        or (
          safety_rate.id is not null
          and main_rate.currency=safety_rate.currency
          and main_rate.input_cost_per_million=safety_rate.input_cost_per_million
          and main_rate.output_cost_per_million=safety_rate.output_cost_per_million
        )
      ) then pg_catalog.round(
        ((a.prompt_tokens::numeric*main_rate.input_cost_per_million)
        +(a.completion_tokens::numeric*main_rate.output_cost_per_million))/1000000::numeric,8
      )
    when a.estimated_cost_usd>0 then a.estimated_cost_usd
    else null::numeric
  end as cost_amount,
  case
    when a.provider='deterministic' or (a.total_tokens=0 and a.estimated_cost_usd=0) then null::text
    when main_rate.id is not null
      and (
        a.safety_model is null
        or (
          safety_rate.id is not null
          and main_rate.currency=safety_rate.currency
          and main_rate.input_cost_per_million=safety_rate.input_cost_per_million
          and main_rate.output_cost_per_million=safety_rate.output_cost_per_million
        )
      ) then main_rate.currency
    when a.estimated_cost_usd>0 then 'USD'
    else null::text
  end as cost_currency
from public.aos_wa_ai_runs_v1 a
left join lateral (
  select p.*
  from public.aos_wa_l7_pricing_authority_v1 p
  where p.provider='GROQ'
    and p.pricing_kind='AI_TOKEN'
    and pg_catalog.lower(p.pricing_model)=pg_catalog.lower(coalesce(a.model,''))
    and p.market_code='GLOBAL'
    and p.valid_from<=a.created_at
    and (p.valid_to is null or a.created_at<p.valid_to)
  order by p.valid_from desc,p.created_at desc
  limit 1
) main_rate on a.provider='groq' and a.model is not null
left join lateral (
  select p.*
  from public.aos_wa_l7_pricing_authority_v1 p
  where p.provider='GROQ'
    and p.pricing_kind='AI_TOKEN'
    and pg_catalog.lower(p.pricing_model)=pg_catalog.lower(coalesce(a.safety_model,''))
    and p.market_code='GLOBAL'
    and p.valid_from<=a.created_at
    and (p.valid_to is null or a.created_at<p.valid_to)
  order by p.valid_from desc,p.created_at desc
  limit 1
) safety_rate on a.provider='groq' and a.safety_model is not null;

revoke all on public.aos_wa_l7_ai_cost_events_v1 from public,anon,authenticated;
grant select on public.aos_wa_l7_ai_cost_events_v1 to service_role;

-- Conversation-scoped aggregation only. The UI must call this by exact conversation UUID;
-- it is intentionally not a global dashboard/materialization.
create or replace function public.aos_wa_l7_conversation_cost_v1(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_meta_n integer:=0;
  v_meta_known integer:=0;
  v_meta_partial integer:=0;
  v_meta_unknown integer:=0;
  v_meta_billable integer:=0;
  v_meta_amount numeric:=0;
  v_meta_currency_count integer:=0;
  v_meta_currency text;
  v_meta_state text;
  v_meta_reason text;

  v_ai_n integer:=0;
  v_ai_known integer:=0;
  v_ai_partial integer:=0;
  v_ai_unknown integer:=0;
  v_ai_amount numeric:=0;
  v_ai_currency_count integer:=0;
  v_ai_currency text;
  v_ai_legacy_usd numeric:=0;
  v_ai_state text;
  v_ai_reason text;

  v_total_state text;
  v_total_amount numeric;
  v_total_currency text;
  v_total_reason text;
begin
  if p_conversation_id is null or not exists(
    select 1 from public.aos_wa_conversations_v1 c where c.id=p_conversation_id
  ) then
    return pg_catalog.jsonb_build_object('ok',false,'error','WA_L7_CONVERSATION_NOT_FOUND');
  end if;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) filter(where e.cost_state='KNOWN')::integer,
    pg_catalog.count(*) filter(where e.cost_state='PARTIAL')::integer,
    pg_catalog.count(*) filter(where e.cost_state='UNKNOWN')::integer,
    pg_catalog.count(*) filter(where e.billable is true)::integer,
    coalesce(pg_catalog.sum(e.cost_amount),0),
    pg_catalog.count(distinct e.cost_currency) filter(where coalesce(e.cost_amount,0)<>0 and e.cost_currency is not null)::integer,
    pg_catalog.max(e.cost_currency) filter(where coalesce(e.cost_amount,0)<>0 and e.cost_currency is not null)
  into v_meta_n,v_meta_known,v_meta_partial,v_meta_unknown,v_meta_billable,
       v_meta_amount,v_meta_currency_count,v_meta_currency
  from public.aos_wa_l7_meta_cost_events_v1 e
  where e.conversation_id=p_conversation_id;

  if v_meta_n=0 then
    v_meta_state:='KNOWN'; v_meta_amount:=0; v_meta_currency:=null; v_meta_reason:='NO_OUTBOUND_MESSAGES';
  elsif v_meta_currency_count>1 then
    v_meta_state:='PARTIAL'; v_meta_amount:=null; v_meta_currency:=null; v_meta_reason:='META_MULTI_CURRENCY_REQUIRES_FX';
  elsif v_meta_unknown=v_meta_n then
    v_meta_state:='UNKNOWN'; v_meta_reason:='META_COST_UNRESOLVED';
  elsif v_meta_partial>0 or v_meta_unknown>0 then
    v_meta_state:='PARTIAL'; v_meta_reason:='META_COST_PARTIALLY_RESOLVED';
  else
    v_meta_state:='KNOWN'; v_meta_reason:='META_COST_RECONCILED';
  end if;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) filter(where e.cost_state='KNOWN')::integer,
    pg_catalog.count(*) filter(where e.cost_state='PARTIAL')::integer,
    pg_catalog.count(*) filter(where e.cost_state='UNKNOWN')::integer,
    coalesce(pg_catalog.sum(e.cost_amount),0),
    pg_catalog.count(distinct e.cost_currency) filter(where coalesce(e.cost_amount,0)<>0 and e.cost_currency is not null)::integer,
    pg_catalog.max(e.cost_currency) filter(where coalesce(e.cost_amount,0)<>0 and e.cost_currency is not null),
    coalesce(pg_catalog.sum(e.legacy_estimated_cost_usd),0)
  into v_ai_n,v_ai_known,v_ai_partial,v_ai_unknown,v_ai_amount,
       v_ai_currency_count,v_ai_currency,v_ai_legacy_usd
  from public.aos_wa_l7_ai_cost_events_v1 e
  where e.conversation_id=p_conversation_id;

  if v_ai_n=0 then
    v_ai_state:='KNOWN'; v_ai_amount:=0; v_ai_currency:=null; v_ai_reason:='NO_AI_RUNS';
  elsif v_ai_currency_count>1 then
    v_ai_state:='PARTIAL'; v_ai_amount:=null; v_ai_currency:=null; v_ai_reason:='AI_MULTI_CURRENCY_REQUIRES_FX';
  elsif v_ai_unknown=v_ai_n then
    v_ai_state:='UNKNOWN'; v_ai_reason:='AI_COST_UNRESOLVED';
  elsif v_ai_partial>0 or v_ai_unknown>0 then
    v_ai_state:='PARTIAL'; v_ai_reason:='AI_COST_PARTIALLY_RESOLVED';
  else
    v_ai_state:='KNOWN'; v_ai_reason:='AI_COST_RECONCILED';
  end if;

  if v_meta_amount is null or v_ai_amount is null then
    v_total_amount:=null; v_total_currency:=null;
    v_total_state:=case when v_meta_state='UNKNOWN' and v_ai_state='UNKNOWN' then 'UNKNOWN' else 'PARTIAL' end;
    v_total_reason:='COMPONENT_COST_UNRESOLVED';
  elsif v_meta_amount<>0 and v_ai_amount<>0 and v_meta_currency is distinct from v_ai_currency then
    v_total_amount:=null; v_total_currency:=null; v_total_state:='PARTIAL';
    v_total_reason:='COST_CURRENCY_MISMATCH_REQUIRES_FX';
  else
    v_total_amount:=v_meta_amount+v_ai_amount;
    v_total_currency:=case when v_meta_amount<>0 then v_meta_currency when v_ai_amount<>0 then v_ai_currency else null end;
    if v_meta_state='KNOWN' and v_ai_state='KNOWN' then
      v_total_state:='KNOWN'; v_total_reason:='COST_RECONCILED';
    elsif v_meta_state='UNKNOWN' and v_ai_state='UNKNOWN' then
      v_total_state:='UNKNOWN'; v_total_reason:='COST_UNRESOLVED';
    else
      v_total_state:='PARTIAL'; v_total_reason:='COST_PARTIALLY_RECONCILED';
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'conversation_id',p_conversation_id,
    'meta',pg_catalog.jsonb_build_object(
      'state',v_meta_state,'reason',v_meta_reason,'outbound_messages',v_meta_n,
      'billable_messages',v_meta_billable,'known_events',v_meta_known,
      'partial_events',v_meta_partial,'unknown_events',v_meta_unknown,
      'amount',v_meta_amount,'currency',v_meta_currency
    ),
    'ai',pg_catalog.jsonb_build_object(
      'state',v_ai_state,'reason',v_ai_reason,'runs',v_ai_n,
      'known_runs',v_ai_known,'partial_runs',v_ai_partial,'unknown_runs',v_ai_unknown,
      'amount',v_ai_amount,'currency',v_ai_currency,'legacy_estimated_cost_usd',v_ai_legacy_usd
    ),
    'total',pg_catalog.jsonb_build_object(
      'state',v_total_state,'reason',v_total_reason,'amount',v_total_amount,'currency',v_total_currency
    )
  );
end
$$;

revoke all on function public.aos_wa_l7_conversation_cost_v1(uuid) from public,anon,authenticated;
grant execute on function public.aos_wa_l7_conversation_cost_v1(uuid) to service_role;

-- Strong-key journey KPI projection. It consumes WA-L6 only by conversation_id and
-- deduplicates appointments/sales before aggregation so multi-touch rows cannot double count.
create or replace function public.aos_wa_l7_journey_cost_v1(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_cost jsonb;
  v_cost_state text;
  v_cost_amount numeric;
  v_cost_currency text;
  v_booking_count integer:=0;
  v_rebook_count integer:=0;
  v_attendance_count integer:=0;
  v_sale_count integer:=0;
  v_revenue_amount numeric:=0;
  v_revenue_currency_count integer:=0;
  v_revenue_currency text;
  v_revenue_state text;
  v_chain_statuses jsonb:='[]'::jsonb;
  v_ratio numeric;
  v_ratio_reason text;
begin
  v_cost:=public.aos_wa_l7_conversation_cost_v1(p_conversation_id);
  if coalesce((v_cost->>'ok')::boolean,false) is not true then
    return v_cost;
  end if;

  with appointment_rows as (
    select distinct on (j.appointment_id)
      j.appointment_id,j.book_count,j.rebook_count,j.attended
    from public.aos_wa_l6_attribution_journey_v1 j
    where j.conversation_id=p_conversation_id and j.appointment_id is not null
    order by j.appointment_id,j.touchpoint_at nulls last,j.touchpoint_id nulls last
  )
  select
    pg_catalog.count(*)::integer,
    coalesce(pg_catalog.sum(coalesce(rebook_count,0)),0)::integer,
    pg_catalog.count(*) filter(where attended is true)::integer
  into v_booking_count,v_rebook_count,v_attendance_count
  from appointment_rows;

  with sale_rows as (
    select distinct on (j.sale_link_venta_id)
      j.sale_link_venta_id,j.revenue_amount,j.revenue_currency
    from public.aos_wa_l6_attribution_journey_v1 j
    where j.conversation_id=p_conversation_id
      and j.sale_link_venta_id is not null
      and coalesce(j.sale_row_count,0)>0
    order by j.sale_link_venta_id,j.touchpoint_at nulls last,j.touchpoint_id nulls last
  )
  select
    pg_catalog.count(*)::integer,
    coalesce(pg_catalog.sum(revenue_amount),0),
    pg_catalog.count(distinct revenue_currency) filter(where coalesce(revenue_amount,0)<>0 and revenue_currency is not null)::integer,
    pg_catalog.max(revenue_currency) filter(where coalesce(revenue_amount,0)<>0 and revenue_currency is not null)
  into v_sale_count,v_revenue_amount,v_revenue_currency_count,v_revenue_currency
  from sale_rows;

  select coalesce(pg_catalog.jsonb_agg(distinct j.attribution_chain_status) filter(where j.attribution_chain_status is not null),'[]'::jsonb)
  into v_chain_statuses
  from public.aos_wa_l6_attribution_journey_v1 j
  where j.conversation_id=p_conversation_id;

  if v_revenue_currency_count>1 or v_revenue_currency='MIXED' then
    v_revenue_state:='PARTIAL'; v_revenue_amount:=null; v_revenue_currency:=null;
  else
    v_revenue_state:='KNOWN';
  end if;

  v_cost_state:=v_cost->'total'->>'state';
  if v_cost->'total'->>'amount' is not null then
    v_cost_amount:=(v_cost->'total'->>'amount')::numeric;
  end if;
  v_cost_currency:=v_cost->'total'->>'currency';

  if v_cost_amount is null then
    v_ratio:=null; v_ratio_reason:='COST_UNRESOLVED';
  elsif v_cost_amount=0 then
    v_ratio:=null; v_ratio_reason:='ZERO_COST_DENOMINATOR';
  elsif v_revenue_amount is null then
    v_ratio:=null; v_ratio_reason:='REVENUE_UNRESOLVED';
  elsif v_revenue_amount=0 then
    v_ratio:=0; v_ratio_reason:='NO_REVENUE';
  elsif v_revenue_currency is distinct from v_cost_currency then
    v_ratio:=null; v_ratio_reason:='REVENUE_COST_CURRENCY_MISMATCH_REQUIRES_FX';
  else
    v_ratio:=pg_catalog.round(v_revenue_amount/v_cost_amount,4); v_ratio_reason:='COMPARABLE_CURRENCY';
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'conversation_id',p_conversation_id,
    'cost',v_cost,
    'journey',pg_catalog.jsonb_build_object(
      'bookings',v_booking_count,'rebooks',v_rebook_count,'attendances',v_attendance_count,
      'sales',v_sale_count,'revenue_state',v_revenue_state,'revenue_amount',v_revenue_amount,
      'revenue_currency',v_revenue_currency,'attribution_chain_statuses',v_chain_statuses
    ),
    'kpis',pg_catalog.jsonb_build_object(
      'cost_state',v_cost_state,
      'cost_per_conversation',v_cost_amount,
      'cost_currency',v_cost_currency,
      'cost_per_booking',case when v_cost_amount is not null and v_booking_count>0 then pg_catalog.round(v_cost_amount/v_booking_count,8) else null end,
      'cost_per_attendance',case when v_cost_amount is not null and v_attendance_count>0 then pg_catalog.round(v_cost_amount/v_attendance_count,8) else null end,
      'cost_per_sale',case when v_cost_amount is not null and v_sale_count>0 then pg_catalog.round(v_cost_amount/v_sale_count,8) else null end,
      'revenue_cost_ratio',v_ratio,
      'revenue_cost_ratio_reason',v_ratio_reason
    )
  );
end
$$;

revoke all on function public.aos_wa_l7_journey_cost_v1(uuid) from public,anon,authenticated;
grant execute on function public.aos_wa_l7_journey_cost_v1(uuid) to service_role;

comment on table public.aos_wa_l7_pricing_authority_v1 is
'WA-L7 append-only effective-dated pricing authority. No implicit/default provider rates; evidence and authority grade are mandatory.';
comment on view public.aos_wa_l7_meta_cost_events_v1 is
'WA-L7 derived outbound Meta cost ledger. billable=false is known zero; billable=true requires governed pricing authority.';
comment on view public.aos_wa_l7_ai_cost_events_v1 is
'WA-L7 derived AI cost verification over append-only WA-4 runs. Legacy runtime estimates remain PARTIAL unless governed token rates make exact recalculation possible.';
comment on function public.aos_wa_l7_conversation_cost_v1(uuid) is
'WA-L7 bounded conversation-scoped Meta+AI cost reconciliation. KNOWN/PARTIAL/UNKNOWN; no phone/name identity joins and no global scan contract.';
comment on function public.aos_wa_l7_journey_cost_v1(uuid) is
'WA-L7 bounded strong-key journey cost KPIs over WA-L6 conversation->appointment->sale lineage. Currency mismatch fails closed; no FX is fabricated.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
