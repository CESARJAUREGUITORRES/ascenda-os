-- Parallel read-only Marketing lead detail for validation before UI cutover.
-- Keeps the same output shape as aos_marketing_leads_detalle, but scopes
-- calls/appointments/sales to each lead touchpoint window instead of copying
-- the full phone history onto every lead row.

create or replace function public.aos_marketing_leads_detalle_v2(
  p_fecha_desde date default null,
  p_fecha_hasta date default null
)
returns table(
  lead_id bigint,
  fecha date,
  hora_ingreso timestamptz,
  celular text,
  numero_limpio text,
  tratamiento text,
  anuncio text,
  preguntas text,
  llamadas_total bigint,
  ultima_llamada timestamptz,
  ultimo_estado text,
  ultimo_asesor text,
  citas_total bigint,
  proxima_cita_fecha date,
  proxima_cita_estado text,
  ventas_total bigint,
  monto_facturado numeric,
  estado_lead text
)
language sql
stable
security invoker
as $function$
with params as (
  select coalesce(p_fecha_desde,date_trunc('month',current_date)::date) d,
         coalesce(p_fecha_hasta,current_date) h
), lead_timeline as (
  select l.*,
         coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamptz) as lead_ts,
         lead(coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamptz)) over(
           partition by l.numero_limpio
           order by coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamptz),l.id
         ) as next_lead_ts
  from public.aos_leads l
  where l.numero_limpio is not null and l.numero_limpio<>''
), lp as (
  select lt.*
  from lead_timeline lt, params p
  where lt.fecha between p.d and p.h
)
select
  lp.id::bigint,
  lp.fecha,
  lp.hora_ingreso,
  lp.celular,
  lp.numero_limpio,
  lp.tratamiento,
  lp.anuncio,
  lp.preguntas,
  coalesce(la.total_llam,0)::bigint,
  la.ultima_ts,
  la.ult_estado,
  la.ult_asesor,
  coalesce(ca.total_citas,0)::bigint,
  ca.prox_fecha,
  ca.prox_estado,
  coalesce(va.total_ventas,0)::bigint,
  coalesce(va.monto_total,0)::numeric,
  case
    when coalesce(va.total_ventas,0)>0 then 'VENDIDO'
    when coalesce(ca.total_citas,0)>0 then 'CON CITA'
    when coalesce(la.total_llam,0)>0 then 'EN GESTION'
    else 'SIN CONTACTO'
  end::text
from lp
left join lateral (
  select count(*) total_llam,
         max(coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz)) ultima_ts,
         (array_agg(ll.estado order by coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz) desc nulls last,ll.id desc))[1] ult_estado,
         (array_agg(ll.asesor order by coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz) desc nulls last,ll.id desc))[1] ult_asesor
  from public.aos_llamadas ll
  where ll.numero_limpio=lp.numero_limpio
    and (
      ll.lead_id_origen=lp.id
      or (
        ll.lead_id_origen is null
        and coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz) >= coalesce(lp.hora_ingreso,lp.created_at,lp.fecha::timestamptz)
        and (lp.next_lead_ts is null or coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz) < lp.next_lead_ts)
      )
    )
) la on true
left join lateral (
  select count(*) total_citas,
         min(c.fecha_cita) filter(where c.fecha_cita>=current_date) prox_fecha,
         (array_agg(c.estado_cita order by coalesce(c.ts_creado,c.fecha_cita::timestamptz) desc nulls last))[1] prox_estado
  from public.aos_agenda_citas c
  where c.numero_limpio=lp.numero_limpio
    and (
      c.lead_id_origen=lp.id
      or (
        c.lead_id_origen is null
        and coalesce(c.ts_creado,c.fecha_cita::timestamptz) >= coalesce(lp.hora_ingreso,lp.created_at,lp.fecha::timestamptz)
        and (lp.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz) < lp.next_lead_ts)
      )
    )
) ca on true
left join lateral (
  select count(*) total_ventas,
         sum(coalesce(v.monto::numeric,0)) monto_total
  from public.aos_ventas v
  where v.numero_limpio=lp.numero_limpio
    and v.fecha>=lp.fecha
    and (lp.next_lead_ts is null or v.fecha < lp.next_lead_ts::date)
) va on true
order by lp.fecha desc,lp.hora_ingreso desc nulls last,lp.id desc;
$function$;
