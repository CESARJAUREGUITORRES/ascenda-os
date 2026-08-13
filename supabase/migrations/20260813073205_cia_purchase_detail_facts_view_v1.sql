-- ASCENDA OS — CIA Phase 4 purchase detail facts
begin;
create or replace view public.aos_cia_purchase_detail_facts_v1 with(security_invoker=true) as
with product_agg as (
 select contact_key,
  count(*)::integer product_row_count,
  count(*) filter(where reconciliation_confidence<>'UNKNOWN')::integer product_mapped_count,
  count(*) filter(where reconciliation_confidence='UNKNOWN')::integer product_unresolved_count,
  array_agg(distinct canonical_short_name order by canonical_short_name) filter(where canonical_short_name is not null) canonical_products,
  array_agg(distinct product_category order by product_category) filter(where product_category is not null) product_categories
 from public.aos_cia_product_sale_reconciliation_v1
 group by contact_key
), service_base as (
 select public.aos_cia_normalize_contact_key_v1(v.numero_limpio) contact_key,
  nullif(upper(btrim(v.tratamiento)),'') service_family,
  t.canonical_category
 from public.aos_ventas v
 left join public.aos_service_family_taxonomy_v1 t
  on public.aos_cia_normalize_item_label_v1(t.raw_family)=public.aos_cia_normalize_item_label_v1(v.tratamiento)
  and t.active=true
 where upper(btrim(coalesce(v.tipo,'')))='SERVICIO'
  and public.aos_cia_normalize_contact_key_v1(v.numero_limpio) is not null
), service_agg as (
 select contact_key,
  count(*)::integer service_row_count,
  count(*) filter(where service_family is null)::integer service_unresolved_count,
  count(*) filter(where canonical_category is null)::integer service_category_unresolved_count,
  array_agg(distinct service_family order by service_family) filter(where service_family is not null) canonical_services,
  array_agg(distinct canonical_category order by canonical_category) filter(where canonical_category is not null) service_categories
 from service_base group by contact_key
)
select i.contact_key,
 coalesce(p.product_row_count,0)::integer product_row_count,
 coalesce(p.product_mapped_count,0)::integer product_mapped_count,
 coalesce(p.product_unresolved_count,0)::integer product_unresolved_count,
 coalesce(p.canonical_products,array[]::text[]) canonical_products,
 coalesce(p.product_categories,array[]::text[]) product_categories,
 coalesce(s.service_row_count,0)::integer service_row_count,
 coalesce(s.service_unresolved_count,0)::integer service_unresolved_count,
 coalesce(s.service_category_unresolved_count,0)::integer service_category_unresolved_count,
 coalesce(s.canonical_services,array[]::text[]) canonical_services,
 coalesce(s.service_categories,array[]::text[]) service_categories,
 statement_timestamp() observed_at
from public.aos_cia_contact_identity_v1 i
left join product_agg p using(contact_key)
left join service_agg s using(contact_key);

revoke all on public.aos_cia_purchase_detail_facts_v1 from public,anon,authenticated;
grant select on public.aos_cia_purchase_detail_facts_v1 to service_role;
commit;
