\set ON_ERROR_STOP on

-- REV-F6.7 final acceptance against the isolated F6.4 fixture.
do $$
declare
  v jsonb;
  v_direct numeric;
  v_direct_count integer;
  v_monthly numeric;
  v_ms numeric;
  v_t0 timestamptz;
  i integer;
begin
  v:=public.aos_sales_intelligence_gateway('bad-token',2026,'','');
  if coalesce(v->>'error','')<>'UNAUTHORIZED' then
    raise exception 'F67_UNAUTHORIZED_NOT_CLOSED %',v;
  end if;

  v:=public.aos_sales_intelligence_gateway('admin-f64-token-00000000000000000000',2026,'','');
  if v->>'api_version'<>'V3' or v->>'ui_contract'<>'REV-F6.7_SALES_INTELLIGENCE_UI_V1' then
    raise exception 'F67_V3_CONTRACT_MISSING %',v;
  end if;
  if coalesce((v->>'legacy_compatibility')::boolean,false) is not true
     or coalesce((v->>'authorized')::boolean,false) is not true then
    raise exception 'F67_LEGACY_COMPATIBILITY_LOST %',v;
  end if;
  if v->'metric_trust' is null or v->'executive_revenue' is null then
    raise exception 'F67_V3_ANALYTICS_MISSING %',v;
  end if;

  if v#>>'{metric_trust,executive_revenue,coverage,pct}' is null
     or v#>>'{metric_trust,executive_revenue,confidence,level}' is null
     or v#>>'{metric_trust,executive_revenue,freshness,status}' is null
     or v#>>'{metric_trust,executive_revenue,sample_size}' is null then
    raise exception 'F67_TRUST_FIELDS_INCOMPLETE %',v->'metric_trust'->'executive_revenue';
  end if;

  if v#>>'{historical_source_status,2024,source_status}'<>'NO_CERTIFIED_SOURCE'
     or v#>>'{historical_source_status,2025,source_status}'<>'NO_CERTIFIED_SOURCE'
     or (v#>'{historical_source_status,2024,value}') is not null
     or (v#>'{historical_source_status,2025,value}') is not null then
    raise exception 'F67_HISTORICAL_NULL_SEMANTICS_REGRESSED %',v->'historical_source_status';
  end if;

  select coalesce(sum(monto),0),count(*) into v_direct,v_direct_count
  from public.aos_ventas
  where extract(year from fecha)=2026;
  if round(coalesce((v#>>'{executive_revenue,billed_amount}')::numeric,0),2)<>round(v_direct,2)
     or coalesce((v#>>'{executive_revenue,transactions}')::integer,-1)<>v_direct_count then
    raise exception 'F67_EXECUTIVE_RECONCILIATION_FAIL rpc=% direct=%/%',v->'executive_revenue',v_direct,v_direct_count;
  end if;

  select coalesce(sum((x->>'billed_amount')::numeric),0) into v_monthly
  from jsonb_array_elements(coalesce(v->'monthly','[]'::jsonb)) x;
  if round(v_monthly,2)<>round(v_direct,2) then
    raise exception 'F67_MONTHLY_RECONCILIATION_FAIL monthly=% direct=%',v_monthly,v_direct;
  end if;

  -- One gateway invocation must remain bounded; this catches accidental mega-query regression.
  for i in 1..5 loop
    v_t0:=clock_timestamp();
    perform public.aos_sales_intelligence_gateway('admin-f64-token-00000000000000000000',2026,'','');
    v_ms:=extract(epoch from (clock_timestamp()-v_t0))*1000;
    if v_ms>=1000 then
      raise exception 'F67_GATEWAY_PERFORMANCE_FAIL ms=%',v_ms;
    end if;
  end loop;
end $$;

-- ACL/privacy topology: compatibility base is private; governed browser entrypoints remain callable.
do $$
begin
  if has_function_privilege('anon','public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)','EXECUTE') then
    raise exception 'F67_LEGACY_BASE_BROWSER_OPEN';
  end if;
  if not has_function_privilege('service_role','public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)','EXECUTE') then
    raise exception 'F67_LEGACY_BASE_SERVICE_CLOSED';
  end if;
  if not has_function_privilege('anon','public.aos_sales_intelligence_gateway(text,integer,text,text)','EXECUTE')
     or not has_function_privilege('anon','public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)','EXECUTE') then
    raise exception 'F67_GOVERNED_BROWSER_GATEWAY_CLOSED';
  end if;
  if has_function_privilege('anon','public.aos_rev_sales_intelligence_v3(integer,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_rev_sales_intelligence_v3(integer,text,text)','EXECUTE') then
    raise exception 'F67_RAW_V3_BROWSER_OPEN';
  end if;
end $$;

select 'REV_F6_7_DB_ACCEPTANCE=PASS' as result;
