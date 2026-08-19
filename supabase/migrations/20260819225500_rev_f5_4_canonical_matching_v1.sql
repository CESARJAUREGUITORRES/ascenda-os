-- REV-F5.4 — conservative canonical matching classifier v1
-- Preview-only. No canonical patient mutation and no Apply.

create or replace function public.aos_f5_classify_canonical_matches_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_source_rows bigint;
  v_members bigint;
  v_clusters bigint;
  v_match bigint;
  v_review bigint;
  v_new bigint;
  v_reclassified bigint;
  v_apply bigint;
  v_canon_before bigint;
  v_canon_after bigint;
  v_fp_before text;
  v_fp_after text;
begin
  select count(*) into v_source_rows from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;

  if v_source_rows=0 or v_members<>v_source_rows then
    raise exception 'F5_4_MEMBERSHIP_COVERAGE_INVALID';
  end if;
  if (select count(*) from public.aos_f5_patient_link_preview_v1)<>v_clusters then
    raise exception 'F5_4_PREVIEW_COVERAGE_INVALID';
  end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where reviewed_at is not null or applied_at is not null) then
    raise exception 'F5_4_PREVIEW_ALREADY_REVIEWED_OR_APPLIED';
  end if;
  select count(*) into v_apply from public.aos_f5_canonical_apply_events_v1;
  if v_apply<>0 then raise exception 'F5_4_APPLY_EVENTS_PRESENT'; end if;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_before,v_fp_before
  from public.aos_pacientes p;

  drop table if exists pg_temp.tmp_f5_4_classification;
  create temporary table tmp_f5_4_classification on commit drop as
  with src as (
    select lp.cluster_id,lp.target_patient_id,
           coalesce(lp.evidence->>'f5_4_original_match_status',lp.match_status) original_status,
           nullif(c.canonical_preview->>'document_key','') s_doc,
           nullif(c.canonical_preview->>'email_key','') s_email,
           nullif(c.canonical_preview->>'birth_date','') s_dob,
           upper(nullif(btrim(c.canonical_preview->>'sex'),'')) s_sex,
           p."ID_PACIENTE" live_patient_id,
           (public.aos_f5_norm_doc_v1(p."N° documento")->>'key') c_doc,
           (public.aos_f5_norm_email_v1(p."Email")->>'key') c_email,
           public.aos_f5_parse_date_v1(p."Fecha de nacimiento")::text c_dob,
           upper(nullif(btrim(p."Sexo"),'')) c_sex
    from public.aos_f5_patient_link_preview_v1 lp
    join public.aos_f5_identity_clusters_v1 c on c.id=lp.cluster_id
    left join public.aos_pacientes p on p."ID_PACIENTE"=lp.target_patient_id
  ), flags as (
    select *,
      (s_doc is not null and c_doc is not null and s_doc<>c_doc) doc_conflict,
      (s_email is not null and c_email is not null and s_email<>c_email) email_conflict,
      (s_dob is not null and c_dob is not null and s_dob<>c_dob) dob_conflict,
      (s_sex is not null and c_sex is not null and s_sex<>c_sex) sex_conflict,
      (target_patient_id is not null and live_patient_id is null) target_missing
    from src
  )
  select *,
    (doc_conflict or email_conflict or dob_conflict or sex_conflict or target_missing) canonical_conflict_any,
    case
      when original_status='UNMATCHED' and target_patient_id is null then 'NEW'
      when original_status='AUTO_CANDIDATE'
       and target_patient_id is not null
       and not (doc_conflict or email_conflict or dob_conflict or sex_conflict or target_missing)
        then 'MATCH'
      else 'REVIEW'
    end operational_classification,
    case
      when original_status='UNMATCHED' and target_patient_id is null then 'NO_CANONICAL_CANDIDATE'
      when target_missing then 'TARGET_NOT_FOUND_CURRENT'
      when doc_conflict or email_conflict or dob_conflict or sex_conflict then 'CANONICAL_STRONG_FIELD_CONFLICT'
      when original_status='AUTO_CANDIDATE' then 'STRONG_EVIDENCE_COMPATIBLE'
      else 'AMBIGUOUS_OR_INSUFFICIENT_EVIDENCE'
    end classification_reason
  from flags;

  update public.aos_f5_patient_link_preview_v1 lp
  set match_status=case t.operational_classification
        when 'MATCH' then 'AUTO_CANDIDATE'
        when 'NEW' then 'UNMATCHED'
        else 'REVIEW_REQUIRED' end,
      evidence=lp.evidence||jsonb_build_object(
        'f5_4_original_match_status',t.original_status,
        'f5_4_classification',t.operational_classification,
        'f5_4_reason',t.classification_reason,
        'f5_4_version','v1'),
      conflicts=lp.conflicts||jsonb_build_object(
        'CANONICAL_DNI_CONFLICT',t.doc_conflict,
        'CANONICAL_EMAIL_CONFLICT',t.email_conflict,
        'CANONICAL_DOB_CONFLICT',t.dob_conflict,
        'CANONICAL_SEX_CONFLICT',t.sex_conflict,
        'CANONICAL_TARGET_MISSING',t.target_missing,
        'CANONICAL_CONFLICT_ANY',t.canonical_conflict_any),
      requires_human=true,
      updated_at=now()
  from tmp_f5_4_classification t
  where t.cluster_id=lp.cluster_id;

  update public.aos_f5_identity_clusters_v1 c
  set status=case
      when lp.match_status='AUTO_CANDIDATE' then 'READY_TO_LINK'
      when lp.match_status='UNMATCHED' then 'NEW_CANDIDATE'
      else 'REVIEW_REQUIRED' end,
      updated_at=now()
  from public.aos_f5_patient_link_preview_v1 lp
  where lp.cluster_id=c.id;

  select count(*) filter(where operational_classification='MATCH'),
         count(*) filter(where operational_classification='REVIEW'),
         count(*) filter(where operational_classification='NEW'),
         count(*) filter(where original_status='AUTO_CANDIDATE' and operational_classification='REVIEW')
    into v_match,v_review,v_new,v_reclassified
  from tmp_f5_4_classification;

  if v_match+v_review+v_new<>v_clusters then raise exception 'F5_4_CLASSIFICATION_COVERAGE_INVALID'; end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where evidence->>'f5_4_classification'='MATCH' and target_patient_id is null) then
    raise exception 'F5_4_MATCH_WITHOUT_TARGET';
  end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where evidence->>'f5_4_classification'='NEW' and target_patient_id is not null) then
    raise exception 'F5_4_NEW_WITH_TARGET';
  end if;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_after,v_fp_after
  from public.aos_pacientes p;
  if v_canon_after<>v_canon_before or v_fp_after is distinct from v_fp_before then
    raise exception 'F5_4_CANONICAL_MUTATION_DETECTED';
  end if;
  if (select count(*) from public.aos_f5_canonical_apply_events_v1)<>0 then
    raise exception 'F5_4_APPLY_EVENT_CREATED';
  end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('CANONICAL_MATCHING_CLASSIFIED','F5','REV-F5.4',jsonb_build_object(
    'clusters',v_clusters,'source_rows',v_source_rows,'members',v_members,
    'match',v_match,'review',v_review,'new',v_new,
    'unsafe_auto_reclassified',v_reclassified,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,
    'canonical_mutation',false,'apply_events',0));

  return jsonb_build_object(
    'ok',true,'source_rows',v_source_rows,'members',v_members,'clusters',v_clusters,
    'match',v_match,'review',v_review,'new',v_new,
    'unsafe_auto_reclassified',v_reclassified,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,
    'canonical_mutation',false,'apply_events',0);
end
$$;

revoke all on function public.aos_f5_classify_canonical_matches_v1() from public,anon,authenticated;
grant execute on function public.aos_f5_classify_canonical_matches_v1() to service_role;
