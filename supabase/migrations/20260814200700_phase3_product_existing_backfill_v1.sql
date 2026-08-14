-- ASCENDA OS — Phase 3 existing product backfill v1
-- Runs after owner-locked evidence is seeded. Locked rows are preserved.

create index if not exists idx_aos_product_alias_v2_product_active
  on public.aos_product_alias_v2(product_key)
  where active=true;

create index if not exists idx_aos_product_sale_fact_v1_product
  on public.aos_product_sale_fact_v1(product_key);

create index if not exists idx_aos_product_sale_fact_v1_resolution
  on public.aos_product_sale_fact_v1(resolution_status,locked);

create or replace view public.aos_product_review_queue_v1 as
select
  f.sale_id,
  v.fecha,
  v.sede,
  v.descripcion as raw_description,
  f.raw_alias_key,
  f.resolution_status,
  f.resolution_source,
  f.locked,
  f.note
from public.aos_product_sale_fact_v1 f
join public.aos_ventas v on v.id=f.sale_id
where f.resolution_status='REVIEW_REQUIRED';

revoke all on table public.aos_product_review_queue_v1 from public, anon, authenticated;
grant select on table public.aos_product_review_queue_v1 to service_role;

-- Resolve all existing PRODUCTO rows that are not owner-locked.
-- This includes sales arriving after the workbook cut-off. Unknown descriptions fail closed to REVIEW_REQUIRED.
select public.aos_product_backfill_unlocked_v1();
