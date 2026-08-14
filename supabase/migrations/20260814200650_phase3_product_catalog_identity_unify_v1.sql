-- ASCENDA OS — Phase 3 catalog identity unification v1
-- If a current catalog SKU maps to exactly one owner-confirmed F3 identity,
-- that owner identity is the canonical identity for automatic resolution.
-- Ambiguous catalog SKUs (multiple F3 variants) remain on their generic CAT identity
-- and must not be collapsed automatically.

with unique_f3 as (
  select catalog_service_id, min(product_key) as f3_product_key
  from public.aos_product_identity_v1
  where product_key like 'F3:%'
    and catalog_service_id is not null
  group by catalog_service_id
  having count(*)=1
), duplicate_cat as (
  select i.product_key as cat_product_key, i.catalog_service_id, u.f3_product_key
  from public.aos_product_identity_v1 i
  join unique_f3 u using (catalog_service_id)
  where i.product_key like 'CAT:%'
)
update public.aos_product_alias_v2 a
set product_key=d.f3_product_key,
    updated_at=now()
from duplicate_cat d
where a.product_key=d.cat_product_key;

with unique_f3 as (
  select catalog_service_id, min(product_key) as f3_product_key
  from public.aos_product_identity_v1
  where product_key like 'F3:%'
    and catalog_service_id is not null
  group by catalog_service_id
  having count(*)=1
), duplicate_cat as (
  select i.product_key as cat_product_key, i.catalog_service_id, u.f3_product_key
  from public.aos_product_identity_v1 i
  join unique_f3 u using (catalog_service_id)
  where i.product_key like 'CAT:%'
)
update public.aos_product_sale_fact_v1 f
set product_key=d.f3_product_key,
    updated_at=now()
from duplicate_cat d
where f.product_key=d.cat_product_key
  and f.locked=false;

-- Remove now-unreferenced generic identities only for one-to-one catalog mappings.
with unique_f3 as (
  select catalog_service_id
  from public.aos_product_identity_v1
  where product_key like 'F3:%'
    and catalog_service_id is not null
  group by catalog_service_id
  having count(*)=1
)
delete from public.aos_product_identity_v1 i
using unique_f3 u
where i.catalog_service_id=u.catalog_service_id
  and i.product_key like 'CAT:%'
  and not exists (select 1 from public.aos_product_alias_v2 a where a.product_key=i.product_key)
  and not exists (select 1 from public.aos_product_sale_fact_v1 f where f.product_key=i.product_key);

-- Re-evaluate unlocked rows after catalog aliases have been unified.
select public.aos_product_backfill_unlocked_v1();
