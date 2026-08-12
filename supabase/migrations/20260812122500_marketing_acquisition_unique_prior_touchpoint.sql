-- Marketing Attribution V2
-- Acquisition fallback for a first purchase with exactly one effective prior marketing touchpoint.
-- Keeps ambiguous multi-touch histories unattributed.

create or replace function public.aos_marketing_acquisition_customers_v2()
returns table(
  numero_limpio text,
  lead_id bigint,
  lead_fecha date,
  lead_anuncio text,
  lead_tratamiento text,
  first_sale_date date,
  attribution_method text,
  confidence integer
)
language sql
stable
as $function$
with first_sale as materialized (
  select v.numero_limpio,min(v.fecha) first_sale_date
  from public.aos_ventas v
  where v.numero_limpio is not null and v.numero_limpio<>''
  group by v.numero_limpio
), direct_attrs as materialized (
  select a.*
  from public.aos_marketing_attribution_v2_preview(null,null) a
  join first_sale f
    on f.numero_limpio=a.numero_limpio
   and a.venta_fecha=f.first_sale_date
  where a.lead_id is not null
), direct_ranked as (
  select a.*,
         row_number() over(
           partition by a.numero_limpio
           order by a.confidence desc,a.lead_fecha desc,a.lead_id
         ) rn
  from direct_attrs a
), direct_best as (
  select d.numero_limpio,d.lead_id,d.lead_fecha,d.lead_anuncio,d.lead_tratamiento,
         f.first_sale_date,d.metodo_match attribution_method,d.confidence
  from direct_ranked d
  join first_sale f using(numero_limpio)
  where d.rn=1
), unresolved as (
  select f.*
  from first_sale f
  left join direct_best d using(numero_limpio)
  where d.numero_limpio is null
), unique_prior as (
  select u.numero_limpio,u.first_sale_date,
         count(t.lead_id) candidate_count,
         min(t.lead_id) candidate_lead_id
  from unresolved u
  join public.aos_marketing_touchpoints_v2(null,null) t
    on t.numero_limpio=u.numero_limpio
   and not t.es_duplicado_tecnico_probable
   and t.fecha<=u.first_sale_date
  group by u.numero_limpio,u.first_sale_date
), historical_unique as (
  select u.numero_limpio,t.lead_id,t.fecha lead_fecha,t.anuncio lead_anuncio,t.tratamiento lead_tratamiento,
         u.first_sale_date,'HISTORICAL_UNIQUE_MATCH'::text attribution_method,60::integer confidence
  from unique_prior u
  join public.aos_marketing_touchpoints_v2(null,null) t
    on t.lead_id=u.candidate_lead_id
  where u.candidate_count=1
)
select d.numero_limpio,d.lead_id,d.lead_fecha,d.lead_anuncio,d.lead_tratamiento,
       d.first_sale_date,d.attribution_method,d.confidence
from direct_best d
union all
select h.numero_limpio,h.lead_id,h.lead_fecha,h.lead_anuncio,h.lead_tratamiento,
       h.first_sale_date,h.attribution_method,h.confidence
from historical_unique h;
$function$;

revoke execute on function public.aos_marketing_acquisition_customers_v2() from anon;
grant execute on function public.aos_marketing_acquisition_customers_v2() to authenticated,service_role;
