-- ASCENDA OS — CIA Phase 2 Commercial Facts V1.1
-- Email reconciliation correction discovered during validation.
-- 1) Empty email_destino falls back to destinatario.
-- 2) clicked_count = unique sends/provider IDs with click evidence.

begin;

create or replace view public.aos_cia_email_facts_v1
with (security_invoker = true)
as
with identity as (
  select * from public.aos_cia_contact_identity_v1
), email_candidates as (
  select
    contact_key,
    lower(btrim(canonical_email)) as email
  from identity
  where identity_status = 'RESOLVED'
    and canonical_email is not null
    and lower(btrim(canonical_email)) ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
), safe_alias as (
  select email, min(contact_key) as contact_key
  from email_candidates
  group by email
  having count(distinct contact_key) = 1
), sends_raw as (
  select
    coalesce(nullif(e.resend_id, ''), 'emails_enviados:' || e.id::text) as provider_key,
    nullif(e.resend_id, '') as resend_id,
    'aos_emails_enviados'::text as source_table,
    e.id::text as source_id,
    lower(coalesce(nullif(btrim(e.email_destino), ''), nullif(btrim(e.destinatario), ''))) as email,
    null::text as direct_contact_key,
    coalesce(e.created_at, e.fecha_envio::timestamp at time zone 'America/Lima') as sent_at,
    e.abierto as legacy_opened,
    coalesce(e.clicks, 0)::integer as legacy_clicks,
    e.rebotado as legacy_bounced,
    1::integer as source_priority
  from public.aos_emails_enviados e

  union all

  select
    coalesce(nullif(e.resend_id, ''), 'email_envios:' || e.id::text),
    nullif(e.resend_id, ''),
    'aos_email_envios',
    e.id::text,
    lower(nullif(btrim(e.destinatario_email), '')),
    public.aos_cia_normalize_contact_key_v1(e.destinatario_numero),
    coalesce(e.enviado_at, e.created_at),
    null::boolean,
    0::integer,
    null::boolean,
    2::integer
  from public.aos_email_envios e
  where lower(btrim(coalesce(e.estado, ''))) = 'enviado'
), sends_dedup as (
  select distinct on (provider_key)
    provider_key, resend_id, source_table, source_id, email,
    direct_contact_key, sent_at, legacy_opened, legacy_clicks,
    legacy_bounced, source_priority
  from sends_raw
  order by provider_key, source_priority
), mapped_sends as (
  select
    s.*,
    coalesce(di.contact_key, ea.contact_key) as contact_key,
    case
      when di.contact_key is not null then 'HIGH'
      when ea.contact_key is not null then 'MEDIUM'
      else 'UNKNOWN'
    end::text as identity_confidence
  from sends_dedup s
  left join identity di on di.contact_key = s.direct_contact_key
  left join safe_alias ea on ea.email = s.email
), send_agg as (
  select
    contact_key,
    count(*)::integer as sent_count,
    max(sent_at) as last_sent_at,
    bool_or(identity_confidence = 'HIGH') as has_high_identity
  from mapped_sends
  where contact_key is not null
  group by contact_key
), event_mapped as (
  select
    e.id::text as event_id,
    coalesce(nullif(e.resend_id, ''), 'email_event:' || e.id::text) as provider_key,
    lower(btrim(coalesce(e.tipo_evento, ''))) as event_type,
    e.created_at as event_at,
    coalesce(ms.contact_key, ea.contact_key) as contact_key
  from public.aos_email_eventos e
  left join mapped_sends ms
    on ms.resend_id is not null and ms.resend_id = e.resend_id
  left join safe_alias ea
    on ea.email = lower(nullif(btrim(e.email_destino), ''))
), engagement_evidence as (
  select contact_key, provider_key, 'DELIVERED'::text as kind
  from event_mapped
  where contact_key is not null and event_type = 'email.delivered'

  union all
  select contact_key, provider_key, 'OPENED'
  from event_mapped
  where contact_key is not null and event_type = 'email.opened'

  union all
  select contact_key, provider_key, 'BOUNCED'
  from event_mapped
  where contact_key is not null and event_type = 'email.bounced'

  union all
  select contact_key, provider_key, 'CLICKED'
  from event_mapped
  where contact_key is not null and event_type in ('email.clicked', 'email.click')

  union all
  select contact_key, provider_key, 'OPENED'
  from mapped_sends
  where contact_key is not null and legacy_opened = true

  union all
  select contact_key, provider_key, 'BOUNCED'
  from mapped_sends
  where contact_key is not null and legacy_bounced = true

  union all
  select contact_key, provider_key, 'CLICKED'
  from mapped_sends
  where contact_key is not null and legacy_clicks > 0
), evidence_dedup as (
  select distinct contact_key, provider_key, kind
  from engagement_evidence
), engagement_agg as (
  select
    contact_key,
    count(*) filter (where kind = 'DELIVERED')::integer as delivered_count,
    count(*) filter (where kind = 'OPENED')::integer as opened_count,
    count(*) filter (where kind = 'CLICKED')::integer as clicked_count,
    count(*) filter (where kind = 'BOUNCED')::integer as bounced_count
  from evidence_dedup
  group by contact_key
), event_last as (
  select contact_key, max(event_at) as last_event_at
  from event_mapped
  where contact_key is not null
  group by contact_key
), safe_by_contact as (
  select contact_key, min(email) as email
  from safe_alias
  group by contact_key
)
select
  1::integer as facts_version,
  i.contact_key,
  case
    when coalesce(sa.has_high_identity, false) then 'HIGH'
    when sbc.contact_key is not null then 'MEDIUM'
    else 'UNKNOWN'
  end::text as identity_confidence,
  coalesce(sa.sent_count, 0)::integer as sent_count,
  case
    when coalesce(sa.sent_count, 0) > 0 then false
    when sbc.contact_key is not null then true
    else null
  end as never_sent,
  sa.last_sent_at,
  case
    when sa.last_sent_at is null then null
    else ((now() at time zone 'America/Lima')::date - sa.last_sent_at::date)::integer
  end as days_since_last,
  coalesce(ea.delivered_count, 0)::integer as delivered_count,
  coalesce(ea.opened_count, 0)::integer as opened_count,
  coalesce(ea.clicked_count, 0)::integer as clicked_count,
  coalesce(ea.bounced_count, 0)::integer as bounced_count,
  el.last_event_at,
  (sbc.contact_key is not null) as has_safe_email_alias,
  greatest(sa.last_sent_at, el.last_event_at) as source_last_at
from identity i
left join safe_by_contact sbc using (contact_key)
left join send_agg sa using (contact_key)
left join engagement_agg ea using (contact_key)
left join event_last el using (contact_key);

comment on view public.aos_cia_email_facts_v1 is
'CIA Email Facts V1.1 — safe empty-email fallback; clicked_count counts unique sends/provider IDs with click evidence.';

revoke all on public.aos_cia_email_facts_v1 from public, anon, authenticated;
grant select on public.aos_cia_email_facts_v1 to service_role;

commit;
