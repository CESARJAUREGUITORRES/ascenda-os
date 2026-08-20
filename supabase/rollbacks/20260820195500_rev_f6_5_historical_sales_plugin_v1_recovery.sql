-- REV-F6.5 recovery — remove only F6.5 dynamic historical coverage/plugin objects and restore exact certified F6.4 runtime boundary.
begin;

drop function if exists public.aos_rev_historical_recompute_v1();
drop function if exists public.aos_rev_f6_5_contract_v1();

drop function if exists public.aos_rev_sales_intelligence_v3(integer,text,text);
do $$
begin
  if to_regprocedure('public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text)') is not null then
    execute 'alter function public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text) rename to aos_rev_sales_intelligence_v3';
  end if;
  if to_regprocedure('public.aos_rev_sales_intelligence_v3(integer,text,text)') is null then
    raise exception 'REV-F6.5 recovery failed to restore F6.4 Sales Intelligence runtime';
  end if;
end $$;
revoke all on function public.aos_rev_sales_intelligence_v3(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3(integer,text,text) to service_role;

drop function if exists public.aos_rev_historical_detailed_status_v1();
drop function if exists public.aos_rev_historical_status_map_v1();
drop function if exists public.aos_rev_historical_coverage_v1();
drop function if exists public.aos_rev_historical_year_coverage_v1(integer);
drop function if exists public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb);
drop function if exists public.aos_rev_historical_source_register_v1(jsonb);
drop table if exists public.aos_rev_historical_source_manifest_v1;

commit;
