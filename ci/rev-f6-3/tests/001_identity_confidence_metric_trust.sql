\set ON_ERROR_STOP on

-- Existence / ACL / security boundary.
do $$
begin
  if to_regclass('public.aos_rev_identity_confidence_current_v1') is null then raise exception 'missing identity confidence view'; end if;
  if to_regprocedure('public.aos_rev_identity_confidence_by_patient_v1(text)') is null then raise exception 'missing identity confidence function'; end if;
  if to_regprocedure('public.aos_rev_identity_confidence_summary_v1()') is null then raise exception 'missing identity confidence summary'; end if;
  if to_regprocedure('public.aos_rev_metric_trust_baseline_v1()') is null then raise exception 'missing metric trust baseline'; end if;
  if to_regprocedure('public.aos_rev_f6_3_contract_v1()') is null then raise exception 'missing F6.3 contract'; end if;

  if has_table_privilege('anon','public.aos_rev_identity_confidence_current_v1','SELECT') then raise exception 'identity confidence view browser-readable'; end if;
  if has_function_privilege('anon','public.aos_rev_identity_confidence_by_patient_v1(text)','EXECUTE') then raise exception 'identity confidence function browser-executable'; end if;
  if has_function_privilege('authenticated','public.aos_rev_f6_3_contract_v1()','EXECUTE') then raise exception 'F6.3 aggregate contract browser-executable'; end if;
  if not has_function_privilege('service_role','public.aos_rev_f6_3_contract_v1()','EXECUTE') then raise exception 'service_role missing F6.3 contract'; end if;
  if has_function_privilege('anon','public.aos_patient_commercial_360_v2_f6_2_base(text,text,text)','EXECUTE') then raise exception 'private F6.2 base exposed'; end if;
  if not has_function_privilege('anon','public.aos_patient_commercial_360_v2(text,text,text)','EXECUTE') then raise exception 'governed 360 gateway unavailable'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy patient 360 reopened'; end if;
end $$;

-- SECURITY DEFINER + explicit search_path for DB-reading internal functions.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure sig,p.prosecdef,coalesce(array_to_string(p.proconfig,','),'') cfg
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'aos_rev_identity_confidence_by_patient_v1','aos_rev_identity_confidence_summary_v1',
      'aos_rev_metric_trust_baseline_v1','aos_rev_f6_3_contract_v1','aos_patient_commercial_360_v2'
    )
  loop
    if not r.prosecdef then raise exception '% must be SECURITY DEFINER',r.sig; end if;
    if position('search_path=' in r.cfg)=0 then raise exception '% missing explicit search_path',r.sig; end if;
  end loop;
end $$;

-- Deterministic identity confidence semantics.
do $$
declare j jsonb;
begin
  j:=public.aos_rev_identity_confidence_by_patient_v1('F63-HIGH');
  if j->>'confidence_level'<>'HIGH' then raise exception 'expected F63-HIGH HIGH: %',j; end if;
  if coalesce((j->>'safe_for_automatic_cross_source_attribution')::boolean,false) is not true then raise exception 'HIGH should be auto-safe under explicit contract'; end if;

  j:=public.aos_rev_identity_confidence_by_patient_v1('F63-MEDIUM');
  if j->>'confidence_level'<>'MEDIUM' then raise exception 'expected F63-MEDIUM MEDIUM: %',j; end if;
  if coalesce((j->>'safe_for_automatic_cross_source_attribution')::boolean,false) then raise exception 'MEDIUM must not auto-authorize cross-source attribution'; end if;

  j:=public.aos_rev_identity_confidence_by_patient_v1('P1');
  if j->>'confidence_level'<>'LOW' then raise exception 'conflicted P1 must be LOW: %',j; end if;
  if coalesce((j#>>'{evidence,conflict_keys}')::integer,0)<1 then raise exception 'LOW P1 must expose conflict evidence'; end if;

  j:=public.aos_rev_identity_confidence_by_patient_v1('F63-FUSED');
  if j->>'confidence_level'<>'UNRESOLVED' then raise exception 'FUSIONADO must be UNRESOLVED: %',j; end if;
  if coalesce((j->>'safe_for_automatic_cross_source_attribution')::boolean,false) then raise exception 'FUSIONADO cannot auto-authorize'; end if;
end $$;

-- Existing alias conflict remains fail-closed.
do $$
declare j jsonb;
begin
  j:=public.aos_rev_resolve_patient_identity_v2('PHONE','999333333');
  if j->>'status'<>'IDENTITY_CONFLICT' then raise exception 'shared phone must stay IDENTITY_CONFLICT: %',j; end if;
  if j->>'canonical_patient_id' is not null then raise exception 'conflicting alias produced canonical target'; end if;
end $$;

-- Metric Trust envelope: explicit and auditable, no pseudo-score.
do $$
declare j jsonb;
begin
  j:=public.aos_rev_metric_trust_envelope_v1('T_HIGH',to_jsonb(42),100,100,'TEST_COVERAGE',100,'AVAILABLE','TEST','2026-08-20 10:00+00','2026-08-20 11:00+00','2026-08-20 11:00+00','HIGH','["RULED"]'::jsonb,'[]'::jsonb,'["TEST"]'::jsonb);
  if j->>'trust_level'<>'HIGH' or j#>>'{freshness,status}'<>'CURRENT' or (j#>>'{coverage,pct}')::numeric<>100 then raise exception 'HIGH envelope invalid: %',j; end if;

  j:=public.aos_rev_metric_trust_envelope_v1('T_STALE',to_jsonb(42),100,100,'TEST_COVERAGE',100,'AVAILABLE','TEST','2026-08-20 12:00+00','2026-08-20 11:00+00','2026-08-20 12:00+00','HIGH','[]'::jsonb,'[]'::jsonb,'[]'::jsonb);
  if j->>'trust_level'<>'LOW' or j#>>'{freshness,status}'<>'STALE' then raise exception 'STALE must degrade trust: %',j; end if;

  j:=public.aos_rev_metric_trust_envelope_v1('T_LOW_COVERAGE',to_jsonb(9),9,100,'TEST_COVERAGE',100,'AVAILABLE','TEST','2026-08-20 10:00+00','2026-08-20 11:00+00','2026-08-20 11:00+00','HIGH','[]'::jsonb,'[]'::jsonb,'[]'::jsonb);
  if j->>'trust_level'<>'LOW' or j#>>'{coverage,band}'<>'LOW' then raise exception 'low coverage must remain visible: %',j; end if;

  j:=public.aos_rev_metric_trust_envelope_v1('T_NO_SOURCE','null'::jsonb,0,1,'SOURCE_AVAILABILITY',0,'NO_CERTIFIED_SOURCE','2024',null,'2026-08-20 11:00+00','2026-08-20 11:00+00','UNRESOLVED','[]'::jsonb,'[]'::jsonb,'[]'::jsonb);
  if j->>'trust_level'<>'UNAVAILABLE' or j->>'source_status'<>'NO_CERTIFIED_SOURCE' or j->'value'<>'null'::jsonb then raise exception 'NO_CERTIFIED_SOURCE must remain null/unavailable: %',j; end if;
  if not (j->'data_quality_flags' ? 'NO_CERTIFIED_SOURCE_NE_ZERO') then raise exception 'missing no-source!=zero guard'; end if;
end $$;

-- Baseline semantics frozen for downstream F6.4.
do $$
declare j jsonb;
begin
  j:=public.aos_rev_metric_trust_baseline_v1();
  if j#>>'{F4_FINANCIAL_EVIDENCE,coverage,semantic}'<>'FINANCIAL_EVIDENCE_AVAILABLE' then raise exception 'F4 semantic drift'; end if;
  if (j#>>'{F4_FINANCIAL_EVIDENCE,coverage,pct}')::numeric<>9.47 then raise exception 'F4 coverage drift'; end if;
  if j#>>'{TRANSACTIONAL_SALES_2024,source_status}'<>'NO_CERTIFIED_SOURCE' or j#>'{TRANSACTIONAL_SALES_2024,value}'<>'null'::jsonb then raise exception '2024 source semantic drift'; end if;
  if j#>>'{TRANSACTIONAL_SALES_2025,source_status}'<>'NO_CERTIFIED_SOURCE' or j#>'{TRANSACTIONAL_SALES_2025,value}'<>'null'::jsonb then raise exception '2025 source semantic drift'; end if;
  if j#>>'{LIFECYCLE_CLASSIFIED_EVIDENCE,coverage,semantic}'<>'QUALIFYING_LIFECYCLE_EVIDENCE' then raise exception 'lifecycle semantic drift'; end if;
end $$;

-- Contract fingerprint is deterministic and carries upstream boundaries.
do $$
declare a jsonb; b jsonb;
begin
  a:=public.aos_rev_f6_3_contract_v1();
  b:=public.aos_rev_f6_3_contract_v1();
  if a->>'contract_fingerprint' is null or a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'F6.3 fingerprint not deterministic'; end if;
  if a#>>'{contract,input_fingerprints,f6_0}'<>(public.aos_rev_f6_data_contract_v1()->>'contract_fingerprint') then raise exception 'F6.0 fingerprint not bound'; end if;
  if a#>>'{contract,input_fingerprints,f6_1}'<>'cd313998c5b5b38d5cb9e2f08882b826' then raise exception 'F6.1 boundary drift'; end if;
  if a#>>'{contract,input_fingerprints,f6_2}'<>'d977b9669b9e741e8785cd863caaf9c2' then raise exception 'F6.2 boundary drift'; end if;
  if coalesce((a#>>'{contract,source_semantics,no_certified_source_means_zero}')::boolean,true) then raise exception 'NO_CERTIFIED_SOURCE incorrectly means zero'; end if;
end $$;

-- Browser gateway remains governed by F6.1 Auth V3/2FA base and adds trust metadata without PHI leak to advisor.
do $$
declare j jsonb;
begin
  j:=public.aos_patient_commercial_360_v2('advisor-f61-token-00000000000000000000','CANONICAL_ID','P1');
  if coalesce((j->>'found')::boolean,false) is not true then raise exception 'advisor F6.3 gateway did not find P1: %',j; end if;
  if j->>'contract'<>'REV-F6.3_PATIENT_COMMERCIAL_360_V2' then raise exception 'gateway contract not upgraded'; end if;
  if j->'identity_confidence' is null or j#>'{metric_trust,patient_lifecycle}' is null then raise exception 'gateway missing F6.3 trust metadata'; end if;
  if position('NOTA CLINICA TEST' in j::text)>0 or position('https://example.test/doc' in j::text)>0 then raise exception 'advisor PHI boundary regressed'; end if;
end $$;

-- Protected synthetic business truth unchanged by F6.3.
do $$
declare b record;
begin
  select * into b from public.ci_f63_protected_baseline limit 1;
  if (select count(*) from public.aos_pacientes)<>b.patients then raise exception 'patient rows mutated'; end if;
  if (select count(*) from public.aos_ventas)<>b.sales then raise exception 'sales rows mutated'; end if;
  if (select count(*) from public.aos_product_sale_fact_current_v1)<>b.f3 then raise exception 'F3 rows mutated'; end if;
  if (select count(*) from public.aos_cartera_reconciliacion)<>b.f4 then raise exception 'F4 rows mutated'; end if;
  if (select count(*) from public.aos_f5_identity_cluster_members_v1)<>b.memberships then raise exception 'F5 memberships mutated'; end if;
  if (select count(*) from public.aos_f5_canonical_classification_v1)<>b.classifications then raise exception 'F5 classifications mutated'; end if;
end $$;

select 'REV-F6.3 DB/security/semantic PASS' as result;
