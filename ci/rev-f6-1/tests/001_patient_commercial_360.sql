\set ON_ERROR_STOP on

do $$
declare
  r jsonb;
  s jsonb;
  a jsonb;
  n integer;
begin
  -- Canonical ID is exact and deterministic.
  r := public.aos_rev_resolve_patient_identity_v2('CANONICAL_ID','P1');
  if r->>'status' <> 'MATCH' or r->>'canonical_patient_id' <> 'P1' then raise exception 'canonical id resolution failed: %',r; end if;

  -- Current and reviewed historical phone aliases must converge on the same subject.
  r := public.aos_rev_resolve_patient_identity_v2('PHONE','999111111');
  if r->>'status' <> 'MATCH' or r->>'canonical_patient_id' <> 'P1' then raise exception 'current phone resolution failed: %',r; end if;
  r := public.aos_rev_resolve_patient_identity_v2('PHONE','999000111');
  if r->>'status' <> 'MATCH' or r->>'canonical_patient_id' <> 'P1' then raise exception 'historical phone resolution failed: %',r; end if;

  -- Shared phone is never silently assigned.
  r := public.aos_rev_resolve_patient_identity_v2('PHONE','999333333');
  if r->>'status' <> 'IDENTITY_CONFLICT' or (r->>'candidate_count')::integer <> 2 or r->>'canonical_patient_id' is not null then
    raise exception 'shared phone must remain conflict: %',r;
  end if;

  -- No RESOLVED alias may represent multiple canonical candidates.
  select count(*) into n from public.aos_rev_patient_identity_alias_v2 where status='RESOLVED' and candidate_count<>1;
  if n<>0 then raise exception 'resolved alias multiplicity violation: %',n; end if;
  select count(*) into n from public.aos_rev_patient_identity_alias_v2 where identifier_type='PHONE' and identifier_key='999333333' and status='CONFLICT';
  if n<>2 then raise exception 'shared phone conflict evidence missing: %',n; end if;

  -- Advisor search can find reviewed historical aliases but labels ambiguous identifiers.
  s := public.aos_patient_search_v2('advisor-f61-token-00000000000000000000','999000111',20);
  if s->>'lookup_status' <> 'NORMAL' or jsonb_array_length(s->'results')<>1 or s->'results'->0->>'canonical_patient_id'<>'P1' then
    raise exception 'historical alias search failed: %',s;
  end if;
  s := public.aos_patient_search_v2('advisor-f61-token-00000000000000000000','999333333',20);
  if s->>'lookup_status' <> 'IDENTITY_CONFLICT' or jsonb_array_length(s->'results')<>2 then
    raise exception 'conflict search failed: %',s;
  end if;

  -- Advisor commercial 360: canonical sales + historical contact history, no clinical PHI.
  a := public.aos_patient_commercial_360_v2('advisor-f61-token-00000000000000000000','PHONE','999000111');
  if coalesce((a->>'found')::boolean,false) is not true then raise exception 'advisor 360 not found: %',a; end if;
  if a->'paciente'->>'canonical_patient_id'<>'P1' then raise exception 'advisor canonical subject wrong'; end if;
  if (a->>'totalCompras')::integer<>1 or (a->>'totalFacturado')::numeric<>100 then raise exception 'canonical sale reconciliation failed: %',a->'commercial_summary'; end if;
  if jsonb_array_length(a->'citas')<>1 or jsonb_array_length(a->'llamadas')<>1 then raise exception 'historical alias contact history not preserved'; end if;
  if coalesce((a->>'clinical_access')::boolean,true) is not false then raise exception 'advisor clinical access leak'; end if;
  if jsonb_array_length(a->'notas')<>0 or jsonb_array_length(a->'documentos')<>0 then raise exception 'advisor PHI arrays must be empty'; end if;
  if (a->'identity'->>'phone_alias_count')::integer<>2 then raise exception 'safe phone alias count wrong: %',a->'identity'; end if;
  if coalesce((a->'identity'->>'historical_contact_indicator')::boolean,false) is not true then raise exception 'historical contact indicator missing'; end if;
  if a->'identity'->>'duplicate_evidence_class'<>'IDENTITY_CONFLICT' then raise exception 'known shared alias conflict not surfaced'; end if;
  if a->'commercial_summary'->>'lifecycle_state'<>'PENDING_REV_F6_2' then raise exception 'F6.1 must not invent lifecycle'; end if;
  if a->'commercial_summary'->'observed_paid_amount' <> 'null'::jsonb then raise exception 'F4 pending ADELANTO must not become paid amount'; end if;
  if (a->'commercial_summary'->>'payment_evidence_rows')::integer<>0 or (a->'commercial_summary'->>'confirmed_balance_rows')::integer<>0 then raise exception 'financial evidence semantics drift'; end if;
  if not (a->'metric_trust' ? 'coverage' and a->'metric_trust' ? 'confidence' and a->'metric_trust' ? 'freshness' and a->'metric_trust' ? 'sample_size') then raise exception 'Metric Trust fields missing'; end if;
  if a->'metric_trust'->>'historical_warning' not like '%NO_CERTIFIED_SOURCE%' then raise exception 'historical warning missing'; end if;
  if not exists(select 1 from jsonb_array_elements(a->'timeline') e where e->>'event_type'='SALE') then raise exception 'sale timeline event missing'; end if;
  if not exists(select 1 from jsonb_array_elements(a->'timeline') e where e->>'event_type'='APPOINTMENT') then raise exception 'appointment timeline event missing'; end if;
  if not exists(select 1 from jsonb_array_elements(a->'timeline') e where e->>'event_type'='CALL') then raise exception 'call timeline event missing'; end if;
  if not exists(select 1 from jsonb_array_elements(a->'timeline') e where e->>'event_type'='LEAD') then raise exception 'lead timeline event missing'; end if;
  if not exists(select 1 from jsonb_array_elements(a->'timeline') e where e->>'event_type'='FINANCIAL_EVIDENCE') then raise exception 'F4 timeline evidence missing'; end if;

  -- Admin+2FA may receive role-gated clinical arrays; aliases remain masked.
  a := public.aos_patient_commercial_360_v2('admin-f61-token-0000000000000000000000','CANONICAL_ID','P1');
  if coalesce((a->>'clinical_access')::boolean,false) is not true then raise exception 'admin clinical access missing'; end if;
  if jsonb_array_length(a->'notas')<>1 or jsonb_array_length(a->'documentos')<>1 then raise exception 'admin role-gated clinical history missing'; end if;
  if jsonb_array_length(coalesce(a->'identity'->'aliases_admin','[]'::jsonb))=0 then raise exception 'admin alias evidence missing'; end if;
  if exists(select 1 from jsonb_array_elements(a->'identity'->'aliases_admin') e where length(coalesce(e->>'masked',''))=0) then raise exception 'unmasked/empty admin alias representation'; end if;

  -- Bad token must fail closed.
  begin
    perform public.aos_patient_search_v2('invalid','999000111',20);
    raise exception 'invalid token unexpectedly accepted';
  exception when others then
    if sqlerrm='invalid token unexpectedly accepted' then raise; end if;
  end;
end $$;

-- ACL/security: private bridge stays private; browser RPCs are token-gated; legacy RPC remains closed by F6.0.
do $$ begin
  if has_table_privilege('anon','public.aos_rev_patient_identity_alias_v2','SELECT') then raise exception 'anon alias-view access'; end if;
  if has_table_privilege('authenticated','public.aos_rev_patient_identity_alias_v2','SELECT') then raise exception 'authenticated alias-view access'; end if;
  if has_function_privilege('anon','public.aos_rev_resolve_patient_identity_v2(text,text)','EXECUTE') then raise exception 'anon resolver access'; end if;
  if has_function_privilege('authenticated','public.aos_rev_resolve_patient_identity_v2(text,text)','EXECUTE') then raise exception 'authenticated resolver access'; end if;
  if not has_function_privilege('anon','public.aos_patient_search_v2(text,text,integer)','EXECUTE') then raise exception 'browser search gateway missing'; end if;
  if not has_function_privilege('authenticated','public.aos_patient_commercial_360_v2(text,text,text)','EXECUTE') then raise exception 'browser 360 gateway missing'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy Patient 360 reopened to anon'; end if;
  if has_function_privilege('authenticated','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy Patient 360 reopened to authenticated'; end if;
end $$;

-- Synthetic business domains must remain untouched by read tests.
do $$ begin
  if (select count(*) from public.aos_pacientes)<>2 then raise exception 'patient mutation detected'; end if;
  if (select count(*) from public.aos_ventas)<>1 then raise exception 'sales mutation detected'; end if;
  if (select count(*) from public.aos_product_sale_fact_current_v1)<>1 then raise exception 'F3 mutation detected'; end if;
  if (select count(*) from public.aos_cartera_reconciliacion)<>1 then raise exception 'F4 mutation detected'; end if;
end $$;

select 'REV-F6.1 DB/security/semantic contract PASS' as result;
