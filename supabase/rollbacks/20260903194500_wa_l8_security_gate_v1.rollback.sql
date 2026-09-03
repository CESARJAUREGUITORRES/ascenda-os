-- WA-L8 recovery. Audit/consent history is immutable: structural recovery is
-- allowed only before any L8 consent/preflight evidence exists.

begin;

do $$
begin
  if to_regclass('public.aos_wa_l8_consent_events_v1') is not null
     and exists(select 1 from public.aos_wa_l8_consent_events_v1) then
    raise exception 'WA_L8_RECOVERY_BLOCKED_AUDIT_HISTORY';
  end if;
  if to_regclass('public.aos_wa_l8_preflight_decisions_v1') is not null
     and exists(select 1 from public.aos_wa_l8_preflight_decisions_v1) then
    raise exception 'WA_L8_RECOVERY_BLOCKED_AUDIT_HISTORY';
  end if;
end $$;

drop view if exists public.aos_wa_l8_meta_monthly_usage_v1;

-- CREATE OR REPLACE cannot remove L8's appended view columns, so drop/recreate
-- the L7 view while no L8 audit history exists.
drop view if exists public.aos_wa_l7_meta_cost_events_v1;
create view public.aos_wa_l7_meta_cost_events_v1
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

drop view if exists public.aos_wa_l8_meta_pricing_evidence_v1;

-- Restore the certified L4 public function name.
drop function if exists public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text);
do $$
begin
  if to_regprocedure('public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)') is not null then
    alter function public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)
      rename to aos_wa_l4_authorize_autonomous_send_v1;
  end if;
end $$;
revoke all on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text) to service_role;

drop function if exists public.aos_wa_l8_security_status_v1();
drop function if exists public.aos_wa_l8_autonomous_preflight_v1(uuid,text,text,text,text,text);
drop function if exists public.aos_wa_l8_consent_record_v1(text,uuid,text,text,text);

drop trigger if exists trg_aos_wa_l8_preflight_append_guard_v1 on public.aos_wa_l8_preflight_decisions_v1;
drop table if exists public.aos_wa_l8_preflight_decisions_v1;
drop trigger if exists trg_aos_wa_l8_consent_append_guard_v1 on public.aos_wa_l8_consent_events_v1;
drop table if exists public.aos_wa_l8_consent_events_v1;
drop function if exists public.aos_wa_l8_append_guard_v1();

alter table public.aos_wa_l7_pricing_authority_v1
  drop constraint if exists aos_wa_l8_meta_market_specific_ck;

-- Least-privilege revocations are monotonic security hardening and intentionally
-- survive structural recovery. They remove privileges no certified runtime needs.

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
