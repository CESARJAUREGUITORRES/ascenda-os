-- Marketing Attribution V2 — annual Ads, Campaigns and traceability.
-- Aggregates the same validated monthly V2 cohorts; no second attribution model.

create or replace function public.aos_marketing_anuncios_v2_anio_preview(
  p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(total_rows bigint,anuncio text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,leads_gestionados bigint,llamadas bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,pct_cita numeric,pct_asistencia numeric,pct_conversion_m0 numeric)
language sql stable as $function$
with months as materialized (select distinct mes from public.aos_marketing_periodos_v2_preview() where anio=p_anio),
monthly as materialized (select x.* from months m cross join lateral public.aos_marketing_anuncios_v2_preview(m.mes,p_anio,null,200,0,'fact_acum') x),
annual_people as materialized (
  select coalesce(nullif(trim(t.anuncio),''),'SIN ANUNCIO') anuncio,count(distinct t.numero_limpio)::bigint personas
  from public.aos_marketing_touchpoints_v2(make_date(p_anio,1,1),make_date(p_anio,12,31)) t
  where not t.es_duplicado_tecnico_probable group by 1
),agg as (
  select m.anuncio,sum(m.touchpoints_raw)::bigint touch_raw,sum(m.touchpoints_efectivos)::bigint touch_eff,coalesce(max(ap.personas),0)::bigint personas,
  sum(m.leads_gestionados)::bigint gestionados,sum(m.llamadas)::bigint llamadas,sum(m.leads_con_cita)::bigint leads_cita,sum(m.citas)::bigint citas,
  sum(m.leads_con_asistencia)::bigint leads_asist,sum(m.asistencias)::bigint asistencias,sum(m.clientes_m0)::bigint cli_m0,sum(m.ventas_m0)::bigint ven_m0,
  sum(m.fact_m0)::numeric fact_m0,sum(m.clientes_post)::bigint cli_post,sum(m.ventas_post)::bigint ven_post,sum(m.fact_post)::numeric fact_post,sum(m.fact_acum)::numeric fact_acum
  from monthly m left join annual_people ap on ap.anuncio=m.anuncio group by m.anuncio
),filtered as (select * from agg where coalesce(trim(p_search),'')='' or anuncio ilike '%'||trim(p_search)||'%'),
ranked as (select f.*,count(*) over() total_rows,case when touch_eff>0 then round(leads_cita::numeric/touch_eff*100,2) else 0 end pct_cita,case when leads_cita>0 then round(leads_asist::numeric/leads_cita*100,2) else 0 end pct_asist,case when personas>0 then round(cli_m0::numeric/personas*100,2) else 0 end pct_conv from filtered f)
select r.total_rows,r.anuncio,r.touch_raw,r.touch_eff,r.personas,r.gestionados,r.llamadas,r.leads_cita,r.citas,r.leads_asist,r.asistencias,r.cli_m0,r.ven_m0,r.fact_m0,r.cli_post,r.ven_post,r.fact_post,r.fact_acum,r.pct_cita,r.pct_asist,r.pct_conv
from ranked r order by case when p_order='leads' then r.touch_eff end desc nulls last,case when p_order='citas' then r.citas end desc nulls last,case when p_order='fact_m0' then r.fact_m0 end desc nulls last,case when p_order='conversion' then r.pct_conv end desc nulls last,r.fact_acum desc,r.anuncio
limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$function$;

create or replace function public.aos_marketing_campanas_v2_anio_preview(
  p_anio integer,p_search text default null,p_limit integer default 50,p_offset integer default 0,p_order text default 'fact_acum'
)
returns table(total_rows bigint,tratamiento text,touchpoints_raw bigint,touchpoints_efectivos bigint,personas_unicas bigint,leads_gestionados bigint,leads_con_cita bigint,citas bigint,leads_con_asistencia bigint,asistencias bigint,clientes_m0 bigint,ventas_m0 bigint,fact_m0 numeric,clientes_post bigint,ventas_post bigint,fact_post numeric,fact_acum numeric,inversion numeric,cpl numeric,roas_m0 numeric,roas_acum numeric)
language sql stable as $function$
with months as materialized (select distinct mes from public.aos_marketing_periodos_v2_preview() where anio=p_anio),
monthly as materialized (select x.* from months m cross join lateral public.aos_marketing_campanas_v2_preview(m.mes,p_anio,null,200,0,'fact_acum') x),
annual_people as materialized (
  select upper(coalesce(nullif(trim(t.tratamiento),''),'SIN TRATAMIENTO')) tratamiento,count(distinct t.numero_limpio)::bigint personas
  from public.aos_marketing_touchpoints_v2(make_date(p_anio,1,1),make_date(p_anio,12,31)) t
  where not t.es_duplicado_tecnico_probable group by 1
),agg as (
  select m.tratamiento,sum(m.touchpoints_raw)::bigint touch_raw,sum(m.touchpoints_efectivos)::bigint touch_eff,coalesce(max(ap.personas),0)::bigint personas,
  sum(m.leads_gestionados)::bigint gestionados,sum(m.leads_con_cita)::bigint leads_cita,sum(m.citas)::bigint citas,sum(m.leads_con_asistencia)::bigint leads_asist,
  sum(m.asistencias)::bigint asistencias,sum(m.clientes_m0)::bigint cli_m0,sum(m.ventas_m0)::bigint ven_m0,sum(m.fact_m0)::numeric fact_m0,
  sum(m.clientes_post)::bigint cli_post,sum(m.ventas_post)::bigint ven_post,sum(m.fact_post)::numeric fact_post,sum(m.fact_acum)::numeric fact_acum,sum(m.inversion)::numeric inversion
  from monthly m left join annual_people ap on ap.tratamiento=m.tratamiento group by m.tratamiento
),filtered as (select * from agg where coalesce(trim(p_search),'')='' or tratamiento ilike '%'||trim(p_search)||'%'),
ranked as (select f.*,count(*) over() total_rows,case when touch_eff>0 and inversion>0 then round(inversion/touch_eff,2) else null end cpl,case when inversion>0 then round(fact_m0/inversion,2) else null end roas0,case when inversion>0 then round(fact_acum/inversion,2) else null end roasa from filtered f)
select r.total_rows,r.tratamiento,r.touch_raw,r.touch_eff,r.personas,r.gestionados,r.leads_cita,r.citas,r.leads_asist,r.asistencias,r.cli_m0,r.ven_m0,r.fact_m0,r.cli_post,r.ven_post,r.fact_post,r.fact_acum,r.inversion,r.cpl,r.roas0,r.roasa
from ranked r order by case when p_order='leads' then r.touch_eff end desc nulls last,case when p_order='citas' then r.citas end desc nulls last,case when p_order='fact_m0' then r.fact_m0 end desc nulls last,case when p_order='roas' then r.roasa end desc nulls last,r.fact_acum desc,r.tratamiento
limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$function$;

create or replace function public.aos_marketing_attribution_summary_v2_anio_preview(p_anio integer)
returns jsonb language sql stable as $function$
with params as (select make_date(p_anio,1,1) d,make_date(p_anio,12,31) h),
raw as materialized (select * from public.aos_marketing_touchpoints_v2((select d from params),(select h from params))),
eff as materialized (select * from raw where not es_duplicado_tecnico_probable),
classes as materialized (select * from public.aos_marketing_touchpoint_classification_v2((select d from params),(select h from params))),
attrs as materialized (select a.* from public.aos_marketing_attribution_v2_preview(null,null) a,params p where a.lead_fecha between p.d and p.h),
acq as materialized (select a.* from public.aos_marketing_acquisition_customers_v2() a,params p where a.lead_fecha between p.d and p.h),
anomalies as materialized (select * from public.aos_marketing_attribution_review_v2((select d from params),(select h from params)))
select jsonb_build_object(
'personasUnicas',(select count(distinct numero_limpio) from eff),'touchpointsRaw',(select count(*) from raw),'touchpointsEfectivos',(select count(*) from eff),
'duplicadosTecnicosProbables',(select count(*) from classes where classification='DUPLICADO_TECNICO_PROBABLE'),'primerosTouchpoints',(select count(*) from classes where classification='PRIMER_TOUCH'),
'reingresosProspectoHistorico',(select count(*) from classes where classification='REINGRESO_PROSPECTO_HISTORICO'),'reingresosProspectoMismoMes',(select count(*) from classes where classification='REINGRESO_PROSPECTO_MISMO_MES'),
'reingresosClienteExistente',(select count(*) from classes where classification='REINGRESO_CLIENTE_EXISTENTE'),'clientesAdquiridos',(select count(*) from acq),
'clientesAdquiridosM0',(select count(*) from acq where extract(year from first_sale_date)=p_anio),'reactivacionesConfirmadas',(select count(distinct numero_limpio) from attrs where tipo_atribucion='REACTIVACION'),
'revenueReactivacion',(select coalesce(sum(monto),0) from attrs where tipo_atribucion='REACTIVACION'),'operacionesSeguimiento',(select count(*) from attrs where tipo_atribucion='SEGUIMIENTO_HISTORICO'),
'revenueSeguimiento',(select coalesce(sum(monto),0) from attrs where tipo_atribucion='SEGUIMIENTO_HISTORICO'),'anomaliasHigh',(select count(*) from anomalies where severity='HIGH'),'anomaliasMedium',(select count(*) from anomalies where severity='MEDIUM'));
$function$;

grant execute on function public.aos_marketing_anuncios_v2_anio_preview(integer,text,integer,integer,text) to anon;
grant execute on function public.aos_marketing_campanas_v2_anio_preview(integer,text,integer,integer,text) to anon;
grant execute on function public.aos_marketing_attribution_summary_v2_anio_preview(integer) to anon;
