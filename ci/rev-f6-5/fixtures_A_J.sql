\set ON_ERROR_STOP on

-- FIXTURE A — no source supplied: dynamic absence must remain null/NO_CERTIFIED_SOURCE, never zero revenue.
do $$
declare c jsonb; j jsonb;
begin
  c:=public.aos_rev_historical_coverage_v1();
  if c#>>'{years,2024,source_status}'<>'NO_CERTIFIED_SOURCE' or c#>>'{years,2025,source_status}'<>'NO_CERTIFIED_SOURCE' then raise exception 'fixture A source absence drift: %',c; end if;
  if c#>'{years,2024,value}'<>'null'::jsonb or c#>'{years,2025,value}'<>'null'::jsonb then raise exception 'fixture A fabricated historical value: %',c; end if;
  j:=public.aos_rev_sales_intelligence_v3(2024,'','');
  if coalesce((j->>'hasData')::boolean,true) then raise exception 'fixture A 2024 fabricated data: %',j; end if;
  if j->>'source_status'<>'NO_CERTIFIED_SOURCE' or j->'value'<>'null'::jsonb then raise exception 'fixture A runtime no-source guard failed: %',j; end if;
end $$;

-- FIXTURE B — register a 2024 manifest; availability is SOURCE_PRESENT_NOT_CERTIFIED and still not revenue.
do $$
declare j jsonb; c jsonb;
begin
  j:=public.aos_rev_historical_source_register_v1(jsonb_build_object(
    'source_year',2024,'source_filename','ventas_2024_fixture.xlsx','source_site','SAN ISIDRO','source_format','XLSX',
    'source_sha256',repeat('a',64),'source_row_count',10,'source_column_count',27,'schema_fingerprint','schema-2024-v1',
    'source_min_date','2024-01-10','source_max_date','2024-12-20','manifest_provenance',jsonb_build_object('fixture','B','origin','CI')
  ));
  if j->>'status'<>'REGISTERED' or coalesce((j->>'idempotent')::boolean,true) then raise exception 'fixture B registration failed: %',j; end if;
  c:=public.aos_rev_historical_year_coverage_v1(2024);
  if c->>'source_status'<>'SOURCE_PRESENT_NOT_CERTIFIED' or c->'value'<>'null'::jsonb then raise exception 'fixture B status drift: %',c; end if;
end $$;

-- FIXTURE C — same SHA + same immutable metadata is idempotent; registry cardinality stays one.
do $$
declare j jsonb; n integer;
begin
  j:=public.aos_rev_historical_source_register_v1(jsonb_build_object(
    'source_year',2024,'source_filename','ventas_2024_fixture.xlsx','source_site','SAN ISIDRO','source_format','XLSX',
    'source_sha256',repeat('a',64),'source_row_count',10,'source_column_count',27,'schema_fingerprint','schema-2024-v1',
    'source_min_date','2024-01-10','source_max_date','2024-12-20','manifest_provenance',jsonb_build_object('fixture','B','origin','CI')
  ));
  select count(*) into n from public.aos_rev_historical_source_manifest_v1 where source_sha256=repeat('a',64);
  if not coalesce((j->>'idempotent')::boolean,false) or n<>1 then raise exception 'fixture C idempotency failed: % rows=%',j,n; end if;
end $$;

-- FIXTURE D — same SHA + different immutable metadata fails closed and does not overwrite evidence.
do $$
declare caught boolean:=false; n integer;
begin
  begin
    perform public.aos_rev_historical_source_register_v1(jsonb_build_object(
      'source_year',2024,'source_filename','DIFFERENT.xlsx','source_site','SAN ISIDRO','source_format','XLSX',
      'source_sha256',repeat('a',64),'source_row_count',10,'source_column_count',27,'schema_fingerprint','schema-2024-v1',
      'source_min_date','2024-01-10','source_max_date','2024-12-20','manifest_provenance',jsonb_build_object('fixture','B','origin','CI')
    ));
  exception when others then
    if position('SOURCE_SHA_METADATA_CONFLICT' in sqlerrm)>0 then caught:=true; else raise; end if;
  end;
  if not caught then raise exception 'fixture D expected metadata conflict'; end if;
  select count(*) into n from public.aos_rev_historical_source_manifest_v1 where source_sha256=repeat('a',64);
  if n<>1 then raise exception 'fixture D source cardinality mutated: %',n; end if;
end $$;

-- FIXTURE E — invalid year and invalid SHA are rejected.
do $$
declare bad_year boolean:=false; bad_sha boolean:=false;
begin
  begin
    perform public.aos_rev_historical_source_register_v1(jsonb_build_object(
      'source_year',2023,'source_filename','bad-year.xlsx','source_sha256',repeat('c',64),'source_row_count',1,'source_column_count',2,
      'schema_fingerprint','bad','manifest_provenance',jsonb_build_object('fixture','E')
    ));
  exception when others then if position('INVALID_SOURCE_YEAR' in sqlerrm)>0 then bad_year:=true; else raise; end if; end;
  begin
    perform public.aos_rev_historical_source_register_v1(jsonb_build_object(
      'source_year',2025,'source_filename','bad-sha.xlsx','source_sha256','not-a-sha','source_row_count',1,'source_column_count',2,
      'schema_fingerprint','bad','manifest_provenance',jsonb_build_object('fixture','E')
    ));
  exception when others then if position('INVALID_SOURCE_SHA256' in sqlerrm)>0 then bad_sha:=true; else raise; end if; end;
  if not bad_year or not bad_sha then raise exception 'fixture E validation gates missing: year=% sha=%',bad_year,bad_sha; end if;
end $$;

-- FIXTURE F — certified partial canonical coverage is explicit, immutable and still value=null at coverage layer.
do $$
declare k text:='HIST-2024-'||repeat('a',64); j jsonb; c jsonb; immutable boolean:=false;
begin
  j:=public.aos_rev_historical_source_certify_v1(k,8,repeat('1',32),jsonb_build_object('fixture','F','gate','CROSS_DOMAIN_CERTIFIED'),jsonb_build_array('SYNTHETIC_PARTIAL'));
  if j->>'status'<>'CERTIFIED' or coalesce((j->>'idempotent')::boolean,true) then raise exception 'fixture F initial certification failed: %',j; end if;
  c:=public.aos_rev_historical_year_coverage_v1(2024);
  if c->>'source_status'<>'CERTIFIED_PARTIAL_COVERAGE' or (c->>'coverage_pct')::numeric<>80 or c->'value'<>'null'::jsonb then raise exception 'fixture F partial coverage wrong: %',c; end if;
  j:=public.aos_rev_historical_source_certify_v1(k,8,repeat('1',32),jsonb_build_object('fixture','F','gate','CROSS_DOMAIN_CERTIFIED'),jsonb_build_array('SYNTHETIC_PARTIAL'));
  if not coalesce((j->>'idempotent')::boolean,false) then raise exception 'fixture F certification replay not idempotent: %',j; end if;
  begin
    perform public.aos_rev_historical_source_certify_v1(k,9,repeat('1',32),jsonb_build_object('fixture','F','gate','CROSS_DOMAIN_CERTIFIED'),jsonb_build_array('SYNTHETIC_PARTIAL'));
  exception when others then if position('CERTIFIED_SOURCE_IMMUTABLE' in sqlerrm)>0 then immutable:=true; else raise; end if; end;
  if not immutable then raise exception 'fixture F certified source was mutable'; end if;
end $$;

-- FIXTURE G — year isolation: 2024 certification must not manufacture 2025 coverage.
do $$
declare a jsonb; b jsonb;
begin
  a:=public.aos_rev_historical_year_coverage_v1(2024);
  b:=public.aos_rev_historical_year_coverage_v1(2025);
  if a->>'source_status'<>'CERTIFIED_PARTIAL_COVERAGE' then raise exception 'fixture G 2024 drift: %',a; end if;
  if b->>'source_status'<>'NO_CERTIFIED_SOURCE' or (b->>'manifest_count')::integer<>0 then raise exception 'fixture G 2025 isolation failed: %',b; end if;
end $$;

-- FIXTURE H — complete certified 2025 source proves source coverage only; it still does not create revenue value.
do $$
declare j jsonb; c jsonb; k text:='HIST-2025-'||repeat('b',64);
begin
  perform public.aos_rev_historical_source_register_v1(jsonb_build_object(
    'source_year',2025,'source_filename','ventas_2025_fixture.csv','source_site','PUEBLO LIBRE','source_format','CSV',
    'source_sha256',repeat('b',64),'source_row_count',5,'source_column_count',27,'schema_fingerprint','schema-2025-v1',
    'source_min_date','2025-02-01','source_max_date','2025-11-30','manifest_provenance',jsonb_build_object('fixture','H','origin','CI')
  ));
  j:=public.aos_rev_historical_source_certify_v1(k,5,repeat('2',32),jsonb_build_object('fixture','H','gate','CROSS_DOMAIN_CERTIFIED'),'[]'::jsonb);
  c:=public.aos_rev_historical_year_coverage_v1(2025);
  if c->>'source_status'<>'CERTIFIED_COMPLETE' or (c->>'coverage_pct')::numeric<>100 or c->'value'<>'null'::jsonb then raise exception 'fixture H complete coverage wrong: %',c; end if;
  if c->>'semantic'<>'SOURCE_COVERAGE_NOT_REVENUE_VALUE' then raise exception 'fixture H semantic lost: %',c; end if;
end $$;

-- FIXTURE I — recompute is derived-only and repeatable; fingerprints/protected truth remain stable when no canonical historical sales were inserted.
do $$
declare a jsonb; b jsonb; c jsonb; base record;
begin
  select * into base from public.ci_f65_protected_baseline limit 1;
  a:=public.aos_rev_f6_5_contract_v1();
  perform public.aos_rev_historical_recompute_v1();
  b:=public.aos_rev_f6_5_contract_v1();
  perform public.aos_rev_historical_recompute_v1();
  c:=public.aos_rev_f6_5_contract_v1();
  if a->>'contract_fingerprint'<>b->>'contract_fingerprint' or b->>'contract_fingerprint'<>c->>'contract_fingerprint' then raise exception 'fixture I F6.5 fingerprint changed on recompute: % % %',a,b,c; end if;
  if public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint'<>base.f64_fp then raise exception 'fixture I F6.4 fingerprint regressed'; end if;
  if (select count(*) from public.aos_pacientes)<>base.patients or (select count(*) from public.aos_ventas)<>base.sales
     or (select count(*) from public.aos_product_sale_fact_current_v1)<>base.f3 or (select count(*) from public.aos_cartera_reconciliacion)<>base.f4 then
    raise exception 'fixture I protected truth mutated';
  end if;
end $$;

-- FIXTURE J — active runtime dynamic overlay + ACL + performance gate.
do $$
declare y24 jsonb; y25 jsonb; y26 jsonb; a jsonb; b jsonb; t0 timestamptz; ms numeric; max_ms numeric:=0; i integer;
begin
  y24:=public.aos_rev_sales_intelligence_v3(2024,'','');
  y25:=public.aos_rev_sales_intelligence_v3(2025,'','');
  y26:=public.aos_rev_sales_intelligence_v3(2026,'','');
  if coalesce((y24->>'hasData')::boolean,true) or y24->>'source_status'<>'CERTIFIED_PARTIAL_COVERAGE' or y24->'value'<>'null'::jsonb then raise exception 'fixture J 2024 runtime fabricated data: %',y24; end if;
  if coalesce((y25->>'hasData')::boolean,true) or y25->>'source_status'<>'CERTIFIED_COMPLETE' or y25->'value'<>'null'::jsonb then raise exception 'fixture J 2025 runtime fabricated data: %',y25; end if;
  if y26#>>'{historical_source_status,2024,source_status}'<>'CERTIFIED_PARTIAL_COVERAGE' or y26#>>'{historical_source_status,2025,source_status}'<>'CERTIFIED_COMPLETE' then raise exception 'fixture J dynamic 2026 overlay failed: %',y26; end if;
  if y26->>'historical_coverage_contract'<>'REV-F6.5_HISTORICAL_COVERAGE_V1' then raise exception 'fixture J runtime contract marker missing'; end if;

  if has_table_privilege('anon','public.aos_rev_historical_source_manifest_v1','SELECT') or has_table_privilege('authenticated','public.aos_rev_historical_source_manifest_v1','SELECT') then raise exception 'fixture J manifest browser-readable'; end if;
  if has_function_privilege('anon','public.aos_rev_historical_source_register_v1(jsonb)','EXECUTE') then raise exception 'fixture J register browser-executable'; end if;
  if has_function_privilege('authenticated','public.aos_rev_historical_recompute_v1()','EXECUTE') then raise exception 'fixture J recompute browser-executable'; end if;
  if has_function_privilege('anon','public.aos_rev_sales_intelligence_v3(integer,text,text)','EXECUTE') then raise exception 'fixture J internal V3 browser-executable'; end if;
  if not has_function_privilege('anon','public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)','EXECUTE') then raise exception 'fixture J governed gateway lost'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'fixture J legacy 360 reopened'; end if;

  a:=public.aos_rev_f6_5_contract_v1(); b:=public.aos_rev_f6_5_contract_v1();
  if a->>'contract_fingerprint' is null or a->>'contract_fingerprint'<>b->>'contract_fingerprint' then raise exception 'fixture J deterministic fingerprint unstable'; end if;
  if coalesce((a#>>'{contract,semantic_guards,no_certified_source_means_zero}')::boolean,true) then raise exception 'fixture J no-source semantic drift'; end if;
  if coalesce((a#>>'{contract,semantic_guards,manifest_coverage_is_revenue}')::boolean,true) then raise exception 'fixture J coverage-as-revenue regression'; end if;

  for i in 1..5 loop
    t0:=clock_timestamp();
    y26:=public.aos_rev_sales_intelligence_v3(2026,'','');
    ms:=extract(epoch from (clock_timestamp()-t0))*1000;
    max_ms:=greatest(max_ms,ms);
  end loop;
  if max_ms>1000 then raise exception 'fixture J F6.5 performance gate exceeded: % ms',max_ms; end if;
end $$;

select 'REV-F6.5 fixtures A-J PASS' as result;
