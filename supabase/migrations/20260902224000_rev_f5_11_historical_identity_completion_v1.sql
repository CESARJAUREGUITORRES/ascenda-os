-- ASCENDA OS · REV-F5.11 Historical Patient Identity Completion V1
-- Scope: patient identity/provenance 2024-2026 only. No 2024/2025 sales ingestion.
-- Safety: never overwrites an existing canonical patient. New rows are limited to
-- deterministic HIGH-confidence historical identities with DNI8 + second signal.

begin;

create table if not exists public.aos_f5_historical_identity_resolution_v2 (
  cluster_id uuid primary key references public.aos_f5_identity_clusters_v1(id) on delete restrict,
  original_classification text not null,
  original_reason text not null,
  original_match_method text null,
  original_match_score numeric null,
  resolution_status text not null check (resolution_status in (
    'RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW','NEW_SAFE','NEW_CREATED','STALE_TARGET','REVIEW_REQUIRED'
  )),
  resolution_rule text not null,
  canonical_patient_id text null,
  proposed_patient_id text null,
  source_row_count integer not null,
  confidence text not null,
  attribute_review jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  preview_hash text not null,
  resolution_version text not null default 'REV-F5.11-V1',
  generated_at timestamptz not null default now(),
  applied_at timestamptz null
);

comment on table public.aos_f5_historical_identity_resolution_v2 is
'REV-F5.11 immutable completion snapshot over certified F5 source identity. Existing canonical patient rows are never overwritten; ambiguous identity remains REVIEW_REQUIRED.';

revoke all on table public.aos_f5_historical_identity_resolution_v2 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_f5_historical_identity_resolution_v2 to service_role;

create index if not exists idx_f5_hist_identity_resolution_v2_patient
  on public.aos_f5_historical_identity_resolution_v2(canonical_patient_id)
  where canonical_patient_id is not null;
create index if not exists idx_f5_hist_identity_resolution_v2_status
  on public.aos_f5_historical_identity_resolution_v2(resolution_status);

create or replace view public.aos_f5_historical_identity_completion_preview_v1 as
with current_alias_raw as (
  select 'PHONE'::text identifier_type,
         public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")) identifier_key,
         p."ID_PACIENTE"::text canonical_patient_id
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  union all
  select 'DOCUMENT',public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento"),p."ID_PACIENTE"::text
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  union all
  select 'EMAIL',public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email"),p."ID_PACIENTE"::text
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
), current_alias as (
  select identifier_type,identifier_key,min(canonical_patient_id) canonical_patient_id,
         count(distinct canonical_patient_id)::integer candidate_count
  from current_alias_raw
  where identifier_key is not null and identifier_key<>''
  group by identifier_type,identifier_key
), core as (
  select c.id cluster_id,c.status cluster_status,c.confidence,c.source_row_count,c.canonical_preview,c.evidence cluster_evidence,c.conflicts,
         cc.classification original_classification,cc.reason original_reason,cc.match_method original_match_method,cc.match_score original_match_score,
         cc.target_patient_id original_target_patient_id,
         cc.canonical_dni_conflict,cc.canonical_email_conflict,cc.canonical_dob_conflict,cc.canonical_sex_conflict,
         cc.source_strong_conflict,
         public.aos_f5_norm_name_v1(concat_ws(' ',c.canonical_preview->>'nombres',c.canonical_preview->>'apellidos')) source_name_key
  from public.aos_f5_identity_clusters_v1 c
  join public.aos_f5_canonical_classification_v1 cc on cc.cluster_id=c.id
), identifier_hits as (
  select c.cluster_id,a.identifier_type,a.canonical_patient_id,a.candidate_count
  from core c join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join current_alias a on a.identifier_type='DOCUMENT' and a.identifier_key=s.document_key and nullif(s.document_key,'') is not null
  union all
  select c.cluster_id,a.identifier_type,a.canonical_patient_id,a.candidate_count
  from core c join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join current_alias a on a.identifier_type='EMAIL' and a.identifier_key=s.email_key and nullif(s.email_key,'') is not null
  union all
  select c.cluster_id,a.identifier_type,a.canonical_patient_id,a.candidate_count
  from core c join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join current_alias a on a.identifier_type='PHONE' and a.identifier_key=s.phone_key and nullif(s.phone_key,'') is not null
), current_hit_agg as (
  select cluster_id,
         count(distinct canonical_patient_id) filter(where candidate_count=1)::integer current_target_count,
         min(canonical_patient_id) filter(where candidate_count=1) current_target,
         bool_or(identifier_type='DOCUMENT' and candidate_count=1) has_document,
         bool_or(identifier_type='EMAIL' and candidate_count=1) has_email,
         bool_or(identifier_type='PHONE' and candidate_count=1) has_phone,
         bool_or(candidate_count>1) has_current_key_conflict
  from identifier_hits group by cluster_id
), source_stats as (
  select c.cluster_id,
         count(distinct s.name_key) filter(where nullif(s.name_key,'') is not null)::integer distinct_names,
         count(distinct s.document_key) filter(where nullif(s.document_key,'') is not null)::integer distinct_documents,
         count(distinct s.document_key) filter(where nullif(s.document_key,'') is not null and s.document_type='DNI8')::integer distinct_dni8,
         count(distinct s.email_key) filter(where nullif(s.email_key,'') is not null)::integer distinct_emails,
         count(distinct s.phone_key) filter(where nullif(s.phone_key,'') is not null and s.phone_type='PERU_9')::integer distinct_peru_phones,
         count(distinct s.birth_date) filter(where s.birth_date is not null)::integer distinct_birth_dates,
         count(distinct upper(nullif(btrim(s.sex_raw),'')))::integer distinct_sexes,
         max(s.phone_key) filter(where nullif(s.phone_key,'') is not null and s.phone_type='PERU_9') proposed_phone,
         max(s.email_key) filter(where nullif(s.email_key,'') is not null) proposed_email,
         max(s.document_key) filter(where nullif(s.document_key,'') is not null and s.document_type='DNI8') proposed_document,
         min(s.source_created_date) filter(where s.source_created_date is not null) first_source_date,
         max(s.last_appointment) filter(where s.last_appointment is not null) last_source_appointment
  from core c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  group by c.cluster_id
), evaluated as (
  select c.*,coalesce(h.current_target_count,0) current_target_count,h.current_target,
         coalesce(h.has_document,false) has_document,coalesce(h.has_email,false) has_email,coalesce(h.has_phone,false) has_phone,
         coalesce(h.has_current_key_conflict,false) has_current_key_conflict,
         ss.*,
         po."ID_PACIENTE" old_current_patient_id,
         pc."ID_PACIENTE" current_candidate_patient_id,
         public.aos_f5_norm_name_v1(concat_ws(' ',pc."Nombres",pc."Apellidos")) current_candidate_name_key
  from core c
  join source_stats ss on ss.cluster_id=c.cluster_id
  left join current_hit_agg h on h.cluster_id=c.cluster_id
  left join public.aos_pacientes po on po."ID_PACIENTE"=c.original_target_patient_id and coalesce(po."ESTADO_PACIENTE",'')<>'FUSIONADO'
  left join public.aos_pacientes pc on pc."ID_PACIENTE"=h.current_target and coalesce(pc."ESTADO_PACIENTE",'')<>'FUSIONADO'
), decided as (
  select e.*,
    case
      when original_classification='MATCH' and old_current_patient_id is not null then 'RESOLVED_EXISTING'
      when original_classification in ('REVIEW','NEW') and current_target_count=1 and not has_current_key_conflict
       and current_candidate_patient_id is not null and (
          (has_document and (has_email or has_phone)) or (has_email and has_phone)
          or (has_document and source_name_key=current_candidate_name_key)
          or (has_email and source_name_key=current_candidate_name_key)
       ) then 'RESOLVED_EXISTING'
      when original_classification='REVIEW' and old_current_patient_id is not null
       and original_reason='CANONICAL_TARGET_COLLISION'
       and (coalesce(original_match_method,'') like '%DNI%' or original_match_method='EMAIL') then 'RESOLVED_EXISTING'
      when original_classification='REVIEW' and old_current_patient_id is not null
       and original_reason='AMBIGUOUS_OR_INSUFFICIENT_EVIDENCE'
       and original_match_method in ('EMAIL','NAME_DOB+PHONE_NAME') then 'RESOLVED_EXISTING'
      when original_classification='REVIEW' and old_current_patient_id is not null
       and original_reason='CANONICAL_STRONG_FIELD_CONFLICT'
       and not canonical_dni_conflict and not canonical_email_conflict and not canonical_dob_conflict and canonical_sex_conflict
       and (coalesce(original_match_method,'') like '%DNI%' or original_match_method='EMAIL') then 'RESOLVED_EXISTING_ATTRIBUTE_REVIEW'
      when original_classification='NEW' and current_target_count=0 and not has_current_key_conflict
       and confidence='HIGH' and source_row_count>=2 and distinct_names=1
       and distinct_documents=1 and distinct_dni8=1 and distinct_emails<=1 and distinct_peru_phones<=1
       and distinct_birth_dates<=1 and distinct_sexes<=1 and (distinct_peru_phones=1 or distinct_emails=1) then 'NEW_SAFE'
      when original_classification='MATCH' and old_current_patient_id is null then 'STALE_TARGET'
      else 'REVIEW_REQUIRED'
    end::text resolution_status,
    case
      when original_classification='MATCH' and old_current_patient_id is not null then 'CERTIFIED_F5_MATCH_CURRENT_TARGET'
      when original_classification in ('REVIEW','NEW') and current_target_count=1 and not has_current_key_conflict
       and current_candidate_patient_id is not null and (
          (has_document and (has_email or has_phone)) or (has_email and has_phone)
          or (has_document and source_name_key=current_candidate_name_key)
          or (has_email and source_name_key=current_candidate_name_key)
       ) then 'CANONICAL_CURRENT_EXACT_MULTI_SIGNAL'
      when original_classification='REVIEW' and old_current_patient_id is not null and original_reason='CANONICAL_TARGET_COLLISION'
       and (coalesce(original_match_method,'') like '%DNI%' or original_match_method='EMAIL') then 'F5_STRONG_TARGET_COLLISION_NON_IDENTITY'
      when original_classification='REVIEW' and old_current_patient_id is not null and original_reason='AMBIGUOUS_OR_INSUFFICIENT_EVIDENCE'
       and original_match_method in ('EMAIL','NAME_DOB+PHONE_NAME') then 'F5_STRONG_LEGACY_EVIDENCE'
      when original_classification='REVIEW' and old_current_patient_id is not null and original_reason='CANONICAL_STRONG_FIELD_CONFLICT'
       and not canonical_dni_conflict and not canonical_email_conflict and not canonical_dob_conflict and canonical_sex_conflict
       and (coalesce(original_match_method,'') like '%DNI%' or original_match_method='EMAIL') then 'IDENTITY_RESOLVED_SEX_REVIEW_RETAINED'
      when original_classification='NEW' and current_target_count=0 and not has_current_key_conflict
       and confidence='HIGH' and source_row_count>=2 and distinct_names=1 and distinct_documents=1 and distinct_dni8=1
       and distinct_emails<=1 and distinct_peru_phones<=1 and distinct_birth_dates<=1 and distinct_sexes<=1
       and (distinct_peru_phones=1 or distinct_emails=1) then 'NEW_HIGH_DNI8_PLUS_SECOND_SIGNAL'
      when original_classification='MATCH' and old_current_patient_id is null then 'CERTIFIED_TARGET_NO_LONGER_CURRENT'
      else 'INSUFFICIENT_OR_CONFLICTING_IDENTITY_EVIDENCE'
    end::text resolution_rule
  from evaluated e
)
select
  cluster_id,original_classification,original_reason,original_match_method,original_match_score,
  resolution_status,resolution_rule,
  case
    when resolution_status='RESOLVED_EXISTING' and resolution_rule='CANONICAL_CURRENT_EXACT_MULTI_SIGNAL' then current_candidate_patient_id
    when resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW') then original_target_patient_id
    else null
  end::text canonical_patient_id,
  case when resolution_status='NEW_SAFE' then 'P-HIST-F511-'||upper(replace(cluster_id::text,'-','')) else null end::text proposed_patient_id,
  source_row_count,confidence,
  case when resolution_status='RESOLVED_EXISTING_ATTRIBUTE_REVIEW' then jsonb_build_object('Sexo','REVIEW_REQUIRED') else '{}'::jsonb end attribute_review,
  jsonb_build_object(
    'cluster_status',cluster_status,'cluster_evidence',cluster_evidence,'source_conflicts',conflicts,
    'current_target_count',current_target_count,'has_current_key_conflict',has_current_key_conflict,
    'source_identity_counts',jsonb_build_object('names',distinct_names,'documents',distinct_documents,'dni8',distinct_dni8,'emails',distinct_emails,'phones',distinct_peru_phones,'birth_dates',distinct_birth_dates,'sexes',distinct_sexes),
    'proposed_identity',jsonb_build_object('nombres',canonical_preview->>'nombres','apellidos',canonical_preview->>'apellidos','phone',proposed_phone,'email',proposed_email,'document',proposed_document),
    'first_source_date',first_source_date,'last_source_appointment',last_source_appointment
  ) evidence,
  md5(concat_ws('|',cluster_id::text,original_classification,original_reason,coalesce(original_match_method,''),coalesce(original_match_score::text,''),resolution_status,resolution_rule,
      coalesce(case when resolution_status='RESOLVED_EXISTING' and resolution_rule='CANONICAL_CURRENT_EXACT_MULTI_SIGNAL' then current_candidate_patient_id when resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW') then original_target_patient_id end,''),
      coalesce(case when resolution_status='NEW_SAFE' then 'P-HIST-F511-'||upper(replace(cluster_id::text,'-','')) end,''),source_row_count::text,confidence)) preview_hash
from decided;

comment on view public.aos_f5_historical_identity_completion_preview_v1 is
'REV-F5.11 deterministic preview. Current exact identifiers are authoritative only when non-fused and unique; phone alone never auto-links. Ambiguous clusters remain REVIEW_REQUIRED.';
revoke all on public.aos_f5_historical_identity_completion_preview_v1 from public,anon,authenticated;
grant select on public.aos_f5_historical_identity_completion_preview_v1 to service_role;

create or replace function public.aos_f5_11_identity_completion_snapshot_v1()
returns jsonb
language sql
security definer
set search_path=''
as $$
  with p as (select * from public.aos_f5_historical_identity_completion_preview_v1),
  x as (
    select count(*) clusters,coalesce(sum(source_row_count),0) source_rows,
      count(*) filter(where resolution_status='RESOLVED_EXISTING') resolved_existing,
      count(*) filter(where resolution_status='RESOLVED_EXISTING_ATTRIBUTE_REVIEW') resolved_attribute_review,
      count(*) filter(where resolution_status='NEW_SAFE') safe_new,
      count(*) filter(where resolution_status='STALE_TARGET') stale_target,
      count(*) filter(where resolution_status='REVIEW_REQUIRED') review_required,
      md5(string_agg(preview_hash,',' order by cluster_id)) preview_fingerprint
    from p
  )
  select jsonb_build_object('ok',true,'resolution_version','REV-F5.11-V1','clusters',clusters,'source_rows',source_rows,
    'resolved_existing',resolved_existing,'resolved_attribute_review',resolved_attribute_review,'safe_new',safe_new,
    'stale_target',stale_target,'review_required',review_required,'preview_fingerprint',preview_fingerprint)
  from x
$$;
revoke all on function public.aos_f5_11_identity_completion_snapshot_v1() from public,anon,authenticated;
grant execute on function public.aos_f5_11_identity_completion_snapshot_v1() to service_role;

create or replace function public.aos_f5_11_apply_identity_completion_v1(p_expected_preview_fingerprint text,p_expected_safe_new integer)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_preview jsonb;
  v_fp text;
  v_safe integer;
  v_clusters integer;
  v_source bigint;
  v_members bigint;
  v_existing_before bigint;
  v_existing_after bigint;
  v_existing_fp_before text;
  v_existing_fp_after text;
  v_inserted integer:=0;
  v_now timestamptz:=clock_timestamp();
begin
  if exists(select 1 from public.aos_f5_historical_identity_resolution_v2) then
    if (select count(*) from public.aos_f5_historical_identity_resolution_v2)<>(select count(*) from public.aos_f5_identity_clusters_v1) then
      raise exception 'F5_11_PARTIAL_RESOLUTION_LEDGER';
    end if;
    if exists(select 1 from public.aos_f5_historical_identity_resolution_v2 where resolution_status='NEW_SAFE') then
      raise exception 'F5_11_PARTIAL_NEW_APPLY';
    end if;
    return jsonb_build_object('ok',true,'replay',true,'resolution_version','REV-F5.11-V1',
      'resolution_rows',(select count(*) from public.aos_f5_historical_identity_resolution_v2),
      'new_created',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='NEW_CREATED'));
  end if;

  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  select count(*) into v_source from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  if v_clusters=0 or v_source=0 or v_members<>v_source then raise exception 'F5_11_SOURCE_COVERAGE_INVALID'; end if;
  if (select count(*) from public.aos_f5_historical_identity_completion_preview_v1)<>v_clusters then raise exception 'F5_11_PREVIEW_COVERAGE_INVALID'; end if;
  if exists(select 1 from public.aos_ventas where fecha between date '2024-01-01' and date '2025-12-31') then raise exception 'F5_11_2024_2025_SALES_OUT_OF_SCOPE'; end if;

  v_preview:=public.aos_f5_11_identity_completion_snapshot_v1();
  v_fp:=v_preview->>'preview_fingerprint';
  v_safe:=(v_preview->>'safe_new')::integer;
  if p_expected_preview_fingerprint is null or p_expected_preview_fingerprint<>v_fp then raise exception 'F5_11_PREVIEW_FINGERPRINT_MISMATCH'; end if;
  if p_expected_safe_new is null or p_expected_safe_new<>v_safe then raise exception 'F5_11_SAFE_NEW_COUNT_MISMATCH'; end if;

  select count(*),md5(string_agg(md5(concat_ws('|',p."ID_PACIENTE",coalesce(p."Teléfono",''),coalesce(p.numero_limpio,''),coalesce(p."Email",''),coalesce(p."N° documento",''),coalesce(p."ESTADO_PACIENTE",''),coalesce(p."Nombres",''),coalesce(p."Apellidos",''))),',' order by p."ID_PACIENTE"))
  into v_existing_before,v_existing_fp_before
  from public.aos_pacientes p where p."ID_PACIENTE" not like 'P-HIST-F511-%';

  insert into public.aos_f5_historical_identity_resolution_v2(
    cluster_id,original_classification,original_reason,original_match_method,original_match_score,resolution_status,resolution_rule,
    canonical_patient_id,proposed_patient_id,source_row_count,confidence,attribute_review,evidence,preview_hash,resolution_version,generated_at,applied_at)
  select cluster_id,original_classification,original_reason,original_match_method,original_match_score,resolution_status,resolution_rule,
    canonical_patient_id,proposed_patient_id,source_row_count,confidence,attribute_review,evidence,preview_hash,'REV-F5.11-V1',v_now,
    case when resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW') then v_now else null end
  from public.aos_f5_historical_identity_completion_preview_v1;

  insert into public.aos_pacientes(
    "ID_PACIENTE","Nombres","Apellidos","Teléfono",numero_limpio,"Email","N° documento","Sexo","Fecha de nacimiento",
    "ESTADO_PACIENTE",fuente_datos,"FUENTE","FECHA_REGISTRO",created_at,updated_at,pais,etiqueta_vip)
  select r.proposed_patient_id,
         nullif(r.evidence->'proposed_identity'->>'nombres',''),
         nullif(r.evidence->'proposed_identity'->>'apellidos',''),
         nullif(r.evidence->'proposed_identity'->>'phone',''),
         nullif(r.evidence->'proposed_identity'->>'phone',''),
         nullif(r.evidence->'proposed_identity'->>'email',''),
         nullif(r.evidence->'proposed_identity'->>'document',''),
         nullif(c.canonical_preview->>'sex',''),
         nullif(c.canonical_preview->>'birth_date',''),
         'PROSPECTO','historico_f5_completion_v2','F5_2024_2026',
         nullif(r.evidence->>'first_source_date',''),v_now,v_now,'Perú','NORMAL'
  from public.aos_f5_historical_identity_resolution_v2 r
  join public.aos_f5_identity_clusters_v1 c on c.id=r.cluster_id
  where r.resolution_status='NEW_SAFE'
  on conflict ("ID_PACIENTE") do nothing;
  get diagnostics v_inserted=row_count;

  if v_inserted<>v_safe then raise exception 'F5_11_NEW_PATIENT_INSERT_COUNT_MISMATCH expected %, inserted %',v_safe,v_inserted; end if;

  update public.aos_f5_historical_identity_resolution_v2
  set resolution_status='NEW_CREATED',canonical_patient_id=proposed_patient_id,applied_at=v_now
  where resolution_status='NEW_SAFE';

  if exists(
    select 1 from public.aos_f5_historical_identity_resolution_v2 r
    left join public.aos_pacientes p on p."ID_PACIENTE"=r.canonical_patient_id
    where r.resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW','NEW_CREATED')
      and (p."ID_PACIENTE" is null or coalesce(p."ESTADO_PACIENTE",'')='FUSIONADO')
  ) then raise exception 'F5_11_RESOLUTION_POINTS_TO_NONCURRENT_PATIENT'; end if;

  select count(*),md5(string_agg(md5(concat_ws('|',p."ID_PACIENTE",coalesce(p."Teléfono",''),coalesce(p.numero_limpio,''),coalesce(p."Email",''),coalesce(p."N° documento",''),coalesce(p."ESTADO_PACIENTE",''),coalesce(p."Nombres",''),coalesce(p."Apellidos",''))),',' order by p."ID_PACIENTE"))
  into v_existing_after,v_existing_fp_after
  from public.aos_pacientes p where p."ID_PACIENTE" not like 'P-HIST-F511-%';
  if v_existing_after<>v_existing_before or v_existing_fp_after is distinct from v_existing_fp_before then raise exception 'F5_11_EXISTING_CANONICAL_MUTATION_DETECTED'; end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('HISTORICAL_IDENTITY_COMPLETION_APPLIED','REV_F5','REV-F5.11',jsonb_build_object(
    'version','REV-F5.11-V1','preview_fingerprint',v_fp,'source_rows',v_source,'clusters',v_clusters,
    'resolved_existing',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='RESOLVED_EXISTING'),
    'resolved_attribute_review',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='RESOLVED_EXISTING_ATTRIBUTE_REVIEW'),
    'new_created',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='NEW_CREATED'),
    'stale_target',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='STALE_TARGET'),
    'review_required',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='REVIEW_REQUIRED'),
    'existing_patient_mutation',false,'sales_2024_2025_mutation',false));

  return jsonb_build_object('ok',true,'replay',false,'resolution_version','REV-F5.11-V1','preview_fingerprint',v_fp,
    'source_rows',v_source,'clusters',v_clusters,'new_created',v_inserted,
    'resolved_existing',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='RESOLVED_EXISTING'),
    'resolved_attribute_review',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='RESOLVED_EXISTING_ATTRIBUTE_REVIEW'),
    'stale_target',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='STALE_TARGET'),
    'review_required',(select count(*) from public.aos_f5_historical_identity_resolution_v2 where resolution_status='REVIEW_REQUIRED'));
end
$$;
revoke all on function public.aos_f5_11_apply_identity_completion_v1(text,integer) from public,anon,authenticated;
grant execute on function public.aos_f5_11_apply_identity_completion_v1(text,integer) to service_role;

-- Replace the alias bridge with the completion ledger. This intentionally removes stale
-- aliases pointing at FUSIONADO historical MATCH targets.
create or replace view public.aos_rev_patient_identity_alias_v2 as
with raw_alias as (
  select 'CANONICAL_ID'::text identifier_type,p."ID_PACIENTE"::text identifier_key,p."ID_PACIENTE"::text canonical_patient_id,'CANONICAL_CURRENT'::text source_scope
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  union all
  select 'PHONE',public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")),p."ID_PACIENTE"::text,'CANONICAL_CURRENT'
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO' and public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")) is not null
  union all
  select 'DOCUMENT',public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento"),p."ID_PACIENTE"::text,'CANONICAL_CURRENT'
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO' and public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento") is not null
  union all
  select 'EMAIL',public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email"),p."ID_PACIENTE"::text,'CANONICAL_CURRENT'
  from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO' and public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email") is not null
  union all
  select 'PHONE',public.aos_rev_normalize_patient_identifier_v2('PHONE',s.phone_key),r.canonical_patient_id,'F5_COMPLETION_V2'
  from public.aos_f5_historical_identity_resolution_v2 r join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=r.cluster_id join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join public.aos_pacientes p on p."ID_PACIENTE"=r.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  where r.resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW','NEW_CREATED') and public.aos_rev_normalize_patient_identifier_v2('PHONE',s.phone_key) is not null
  union all
  select 'DOCUMENT',public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',s.document_key),r.canonical_patient_id,'F5_COMPLETION_V2'
  from public.aos_f5_historical_identity_resolution_v2 r join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=r.cluster_id join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join public.aos_pacientes p on p."ID_PACIENTE"=r.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  where r.resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW','NEW_CREATED') and public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',s.document_key) is not null
  union all
  select 'EMAIL',public.aos_rev_normalize_patient_identifier_v2('EMAIL',s.email_key),r.canonical_patient_id,'F5_COMPLETION_V2'
  from public.aos_f5_historical_identity_resolution_v2 r join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=r.cluster_id join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  join public.aos_pacientes p on p."ID_PACIENTE"=r.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  where r.resolution_status in ('RESOLVED_EXISTING','RESOLVED_EXISTING_ATTRIBUTE_REVIEW','NEW_CREATED') and public.aos_rev_normalize_patient_identifier_v2('EMAIL',s.email_key) is not null
), per_candidate as (
  select identifier_type,identifier_key,canonical_patient_id,count(*)::integer evidence_rows,
         bool_or(source_scope='F5_COMPLETION_V2') has_reviewed_match,
         jsonb_agg(distinct source_scope order by source_scope) evidence_scopes
  from raw_alias where identifier_key is not null and identifier_key<>'' and canonical_patient_id is not null
  group by identifier_type,identifier_key,canonical_patient_id
), scored as (
  select pc.*,count(*) over(partition by identifier_type,identifier_key)::integer candidate_count from per_candidate pc
)
select identifier_type,identifier_key,canonical_patient_id,evidence_rows,evidence_scopes,candidate_count,
       case when candidate_count=1 then 'RESOLVED' else 'CONFLICT' end::text status,
       case when identifier_type='CANONICAL_ID' then 'EXACT' when has_reviewed_match then 'HIGH' else 'MEDIUM' end::text confidence_band,
       has_reviewed_match
from scored;

comment on view public.aos_rev_patient_identity_alias_v2 is
'REV-F5.11/F6.1 identity lookup bridge. Current canonical aliases plus governed historical completion aliases; stale FUSIONADO targets are excluded and conflicting identifiers remain explicit.';
revoke all on public.aos_rev_patient_identity_alias_v2 from public,anon,authenticated;
grant select on public.aos_rev_patient_identity_alias_v2 to service_role;

select pg_notify('pgrst','reload schema');
commit;
