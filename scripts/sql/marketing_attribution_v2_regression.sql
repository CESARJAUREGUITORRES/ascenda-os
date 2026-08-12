-- ASCENDA OS — Marketing Attribution V2 regression contract
-- Read-only. Expected snapshot values are intentionally limited to known historical periods.

with attr as materialized (
  select * from public.aos_marketing_attribution_v2_preview(null,null)
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
  select 'historico_current_year_has_8_months',count(*)=8,count(*)::text
  from public.aos_marketing_historico_v2_preview(2026)

  union all
  select 'aug_touchpoint_accounting',
         (max(touchpoints_raw)=max(touchpoints_efectivos)+max(duplicados_tecnicos_probables)),
         (max(touchpoints_raw)||'='||max(touchpoints_efectivos)||'+'||max(duplicados_tecnicos_probables))::text
  from public.aos_marketing_historico_v2_preview(2026) where mes=8

  union all
  select 'aug_m0_baseline',
         (max(clientes_m0)=2 and max(ventas_m0)=6 and max(fact_m0)=1045),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from public.aos_marketing_historico_v2_preview(2026) where mes=8

  union all
  select 'july_sale_before_lead_excluded',
         (max(clientes_m0)=3 and max(ventas_m0)=13 and max(fact_m0)=4258.8),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from public.aos_marketing_historico_v2_preview(2026) where mes=7

  union all
  select 'march_ambiguous_reentry_excluded',
         (max(clientes_m0)=3 and max(ventas_m0)=6 and max(fact_m0)=965),
         ('clientes='||max(clientes_m0)||',ops='||max(ventas_m0)||',fact='||max(fact_m0))::text
  from public.aos_marketing_historico_v2_preview(2026) where mes=3
)
select * from checks order by test_name;
