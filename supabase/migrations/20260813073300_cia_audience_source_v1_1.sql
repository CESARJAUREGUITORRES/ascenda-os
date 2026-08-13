-- ASCENDA OS — CIA Phase 4 Audience Source V1.1
begin;
create or replace view public.aos_cia_audience_source_v1_1 with(security_invoker=true) as
select a.*,
 d.product_mapped_count,
 d.product_unresolved_count,
 d.canonical_products,
 d.product_categories,
 d.service_unresolved_count,
 d.service_category_unresolved_count,
 d.canonical_services,
 d.service_categories
from public.aos_cia_audience_source_v1 a
join public.aos_cia_purchase_detail_facts_v1 d using(contact_key);

update public.aos_audience_filter_registry set
 allowed_operators=array['contains','contains_any','contains_all','never_contains'],
 description='Canonical catalog-recognized products. never_contains requires zero unresolved product rows.',updated_at=now()
where field_key='sales.products';
update public.aos_audience_filter_registry set
 allowed_operators=array['contains','contains_any','contains_all','never_contains'],
 description='Observed service families. never_contains requires zero unresolved service-family rows.',updated_at=now()
where field_key='sales.services';

insert into public.aos_audience_filter_registry(field_key,label,category,data_type,allowed_operators,source_column,description) values
('sales.product_categories','Categorías producto','SALE','set',array['contains','contains_any','contains_all','never_contains'],'product_categories','Catalog categories from safely reconciled product sales'),
('sales.product_unresolved_count','Compras producto sin resolver','SALE','integer',array['eq','gt','gte','lt','lte','between'],'product_unresolved_count','Product sale rows without safe catalog reconciliation'),
('sales.service_categories','Categorías servicio','SALE','set',array['contains','contains_any','contains_all','never_contains'],'service_categories','High-confidence service categories'),
('sales.service_category_unresolved_count','Servicios sin categoría resuelta','SALE','integer',array['eq','gt','gte','lt','lte','between'],'service_category_unresolved_count','Service rows without high-confidence category mapping')
on conflict(field_key) do update set label=excluded.label,category=excluded.category,data_type=excluded.data_type,allowed_operators=excluded.allowed_operators,source_column=excluded.source_column,description=excluded.description,active=true,registry_version=1,updated_at=now();

revoke all on public.aos_cia_audience_source_v1_1 from public,anon,authenticated;
grant select on public.aos_cia_audience_source_v1_1 to service_role;
commit;
