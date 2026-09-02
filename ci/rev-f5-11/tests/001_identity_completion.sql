\set ON_ERROR_STOP on

-- A REVIEW with identity strong enough to retain the target while current identity anchors are absent;
-- sex conflict must remain explicit rather than overwrite the patient.
insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Sexo","ESTADO_PACIENTE",fuente_datos)
values ('P-E','Elena','Evidencia','F','ACTIVO','historico') on conflict ("ID_PACIENTE") do nothing;
insert into public.aos_f5_identity_clusters_v1(id,status,confidence,source_row_count,canonical_preview,evidence,conflicts) values
('00000000-0000-0000-0000-000000000009','REVIEW_REQUIRED','HIGH',1,'{"nombres":"Elena","apellidos":"Evidencia","sex":"M"}','{}','{}') on conflict (id) do nothing;
insert into public.aos_f5_canonical_classification_v1(cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score,canonical_sex_conflict) values
('00000000-0000-0000-0000-000000000009','P-E','REVIEW_REQUIRED','REVIEW','CANONICAL_STRONG_FIELD_CONFLICT','EMAIL',60,true) on conflict (cluster_id) do nothing;
insert into public.aos_f5_patient_source_rows_v1(id,phone_key,phone_type,names_raw,surnames_raw,name_key,email_key,document_key,document_type,sex_raw,source_created_date) values
(10,null,'MISSING','Elena','Evidencia','ELENAEVIDENCIA','elena.old@test.pe',null,null,'M','2024-07-01') on conflict (id) do nothing;
insert into public.aos_f5_identity_cluster_members_v1 values ('00000000-0000-0000-0000-000000000009',10) on conflict (cluster_id,source_row_id) do nothing;

do $$
declare s jsonb;
begin
 s:=public.aos_f5_11_identity_completion_snapshot_v1();
 if (s->>'clusters')::int<>9 then raise exception 'F5_11_TEST_CLUSTER_COUNT %',s; end if;
 if (s->>'source_rows')::int<>10 then raise exception 'F5_11_TEST_SOURCE_COUNT %',s; end if;
 if (s->>'resolved_existing')::int<>4 then raise exception 'F5_11_TEST_RESOLVED_EXISTING %',s; end if;
 if (s->>'resolved_attribute_review')::int<>1 then raise exception 'F5_11_TEST_ATTRIBUTE_REVIEW %',s; end if;
 if (s->>'safe_new')::int<>1 then raise exception 'F5_11_TEST_SAFE_NEW %',s; end if;
 if (s->>'stale_target')::int<>1 then raise exception 'F5_11_TEST_STALE %',s; end if;
 if (s->>'review_required')::int<>2 then raise exception 'F5_11_TEST_REVIEW %',s; end if;
end $$;

-- Phone-only evidence must never auto-link.
do $$ begin
 if (select resolution_status from public.aos_f5_historical_identity_completion_preview_v1 where cluster_id='00000000-0000-0000-0000-000000000003')<>'REVIEW_REQUIRED' then
  raise exception 'F5_11_PHONE_ONLY_MUST_REVIEW';
 end if;
 if (select resolution_status from public.aos_f5_historical_identity_completion_preview_v1 where cluster_id='00000000-0000-0000-0000-000000000008')<>'STALE_TARGET' then
  raise exception 'F5_11_STALE_MATCH_MUST_NOT_PHONE_REMAP';
 end if;
 if (select resolution_status from public.aos_f5_historical_identity_completion_preview_v1 where cluster_id='00000000-0000-0000-0000-000000000009')<>'RESOLVED_EXISTING_ATTRIBUTE_REVIEW' then
  raise exception 'F5_11_SEX_CONFLICT_IDENTITY_EXPECTED';
 end if;
end $$;

-- Apply with optimistic fingerprint/count lock.
do $$
declare s jsonb; r jsonb;
begin
 s:=public.aos_f5_11_identity_completion_snapshot_v1();
 r:=public.aos_f5_11_apply_identity_completion_v1(s->>'preview_fingerprint',(s->>'safe_new')::int);
 if not coalesce((r->>'ok')::boolean,false) or coalesce((r->>'replay')::boolean,true) then raise exception 'F5_11_APPLY_FAILED %',r; end if;
 if (r->>'new_created')::int<>1 then raise exception 'F5_11_NEW_CREATED_BAD %',r; end if;
end $$;

-- Existing canonical identity fields remain untouched.
do $$ begin
 if not exists(select 1 from public.aos_pacientes where "ID_PACIENTE"='P-A' and "Teléfono"='999111222' and numero_limpio='999111222' and "Email"='ana@clinic.test' and "N° documento"='11111111' and "Nombres"='Ana' and "Apellidos"='Actual') then raise exception 'F5_11_EXISTING_P_A_MUTATED'; end if;
 if not exists(select 1 from public.aos_pacientes where "ID_PACIENTE"='P-B' and "Teléfono"='988777666' and numero_limpio='988777666' and "Email"='bruno@clinic.test' and "N° documento"='22222222' and "Sexo"='M') then raise exception 'F5_11_EXISTING_P_B_MUTATED'; end if;
 if not exists(select 1 from public.aos_pacientes where "ID_PACIENTE"='P-E' and "Sexo"='F') then raise exception 'F5_11_ATTRIBUTE_REVIEW_OVERWROTE_SEX'; end if;
end $$;

-- Exactly one deterministic safe-new patient is created with provenance.
do $$ begin
 if (select count(*) from public.aos_pacientes where "ID_PACIENTE" like 'P-HIST-F511-%')<>1 then raise exception 'F5_11_SAFE_NEW_COUNT'; end if;
 if not exists(select 1 from public.aos_pacientes where "ID_PACIENTE"='P-HIST-F511-00000000000000000000000000000006' and "Nombres"='Carla' and "Apellidos"='Historica' and "Teléfono"='955444333' and numero_limpio='955444333' and "Email"='carla.hist@test.pe' and "N° documento"='87654321' and "ESTADO_PACIENTE"='PROSPECTO' and fuente_datos='historico_f5_completion_v2') then raise exception 'F5_11_SAFE_NEW_PAYLOAD'; end if;
end $$;

-- Alias bridge exposes completed history, and stale fused targets disappear.
do $$ begin
 if not exists(select 1 from public.aos_rev_patient_identity_alias_v2 where identifier_type='PHONE' and identifier_key='955444333' and canonical_patient_id='P-HIST-F511-00000000000000000000000000000006' and status='RESOLVED' and confidence_band='HIGH' and evidence_scopes ? 'F5_COMPLETION_V2') then raise exception 'F5_11_NEW_PHONE_ALIAS_MISSING'; end if;
 if not exists(select 1 from public.aos_rev_patient_identity_alias_v2 where identifier_type='EMAIL' and identifier_key='ana@clinic.test' and canonical_patient_id='P-A' and evidence_scopes ? 'F5_COMPLETION_V2') then raise exception 'F5_11_REVIEW_ALIAS_NOT_PROMOTED'; end if;
 if exists(select 1 from public.aos_rev_patient_identity_alias_v2 where canonical_patient_id='P-OLD') then raise exception 'F5_11_STALE_FUSED_ALIAS_LEAK'; end if;
end $$;

-- Full accounting and idempotent replay.
do $$
declare r jsonb;
begin
 if (select count(*) from public.aos_f5_historical_identity_resolution_v2)<>9 then raise exception 'F5_11_LEDGER_INCOMPLETE'; end if;
 if (select sum(source_row_count) from public.aos_f5_historical_identity_resolution_v2)<>10 then raise exception 'F5_11_LEDGER_SOURCE_INCOMPLETE'; end if;
 r:=public.aos_f5_11_apply_identity_completion_v1('ignored-on-replay',999);
 if not coalesce((r->>'replay')::boolean,false) then raise exception 'F5_11_REPLAY_NOT_IDEMPOTENT %',r; end if;
 if (select count(*) from public.aos_pacientes where "ID_PACIENTE" like 'P-HIST-F511-%')<>1 then raise exception 'F5_11_REPLAY_DUPLICATED_PATIENT'; end if;
 if exists(select 1 from public.aos_ventas where fecha between date '2024-01-01' and date '2025-12-31') then raise exception 'F5_11_HISTORICAL_SALES_MUTATED'; end if;
end $$;
