-- ASCENDA OS — CIA Phase 4 purchase-detail helper mappings
begin;
create or replace function public.aos_cia_audience_observed_value_v1(p_row jsonb,p_field text)
returns jsonb language sql immutable parallel safe as $$
select case p_field
 when 'sales.products' then p_row->'canonical_products'
 when 'sales.product_categories' then p_row->'product_categories'
 when 'sales.product_unresolved_count' then p_row->'product_unresolved_count'
 when 'sales.services' then p_row->'canonical_services'
 when 'sales.service_categories' then p_row->'service_categories'
 when 'sales.service_category_unresolved_count' then p_row->'service_category_unresolved_count'
 else public.aos_cia_audience_get_value_v1(p_row,p_field)
end;
$$;
create or replace function public.aos_cia_audience_effective_field_type_v1(p_field text)
returns text language sql immutable parallel safe as $$
select case
 when p_field in ('sales.products','sales.product_categories','sales.services','sales.service_categories') then 'set'
 when p_field in ('sales.product_unresolved_count','sales.service_category_unresolved_count') then 'integer'
 else public.aos_cia_audience_field_type_v1(p_field)
end;
$$;
revoke all on function public.aos_cia_audience_observed_value_v1(jsonb,text) from public,anon,authenticated;
revoke all on function public.aos_cia_audience_effective_field_type_v1(text) from public,anon,authenticated;
grant execute on function public.aos_cia_audience_observed_value_v1(jsonb,text) to service_role;
grant execute on function public.aos_cia_audience_effective_field_type_v1(text) to service_role;
commit;
