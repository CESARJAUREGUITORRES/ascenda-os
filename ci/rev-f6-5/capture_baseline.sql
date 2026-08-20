\set ON_ERROR_STOP on

create table if not exists public.ci_f65_protected_baseline as
select
  (select count(*)::bigint from public.aos_pacientes) patients,
  (select count(*)::bigint from public.aos_ventas) sales,
  (select count(*)::bigint from public.aos_product_sale_fact_current_v1) f3,
  (select count(*)::bigint from public.aos_cartera_reconciliacion) f4,
  (public.aos_rev_f6_3_contract_v1()->>'contract_fingerprint')::text f63_fp,
  (public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint')::text f64_fp,
  (select count(*)::bigint from public.aos_rev_si_sales_fact_v1) f64_sales_fact,
  has_function_privilege('anon','public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)','EXECUTE') gateway_anon_exec,
  has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') legacy_360_anon_exec;

select 'REV-F6.5 protected baseline captured' as result;
