\set ON_ERROR_STOP on
create table public.ci_f64_protected_baseline as
select
  (select count(*) from public.aos_pacientes)::bigint patients,
  (select count(*) from public.aos_ventas)::bigint sales,
  (select count(*) from public.aos_product_sale_fact_current_v1)::bigint f3,
  (select count(*) from public.aos_cartera_reconciliacion)::bigint f4,
  (select count(*) from public.aos_f5_identity_cluster_members_v1)::bigint memberships,
  (select count(*) from public.aos_f5_canonical_classification_v1)::bigint classifications;
