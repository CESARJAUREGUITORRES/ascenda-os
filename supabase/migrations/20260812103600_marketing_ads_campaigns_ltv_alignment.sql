-- Marketing Attribution V2
-- M0 stays touchpoint-attributed. Post/accrued value uses all future purchases of customers actually acquired by the ad/campaign.

create or replace function public.aos_marketing_anuncios_v2_preview(
  p_mes integer,p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(
  total_rows bigint,anuncio text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,
  leads_gestionados bigint,llamadas bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,
  clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,
  pct_cita numeric,pct_asistencia numeric,pct_conversion_m0 numeric
)
language sql stable
as $$
with params as (
  select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd
), raw as materialized (
  select * from public.aos_marketing_touchpoints_v2((select d from params),((select nd from params)-1))
), eff as materialized (
  select * from raw where not es_duplicado_tecnico_probable
), detail as materialized (
  select d.* from public.aos_marketing_leads_detalle_v2((select d from params),((select nd from params)-1)) d
  join eff e on e.lead_id=d.lead_id
), raw_stats as (
  select coalesce(nullif(trim(anuncio),''),'SIN ANUNCIO') key,count(*)::bigint touch_raw
  from raw group by 1
), eff_stats as (
  select coalesce(nullif(trim(anuncio),''),'SIN ANUNCIO') key,count(*)::bigint touch_eff,count(distinct numero_limpio)::bigint personas
  from eff group by 1
), gestion_stats as (
  select coalesce(nullif(trim(anuncio),''),'SIN ANUNCIO') key,
         count(*) filter(where llamadas_total>0)::bigint gestionados,
         coalesce(sum(llamadas_total),0)::bigint llamadas,
         count(*) filter(where citas_total>0)::bigint leads_cita,
         coalesce(sum(citas_total),0)::bigint citas
  from detail group by 1
), attendance_by_lead as materialized (
  select e.lead_id,e.anuncio,
         count(c.id) filter(where upper(coalesce(c.estado_cita,'')) in ('ASISTIO','EFECTIVA'))::bigint asistencias
  from eff e
  left join public.aos_agenda_citas c
    on c.numero_limpio=e.numero_limpio
   and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=e.lead_ts
   and (e.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<e.next_lead_ts)
  group by e.lead_id,e.anuncio
), attendance_stats as (
  select coalesce(nullif(trim(anuncio),''),'SIN ANUNCIO') key,
         count(*) filter(where asistencias>0)::bigint leads_asist,
         coalesce(sum(asistencias),0)::bigint asistencias
  from attendance_by_lead group by 1
), attrs as materialized (
  select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p
  where a.lead_fecha>=p.d and a.lead_fecha<p.nd
), m0_stats as (
  select coalesce(nullif(trim(lead_anuncio),''),'SIN ANUNCIO') key,
         count(distinct lead_id) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params))::bigint cli_m0,
         count(*) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params))::bigint ven_m0,
         coalesce(sum(monto) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params)),0)::numeric fact_m0
  from attrs group by 1
), acq as materialized (
  select a.* from public.aos_marketing_acquisition_customers_v2() a,params p
  where a.lead_fecha>=p.d and a.lead_fecha<p.nd
), post_stats as (
  select coalesce(nullif(trim(ac.lead_anuncio),''),'SIN ANUNCIO') key,
         count(distinct ac.numero_limpio) filter(where v.id is not null)::bigint cli_post,
         count(v.id)::bigint ven_post,
         coalesce(sum(v.monto),0)::numeric fact_post
  from acq ac
  left join public.aos_ventas v on v.numero_limpio=ac.numero_limpio and v.fecha>=(select nd from params)
  group by 1
), names as (select key from eff_stats), combined as (
  select n.key anuncio,
         coalesce(r.touch_raw,0)::bigint touch_raw,coalesce(e.touch_eff,0)::bigint touch_eff,coalesce(e.personas,0)::bigint personas,
         coalesce(g.gestionados,0)::bigint gestionados,coalesce(g.llamadas,0)::bigint llamadas,
         coalesce(g.leads_cita,0)::bigint leads_cita,coalesce(g.citas,0)::bigint citas,
         coalesce(at.leads_asist,0)::bigint leads_asist,coalesce(at.asistencias,0)::bigint asistencias,
         coalesce(m.cli_m0,0)::bigint cli_m0,coalesce(m.ven_m0,0)::bigint ven_m0,coalesce(m.fact_m0,0)::numeric fact_m0,
         coalesce(po.cli_post,0)::bigint cli_post,coalesce(po.ven_post,0)::bigint ven_post,coalesce(po.fact_post,0)::numeric fact_post
  from names n
  left join raw_stats r on r.key=n.key
  left join eff_stats e on e.key=n.key
  left join gestion_stats g on g.key=n.key
  left join attendance_stats at on at.key=n.key
  left join m0_stats m on m.key=n.key
  left join post_stats po on po.key=n.key
), filtered as (
  select c.*,(c.fact_m0+c.fact_post)::numeric fact_acum from combined c
  where coalesce(trim(p_search),'')='' or c.anuncio ilike '%'||trim(p_search)||'%'
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

revoke execute on function public.aos_marketing_anuncios_v2_preview(integer,integer,text,integer,integer,text) from public,anon,authenticated;

create or replace function public.aos_marketing_campanas_v2_preview(
  p_mes integer,p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(
  total_rows bigint,tratamiento text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,
  leads_gestionados bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,
  clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,
  inversion numeric,cpl numeric,roas_m0 numeric,roas_acum numeric
)
language sql stable
as $$
with params as (
  select make_date(p_anio,p_mes,1) d,(make_date(p_anio,p_mes,1)+interval '1 month')::date nd
), raw as materialized (
  select * from public.aos_marketing_touchpoints_v2((select d from params),((select nd from params)-1))
), eff as materialized (
  select * from raw where not es_duplicado_tecnico_probable
), detail as materialized (
  select d.* from public.aos_marketing_leads_detalle_v2((select d from params),((select nd from params)-1)) d
  join eff e on e.lead_id=d.lead_id
), raw_stats as (
  select upper(coalesce(nullif(trim(tratamiento),''),'SIN TRATAMIENTO')) key,count(*)::bigint touch_raw from raw group by 1
), eff_stats as (
  select upper(coalesce(nullif(trim(tratamiento),''),'SIN TRATAMIENTO')) key,count(*)::bigint touch_eff,count(distinct numero_limpio)::bigint personas from eff group by 1
), gestion_stats as (
  select upper(coalesce(nullif(trim(tratamiento),''),'SIN TRATAMIENTO')) key,
         count(*) filter(where llamadas_total>0)::bigint gestionados,
         count(*) filter(where citas_total>0)::bigint leads_cita,
         coalesce(sum(citas_total),0)::bigint citas
  from detail group by 1
), attendance_by_lead as materialized (
  select e.lead_id,e.tratamiento,
         count(c.id) filter(where upper(coalesce(c.estado_cita,'')) in ('ASISTIO','EFECTIVA'))::bigint asistencias
  from eff e
  left join public.aos_agenda_citas c
    on c.numero_limpio=e.numero_limpio
   and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=e.lead_ts
   and (e.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<e.next_lead_ts)
  group by e.lead_id,e.tratamiento
), attendance_stats as (
  select upper(coalesce(nullif(trim(tratamiento),''),'SIN TRATAMIENTO')) key,
         count(*) filter(where asistencias>0)::bigint leads_asist,
         coalesce(sum(asistencias),0)::bigint asistencias
  from attendance_by_lead group by 1
), attrs as materialized (
  select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p
  where a.lead_fecha>=p.d and a.lead_fecha<p.nd
), m0_stats as (
  select upper(coalesce(nullif(trim(lead_tratamiento),''),'SIN TRATAMIENTO')) key,
         count(distinct lead_id) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params))::bigint cli_m0,
         count(*) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params))::bigint ven_m0,
         coalesce(sum(monto) filter(where venta_fecha>=(select d from params) and venta_fecha<(select nd from params)),0)::numeric fact_m0
  from attrs group by 1
), acq as materialized (
  select a.* from public.aos_marketing_acquisition_customers_v2() a,params p
  where a.lead_fecha>=p.d and a.lead_fecha<p.nd
), post_stats as (
  select upper(coalesce(nullif(trim(ac.lead_tratamiento),''),'SIN TRATAMIENTO')) key,
         count(distinct ac.numero_limpio) filter(where v.id is not null)::bigint cli_post,
         count(v.id)::bigint ven_post,
         coalesce(sum(v.monto),0)::numeric fact_post
  from acq ac
  left join public.aos_ventas v on v.numero_limpio=ac.numero_limpio and v.fecha>=(select nd from params)
  group by 1
), inv_stats as (
  select upper(trim(tratamiento)) key,coalesce(sum(inversion),0)::numeric inversion
  from public.aos_inversion_campanas where mes_num=p_mes and anio=p_anio group by 1
), names as (select key from eff_stats), combined as (
  select n.key tratamiento,
         coalesce(r.touch_raw,0)::bigint touch_raw,coalesce(e.touch_eff,0)::bigint touch_eff,coalesce(e.personas,0)::bigint personas,
         coalesce(g.gestionados,0)::bigint gestionados,coalesce(g.leads_cita,0)::bigint leads_cita,coalesce(g.citas,0)::bigint citas,
         coalesce(at.leads_asist,0)::bigint leads_asist,coalesce(at.asistencias,0)::bigint asistencias,
         coalesce(m.cli_m0,0)::bigint cli_m0,coalesce(m.ven_m0,0)::bigint ven_m0,coalesce(m.fact_m0,0)::numeric fact_m0,
         coalesce(po.cli_post,0)::bigint cli_post,coalesce(po.ven_post,0)::bigint ven_post,coalesce(po.fact_post,0)::numeric fact_post,
         coalesce(iv.inversion,0)::numeric inversion
  from names n
  left join raw_stats r on r.key=n.key
  left join eff_stats e on e.key=n.key
  left join gestion_stats g on g.key=n.key
  left join attendance_stats at on at.key=n.key
  left join m0_stats m on m.key=n.key
  left join post_stats po on po.key=n.key
  left join inv_stats iv on iv.key=n.key
), filtered as (
  select c.*,(c.fact_m0+c.fact_post)::numeric fact_acum from combined c
  where coalesce(trim(p_search),'')='' or c.tratamiento ilike '%'||trim(p_search)||'%'
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

revoke execute on function public.aos_marketing_campanas_v2_preview(integer,integer,text,integer,integer,text) from public,anon,authenticated;
