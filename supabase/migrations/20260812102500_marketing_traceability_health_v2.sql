create or replace function public.aos_marketing_traceability_health_v2(
  p_desde date,
  p_hasta date
)
returns table(
  fecha date,
  llamadas_total bigint,
  llamadas_con_lead_id bigint,
  llamadas_cobertura_pct numeric,
  citas_callcenter bigint,
  citas_callcenter_con_lead_id bigint,
  citas_cobertura_pct numeric
)
language sql
stable
as $$
with days as (
  select generate_series(p_desde,p_hasta,interval '1 day')::date fecha
), calls as (
  select ll.fecha,
         count(*)::bigint total,
         count(*) filter(where ll.lead_id_origen is not null)::bigint con_id
  from public.aos_llamadas ll
  where ll.fecha between p_desde and p_hasta
  group by ll.fecha
), citas as (
  select c.fecha_cita fecha,
         count(*)::bigint total,
         count(*) filter(where c.lead_id_origen is not null)::bigint con_id
  from public.aos_agenda_citas c
  where c.fecha_cita between p_desde and p_hasta
    and upper(coalesce(c.origen_cita,''))='CALL_CENTER'
  group by c.fecha_cita
)
select d.fecha,
       coalesce(ca.total,0)::bigint,
       coalesce(ca.con_id,0)::bigint,
       case when coalesce(ca.total,0)>0 then round(ca.con_id::numeric/ca.total*100,2) else null end,
       coalesce(ci.total,0)::bigint,
       coalesce(ci.con_id,0)::bigint,
       case when coalesce(ci.total,0)>0 then round(ci.con_id::numeric/ci.total*100,2) else null end
from days d
left join calls ca using(fecha)
left join citas ci using(fecha)
order by d.fecha;
$$;

revoke execute on function public.aos_marketing_traceability_health_v2(date,date) from public,anon,authenticated;
