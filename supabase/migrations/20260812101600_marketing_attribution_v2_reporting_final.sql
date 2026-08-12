-- ASCENDA OS — Marketing Attribution V2 canonical reporting state
-- Reporting/read-model functions. Internal until UI cutover is explicitly approved.

create or replace function public.aos_marketing_historico_v2_preview(p_anio integer)
returns table(
  mes integer,anio integer,touchpoints_raw bigint,touchpoints_efectivos bigint,duplicados_tecnicos_probables bigint,personas_unicas bigint,
  leads_gestionados bigint,llamadas_atribuidas bigint,leads_con_cita bigint,citas_atribuidas bigint,leads_con_asistencia bigint,asistencias_atribuidas bigint,
  clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acumulado numeric,conversion_m0 numeric
)
language sql
stable
as $$
with horizon as (
  select case when p_anio<extract(year from current_date)::int then 12
              when p_anio=extract(year from current_date)::int then extract(month from current_date)::int
              else 0 end max_mes
), months as (
  select m mes,make_date(p_anio,m,1) d,(make_date(p_anio,m,1)+interval '1 month')::date next_d
  from horizon h,generate_series(1,h.max_mes) g(m)
), tp_raw as materialized (
  select * from public.aos_marketing_touchpoints_v2(make_date(p_anio,1,1),make_date(p_anio,12,31))
), tp as materialized (
  select * from tp_raw where not es_duplicado_tecnico_probable
), attribution as materialized (
  select * from public.aos_marketing_attribution_v2_preview(null,null)
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
), sale_stats as (
  select m.mes,
    count(distinct a.lead_id) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d) clientes_m0,
    count(*) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d) ventas_m0,
    coalesce(sum(a.monto) filter(where a.venta_fecha>=m.d and a.venta_fecha<m.next_d),0) fact_m0,
    count(distinct a.lead_id) filter(where a.venta_fecha>=m.next_d) clientes_post,
    count(*) filter(where a.venta_fecha>=m.next_d) ventas_post,
    coalesce(sum(a.monto) filter(where a.venta_fecha>=m.next_d),0) fact_post
  from months m
  left join attribution a on a.lead_fecha>=m.d and a.lead_fecha<m.next_d
  group by m.mes
)
select m.mes,p_anio,
  coalesce(ts.touchpoints_raw,0)::bigint,coalesce(ts.touchpoints_efectivos,0)::bigint,coalesce(ts.duplicados,0)::bigint,coalesce(ts.personas,0)::bigint,
  coalesce(es.leads_gestionados,0)::bigint,coalesce(es.llamadas,0)::bigint,coalesce(es.leads_con_cita,0)::bigint,coalesce(es.citas,0)::bigint,
  coalesce(es.leads_con_asistencia,0)::bigint,coalesce(es.asistencias,0)::bigint,
  coalesce(ss.clientes_m0,0)::bigint,coalesce(ss.ventas_m0,0)::bigint,coalesce(ss.fact_m0,0)::numeric,
  coalesce(ss.clientes_post,0)::bigint,coalesce(ss.ventas_post,0)::bigint,coalesce(ss.fact_post,0)::numeric,
  (coalesce(ss.fact_m0,0)+coalesce(ss.fact_post,0))::numeric,
  case when coalesce(ts.personas,0)>0 then round(coalesce(ss.clientes_m0,0)::numeric/ts.personas*100,2) else 0 end
from months m
left join tp_stats ts on ts.mes=m.mes
left join event_stats es on es.mes=m.mes
left join sale_stats ss on ss.mes=m.mes
order by m.mes;
$$;

create or replace function public.aos_marketing_anuncios_v2_preview(
  p_mes integer,p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(
  total_rows bigint,anuncio text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,
  leads_gestionados bigint,llamadas bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,
  clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,
  pct_cita numeric,pct_asistencia numeric,pct_conversion_m0 numeric
)
language sql
stable
as $$
with params as (select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd),
raw as materialized (select * from public.aos_marketing_touchpoints_v2((select d from params),((select nd from params)-1))),
eff as materialized (select * from raw where not es_duplicado_tecnico_probable),
detail as materialized (
  select d.*,e.lead_ts,e.next_lead_ts
  from public.aos_marketing_leads_detalle_v2((select d from params),((select nd from params)-1)) d
  join eff e on e.lead_id=d.lead_id
),
att as materialized (
  select e.lead_id,
    (select count(*) from public.aos_agenda_citas c
      where c.numero_limpio=e.numero_limpio and upper(coalesce(c.estado_cita,'')) in ('ASISTIO','EFECTIVA')
        and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=e.lead_ts
        and (e.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<e.next_lead_ts))::bigint asistencias
  from eff e
),
attrs as materialized (select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p where a.lead_fecha>=p.d and a.lead_fecha<p.nd),
names as (select distinct coalesce(nullif(trim(anuncio),''),'SIN ANUNCIO') anuncio from eff),
metrics as (
  select n.anuncio,
    (select count(*) from raw r where coalesce(nullif(trim(r.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint touch_raw,
    (select count(*) from eff e where coalesce(nullif(trim(e.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint touch_eff,
    (select count(distinct e.numero_limpio) from eff e where coalesce(nullif(trim(e.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint personas,
    (select count(*) from detail d where coalesce(nullif(trim(d.anuncio),''),'SIN ANUNCIO')=n.anuncio and d.llamadas_total>0)::bigint gestionados,
    (select coalesce(sum(d.llamadas_total),0) from detail d where coalesce(nullif(trim(d.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint llamadas,
    (select count(*) from detail d where coalesce(nullif(trim(d.anuncio),''),'SIN ANUNCIO')=n.anuncio and d.citas_total>0)::bigint leads_cita,
    (select coalesce(sum(d.citas_total),0) from detail d where coalesce(nullif(trim(d.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint citas,
    (select count(*) from eff e join att x on x.lead_id=e.lead_id where coalesce(nullif(trim(e.anuncio),''),'SIN ANUNCIO')=n.anuncio and x.asistencias>0)::bigint leads_asist,
    (select coalesce(sum(x.asistencias),0) from eff e join att x on x.lead_id=e.lead_id where coalesce(nullif(trim(e.anuncio),''),'SIN ANUNCIO')=n.anuncio)::bigint asistencias,
    (select count(distinct a.lead_id) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::bigint cli_m0,
    (select count(*) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::bigint ven_m0,
    (select coalesce(sum(a.monto),0) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::numeric fact_m0,
    (select count(distinct a.lead_id) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.nd)::bigint cli_post,
    (select count(*) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.nd)::bigint ven_post,
    (select coalesce(sum(a.monto),0) from attrs a,params p where coalesce(nullif(trim(a.lead_anuncio),''),'SIN ANUNCIO')=n.anuncio and a.venta_fecha>=p.nd)::numeric fact_post
  from names n
), filtered as (
  select m.*,(m.fact_m0+m.fact_post)::numeric fact_acum from metrics m
  where coalesce(trim(p_search),'')='' or m.anuncio ilike '%'||trim(p_search)||'%'
), ranked as (
  select f.*,count(*) over() total_rows,
    case when f.touch_eff>0 then round(f.leads_cita::numeric/f.touch_eff*100,2) else 0 end pct_cita,
    case when f.leads_cita>0 then round(f.leads_asist::numeric/f.leads_cita*100,2) else 0 end pct_asist,
    case when f.personas>0 then round(f.cli_m0::numeric/f.personas*100,2) else 0 end pct_conv
  from filtered f
)
select r.total_rows,r.anuncio,r.touch_raw,r.touch_eff,r.personas,r.gestionados,r.llamadas,r.leads_cita,r.citas,r.leads_asist,r.asistencias,
       r.cli_m0,r.ven_m0,r.fact_m0,r.cli_post,r.ven_post,r.fact_post,r.fact_acum,r.pct_cita,r.pct_asist,r.pct_conv
from ranked r
order by case when p_order='leads' then r.touch_eff end desc nulls last,
         case when p_order='citas' then r.citas end desc nulls last,
         case when p_order='fact_m0' then r.fact_m0 end desc nulls last,
         case when p_order='conversion' then r.pct_conv end desc nulls last,
         r.fact_acum desc,r.anuncio
limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.aos_marketing_campanas_v2_preview(
  p_mes integer,p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(
  total_rows bigint,tratamiento text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,
  leads_gestionados bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,
  clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,
  inversion numeric,cpl numeric,roas_m0 numeric,roas_acum numeric
)
language sql
stable
as $$
with params as (select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd),
raw as materialized (select * from public.aos_marketing_touchpoints_v2((select d from params),((select nd from params)-1))),
eff as materialized (select * from raw where not es_duplicado_tecnico_probable),
detail as materialized (
  select d.*,e.lead_ts,e.next_lead_ts
  from public.aos_marketing_leads_detalle_v2((select d from params),((select nd from params)-1)) d
  join eff e on e.lead_id=d.lead_id
),
att as materialized (
  select e.lead_id,
    (select count(*) from public.aos_agenda_citas c where c.numero_limpio=e.numero_limpio and upper(coalesce(c.estado_cita,'')) in ('ASISTIO','EFECTIVA')
      and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=e.lead_ts and (e.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<e.next_lead_ts))::bigint asistencias
  from eff e
),
attrs as materialized (select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p where a.lead_fecha>=p.d and a.lead_fecha<p.nd),
names as (select distinct upper(coalesce(nullif(trim(tratamiento),''),'SIN TRATAMIENTO')) tratamiento from eff),
metrics as (
  select n.tratamiento,
    (select count(*) from raw r where upper(coalesce(nullif(trim(r.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento)::bigint touch_raw,
    (select count(*) from eff e where upper(coalesce(nullif(trim(e.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento)::bigint touch_eff,
    (select count(distinct e.numero_limpio) from eff e where upper(coalesce(nullif(trim(e.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento)::bigint personas,
    (select count(*) from detail d where upper(coalesce(nullif(trim(d.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and d.llamadas_total>0)::bigint gestionados,
    (select count(*) from detail d where upper(coalesce(nullif(trim(d.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and d.citas_total>0)::bigint leads_cita,
    (select coalesce(sum(d.citas_total),0) from detail d where upper(coalesce(nullif(trim(d.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento)::bigint citas,
    (select count(*) from eff e join att x on x.lead_id=e.lead_id where upper(coalesce(nullif(trim(e.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and x.asistencias>0)::bigint leads_asist,
    (select coalesce(sum(x.asistencias),0) from eff e join att x on x.lead_id=e.lead_id where upper(coalesce(nullif(trim(e.tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento)::bigint asistencias,
    (select count(distinct a.lead_id) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::bigint cli_m0,
    (select count(*) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::bigint ven_m0,
    (select coalesce(sum(a.monto),0) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.d and a.venta_fecha<p.nd)::numeric fact_m0,
    (select count(distinct a.lead_id) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.nd)::bigint cli_post,
    (select count(*) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.nd)::bigint ven_post,
    (select coalesce(sum(a.monto),0) from attrs a,params p where upper(coalesce(nullif(trim(a.lead_tratamiento),''),'SIN TRATAMIENTO'))=n.tratamiento and a.venta_fecha>=p.nd)::numeric fact_post,
    coalesce((select sum(ic.inversion) from public.aos_inversion_campanas ic where ic.mes_num=p_mes and ic.anio=p_anio and upper(trim(ic.tratamiento))=n.tratamiento),0)::numeric inversion
  from names n
), filtered as (
  select m.*,(m.fact_m0+m.fact_post)::numeric fact_acum from metrics m
  where coalesce(trim(p_search),'')='' or m.tratamiento ilike '%'||trim(p_search)||'%'
), ranked as (
  select f.*,count(*) over() total_rows,
    case when f.touch_eff>0 and f.inversion>0 then round(f.inversion/f.touch_eff,2) else null end cpl,
    case when f.inversion>0 then round(f.fact_m0/f.inversion,2) else null end roas_m0,
    case when f.inversion>0 then round(f.fact_acum/f.inversion,2) else null end roas_acum
  from filtered f
)
select r.total_rows,r.tratamiento,r.touch_raw,r.touch_eff,r.personas,r.gestionados,r.leads_cita,r.citas,r.leads_asist,r.asistencias,
       r.cli_m0,r.ven_m0,r.fact_m0,r.cli_post,r.ven_post,r.fact_post,r.fact_acum,r.inversion,r.cpl,r.roas_m0,r.roas_acum
from ranked r
order by case when p_order='leads' then r.touch_eff end desc nulls last,
         case when p_order='citas' then r.citas end desc nulls last,
         case when p_order='fact_m0' then r.fact_m0 end desc nulls last,
         case when p_order='roas' then r.roas_acum end desc nulls last,
         r.fact_acum desc,r.tratamiento
limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.aos_marketing_periodos_v2_preview()
returns table(anio integer,mes integer,leads_raw bigint,personas_unicas bigint,inversion numeric,tiene_leads boolean,tiene_inversion boolean)
language sql
stable
as $$
with lead_periods as (
  select extract(year from fecha)::int anio,extract(month from fecha)::int mes,count(*)::bigint leads_raw,count(distinct numero_limpio)::bigint personas
  from public.aos_leads where fecha is not null group by 1,2
), inv_periods as (
  select anio,mes_num mes,coalesce(sum(inversion),0)::numeric inversion
  from public.aos_inversion_campanas where anio is not null and mes_num between 1 and 12 group by anio,mes_num
), periods as (
  select anio,mes from lead_periods union select anio,mes from inv_periods
)
select p.anio,p.mes,coalesce(l.leads_raw,0)::bigint,coalesce(l.personas,0)::bigint,coalesce(i.inversion,0)::numeric,
       (coalesce(l.leads_raw,0)>0),(coalesce(i.inversion,0)>0)
from periods p
left join lead_periods l using(anio,mes)
left join inv_periods i using(anio,mes)
order by p.anio desc,p.mes desc;
$$;

create or replace function public.aos_marketing_acquisition_customers_v2()
returns table(numero_limpio text,lead_id bigint,lead_fecha date,lead_anuncio text,lead_tratamiento text,first_sale_date date,attribution_method text,confidence integer)
language sql
stable
as $$
with attrs as materialized (select * from public.aos_marketing_attribution_v2_preview(null,null)),
first_sale as (
  select numero_limpio,min(fecha) first_sale_date from public.aos_ventas
  where numero_limpio is not null and numero_limpio<>'' group by numero_limpio
), candidates as (
  select a.numero_limpio,a.lead_id,a.lead_fecha,a.lead_anuncio,a.lead_tratamiento,f.first_sale_date,a.metodo_match,a.confidence,
         row_number() over(partition by a.numero_limpio order by a.confidence desc,a.lead_fecha desc,a.lead_id) rn
  from attrs a join first_sale f on f.numero_limpio=a.numero_limpio and a.venta_fecha=f.first_sale_date
)
select c.numero_limpio,c.lead_id,c.lead_fecha,c.lead_anuncio,c.lead_tratamiento,c.first_sale_date,c.metodo_match,c.confidence
from candidates c where c.rn=1;
$$;

create or replace function public.aos_marketing_cohortes_ltv_v2_preview(p_anio integer)
returns table(
  mes integer,anio integer,personas_unicas bigint,touchpoints_efectivos bigint,clientes_adquiridos bigint,clientes_adquiridos_m0 bigint,inversion numeric,
  m0 numeric,m1 numeric,m2 numeric,m3 numeric,m4plus numeric,ltv_total numeric,cac_adquisicion numeric,roas_m0 numeric,roas_ltv numeric,
  m0_estado text,m1_estado text,m2_estado text,m3_estado text
)
language sql
stable
as $$
with months as (
  select m mes,make_date(p_anio,m,1) cohort_start,(make_date(p_anio,m,1)+interval '1 month')::date cohort_next
  from generate_series(1,12) g(m) where make_date(p_anio,m,1)<=date_trunc('month',current_date)::date
), tp as materialized (
  select * from public.aos_marketing_touchpoints_v2(make_date(p_anio,1,1),make_date(p_anio,12,31)) where not es_duplicado_tecnico_probable
), acq as materialized (
  select * from public.aos_marketing_acquisition_customers_v2()
  where lead_fecha>=make_date(p_anio,1,1) and lead_fecha<make_date(p_anio+1,1,1)
), sales as materialized (
  select v.numero_limpio,v.fecha,v.monto from public.aos_ventas v where v.numero_limpio is not null and v.numero_limpio<>''
), base as (
  select m.*,
    (select count(distinct t.numero_limpio) from tp t where t.fecha>=m.cohort_start and t.fecha<m.cohort_next)::bigint personas,
    (select count(*) from tp t where t.fecha>=m.cohort_start and t.fecha<m.cohort_next)::bigint touchpoints,
    (select count(*) from acq a where a.lead_fecha>=m.cohort_start and a.lead_fecha<m.cohort_next)::bigint adquiridos,
    (select count(*) from acq a where a.lead_fecha>=m.cohort_start and a.lead_fecha<m.cohort_next and a.first_sale_date<m.cohort_next)::bigint adquiridos_m0,
    coalesce((select sum(i.inversion) from public.aos_inversion_campanas i where i.anio=p_anio and i.mes_num=m.mes),0)::numeric inversion
  from months m
), revenue as (
  select b.mes,
    coalesce(sum(s.monto) filter(where ((extract(year from s.fecha)::int-extract(year from a.lead_fecha)::int)*12+extract(month from s.fecha)::int-extract(month from a.lead_fecha)::int)=0),0)::numeric m0,
    coalesce(sum(s.monto) filter(where ((extract(year from s.fecha)::int-extract(year from a.lead_fecha)::int)*12+extract(month from s.fecha)::int-extract(month from a.lead_fecha)::int)=1),0)::numeric m1,
    coalesce(sum(s.monto) filter(where ((extract(year from s.fecha)::int-extract(year from a.lead_fecha)::int)*12+extract(month from s.fecha)::int-extract(month from a.lead_fecha)::int)=2),0)::numeric m2,
    coalesce(sum(s.monto) filter(where ((extract(year from s.fecha)::int-extract(year from a.lead_fecha)::int)*12+extract(month from s.fecha)::int-extract(month from a.lead_fecha)::int)=3),0)::numeric m3,
    coalesce(sum(s.monto) filter(where ((extract(year from s.fecha)::int-extract(year from a.lead_fecha)::int)*12+extract(month from s.fecha)::int-extract(month from a.lead_fecha)::int)>=4),0)::numeric m4plus,
    coalesce(sum(s.monto),0)::numeric ltv_total
  from base b
  left join acq a on a.lead_fecha>=b.cohort_start and a.lead_fecha<b.cohort_next
  left join sales s on s.numero_limpio=a.numero_limpio and s.fecha>=a.first_sale_date
  group by b.mes
)
select b.mes,p_anio,b.personas,b.touchpoints,b.adquiridos,b.adquiridos_m0,b.inversion,r.m0,
       case when b.cohort_start+interval '1 month'<=current_date then r.m1 else null end,
       case when b.cohort_start+interval '2 month'<=current_date then r.m2 else null end,
       case when b.cohort_start+interval '3 month'<=current_date then r.m3 else null end,
       case when b.cohort_start+interval '4 month'<=current_date then r.m4plus else null end,
       r.ltv_total,
       case when b.adquiridos>0 and b.inversion>0 then round(b.inversion/b.adquiridos,2) else null end,
       case when b.inversion>0 then round(r.m0/b.inversion,2) else null end,
       case when b.inversion>0 then round(r.ltv_total/b.inversion,2) else null end,
       case when b.cohort_next<=current_date then 'COMPLETE' else 'PARTIAL' end,
       case when b.cohort_start+interval '2 month'<=current_date then 'COMPLETE' when b.cohort_start+interval '1 month'<=current_date then 'PARTIAL' else 'FUTURE' end,
       case when b.cohort_start+interval '3 month'<=current_date then 'COMPLETE' when b.cohort_start+interval '2 month'<=current_date then 'PARTIAL' else 'FUTURE' end,
       case when b.cohort_start+interval '4 month'<=current_date then 'COMPLETE' when b.cohort_start+interval '3 month'<=current_date then 'PARTIAL' else 'FUTURE' end
from base b join revenue r on r.mes=b.mes
order by b.mes;
$$;

create or replace function public.aos_marketing_attribution_summary_v2_preview(p_mes integer,p_anio integer)
returns jsonb
language sql
stable
as $$
with params as (select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd),
raw as materialized (select * from public.aos_marketing_touchpoints_v2((select d from params),((select nd from params)-1))),
eff as materialized (select * from raw where not es_duplicado_tecnico_probable),
classes as materialized (select * from public.aos_marketing_touchpoint_classification_v2((select d from params),((select nd from params)-1))),
people as (select numero_limpio,count(*) touchpoints from eff group by numero_limpio),
attrs as materialized (select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p where a.lead_fecha>=p.d and a.lead_fecha<p.nd),
acq as materialized (select a.* from public.aos_marketing_acquisition_customers_v2() a,params p where a.lead_fecha>=p.d and a.lead_fecha<p.nd),
anomalies as materialized (select * from public.aos_marketing_attribution_review_v2((select d from params),((select nd from params)-1))
)
select jsonb_build_object(
  'personasUnicas',(select count(*) from people),
  'touchpointsRaw',(select count(*) from raw),
  'touchpointsEfectivos',(select count(*) from eff),
  'duplicadosTecnicosProbables',(select count(*) from classes where classification='DUPLICADO_TECNICO_PROBABLE'),
  'primerosTouchpoints',(select count(*) from classes where classification='PRIMER_TOUCH'),
  'reingresosProspectoHistorico',(select count(*) from classes where classification='REINGRESO_PROSPECTO_HISTORICO'),
  'reingresosProspectoMismoMes',(select count(*) from classes where classification='REINGRESO_PROSPECTO_MISMO_MES'),
  'reingresosClienteExistente',(select count(*) from classes where classification='REINGRESO_CLIENTE_EXISTENTE'),
  'personasConMasDeUnTouchpointEnMes',(select count(*) from people where touchpoints>1),
  'clientesAdquiridos',(select count(*) from acq),
  'clientesAdquiridosM0',(select count(*) from acq,params p where first_sale_date>=p.d and first_sale_date<p.nd),
  'reactivacionesConfirmadas',(select count(distinct numero_limpio) from attrs where tipo_atribucion='REACTIVACION'),
  'revenueReactivacion',(select coalesce(sum(monto),0) from attrs where tipo_atribucion='REACTIVACION'),
  'operacionesSeguimiento',(select count(*) from attrs where tipo_atribucion='SEGUIMIENTO_HISTORICO'),
  'revenueSeguimiento',(select coalesce(sum(monto),0) from attrs where tipo_atribucion='SEGUIMIENTO_HISTORICO'),
  'anomaliasHigh',(select count(*) from anomalies where severity='HIGH'),
  'anomaliasMedium',(select count(*) from anomalies where severity='MEDIUM')
);
$$;

create or replace function public.aos_marketing_intent_to_purchase_v2_preview(p_mes integer,p_anio integer)
returns table(tratamiento_interes text,tratamiento_compra text,clientes bigint,operaciones bigint,facturacion numeric,coincide_intencion boolean,porcentaje_facturacion_intencion numeric)
language sql
stable
as $$
with params as (select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd),
attrs as materialized (select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p where a.lead_fecha>=p.d and a.lead_fecha<p.nd),
grouped as (
  select upper(coalesce(nullif(trim(lead_tratamiento),''),'SIN TRATAMIENTO')) tratamiento_interes,
         upper(coalesce(nullif(trim(tratamiento_compra),''),'SIN TRATAMIENTO')) tratamiento_compra,
         count(distinct numero_limpio)::bigint clientes,count(*)::bigint operaciones,coalesce(sum(monto),0)::numeric facturacion
  from attrs group by 1,2
), totals as (select tratamiento_interes,sum(facturacion) total_fact from grouped group by tratamiento_interes)
select g.tratamiento_interes,g.tratamiento_compra,g.clientes,g.operaciones,g.facturacion,
       (g.tratamiento_interes=g.tratamiento_compra),case when t.total_fact>0 then round(g.facturacion/t.total_fact*100,2) else 0 end
from grouped g join totals t using(tratamiento_interes)
order by g.tratamiento_interes,g.facturacion desc,g.tratamiento_compra;
$$;

create or replace function public.aos_marketing_leads_detalle_v2_paged(
  p_fecha_desde date,p_fecha_hasta date,p_search text default null,p_estado text default null,p_limit integer default 50,p_offset integer default 0
)
returns table(
  total_rows bigint,lead_id bigint,fecha date,hora_ingreso timestamptz,celular text,numero_limpio text,tratamiento text,anuncio text,preguntas text,
  llamadas_total bigint,ultima_llamada timestamptz,ultimo_estado text,ultimo_asesor text,citas_total bigint,proxima_cita_fecha date,
  proxima_cita_estado text,ventas_total bigint,monto_facturado numeric,estado_lead text
)
language sql
stable
as $$
with data as materialized (select d.* from public.aos_marketing_leads_detalle_v2(p_fecha_desde,p_fecha_hasta) d),
filtered as (
  select d.* from data d
  where (coalesce(trim(p_search),'')='' or coalesce(d.numero_limpio,'') ilike '%'||trim(p_search)||'%' or coalesce(d.celular,'') ilike '%'||trim(p_search)||'%'
      or coalesce(d.tratamiento,'') ilike '%'||trim(p_search)||'%' or coalesce(d.anuncio,'') ilike '%'||trim(p_search)||'%' or coalesce(d.ultimo_asesor,'') ilike '%'||trim(p_search)||'%')
    and (coalesce(trim(p_estado),'')='' or upper(coalesce(d.estado_lead,''))=upper(trim(p_estado)))
), ranked as (select f.*,count(*) over() total_rows from filtered f)
select r.total_rows,r.lead_id,r.fecha,r.hora_ingreso,r.celular,r.numero_limpio,r.tratamiento,r.anuncio,r.preguntas,
       r.llamadas_total,r.ultima_llamada,r.ultimo_estado,r.ultimo_asesor,r.citas_total,r.proxima_cita_fecha,r.proxima_cita_estado,
       r.ventas_total,r.monto_facturado,r.estado_lead
from ranked r
order by r.fecha desc,r.hora_ingreso desc nulls last,r.lead_id desc
limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$$;

-- Keep previews/internal read models private until each UI cutover is approved.
revoke execute on function public.aos_marketing_historico_v2_preview(integer) from public,anon,authenticated;
revoke execute on function public.aos_marketing_anuncios_v2_preview(integer,integer,text,integer,integer,text) from public,anon,authenticated;
revoke execute on function public.aos_marketing_campanas_v2_preview(integer,integer,text,integer,integer,text) from public,anon,authenticated;
revoke execute on function public.aos_marketing_periodos_v2_preview() from public,anon,authenticated;
revoke execute on function public.aos_marketing_acquisition_customers_v2() from public,anon,authenticated;
revoke execute on function public.aos_marketing_cohortes_ltv_v2_preview(integer) from public,anon,authenticated;
revoke execute on function public.aos_marketing_attribution_summary_v2_preview(integer,integer) from public,anon,authenticated;
revoke execute on function public.aos_marketing_intent_to_purchase_v2_preview(integer,integer) from public,anon,authenticated;
revoke execute on function public.aos_marketing_leads_detalle_v2_paged(date,date,text,text,integer,integer) from public,anon,authenticated;
