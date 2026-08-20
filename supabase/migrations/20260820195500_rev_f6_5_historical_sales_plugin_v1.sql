-- REV-F6.5 — Historical Sales Plug-in V1
-- Dynamic coverage/runtime boundary only. No historical business rows are fabricated or inserted into aos_ventas.

begin;

create table if not exists public.aos_rev_historical_source_manifest_v1 (
  source_key text primary key,
  source_year integer not null check (source_year in (2024,2025)),
  source_filename text not null,
  source_site text not null default 'UNSPECIFIED',
  source_format text not null default 'UNKNOWN',
  source_sha256 text not null unique check (source_sha256 ~ '^[0-9a-f]{64}$'),
  source_row_count integer not null check (source_row_count >= 0),
  source_column_count integer not null check (source_column_count > 0),
  schema_fingerprint text not null,
  source_min_date date,
  source_max_date date,
  certification_status text not null default 'REGISTERED' check (certification_status in ('REGISTERED','STAGED','CANONICALIZED','CERTIFIED','REJECTED')),
  canonical_sale_rows integer not null default 0 check (canonical_sale_rows >= 0 and canonical_sale_rows <= source_row_count),
  source_fingerprint text,
  manifest_provenance jsonb not null default '{}'::jsonb check (jsonb_typeof(manifest_provenance)='object'),
  certification_provenance jsonb,
  limitations jsonb not null default '[]'::jsonb check (jsonb_typeof(limitations)='array'),
  certified_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (source_min_date is null or extract(year from source_min_date)::integer=source_year),
  check (source_max_date is null or extract(year from source_max_date)::integer=source_year),
  check (source_min_date is null or source_max_date is null or source_min_date<=source_max_date)
);
comment on table public.aos_rev_historical_source_manifest_v1 is
'REV-F6.5 zero-PII source manifest. Manifest/SHA proves source coverage only; it is never revenue truth. Canonical historical sales must still follow staging→dedup→aos_ventas→F3→F5→F4→F6.';
alter table public.aos_rev_historical_source_manifest_v1 enable row level security;
revoke all on public.aos_rev_historical_source_manifest_v1 from public,anon,authenticated;
grant select,insert,update on public.aos_rev_historical_source_manifest_v1 to service_role;

create or replace function public.aos_rev_historical_source_register_v1(p_manifest jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_year integer;
  v_filename text;
  v_site text;
  v_format text;
  v_sha text;
  v_rows integer;
  v_cols integer;
  v_schema_fp text;
  v_min date;
  v_max date;
  v_prov jsonb;
  v_key text;
  r public.aos_rev_historical_source_manifest_v1%rowtype;
begin
  if p_manifest is null or jsonb_typeof(p_manifest)<>'object' then raise exception 'F6.5 INVALID_MANIFEST_OBJECT'; end if;
  v_year := nullif(trim(p_manifest->>'source_year'),'')::integer;
  v_filename := nullif(trim(p_manifest->>'source_filename'),'');
  v_site := coalesce(nullif(trim(p_manifest->>'source_site'),''),'UNSPECIFIED');
  v_format := upper(coalesce(nullif(trim(p_manifest->>'source_format'),''),'UNKNOWN'));
  v_sha := lower(coalesce(nullif(trim(p_manifest->>'source_sha256'),''),''));
  v_rows := nullif(trim(p_manifest->>'source_row_count'),'')::integer;
  v_cols := nullif(trim(p_manifest->>'source_column_count'),'')::integer;
  v_schema_fp := nullif(trim(p_manifest->>'schema_fingerprint'),'');
  v_min := nullif(trim(p_manifest->>'source_min_date'),'')::date;
  v_max := nullif(trim(p_manifest->>'source_max_date'),'')::date;
  v_prov := coalesce(p_manifest->'manifest_provenance','{}'::jsonb);

  if v_year not in (2024,2025) then raise exception 'F6.5 INVALID_SOURCE_YEAR'; end if;
  if v_filename is null then raise exception 'F6.5 SOURCE_FILENAME_REQUIRED'; end if;
  if v_sha !~ '^[0-9a-f]{64}$' then raise exception 'F6.5 INVALID_SOURCE_SHA256'; end if;
  if v_rows is null or v_rows<0 then raise exception 'F6.5 INVALID_SOURCE_ROW_COUNT'; end if;
  if v_cols is null or v_cols<=0 then raise exception 'F6.5 INVALID_SOURCE_COLUMN_COUNT'; end if;
  if v_schema_fp is null then raise exception 'F6.5 SCHEMA_FINGERPRINT_REQUIRED'; end if;
  if jsonb_typeof(v_prov)<>'object' or v_prov='{}'::jsonb then raise exception 'F6.5 MANIFEST_PROVENANCE_REQUIRED'; end if;
  if v_min is not null and extract(year from v_min)::integer<>v_year then raise exception 'F6.5 MIN_DATE_YEAR_MISMATCH'; end if;
  if v_max is not null and extract(year from v_max)::integer<>v_year then raise exception 'F6.5 MAX_DATE_YEAR_MISMATCH'; end if;
  if v_min is not null and v_max is not null and v_min>v_max then raise exception 'F6.5 INVALID_SOURCE_DATE_RANGE'; end if;

  select * into r from public.aos_rev_historical_source_manifest_v1 where source_sha256=v_sha;
  if found then
    if r.source_year<>v_year or r.source_filename<>v_filename or r.source_site<>v_site or r.source_format<>v_format
       or r.source_row_count<>v_rows or r.source_column_count<>v_cols or r.schema_fingerprint<>v_schema_fp
       or r.source_min_date is distinct from v_min or r.source_max_date is distinct from v_max
       or r.manifest_provenance<>v_prov then
      raise exception 'F6.5 SOURCE_SHA_METADATA_CONFLICT';
    end if;
    return jsonb_build_object('ok',true,'source_key',r.source_key,'source_year',r.source_year,'status',r.certification_status,'idempotent',true);
  end if;

  v_key := 'HIST-'||v_year::text||'-'||v_sha;
  insert into public.aos_rev_historical_source_manifest_v1(
    source_key,source_year,source_filename,source_site,source_format,source_sha256,source_row_count,source_column_count,
    schema_fingerprint,source_min_date,source_max_date,manifest_provenance
  ) values(v_key,v_year,v_filename,v_site,v_format,v_sha,v_rows,v_cols,v_schema_fp,v_min,v_max,v_prov);

  return jsonb_build_object('ok',true,'source_key',v_key,'source_year',v_year,'status','REGISTERED','idempotent',false);
end;
$$;
comment on function public.aos_rev_historical_source_register_v1(jsonb) is
'REV-F6.5 service-only idempotent source manifest registration. Same SHA + same immutable metadata replays; same SHA + different metadata fails closed.';
revoke all on function public.aos_rev_historical_source_register_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_rev_historical_source_register_v1(jsonb) to service_role;

create or replace function public.aos_rev_historical_source_certify_v1(
  p_source_key text,
  p_canonical_sale_rows integer,
  p_source_fingerprint text,
  p_certification_provenance jsonb,
  p_limitations jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  r public.aos_rev_historical_source_manifest_v1%rowtype;
  v_fp text:=lower(trim(coalesce(p_source_fingerprint,'')));
  v_limits jsonb:=coalesce(p_limitations,'[]'::jsonb);
begin
  select * into r from public.aos_rev_historical_source_manifest_v1 where source_key=p_source_key for update;
  if not found then raise exception 'F6.5 SOURCE_MANIFEST_NOT_FOUND'; end if;
  if p_canonical_sale_rows is null or p_canonical_sale_rows<0 or p_canonical_sale_rows>r.source_row_count then raise exception 'F6.5 INVALID_CANONICAL_ROW_COUNT'; end if;
  if v_fp !~ '^[0-9a-f]{32,64}$' then raise exception 'F6.5 INVALID_SOURCE_FINGERPRINT'; end if;
  if p_certification_provenance is null or jsonb_typeof(p_certification_provenance)<>'object' or p_certification_provenance='{}'::jsonb then raise exception 'F6.5 CERTIFICATION_PROVENANCE_REQUIRED'; end if;
  if jsonb_typeof(v_limits)<>'array' then raise exception 'F6.5 LIMITATIONS_MUST_BE_ARRAY'; end if;

  if r.certification_status='CERTIFIED' then
    if r.canonical_sale_rows=p_canonical_sale_rows and r.source_fingerprint=v_fp
       and r.certification_provenance=p_certification_provenance and r.limitations=v_limits then
      return jsonb_build_object('ok',true,'source_key',r.source_key,'status','CERTIFIED','idempotent',true);
    end if;
    raise exception 'F6.5 CERTIFIED_SOURCE_IMMUTABLE';
  end if;

  update public.aos_rev_historical_source_manifest_v1
  set certification_status='CERTIFIED',canonical_sale_rows=p_canonical_sale_rows,source_fingerprint=v_fp,
      certification_provenance=p_certification_provenance,limitations=v_limits,certified_at=clock_timestamp(),updated_at=clock_timestamp()
  where source_key=p_source_key;

  return jsonb_build_object('ok',true,'source_key',p_source_key,'status','CERTIFIED','idempotent',false);
end;
$$;
comment on function public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb) is
'REV-F6.5 service-only certification. Certification freezes canonical-row coverage + source fingerprint + provenance; it does not itself create revenue value.';
revoke all on function public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.aos_rev_historical_source_certify_v1(text,integer,text,jsonb,jsonb) to service_role;

create or replace function public.aos_rev_historical_year_coverage_v1(p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_manifest_count integer:=0;
  v_certified_count integer:=0;
  v_expected_rows bigint:=0;
  v_canonical_rows bigint:=0;
  v_sources jsonb:='[]'::jsonb;
  v_status text;
  v_trust text;
  v_pct numeric;
  v_limits jsonb;
begin
  if p_year not in (2024,2025) then raise exception 'F6.5 COVERAGE_YEAR_OUT_OF_SCOPE'; end if;
  select count(*)::integer,
         count(*) filter(where certification_status='CERTIFIED')::integer,
         coalesce(sum(source_row_count) filter(where certification_status='CERTIFIED'),0)::bigint,
         coalesce(sum(canonical_sale_rows) filter(where certification_status='CERTIFIED'),0)::bigint,
         coalesce(jsonb_agg(jsonb_build_object(
           'source_key',source_key,'status',certification_status,'source_rows',source_row_count,'canonical_sale_rows',canonical_sale_rows,
           'source_fingerprint',source_fingerprint,'source_site',source_site,'source_min_date',source_min_date,'source_max_date',source_max_date
         ) order by source_key),'[]'::jsonb)
  into v_manifest_count,v_certified_count,v_expected_rows,v_canonical_rows,v_sources
  from public.aos_rev_historical_source_manifest_v1
  where source_year=p_year;

  v_pct:=case when v_expected_rows>0 then round(100.0*v_canonical_rows/v_expected_rows,2) else null end;

  if v_manifest_count=0 then
    v_status:='NO_CERTIFIED_SOURCE'; v_trust:='UNAVAILABLE';
    v_limits:=jsonb_build_array('NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE');
  elsif v_certified_count=0 then
    v_status:='SOURCE_PRESENT_NOT_CERTIFIED'; v_trust:='UNAVAILABLE';
    v_limits:=jsonb_build_array('SOURCE_PRESENT_NOT_CERTIFIED_NE_REVENUE');
  elsif v_certified_count<v_manifest_count then
    v_status:='CERTIFIED_PARTIAL_SOURCE_SET'; v_trust:='LOW';
    v_limits:=jsonb_build_array('UNCERTIFIED_SOURCE_MANIFESTS_REMAIN','DO_NOT_EXTRAPOLATE_HISTORICAL_REVENUE','COVERAGE_MANIFEST_IS_NOT_REVENUE');
  elsif v_expected_rows=0 then
    v_status:='CERTIFIED_EMPTY_SOURCE'; v_trust:='LOW';
    v_limits:=jsonb_build_array('CERTIFIED_SOURCE_HAS_ZERO_EXPECTED_ROWS','ZERO_ROWS_IS_SOURCE_FACT_NOT_REVENUE_INFERENCE');
  elsif v_canonical_rows<v_expected_rows then
    v_status:='CERTIFIED_PARTIAL_COVERAGE'; v_trust:='MEDIUM';
    v_limits:=jsonb_build_array('CERTIFIED_SOURCE_PARTIAL_CANONICAL_COVERAGE','DO_NOT_EXTRAPOLATE_HISTORICAL_REVENUE','COVERAGE_MANIFEST_IS_NOT_REVENUE');
  else
    v_status:='CERTIFIED_COMPLETE'; v_trust:='HIGH';
    v_limits:=jsonb_build_array('COVERAGE_MANIFEST_IS_NOT_REVENUE','CANONICAL_READ_MODEL_REQUIRED_FOR_REVENUE');
  end if;

  return jsonb_build_object(
    'contract','REV-F6.5_HISTORICAL_COVERAGE_YEAR_V1','year',p_year,'value',null,
    'source_status',v_status,'trust_level',v_trust,'manifest_count',v_manifest_count,'certified_source_count',v_certified_count,
    'expected_source_rows',v_expected_rows,'canonical_sale_rows',v_canonical_rows,'coverage_pct',v_pct,
    'source_period',p_year::text,'sources',v_sources,'limitations',v_limits,
    'semantic','SOURCE_COVERAGE_NOT_REVENUE_VALUE'
  );
end;
$$;
revoke all on function public.aos_rev_historical_year_coverage_v1(integer) from public,anon,authenticated;
grant execute on function public.aos_rev_historical_year_coverage_v1(integer) to service_role;

create or replace function public.aos_rev_historical_coverage_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
select jsonb_build_object(
  'contract','REV-F6.5_HISTORICAL_COVERAGE_V1',
  'generated_at',clock_timestamp(),
  'years',jsonb_build_object(
    '2024',public.aos_rev_historical_year_coverage_v1(2024),
    '2025',public.aos_rev_historical_year_coverage_v1(2025)
  ),
  'semantic','DYNAMIC_SOURCE_COVERAGE_NE_REVENUE',
  'pipeline',jsonb_build_array('MANIFEST_SHA','ROW_PROVENANCE','STAGING','DEDUP_VALIDATION','AOS_VENTAS_COMPATIBLE_CANONICAL_SALE','F3_PRODUCT','F5_PATIENT','F4_FINANCIAL','RECOMPUTE_F6')
);
$$;
revoke all on function public.aos_rev_historical_coverage_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_historical_coverage_v1() to service_role;

create or replace function public.aos_rev_historical_status_map_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
select jsonb_build_object(
  '2024',public.aos_rev_historical_year_coverage_v1(2024)->>'source_status',
  '2025',public.aos_rev_historical_year_coverage_v1(2025)->>'source_status',
  '2026','AVAILABLE'
);
$$;
revoke all on function public.aos_rev_historical_status_map_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_historical_status_map_v1() to service_role;

create or replace function public.aos_rev_historical_detailed_status_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
with y24 as (select public.aos_rev_historical_year_coverage_v1(2024) j),
     y25 as (select public.aos_rev_historical_year_coverage_v1(2025) j)
select jsonb_build_object(
  '2024',jsonb_build_object('value',null,'source_status',y24.j->>'source_status','trust_level',y24.j->>'trust_level','coverage_pct',y24.j->'coverage_pct','canonical_sale_rows',y24.j->'canonical_sale_rows'),
  '2025',jsonb_build_object('value',null,'source_status',y25.j->>'source_status','trust_level',y25.j->>'trust_level','coverage_pct',y25.j->'coverage_pct','canonical_sale_rows',y25.j->'canonical_sale_rows'),
  '2026',jsonb_build_object('source_status','AVAILABLE','min_date',(select min(sale_date) from public.aos_rev_si_sales_fact_v1),'max_date',(select max(sale_date) from public.aos_rev_si_sales_fact_v1))
)
from y24,y25;
$$;
revoke all on function public.aos_rev_historical_detailed_status_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_historical_detailed_status_v1() to service_role;

-- Freeze the certified F6.4 runtime as an internal base once. Replays keep the base intact.
do $$
begin
  if to_regprocedure('public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text)') is null then
    if to_regprocedure('public.aos_rev_sales_intelligence_v3(integer,text,text)') is null then
      raise exception 'F6.5 F6.4 RUNTIME BASE NOT FOUND';
    end if;
    execute 'alter function public.aos_rev_sales_intelligence_v3(integer,text,text) rename to aos_rev_sales_intelligence_v3_f6_4_runtime_base';
  end if;
end $$;
revoke all on function public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(integer,text,text) to service_role;

-- Active runtime overlay: all historical availability is now dynamic. F6.4 hardcoded historical labels are no longer authoritative runtime output.
create or replace function public.aos_rev_sales_intelligence_v3(p_anio integer,p_sede text default '',p_asesor text default '')
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_payload jsonb;
  v_cov jsonb;
  v_status text;
begin
  v_payload:=public.aos_rev_sales_intelligence_v3_f6_4_runtime_base(p_anio,p_sede,p_asesor);
  if coalesce((v_payload->>'ok')::boolean,false) is not true then return v_payload; end if;

  if p_anio in (2024,2025) then
    v_cov:=public.aos_rev_historical_year_coverage_v1(p_anio);
    v_status:=v_cov->>'source_status';
    v_payload:=jsonb_set(v_payload,'{historical_coverage}',v_cov,true);
    if coalesce((v_payload->>'hasData')::boolean,false) then
      v_payload:=jsonb_set(v_payload,'{historical_source_status}',public.aos_rev_historical_detailed_status_v1(),true);
    else
      v_payload:=jsonb_set(v_payload,'{source_status}',to_jsonb(v_status),true);
      v_payload:=jsonb_set(v_payload,'{value}','null'::jsonb,true);
      v_payload:=jsonb_set(v_payload,'{limitations}',coalesce(v_cov->'limitations','[]'::jsonb),true);
      v_payload:=jsonb_set(v_payload,'{historical_source_status}',public.aos_rev_historical_status_map_v1(),true);
    end if;
  elsif p_anio=2026 then
    v_payload:=jsonb_set(v_payload,'{historical_source_status}',public.aos_rev_historical_detailed_status_v1(),true);
  else
    v_payload:=jsonb_set(v_payload,'{historical_source_status}',public.aos_rev_historical_status_map_v1(),true);
  end if;

  return v_payload || jsonb_build_object('historical_coverage_contract','REV-F6.5_HISTORICAL_COVERAGE_V1');
end;
$$;
comment on function public.aos_rev_sales_intelligence_v3(integer,text,text) is
'REV-F6.5 active Sales Intelligence runtime. F6.4 analytics remain the base; historical source availability is dynamically governed by the F6.5 coverage contract.';
revoke all on function public.aos_rev_sales_intelligence_v3(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3(integer,text,text) to service_role;

create or replace function public.aos_rev_f6_5_contract_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_cov jsonb;
  v_payload jsonb;
  v_fp text;
  v_f64 text;
  v_manifest_rows integer;
  v_certified integer;
begin
  v_cov:=public.aos_rev_historical_coverage_v1()-'generated_at';
  v_f64:=public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint';
  select count(*)::integer,count(*) filter(where certification_status='CERTIFIED')::integer
    into v_manifest_rows,v_certified from public.aos_rev_historical_source_manifest_v1;

  v_payload:=jsonb_build_object(
    'contract','REV-F6.5_HISTORICAL_SALES_PLUGIN_V1',
    'upstream_f6_4_fingerprint',v_f64,
    'historical_coverage',v_cov,
    'manifest_rows',v_manifest_rows,
    'certified_sources',v_certified,
    'runtime',jsonb_build_object('active_historical_coverage_contract','REV-F6.5_HISTORICAL_COVERAGE_V1','f6_4_runtime_retained_as_internal_base',true,'hardcoded_2024_2025_runtime_status',false),
    'semantic_guards',jsonb_build_object(
      'no_certified_source_means_zero',false,
      'manifest_coverage_is_revenue',false,
      'uncertified_source_exposed_as_revenue',false,
      'direct_mass_insert_into_aos_ventas',false,
      'phone_only_identity_authority',false,
      'f3_f5_f4_reuse_required',true,
      'source_file_required_before_historical_revenue',true
    ),
    'ingestion_contract',jsonb_build_object(
      'files_supplied_now',(v_manifest_rows>0),
      'pipeline','MANIFEST/SHA -> ROW PROVENANCE -> STAGING -> DEDUP/VALIDATION -> AOS_VENTAS-COMPATIBLE CANONICAL SALE -> F3 -> F5 -> F4 -> RECOMPUTE F6',
      'raw_business_rows_created_by_f6_5',false,
      'replay_rule','SAME_SHA_SAME_METADATA_IDEMPOTENT; SAME_SHA_DIFFERENT_METADATA_FAIL_CLOSED'
    ),
    'performance_contract',jsonb_build_object('live_rpc_target_ms',1000,'timeout_increase_is_solution',false,'coverage_registry_is_bounded',true),
    'security',jsonb_build_object('manifest_browser_closed',true,'control_functions_service_only',true,'raw_pii_phi_in_coverage_contract',false,'existing_admin_2fa_gateway_preserved',true)
  );
  v_fp:=md5(v_payload::text);
  return jsonb_build_object('ok',true,'generated_at',clock_timestamp(),'contract',v_payload,'contract_fingerprint',v_fp);
end;
$$;
comment on function public.aos_rev_f6_5_contract_v1() is
'REV-F6.5 deterministic contract. Fingerprint excludes generated_at and changes only when governed historical coverage/upstream certified state changes.';
revoke all on function public.aos_rev_f6_5_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_5_contract_v1() to service_role;

create or replace function public.aos_rev_historical_recompute_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_before text;
  v_after text;
  v_refresh jsonb;
  v_contract jsonb;
begin
  v_before:=public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint';
  v_refresh:=public.aos_rev_si_refresh_v1();
  v_after:=public.aos_rev_f6_4_contract_v1()->>'contract_fingerprint';
  v_contract:=public.aos_rev_f6_5_contract_v1();
  return jsonb_build_object('ok',true,'upstream_f6_4_before',v_before,'upstream_f6_4_after',v_after,'f6_4_refresh',v_refresh,'f6_5',v_contract,'recompute_semantic','DERIVED_READ_MODELS_ONLY_NO_BUSINESS_SOURCE_MUTATION');
end;
$$;
comment on function public.aos_rev_historical_recompute_v1() is
'REV-F6.5 service-only recompute hook. Refreshes F6 read models after a future canonical historical ingest; never ingests or mutates source business rows itself.';
revoke all on function public.aos_rev_historical_recompute_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_historical_recompute_v1() to service_role;

select public.aos_rev_historical_recompute_v1();

commit;
