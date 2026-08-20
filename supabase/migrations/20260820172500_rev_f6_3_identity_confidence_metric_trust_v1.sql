-- REV-F6.3 — Identity Confidence + Metric Trust V1
-- Read/intelligence layer only. No patient merge, no sales/F3/F4 mutation, no historical revenue inference.

begin;

create or replace view public.aos_rev_identity_confidence_current_v1 as
with alias_stats as (
  select
    a.canonical_patient_id,
    count(distinct a.identifier_type) filter(where a.status='RESOLVED' and a.identifier_type<>'CANONICAL_ID')::integer resolved_alias_types,
    count(distinct (a.identifier_type,a.identifier_key)) filter(where a.status='CONFLICT' and a.identifier_type in ('PHONE','DOCUMENT','EMAIL'))::integer conflict_keys,
    bool_or(a.has_reviewed_match) as has_reviewed_alias
  from public.aos_rev_patient_identity_alias_v2 a
  group by a.canonical_patient_id
), class_stats as (
  select
    c.target_patient_id::text canonical_patient_id,
    count(*) filter(where c.classification='MATCH')::integer reviewed_match_clusters,
    count(*) filter(where c.classification='REVIEW')::integer review_clusters
  from public.aos_f5_canonical_classification_v1 c
  where c.target_patient_id is not null
  group by c.target_patient_id
)
select
  p."ID_PACIENTE"::text canonical_patient_id,
  case
    when coalesce(a.conflict_keys,0)>0 then 'LOW'
    when coalesce(c.reviewed_match_clusters,0)>0 and coalesce(a.resolved_alias_types,0)>0 then 'HIGH'
    else 'MEDIUM'
  end::text confidence_level,
  coalesce(c.reviewed_match_clusters,0)::integer reviewed_match_clusters,
  coalesce(c.review_clusters,0)::integer review_clusters,
  coalesce(a.resolved_alias_types,0)::integer resolved_alias_types,
  coalesce(a.conflict_keys,0)::integer conflict_keys,
  coalesce(a.has_reviewed_alias,false) as has_reviewed_alias,
  case
    when coalesce(a.conflict_keys,0)>0 then jsonb_build_array('STRONG_ALIAS_CONFLICT_PRESENT','CANONICAL_ID_REMAINS_SUBJECT')
    when coalesce(c.reviewed_match_clusters,0)>0 and coalesce(a.resolved_alias_types,0)>0 then jsonb_build_array('F5_REVIEWED_MATCH','NON_CONFLICTING_ALIAS_EVIDENCE','CANONICAL_ID_AUTHORITY')
    when coalesce(a.resolved_alias_types,0)>0 then jsonb_build_array('CANONICAL_CURRENT','NON_CONFLICTING_ALIAS_EVIDENCE','NO_REVIEWED_HISTORICAL_MATCH')
    else jsonb_build_array('CANONICAL_CURRENT_ONLY','NO_REVIEWED_HISTORICAL_MATCH')
  end as reason_codes,
  case
    when coalesce(a.conflict_keys,0)>0 then jsonb_build_array('ALIAS_CONFLICT_BLOCKS_AUTOMATIC_CROSS_SOURCE_ATTRIBUTION')
    when coalesce(c.reviewed_match_clusters,0)=0 then jsonb_build_array('HISTORICAL_IDENTITY_LINKAGE_NOT_REVIEWED_MATCH')
    else '[]'::jsonb
  end as limitations,
  (coalesce(a.conflict_keys,0)=0 and coalesce(c.reviewed_match_clusters,0)>0 and coalesce(a.resolved_alias_types,0)>0) as safe_for_automatic_cross_source_attribution
from public.aos_pacientes p
left join alias_stats a on a.canonical_patient_id=p."ID_PACIENTE"::text
left join class_stats c on c.canonical_patient_id=p."ID_PACIENTE"::text
where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO';

comment on view public.aos_rev_identity_confidence_current_v1 is
'REV-F6.3 private canonical-patient identity confidence. Deterministic evidence bands only; no fuzzy identity, phone-nearness authority or second patient truth layer.';
revoke all on public.aos_rev_identity_confidence_current_v1 from public,anon,authenticated;
grant select on public.aos_rev_identity_confidence_current_v1 to service_role;

create or replace function public.aos_rev_identity_confidence_by_patient_v1(p_canonical_patient_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_row record;
begin
  select * into v_row
  from public.aos_rev_identity_confidence_current_v1 x
  where x.canonical_patient_id=p_canonical_patient_id;

  if not found then
    return jsonb_build_object(
      'contract','REV-F6.3_IDENTITY_CONFIDENCE_V1',
      'canonical_patient_id',p_canonical_patient_id,
      'confidence_level','UNRESOLVED',
      'reason_codes',jsonb_build_array('CANONICAL_TARGET_MISSING_OR_FUSIONADO'),
      'limitations',jsonb_build_array('NO_AUTOMATIC_ATTRIBUTION_ALLOWED'),
      'safe_for_automatic_cross_source_attribution',false
    );
  end if;

  return jsonb_build_object(
    'contract','REV-F6.3_IDENTITY_CONFIDENCE_V1',
    'canonical_patient_id',v_row.canonical_patient_id,
    'confidence_level',v_row.confidence_level,
    'evidence',jsonb_build_object(
      'reviewed_match_clusters',v_row.reviewed_match_clusters,
      'review_clusters',v_row.review_clusters,
      'resolved_alias_types',v_row.resolved_alias_types,
      'conflict_keys',v_row.conflict_keys,
      'has_reviewed_alias',v_row.has_reviewed_alias
    ),
    'reason_codes',v_row.reason_codes,
    'limitations',v_row.limitations,
    'safe_for_automatic_cross_source_attribution',v_row.safe_for_automatic_cross_source_attribution,
    'authority','canonical_patient_id',
    'guards',jsonb_build_object(
      'name_alone_authorizes_identity',false,
      'phone_alone_authorizes_identity',false,
      'phone_nearness_authorizes_identity',false,
      'conflict_auto_resolves',false
    )
  );
end;
$$;
comment on function public.aos_rev_identity_confidence_by_patient_v1(text) is
'REV-F6.3 service-only identity-confidence explainer. Missing/fused targets are UNRESOLVED; alias conflicts are LOW and never auto-authorize cross-source attribution.';
revoke all on function public.aos_rev_identity_confidence_by_patient_v1(text) from public,anon,authenticated;
grant execute on function public.aos_rev_identity_confidence_by_patient_v1(text) to service_role;

create or replace function public.aos_rev_identity_confidence_summary_v1()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
select jsonb_build_object(
  'contract','REV-F6.3_IDENTITY_CONFIDENCE_V1',
  'canonical_population',count(*)::integer,
  'HIGH',count(*) filter(where confidence_level='HIGH')::integer,
  'MEDIUM',count(*) filter(where confidence_level='MEDIUM')::integer,
  'LOW',count(*) filter(where confidence_level='LOW')::integer,
  'UNRESOLVED',0,
  'safe_for_automatic_cross_source_attribution',count(*) filter(where safe_for_automatic_cross_source_attribution)::integer,
  'patients_with_conflict_keys',count(*) filter(where conflict_keys>0)::integer,
  'phone_conflict_keys',(select count(distinct identifier_key)::integer from public.aos_rev_patient_identity_alias_v2 where identifier_type='PHONE' and status='CONFLICT'),
  'authority','canonical_patient_id'
)
from public.aos_rev_identity_confidence_current_v1;
$$;
comment on function public.aos_rev_identity_confidence_summary_v1() is
'REV-F6.3 aggregate identity-confidence distribution without raw aliases/PII.';
revoke all on function public.aos_rev_identity_confidence_summary_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_identity_confidence_summary_v1() to service_role;

create or replace function public.aos_rev_metric_trust_envelope_v1(
  p_metric_key text,
  p_value jsonb,
  p_coverage_numerator bigint,
  p_coverage_denominator bigint,
  p_coverage_semantic text,
  p_sample_size bigint,
  p_source_status text,
  p_source_period text,
  p_source_updated_at timestamptz,
  p_generated_at timestamptz,
  p_as_of timestamptz,
  p_confidence_level text,
  p_confidence_reasons jsonb default '[]'::jsonb,
  p_limitations jsonb default '[]'::jsonb,
  p_provenance jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
immutable
set search_path=''
as $$
declare
  v_pct numeric;
  v_coverage_band text;
  v_freshness text;
  v_confidence text := upper(coalesce(p_confidence_level,'UNRESOLVED'));
  v_source_status text := upper(coalesce(p_source_status,'UNKNOWN'));
  v_trust text;
  v_flags jsonb := '[]'::jsonb;
begin
  if v_confidence not in ('HIGH','MEDIUM','LOW','UNRESOLVED') then v_confidence := 'UNRESOLVED'; end if;

  if p_coverage_denominator is null or p_coverage_denominator<=0 then
    v_pct := null;
    v_coverage_band := 'UNAVAILABLE';
  else
    v_pct := round((100.0*p_coverage_numerator::numeric/p_coverage_denominator::numeric),2);
    v_coverage_band := case when v_pct>=95 then 'HIGH' when v_pct>=50 then 'MEDIUM' else 'LOW' end;
  end if;

  if p_source_updated_at is null or p_generated_at is null then
    v_freshness := 'UNKNOWN';
  elsif p_source_updated_at>p_generated_at then
    v_freshness := 'STALE';
  else
    v_freshness := 'CURRENT';
  end if;

  if v_source_status in ('NO_CERTIFIED_SOURCE','UNAVAILABLE') then
    v_trust := 'UNAVAILABLE';
  elsif v_freshness in ('STALE','UNKNOWN') then
    v_trust := 'LOW';
  elsif v_coverage_band in ('LOW','UNAVAILABLE') then
    v_trust := 'LOW';
  elsif v_confidence in ('LOW','UNRESOLVED') then
    v_trust := 'LOW';
  elsif v_coverage_band='MEDIUM' or v_confidence='MEDIUM' then
    v_trust := 'MEDIUM';
  else
    v_trust := 'HIGH';
  end if;

  if v_source_status='NO_CERTIFIED_SOURCE' then v_flags := v_flags || jsonb_build_array('NO_CERTIFIED_SOURCE_NE_ZERO'); end if;
  if v_coverage_band='LOW' then v_flags := v_flags || jsonb_build_array('LOW_COVERAGE'); end if;
  if v_freshness='STALE' then v_flags := v_flags || jsonb_build_array('STALE_DERIVED_MODEL'); end if;
  if v_freshness='UNKNOWN' then v_flags := v_flags || jsonb_build_array('UNKNOWN_FRESHNESS'); end if;
  if coalesce(p_sample_size,0)<10 then v_flags := v_flags || jsonb_build_array('SMALL_SAMPLE'); end if;

  return jsonb_build_object(
    'contract','REV-F6.3_METRIC_TRUST_V1',
    'metric_key',p_metric_key,
    'value',p_value,
    'coverage',jsonb_build_object(
      'numerator',p_coverage_numerator,
      'denominator',p_coverage_denominator,
      'pct',v_pct,
      'semantic',p_coverage_semantic,
      'band',v_coverage_band
    ),
    'confidence',jsonb_build_object(
      'level',v_confidence,
      'reasons',coalesce(p_confidence_reasons,'[]'::jsonb)
    ),
    'freshness',jsonb_build_object(
      'status',v_freshness,
      'source_updated_at',p_source_updated_at,
      'generated_at',p_generated_at,
      'as_of',p_as_of
    ),
    'sample_size',p_sample_size,
    'source_status',v_source_status,
    'source_period',p_source_period,
    'limitations',coalesce(p_limitations,'[]'::jsonb),
    'data_quality_flags',v_flags,
    'provenance',coalesce(p_provenance,'[]'::jsonb),
    'trust_level',v_trust,
    'trust_rule','SOURCE_AVAILABILITY -> FRESHNESS -> COVERAGE -> CONFIDENCE; no opaque score'
  );
end;
$$;
comment on function public.aos_rev_metric_trust_envelope_v1(text,jsonb,bigint,bigint,text,bigint,text,text,timestamptz,timestamptz,timestamptz,text,jsonb,jsonb,jsonb) is
'REV-F6.3 reusable deterministic Metric Trust envelope. Keeps source availability, coverage, confidence, freshness and sample size distinct; no pseudo-probability score.';
revoke all on function public.aos_rev_metric_trust_envelope_v1(text,jsonb,bigint,bigint,text,bigint,text,text,timestamptz,timestamptz,timestamptz,text,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.aos_rev_metric_trust_envelope_v1(text,jsonb,bigint,bigint,text,bigint,text,text,timestamptz,timestamptz,timestamptz,text,jsonb,jsonb,jsonb) to service_role;

create or replace function public.aos_rev_metric_trust_baseline_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_f60 jsonb := public.aos_rev_f6_data_contract_v1();
  v_lc jsonb := public.aos_rev_customer_lifecycle_summary_v1(public.aos_rev_business_date_lima_v1());
  v_now timestamptz := clock_timestamp();
  v_patient_updated timestamptz;
  v_sales_updated timestamptz;
  v_f4_updated timestamptz;
  v_agenda_updated timestamptz;
begin
  v_patient_updated := nullif(v_f60#>>'{contract,freshness_sources,patient_source_updated_at}','')::timestamptz;
  v_sales_updated := nullif(v_f60#>>'{contract,freshness_sources,sales_updated_at}','')::timestamptz;
  v_f4_updated := nullif(v_f60#>>'{contract,freshness_sources,f4_updated_at}','')::timestamptz;
  select max(c.ts_actualizado) into v_agenda_updated from public.aos_agenda_citas c;

  return jsonb_build_object(
    'contract','REV-F6.3_METRIC_TRUST_BASELINE_V1',
    'IDENTITY_SAFE_MATCH',public.aos_rev_metric_trust_envelope_v1(
      'IDENTITY_SAFE_MATCH',to_jsonb(3.40::numeric),296,8716,'SAFE_IDENTITY_LINKAGE',8716,'AVAILABLE_PARTIAL_COVERAGE','F5_CERTIFIED_PATIENT_HISTORY',v_patient_updated,v_now,v_now,'HIGH',
      jsonb_build_array('F5_MATCH_CLASSIFICATION_IS_GOVERNED'),jsonb_build_array('ONLY_SAFE_MATCH_CLUSTERS_ARE_LINKED'),jsonb_build_array('REV-F5','REV-F6.0')
    ),
    'SALES_SAFE_LINKAGE',public.aos_rev_metric_trust_envelope_v1(
      'SALES_SAFE_LINKAGE',to_jsonb(16.01::numeric),208,1299,'SAFE_SALES_TO_CANONICAL_PATIENT_LINKAGE',1299,'AVAILABLE_PARTIAL_COVERAGE','2026-01-05_TO_2026-08-15',greatest(v_patient_updated,v_sales_updated),v_now,v_now,'HIGH',
      jsonb_build_array('F5_MATCH_ONLY'),jsonb_build_array('UNRESOLVED_AND_REVIEW_SALES_EXCLUDED'),jsonb_build_array('REV-F5','aos_ventas')
    ),
    'F3_PRODUCT_RESOLUTION',public.aos_rev_metric_trust_envelope_v1(
      'F3_PRODUCT_RESOLUTION',to_jsonb(97.78::numeric),397,406,'PRODUCT_FACT_RESOLUTION',406,'AVAILABLE','2026_CERTIFIED_SALES_SCOPE',v_sales_updated,v_now,v_now,'HIGH',
      jsonb_build_array('F3_IS_PRODUCT_TRUTH'),jsonb_build_array('ONLY_APPLICABLE_F3_FACTS_IN_DENOMINATOR'),jsonb_build_array('REV-F3')
    ),
    'F4_FINANCIAL_EVIDENCE',public.aos_rev_metric_trust_envelope_v1(
      'F4_FINANCIAL_EVIDENCE',to_jsonb(9.47::numeric),123,1299,'FINANCIAL_EVIDENCE_AVAILABLE',1299,'AVAILABLE_PARTIAL_COVERAGE','2026_CERTIFIED_SALES_SCOPE',v_f4_updated,v_now,v_now,'HIGH',
      jsonb_build_array('F4_IS_FINANCIAL_TRUTH'),jsonb_build_array('MISSING_F4_EVIDENCE_IS_NOT_NON_PAYMENT','ADELANTO_IS_NOT_AUTOMATIC_DEBT'),jsonb_build_array('REV-F4')
    ),
    'HISTORICAL_TRANSACTION_SOURCE_AVAILABILITY',public.aos_rev_metric_trust_envelope_v1(
      'HISTORICAL_TRANSACTION_SOURCE_AVAILABILITY',to_jsonb(33.33::numeric),1,3,'SOURCE_AVAILABILITY_NOT_REVENUE',3,'PARTIAL_CERTIFIED_SOURCE','2024_2026_REQUESTED_YEARS',v_sales_updated,v_now,v_now,'HIGH',
      jsonb_build_array('SOURCE_BOUNDARY_AUDITED'),jsonb_build_array('2024_2025_TRANSACTIONAL_SALES_NO_CERTIFIED_SOURCE','DO_NOT_INTERPRET_AS_ZERO_REVENUE'),jsonb_build_array('REV-F5.8','REV-F6.0')
    ),
    'TRANSACTIONAL_SALES_2024',public.aos_rev_metric_trust_envelope_v1(
      'TRANSACTIONAL_SALES_2024','null'::jsonb,0,1,'SOURCE_AVAILABILITY',0,'NO_CERTIFIED_SOURCE','2024',null,v_now,v_now,'UNRESOLVED',
      jsonb_build_array('NO_CERTIFIED_TRANSACTIONAL_SOURCE'),jsonb_build_array('NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE'),jsonb_build_array('REV-F6.0')
    ),
    'TRANSACTIONAL_SALES_2025',public.aos_rev_metric_trust_envelope_v1(
      'TRANSACTIONAL_SALES_2025','null'::jsonb,0,1,'SOURCE_AVAILABILITY',0,'NO_CERTIFIED_SOURCE','2025',null,v_now,v_now,'UNRESOLVED',
      jsonb_build_array('NO_CERTIFIED_TRANSACTIONAL_SOURCE'),jsonb_build_array('NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE'),jsonb_build_array('REV-F6.0')
    ),
    'LIFECYCLE_CLASSIFIED_EVIDENCE',public.aos_rev_metric_trust_envelope_v1(
      'LIFECYCLE_CLASSIFIED_EVIDENCE',to_jsonb((v_lc->>'classified_population')::integer),(v_lc->>'classified_population')::bigint,(v_lc->>'canonical_population')::bigint,'QUALIFYING_LIFECYCLE_EVIDENCE',(v_lc->>'qualifying_event_rows')::bigint,'AVAILABLE_PARTIAL_COVERAGE','PATIENT_HISTORY_2024_2026_PLUS_2026_TRANSACTIONS',greatest(v_patient_updated,v_sales_updated,v_agenda_updated),v_now,v_now,'HIGH',
      jsonb_build_array('DETERMINISTIC_F6_2_STATE_RULES'),jsonb_build_array('INSUFFICIENT_ACTIVITY_EVIDENCE_REMAINS_UNCLASSIFIED','PATIENT_HISTORY_IS_NOT_HISTORICAL_REVENUE'),jsonb_build_array('REV-F6.2')
    )
  );
end;
$$;
comment on function public.aos_rev_metric_trust_baseline_v1() is
'REV-F6.3 service-only trust baseline for F6.4. Explicit low coverage stays visible; 2024/2025 transactional sales remain NO_CERTIFIED_SOURCE, not zero.';
revoke all on function public.aos_rev_metric_trust_baseline_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_metric_trust_baseline_v1() to service_role;

create or replace function public.aos_rev_f6_3_contract_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_f60 jsonb := public.aos_rev_f6_data_contract_v1();
  v_identity jsonb := public.aos_rev_identity_confidence_summary_v1();
  v_lc jsonb := public.aos_rev_customer_lifecycle_summary_v1(public.aos_rev_business_date_lima_v1());
  v_bridge jsonb;
  v_payload jsonb;
  v_fp text;
begin
  select jsonb_object_agg(identifier_type,jsonb_build_object(
    'keys',keys,'resolved',resolved,'conflicts',conflicts,'max_candidates',max_candidates
  ) order by identifier_type)
  into v_bridge
  from (
    select identifier_type,
           count(distinct identifier_key)::integer keys,
           count(distinct identifier_key) filter(where status='RESOLVED')::integer resolved,
           count(distinct identifier_key) filter(where status='CONFLICT')::integer conflicts,
           max(candidate_count)::integer max_candidates
    from public.aos_rev_patient_identity_alias_v2
    group by identifier_type
  ) q;

  v_payload := jsonb_build_object(
    'contract_id','REV-F6.3_IDENTITY_CONFIDENCE_METRIC_TRUST_V1',
    'contract_version',1,
    'identity_confidence_distribution',v_identity,
    'identity_bridge',v_bridge,
    'metric_trust_rules',jsonb_build_object(
      'required_fields',jsonb_build_array('value','coverage','confidence','freshness','sample_size'),
      'coverage_requires',jsonb_build_array('numerator','denominator','pct','semantic'),
      'confidence_levels',jsonb_build_array('HIGH','MEDIUM','LOW','UNRESOLVED'),
      'freshness_levels',jsonb_build_array('CURRENT','STALE','UNKNOWN'),
      'trust_precedence',jsonb_build_array('SOURCE_AVAILABILITY','FRESHNESS','COVERAGE','CONFIDENCE'),
      'opaque_numeric_confidence_score',false,
      'no_certified_source_is_zero',false
    ),
    'coverage_baselines',jsonb_build_object(
      'identity',jsonb_build_object('numerator',296,'denominator',8716,'pct',3.40,'semantic','SAFE_IDENTITY_LINKAGE'),
      'sales_linkage',jsonb_build_object('numerator',208,'denominator',1299,'pct',16.01,'semantic','SAFE_SALES_TO_CANONICAL_PATIENT_LINKAGE'),
      'f3_product',jsonb_build_object('numerator',397,'denominator',406,'pct',97.78,'semantic','PRODUCT_FACT_RESOLUTION'),
      'f4_financial',jsonb_build_object('numerator',123,'denominator',1299,'pct',9.47,'semantic','FINANCIAL_EVIDENCE_AVAILABLE'),
      'historical_transaction_source',jsonb_build_object('numerator',1,'denominator',3,'pct',33.33,'semantic','SOURCE_AVAILABILITY_NOT_REVENUE'),
      'lifecycle',jsonb_build_object('numerator',(v_lc->>'classified_population')::integer,'denominator',(v_lc->>'canonical_population')::integer,'semantic','QUALIFYING_LIFECYCLE_EVIDENCE')
    ),
    'source_semantics',jsonb_build_object(
      'transactional_sales_2024','NO_CERTIFIED_SOURCE',
      'transactional_sales_2025','NO_CERTIFIED_SOURCE',
      'transactional_sales_2026','AVAILABLE',
      'no_certified_source_means_zero',false,
      'patient_history_can_support_lifecycle_not_revenue',true
    ),
    'protected_truth',v_f60#>'{contract,canonical_state}',
    'input_fingerprints',jsonb_build_object(
      'f6_0',v_f60->>'contract_fingerprint',
      'f6_1','cd313998c5b5b38d5cb9e2f08882b826',
      'f6_2','d977b9669b9e741e8785cd863caaf9c2'
    ),
    'security_guards',jsonb_build_object(
      'canonical_patient_id_authority',true,
      'name_alone_authority',false,
      'phone_alone_absolute_authority',false,
      'phone_nearness_authority',false,
      'conflict_auto_resolution',false,
      'fused_subject_active',false,
      'raw_pii_in_aggregate_contract',false
    )
  );
  v_fp := md5(v_payload::text);
  return jsonb_build_object('ok',true,'generated_at',clock_timestamp(),'contract',v_payload,'contract_fingerprint',v_fp);
end;
$$;
comment on function public.aos_rev_f6_3_contract_v1() is
'REV-F6.3 aggregate contract + deterministic fingerprint. Dynamic generated_at is excluded from fingerprint payload.';
revoke all on function public.aos_rev_f6_3_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_3_contract_v1() to service_role;

-- Preserve the certified F6.2 browser gateway as a private base. F6.3 only augments trust metadata.
do $$
begin
  if to_regprocedure('public.aos_patient_commercial_360_v2_f6_2_base(text,text,text)') is null then
    if to_regprocedure('public.aos_patient_commercial_360_v2(text,text,text)') is null then
      raise exception 'REV_F6_3_REQUIRES_F6_2_360';
    end if;
    alter function public.aos_patient_commercial_360_v2(text,text,text) rename to aos_patient_commercial_360_v2_f6_2_base;
  end if;
end $$;
revoke all on function public.aos_patient_commercial_360_v2_f6_2_base(text,text,text) from public,anon,authenticated;
grant execute on function public.aos_patient_commercial_360_v2_f6_2_base(text,text,text) to service_role;

create or replace function public.aos_patient_commercial_360_v2(p_token text,p_lookup_type text,p_lookup_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_base jsonb;
  v_pid text;
  v_identity jsonb;
  v_lifecycle jsonb;
  v_patient_trust jsonb;
  v_now timestamptz := clock_timestamp();
  v_classified bigint := 0;
  v_sample bigint := 0;
begin
  v_base := public.aos_patient_commercial_360_v2_f6_2_base(p_token,p_lookup_type,p_lookup_value);
  if coalesce((v_base->>'found')::boolean,false) then
    v_pid := v_base#>>'{paciente,canonical_patient_id}';
    v_identity := public.aos_rev_identity_confidence_by_patient_v1(v_pid);
    v_lifecycle := v_base->'lifecycle';
    v_classified := case when coalesce(v_lifecycle->>'classification_status','')='CLASSIFIED' then 1 else 0 end;
    v_sample := coalesce((v_lifecycle#>>'{evidence,event_rows}')::bigint,0);
    v_patient_trust := public.aos_rev_metric_trust_envelope_v1(
      'PATIENT_LIFECYCLE_STATE',v_lifecycle->'lifecycle_state',v_classified,1,'PATIENT_LEVEL_QUALIFYING_LIFECYCLE_EVIDENCE',v_sample,
      'AVAILABLE','OBSERVED_PATIENT_ACTIVITY',v_now,v_now,v_now,coalesce(v_identity->>'confidence_level','UNRESOLVED'),
      coalesce(v_identity->'reason_codes','[]'::jsonb),
      coalesce(v_identity->'limitations','[]'::jsonb) || jsonb_build_array('2024_2025_PATIENT_HISTORY_IS_NOT_TRANSACTIONAL_REVENUE'),
      jsonb_build_array('REV-F6.1','REV-F6.2','REV-F6.3')
    );
    v_base := v_base || jsonb_build_object('identity_confidence',v_identity,'metric_trust',jsonb_build_object('patient_lifecycle',v_patient_trust));
  end if;
  v_base := jsonb_set(v_base,'{contract}',to_jsonb('REV-F6.3_PATIENT_COMMERCIAL_360_V2'::text),true);
  return v_base;
end;
$$;
comment on function public.aos_patient_commercial_360_v2(text,text,text) is
'REV-F6.3 governed Patient Commercial 360 gateway. Preserves F6.2/F6.1 Auth V3 + PASSWORD_2FA and adds explainable identity confidence + patient lifecycle Metric Trust.';
revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

select pg_notify('pgrst','reload schema');
commit;
