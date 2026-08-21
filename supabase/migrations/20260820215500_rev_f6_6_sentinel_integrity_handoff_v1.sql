-- REV-F6.6 Sentinel Data-Integrity Handoff / zero-PII aggregate sensors.
-- Observation-only: no business truth mutation and no automatic Sentinel incident ingest.

begin;

create or replace function public.aos_rev_f6_6_integrity_baseline_v1()
returns jsonb
language sql
immutable
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'contract','REV-F6.6_SENTINEL_DATA_INTEGRITY_HANDOFF_V1',
    'baseline_version',1,
    'entry_main','589f790b72b9373fa983f745f7e4d9c0e3090b4d',
    'f5_source',pg_catalog.jsonb_build_object(
      'batches_total',6,
      'staging_complete_batches',6,
      'matched_batches',6,
      'expected_rows',15498,
      'persisted_rows',15498,
      'members',15498,
      'orphans',0,
      'invalid_multiplicity',0
    ),
    'f6_fingerprints',pg_catalog.jsonb_build_object(
      'f6_0','f81a1b8fcfe010cd5254c4ab2e6048d2',
      'f6_1','cd313998c5b5b38d5cb9e2f08882b826',
      'f6_2','d977b9669b9e741e8785cd863caaf9c2',
      'f6_3','186a1da2c29b498dad26223ae264adea',
      'f6_4','54c07961f191147860f6acd3a3e85c2a',
      'f6_5','88957cec3d785e4931a8f834c0259a91'
    ),
    'coverage_pct',pg_catalog.jsonb_build_object(
      'identity',3.40,
      'lifecycle',pg_catalog.round((543::numeric*100)/7264,4),
      'f3_product',97.78,
      'f4_financial',9.47,
      'sales_linkage',16.01,
      'historical_transaction_source',33.33
    ),
    'patient360_alias_keys',pg_catalog.jsonb_build_object(
      'CANONICAL_ID',pg_catalog.jsonb_build_object('keys',7264,'resolved',7264,'conflicts',0),
      'PHONE',pg_catalog.jsonb_build_object('keys',7138,'resolved',7101,'conflicts',37),
      'EMAIL',pg_catalog.jsonb_build_object('keys',1635,'resolved',1557,'conflicts',78),
      'DOCUMENT',pg_catalog.jsonb_build_object('keys',2607,'resolved',2461,'conflicts',146)
    ),
    'coverage_material_drop_pp',2.0,
    'patient360_conflict_rate_material_delta_pp',1.0,
    'historical',pg_catalog.jsonb_build_object(
      '2024',pg_catalog.jsonb_build_object('status','NO_CERTIFIED_SOURCE','value',null),
      '2025',pg_catalog.jsonb_build_object('status','NO_CERTIFIED_SOURCE','value',null)
    ),
    'semantic','SENTINEL_OBSERVES_ZERO_PII_AND_NEVER_AUTO_REPAIRS'
  );
$$;

create or replace function public.aos_sentinel_rev_f6_6_signal_envelope_v1(
  p_signal_id text,
  p_signal_name text,
  p_owner text,
  p_contract text,
  p_state text,
  p_severity text,
  p_expected jsonb,
  p_actual jsonb,
  p_source_version text,
  p_baseline_version text,
  p_runbook_ref text,
  p_limitations jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
volatile
set search_path=''
as $$
declare
  v_state text:=pg_catalog.upper(coalesce(p_state,'UNKNOWN'));
  v_severity text:=pg_catalog.upper(coalesce(p_severity,'MEDIUM'));
  v_core jsonb;
  v_digest text;
begin
  if v_state not in ('OK','DEGRADED','REVIEW_REQUIRED','BROKEN','UNKNOWN') then raise exception 'F6_6_INVALID_STATE'; end if;
  if v_severity not in ('CRITICAL','HIGH','MEDIUM','LOW') then raise exception 'F6_6_INVALID_SEVERITY'; end if;
  if p_signal_id is null or p_signal_id !~ '^SEN-DQ-[A-Z0-9-]+$' then raise exception 'F6_6_INVALID_SIGNAL_ID'; end if;
  if pg_catalog.jsonb_typeof(coalesce(p_expected,'{}'::jsonb)) <> 'object' or pg_catalog.jsonb_typeof(coalesce(p_actual,'{}'::jsonb)) <> 'object' or pg_catalog.jsonb_typeof(coalesce(p_limitations,'[]'::jsonb)) <> 'array' then raise exception 'F6_6_INVALID_ENVELOPE_JSON'; end if;
  v_core:=pg_catalog.jsonb_build_object('signal_id',p_signal_id,'signal_name',p_signal_name,'owning_workstream',p_owner,'affected_contract',p_contract,'state',v_state,'severity',v_severity,'expected',coalesce(p_expected,'{}'::jsonb),'actual',coalesce(p_actual,'{}'::jsonb),'source_version',p_source_version,'baseline_version',p_baseline_version,'runbook_ref',p_runbook_ref,'limitations',coalesce(p_limitations,'[]'::jsonb));
  v_digest:=pg_catalog.md5(v_core::text);
  return v_core || pg_catalog.jsonb_build_object('observed_at',pg_catalog.clock_timestamp(),'state_digest',v_digest);
end;
$$;

create or replace function public.aos_sentinel_rev_f6_6_evaluate_v1(p_snapshot jsonb)
returns jsonb
language plpgsql
volatile
set search_path=''
as $$
declare
  v_b jsonb; v_signals jsonb:='[]'::jsonb; v_state text; v_ok integer:=0; v_degraded integer:=0; v_review integer:=0; v_broken integer:=0; v_unknown integer:=0; v_max_drop numeric; v_missing integer; v_max_conflict_delta numeric; v_signal jsonb;
begin
  if p_snapshot is null or pg_catalog.jsonb_typeof(p_snapshot)<>'object' then raise exception 'F6_6_SNAPSHOT_OBJECT_REQUIRED'; end if;
  v_b:=public.aos_rev_f6_6_integrity_baseline_v1();
  if not (p_snapshot ? 'f5_source') or coalesce((p_snapshot#>>'{f5_source,batches_total}')::integer,0)=0 then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{f5_source,staging_complete_batches}')::integer,-1)<>coalesce((p_snapshot#>>'{f5_source,batches_total}')::integer,0) or coalesce((p_snapshot#>>'{f5_source,matched_batches}')::integer,-1)<>coalesce((p_snapshot#>>'{f5_source,batches_total}')::integer,0) or coalesce((p_snapshot#>>'{f5_source,expected_rows}')::bigint,-1)<>coalesce((p_snapshot#>>'{f5_source,persisted_rows}')::bigint,-2) or coalesce((p_snapshot#>>'{f5_source,mismatched_batches}')::integer,0)>0 or coalesce((p_snapshot#>>'{f5_source,continuity_failures}')::integer,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F5-001','SOURCE_BATCH_MISMATCH','REV-F5','REV-F5_SOURCE_TRUTH',v_state,'HIGH',v_b->'f5_source',coalesce(p_snapshot->'f5_source','{}'::jsonb),'REV-F5-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f5-001-source_batch_mismatch'); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'f5_membership') then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{f5_membership,source_rows}')::bigint,-1)<>coalesce((p_snapshot#>>'{f5_membership,members}')::bigint,-2) or coalesce((p_snapshot#>>'{f5_membership,orphans}')::bigint,0)>0 or coalesce((p_snapshot#>>'{f5_membership,invalid_multiplicity}')::bigint,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F5-002','IDENTITY_MEMBERSHIP_MISMATCH','REV-F5','REV-F5_IDENTITY_MEMBERSHIP',v_state,'CRITICAL',v_b->'f5_membership',coalesce(p_snapshot->'f5_membership','{}'::jsonb),'REV-F5-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f5-002-identity_membership_mismatch'); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'identity_bridge') then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{identity_bridge,resolved_collisions}')::bigint,0)>0 or coalesce((p_snapshot#>>'{identity_bridge,resolved_bad_candidate_count}')::bigint,0)>0 or coalesce((p_snapshot#>>'{identity_bridge,resolved_missing_target}')::bigint,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F5-003','IDENTITY_BRIDGE_COLLISION','REV-F5','REV_PATIENT_IDENTITY_BRIDGE_V2',v_state,'CRITICAL',pg_catalog.jsonb_build_object('resolved_collisions',0,'resolved_bad_candidate_count',0,'resolved_missing_target',0),coalesce(p_snapshot->'identity_bridge','{}'::jsonb),'REV-F6.3','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f5-003-identity_bridge_collision',pg_catalog.jsonb_build_array('KNOWN_CONFLICT_KEYS_ARE_FAIL_CLOSED_REVIEW_INVENTORY_NOT_RESOLVED_COLLISIONS')); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'f5_apply') then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{f5_apply,missing_governance}')::bigint,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F5-004','APPLY_WITHOUT_GOVERNANCE','REV-F5','REV-F5_GOVERNED_APPLY',v_state,'CRITICAL',pg_catalog.jsonb_build_object('missing_governance',0),coalesce(p_snapshot->'f5_apply','{}'::jsonb),'REV-F5-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f5-004-apply_without_governance',pg_catalog.jsonb_build_array('ROLLED_BACK_CANARY_EVENTS_ARE_HISTORICAL_AND_EXCLUDED_FROM_ACTIVE_VIOLATION_COUNT')); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'duplicate_profile') or coalesce((p_snapshot#>>'{duplicate_profile,telemetry_available}')::boolean,false)=false then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{duplicate_profile,critical_drift_count}')::integer,0)>0 then v_state:='BROKEN'; elsif coalesce((p_snapshot#>>'{duplicate_profile,abnormal_drift_count}')::integer,0)>0 then v_state:='DEGRADED'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F5-005','DUPLICATE_PROFILE_DRIFT','REV-F5','REV-F5_DUPLICATE_PROFILE_CLASSIFICATION',v_state,'MEDIUM',pg_catalog.jsonb_build_object('classes',pg_catalog.jsonb_build_array('AUTO_ELIGIBLE_EXACT','REVIEW_STRONG','BLOCK_CONFLICT','NO_MERGE')),coalesce(p_snapshot->'duplicate_profile','{}'::jsonb),'REV-F5-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f5-005-duplicate_profile_drift',case when v_state='UNKNOWN' then pg_catalog.jsonb_build_array('REQUESTED_DUPLICATE_PROFILE_CLASSES_NOT_MATERIALIZED_IN_LIVE_SCHEMA','MISSING_TELEMETRY_NEVER_RETURNS_OK') else '[]'::jsonb end); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'product_sale') then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{product_sale,missing_sale}')::bigint,0)>0 or coalesce((p_snapshot#>>'{product_sale,resolved_missing_product}')::bigint,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-REV-001','PRODUCT_SALE_ORPHAN','REV-F3','REV-F3_PRODUCT_SALE_FACT',v_state,'HIGH',pg_catalog.jsonb_build_object('missing_sale',0,'resolved_missing_product',0),coalesce(p_snapshot->'product_sale','{}'::jsonb),'REV-F3-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-rev-001-product_sale_orphan'); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'reconciliation') then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{reconciliation,missing_sale}')::bigint,0)>0 or coalesce((p_snapshot#>>'{reconciliation,missing_payment}')::bigint,0)>0 or coalesce((p_snapshot#>>'{reconciliation,missing_quote}')::bigint,0)>0 or coalesce((p_snapshot#>>'{reconciliation,no_evidence_ref}')::bigint,0)>0 then v_state:='BROKEN'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-REV-002','RECONCILIATION_ORPHAN','REV-F4','REV-F4_RECONCILIATION',v_state,'HIGH',pg_catalog.jsonb_build_object('missing_sale',0,'missing_payment',0,'missing_quote',0,'no_evidence_ref',0),coalesce(p_snapshot->'reconciliation','{}'::jsonb),'REV-F4-CERTIFIED','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-rev-002-reconciliation_orphan'); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'f6_readmodel') or coalesce((p_snapshot#>>'{f6_readmodel,cache_rows}')::integer,0)=0 then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{f6_readmodel,version_mismatch_count}')::integer,0)>0 then v_state:='BROKEN'; elsif coalesce((p_snapshot#>>'{f6_readmodel,source_newer_than_cache}')::boolean,false) then v_state:='DEGRADED'; else v_state:='OK'; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F6-001','READMODEL_STALE','REV-F6','REV-F6.4_SALES_INTELLIGENCE_3_V1',v_state,'HIGH',pg_catalog.jsonb_build_object('version_mismatch_count',0,'source_newer_than_cache',false),coalesce(p_snapshot->'f6_readmodel','{}'::jsonb),'REV-F6.4','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f6-001-readmodel_stale',pg_catalog.jsonb_build_array('FRESHNESS_IS_SOURCE_AWARE_CACHE_GENERATED_AT_MUST_NOT_PRECEDE_RELEVANT_SOURCE_FRESHNESS')); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'f6_coverage') then v_state:='UNKNOWN'; else v_missing:=coalesce((p_snapshot#>>'{f6_coverage,missing_metrics}')::integer,0); v_max_drop:=coalesce((p_snapshot#>>'{f6_coverage,max_drop_pp}')::numeric,0); if v_missing>0 then v_state:='UNKNOWN'; elsif v_max_drop>=coalesce((v_b#>>'{coverage_material_drop_pp}')::numeric,2.0) then v_state:='BROKEN'; elsif v_max_drop>0 then v_state:='DEGRADED'; else v_state:='OK'; end if; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-F6-002','COVERAGE_REGRESSION','REV-F6','REV-F6.3_METRIC_TRUST',v_state,'HIGH',pg_catalog.jsonb_build_object('baseline_pct',v_b->'coverage_pct','material_drop_pp',v_b->'coverage_material_drop_pp'),coalesce(p_snapshot->'f6_coverage','{}'::jsonb),'REV-F6.3','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-f6-002-coverage_regression'); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  if not (p_snapshot ? 'patient360') or coalesce((p_snapshot#>>'{patient360,metrics_missing}')::integer,0)>0 then v_state:='UNKNOWN'; elsif coalesce((p_snapshot#>>'{patient360,resolved_collisions}')::integer,0)>0 or coalesce((p_snapshot#>>'{patient360,resolved_missing_target}')::integer,0)>0 or coalesce((p_snapshot#>>'{patient360,resolved_bad_candidate_count}')::integer,0)>0 then v_state:='BROKEN'; else v_max_conflict_delta:=coalesce((p_snapshot#>>'{patient360,max_conflict_rate_delta_pp}')::numeric,0); if v_max_conflict_delta>=coalesce((v_b#>>'{patient360_conflict_rate_material_delta_pp}')::numeric,1.0) then v_state:='DEGRADED'; else v_state:='OK'; end if; end if;
  v_signal:=public.aos_sentinel_rev_f6_6_signal_envelope_v1('SEN-DQ-360-001','PATIENT360_IDENTITY_RESOLUTION_REGRESSION','REV-F6.1','REV_PATIENT_COMMERCIAL_360_V2',v_state,'HIGH',pg_catalog.jsonb_build_object('alias_key_baseline',v_b->'patient360_alias_keys','material_conflict_rate_delta_pp',v_b->'patient360_conflict_rate_material_delta_pp','resolved_collisions',0,'resolved_missing_target',0,'resolved_bad_candidate_count',0),coalesce(p_snapshot->'patient360','{}'::jsonb),'REV-F6.3','1','docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md#sen-dq-360-001-patient360_identity_resolution_regression',pg_catalog.jsonb_build_array('KNOWN_FAIL_CLOSED_CONFLICT_KEYS_ARE_NOT_RESOLUTION_ERRORS')); v_signals:=v_signals||pg_catalog.jsonb_build_array(v_signal);
  select count(*) filter(where value->>'state'='OK'),count(*) filter(where value->>'state'='DEGRADED'),count(*) filter(where value->>'state'='REVIEW_REQUIRED'),count(*) filter(where value->>'state'='BROKEN'),count(*) filter(where value->>'state'='UNKNOWN') into v_ok,v_degraded,v_review,v_broken,v_unknown from pg_catalog.jsonb_array_elements(v_signals);
  return pg_catalog.jsonb_build_object('ok',true,'contract','REV-F6.6_SENTINEL_DATA_INTEGRITY_HANDOFF_V1','observation_only',true,'auto_repair',false,'zero_pii_envelope',true,'signals',v_signals,'summary',pg_catalog.jsonb_build_object('OK',v_ok,'DEGRADED',v_degraded,'REVIEW_REQUIRED',v_review,'BROKEN',v_broken,'UNKNOWN',v_unknown),'health_fingerprint',pg_catalog.md5((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('signal_id',value->>'signal_id','state_digest',value->>'state_digest') order by value->>'signal_id')::text from pg_catalog.jsonb_array_elements(v_signals))));
end;
$$;

create or replace function public.aos_sentinel_rev_f6_6_snapshot_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_f60 jsonb:=public.aos_rev_f6_data_contract_v1(); v_f63 jsonb:=public.aos_rev_f6_3_contract_v1(); v_f64 jsonb:=public.aos_rev_f6_4_contract_v1(); v_f65 jsonb:=public.aos_rev_f6_5_contract_v1(); v_b jsonb:=public.aos_rev_f6_6_integrity_baseline_v1(); v_source jsonb; v_members jsonb; v_bridge jsonb; v_apply jsonb; v_duplicate jsonb; v_product jsonb; v_recon jsonb; v_readmodel jsonb; v_coverage jsonb; v_patient360 jsonb; v_cache_rows bigint; v_cache_oldest timestamptz; v_cache_newest timestamptz; v_source_latest timestamptz; v_version_mismatch integer:=0; v_missing_metrics integer:=0; v_max_drop numeric:=0; v_metrics jsonb; v_p360_metrics jsonb; v_p360_missing integer:=0; v_p360_max_delta numeric:=0; v_resolved_collisions integer:=0; v_resolved_bad integer:=0; v_resolved_missing integer:=0;
begin
  with per_batch as (select b.id,b.source_rows,b.status,coalesce((b.metadata->>'staging_complete')::boolean,false) staging_complete,count(s.*)::bigint persisted,count(distinct s.source_row_num)::bigint distinct_n,min(s.source_row_num) min_n,max(s.source_row_num) max_n from public.aos_f5_source_batches_v1 b left join public.aos_f5_patient_source_rows_v1 s on s.batch_id=b.id group by b.id,b.source_rows,b.status,b.metadata) select pg_catalog.jsonb_build_object('batches_total',count(*)::bigint,'staging_complete_batches',count(*) filter(where staging_complete)::bigint,'matched_batches',count(*) filter(where status='MATCHED')::bigint,'expected_rows',coalesce(sum(source_rows),0)::bigint,'persisted_rows',coalesce(sum(persisted),0)::bigint,'mismatched_batches',count(*) filter(where persisted<>source_rows)::bigint,'continuity_failures',count(*) filter(where persisted<>source_rows or distinct_n<>persisted or (persisted>0 and (max_n-min_n+1)<>persisted))::bigint) into v_source from per_batch;
  select pg_catalog.jsonb_build_object('source_rows',(select count(*)::bigint from public.aos_f5_patient_source_rows_v1),'members',count(*)::bigint,'distinct_member_rows',count(distinct im.source_row_id)::bigint,'orphans',count(*) filter(where s.id is null)::bigint,'invalid_multiplicity',(select count(*)::bigint from (select source_row_id from public.aos_f5_identity_cluster_members_v1 group by source_row_id having count(*)<>1) q)) into v_members from public.aos_f5_identity_cluster_members_v1 im left join public.aos_f5_patient_source_rows_v1 s on s.id=im.source_row_id;
  with key_state as (select identifier_type,identifier_key,count(distinct canonical_patient_id) filter(where status='RESOLVED' and canonical_patient_id is not null) resolved_targets,max(candidate_count) filter(where status='RESOLVED') max_resolved_candidates,bool_or(status='RESOLVED' and canonical_patient_id is null) resolved_null,bool_or(status='RESOLVED' and p."ID_PACIENTE" is null) resolved_missing,bool_or(status='CONFLICT') has_conflict from public.aos_rev_patient_identity_alias_v2 a left join public.aos_pacientes p on p."ID_PACIENTE"=a.canonical_patient_id group by identifier_type,identifier_key) select pg_catalog.jsonb_build_object('resolved_collisions',count(*) filter(where resolved_targets>1)::bigint,'resolved_bad_candidate_count',count(*) filter(where coalesce(max_resolved_candidates,1)<>1 and resolved_targets>0)::bigint,'resolved_missing_target',count(*) filter(where resolved_null or resolved_missing)::bigint,'known_conflict_keys',count(*) filter(where has_conflict)::bigint) into v_bridge from key_state;
  with active as (select e.id,e.preview_snapshot_hash,e.actor_user_id,p.review_decision,p.reviewed_at,p.reviewed_snapshot_hash,p.apply_event_id,p.applied_at as preview_applied_at from public.aos_f5_canonical_apply_events_v1 e left join public.aos_f5_enrichment_preview_v1 p on p.cluster_id=e.cluster_id and p.target_patient_id=e.target_patient_id and p.field_name=e.field_name where e.rolled_back_at is null) select pg_catalog.jsonb_build_object('active_events',count(*)::bigint,'missing_governance',count(*) filter(where review_decision is null or reviewed_at is null or reviewed_snapshot_hash is distinct from preview_snapshot_hash or apply_event_id is distinct from id or preview_applied_at is null or actor_user_id is null)::bigint) into v_apply from active;
  select pg_catalog.jsonb_build_object('telemetry_available',false,'current_canonical_classification',coalesce((select pg_catalog.jsonb_object_agg(classification,c) from (select classification,count(*)::bigint c from public.aos_f5_canonical_classification_v1 group by classification) x),'{}'::jsonb),'abnormal_drift_count',0,'critical_drift_count',0) into v_duplicate;
  select pg_catalog.jsonb_build_object('rows',count(*)::bigint,'missing_sale',count(*) filter(where v.id is null)::bigint,'resolved_missing_product',count(*) filter(where f.resolution_status='RESOLVED' and p.product_key is null)::bigint) into v_product from public.aos_product_sale_fact_current_v1 f left join public.aos_ventas v on v.id=f.sale_id left join public.aos_product_identity_v1 p on p.product_key=f.product_key;
  select pg_catalog.jsonb_build_object('rows',count(*)::bigint,'active',count(*) filter(where r.source_active)::bigint,'missing_sale',count(*) filter(where r.source_active and r.venta_row_id is not null and v.id is null)::bigint,'missing_payment',count(*) filter(where r.source_active and r.pago_id is not null and pg.id is null)::bigint,'missing_quote',count(*) filter(where r.source_active and r.cotizacion_id is not null and c.id is null)::bigint,'no_evidence_ref',count(*) filter(where r.source_active and r.venta_row_id is null and r.pago_id is null and r.cotizacion_id is null)::bigint) into v_recon from public.aos_cartera_reconciliacion r left join public.aos_ventas v on v.id=r.venta_row_id left join public.aos_pagos pg on pg.id=r.pago_id left join public.aos_cotizaciones c on c.id=r.cotizacion_id;
  select count(*)::bigint,min(generated_at),max(generated_at) into v_cache_rows,v_cache_oldest,v_cache_newest from public.aos_rev_si_dashboard_cache_v1;
  select greatest(nullif(v_f60#>>'{contract,freshness_sources,sales_updated_at}','')::timestamptz,nullif(v_f60#>>'{contract,freshness_sources,f4_updated_at}','')::timestamptz,nullif(v_f60#>>'{contract,freshness_sources,patient_source_updated_at}','')::timestamptz,nullif(v_f60#>>'{contract,freshness_sources,cia_identity_updated_at}','')::timestamptz) into v_source_latest;
  if v_f64#>>'{contract,input_fingerprints,f6_0}' is distinct from v_f60->>'contract_fingerprint' then v_version_mismatch:=v_version_mismatch+1; end if; if v_f64#>>'{contract,input_fingerprints,f6_1}' is distinct from v_f63#>>'{contract,input_fingerprints,f6_1}' then v_version_mismatch:=v_version_mismatch+1; end if; if v_f64#>>'{contract,input_fingerprints,f6_2}' is distinct from v_f63#>>'{contract,input_fingerprints,f6_2}' then v_version_mismatch:=v_version_mismatch+1; end if; if v_f64#>>'{contract,input_fingerprints,f6_3}' is distinct from v_f63->>'contract_fingerprint' then v_version_mismatch:=v_version_mismatch+1; end if; if v_f65#>>'{contract,upstream_f6_4_fingerprint}' is distinct from v_f64->>'contract_fingerprint' then v_version_mismatch:=v_version_mismatch+1; end if;
  v_readmodel:=pg_catalog.jsonb_build_object('cache_rows',v_cache_rows,'cache_oldest',v_cache_oldest,'cache_newest',v_cache_newest,'source_latest',v_source_latest,'source_newer_than_cache',case when v_cache_newest is null or v_source_latest is null then null else v_source_latest>v_cache_newest end,'version_mismatch_count',v_version_mismatch);
  with metrics(name,baseline_pct,current_pct) as (values ('identity',(v_b#>>'{coverage_pct,identity}')::numeric,nullif(v_f63#>>'{contract,coverage_baselines,identity,pct}','')::numeric),('lifecycle',(v_b#>>'{coverage_pct,lifecycle}')::numeric,case when nullif(v_f63#>>'{contract,coverage_baselines,lifecycle,denominator}','')::numeric>0 then (v_f63#>>'{contract,coverage_baselines,lifecycle,numerator}')::numeric*100/(v_f63#>>'{contract,coverage_baselines,lifecycle,denominator}')::numeric end),('f3_product',(v_b#>>'{coverage_pct,f3_product}')::numeric,nullif(v_f63#>>'{contract,coverage_baselines,f3_product,pct}','')::numeric),('f4_financial',(v_b#>>'{coverage_pct,f4_financial}')::numeric,nullif(v_f63#>>'{contract,coverage_baselines,f4_financial,pct}','')::numeric),('sales_linkage',(v_b#>>'{coverage_pct,sales_linkage}')::numeric,nullif(v_f63#>>'{contract,coverage_baselines,sales_linkage,pct}','')::numeric),('historical_transaction_source',(v_b#>>'{coverage_pct,historical_transaction_source}')::numeric,nullif(v_f63#>>'{contract,coverage_baselines,historical_transaction_source,pct}','')::numeric)) select count(*) filter(where current_pct is null)::integer,coalesce(max(greatest(baseline_pct-current_pct,0)),0),pg_catalog.jsonb_object_agg(name,pg_catalog.jsonb_build_object('baseline_pct',pg_catalog.round(baseline_pct,4),'current_pct',case when current_pct is null then null else pg_catalog.round(current_pct,4) end,'drop_pp',case when current_pct is null then null else pg_catalog.round(greatest(baseline_pct-current_pct,0),4) end)) into v_missing_metrics,v_max_drop,v_metrics from metrics;
  v_coverage:=pg_catalog.jsonb_build_object('missing_metrics',v_missing_metrics,'max_drop_pp',pg_catalog.round(v_max_drop,4),'metrics',v_metrics);
  with key_state as (select a.identifier_type,a.identifier_key,bool_or(a.status='RESOLVED') has_resolved,bool_or(a.status='CONFLICT') has_conflict,count(distinct a.canonical_patient_id) filter(where a.status='RESOLVED' and a.canonical_patient_id is not null) resolved_targets,max(a.candidate_count) filter(where a.status='RESOLVED') max_resolved_candidates,bool_or(a.status='RESOLVED' and (a.canonical_patient_id is null or p."ID_PACIENTE" is null)) resolved_missing from public.aos_rev_patient_identity_alias_v2 a left join public.aos_pacientes p on p."ID_PACIENTE"=a.canonical_patient_id group by a.identifier_type,a.identifier_key), agg as (select identifier_type,count(*)::numeric keys,count(*) filter(where has_resolved)::numeric resolved,count(*) filter(where has_conflict)::numeric conflicts,count(*) filter(where resolved_targets>1)::integer collisions,count(*) filter(where coalesce(max_resolved_candidates,1)<>1 and has_resolved)::integer bad_candidates,count(*) filter(where resolved_missing)::integer missing_targets from key_state group by identifier_type), normalized as (select a.identifier_type,a.keys,a.resolved,a.conflicts,a.collisions,a.bad_candidates,a.missing_targets,(a.conflicts*100/nullif(a.keys,0)) conflict_pct,((v_b#>>array['patient360_alias_keys',a.identifier_type,'conflicts'])::numeric*100/nullif((v_b#>>array['patient360_alias_keys',a.identifier_type,'keys'])::numeric,0)) baseline_conflict_pct from agg a) select count(*) filter(where identifier_type in ('PHONE','EMAIL','DOCUMENT','CANONICAL_ID'))::integer,coalesce(max(greatest(conflict_pct-baseline_conflict_pct,0)),0),coalesce(sum(collisions),0)::integer,coalesce(sum(bad_candidates),0)::integer,coalesce(sum(missing_targets),0)::integer,pg_catalog.jsonb_object_agg(identifier_type,pg_catalog.jsonb_build_object('keys',keys::bigint,'resolved',resolved::bigint,'conflicts',conflicts::bigint,'conflict_pct',pg_catalog.round(conflict_pct,4),'baseline_conflict_pct',pg_catalog.round(baseline_conflict_pct,4))) into v_p360_missing,v_p360_max_delta,v_resolved_collisions,v_resolved_bad,v_resolved_missing,v_p360_metrics from normalized;
  v_p360_missing:=case when v_p360_missing=4 then 0 else 4-v_p360_missing end; v_patient360:=pg_catalog.jsonb_build_object('metrics_missing',v_p360_missing,'max_conflict_rate_delta_pp',pg_catalog.round(v_p360_max_delta,4),'resolved_collisions',v_resolved_collisions,'resolved_bad_candidate_count',v_resolved_bad,'resolved_missing_target',v_resolved_missing,'metrics',coalesce(v_p360_metrics,'{}'::jsonb));
  return pg_catalog.jsonb_build_object('contract','REV-F6.6_SAFE_AGGREGATE_SNAPSHOT_V1','captured_at',pg_catalog.clock_timestamp(),'f5_source',v_source,'f5_membership',v_members,'identity_bridge',v_bridge,'f5_apply',v_apply,'duplicate_profile',v_duplicate,'product_sale',v_product,'reconciliation',v_recon,'f6_readmodel',v_readmodel,'f6_coverage',v_coverage,'patient360',v_patient360,'f6_fingerprints',pg_catalog.jsonb_build_object('f6_0',v_f60->>'contract_fingerprint','f6_3',v_f63->>'contract_fingerprint','f6_4',v_f64->>'contract_fingerprint','f6_5',v_f65->>'contract_fingerprint'),'historical',pg_catalog.jsonb_build_object('2024',pg_catalog.jsonb_build_object('status',v_f65#>>'{contract,historical_coverage,years,2024,source_status}','value',v_f65#>'{contract,historical_coverage,years,2024,value}'),'2025',pg_catalog.jsonb_build_object('status',v_f65#>>'{contract,historical_coverage,years,2025,source_status}','value',v_f65#>'{contract,historical_coverage,years,2025,value}')));
end;
$$;

create or replace function public.aos_sentinel_rev_f6_6_integrity_health_v1() returns jsonb language plpgsql volatile security definer set search_path='' as $$ begin return public.aos_sentinel_rev_f6_6_evaluate_v1(public.aos_sentinel_rev_f6_6_snapshot_v1()); end; $$;

create or replace function public.aos_sentinel_rev_f6_6_incident_candidates_v1()
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_health jsonb:=public.aos_sentinel_rev_f6_6_integrity_health_v1(); v_out jsonb:='[]'::jsonb; s jsonb; v_domain text; v_p text; v_id text;
begin
  for s in select value from pg_catalog.jsonb_array_elements(v_health->'signals') loop
    if s->>'state'='OK' then continue; end if;
    v_domain:=case when s->>'signal_id' like 'SEN-DQ-F5-%' or s->>'signal_id' like 'SEN-DQ-360-%' then 'CLINICAL' else 'SALES' end;
    v_p:=case s->>'severity' when 'CRITICAL' then 'P1' when 'HIGH' then 'P2' else 'P3' end;
    v_id:=pg_catalog.lower(s->>'signal_id')||'/'||(s->>'state_digest');
    v_out:=v_out||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('event_id','rev-f6-6/'||v_id,'signal_class','BUSINESS_HEALTH','environment','production','domain',v_domain,'component','rev-f6-6-integrity','capability',pg_catalog.lower(s->>'signal_id'),'failure_family',pg_catalog.lower(s->>'signal_name'),'signal_fingerprint','dq:'||pg_catalog.lower(s->>'signal_id')||':'||(s->>'state_digest'),'incident_fingerprint','dq:'||pg_catalog.lower(s->>'signal_id'),'severity',v_p,'observed_at',s->>'observed_at','evidence_refs',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('kind','sentinel-signal','id',v_id))));
  end loop;
  return pg_catalog.jsonb_build_object('ok',true,'auto_ingest',false,'f8_compatible',true,'candidate_count',pg_catalog.jsonb_array_length(v_out),'signals',v_out);
end; $$;

create or replace function public.aos_rev_f6_6_contract_v1()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_b jsonb:=public.aos_rev_f6_6_integrity_baseline_v1(); v_contract jsonb;
begin
  v_contract:=pg_catalog.jsonb_build_object('contract_id','REV-F6.6_SENTINEL_DATA_INTEGRITY_HANDOFF_V1','contract_version',1,'signal_count',10,'signal_registry',pg_catalog.jsonb_build_array('SEN-DQ-F5-001','SEN-DQ-F5-002','SEN-DQ-F5-003','SEN-DQ-F5-004','SEN-DQ-F5-005','SEN-DQ-REV-001','SEN-DQ-REV-002','SEN-DQ-F6-001','SEN-DQ-F6-002','SEN-DQ-360-001'),'states',pg_catalog.jsonb_build_array('OK','DEGRADED','REVIEW_REQUIRED','BROKEN','UNKNOWN'),'missing_telemetry_state','UNKNOWN','observation_only',true,'auto_repair',false,'auto_incident_ingest',false,'zero_pii',true,'dedup_key','signal_id + affected_contract + state_digest','f8_adapter','aos_sentinel_rev_f6_6_incident_candidates_v1','baseline_version',v_b->'baseline_version','input_fingerprints',v_b->'f6_fingerprints','historical',v_b->'historical','limitations',pg_catalog.jsonb_build_array('SEN-DQ-F5-005_IS_UNKNOWN_UNTIL_REQUESTED_DUPLICATE_PROFILE_CLASSES_ARE_MATERIALIZED'));
  return pg_catalog.jsonb_build_object('ok',true,'contract',v_contract,'contract_fingerprint',pg_catalog.md5(v_contract::text));
end; $$;

revoke all on function public.aos_rev_f6_6_integrity_baseline_v1() from public,anon,authenticated;
revoke all on function public.aos_sentinel_rev_f6_6_signal_envelope_v1(text,text,text,text,text,text,jsonb,jsonb,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_sentinel_rev_f6_6_evaluate_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_sentinel_rev_f6_6_snapshot_v1() from public,anon,authenticated;
revoke all on function public.aos_sentinel_rev_f6_6_integrity_health_v1() from public,anon,authenticated;
revoke all on function public.aos_sentinel_rev_f6_6_incident_candidates_v1() from public,anon,authenticated;
revoke all on function public.aos_rev_f6_6_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_6_integrity_baseline_v1() to service_role;
grant execute on function public.aos_sentinel_rev_f6_6_signal_envelope_v1(text,text,text,text,text,text,jsonb,jsonb,text,text,text,jsonb) to service_role;
grant execute on function public.aos_sentinel_rev_f6_6_evaluate_v1(jsonb) to service_role;
grant execute on function public.aos_sentinel_rev_f6_6_snapshot_v1() to service_role;
grant execute on function public.aos_sentinel_rev_f6_6_integrity_health_v1() to service_role;
grant execute on function public.aos_sentinel_rev_f6_6_incident_candidates_v1() to service_role;
grant execute on function public.aos_rev_f6_6_contract_v1() to service_role;
comment on function public.aos_sentinel_rev_f6_6_integrity_health_v1() is 'REV-F6.6 zero-PII aggregate health. Observation-only; never repairs business truth.';
comment on function public.aos_sentinel_rev_f6_6_incident_candidates_v1() is 'REV-F6.6 sanitized F8-compatible candidates. Does not ingest incidents automatically.';
commit;
