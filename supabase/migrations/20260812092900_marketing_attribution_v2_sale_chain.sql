create or replace function public.aos_marketing_sale_attribution_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  venta_pk bigint,
  venta_id text,
  venta_fecha date,
  monto numeric,
  tratamiento_compra text,
  numero_limpio text,
  lead_id bigint,
  lead_fecha date,
  lead_anuncio text,
  lead_tratamiento text,
  llamada_id bigint,
  cita_id text,
  cita_estado text,
  metodo_match text,
  confidence integer,
  anomaly_code text
)
language sql
stable
as $$
with ventas as (
  select v.*
  from public.aos_ventas v
  where v.numero_limpio is not null and v.numero_limpio<>''
    and (p_desde is null or v.fecha>=p_desde)
    and (p_hasta is null or v.fecha<=p_hasta)
), candidates as (
  select v.id venta_pk,c.id cita_id,c.estado_cita,cl.llamada_id,cl.lead_id,cl.confidence lead_confidence,
         count(*) over(partition by v.id) candidate_citas,
         row_number() over(partition by v.id order by cl.confidence desc,c.id) rn
  from ventas v
  join public.aos_agenda_citas c
    on c.numero_limpio=v.numero_limpio
   and c.fecha_cita=v.fecha
   and upper(coalesce(c.origen_cita,''))='CALL_CENTER'
  join public.aos_marketing_call_lead_match_v2(null,null) cl
    on cl.cita_id=c.id
   and cl.lead_id is not null
   and cl.confidence>=85
), best as (
  select * from candidates where rn=1
)
select
  v.id::bigint,v.venta_id,v.fecha,v.monto,v.tratamiento,v.numero_limpio,
  case when b.candidate_citas=1 then b.lead_id else null end,
  case when b.candidate_citas=1 then l.fecha else null end,
  case when b.candidate_citas=1 then l.anuncio else null end,
  case when b.candidate_citas=1 then l.tratamiento else null end,
  case when b.candidate_citas=1 then b.llamada_id else null end,
  case when b.candidate_citas=1 then b.cita_id else null end,
  case when b.candidate_citas=1 then b.estado_cita else null end,
  case
    when b.venta_pk is null then 'SIN_MATCH'
    when b.candidate_citas>1 then 'AMBIGUOUS_CITA_SAME_DAY'
    when upper(coalesce(b.estado_cita,'')) in ('ASISTIO','EFECTIVA') then 'CALL_CITA_ATTENDED_SAME_DAY'
    when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then 'CALL_CITA_NO_SHOW_WITH_SALE'
    else 'CALL_CITA_OTHER_STATUS_WITH_SALE' end,
  case
    when b.venta_pk is null then 0
    when b.candidate_citas>1 then 40
    when upper(coalesce(b.estado_cita,'')) in ('ASISTIO','EFECTIVA') then least(b.lead_confidence,90)
    when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then least(b.lead_confidence,80)
    else least(b.lead_confidence,60) end,
  case
    when b.venta_pk is null then null
    when b.candidate_citas>1 then 'MULTIPLE_CITAS_SAME_DAY'
    when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then 'NO_SHOW_WITH_SAME_DAY_SALE'
    when upper(coalesce(b.estado_cita,'')) not in ('ASISTIO','EFECTIVA') then 'NON_ATTENDED_STATUS_WITH_SALE'
    else null end
from ventas v
left join best b on b.venta_pk=v.id
left join public.aos_leads l on l.id=b.lead_id
order by v.fecha,v.id;
$$;

revoke all on function public.aos_marketing_sale_attribution_v2(date,date) from public;
