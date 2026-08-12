create or replace function public.aos_marketing_call_lead_match_v2(
  p_desde date default null,
  p_hasta date default null
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
as $$
with chain as (
  select m.cita_id,m.llamada_id,m.llamada_ts,m.numero_limpio,ll.lead_id_origen,ll.tratamiento
  from public.aos_marketing_call_cita_match_v2(p_desde,p_hasta) m
  join public.aos_llamadas ll on ll.id=m.llamada_id
  where m.metodo_match='CALL_CITA_UNICO_10M'
), counts as (
  select c.*,
    (select count(*) from public.aos_marketing_touchpoints_v2(null,null) l
      where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts) as n_prior,
    (select count(*) from public.aos_marketing_touchpoints_v2(null,null) l
      where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
        and nullif(trim(c.tratamiento),'') is not null and upper(coalesce(l.tratamiento,''))=upper(c.tratamiento)) as n_trat
  from chain c
), resolved as (
  select c.*,
    case
      when c.lead_id_origen is not null then c.lead_id_origen
      when c.n_prior=1 then (
        select l.lead_id from public.aos_marketing_touchpoints_v2(null,null) l
        where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
        order by l.lead_ts desc,l.lead_id desc limit 1)
      when c.n_prior>1 and c.n_trat=1 then (
        select l.lead_id from public.aos_marketing_touchpoints_v2(null,null) l
        where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
          and nullif(trim(c.tratamiento),'') is not null and upper(coalesce(l.tratamiento,''))=upper(c.tratamiento)
        order by l.lead_ts desc,l.lead_id desc limit 1)
      else null end as resolved_lead_id
  from counts c
)
select r.cita_id,r.llamada_id,r.llamada_ts,r.numero_limpio,r.resolved_lead_id,l.lead_ts,
       r.n_prior::bigint,r.n_trat::bigint,
       case
         when r.lead_id_origen is not null then 'DIRECT_LEAD_ID'
         when r.n_prior=1 then 'UNIQUE_PRIOR_LEAD'
         when r.n_prior>1 and r.n_trat=1 then 'UNIQUE_PRIOR_BY_TREATMENT'
         when r.n_prior=0 then 'NO_PRIOR_MARKETING_LEAD'
         else 'AMBIGUOUS_PRIOR_LEAD' end,
       case
         when r.lead_id_origen is not null then 100
         when r.n_prior=1 then 90
         when r.n_prior>1 and r.n_trat=1 then 85
         when r.n_prior=0 then 0
         else 40 end
from resolved r
left join public.aos_marketing_touchpoints_v2(null,null) l on l.lead_id=r.resolved_lead_id
order by r.llamada_ts,r.llamada_id;
$$;

revoke all on function public.aos_marketing_call_lead_match_v2(date,date) from public;
