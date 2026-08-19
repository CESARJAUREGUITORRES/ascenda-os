-- ASCENDA OS — REV-F5.5 Enrichment Preview v1
-- Scope: preview-only, MATCH-only, fill-only. Never mutates public.aos_pacientes.

create table if not exists public.aos_f5_enrichment_preview_v1 (
  cluster_id uuid not null references public.aos_f5_identity_clusters_v1(id) on delete cascade,
  target_patient_id text not null,
  field_name text not null check (field_name in (
    'Email','N° documento','Sexo','Fecha de nacimiento','Dirección','Ocupación','distrito','departamento','ciudad'
  )),
  proposed_value text not null,
  source_evidence_rows integer not null check (source_evidence_rows > 0),
  source_distinct_values integer not null check (source_distinct_values = 1),
  source_row_ids bigint[] not null,
  policy_state text not null check (policy_state in ('APPLY_ALLOWED','POLICY_BLOCKED','POLICY_UNDEFINED')),
  policy_risk_class text,
  policy_apply_allowed boolean not null default false,
  apply_eligible boolean not null default false check (apply_eligible is false),
  requires_human boolean not null default true check (requires_human is true),
  canonical_empty boolean not null default true check (canonical_empty is true),
  generated_at timestamptz not null default now(),
  primary key(cluster_id,field_name)
);

alter table public.aos_f5_enrichment_preview_v1 enable row level security;
revoke all on table public.aos_f5_enrichment_preview_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_f5_enrichment_preview_v1 to service_role;

comment on table public.aos_f5_enrichment_preview_v1 is
  'REV-F5.5 private fill-only enrichment preview for REV-F5.4 MATCH identities. F5.5 never authorizes Apply.';

create or replace function public.aos_f5_build_enrichment_preview_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_source_rows bigint;
  v_members bigint;
  v_clusters bigint;
  v_classifications bigint;
  v_match bigint;
  v_review bigint;
  v_new bigint;
  v_expected_proposals bigint;
  v_proposals bigint;
  v_patients bigint;
  v_policy_allowed bigint;
  v_policy_blocked bigint;
  v_policy_undefined bigint;
  v_canon_before bigint;
  v_canon_after bigint;
  v_fp_before text;
  v_fp_after text;
  v_preview_fp text;
begin
  select count(*) into v_source_rows from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  select count(*),
         count(*) filter(where classification='MATCH'),
         count(*) filter(where classification='REVIEW'),
         count(*) filter(where classification='NEW')
    into v_classifications,v_match,v_review,v_new
  from public.aos_f5_canonical_classification_v1;

  if v_source_rows=0 or v_members<>v_source_rows then
    raise exception 'F5_5_MEMBERSHIP_COVERAGE_INVALID';
  end if;
  if v_classifications<>v_clusters or v_match+v_review+v_new<>v_clusters then
    raise exception 'F5_5_CLASSIFICATION_COVERAGE_INVALID';
  end if;
  if exists(
    select 1 from public.aos_f5_canonical_classification_v1
    where classification='MATCH' and (
      target_patient_id is null or canonical_dni_conflict or canonical_email_conflict or
      canonical_dob_conflict or canonical_sex_conflict or target_missing or
      target_collision or source_strong_conflict
    )
  ) then raise exception 'F5_5_UNSAFE_MATCH_PRESENT'; end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where reviewed_at is not null or applied_at is not null) then
    raise exception 'F5_5_REVIEW_OR_APPLY_ALREADY_PRESENT';
  end if;
  if (select count(*) from public.aos_f5_canonical_apply_events_v1)<>0 then
    raise exception 'F5_5_APPLY_EVENTS_PRESENT';
  end if;

  -- Use the exact canonical fingerprint contract introduced in REV-F5.4.
  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_before,v_fp_before
  from public.aos_pacientes p;

  -- The pre-existing F5.3 proposed_patch is reused as the established semantic mapping.
  -- Fail closed if a future patch introduces a field outside that approved preview mapping.
  if exists(
    select 1
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_patient_link_preview_v1 lp on lp.cluster_id=c.cluster_id
    cross join lateral jsonb_each_text(lp.proposed_patch) j
    where c.classification='MATCH'
      and j.key not in ('Email','N° documento','Sexo','Fecha de nacimiento','Dirección','Ocupación','distrito','departamento','ciudad')
  ) then raise exception 'F5_5_UNAPPROVED_PREVIEW_FIELD'; end if;

  select count(*) into v_expected_proposals
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_patient_link_preview_v1 lp on lp.cluster_id=c.cluster_id
  cross join lateral jsonb_each_text(lp.proposed_patch) j
  where c.classification='MATCH';

  truncate table public.aos_f5_enrichment_preview_v1;

  insert into public.aos_f5_enrichment_preview_v1(
    cluster_id,target_patient_id,field_name,proposed_value,
    source_evidence_rows,source_distinct_values,source_row_ids,
    policy_state,policy_risk_class,policy_apply_allowed,
    apply_eligible,requires_human,canonical_empty,generated_at
  )
  with proposals as (
    select c.cluster_id,c.target_patient_id,j.key field_name,j.value proposed_value,
      case j.key
        when 'Email' then nullif(btrim(p."Email"),'') is null
        when 'N° documento' then nullif(btrim(p."N° documento"),'') is null
        when 'Sexo' then nullif(btrim(p."Sexo"),'') is null
        when 'Fecha de nacimiento' then nullif(btrim(p."Fecha de nacimiento"),'') is null
        when 'Dirección' then nullif(btrim(p."Dirección"),'') is null
        when 'Ocupación' then nullif(btrim(p."Ocupación"),'') is null
        when 'distrito' then nullif(btrim(p.distrito),'') is null
        when 'departamento' then nullif(btrim(p.departamento),'') is null
        when 'ciudad' then nullif(btrim(p.ciudad),'') is null
        else false
      end canonical_empty
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_patient_link_preview_v1 lp on lp.cluster_id=c.cluster_id
    join public.aos_pacientes p on p."ID_PACIENTE"=c.target_patient_id
    cross join lateral jsonb_each_text(lp.proposed_patch) j
    where c.classification='MATCH'
  ), all_evidence as (
    select c.cluster_id,r.id source_row_id,'Email'::text field_name,r.email_key evidence_value
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.email_key is not null
    union all
    select c.cluster_id,r.id,'N° documento',r.document_key
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.document_type='DNI8' and r.document_key is not null
    union all
    select c.cluster_id,r.id,'Sexo',upper(btrim(r.sex_raw))
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and nullif(btrim(r.sex_raw),'') is not null
    union all
    select c.cluster_id,r.id,'Fecha de nacimiento',r.birth_date::text
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.birth_date is not null and r.birth_quality='VALID'
    union all
    select c.cluster_id,r.id,'Dirección',btrim(r.address_raw)
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and nullif(btrim(r.address_raw),'') is not null
    union all
    select c.cluster_id,r.id,'Ocupación',btrim(r.occupation)
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and nullif(btrim(r.occupation),'') is not null
    union all
    select c.cluster_id,r.id,'distrito',btrim(r.district)
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.address_parse_status='PARSED_RIGHT' and nullif(btrim(r.district),'') is not null
    union all
    select c.cluster_id,r.id,'departamento',btrim(r.department)
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.address_parse_status='PARSED_RIGHT' and nullif(btrim(r.department),'') is not null
    union all
    select c.cluster_id,r.id,'ciudad',btrim(r.province)
    from public.aos_f5_canonical_classification_v1 c
    join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
    join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
    where c.classification='MATCH' and r.address_parse_status='PARSED_RIGHT' and nullif(btrim(r.province),'') is not null
  ), stats as (
    select cluster_id,field_name,
      count(*)::integer source_evidence_rows,
      count(distinct evidence_value)::integer source_distinct_values,
      array_agg(source_row_id order by source_row_id) source_row_ids
    from all_evidence
    group by cluster_id,field_name
  )
  select p.cluster_id,p.target_patient_id,p.field_name,p.proposed_value,
         s.source_evidence_rows,s.source_distinct_values,s.source_row_ids,
         case
           when fp.field_name is null then 'POLICY_UNDEFINED'
           when fp.apply_allowed then 'APPLY_ALLOWED'
           else 'POLICY_BLOCKED'
         end,
         fp.risk_class,coalesce(fp.apply_allowed,false),
         false,true,true,now()
  from proposals p
  join stats s on s.cluster_id=p.cluster_id and s.field_name=p.field_name
  left join public.aos_f5_apply_field_policy_v1 fp on fp.field_name=p.field_name
  where p.canonical_empty is true
    and nullif(btrim(p.proposed_value),'') is not null
    and s.source_distinct_values=1;

  select count(*),count(distinct target_patient_id),
         count(*) filter(where policy_state='APPLY_ALLOWED'),
         count(*) filter(where policy_state='POLICY_BLOCKED'),
         count(*) filter(where policy_state='POLICY_UNDEFINED')
    into v_proposals,v_patients,v_policy_allowed,v_policy_blocked,v_policy_undefined
  from public.aos_f5_enrichment_preview_v1;

  -- Every existing MATCH proposed_patch item must survive the stricter F5.5 gates.
  if v_proposals<>v_expected_proposals then
    raise exception 'F5_5_PROPOSAL_DROPPED_BY_SAFETY_GATE expected=% actual=%',v_expected_proposals,v_proposals;
  end if;
  if exists(
    select 1 from public.aos_f5_enrichment_preview_v1 e
    join public.aos_f5_canonical_classification_v1 c on c.cluster_id=e.cluster_id
    where c.classification<>'MATCH' or c.target_patient_id is distinct from e.target_patient_id
  ) then raise exception 'F5_5_NON_MATCH_PREVIEW_PRESENT'; end if;
  if exists(select 1 from public.aos_f5_enrichment_preview_v1 where apply_eligible or not requires_human or not canonical_empty) then
    raise exception 'F5_5_APPLY_BOUNDARY_BROKEN';
  end if;
  if exists(select 1 from public.aos_f5_enrichment_preview_v1 where source_distinct_values<>1 or cardinality(source_row_ids)=0) then
    raise exception 'F5_5_PROVENANCE_INVALID';
  end if;

  select md5(string_agg(
    md5(concat_ws('|',cluster_id::text,target_patient_id,field_name,proposed_value,
      source_evidence_rows::text,source_distinct_values::text,array_to_string(source_row_ids,','),
      policy_state,coalesce(policy_risk_class,''),policy_apply_allowed::text,
      apply_eligible::text,requires_human::text,canonical_empty::text)),
    ',' order by cluster_id,field_name))
    into v_preview_fp
  from public.aos_f5_enrichment_preview_v1;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_after,v_fp_after
  from public.aos_pacientes p;
  if v_canon_after<>v_canon_before or v_fp_after is distinct from v_fp_before then
    raise exception 'F5_5_CANONICAL_MUTATION_DETECTED';
  end if;
  if (select count(*) from public.aos_f5_canonical_apply_events_v1)<>0 then
    raise exception 'F5_5_APPLY_EVENT_CREATED';
  end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('ENRICHMENT_PREVIEW_BUILT','F5','REV-F5.5',jsonb_build_object(
    'source_rows',v_source_rows,'members',v_members,'clusters',v_clusters,
    'match',v_match,'review',v_review,'new',v_new,
    'proposal_fields',v_proposals,'patients_with_proposal',v_patients,
    'policy_allowed_fields',v_policy_allowed,'policy_blocked_fields',v_policy_blocked,
    'policy_undefined_fields',v_policy_undefined,
    'preview_fingerprint',v_preview_fp,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,
    'canonical_mutation',false,'apply_events',0,'apply_eligible',false));

  return jsonb_build_object(
    'ok',true,'source_rows',v_source_rows,'members',v_members,'clusters',v_clusters,
    'match',v_match,'review',v_review,'new',v_new,
    'proposal_fields',v_proposals,'patients_with_proposal',v_patients,
    'policy_allowed_fields',v_policy_allowed,'policy_blocked_fields',v_policy_blocked,
    'policy_undefined_fields',v_policy_undefined,
    'preview_fingerprint',v_preview_fp,
    'canonical_patient_count',v_canon_after,'canonical_fingerprint',v_fp_after,
    'canonical_mutation',false,'apply_events',0,'apply_eligible',false);
end
$$;

revoke all on function public.aos_f5_build_enrichment_preview_v1() from public,anon,authenticated;
grant execute on function public.aos_f5_build_enrichment_preview_v1() to service_role;
