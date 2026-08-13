-- ASCENDA OS — CIA Phase 2 Commercial Facts
-- Read-only audit. Safe to run on live Supabase. No DDL/DML.

-- 1) Core source volume and normalization quality.
with x as (
  select 'leads' src, numero_limpio raw from aos_leads
  union all select 'calls', numero_limpio from aos_llamadas
  union all select 'appointments', numero_limpio from aos_agenda_citas
  union all select 'sales', numero_limpio from aos_ventas
), n as (
  select src,
    case
      when length(regexp_replace(coalesce(raw,''),'\D','','g'))=9
        then regexp_replace(coalesce(raw,''),'\D','','g')
      when length(regexp_replace(coalesce(raw,''),'\D','','g'))=11
       and left(regexp_replace(coalesce(raw,''),'\D','','g'),2)='51'
        then right(regexp_replace(coalesce(raw,''),'\D','','g'),9)
    end contact_key
  from x
)
select src, count(*) rows, count(*) filter(where contact_key is not null) valid_rows,
       count(distinct contact_key) filter(where contact_key is not null) contacts
from n group by src order by src;

-- 2) Contact history vs current lead opportunity.
with l as (
  select
    case
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9
        then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11
       and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51'
        then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
    end contact_key,
    max(coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima')) last_lead_at
  from aos_leads
  group by 1
), c as (
  select
    case
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9
        then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11
       and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51'
        then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
    end contact_key,
    max(created_at) last_call_at
  from aos_llamadas
  group by 1
)
select
  count(*) filter(where l.contact_key is not null) lead_contacts,
  count(*) filter(where l.contact_key is not null and c.last_call_at is null) never_called_lifetime,
  count(*) filter(where l.contact_key is not null and (c.last_call_at is null or c.last_call_at < l.last_lead_at)) unworked_since_latest_entry,
  count(*) filter(where l.contact_key is not null and c.last_call_at >= l.last_lead_at) called_since_latest_entry
from l left join c using(contact_key);

-- 3) Current operational status distributions.
select 'calls' domain, coalesce(estado,'<NULL>') state, count(*) n
from aos_llamadas group by estado
union all
select 'appointments', coalesce(estado_cita,'<NULL>'), count(*)
from aos_agenda_citas group by estado_cita
union all
select 'sales_type', coalesce(tipo,'<NULL>'), count(*)
from aos_ventas group by tipo
union all
select 'followups', coalesce("ESTADO",'<NULL>'), count(*)
from aos_seguimientos group by "ESTADO"
order by domain,n desc;

-- 4) Follow-up parseability.
select
  count(*) total,
  count(*) filter(where btrim(coalesce("FECHA_PROGRAMADA",'')) ~ '^\d{4}-\d{2}-\d{2}$') iso_dates,
  count(*) filter(where not btrim(coalesce("FECHA_PROGRAMADA",'')) ~ '^\d{4}-\d{2}-\d{2}$') non_iso_dates
from aos_seguimientos;

-- 5) Email send identity reconciliation baseline using safe canonical patient email.
with pn as (
  select p.*,
    case
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9
        then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11
       and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51'
        then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
    end contact_key
  from aos_pacientes p
), ps as (
  select contact_key,
         count(*) filter(where upper(coalesce("ESTADO_PACIENTE",''))<>'FUSIONADO') non_fused
  from pn where contact_key is not null group by contact_key
), pc as (
  select distinct on (pn.contact_key)
    pn.contact_key, lower(btrim(pn."Email")) email
  from pn join ps using(contact_key)
  where ps.non_fused=1
    and upper(coalesce(pn."ESTADO_PACIENTE",''))<>'FUSIONADO'
  order by pn.contact_key,pn.updated_at desc nulls last,pn.created_at desc nulls last,pn."ID_PACIENTE" desc
), emap as (
  select email,min(contact_key) contact_key,count(distinct contact_key) nkeys
  from pc
  where email is not null and email<>''
    and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  group by email
), sends0 as (
  select coalesce(resend_id,'emails_enviados:'||id::text) provider_key,
         lower(btrim(coalesce(email_destino,destinatario))) email
  from aos_emails_enviados
  union all
  select coalesce(resend_id,'email_envios:'||id::text), lower(btrim(destinatario_email))
  from aos_email_envios where lower(btrim(coalesce(estado,'')))='enviado'
), sends as (
  select distinct on(provider_key) * from sends0 order by provider_key
), mapped as (
  select s.*,e.contact_key
  from sends s left join emap e on e.email=s.email and e.nkeys=1
)
select
  (select count(*) from emap where nkeys=1) safe_email_contacts,
  count(*) total_unique_sends,
  count(*) filter(where contact_key is not null) mapped_sends,
  count(*) filter(where contact_key is null) unresolved_sends,
  count(distinct contact_key) filter(where contact_key is not null) contacts_with_send
from mapped;

-- 6) Email provider event distribution.
select coalesce(tipo_evento,'<NULL>') event_type,count(*) n
from aos_email_eventos group by tipo_evento order by n desc;

-- 7) Representative latest-call benchmark used by the facts layer.
explain (analyze,buffers,format json)
with base as (
  select
    case
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9
        then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
      when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11
       and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51'
        then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
    end contact_key,
    id,created_at,fecha,estado
  from aos_llamadas
), ranked as (
  select *,row_number() over(partition by contact_key order by created_at desc,fecha desc,id desc) rn
  from base where contact_key is not null
)
select count(*) from ranked where rn=1;
