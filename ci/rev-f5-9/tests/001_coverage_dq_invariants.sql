\set ON_ERROR_STOP on

-- Independent REV-F5.9 invariants.
-- This deliberately does not reuse the canonical report JSON builder.

do $$
begin
  if (select count(*) from public.aos_f5_source_batches_v1 where status='MATCHED' and source_rows=(select count(*) from public.aos_f5_patient_source_rows_v1 r where r.batch_id=aos_f5_source_batches_v1.id)) <> 6 then
    raise exception 'F5_9_BATCH_PARITY_FAIL';
  end if;

  if (select count(*) from public.aos_f5_patient_source_rows_v1) <> 15498
     or (select count(*) from public.aos_f5_identity_cluster_members_v1) <> 15498 then
    raise exception 'F5_9_SOURCE_MEMBERSHIP_COUNT_FAIL';
  end if;

  if exists(select 1 from public.aos_f5_identity_cluster_members_v1 group by source_row_id having count(*)<>1) then
    raise exception 'F5_9_MEMBER_MULTIPLICITY_FAIL';
  end if;

  if exists(select 1 from public.aos_f5_patient_source_rows_v1 r left join public.aos_f5_identity_cluster_members_v1 m on m.source_row_id=r.id where m.source_row_id is null)
     or exists(select 1 from public.aos_f5_identity_cluster_members_v1 m left join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id where r.id is null) then
    raise exception 'F5_9_MEMBER_ORPHAN_FAIL';
  end if;

  if (select count(*) from public.aos_f5_canonical_classification_v1) <> 8716 then
    raise exception 'F5_9_CLASSIFICATION_COUNT_FAIL';
  end if;

  if exists(
    select 1 from public.aos_f5_canonical_classification_v1
    where classification='MATCH'
      and (target_patient_id is null or target_missing or target_collision or source_strong_conflict or canonical_dni_conflict or canonical_email_conflict or canonical_dob_conflict or canonical_sex_conflict)
  ) then
    raise exception 'F5_9_UNSAFE_MATCH_FAIL';
  end if;

  if exists(
    select 1 from public.aos_f5_enrichment_preview_v1
    where applied_at is not null
      and (policy_apply_allowed is distinct from true or review_decision is distinct from 'APPROVE_FIELD' or apply_event_id is null)
  ) then
    raise exception 'F5_9_APPLY_GOVERNANCE_FAIL';
  end if;

  if exists(
    select 1
    from public.aos_f5_canonical_apply_events_v1 e
    left join public.aos_f5_enrichment_preview_v1 p on p.cluster_id=e.cluster_id and p.field_name=e.field_name
    where e.rolled_back_at is null and (p.apply_event_id is distinct from e.id or p.applied_at is null)
  ) then
    raise exception 'F5_9_EVENT_PREVIEW_MISMATCH';
  end if;

  if exists(
    select 1
    from public.aos_f5_canonical_apply_events_v1 e
    left join public.aos_pacientes p on p."ID_PACIENTE"=e.target_patient_id
    where e.rolled_back_at is null
      and (p."ID_PACIENTE" is null or coalesce(to_jsonb(p)->>e.field_name,'')<>coalesce(e.after_patch->>e.field_name,''))
  ) then
    raise exception 'F5_9_CURRENT_AFTER_MISMATCH';
  end if;

  if (select count(*) from public.aos_f5_historical_join_v1) <> 1299
     or (select count(distinct sale_id) from public.aos_f5_historical_join_v1) <> 1299 then
    raise exception 'F5_9_BRIDGE_COVERAGE_FAIL';
  end if;

  if exists(select 1 from public.aos_ventas v left join public.aos_f5_historical_join_v1 j on j.sale_id=v.id where j.sale_id is null)
     or exists(select 1 from public.aos_f5_historical_join_v1 j left join public.aos_ventas v on v.id=j.sale_id where v.id is null) then
    raise exception 'F5_9_BRIDGE_ORPHAN_FAIL';
  end if;

  if exists(select 1 from public.aos_f5_historical_join_v1 where patient_link_status='MATCH' and (canonical_patient_id is null or patient_link_method<>'DNI_NAME_EXACT')) then
    raise exception 'F5_9_UNSAFE_SALE_MATCH_FAIL';
  end if;

  if exists(select 1 from public.aos_f5_historical_join_v1 where product_applicable and product_resolution_status='MISSING_F3_FACT') then
    raise exception 'F5_9_MISSING_F3_FACT_FAIL';
  end if;

  if (select count(*) from public.aos_product_sale_fact_current_v1) <> 406
     or (select count(distinct sale_id) from public.aos_product_sale_fact_current_v1) <> 406
     or exists(select 1 from public.aos_product_sale_fact_current_v1 f left join public.aos_ventas v on v.id=f.sale_id where v.id is null) then
    raise exception 'F5_9_F3_STRUCTURAL_FAIL';
  end if;

  if (select count(*) from public.aos_cartera_reconciliacion) <> 162
     or (select count(distinct venta_row_id) from public.aos_cartera_reconciliacion where venta_row_id is not null) <> 123
     or exists(select 1 from public.aos_cartera_reconciliacion where venta_row_id is not null group by venta_row_id having count(*)>1)
     or exists(select 1 from public.aos_cartera_reconciliacion c left join public.aos_ventas v on v.id=c.venta_row_id where c.venta_row_id is not null and v.id is null) then
    raise exception 'F5_9_F4_STRUCTURAL_FAIL';
  end if;

  if (select count(*) from public.aos_pacientes) <> 7688
     or (select md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE")) from public.aos_pacientes p) <> 'eee5a57717937a4f77049b3aebd8c525' then
    raise exception 'F5_9_PATIENT_FINGERPRINT_DRIFT';
  end if;

  if (select count(*) from public.aos_ventas) <> 1299
     or (select md5(string_agg(md5(to_jsonb(v)::text),',' order by v.id)) from public.aos_ventas v) <> '20104fd91fbf427e39566e7b84d7ec4f' then
    raise exception 'F5_9_SALES_FINGERPRINT_DRIFT';
  end if;

  if (select md5(string_agg(md5(to_jsonb(f)::text),',' order by f.sale_id)) from public.aos_product_sale_fact_current_v1 f) <> 'e3c8499026d13401c4a733b4da16b6c8' then
    raise exception 'F5_9_F3_FINGERPRINT_DRIFT';
  end if;

  if (select md5(string_agg(md5(to_jsonb(c)::text),',' order by c.id)) from public.aos_cartera_reconciliacion c) <> '5524a2280442224ec4e9a7cfdfffa008' then
    raise exception 'F5_9_F4_FINGERPRINT_DRIFT';
  end if;
end
$$;

select 'PASS' as rev_f5_9_independent_invariants;
