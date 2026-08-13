-- ASCENDA OS — Commercial Intelligence & Audience OS
-- Phase 2 — Commercial Facts Engine V1
-- Additive/read-only analytical layer. No source row is mutated.

begin;

-- -----------------------------------------------------------------------------
-- Lead interest taxonomy V1.
-- Current observed campaign labels are classified explicitly; unknown future
-- labels remain UNKNOWN until a controlled mapping is added/versioned.
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_interest_taxonomy_v1
with (security_invoker = true)
as
select *
from (values
  ('CAPILAR'::text, 'SERVICIO'::text, 'MANUAL_V1'::text),
  ('ENZIMAS FACIALES', 'SERVICIO', 'MANUAL_V1'),
  ('HIFU', 'SERVICIO', 'MANUAL_V1'),
  ('BIO ESTIMULADOR', 'SERVICIO', 'MANUAL_V1'),
  ('HIDROFACIAL', 'SERVICIO', 'MANUAL_V1'),
  ('CRIOLIPOLISIS', 'SERVICIO', 'MANUAL_V1'),
  ('TOXINA', 'SERVICIO', 'MANUAL_V1'),
  ('RESET - DE/HI/VIT', 'SERVICIO', 'MANUAL_V1'),
  ('RADIOFRECUENCIA FRACCIONADA', 'SERVICIO', 'MANUAL_V1'),
  ('PINK INTIMATE', 'SERVICIO', 'MANUAL_V1')
) v(interest_key, interest_type, mapping_source);

comment on view public.aos_cia_interest_taxonomy_v1 is
'CIA V1 explicit lead-interest taxonomy. No fuzzy classification; unknown labels remain UNKNOWN.';

-- -----------------------------------------------------------------------------
-- LEAD FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_lead_facts_v1
with (security_invoker = true)
as
with base as (
  select
    public.aos_cia_normalize_contact_key_v1(l.numero_limpio) as contact_key,
    l.id,
    coalesce(l.hora_ingreso, l.created_at, l.fecha::timestamp at time zone 'America/Lima') as event_at,
    nullif(upper(btrim(l.tratamiento)), '') as interest_key,
    nullif(btrim(l.anuncio), '') as ad
  from public.aos_leads l
  where public.aos_cia_normalize_contact_key_v1(l.numero_limpio) is not null
), enriched as (
  select b.*, t.interest_type
  from base b
  left join public.aos_cia_interest_taxonomy_v1 t
    on t.interest_key = b.interest_key
), ranked as (
  select e.*,
         row_number() over (
           partition by contact_key
           order by event_at desc nulls last, id desc
         ) as rn
  from enriched e
), agg as (
  select
    contact_key,
    count(*)::integer as lead_count,
    min(event_at) as first_lead_at,
    max(event_at) as last_lead_at,
    array_agg(distinct interest_key order by interest_key)
      filter (where interest_key is not null) as interests,
    array_agg(distinct coalesce(interest_type, 'UNKNOWN') order by coalesce(interest_type, 'UNKNOWN'))
      as interest_types,
    array_agg(distinct ad order by ad)
      filter (where ad is not null) as ads
  from enriched
  group by contact_key
)
select
  1::integer as facts_version,
  a.contact_key,
  a.lead_count,
  a.first_lead_at,
  a.last_lead_at,
  ((now() at time zone 'America/Lima')::date - a.last_lead_at::date)::integer as days_since_last_lead,
  r.id as latest_lead_id,
  r.interest_key as latest_interest,
  coalesce(r.interest_type, 'UNKNOWN')::text as latest_interest_type,
  coalesce(a.interests, array[]::text[]) as interests,
  coalesce(a.interest_types, array[]::text[]) as interest_types,
  r.ad as latest_ad,
  coalesce(a.ads, array[]::text[]) as ads,
  a.last_lead_at as source_last_at
from agg a
join ranked r
  on r.contact_key = a.contact_key
 and r.rn = 1;

comment on view public.aos_cia_lead_facts_v1 is
'CIA Commercial Facts V1 — one row per contact_key with lead history/latest acquisition facts.';

-- -----------------------------------------------------------------------------
-- CALL FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_call_facts_v1
with (security_invoker = true)
as
with base as (
  select
    public.aos_cia_normalize_contact_key_v1(c.numero_limpio) as contact_key,
    c.id,
    c.created_at as event_at,
    c.fecha,
    case
      when nullif(upper(btrim(c.estado)), '') is null then null
      when upper(btrim(c.estado)) = 'PROVINCIAS' then 'PROVINCIA'
      else upper(btrim(c.estado))
    end as status_norm,
    nullif(upper(btrim(c.sub_estado)), '') as substatus_norm,
    nullif(btrim(c.id_asesor), '') as advisor_id,
    nullif(btrim(c.asesor), '') as advisor_label,
    nullif(upper(btrim(c.tratamiento)), '') as treatment,
    c.intento
  from public.aos_llamadas c
  where public.aos_cia_normalize_contact_key_v1(c.numero_limpio) is not null
), ranked as (
  select b.*,
         row_number() over (
           partition by contact_key
           order by event_at desc nulls last, fecha desc nulls last, id desc
         ) as rn
  from base b
), agg as (
  select
    contact_key,
    count(*)::integer as call_count,
    min(event_at) as first_call_at,
    max(event_at) as last_call_at,
    array_agg(distinct status_norm order by status_norm)
      filter (where status_norm is not null) as ever_statuses,
    bool_or((event_at at time zone 'America/Lima')::date = (now() at time zone 'America/Lima')::date) as called_today,
    coalesce(max(intento), 0)::integer as max_attempt,
    count(*) filter (
      where status_norm is not null
        and status_norm not in ('SIN CONTACTO', 'NO CONTESTA')
    )::integer as effective_contact_count,
    count(*) filter (
      where status_norm in ('SIN CONTACTO', 'NO CONTESTA')
    )::integer as non_contact_count
  from base
  group by contact_key
)
select
  1::integer as facts_version,
  a.contact_key,
  a.call_count,
  a.first_call_at,
  a.last_call_at,
  ((now() at time zone 'America/Lima')::date - a.last_call_at::date)::integer as days_since_last_call,
  r.id as latest_call_id,
  r.status_norm as latest_status,
  r.substatus_norm as latest_substatus,
  r.advisor_id as latest_advisor_id,
  r.advisor_label as latest_advisor_label,
  r.treatment as latest_treatment,
  coalesce(a.ever_statuses, array[]::text[]) as ever_statuses,
  coalesce(a.called_today, false) as called_today,
  a.max_attempt,
  a.effective_contact_count,
  a.non_contact_count,
  a.last_call_at as source_last_at
from agg a
join ranked r
  on r.contact_key = a.contact_key
 and r.rn = 1;

comment on view public.aos_cia_call_facts_v1 is
'CIA Commercial Facts V1 — one row per contact_key with call latest/ever/count semantics and Call Contact Policy V1.';

-- -----------------------------------------------------------------------------
-- APPOINTMENT FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_appointment_facts_v1
with (security_invoker = true)
as
with base as (
  select
    public.aos_cia_normalize_contact_key_v1(a.numero_limpio) as contact_key,
    a.id,
    a.fecha_cita,
    case
      when nullif(upper(btrim(a.estado_cita)), '') is null then null
      else upper(btrim(a.estado_cita))
    end as status_norm,
    nullif(upper(btrim(a.tratamiento)), '') as treatment,
    nullif(btrim(a.sede), '') as branch,
    a.ts_actualizado,
    a.ts_creado
  from public.aos_agenda_citas a
  where public.aos_cia_normalize_contact_key_v1(a.numero_limpio) is not null
), agg as (
  select
    contact_key,
    count(*)::integer as appointment_count,
    count(*) filter (where status_norm = 'NO ASISTIO')::integer as no_show_count,
    count(*) filter (where status_norm in ('ASISTIO', 'EFECTIVA'))::integer as attended_count,
    max(fecha_cita) filter (where status_norm in ('ASISTIO', 'EFECTIVA')) as last_attended_at,
    array_agg(distinct status_norm order by status_norm)
      filter (where status_norm is not null) as appointment_statuses
  from base
  group by contact_key
), last_ranked as (
  select b.*,
         row_number() over (
           partition by contact_key
           order by fecha_cita desc nulls last, ts_actualizado desc nulls last, ts_creado desc nulls last, id desc
         ) as rn
  from base b
  where fecha_cita <= (now() at time zone 'America/Lima')::date
), next_ranked as (
  select b.*,
         row_number() over (
           partition by contact_key
           order by fecha_cita asc nulls last, ts_actualizado desc nulls last, ts_creado desc nulls last, id desc
         ) as rn
  from base b
  where fecha_cita >= (now() at time zone 'America/Lima')::date
    and status_norm in ('PENDIENTE', 'CITA CONFIRMADA')
)
select
  1::integer as facts_version,
  a.contact_key,
  a.appointment_count,
  lp.fecha_cita as last_appointment_at,
  lp.status_norm as last_appointment_status,
  lp.treatment as last_treatment,
  lp.branch as last_branch,
  nx.fecha_cita as next_appointment_at,
  nx.status_norm as next_appointment_status,
  nx.treatment as next_treatment,
  nx.branch as next_branch,
  (nx.contact_key is not null) as has_future_appointment,
  a.no_show_count,
  (a.no_show_count > 0) as ever_no_show,
  a.attended_count,
  a.last_attended_at,
  coalesce(a.appointment_statuses, array[]::text[]) as appointment_statuses,
  greatest(lp.fecha_cita, nx.fecha_cita) as source_last_at
from agg a
left join last_ranked lp
  on lp.contact_key = a.contact_key and lp.rn = 1
left join next_ranked nx
  on nx.contact_key = a.contact_key and nx.rn = 1;

comment on view public.aos_cia_appointment_facts_v1 is
'CIA Commercial Facts V1 — one row per contact_key with past/latest and upcoming appointment semantics.';

-- -----------------------------------------------------------------------------
-- SALES + PRODUCT + SERVICE FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_sales_facts_v1
with (security_invoker = true)
as
with user_tokens as (
  select u.id::text as user_id, upper(btrim(u.nombre)) as token
  from public.aos_usuarios u
  where u.activo = true and nullif(btrim(u.nombre), '') is not null
  union all
  select u.id::text, upper(btrim(u.codigo_asesor))
  from public.aos_usuarios u
  where u.activo = true and nullif(btrim(u.codigo_asesor), '') is not null
), user_alias as (
  select token, min(user_id) as user_id
  from user_tokens
  group by token
  having count(distinct user_id) = 1
), base as (
  select
    public.aos_cia_normalize_contact_key_v1(v.numero_limpio) as contact_key,
    v.id,
    v.fecha,
    v.created_at,
    upper(btrim(v.tipo)) as item_type,
    nullif(upper(btrim(v.tratamiento)), '') as item,
    coalesce(v.monto, 0)::numeric as amount,
    nullif(btrim(v.sede), '') as branch,
    nullif(btrim(v.asesor), '') as advisor_label,
    nullif(upper(btrim(v.estado_pago)), '') as payment_state,
    nullif(upper(btrim(v.pago)), '') as payment_method
  from public.aos_ventas v
  where public.aos_cia_normalize_contact_key_v1(v.numero_limpio) is not null
), ranked as (
  select b.*,
         row_number() over (
           partition by contact_key
           order by fecha desc nulls last, created_at desc nulls last, id desc
         ) as rn
  from base b
), agg as (
  select
    contact_key,
    count(*)::integer as sale_count,
    sum(amount)::numeric as revenue_lifetime,
    min(fecha) as first_sale_at,
    max(fecha) as last_sale_at,
    count(*) filter (where item_type = 'PRODUCTO')::integer as product_count,
    count(*) filter (where item_type = 'SERVICIO')::integer as service_count,
    coalesce(sum(amount) filter (where item_type = 'PRODUCTO'), 0)::numeric as product_revenue,
    coalesce(sum(amount) filter (where item_type = 'SERVICIO'), 0)::numeric as service_revenue,
    array_agg(distinct item order by item)
      filter (where item_type = 'PRODUCTO' and item is not null) as products,
    array_agg(distinct item order by item)
      filter (where item_type = 'SERVICIO' and item is not null) as services,
    array_agg(distinct payment_state order by payment_state)
      filter (where payment_state is not null) as payment_states,
    array_agg(distinct payment_method order by payment_method)
      filter (where payment_method is not null) as payment_methods
  from base
  group by contact_key
)
select
  1::integer as facts_version,
  a.contact_key,
  a.sale_count,
  a.revenue_lifetime,
  a.first_sale_at,
  a.last_sale_at,
  ((now() at time zone 'America/Lima')::date - a.last_sale_at)::integer as days_since_last_sale,
  a.product_count,
  a.service_count,
  a.product_revenue,
  a.service_revenue,
  coalesce(a.products, array[]::text[]) as products,
  coalesce(a.services, array[]::text[]) as services,
  r.item_type as latest_item_type,
  r.item as latest_item,
  r.branch as latest_branch,
  ua.user_id as latest_advisor_id,
  r.advisor_label as latest_advisor_label,
  coalesce(a.payment_states, array[]::text[]) as payment_states,
  coalesce(a.payment_methods, array[]::text[]) as payment_methods,
  a.last_sale_at as source_last_at
from agg a
join ranked r
  on r.contact_key = a.contact_key and r.rn = 1
left join user_alias ua
  on ua.token = upper(btrim(coalesce(r.advisor_label, '')));

comment on view public.aos_cia_sales_facts_v1 is
'CIA Commercial Facts V1 — sales plus explicit PRODUCTO/SERVICIO purchase facts per contact_key.';

-- -----------------------------------------------------------------------------
-- FOLLOW-UP FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_followup_facts_v1
with (security_invoker = true)
as
with base as (
  select
    public.aos_cia_normalize_contact_key_v1(s."NUMERO") as contact_key,
    s."ID" as id,
    case
      when btrim(coalesce(s."FECHA_PROGRAMADA", '')) ~ '^\d{4}-\d{2}-\d{2}$'
        then to_date(btrim(s."FECHA_PROGRAMADA"), 'YYYY-MM-DD')
      else null
    end as scheduled_date,
    nullif(upper(btrim(s."ESTADO")), '') as status_norm,
    nullif(btrim(s."ID_ASESOR"), '') as advisor_id,
    nullif(btrim(s."ASESOR"), '') as advisor_label,
    nullif(upper(btrim(s."TRATAMIENTO")), '') as treatment,
    s."TS_CREADO" as created_text
  from public.aos_seguimientos s
  where public.aos_cia_normalize_contact_key_v1(s."NUMERO") is not null
), ranked as (
  select b.*,
         row_number() over (
           partition by contact_key
           order by created_text desc nulls last, id desc
         ) as rn
  from base b
), agg as (
  select
    contact_key,
    count(*)::integer as followup_count,
    count(*) filter (where status_norm = 'PENDIENTE')::integer as pending_count,
    count(*) filter (
      where status_norm = 'VENCIDO'
         or (status_norm = 'PENDIENTE' and scheduled_date < (now() at time zone 'America/Lima')::date)
    )::integer as overdue_count,
    count(*) filter (where status_norm = 'COMPLETADO')::integer as completed_count,
    min(scheduled_date) filter (
      where status_norm = 'PENDIENTE'
        and scheduled_date >= (now() at time zone 'America/Lima')::date
    ) as next_followup_at,
    min(scheduled_date) filter (
      where status_norm = 'VENCIDO'
         or (status_norm = 'PENDIENTE' and scheduled_date < (now() at time zone 'America/Lima')::date)
    ) as oldest_overdue_at,
    array_agg(distinct treatment order by treatment)
      filter (where treatment is not null) as treatments,
    max(scheduled_date) as source_last_at
  from base
  group by contact_key
)
select
  1::integer as facts_version,
  a.contact_key,
  a.followup_count,
  a.pending_count,
  a.overdue_count,
  a.completed_count,
  a.next_followup_at,
  a.oldest_overdue_at,
  r.advisor_id as latest_advisor_id,
  r.advisor_label as latest_advisor_label,
  coalesce(a.treatments, array[]::text[]) as treatments,
  a.source_last_at
from agg a
join ranked r
  on r.contact_key = a.contact_key and r.rn = 1;

comment on view public.aos_cia_followup_facts_v1 is
'CIA Commercial Facts V1 — follow-up status/date facts per contact_key using read-only legacy number/date normalization.';

-- -----------------------------------------------------------------------------
-- EMAIL FACTS
-- -----------------------------------------------------------------------------
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
  select
    email,
    min(contact_key) as contact_key
  from email_candidates
  group by email
  having count(distinct contact_key) = 1
), sends_raw as (
  select
    coalesce(nullif(e.resend_id, ''), 'emails_enviados:' || e.id::text) as provider_key,
    nullif(e.resend_id, '') as resend_id,
    'aos_emails_enviados'::text as source_table,
    e.id::text as source_id,
    lower(btrim(coalesce(e.email_destino, e.destinatario))) as email,
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
    lower(btrim(e.destinatario_email)),
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
  left join identity di
    on di.contact_key = s.direct_contact_key
  left join safe_alias ea
    on ea.email = s.email
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
    on ea.email = lower(btrim(e.email_destino))
), engagement_evidence as (
  select contact_key, provider_key, 'DELIVERED'::text as kind, 1::integer as metric
  from event_mapped
  where contact_key is not null and event_type = 'email.delivered'

  union all
  select contact_key, provider_key, 'OPENED', 1
  from event_mapped
  where contact_key is not null and event_type = 'email.opened'

  union all
  select contact_key, provider_key, 'BOUNCED', 1
  from event_mapped
  where contact_key is not null and event_type = 'email.bounced'

  union all
  select contact_key, provider_key, 'CLICKED', 1
  from event_mapped
  where contact_key is not null and event_type in ('email.clicked', 'email.click')

  union all
  select contact_key, provider_key, 'OPENED', 1
  from mapped_sends
  where contact_key is not null and legacy_opened = true

  union all
  select contact_key, provider_key, 'BOUNCED', 1
  from mapped_sends
  where contact_key is not null and legacy_bounced = true

  union all
  select contact_key, provider_key, 'CLICKED', legacy_clicks
  from mapped_sends
  where contact_key is not null and legacy_clicks > 0
), evidence_dedup as (
  select contact_key, provider_key, kind, max(metric)::integer as metric
  from engagement_evidence
  group by contact_key, provider_key, kind
), engagement_agg as (
  select
    contact_key,
    count(*) filter (where kind = 'DELIVERED')::integer as delivered_count,
    count(*) filter (where kind = 'OPENED')::integer as opened_count,
    coalesce(sum(metric) filter (where kind = 'CLICKED'), 0)::integer as clicked_count,
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
'CIA Email Facts V1 — one row per Identity V1 contact. never_sent preserves UNKNOWN when safe channel identity is insufficient.';

-- -----------------------------------------------------------------------------
-- CONSOLIDATED COMMERCIAL FACTS
-- -----------------------------------------------------------------------------
create or replace view public.aos_cia_commercial_facts_v1
with (security_invoker = true)
as
select
  1::integer as facts_version,
  i.identity_version,
  i.contact_key,
  i.identity_status,
  i.canonical_patient_id,
  i.identity_conflict,

  coalesce(l.lead_count, 0)::integer as lead_count,
  l.first_lead_at,
  l.last_lead_at,
  l.days_since_last_lead,
  l.latest_lead_id,
  l.latest_interest,
  l.latest_interest_type,
  coalesce(l.interests, array[]::text[]) as lead_interests,
  coalesce(l.interest_types, array[]::text[]) as lead_interest_types,
  l.latest_ad,
  coalesce(l.ads, array[]::text[]) as lead_ads,

  coalesce(c.call_count, 0)::integer as call_count,
  (coalesce(c.call_count, 0) = 0) as calls_never_called,
  c.first_call_at,
  c.last_call_at,
  c.days_since_last_call,
  c.latest_call_id,
  c.latest_status as latest_call_status,
  c.latest_substatus as latest_call_substatus,
  c.latest_advisor_id as latest_call_advisor_id,
  c.latest_advisor_label as latest_call_advisor_label,
  c.latest_treatment as latest_call_treatment,
  coalesce(c.ever_statuses, array[]::text[]) as call_ever_statuses,
  coalesce(c.called_today, false) as called_today,
  coalesce(c.max_attempt, 0)::integer as max_call_attempt,
  coalesce(c.effective_contact_count, 0)::integer as effective_contact_count,
  coalesce(c.non_contact_count, 0)::integer as non_contact_count,

  case
    when coalesce(l.lead_count, 0) = 0 then null
    when coalesce(c.call_count, 0) = 0 then true
    else false
  end as lead_never_called,
  case
    when coalesce(l.lead_count, 0) = 0 then null
    when c.last_call_at is null then false
    else c.last_call_at >= l.last_lead_at
  end as lead_called_since_latest_entry,
  case
    when coalesce(l.lead_count, 0) = 0 then null
    when c.last_call_at is null then true
    else c.last_call_at < l.last_lead_at
  end as lead_unworked_since_latest_entry,

  coalesce(a.appointment_count, 0)::integer as appointment_count,
  (coalesce(a.appointment_count, 0) = 0) as appointments_never_had,
  a.last_appointment_at,
  a.last_appointment_status,
  a.last_treatment as last_appointment_treatment,
  a.last_branch as last_appointment_branch,
  a.next_appointment_at,
  a.next_appointment_status,
  a.next_treatment as next_appointment_treatment,
  a.next_branch as next_appointment_branch,
  coalesce(a.has_future_appointment, false) as has_future_appointment,
  coalesce(a.no_show_count, 0)::integer as no_show_count,
  coalesce(a.ever_no_show, false) as ever_no_show,
  coalesce(a.attended_count, 0)::integer as attended_count,
  a.last_attended_at,
  coalesce(a.appointment_statuses, array[]::text[]) as appointment_statuses,

  coalesce(s.sale_count, 0)::integer as sale_count,
  (coalesce(s.sale_count, 0) = 0) as sales_never_bought,
  coalesce(s.revenue_lifetime, 0)::numeric as revenue_lifetime,
  s.first_sale_at,
  s.last_sale_at,
  s.days_since_last_sale,
  coalesce(s.product_count, 0)::integer as product_count,
  coalesce(s.service_count, 0)::integer as service_count,
  coalesce(s.product_revenue, 0)::numeric as product_revenue,
  coalesce(s.service_revenue, 0)::numeric as service_revenue,
  coalesce(s.products, array[]::text[]) as products,
  coalesce(s.services, array[]::text[]) as services,
  s.latest_item_type,
  s.latest_item,
  s.latest_branch as latest_sale_branch,
  s.latest_advisor_id as latest_sale_advisor_id,
  s.latest_advisor_label as latest_sale_advisor_label,
  coalesce(s.payment_states, array[]::text[]) as payment_states,
  coalesce(s.payment_methods, array[]::text[]) as payment_methods,

  coalesce(f.followup_count, 0)::integer as followup_count,
  coalesce(f.pending_count, 0)::integer as pending_followup_count,
  coalesce(f.overdue_count, 0)::integer as overdue_followup_count,
  coalesce(f.completed_count, 0)::integer as completed_followup_count,
  f.next_followup_at,
  f.oldest_overdue_at,
  f.latest_advisor_id as latest_followup_advisor_id,
  f.latest_advisor_label as latest_followup_advisor_label,
  coalesce(f.treatments, array[]::text[]) as followup_treatments,

  e.identity_confidence as email_identity_confidence,
  coalesce(e.sent_count, 0)::integer as email_sent_count,
  e.never_sent as email_never_sent,
  e.last_sent_at as email_last_sent_at,
  e.days_since_last as email_days_since_last,
  coalesce(e.delivered_count, 0)::integer as email_delivered_count,
  coalesce(e.opened_count, 0)::integer as email_opened_count,
  coalesce(e.clicked_count, 0)::integer as email_clicked_count,
  coalesce(e.bounced_count, 0)::integer as email_bounced_count,
  e.last_event_at as email_last_event_at,

  statement_timestamp() as facts_observed_at,
  jsonb_build_object(
    'identity', jsonb_build_object('version', i.identity_version, 'status', i.identity_status),
    'lead', jsonb_build_object('rows', coalesce(l.lead_count, 0), 'latest_id', l.latest_lead_id),
    'calls', jsonb_build_object('rows', coalesce(c.call_count, 0), 'latest_id', c.latest_call_id),
    'appointments', jsonb_build_object('rows', coalesce(a.appointment_count, 0)),
    'sales', jsonb_build_object('rows', coalesce(s.sale_count, 0)),
    'followups', jsonb_build_object('rows', coalesce(f.followup_count, 0)),
    'email', jsonb_build_object('sent_rows', coalesce(e.sent_count, 0), 'identity_confidence', e.identity_confidence)
  ) as provenance
from public.aos_cia_contact_identity_v1 i
left join public.aos_cia_lead_facts_v1 l using (contact_key)
left join public.aos_cia_call_facts_v1 c using (contact_key)
left join public.aos_cia_appointment_facts_v1 a using (contact_key)
left join public.aos_cia_sales_facts_v1 s using (contact_key)
left join public.aos_cia_followup_facts_v1 f using (contact_key)
left join public.aos_cia_email_facts_v1 e using (contact_key);

comment on view public.aos_cia_commercial_facts_v1 is
'CIA Commercial Facts V1 consolidated contract. Exactly one row per Identity V1 contact_key; no multi-event joins at final grain.';

-- -----------------------------------------------------------------------------
-- PRIVILEGES: private by default. Browser exposure comes in later phases through
-- controlled RPC/backend contracts.
-- -----------------------------------------------------------------------------
revoke all on public.aos_cia_interest_taxonomy_v1 from public, anon, authenticated;
revoke all on public.aos_cia_lead_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_call_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_appointment_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_sales_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_followup_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_email_facts_v1 from public, anon, authenticated;
revoke all on public.aos_cia_commercial_facts_v1 from public, anon, authenticated;

grant select on public.aos_cia_interest_taxonomy_v1 to service_role;
grant select on public.aos_cia_lead_facts_v1 to service_role;
grant select on public.aos_cia_call_facts_v1 to service_role;
grant select on public.aos_cia_appointment_facts_v1 to service_role;
grant select on public.aos_cia_sales_facts_v1 to service_role;
grant select on public.aos_cia_followup_facts_v1 to service_role;
grant select on public.aos_cia_email_facts_v1 to service_role;
grant select on public.aos_cia_commercial_facts_v1 to service_role;

commit;
