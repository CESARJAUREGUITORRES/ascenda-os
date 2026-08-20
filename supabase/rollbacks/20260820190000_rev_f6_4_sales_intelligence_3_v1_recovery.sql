-- REV-F6.4 recovery — restore the exact certified F6.3 public boundary.
begin;

drop function if exists public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text);
drop function if exists public.aos_rev_si_refresh_v1();
drop function if exists public.aos_rev_f6_4_contract_v1();
drop function if exists public.aos_rev_sales_intelligence_v3(integer,text,text);
drop function if exists public.aos_rev_si_rebuild_dashboard_cache_v1();
drop function if exists public.aos_rev_si_cache_filter_v1(integer,text,text);
drop function if exists public.aos_rev_sales_intelligence_v3_uncached_f6_4_base(integer,text,text);
drop function if exists public.aos_rev_si_patient_value_by_patient_v1(text);

drop table if exists public.aos_rev_si_dashboard_cache_v1;
drop materialized view if exists public.aos_rev_si_acquisition_fact_v1;
drop materialized view if exists public.aos_rev_si_product_transition_v1;
drop materialized view if exists public.aos_rev_si_cohort_month_v1;
drop materialized view if exists public.aos_rev_si_patient_value_v1;
drop materialized view if exists public.aos_rev_si_monthly_v1;
drop materialized view if exists public.aos_rev_si_sales_fact_v1;

drop function if exists public.aos_patient_commercial_360_v2(text,text,text);
do $$
begin
  if to_regprocedure('public.aos_patient_commercial_360_v2_f6_3_base(text,text,text)') is not null then
    execute 'alter function public.aos_patient_commercial_360_v2_f6_3_base(text,text,text) rename to aos_patient_commercial_360_v2';
  end if;
end $$;
revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

commit;
