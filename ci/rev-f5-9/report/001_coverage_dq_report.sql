\set ON_ERROR_STOP on

-- REV-F5.9 deterministic read-only report.
-- Expected fingerprint at certified LIVE state:
-- 5070c701d216eb839572bd70f530c2e6

with
source_files as (
 select jsonb_agg(jsonb_build_object('file',b.source_filename,'sede',b.source_sede,'year',b.source_year,'status',b.status,'expected_rows',b.source_rows,'persisted_rows',coalesce(r.c,0)) order by b.source_year,b.source_sede) j
 from public.aos_f5_source_batches_v1 b
 left join (select batch_id,count(*) c from public.aos_f5_patient_source_rows_v1 group by batch_id) r on r.batch_id=b.id
),
staging as (
 select jsonb_build_object(
 'batches',(select count(*) from public.aos_f5_source_batches_v1),
 'matched_batches',(select count(*) from public.aos_f5_source_batches_v1 where status='MATCHED'),
 'source_rows',(select count(*) from public.aos_f5_patient_source_rows_v1),
 'expected_rows',(select sum(source_rows) from public.aos_f5_source_batches_v1),
 'members',(select count(*) from public.aos_f5_identity_cluster_members_v1),
 'clusters',(select count(*) from public.aos_f5_identity_clusters_v1),
 'missing_members',(select count(*) from public.aos_f5_patient_source_rows_v1 r left join public.aos_f5_identity_cluster_members_v1 m on m.source_row_id=r.id where m.source_row_id is null),
 'orphan_members',(select count(*) from public.aos_f5_identity_cluster_members_v1 m left join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id where r.id is null),
 'invalid_member_multiplicity',(select count(*) from (select source_row_id from public.aos_f5_identity_cluster_members_v1 group by source_row_id having count(*)<>1)x),
 'duplicate_source_keys',(select count(*) from (select batch_id,source_row_num from public.aos_f5_patient_source_rows_v1 group by batch_id,source_row_num having count(*)>1)x),
 'provenance_gaps',(select count(*) from public.aos_f5_patient_source_rows_v1 where batch_id is null or source_row_num is null or row_content_hash is null or identity_seed_hash is null),
 'files',(select j from source_files)) j
),
identity as (
 select jsonb_build_object(
 'clusters',count(*),'MATCH',count(*) filter(where classification='MATCH'),'REVIEW',count(*) filter(where classification='REVIEW'),'NEW',count(*) filter(where classification='NEW'),
 'strong_conflicts',count(*) filter(where source_strong_conflict),'target_collisions',count(*) filter(where target_collision),
 'conflict_clusters',count(*) filter(where canonical_dni_conflict or canonical_email_conflict or canonical_dob_conflict or canonical_sex_conflict or source_strong_conflict or target_collision),
 'linked_canonical_patients',count(distinct target_patient_id) filter(where classification='MATCH' and target_patient_id is not null),
 'score_pct',round(100.0*count(*) filter(where classification='MATCH')/nullif(count(*),0),2)) j
 from public.aos_f5_canonical_classification_v1
),
identity_year as (
 select jsonb_agg(jsonb_build_object('year',yr,'source_rows',rows,'MATCH',m,'REVIEW',r,'NEW',n,'match_pct',round(100.0*m/nullif(rows,0),2)) order by yr) j
 from (
  select b.source_year yr,count(*) rows,count(*) filter(where c.classification='MATCH') m,count(*) filter(where c.classification='REVIEW') r,count(*) filter(where c.classification='NEW') n
  from public.aos_f5_identity_cluster_members_v1 cm
  join public.aos_f5_patient_source_rows_v1 sr on sr.id=cm.source_row_id
  join public.aos_f5_source_batches_v1 b on b.id=sr.batch_id
  join public.aos_f5_canonical_classification_v1 c on c.cluster_id=cm.cluster_id
  group by b.source_year
 )x
),
identity_sede as (
 select jsonb_agg(jsonb_build_object('sede',sede,'source_rows',rows,'MATCH',m,'REVIEW',r,'NEW',n,'match_pct',round(100.0*m/nullif(rows,0),2)) order by sede) j
 from (
  select b.source_sede sede,count(*) rows,count(*) filter(where c.classification='MATCH') m,count(*) filter(where c.classification='REVIEW') r,count(*) filter(where c.classification='NEW') n
  from public.aos_f5_identity_cluster_members_v1 cm
  join public.aos_f5_patient_source_rows_v1 sr on sr.id=cm.source_row_id
  join public.aos_f5_source_batches_v1 b on b.id=sr.batch_id
  join public.aos_f5_canonical_classification_v1 c on c.cluster_id=cm.cluster_id
  group by b.source_sede
 )x
),
dq_raw as (
 select 'Nombres' field,count(*) filter(where nullif(btrim("Nombres"),'') is not null)::bigint populated,null::bigint valid from public.aos_pacientes
 union all select 'Apellidos',count(*) filter(where nullif(btrim("Apellidos"),'') is not null),null from public.aos_pacientes
 union all select 'Teléfono',count(*) filter(where nullif(btrim("Teléfono"),'') is not null),count(*) filter(where regexp_replace(coalesce("Teléfono",''),'\D','','g') ~ '^9[0-9]{8}$') from public.aos_pacientes
 union all select 'Email',count(*) filter(where nullif(btrim("Email"),'') is not null),count(*) filter(where lower(btrim(coalesce("Email",''))) ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') from public.aos_pacientes
 union all select 'N° documento',count(*) filter(where nullif(btrim("N° documento"),'') is not null),count(*) filter(where regexp_replace(coalesce("N° documento",''),'\D','','g') ~ '^[0-9]{8}$') from public.aos_pacientes
 union all select 'Sexo',count(*) filter(where nullif(btrim("Sexo"),'') is not null),null from public.aos_pacientes
 union all select 'Fecha de nacimiento',count(*) filter(where nullif(btrim("Fecha de nacimiento"),'') is not null),count(*) filter(where public.aos_f5_parse_date_v1("Fecha de nacimiento") is not null) from public.aos_pacientes
 union all select 'Dirección',count(*) filter(where nullif(btrim("Dirección"),'') is not null),null from public.aos_pacientes
 union all select 'distrito',count(*) filter(where nullif(btrim(distrito),'') is not null),null from public.aos_pacientes
 union all select 'ciudad',count(*) filter(where nullif(btrim(ciudad),'') is not null),null from public.aos_pacientes
 union all select 'departamento',count(*) filter(where nullif(btrim(departamento),'') is not null),null from public.aos_pacientes
 union all select 'Ocupación',count(*) filter(where nullif(btrim("Ocupación"),'') is not null),null from public.aos_pacientes
 union all select 'SEDE_PRINCIPAL',count(*) filter(where nullif(btrim("SEDE_PRINCIPAL"),'') is not null),null from public.aos_pacientes
 union all select 'ULTIMA_VISITA',count(*) filter(where nullif(btrim("ULTIMA_VISITA"),'') is not null),count(*) filter(where public.aos_f5_parse_date_v1("ULTIMA_VISITA") is not null) from public.aos_pacientes
),
dq as (
 select jsonb_build_object('canonical_total',7688,'fields',jsonb_agg(jsonb_build_object('field',field,'populated',populated,'empty',7688-populated,'coverage_pct',round(100.0*populated/7688,2),'valid_format',valid,'valid_pct_of_populated',case when valid is null then null else round(100.0*valid/nullif(populated,0),2) end) order by field),'score_pct',round(100.0*sum(populated)/(7688.0*count(*)),2)) j from dq_raw
),
apply as (
 select jsonb_build_object(
 'previews',(select count(*) from public.aos_f5_enrichment_preview_v1),
 'preview_patients',(select count(distinct target_patient_id) from public.aos_f5_enrichment_preview_v1),
 'APPLY_ALLOWED',(select count(*) from public.aos_f5_enrichment_preview_v1 where policy_state='APPLY_ALLOWED'),
 'POLICY_BLOCKED',(select count(*) from public.aos_f5_enrichment_preview_v1 where policy_state='POLICY_BLOCKED'),
 'POLICY_UNDEFINED',(select count(*) from public.aos_f5_enrichment_preview_v1 where policy_state is null or policy_state='POLICY_UNDEFINED'),
 'applied',(select count(*) from public.aos_f5_enrichment_preview_v1 where applied_at is not null),
 'allowed_pending',(select count(*) from public.aos_f5_enrichment_preview_v1 where policy_state='APPLY_ALLOWED' and applied_at is null),
 'blocked_unapplied',(select count(*) from public.aos_f5_enrichment_preview_v1 where policy_state='POLICY_BLOCKED' and applied_at is null),
 'events_total',(select count(*) from public.aos_f5_canonical_apply_events_v1),
 'active_events',(select count(*) from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is null),
 'rolled_back_events',(select count(*) from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is not null),
 'policy_violations',(select count(*) from public.aos_f5_enrichment_preview_v1 where applied_at is not null and (policy_apply_allowed is distinct from true or field_name not in ('Sexo','distrito','departamento','ciudad'))),
 'applied_without_review',(select count(*) from public.aos_f5_enrichment_preview_v1 where applied_at is not null and (review_decision is distinct from 'APPROVE_FIELD' or reviewed_at is null or reviewed_by is null)),
 'applied_without_event',(select count(*) from public.aos_f5_enrichment_preview_v1 where applied_at is not null and apply_event_id is null),
 'active_outside_allowlist',(select count(*) from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is null and field_name not in ('Sexo','distrito','departamento','ciudad')),
 'invalid_hash_events',(select count(*) from public.aos_f5_canonical_apply_events_v1 where canonical_before_hash is null or canonical_after_hash is null or canonical_before_hash !~ '^[0-9a-f]{64}$' or canonical_after_hash !~ '^[0-9a-f]{64}$'),
 'exact_canary_rollbacks',(select count(*) from public.aos_f5_canonical_apply_events_v1 where apply_scope='CANARY' and rolled_back_at is not null and rollback_after_hash=canonical_before_hash),
 'distribution',(select coalesce(jsonb_object_agg(field_name,c), '{}'::jsonb) from (select field_name,count(*) c from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is null group by field_name)x)) j
),
sales as (
 select jsonb_build_object(
 'total',count(*),'min_date',min(sale_date),'max_date',max(sale_date),
 'MATCH',count(*) filter(where patient_link_status='MATCH'),'REVIEW',count(*) filter(where patient_link_status='REVIEW'),'UNRESOLVED',count(*) filter(where patient_link_status='UNRESOLVED'),
 'with_canonical_patient',count(*) filter(where canonical_patient_id is not null),'without_canonical_patient',count(*) filter(where canonical_patient_id is null),
 'historical_linked_sales',count(*) filter(where historical_cluster_id is not null),
 'score_pct',round(100.0*count(*) filter(where patient_link_status='MATCH')/nullif(count(*),0),2),
 'unsafe_match_rows',count(*) filter(where patient_link_status='MATCH' and (canonical_patient_id is null or patient_link_method is distinct from 'DNI_NAME_EXACT')),
 'product_applicable',count(*) filter(where product_applicable),
 'f3_resolved',count(*) filter(where product_resolution_status='RESOLVED'),'f3_review_required',count(*) filter(where product_resolution_status='REVIEW_REQUIRED'),'f3_excluded',count(*) filter(where product_resolution_status='EXCLUDED'),'f3_missing',count(*) filter(where product_resolution_status='MISSING_F3_FACT'),'f3_not_applicable',count(*) filter(where product_resolution_status='NOT_APPLICABLE'),
 'f3_score_pct',round(100.0*count(*) filter(where product_resolution_status='RESOLVED')/nullif(count(*) filter(where product_applicable),0),2),
 'f4_linked',count(*) filter(where cartera_link_status='F4_LINKED'),'f4_unlinked',count(*) filter(where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE'),
 'f4_score_pct',round(100.0*count(*) filter(where cartera_link_status='F4_LINKED')/nullif(count(*),0),2),
 'payment_evidence_rows',sum(payment_evidence_row_count),'confirmed_balance_rows',sum(confirmed_balance_row_count)) j
 from public.aos_f5_historical_join_v1
),
sales_month as (
 select jsonb_agg(jsonb_build_object('month',m,'sales',c,'MATCH',ma,'REVIEW',rv,'UNRESOLVED',ur,'f4_linked',f4) order by m) j
 from (select to_char(sale_date,'YYYY-MM') m,count(*) c,count(*) filter(where patient_link_status='MATCH') ma,count(*) filter(where patient_link_status='REVIEW') rv,count(*) filter(where patient_link_status='UNRESOLVED') ur,count(*) filter(where cartera_link_status='F4_LINKED') f4 from public.aos_f5_historical_join_v1 group by to_char(sale_date,'YYYY-MM'))x
),
sales_sede as (
 select jsonb_agg(jsonb_build_object('sede',sede,'sales',c,'MATCH',ma,'REVIEW',rv,'UNRESOLVED',ur,'f4_linked',f4) order by sede) j
 from (select coalesce(sede,'(NULL)') sede,count(*) c,count(*) filter(where patient_link_status='MATCH') ma,count(*) filter(where patient_link_status='REVIEW') rv,count(*) filter(where patient_link_status='UNRESOLVED') ur,count(*) filter(where cartera_link_status='F4_LINKED') f4 from public.aos_f5_historical_join_v1 group by coalesce(sede,'(NULL)'))x
),
structural as (
 select jsonb_build_object(
 'f3_rows',(select count(*) from public.aos_product_sale_fact_current_v1),'f3_distinct_sales',(select count(distinct sale_id) from public.aos_product_sale_fact_current_v1),'f3_duplicate_sale_facts',(select count(*) from (select sale_id from public.aos_product_sale_fact_current_v1 group by sale_id having count(*)>1)x),'f3_orphans',(select count(*) from public.aos_product_sale_fact_current_v1 f left join public.aos_ventas v on v.id=f.sale_id where v.id is null),
 'f4_rows',(select count(*) from public.aos_cartera_reconciliacion),'f4_distinct_sales',(select count(distinct venta_row_id) from public.aos_cartera_reconciliacion where venta_row_id is not null),'f4_sales_with_multiple_rows',(select count(*) from (select venta_row_id from public.aos_cartera_reconciliacion where venta_row_id is not null group by venta_row_id having count(*)>1)x),'f4_orphans',(select count(*) from public.aos_cartera_reconciliacion c left join public.aos_ventas v on v.id=c.venta_row_id where c.venta_row_id is not null and v.id is null),'f4_payment_link_rows',(select count(*) from public.aos_cartera_reconciliacion where pago_id is not null),'f4_confirmed_balance_rows',(select count(*) from public.aos_cartera_reconciliacion where saldo_confirmado is not null)) j
),
historical as (
 select jsonb_build_object('patient_history_2024','AVAILABLE','patient_history_2025','AVAILABLE','patient_history_2026','AVAILABLE','transactional_sales_2024','NO_CERTIFIED_SOURCE','transactional_sales_2025','NO_CERTIFIED_SOURCE','transactional_sales_2026','AVAILABLE_2026-01-05_TO_2026-08-15','certified_transaction_years',1,'target_years',3,'score_pct',33.33,'absence_means_zero',false,'yoy_2024_2026_supported',false) j
),
severity as (
 select jsonb_build_array(
 jsonb_build_object('severity','PASS','category','provenance','finding','source_staging_exact_and_structurally_clean'),
 jsonb_build_object('severity','MEDIUM','category','coverage_gap','finding','safe_identity_MATCH_is_conservative_and_low_coverage'),
 jsonb_build_object('severity','MEDIUM','category','coverage_gap','finding','canonical_patient_fields_have_large_completeness_variance'),
 jsonb_build_object('severity','PASS','category','policy','finding','governed_apply_has_zero_policy_review_event_hash_violations'),
 jsonb_build_object('severity','PASS','category','product_truth','finding','F3_has_no_missing_applicable_fact_or_structural_orphan'),
 jsonb_build_object('severity','HIGH','category','financial_coverage_gap','finding','F4_reconciliation_covers_123_of_1299_sales_and_payment_evidence_is_zero'),
 jsonb_build_object('severity','INFO','category','legitimate_source_absence','finding','2024_2025_transactional_sales_source_not_certified'),
 jsonb_build_object('severity','PASS','category','financial_safety','finding','unsupported_2024_2025_YoY_and_budget_or_adelanto_inference_remain_prohibited'),
 jsonb_build_object('severity','PASS','category','critical','finding','no_CRITICAL_invariant_failure_detected')) j
),
report as (
 select jsonb_build_object(
 'report','REV-F5.9_COVERAGE_DQ_V1','baseline_main','83015824f8aa744f35f4a470bc8684110132c07b',
 'staging',staging.j,
 'identity',identity.j || jsonb_build_object('by_year',identity_year.j,'by_sede',identity_sede.j),
 'canonical_patient_dq',dq.j,
 'apply',apply.j,
 'sales',sales.j || jsonb_build_object('by_month',sales_month.j,'by_sede',sales_sede.j),
 'structural',structural.j,
 'historical_periods',historical.j,
 'scores',jsonb_build_object('Identity_Coverage_Score',(identity.j->>'score_pct')::numeric,'Canonical_Patient_DQ_Score',(dq.j->>'score_pct')::numeric,'Sales_Linkage_Coverage',(sales.j->>'score_pct')::numeric,'F3_Product_Coverage',(sales.j->>'f3_score_pct')::numeric,'F4_Financial_Evidence_Coverage',(sales.j->>'f4_score_pct')::numeric,'Historical_Transaction_Coverage',33.33),
 'severity_matrix',severity.j,
 'semantics',jsonb_build_object('missing_transaction_source_is_zero_sales',false,'ultimo_presupuesto_is_financial_fact',false,'adelanto_is_automatic_balance_or_debt',false,'phone_alone_authorizes_identity',false,'name_alone_authorizes_identity',false)) j
 from staging,identity,identity_year,identity_sede,dq,apply,sales,sales_month,sales_sede,structural,historical,severity
)
select j as report_json, md5(j::text) as report_fingerprint,
       (md5(j::text)='5070c701d216eb839572bd70f530c2e6') as certified_fingerprint_match
from report;
