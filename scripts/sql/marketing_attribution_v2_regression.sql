-- ASCENDA OS — Marketing Attribution V2 regression contract
-- Read-only. Expected snapshot values are intentionally limited to known historical periods.
-- Materialize expensive read models once per run to avoid repeated full recomputation.

with hist as materialized (
  select * from public.aos_marketing_historico_v2_preview(2026)
), attr as materialized (
  select * from public.aos_marketing_attribution_v2_preview(date '2026-01-01',date '2026-08-31')
), first_sale as materialized (
  select numero_limpio,min(fecha) first_sale_date
  from public.aos_ventas
  where numero_limpio is not null and numero_limpio<>''
  group by numero_limpio
), eligible_acq as materialized (
  select f.* from first_sale f
  where exists(
    select 1 from public.aos_marketing_touchpoints_v2(null,null) t
    where t.numero_limpio=f.numero_limpio
      and not t.es_duplicado_tecnico_probable
      and t.fecha<=f.first_sale_date
  )
), acq as materialized (
  select * from public.aos_marketing_acquisition_customers_v2()
), annual_ads as materialized (
  select * from public.aos_marketing_anuncios_v2_anio_preview(2026,null,200,0,'fact_acum')
), annual_campaigns as materialized (
  select * from public.aos_marketing_campanas_v2_anio_preview(2026,null,200,0,'fact_acum')
), checks as (
  select 'no_sale_before_lead' test_name,
         count(*)=0 passed,
         count(*)::text detail
  from attr where venta_fecha<lead_fecha

  union all
  select 'one_attribution_per_sale',count(*)=0,count(*)::text
  from (select venta_pk,count(*) n from attr group by venta_pk having count(*)>1) x

  union all
  select 'confidence_allowed',count(*)=0,count(*)::text
  from attr where confidence not in (70,80,85,90,95,100)

  union all
  select 'acquisition_coverage_ge_95',
         ((select count(*) from acq)::numeric/nullif((select count(*) from eligible_acq),0)>=0.95),
         ((select count(*) from acq)||'/'||(select count(*) from eligible_acq)||' = '||round((select count(*) from acq)::numeric/nullif((select count(*) from eligible_acq),0)*100,2)||'%')::text

  union all
  select 'historical_unique_acquisition_is_explicit',
         count(*)=17,
         count(*)::text
  from acq where attribution_method='HISTORICAL_UNIQUE_MATCH' and confidence=60

  union all
  select 'historico_current_year_has_8_months',count(*)=8,count(*)::text
  from hist

  union all
  select 'aug_touchpoint_accounting',
         (max(touchpoints_raw)=max(touchpoints_efectivos)+max(duplicados_tecnicos_probables)),
         (max(touchpoints_raw)||'='||max(touchpoints_efectivos)||'+'||max(duplicados_tecnicos_probables))::text
  from hist where mes=8

  union all
  select 'aug_m0_baseline',
         (max(clientes_m0)=2 and max(ventas_m0)=6 and max(fact_m0)=1045),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from hist where mes=8

  union all
  select 'july_sale_before_lead_excluded',
         (max(clientes_m0)=3 and max(ventas_m0)=13 and max(fact_m0)=4258.8),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from hist where mes=7

  union all
  select 'march_ambiguous_reentry_excluded',
         (max(clientes_m0)=3 and max(ventas_m0)=6 and max(fact_m0)=965),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from hist where mes=3

  union all
  select 'annual_ads_match_historico',
         ((select coalesce(sum(fact_m0),0) from annual_ads)=(select coalesce(sum(fact_m0),0) from hist)
          and (select coalesce(sum(fact_post),0) from annual_ads)=(select coalesce(sum(fact_post),0) from hist)),
         ('ads='||(select coalesce(sum(fact_acum),0) from annual_ads)||',hist='||(select coalesce(sum(fact_acumulado),0) from hist))::text

  union all
  select 'annual_campaigns_match_historico',
         ((select coalesce(sum(fact_m0),0) from annual_campaigns)=(select coalesce(sum(fact_m0),0) from hist)
          and (select coalesce(sum(fact_post),0) from annual_campaigns)=(select coalesce(sum(fact_post),0) from hist)),
         ('camp='||(select coalesce(sum(fact_acum),0) from annual_campaigns)||',hist='||(select coalesce(sum(fact_acumulado),0) from hist))::text
)
select * from checks order by test_name;
