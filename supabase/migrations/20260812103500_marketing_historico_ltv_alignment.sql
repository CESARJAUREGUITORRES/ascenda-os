-- Marketing Attribution V2
-- Align Historical monthly post/accrued revenue with acquisition-cohort LTV.
-- M0 remains touchpoint-attributed revenue. Post = all future purchases of customers acquired by the cohort.

create or replace function public.aos_marketing_historico_v2_preview(
  p_anio integer
)
returns table(
  mes integer,
  anio integer,
  touchpoints_raw bigint,
  touchpoints_efectivos bigint,
  duplicados_tecnicos_probables bigint,
  personas_unicas bigint,
  leads_gestionados bigint,
  llamadas_atribuidas bigint,
  leads_con_cita bigint,
  citas_atribuidas bigint,
  leads_con_asistencia bigint,
  asistencias_atribuidas bigint,
  clientes_m0 bigint,
  ventas_m0 bigint,
  fact_m0 numeric,
  clientes_post bigint,
  ventas_post bigint,
  fact_post numeric,
  fact_acumulado numeric,
  conversion_m0 numeric
)
language sql
stable
as $$
with horizon as (
  select case
    when p_anio < extract(year from current_date)::int then 12
    when p_anio = extract(year from current_date)::int then extract(month from current_date)::int
    else 0 end as max_mes
), months as (
  select m as mes,make_date(p_anio,m,1) d,(make_date(p_anio,m,1)+interval '1 month')::date next_d
  from horizon h,generate_series(1,h.max_mes) g(m)
), tp_raw as materialized (
  select * from public.aos_marketing_touchpoints_v2(make_date(p_anio,1,1),make_date(p_anio,12,31))
), tp as materialized (
  select * from tp_raw where not es_duplicado_tecnico_probable
), attribution as materialized (
  select * from public.aos_marketing_attribution_v2_preview(null,null)
  where lead_fecha>=make_date(p_anio,1,1) and lead_fecha<make_date(p_anio+1,1,1)
), acquisition as materialized (
  select * from public.aos_marketing_acquisition_customers_v2()
  where lead_fecha>=make_date(p_anio,1,1) and lead_fecha<make_date(p_anio+1,1,1)
), tp_stats as (
  select m.mes,
    count(r.lead_id) touchpoints_raw,
    count(r.lead_id) filter(where not r.es_duplicado_tecnico_probable) touchpoints_efectivos,
    count(r.lead_id) filter(where r.es_duplicado_tecnico_probable) duplicados,
    count(distinct r.numero_limpio) filter(where not r.es_duplicado_tecnico_probable) personas
  from months m left join tp_raw r on r.fecha>=m.d and r.fecha<m.next_d
  group by m.mes
), event_stats as (
  select m.mes,
    count(*) filter(where s.n_llamadas>0) leads_gestionados,
    coalesce(sum(s.n_llamadas),0) llamadas,
    count(*) filter(where s.n_citas>0) leads_con_cita,
    coalesce(sum(s.n_citas),0) citas,
    count(*) filter(where s.n_asist>0) leads_con_asistencia,
    coalesce(sum(s.n_asist),0) asistencias
  from months m
  left join lateral (
    select t.lead_id,
      (select count(*) from public.aos_llamadas ll
       where ll.numero_limpio=t.numero_limpio
         and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)>=t.lead_ts
         and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<m.next_d::timestamptz
         and (ll.lead_id_origen=t.lead_id or (ll.lead_id_origen is null and (t.next_lead_ts is null or public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<t.next_lead_ts)))) n_llamadas,
      (select count(*) from public.aos_agenda_citas c
       where c.numero_limpio=t.numero_limpio
         and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=t.lead_ts
         and c.fecha_cita<m.next_d
         and (c.lead_id_origen=t.lead_id or (c.lead_id_origen is null and (t.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<t.next_lead_ts)))) n_citas,
      (select count(*) from public.aos_agenda_citas c
       where c.numero_limpio=t.numero_limpio
         and upper(coalesce(c.estado_cita,'')) in ('ASISTIO','EFECTIVA')
         and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=t.lead_ts
         and c.fecha_cita<m.next_d
         and (c.lead_id_origen=t.lead_id or (c.lead_id_origen is null and (t.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<t.next_lead_ts)))) n_asist
    from tp t where t.fecha>=m.d and t.fecha<m.next_d
  ) s on true
  group by m.mes
), m0_stats as (
  select m.mes,
    count(distinct a.lead_id) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d) clientes_m0,
    count(*) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d) ventas_m0,
    coalesce(sum(a.monto) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d),0) fact_m0
  from months m
  left join attribution a on a.lead_fecha>=m.d and a.lead_fecha<m.next_d
  group by m.mes
), post_ltv as (
  select m.mes,
    count(distinct ac.numero_limpio) filter(where v.fecha>=m.next_d) clientes_post,
    count(v.id) filter(where v.fecha>=m.next_d) ventas_post,
    coalesce(sum(v.monto) filter(where v.fecha>=m.next_d),0) fact_post
  from months m
  left join acquisition ac on ac.lead_fecha>=m.d and ac.lead_fecha<m.next_d
  left join public.aos_ventas v on v.numero_limpio=ac.numero_limpio and v.fecha>=ac.first_sale_date
  group by m.mes
)
select m.mes,p_anio,
  coalesce(ts.touchpoints_raw,0)::bigint,coalesce(ts.touchpoints_efectivos,0)::bigint,
  coalesce(ts.duplicados,0)::bigint,coalesce(ts.personas,0)::bigint,
  coalesce(es.leads_gestionados,0)::bigint,coalesce(es.llamadas,0)::bigint,
  coalesce(es.leads_con_cita,0)::bigint,coalesce(es.citas,0)::bigint,
  coalesce(es.leads_con_asistencia,0)::bigint,coalesce(es.asistencias,0)::bigint,
  coalesce(ms.clientes_m0,0)::bigint,coalesce(ms.ventas_m0,0)::bigint,coalesce(ms.fact_m0,0)::numeric,
  coalesce(pl.clientes_post,0)::bigint,coalesce(pl.ventas_post,0)::bigint,coalesce(pl.fact_post,0)::numeric,
  (coalesce(ms.fact_m0,0)+coalesce(pl.fact_post,0))::numeric,
  case when coalesce(ts.personas,0)>0 then round(coalesce(ms.clientes_m0,0)::numeric/ts.personas*100,2) else 0 end
from months m
left join tp_stats ts on ts.mes=m.mes
left join event_stats es on es.mes=m.mes
left join m0_stats ms on ms.mes=m.mes
left join post_ltv pl on pl.mes=m.mes
order by m.mes;
$$;

revoke execute on function public.aos_marketing_historico_v2_preview(integer) from public,anon,authenticated;
