\set ON_ERROR_STOP on

-- Cross-workstream isolation: mutable CIA compatibility observations remain visible but cannot invalidate Revenue certification hashes.
do $$
declare
  legacy jsonb;
  original_contract jsonb;
  mutated_contract jsonb;
  fp_original text;
  fp_mutated text;
  legacy_fp_original text;
  legacy_fp_mutated text;
  wrapper jsonb;
begin
  if to_regprocedure('public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp()') is null then raise exception 'legacy F6.0 source missing'; end if;
  if to_regprocedure('public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb)') is null then raise exception 'isolated fingerprint helper missing'; end if;

  legacy:=public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp();
  original_contract:=legacy->'contract';
  if original_contract#>'{compatibility_identity}' is null then raise exception 'CIA compatibility metrics disappeared from visible F6.0 contract'; end if;
  if original_contract#>'{freshness_sources}' is null then raise exception 'freshness metrics disappeared from visible F6.0 contract'; end if;

  mutated_contract:=jsonb_set(original_contract,'{compatibility_identity,rows}',to_jsonb(987654321),true);
  mutated_contract:=jsonb_set(mutated_contract,'{compatibility_identity,with_canonical_patient}',to_jsonb(123456789),true);
  mutated_contract:=jsonb_set(mutated_contract,'{compatibility_identity,identity_conflicts}',to_jsonb(777),true);
  mutated_contract:=jsonb_set(mutated_contract,'{freshness_sources,cia_identity_updated_at}',to_jsonb('2099-12-31T23:59:59+00:00'::text),true);

  legacy_fp_original:=md5(original_contract::text);
  legacy_fp_mutated:=md5(mutated_contract::text);
  if legacy_fp_original=legacy_fp_mutated then raise exception 'test invalid: legacy fingerprint did not react to synthetic CIA churn'; end if;

  fp_original:=public.aos_rev_f6_data_contract_fingerprint_isolated_v1(original_contract);
  fp_mutated:=public.aos_rev_f6_data_contract_fingerprint_isolated_v1(mutated_contract);
  if fp_original<>fp_mutated then raise exception 'Revenue fingerprint still coupled to mutable CIA compatibility state: % <> %',fp_original,fp_mutated; end if;

  wrapper:=public.aos_rev_f6_data_contract_v1();
  if wrapper->>'contract_fingerprint'<>fp_original then raise exception 'wrapper fingerprint does not equal isolated projection'; end if;
  if wrapper->>'fingerprint_semantic'<>'REVENUE_TRUTH_EXCLUDES_MUTABLE_CIA_COMPATIBILITY_CARDINALITY' then raise exception 'fingerprint semantic missing'; end if;
  if wrapper#>'{contract,compatibility_identity}'<>original_contract->'compatibility_identity' then raise exception 'visible CIA compatibility metrics were altered'; end if;
end $$;

-- New chain must be deterministic after isolation.
do $$
declare a jsonb; b jsonb;
begin
  a:=public.aos_rev_f6_data_contract_v1(); b:=public.aos_rev_f6_data_contract_v1();
  if a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.0 isolated fingerprint unstable'; end if;
  a:=public.aos_rev_f6_3_contract_v1(); b:=public.aos_rev_f6_3_contract_v1();
  if a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.3 chain fingerprint unstable'; end if;
  a:=public.aos_rev_f6_4_contract_v1(); b:=public.aos_rev_f6_4_contract_v1();
  if a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.4 chain fingerprint unstable'; end if;
  a:=public.aos_rev_f6_5_contract_v1(); b:=public.aos_rev_f6_5_contract_v1();
  if a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.5 chain fingerprint unstable'; end if;
end $$;

-- Security and protected truth remain unchanged.
do $$
declare b record;
begin
  if has_function_privilege('anon','public.aos_rev_f6_data_contract_v1()','EXECUTE') then raise exception 'F6.0 wrapper browser executable'; end if;
  if has_function_privilege('authenticated','public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb)','EXECUTE') then raise exception 'fingerprint helper browser executable'; end if;
  if not has_function_privilege('service_role','public.aos_rev_f6_data_contract_v1()','EXECUTE') then raise exception 'F6.0 service boundary lost'; end if;

  select * into b from public.ci_f65_protected_baseline limit 1;
  if (select count(*) from public.aos_pacientes)<>b.patients then raise exception 'patients mutated by fingerprint isolation'; end if;
  if (select count(*) from public.aos_ventas)<>b.sales then raise exception 'sales mutated by fingerprint isolation'; end if;
  if (select count(*) from public.aos_product_sale_fact_current_v1)<>b.f3 then raise exception 'F3 mutated by fingerprint isolation'; end if;
  if (select count(*) from public.aos_cartera_reconciliacion)<>b.f4 then raise exception 'F4 mutated by fingerprint isolation'; end if;
end $$;

select 'REV-F6.5 cross-workstream fingerprint isolation PASS' as result;
