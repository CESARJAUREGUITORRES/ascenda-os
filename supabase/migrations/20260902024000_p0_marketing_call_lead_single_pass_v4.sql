-- ASCENDA OS · Marketing P0.4
-- Replace repeated scans of the global touchpoint CTE in aos_marketing_call_lead_match_v2
-- with one phone-scoped dedupe + aggregation pass.
-- Business semantics are intentionally unchanged.

create or replace function public.aos_marketing_call_lead_match_v2(
  p_desde date default null::date,
  p_hasta date default null::date
)
returns table(
  cita_id text,
  llamada_id bigint,
  llamada_ts timestamptz,
  numero_limpio text,
  lead_id bigint,
  lead_ts timestamptz,
  candidatos_previos bigint,
  candidatos_tratamiento bigint,
  metodo_match text,
  confidence integer
)
language sql
stable
as $function$
with chain as materialized (
  select
    m.cita_id,
    m.llamada_id,
    m.llamada_ts,
    m.numero_limpio,
    ll.lead_id_origen,
    ll.tratamiento
  from public.aos_marketing_call_cita_match_v2(p_desde,p_hasta) m
  join public.aos_llamadas ll on ll.id=m.llamada_id
  where m.metodo_match in ('CALL_CITA_UNICO_10M','DIRECT_LLAMADA_ID')
),
phones as materialized (
  select distinct numero_limpio
  from chain
  where numero_limpio is not null and numero_limpio<>''
),
tp_base as materialized (
  select
    l.id::bigint lead_id,
    l.numero_limpio,
    public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) lead_ts,
    l.tratamiento,
    row_number() over(
      partition by
        l.numero_limpio,
        l.fecha,
        l.hora_ingreso,
        coalesce(l.tratamiento,''),
        coalesce(l.anuncio,''),
        l.created_at
      order by l.id
    ) dup_rank
  from public.aos_leads l
  join phones p on p.numero_limpio=l.numero_limpio
  where l.numero_limpio is not null and l.numero_limpio<>''
),
tp as materialized (
  select lead_id,numero_limpio,lead_ts,tratamiento
  from tp_base
  where dup_rank=1
),
agg as materialized (
  select
    c.cita_id,
    c.llamada_id,
    c.llamada_ts,
    c.numero_limpio,
    c.lead_id_origen,
    c.tratamiento,
    count(t.lead_id)::bigint n_prior,
    count(t.lead_id) filter (
      where nullif(trim(c.tratamiento),'') is not null
        and upper(coalesce(t.tratamiento,''))=upper(c.tratamiento)
    )::bigint n_trat,
    (array_agg(t.lead_id order by t.lead_ts desc,t.lead_id desc)
      filter (where t.lead_id is not null))[1] latest_prior_lead_id,
    (array_agg(t.lead_id order by t.lead_ts desc,t.lead_id desc)
      filter (
        where t.lead_id is not null
          and nullif(trim(c.tratamiento),'') is not null
          and upper(coalesce(t.tratamiento,''))=upper(c.tratamiento)
      ))[1] latest_trat_lead_id
  from chain c
  left join tp t
    on t.numero_limpio=c.numero_limpio
   and t.lead_ts<=c.llamada_ts
  group by
    c.cita_id,c.llamada_id,c.llamada_ts,c.numero_limpio,c.lead_id_origen,c.tratamiento
),
resolved as (
  select
    a.*,
    case
      when a.lead_id_origen is not null then a.lead_id_origen
      when a.n_prior=1 then a.latest_prior_lead_id
      when a.n_prior>1 and a.n_trat=1 then a.latest_trat_lead_id
      else null
    end resolved_lead_id
  from agg a
)
select
  r.cita_id,
  r.llamada_id,
  r.llamada_ts,
  r.numero_limpio,
  r.resolved_lead_id::bigint lead_id,
  public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) lead_ts,
  r.n_prior::bigint candidatos_previos,
  r.n_trat::bigint candidatos_tratamiento,
  case
    when r.lead_id_origen is not null then 'DIRECT_LEAD_ID'
    when r.n_prior=1 then 'UNIQUE_PRIOR_LEAD'
    when r.n_prior>1 and r.n_trat=1 then 'UNIQUE_PRIOR_BY_TREATMENT'
    when r.n_prior=0 then 'NO_PRIOR_MARKETING_LEAD'
    else 'AMBIGUOUS_PRIOR_LEAD'
  end::text metodo_match,
  case
    when r.lead_id_origen is not null then 100
    when r.n_prior=1 then 90
    when r.n_prior>1 and r.n_trat=1 then 85
    when r.n_prior=0 then 0
    else 40
  end::integer confidence
from resolved r
left join public.aos_leads l on l.id=r.resolved_lead_id
order by r.llamada_ts,r.llamada_id;
$function$;

comment on function public.aos_marketing_call_lead_match_v2(date,date) is
  'Marketing attribution call-to-lead resolver. P0.4 preserves V2 match/confidence semantics while using phone-scoped single-pass touchpoint aggregation.';
