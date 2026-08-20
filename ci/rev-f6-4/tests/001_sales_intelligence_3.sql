\set ON_ERROR_STOP on

do $$
begin
  if to_regclass('public.aos_rev_si_sales_fact_v1') is null then raise exception 'missing sales fact read model'; end if;
  if to_regclass('public.aos_rev_si_monthly_v1') is null then raise exception 'missing monthly read model'; end if;
  if to_regclass('public.aos_rev_si_patient_value_v1') is null then raise exception 'missing patient value read model'; end if;
  if to_regclass('public.aos_rev_si_cohort_month_v1') is null then raise exception 'missing cohort read model'; end if;
  if to_regclass('public.aos_rev_si_product_transition_v1') is null then raise exception 'missing transition read model'; end if;
  if to_regclass('public.aos_rev_si_acquisition_fact_v1') is null then raise exception 'missing acquisition read model'; end if;
  if to_regprocedure('public.aos_rev_sales_intelligence_v3(integer,text,text)') is null then raise exception 'missing v3 contract'; end if;
  if to_regprocedure('public.aos_rev_f6_4_contract_v1()') is null then raise exception 'missing f6.4 contract'; end if;
  if to_regprocedure('public.aos_rev_si_refresh_v1()') is null then raise exception 'missing refresh'; end if;
  if to_regprocedure('public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)') is null then raise exception 'missing gateway'; end if;
end $$;

do $$
begin
  if has_table_privilege('anon','public.aos_rev_si_sales_fact_v1','SELECT') then raise exception 'sales fact browser-readable'; end if;
  if has_table_privilege('authenticated','public.aos_rev_si_patient_value_v1','SELECT') then raise exception 'patient value browser-readable'; end if;
  if has_function_privilege('anon','public.aos_rev_sales_intelligence_v3(integer,text,text)','EXECUTE') then raise exception 'internal v3 browser executable'; end if;
  if has_function_privilege('authenticated','public.aos_rev_si_refresh_v1()','EXECUTE') then raise exception 'refresh browser executable'; end if;
  if not has_function_privilege('service_role','public.aos_rev_f6_4_contract_v1()','EXECUTE') then raise exception 'service contract unavailable'; end if;
  if not has_function_privilege('anon','public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)','EXECUTE') then raise exception 'governed gateway unavailable'; end if;
  if has_function_privilege('anon','public.aos_patient_commercial_360_v2_f6_3_base(text,text,text)','EXECUTE') then raise exception 'private f6.3 360 base exposed'; end if;
  if not has_function_privilege('anon','public.aos_patient_commercial_360_v2(text,text,text)','EXECUTE') then raise exception 'governed patient 360 unavailable'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy 360 reopened'; end if;
end $$;

do $$
declare n integer;
begin
  select count(*) into n
  from information_schema.columns
  where table_schema='public'
    and table_name in ('aos_rev_si_sales_fact_v1','aos_rev_si_monthly_v1','aos_rev_si_patient_value_v1','aos_rev_si_cohort_month_v1','aos_rev_si_product_transition_v1','aos_rev_si_acquisition_fact_v1')
    and lower(column_name) in ('nombres','apellidos','nombre','telefono','phone','celular','email','correo','dni','documento','direccion','notas','observacion');
  if n<>0 then raise exception 'PII/PHI-like aggregate columns found: %',n; end if;
end $$;

do $$
declare j jsonb;
begin
  j:=public.aos_rev_sales_intelligence_v3(2026,'','');
  if j->>'contract'<>'REV-F6.4_SALES_INTELLIGENCE_3_V1' then raise exception 'wrong contract: %',j; end if;
  if (j#>>'{executive_revenue,transactions}')::integer<>4 then raise exception 'expected 4 transactions: %',j; end if;
  if (j#>>'{executive_revenue,billed_amount}')::numeric<>750 then raise exception 'expected billed 750: %',j; end if;
  if (j#>>'{identity_coverage,safe_match_sales}')::integer<>4 then raise exception 'safe linkage mismatch: %',j; end if;
  if j#>>'{observed_ltv,semantic}'<>'OBSERVED_VALUE_NOT_LIFETIME_PREDICTION' then raise exception 'observed value semantic missing'; end if;
  if jsonb_array_length(j->'cross_sell_transitions')<2 then raise exception 'expected product transitions: %',j; end if;
  if j#>>'{acquisition_to_revenue,source_status}'<>'AVAILABLE_PARTIAL_COVERAGE' then raise exception 'explicit acquisition lineage missing: %',j; end if;
  if (j#>>'{acquisition_to_revenue,sample_size}')::integer<>1 then raise exception 'acquisition sample mismatch: %',j; end if;
  if j#>>'{historical_source_status,2024,source_status}'<>'NO_CERTIFIED_SOURCE' then raise exception '2024 no-source guard missing'; end if;
  if j#>>'{historical_source_status,2025,source_status}'<>'NO_CERTIFIED_SOURCE' then raise exception '2025 no-source guard missing'; end if;
  if j#>>'{executive_revenue,financial_semantic}'<>'F4_LINKED_IS_EVIDENCE_COVERAGE_NOT_COLLECTED_CASH' then raise exception 'F4 cash semantic drift'; end if;

  j:=public.aos_rev_sales_intelligence_v3(2025,'','');
  if coalesce((j->>'hasData')::boolean,true) then raise exception '2025 should not fabricate data'; end if;
  if j#>>'{historical_source_status,2025}'<>'NO_CERTIFIED_SOURCE' then raise exception '2025 no-source no-data guard missing'; end if;
end $$;

do $$
declare j jsonb;
begin
  j:=public.aos_rev_sales_intelligence_v3_gateway('bad-token',2026,'','');
  if j->>'error'<>'UNAUTHORIZED' then raise exception 'bad token accepted: %',j; end if;
  j:=public.aos_rev_sales_intelligence_v3_gateway('admin-f64-token-00000000000000000000',2026,'','');
  if j->>'contract'<>'REV-F6.4_SALES_INTELLIGENCE_3_V1' then raise exception 'good token failed: %',j; end if;
end $$;

do $$
declare j jsonb;
begin
  j:=public.aos_patient_commercial_360_v2('advisor-f61-token-00000000000000000000','CANONICAL_ID','P1');
  if coalesce((j->>'found')::boolean,false) is not true then raise exception 'patient 360 lost P1: %',j; end if;
  if j->>'contract'<>'REV-F6.4_PATIENT_COMMERCIAL_360_V2' then raise exception 'patient 360 contract not upgraded'; end if;
  if j#>'{intelligence,sales_intelligence}' is null then raise exception 'patient sales intelligence missing'; end if;
  if position('NOTA CLINICA TEST' in j::text)>0 or position('https://example.test/doc' in j::text)>0 then raise exception 'advisor PHI boundary regressed'; end if;
end $$;

do $$
declare a jsonb; b jsonb; c jsonb;
begin
  a:=public.aos_rev_f6_4_contract_v1();
  b:=public.aos_rev_f6_4_contract_v1();
  if a->>'contract_fingerprint' is null or a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'fingerprint unstable'; end if;
  c:=public.aos_rev_si_refresh_v1();
  if c->>'contract_fingerprint'<>a->>'contract_fingerprint' then raise exception 'refresh changed deterministic fingerprint: % vs %',a,c; end if;
  if coalesce((a#>>'{contract,semantic_guards,no_certified_source_means_zero}')::boolean,true) then raise exception 'no-source guard drift'; end if;
  if coalesce((a#>>'{contract,semantic_guards,f4_link_means_collected_cash}')::boolean,true) then raise exception 'F4 cash guard drift'; end if;
end $$;

do $$
declare b record;
begin
  select * into b from public.ci_f64_protected_baseline limit 1;
  if (select count(*) from public.aos_pacientes)<>b.patients then raise exception 'patient rows mutated'; end if;
  if (select count(*) from public.aos_ventas)<>b.sales then raise exception 'sales rows mutated'; end if;
  if (select count(*) from public.aos_product_sale_fact_current_v1)<>b.f3 then raise exception 'F3 rows mutated'; end if;
  if (select count(*) from public.aos_cartera_reconciliacion)<>b.f4 then raise exception 'F4 rows mutated'; end if;
  if (select count(*) from public.aos_f5_identity_cluster_members_v1)<>b.memberships then raise exception 'F5 memberships mutated'; end if;
  if (select count(*) from public.aos_f5_canonical_classification_v1)<>b.classifications then raise exception 'F5 classifications mutated'; end if;
end $$;

do $$
declare t0 timestamptz; elapsed_ms numeric; i integer; max_ms numeric:=0; j jsonb;
begin
  for i in 1..5 loop
    t0:=clock_timestamp();
    j:=public.aos_rev_sales_intelligence_v3(2026,'','');
    elapsed_ms:=extract(epoch from (clock_timestamp()-t0))*1000;
    max_ms:=greatest(max_ms,elapsed_ms);
  end loop;
  if max_ms>1000 then raise exception 'F6.4 performance gate exceeded: % ms',max_ms; end if;
end $$;

select 'REV-F6.4 DB/security/semantic/performance PASS' as result;
