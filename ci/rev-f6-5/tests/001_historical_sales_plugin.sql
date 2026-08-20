\set ON_ERROR_STOP on

do $$
begin
  if to_regclass('public.aos_rev_historical_source_manifest_v1') is null then raise exception 'missing F6.5 manifest'; end if;
  if to_regprocedure('public.aos_rev_historical_source_register_v1(jsonb)') is null then raise exception 'missing F6.5 register'; end if;
  if to_regprocedure('public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb)') is null then raise exception 'missing F6.5 certify'; end if;
  if to_regprocedure('public.aos_rev_historical_year_coverage_v1(integer)') is null then raise exception 'missing F6.5 year coverage'; end if;
  if to_regprocedure('public.aos_rev_historical_coverage_v1()') is null then raise exception 'missing F6.5 coverage'; end if;
  if to_regprocedure('public.aos_rev_f6_5_contract_v1()') is null then raise exception 'missing F6.5 contract'; end if;
  if to_regprocedure('public.aos_rev_historical_recompute_v1()') is null then raise exception 'missing F6.5 recompute'; end if;
  if to_regprocedure('public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text)') is null then raise exception 'missing frozen F6.4 runtime base'; end if;
end $$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure rp,p.prosecdef,p.proconfig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.oid in (
      'public.aos_rev_historical_source_register_v1(jsonb)'::regprocedure,
      'public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb)'::regprocedure,
      'public.aos_rev_historical_year_coverage_v1(integer)'::regprocedure,
      'public.aos_rev_historical_coverage_v1()'::regprocedure,
      'public.aos_rev_historical_status_map_v1()'::regprocedure,
      'public.aos_rev_historical_detailed_status_v1()'::regprocedure,
      'public.aos_rev_f6_5_contract_v1()'::regprocedure,
      'public.aos_rev_historical_recompute_v1()'::regprocedure,
      'public.aos_rev_sales_intelligence_v3(integer,text,text)'::regprocedure
    )
  loop
    if not r.prosecdef then raise exception 'F6.5 function not SECURITY DEFINER: %',r.rp; end if;
    if r.proconfig is null or not exists(select 1 from unnest(r.proconfig) x where x like 'search_path=%') then raise exception 'F6.5 function missing explicit search_path: %',r.rp; end if;
  end loop;
end $$;

do $$
declare base record; c jsonb;
begin
  select * into base from public.ci_f65_protected_baseline limit 1;
  if (select count(*) from public.aos_pacientes)<>base.patients then raise exception 'patient rows mutated'; end if;
  if (select count(*) from public.aos_ventas)<>base.sales then raise exception 'sales rows mutated'; end if;
  if (select count(*) from public.aos_product_sale_fact_current_v1)<>base.f3 then raise exception 'F3 rows mutated'; end if;
  if (select count(*) from public.aos_cartera_reconciliacion)<>base.f4 then raise exception 'F4 rows mutated'; end if;
  if public.aos_rev_f6_3_contract_v1()->>'contract_fingerprint'<>base.f63_fp then raise exception 'F6.3 fingerprint drift'; end if;
  if public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint'<>base.f64_fp then raise exception 'F6.4 fingerprint drift'; end if;
  if (select count(*) from public.aos_rev_si_sales_fact_v1)<>base.f64_sales_fact then raise exception 'F6.4 sale fact drift'; end if;
  c:=public.aos_rev_f6_5_contract_v1();
  if c#>>'{contract,historical_coverage,semantic}'<>'DYNAMIC_SOURCE_COVERAGE_NE_REVENUE' then raise exception 'dynamic coverage contract missing: %',c; end if;
  if coalesce((c#>>'{contract,runtime,hardcoded_2024_2025_runtime_status}')::boolean,true) then raise exception 'active runtime still declares hardcoded historical status'; end if;
end $$;

do $$
begin
  if has_table_privilege('anon','public.aos_rev_historical_source_manifest_v1','SELECT') then raise exception 'manifest anon-readable'; end if;
  if has_table_privilege('authenticated','public.aos_rev_historical_source_manifest_v1','SELECT') then raise exception 'manifest authenticated-readable'; end if;
  if has_function_privilege('anon','public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb)','EXECUTE') then raise exception 'certify anon-executable'; end if;
  if has_function_privilege('authenticated','public.aos_rev_historical_coverage_v1()','EXECUTE') then raise exception 'coverage authenticated-executable'; end if;
  if not has_function_privilege('service_role','public.aos_rev_f6_5_contract_v1()','EXECUTE') then raise exception 'service contract unavailable'; end if;
  if not has_function_privilege('anon','public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)','EXECUTE') then raise exception 'governed F6.4/F6.5 gateway unavailable'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy 360 reopened'; end if;
end $$;

do $$
declare a jsonb; b jsonb; y24 jsonb; y25 jsonb;
begin
  a:=public.aos_rev_f6_5_contract_v1(); b:=public.aos_rev_f6_5_contract_v1();
  if a->>'contract_fingerprint' is null or a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.5 fingerprint unstable'; end if;
  y24:=public.aos_rev_sales_intelligence_v3(2024,'',''); y25:=public.aos_rev_sales_intelligence_v3(2025,'','');
  if y24->'value'<>'null'::jsonb or y25->'value'<>'null'::jsonb then raise exception 'manifest coverage became historical revenue'; end if;
  if y24->>'source_status'<>'CERTIFIED_PARTIAL_COVERAGE' or y25->>'source_status'<>'CERTIFIED_COMPLETE' then raise exception 'dynamic historical status mismatch: % / %',y24,y25; end if;
end $$;

select 'REV-F6.5 DB/security/semantic/performance contracts PASS' as result;
