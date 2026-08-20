\set ON_ERROR_STOP on

create or replace function pg_temp.f66_signal(p_eval jsonb,p_id text)
returns jsonb language sql immutable as $$
  select value from jsonb_array_elements(p_eval->'signals') where value->>'signal_id'=p_id limit 1
$$;

do $$
declare
  s jsonb:=public.aos_sentinel_rev_f6_6_snapshot_v1();
  h jsonb;
  x jsonb;
  d1 text;
  d2 text;
  candidate jsonb;
  ingest1 jsonb;
  ingest2 jsonb;
begin
  if s->>'contract'<>'REV-F6.6_SAFE_AGGREGATE_SNAPSHOT_V1' then raise exception 'F6_6_SNAPSHOT_CONTRACT'; end if;

  s:=jsonb_set(s,'{f5_source}',jsonb_build_object('batches_total',3,'staging_complete_batches',3,'matched_batches',3,'expected_rows',4,'persisted_rows',4,'mismatched_batches',0,'continuity_failures',0));
  s:=jsonb_set(s,'{f5_membership}',jsonb_build_object('source_rows',4,'members',4,'distinct_member_rows',4,'orphans',0,'invalid_multiplicity',0));
  s:=jsonb_set(s,'{identity_bridge}',jsonb_build_object('resolved_collisions',0,'resolved_bad_candidate_count',0,'resolved_missing_target',0,'known_conflict_keys',3));
  s:=jsonb_set(s,'{f5_apply}',jsonb_build_object('active_events',1,'missing_governance',0));
  s:=jsonb_set(s,'{duplicate_profile}',jsonb_build_object('telemetry_available',true,'abnormal_drift_count',0,'critical_drift_count',0,'class_counts',jsonb_build_object('AUTO_ELIGIBLE_EXACT',1,'REVIEW_STRONG',2,'BLOCK_CONFLICT',1,'NO_MERGE',4)));
  s:=jsonb_set(s,'{product_sale}',jsonb_build_object('rows',4,'missing_sale',0,'resolved_missing_product',0));
  s:=jsonb_set(s,'{reconciliation}',jsonb_build_object('rows',2,'active',2,'missing_sale',0,'missing_payment',0,'missing_quote',0,'no_evidence_ref',0));
  s:=jsonb_set(s,'{f6_readmodel}',jsonb_build_object('cache_rows',1,'source_newer_than_cache',false,'version_mismatch_count',0));
  s:=jsonb_set(s,'{f6_coverage}',jsonb_build_object('missing_metrics',0,'max_drop_pp',0,'metrics',jsonb_build_object()));
  s:=jsonb_set(s,'{patient360}',jsonb_build_object('metrics_missing',0,'max_conflict_rate_delta_pp',0,'resolved_collisions',0,'resolved_bad_candidate_count',0,'resolved_missing_target',0,'metrics',jsonb_build_object()));

  -- A. healthy F5 source and membership -> OK.
  h:=public.aos_sentinel_rev_f6_6_evaluate_v1(s);
  if pg_temp.f66_signal(h,'SEN-DQ-F5-001')->>'state'<>'OK' then raise exception 'A_SOURCE_HEALTHY'; end if;
  if pg_temp.f66_signal(h,'SEN-DQ-F5-002')->>'state'<>'OK' then raise exception 'A_MEMBERSHIP_HEALTHY'; end if;
  -- B. source mismatch.
  x:=jsonb_set(s,'{f5_source,mismatched_batches}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-001')->>'state'<>'BROKEN' then raise exception 'B_SOURCE_MISMATCH'; end if;
  -- C. members mismatch.
  x:=jsonb_set(s,'{f5_membership,members}','3'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-002')->>'state'<>'BROKEN' then raise exception 'C_MEMBERS_MISMATCH'; end if;
  -- D. orphan membership.
  x:=jsonb_set(s,'{f5_membership,orphans}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-002')->>'state'<>'BROKEN' then raise exception 'D_ORPHAN'; end if;
  -- E. duplicate membership multiplicity.
  x:=jsonb_set(s,'{f5_membership,invalid_multiplicity}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-002')->>'state'<>'BROKEN' then raise exception 'E_MULTIPLICITY'; end if;
  -- F. resolved identifier collision.
  x:=jsonb_set(s,'{identity_bridge,resolved_collisions}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-003')->>'state'<>'BROKEN' then raise exception 'F_IDENTITY_COLLISION'; end if;
  -- G. governed apply.
  if pg_temp.f66_signal(h,'SEN-DQ-F5-004')->>'state'<>'OK' then raise exception 'G_GOVERNED_APPLY'; end if;
  -- H. apply without governance.
  x:=jsonb_set(s,'{f5_apply,missing_governance}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-004')->>'state'<>'BROKEN' then raise exception 'H_APPLY_GOVERNANCE'; end if;
  -- I. normal duplicate telemetry.
  if pg_temp.f66_signal(h,'SEN-DQ-F5-005')->>'state'<>'OK' then raise exception 'I_DUPLICATE_NORMAL'; end if;
  -- J. abnormal and critical duplicate drift.
  x:=jsonb_set(s,'{duplicate_profile,abnormal_drift_count}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-005')->>'state'<>'DEGRADED' then raise exception 'J_DUPLICATE_DEGRADED'; end if;
  x:=jsonb_set(x,'{duplicate_profile,critical_drift_count}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-005')->>'state'<>'BROKEN' then raise exception 'J_DUPLICATE_BROKEN'; end if;
  -- K. product-sale orphan.
  x:=jsonb_set(s,'{product_sale,missing_sale}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-REV-001')->>'state'<>'BROKEN' then raise exception 'K_PRODUCT_SALE_ORPHAN'; end if;
  -- L. reconciliation orphan.
  x:=jsonb_set(s,'{reconciliation,missing_payment}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-REV-002')->>'state'<>'BROKEN' then raise exception 'L_RECON_ORPHAN'; end if;
  -- M. current read model.
  if pg_temp.f66_signal(h,'SEN-DQ-F6-001')->>'state'<>'OK' then raise exception 'M_READMODEL_CURRENT'; end if;
  -- N. stale and version mismatch.
  x:=jsonb_set(s,'{f6_readmodel,source_newer_than_cache}','true'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F6-001')->>'state'<>'DEGRADED' then raise exception 'N_READMODEL_STALE'; end if;
  x:=jsonb_set(s,'{f6_readmodel,version_mismatch_count}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F6-001')->>'state'<>'BROKEN' then raise exception 'N_READMODEL_VERSION'; end if;
  -- O. normal coverage.
  if pg_temp.f66_signal(h,'SEN-DQ-F6-002')->>'state'<>'OK' then raise exception 'O_COVERAGE_NORMAL'; end if;
  -- P. material coverage regression.
  x:=jsonb_set(s,'{f6_coverage,max_drop_pp}','2.5'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F6-002')->>'state'<>'BROKEN' then raise exception 'P_COVERAGE_REGRESSION'; end if;
  -- Q. valid Patient360 aggregate resolution.
  if pg_temp.f66_signal(h,'SEN-DQ-360-001')->>'state'<>'OK' then raise exception 'Q_P360_OK'; end if;
  -- R. unexpected alias collision.
  x:=jsonb_set(s,'{patient360,resolved_collisions}','1'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-360-001')->>'state'<>'BROKEN' then raise exception 'R_P360_COLLISION'; end if;
  -- S. unavailable telemetry -> UNKNOWN, never OK.
  x:=s-'f6_coverage';
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F6-002')->>'state'<>'UNKNOWN' then raise exception 'S_MISSING_TELEMETRY'; end if;
  x:=jsonb_set(s,'{duplicate_profile,telemetry_available}','false'::jsonb);
  if pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-F5-005')->>'state'<>'UNKNOWN' then raise exception 'S_DUPLICATE_UNKNOWN'; end if;
  -- T. identical failing state -> identical digest/dedup.
  x:=jsonb_set(s,'{product_sale,missing_sale}','1'::jsonb);
  d1:=pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-REV-001')->>'state_digest';
  d2:=pg_temp.f66_signal(public.aos_sentinel_rev_f6_6_evaluate_v1(x),'SEN-DQ-REV-001')->>'state_digest';
  if d1 is distinct from d2 then raise exception 'T_DEDUP_DIGEST_UNSTABLE'; end if;
  -- U. state change -> new digest.
  d2:=pg_temp.f66_signal(h,'SEN-DQ-REV-001')->>'state_digest';
  if d1 is not distinct from d2 then raise exception 'U_STATE_CHANGE_DIGEST'; end if;
  -- V. zero-PII envelope and live missing duplicate telemetry is UNKNOWN.
  if h::text ~* '"(phone|email|dni|document|address|birth_date|clinical_note|message_body|payment_reference|raw_payload|identifier_key|target_patient_id|canonical_patient_id)"[[:space:]]*:' then raise exception 'V_PII_KEY_IN_HEALTH'; end if;
  if h::text ~* '\b[0-9]{9}\b' then raise exception 'V_PHONE_LIKE_VALUE_IN_HEALTH'; end if;
  x:=public.aos_sentinel_rev_f6_6_integrity_health_v1();
  if pg_temp.f66_signal(x,'SEN-DQ-F5-005')->>'state'<>'UNKNOWN' then raise exception 'V_LIVE_DUPLICATE_TELEMETRY_FALSE_GREEN'; end if;
  candidate:=public.aos_sentinel_rev_f6_6_incident_candidates_v1();
  if coalesce((candidate->>'auto_ingest')::boolean,true) then raise exception 'F8_AUTO_INGEST_FORBIDDEN'; end if;
  if coalesce((candidate->>'f8_compatible')::boolean,false)=false then raise exception 'F8_COMPAT_FLAG'; end if;
  if coalesce((candidate->>'candidate_count')::integer,0)<1 then raise exception 'F8_EXPECT_UNKNOWN_CANDIDATE'; end if;
  if candidate::text ~* '"(phone|email|dni|document|address|birth_date|clinical_note|message_body|payment_reference|raw_payload|identifier_key|target_patient_id|canonical_patient_id)"[[:space:]]*:' then raise exception 'F8_PII_KEY'; end if;
  ingest1:=public.aos_sentinel_ingest_signal_v1(candidate->'signals'->0);
  ingest2:=public.aos_sentinel_ingest_signal_v1(candidate->'signals'->0);
  if coalesce((ingest1->>'ok')::boolean,false)=false then raise exception 'F8_INGEST_COMPAT'; end if;
  if coalesce((ingest2->>'replay')::boolean,false)=false then raise exception 'F8_REPLAY_DEDUP'; end if;
  -- W. idempotent replay is executed by workflow after this matrix.
  -- X. recovery is executed by workflow and must restore exact pre-F6.6 boundary.
end $$;

do $$
declare r record;
begin
  for r in select p.oid::regprocedure proc from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('aos_rev_f6_6_integrity_baseline_v1','aos_sentinel_rev_f6_6_signal_envelope_v1','aos_sentinel_rev_f6_6_evaluate_v1','aos_sentinel_rev_f6_6_snapshot_v1','aos_sentinel_rev_f6_6_integrity_health_v1','aos_sentinel_rev_f6_6_incident_candidates_v1','aos_rev_f6_6_contract_v1') loop
    if has_function_privilege('anon',r.proc,'EXECUTE') then raise exception 'ACL_ANON:%',r.proc; end if;
    if has_function_privilege('authenticated',r.proc,'EXECUTE') then raise exception 'ACL_AUTH:%',r.proc; end if;
    if not has_function_privilege('service_role',r.proc,'EXECUTE') then raise exception 'ACL_SERVICE:%',r.proc; end if;
  end loop;
end $$;

do $$
declare c1 jsonb:=public.aos_rev_f6_6_contract_v1(); c2 jsonb:=public.aos_rev_f6_6_contract_v1();
begin
  if c1->>'contract_fingerprint' is distinct from c2->>'contract_fingerprint' then raise exception 'CONTRACT_FP_UNSTABLE'; end if;
  if (c1#>>'{contract,signal_count}')::integer<>10 then raise exception 'SIGNAL_COUNT'; end if;
  if coalesce((c1#>>'{contract,observation_only}')::boolean,false)=false then raise exception 'OBSERVATION_ONLY'; end if;
  if coalesce((c1#>>'{contract,auto_repair}')::boolean,true) then raise exception 'AUTO_REPAIR_FORBIDDEN'; end if;
end $$;

select 'REV-F6.6_SYNTHETIC_A_X_PASS' as certificate;
