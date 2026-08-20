\set ON_ERROR_STOP on

do $$
declare
  r jsonb;
  r2 jsonb;
  s jsonb;
  a jsonb;
  n integer;
begin
  r := public.aos_rev_customer_lifecycle_v1('PHONE','999300003','2026-08-19');
  if r->>'lifecycle_state'<>'NEW_PATIENT' or r->>'classification_status'<>'CLASSIFIED' then raise exception 'NEW_PATIENT failed: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999400004','2026-08-19');
  if r->>'lifecycle_state'<>'HISTORICAL_REACTIVATED' then raise exception 'HISTORICAL_REACTIVATED failed: %',r; end if;
  if (r->'flags'->>'reactivation_gap_days')::integer < 180 then raise exception 'reactivation gap missing: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999500005','2026-08-19');
  if r->>'lifecycle_state'<>'ACTIVE_REPEAT' then raise exception 'ACTIVE_REPEAT failed: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999600006','2026-08-19');
  if r->>'lifecycle_state'<>'RETURNING_PATIENT' then raise exception 'RETURNING_PATIENT failed: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999700007','2026-08-19');
  if r->>'lifecycle_state'<>'DORMANT' then raise exception 'DORMANT failed: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999800008','2026-08-19');
  if r->>'lifecycle_state'<>'RETURNING_PATIENT' or coalesce((r->'flags'->>'has_future_appointment')::boolean,false) is not true then
    raise exception 'future confirmed appointment must prevent dormant: %',r;
  end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999222222','2026-08-19');
  if r->'lifecycle_state' <> 'null'::jsonb or r->>'classification_status'<>'INSUFFICIENT_ACTIVITY_EVIDENCE' then
    raise exception 'no-evidence patient must fail closed without invented state: %',r;
  end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','111111111','2026-08-19');
  if r->>'lifecycle_state'<>'UNRESOLVED_IDENTITY' or r->>'identity_resolution_status'<>'UNRESOLVED' then raise exception 'unresolved identity lifecycle failed: %',r; end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999333333','2026-08-19');
  if r->>'lifecycle_state'<>'UNRESOLVED_IDENTITY' or r->>'identity_resolution_status'<>'IDENTITY_CONFLICT' or (r->>'candidate_count')::integer<>2 then
    raise exception 'identity conflict must fail closed: %',r;
  end if;

  r := public.aos_rev_customer_lifecycle_v1('PHONE','999400004','2026-08-19');
  r2 := public.aos_rev_customer_lifecycle_v1('PHONE','999400004','2026-08-19');
  if r is distinct from r2 then raise exception 'same as-of/input must be deterministic'; end if;
  if (r->'thresholds'->>'active_days')::integer<>90 or (r->'thresholds'->>'dormant_gap_days')::integer<>180 or (r->'thresholds'->>'reactivation_window_days')::integer<>30 then
    raise exception 'threshold contract drift: %',r->'thresholds';
  end if;
  if r->>'historical_warning' not like '%NO_CERTIFIED_SOURCE%' then raise exception 'historical coverage warning missing'; end if;
  if coalesce((r->'event_definition'->>'registration_is_not_qualifying')::boolean,false) is not true then raise exception 'registration unexpectedly qualifying'; end if;

  s := public.aos_rev_customer_lifecycle_summary_v1('2026-08-19');
  if (s->>'canonical_population')::integer<>8 or (s->>'classified_population')::integer<>7 or (s->>'insufficient_activity_evidence')::integer<>1 then
    raise exception 'summary population mismatch: %',s;
  end if;
  if (s->'states'->>'HISTORICAL_REACTIVATED')::integer<>1 or (s->'states'->>'ACTIVE_REPEAT')::integer<>1 or (s->'states'->>'DORMANT')::integer<>1 then
    raise exception 'summary state counts mismatch: %',s->'states';
  end if;

  a := public.aos_patient_commercial_360_v2('advisor-f61-token-00000000000000000000','PHONE','999400004');
  if coalesce((a->>'found')::boolean,false) is not true then raise exception 'F6.2 wrapper 360 not found: %',a; end if;
  if a->>'contract'<>'REV-F6.2_PATIENT_COMMERCIAL_360_V2' then raise exception 'wrapper contract wrong'; end if;
  if a->'commercial_summary'->>'lifecycle_state'<>'HISTORICAL_REACTIVATED' then raise exception '360 lifecycle not injected: %',a->'commercial_summary'; end if;
  if a->'lifecycle'->>'lifecycle_state'<>'HISTORICAL_REACTIVATED' then raise exception 'top lifecycle contract missing'; end if;
  if coalesce((a->>'clinical_access')::boolean,true) is not false or jsonb_array_length(a->'notas')<>0 or jsonb_array_length(a->'documentos')<>0 then
    raise exception 'advisor PHI boundary regressed';
  end if;

  if exists(select 1 from public.aos_rev_customer_agenda_identity_v1 where identity_status='RESOLVED' and candidate_count<>1) then raise exception 'resolved agenda identity multiplicity'; end if;
  if exists(select 1 from public.aos_rev_customer_lifecycle_events_v1 e left join public.aos_pacientes p on p."ID_PACIENTE"=e.canonical_patient_id where p."ID_PACIENTE" is null) then raise exception 'lifecycle orphan patient'; end if;
  if exists(select 1 from public.aos_ventas where fecha < date '2026-01-01') then raise exception 'synthetic historical sale introduced'; end if;

  select count(*) into n from public.aos_pacientes;
  if n<>8 then raise exception 'patient mutation detected: %',n; end if;
  select count(*) into n from public.aos_ventas;
  if n<>1 then raise exception 'sales mutation detected: %',n; end if;
  select count(*) into n from public.aos_product_sale_fact_current_v1;
  if n<>1 then raise exception 'F3 mutation detected: %',n; end if;
  select count(*) into n from public.aos_cartera_reconciliacion;
  if n<>1 then raise exception 'F4 mutation detected: %',n; end if;
end $$;

do $$ begin
  if has_table_privilege('anon','public.aos_rev_customer_lifecycle_events_v1','SELECT') then raise exception 'anon lifecycle-event view access'; end if;
  if has_table_privilege('authenticated','public.aos_rev_customer_agenda_identity_v1','SELECT') then raise exception 'authenticated agenda identity view access'; end if;
  if has_function_privilege('anon','public.aos_rev_customer_lifecycle_v1(text,text,date)','EXECUTE') then raise exception 'anon direct lifecycle resolver access'; end if;
  if has_function_privilege('authenticated','public.aos_rev_customer_lifecycle_by_patient_v1(text,date)','EXECUTE') then raise exception 'authenticated direct lifecycle patient access'; end if;
  if has_function_privilege('anon','public.aos_patient_commercial_360_v2_f6_1_base(text,text,text)','EXECUTE') then raise exception 'F6.1 base browser bypass'; end if;
  if not has_function_privilege('anon','public.aos_patient_commercial_360_v2(text,text,text)','EXECUTE') then raise exception 'governed browser 360 gateway missing'; end if;
  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'legacy Patient 360 reopened'; end if;
end $$;

select 'REV-F6.2 lifecycle/security/semantic contract PASS' as result;
