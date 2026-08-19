-- REV-F5.4 — lightweight, preview-only canonical classification.
create table if not exists public.aos_f5_canonical_classification_v1 (
  cluster_id uuid primary key references public.aos_f5_identity_clusters_v1(id) on delete cascade,
  target_patient_id text null,
  source_match_status text not null,
  classification text not null check (classification in ('MATCH','REVIEW','NEW')),
  reason text not null,
  match_method text null,
  match_score numeric null,
  canonical_dni_conflict boolean not null default false,
  canonical_email_conflict boolean not null default false,
  canonical_dob_conflict boolean not null default false,
  canonical_sex_conflict boolean not null default false,
  target_missing boolean not null default false,
  target_collision boolean not null default false,
  source_strong_conflict boolean not null default false,
  classified_at timestamptz not null default now()
);

revoke all on table public.aos_f5_canonical_classification_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_f5_canonical_classification_v1 to service_role;

create or replace function public.aos_f5_classify_canonical_matches_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_source_rows bigint; v_members bigint; v_clusters bigint;
  v_match bigint; v_review bigint; v_new bigint; v_reclassified bigint;
  v_canon_before bigint; v_canon_after bigint; v_fp_before text; v_fp_after text;
begin
  select count(*) into v_source_rows from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  if v_source_rows=0 or v_members<>v_source_rows then raise exception 'F5_4_MEMBERSHIP_COVERAGE_INVALID'; end if;
  if (select count(*) from public.aos_f5_patient_link_preview_v1)<>v_clusters then raise exception 'F5_4_PREVIEW_COVERAGE_INVALID'; end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where reviewed_at is not null or applied_at is not null) then raise exception 'F5_4_PREVIEW_ALREADY_REVIEWED_OR_APPLIED'; end if;
  if (select count(*) from public.aos_f5_canonical_apply_events_v1)<>0 then raise exception 'F5_4_APPLY_EVENTS_PRESENT'; end if;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_before,v_fp_before from public.aos_pacientes p;

  truncate table public.aos_f5_canonical_classification_v1;

  insert into public.aos_f5_canonical_classification_v1(
    cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score,
    canonical_dni_conflict,canonical_email_conflict,canonical_dob_conflict,canonical_sex_conflict,
    target_missing,target_collision,source_strong_conflict,classified_at)
  with target_counts as (
    select target_patient_id,count(*) n
    from public.aos_f5_patient_link_preview_v1
    where target_patient_id is not null
    group by target_patient_id
  ), x as (
    select lp.cluster_id,lp.target_patient_id,lp.match_status,lp.match_method,lp.match_score,
      (nullif(c.canonical_preview->>'document_key','') is not null and (public.aos_f5_norm_doc_v1(p."N° documento")->>'key') is not null and nullif(c.canonical_preview->>'document_key','')<>(public.aos_f5_norm_doc_v1(p."N° documento")->>'key')) dni_conflict,
      (nullif(c.canonical_preview->>'email_key','') is not null and (public.aos_f5_norm_email_v1(p."Email")->>'key') is not null and nullif(c.canonical_preview->>'email_key','')<>(public.aos_f5_norm_email_v1(p."Email")->>'key')) email_conflict,
      (nullif(c.canonical_preview->>'birth_date','') is not null and public.aos_f5_parse_date_v1(p."Fecha de nacimiento") is not null and nullif(c.canonical_preview->>'birth_date','')<>public.aos_f5_parse_date_v1(p."Fecha de nacimiento")::text) dob_conflict,
      (upper(nullif(btrim(c.canonical_preview->>'sex'),'')) is not null and upper(nullif(btrim(p."Sexo"),'')) is not null and upper(nullif(btrim(c.canonical_preview->>'sex'),''))<>upper(nullif(btrim(p."Sexo"),''))) sex_conflict,
      (lp.target_patient_id is not null and p."ID_PACIENTE" is null) target_missing,
      coalesce(tc.n,0)>1 target_collision,
      coalesce((c.conflicts->>'DNI_CONFLICT')::boolean,false) or coalesce((c.conflicts->>'DOB_CONFLICT')::boolean,false) or coalesce((c.conflicts->>'SEX_CONFLICT')::boolean,false) source_strong_conflict,
      coalesce((lp.conflicts->>'candidate_tie')::boolean,false) candidate_tie
    from public.aos_f5_patient_link_preview_v1 lp
    join public.aos_f5_identity_clusters_v1 c on c.id=lp.cluster_id
    left join public.aos_pacientes p on p."ID_PACIENTE"=lp.target_patient_id
    left join target_counts tc on tc.target_patient_id=lp.target_patient_id
  )
  select cluster_id,target_patient_id,match_status,
    case
      when match_status='UNMATCHED' and target_patient_id is null then 'NEW'
      when match_status='AUTO_CANDIDATE' and target_patient_id is not null
       and not(dni_conflict or email_conflict or dob_conflict or sex_conflict or target_missing or target_collision or source_strong_conflict or candidate_tie)
        then 'MATCH'
      else 'REVIEW'
    end,
    case
      when match_status='UNMATCHED' and target_patient_id is null then 'NO_CANONICAL_CANDIDATE'
      when target_missing then 'TARGET_NOT_FOUND_CURRENT'
      when source_strong_conflict then 'SOURCE_STRONG_IDENTIFIER_CONFLICT'
      when dni_conflict or email_conflict or dob_conflict or sex_conflict then 'CANONICAL_STRONG_FIELD_CONFLICT'
      when target_collision then 'CANONICAL_TARGET_COLLISION'
      when candidate_tie then 'CANDIDATE_TIE'
      when match_status='AUTO_CANDIDATE' then 'STRONG_EVIDENCE_COMPATIBLE'
      else 'AMBIGUOUS_OR_INSUFFICIENT_EVIDENCE'
    end,
    match_method,match_score,dni_conflict,email_conflict,dob_conflict,sex_conflict,
    target_missing,target_collision,source_strong_conflict,now()
  from x;

  select count(*) filter(where classification='MATCH'),count(*) filter(where classification='REVIEW'),count(*) filter(where classification='NEW'),
         count(*) filter(where source_match_status='AUTO_CANDIDATE' and classification='REVIEW')
    into v_match,v_review,v_new,v_reclassified
  from public.aos_f5_canonical_classification_v1;

  if v_match+v_review+v_new<>v_clusters then raise exception 'F5_4_CLASSIFICATION_COVERAGE_INVALID'; end if;
  if exists(select 1 from public.aos_f5_canonical_classification_v1 where classification='MATCH' and target_patient_id is null) then raise exception 'F5_4_MATCH_WITHOUT_TARGET'; end if;
  if exists(select 1 from public.aos_f5_canonical_classification_v1 where classification='NEW' and target_patient_id is not null) then raise exception 'F5_4_NEW_WITH_TARGET'; end if;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_after,v_fp_after from public.aos_pacientes p;
  if v_canon_after<>v_canon_before or v_fp_after is distinct from v_fp_before then raise exception 'F5_4_CANONICAL_MUTATION_DETECTED'; end if;
  if (select count(*) from public.aos_f5_canonical_apply_events_v1)<>0 then raise exception 'F5_4_APPLY_EVENT_CREATED'; end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('CANONICAL_MATCHING_CLASSIFIED','F5','REV-F5.4',jsonb_build_object(
    'clusters',v_clusters,'source_rows',v_source_rows,'members',v_members,
    'match',v_match,'review',v_review,'new',v_new,'unsafe_auto_reclassified',v_reclassified,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,'canonical_mutation',false,'apply_events',0));

  return jsonb_build_object('ok',true,'source_rows',v_source_rows,'members',v_members,'clusters',v_clusters,
    'match',v_match,'review',v_review,'new',v_new,'unsafe_auto_reclassified',v_reclassified,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,'canonical_mutation',false,'apply_events',0);
end
$$;

revoke all on function public.aos_f5_classify_canonical_matches_v1() from public,anon,authenticated;
grant execute on function public.aos_f5_classify_canonical_matches_v1() to service_role;
