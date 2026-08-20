-- REV-F6.0 — Data Contract V1 + Patient 360 legacy security boundary
-- Additive/read-only contract. No patient/sale/F3/F4/identity/financial mutation.

begin;

create or replace function public.aos_rev_f6_data_contract_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_payload jsonb;
  v_patient_fp text;
  v_sales_fp text;
  v_f3_fp text;
  v_f4_fp text;
  v_source_rows bigint;
  v_expected_rows bigint;
  v_members bigint;
  v_clusters bigint;
  v_match bigint;
  v_review bigint;
  v_new bigint;
  v_sales bigint;
  v_sale_match bigint;
  v_sale_review bigint;
  v_sale_unresolved bigint;
  v_f3_applicable bigint;
  v_f3_resolved bigint;
  v_f3_review bigint;
  v_f3_excluded bigint;
  v_f3_missing bigint;
  v_f3_not_applicable bigint;
  v_f4_linked bigint;
  v_f4_unlinked bigint;
  v_f4_rows bigint;
  v_f4_distinct_sales bigint;
  v_patient_rows bigint;
  v_cia_rows bigint;
  v_cia_patients bigint;
  v_cia_conflicts bigint;
  v_sales_min date;
  v_sales_max date;
  v_source_updated timestamptz;
  v_sales_updated timestamptz;
  v_f4_updated timestamptz;
  v_cia_updated timestamptz;
begin
  select count(*), coalesce(sum(source_rows),0), max(updated_at)
    into v_source_rows, v_expected_rows, v_source_updated
  from public.aos_f5_source_batches_v1 b
  cross join lateral (select 1) x
  where b.status = 'MATCHED';

  -- source_rows above is batch count because it is intentionally overwritten below;
  -- keeping all counts explicit makes the contract independent from UI assumptions.
  select count(*) into v_source_rows from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  select
    count(*) filter (where classification='MATCH'),
    count(*) filter (where classification='REVIEW'),
    count(*) filter (where classification='NEW')
  into v_match,v_review,v_new
  from public.aos_f5_canonical_classification_v1;

  select count(*), min(fecha), max(fecha), max(updated_at)
  into v_sales,v_sales_min,v_sales_max,v_sales_updated
  from public.aos_ventas;

  select
    count(*) filter (where patient_link_status='MATCH'),
    count(*) filter (where patient_link_status='REVIEW'),
    count(*) filter (where patient_link_status='UNRESOLVED'),
    count(*) filter (where product_applicable),
    count(*) filter (where product_resolution_status='RESOLVED'),
    count(*) filter (where product_resolution_status='REVIEW_REQUIRED'),
    count(*) filter (where product_resolution_status='EXCLUDED'),
    count(*) filter (where product_resolution_status='MISSING_F3_FACT'),
    count(*) filter (where product_resolution_status='NOT_APPLICABLE'),
    count(*) filter (where cartera_link_status='F4_LINKED'),
    count(*) filter (where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE')
  into v_sale_match,v_sale_review,v_sale_unresolved,
       v_f3_applicable,v_f3_resolved,v_f3_review,v_f3_excluded,v_f3_missing,v_f3_not_applicable,
       v_f4_linked,v_f4_unlinked
  from public.aos_f5_historical_join_v1;

  select count(*), count(distinct venta_row_id) filter (where venta_row_id is not null), max(updated_at)
  into v_f4_rows,v_f4_distinct_sales,v_f4_updated
  from public.aos_cartera_reconciliacion;

  select count(*), count(*) filter (where canonical_patient_id is not null),
         count(*) filter (where identity_conflict), max(canonical_patient_updated_at)
  into v_cia_rows,v_cia_patients,v_cia_conflicts,v_cia_updated
  from public.aos_cia_contact_identity_v1;

  select count(*) into v_patient_rows from public.aos_pacientes;

  select md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_patient_fp from public.aos_pacientes p;
  select md5(string_agg(md5(to_jsonb(v)::text),',' order by v.id))
    into v_sales_fp from public.aos_ventas v;
  select md5(string_agg(md5(to_jsonb(f)::text),',' order by f.sale_id))
    into v_f3_fp from public.aos_product_sale_fact_current_v1 f;
  select md5(string_agg(md5(to_jsonb(c)::text),',' order by c.id))
    into v_f4_fp from public.aos_cartera_reconciliacion c;

  v_payload := jsonb_build_object(
    'contract_id','REV-F6.0_DATA_CONTRACT_V1',
    'contract_version',1,
    'status','CERTIFIED_INPUT_BOUNDARY',
    'truth_layers',jsonb_build_object(
      'patient_identity','REV-F5 / aos_f5_* + aos_pacientes',
      'sales','aos_ventas',
      'product','F3 / aos_product_sale_fact_current_v1',
      'financial','F4 / aos_cartera_reconciliacion',
      'identity_compatibility','aos_cia_contact_identity_v1',
      'patient_commercial_360_target','REV_PATIENT_COMMERCIAL_360_V2_CONTRACT',
      'identity_bridge_v2','CONTRACT_FROZEN_NOT_MATERIALIZED_AT_F6_0'
    ),
    'source_state',jsonb_build_object(
      'batches_total',(select count(*) from public.aos_f5_source_batches_v1),
      'batches_matched',(select count(*) from public.aos_f5_source_batches_v1 where status='MATCHED'),
      'source_rows',v_source_rows,
      'expected_rows',(select coalesce(sum(source_rows),0) from public.aos_f5_source_batches_v1),
      'memberships',v_members,
      'clusters',v_clusters,
      'classification',jsonb_build_object('MATCH',v_match,'REVIEW',v_review,'NEW',v_new),
      'patient_history_years',(select jsonb_agg(y order by y) from (select distinct source_year y from public.aos_f5_source_batches_v1 where status='MATCHED') q)
    ),
    'canonical_state',jsonb_build_object(
      'patients',v_patient_rows,
      'patient_fingerprint',v_patient_fp,
      'sales',v_sales,
      'sales_fingerprint',v_sales_fp,
      'sales_min_date',v_sales_min,
      'sales_max_date',v_sales_max,
      'f3_rows',(select count(*) from public.aos_product_sale_fact_current_v1),
      'f3_fingerprint',v_f3_fp,
      'f4_rows',v_f4_rows,
      'f4_fingerprint',v_f4_fp
    ),
    'coverage',jsonb_build_object(
      'identity',jsonb_build_object('numerator',v_match,'denominator',v_clusters,'pct',round(100.0*v_match/nullif(v_clusters,0),2),'semantic','SAFE_MATCH_CLUSTERS'),
      'sales_linkage',jsonb_build_object('numerator',v_sale_match,'denominator',v_sales,'pct',round(100.0*v_sale_match/nullif(v_sales,0),2),'REVIEW',v_sale_review,'UNRESOLVED',v_sale_unresolved),
      'f3_product',jsonb_build_object('numerator',v_f3_resolved,'denominator',v_f3_applicable,'pct',round(100.0*v_f3_resolved/nullif(v_f3_applicable,0),2),'REVIEW_REQUIRED',v_f3_review,'EXCLUDED',v_f3_excluded,'MISSING_F3_FACT',v_f3_missing,'NOT_APPLICABLE',v_f3_not_applicable),
      'f4_financial_evidence',jsonb_build_object('numerator',v_f4_linked,'denominator',v_sales,'pct',round(100.0*v_f4_linked/nullif(v_sales,0),2),'NO_F4_RECONCILIATION_EVIDENCE',v_f4_unlinked,'reconciliation_rows',v_f4_rows,'distinct_sales',v_f4_distinct_sales),
      'historical_transaction_source_availability',jsonb_build_object('numerator',1,'denominator',3,'pct',33.33,'semantic','SOURCE_AVAILABILITY_NOT_REVENUE')
    ),
    'historical_periods',jsonb_build_object(
      'patient_history_2024','AVAILABLE',
      'patient_history_2025','AVAILABLE',
      'patient_history_2026','AVAILABLE',
      'transactional_sales_2024','NO_CERTIFIED_SOURCE',
      'transactional_sales_2025','NO_CERTIFIED_SOURCE',
      'transactional_sales_2026',format('AVAILABLE_%s_TO_%s',v_sales_min,v_sales_max),
      'absence_means_zero',false,
      'yoy_2024_2026_supported',false
    ),
    'metric_trust_contract',jsonb_build_object(
      'required_fields',jsonb_build_array('coverage','confidence','freshness','sample_size'),
      'zero_observed_is_not_no_source',true,
      'no_source_must_be_explicit',true,
      'derived_models_require_generated_at',true,
      'derived_models_are_stale_when_source_is_newer',true
    ),
    'freshness_sources',jsonb_build_object(
      'patient_source_updated_at',v_source_updated,
      'sales_updated_at',v_sales_updated,
      'f4_updated_at',v_f4_updated,
      'cia_identity_updated_at',v_cia_updated
    ),
    'compatibility_identity',jsonb_build_object(
      'object','aos_cia_contact_identity_v1',
      'rows',v_cia_rows,
      'with_canonical_patient',v_cia_patients,
      'identity_conflicts',v_cia_conflicts,
      'authority','COMPATIBILITY_ONLY_NOT_NEW_TRUTH_LAYER'
    ),
    'semantic_guards',jsonb_build_object(
      'name_alone_authorizes_identity',false,
      'phone_alone_authorizes_identity',false,
      'phone_nearness_authorizes_identity',false,
      'ultimo_presupuesto_is_sale_payment_or_debt',false,
      'adelanto_is_automatic_debt',false,
      'clinical_notes_auto_enrichment',false,
      'f3_is_product_truth',true,
      'f4_is_financial_truth',true,
      'f5_is_identity_provenance_truth',true,
      'unsupported_historical_yoy_allowed',false
    ),
    'prior_certification',jsonb_build_object(
      'f5_7_fp','5af139243f6aed37020048af292587fe',
      'f5_8_fp','4ce1695532a57655179558ed2b5f78aa',
      'f5_9_fp','5070c701d216eb839572bd70f530c2e6',
      'f5_10_terminal_fp','2f0a365fae4caaa7be9d204e0f76679b'
    )
  );

  return jsonb_build_object(
    'ok',true,
    'contract',v_payload,
    'contract_fingerprint',md5(v_payload::text),
    'as_of',now()
  );
end;
$$;

comment on function public.aos_rev_f6_data_contract_v1() is
'REV-F6.0 service-only read contract. Produces truth-layer, coverage, freshness and semantic boundary with deterministic payload fingerprint.';

revoke all on function public.aos_rev_f6_data_contract_v1() from public, anon, authenticated;
grant execute on function public.aos_rev_f6_data_contract_v1() to service_role;

create or replace function public.aos_patient_history_summary_v1(p_token text, p_numero text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_phone text;
  v_compras jsonb;
  v_citas jsonb;
  v_llamadas jsonb;
begin
  if nullif(btrim(coalesce(p_token,'')),'') is null then
    raise exception 'UNAUTHORIZED';
  end if;

  begin
    v_actor := public.aos_app_actor_v3(p_token,'advisor-patients',true);
  exception when others then
    begin
      v_actor := public.aos_app_actor_v3(p_token,'admin-patients',true);
    exception when others then
      raise exception 'UNAUTHORIZED';
    end;
  end;

  if v_actor is null then
    raise exception 'UNAUTHORIZED';
  end if;

  v_phone := right(regexp_replace(coalesce(p_numero,''),'\D','','g'),9);
  if length(v_phone) <> 9 then
    raise exception 'INVALID_PHONE';
  end if;

  select coalesce(jsonb_agg(x order by (x->>'fecha') desc nulls last),'[]'::jsonb)
  into v_compras
  from (
    select jsonb_build_object(
      'fecha',v.fecha,
      'tratamiento',v.tratamiento,
      'monto',v.monto,
      'sede',v.sede
    ) x
    from public.aos_ventas v
    where right(regexp_replace(coalesce(nullif(v.numero_limpio,''),v.celular,''),'\D','','g'),9)=v_phone
    order by v.fecha desc, v.id desc
    limit 100
  ) q;

  select coalesce(jsonb_agg(x order by (x->>'fecha_cita') desc nulls last),'[]'::jsonb)
  into v_citas
  from (
    select jsonb_build_object(
      'fecha_cita',c.fecha_cita,
      'hora_cita',c.hora_cita,
      'tratamiento',c.tratamiento,
      'estado_cita',c.estado_cita,
      'sede',c.sede
    ) x
    from public.aos_agenda_citas c
    where right(regexp_replace(coalesce(nullif(c.numero_limpio,''),c.numero,''),'\D','','g'),9)=v_phone
    order by c.fecha_cita desc, c.ts_creado desc nulls last
    limit 100
  ) q;

  select coalesce(jsonb_agg(x order by (x->>'fecha') desc nulls last),'[]'::jsonb)
  into v_llamadas
  from (
    select jsonb_build_object(
      'fecha',l.fecha,
      'hora_llamada',l.hora_llamada,
      'tratamiento',l.tratamiento,
      'estado',l.estado,
      'sub_estado',l.sub_estado
    ) x
    from public.aos_llamadas l
    where right(regexp_replace(coalesce(nullif(l.numero_limpio,''),l.numero,''),'\D','','g'),9)=v_phone
    order by l.fecha desc, l.id desc
    limit 100
  ) q;

  return jsonb_build_object(
    'ok',true,
    'readOnly',true,
    'contract','REV-F6.0_PATIENT_HISTORY_MINIMUM_V1',
    'compras',v_compras,
    'citas',v_citas,
    'llamadas',v_llamadas
  );
end;
$$;

comment on function public.aos_patient_history_summary_v1(text,text) is
'Auth V3 + PASSWORD_2FA patient-commercial summary for Citas. Deliberately excludes patient record, clinical notes, documents and call observations.';

revoke all on function public.aos_patient_history_summary_v1(text,text) from public;
grant execute on function public.aos_patient_history_summary_v1(text,text) to anon, authenticated, service_role;

-- Legacy Patient 360 returned patient records + notes + documents under SECURITY DEFINER.
-- Close it to browser roles. Recovery must never reopen this weak path.
alter function public.aos_paciente_360(text) set search_path = '';
revoke all on function public.aos_paciente_360(text) from public, anon, authenticated;
grant execute on function public.aos_paciente_360(text) to service_role;

select pg_notify('pgrst','reload schema');

commit;
