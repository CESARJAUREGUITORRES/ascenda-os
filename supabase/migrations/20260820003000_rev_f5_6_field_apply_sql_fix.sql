-- REV-F5.6 repair: the target patient row is already held FOR UPDATE and its
-- field emptiness has already been verified. Use the locked-row update directly
-- instead of a redundant dynamically quoted emptiness predicate.

create or replace function public.aos_f5_apply_enrichment_field_v2(
  p_cluster_id uuid,
  p_field_name text,
  p_actor_user_id uuid,
  p_expected_reviewed_at timestamptz,
  p_mode text default 'DRY_RUN',
  p_scope text default 'CANARY'
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  e public.aos_f5_enrichment_preview_v1%rowtype;
  c public.aos_f5_canonical_classification_v1%rowtype;
  fp public.aos_f5_apply_field_policy_v1%rowtype;
  v_mode text:=upper(coalesce(p_mode,'DRY_RUN'));
  v_scope text:=upper(coalesce(p_scope,'CANARY'));
  v_patient jsonb;
  v_current jsonb;
  v_before_hash text;
  v_after_hash text;
  v_review_hash text;
  v_target_hash text;
  v_value_hash text;
  v_event uuid;
  v_rows integer;
  v_sql text;
begin
  perform public.aos_f5_assert_active_admin_2fa_v2(p_actor_user_id);
  if v_mode not in ('DRY_RUN','APPLY') then raise exception 'F5_6_INVALID_APPLY_MODE'; end if;
  if v_scope not in ('CANARY','BATCH') then raise exception 'F5_6_INVALID_APPLY_SCOPE'; end if;

  select * into e
  from public.aos_f5_enrichment_preview_v1
  where cluster_id=p_cluster_id and field_name=p_field_name
  for update;
  if not found then raise exception 'F5_6_ENRICHMENT_PREVIEW_NOT_FOUND'; end if;
  if e.review_decision<>'APPROVE_FIELD' or e.reviewed_by is distinct from p_actor_user_id or e.reviewed_at is null then raise exception 'F5_6_APPROVED_REVIEW_REQUIRED'; end if;
  if p_expected_reviewed_at is null or e.reviewed_at<>p_expected_reviewed_at then raise exception 'F5_6_STALE_REVIEW'; end if;
  if e.applied_at is not null then return jsonb_build_object('ok',true,'idempotent',true,'field_name',e.field_name,'event_id',e.apply_event_id,'applied',true); end if;
  if not e.apply_eligible or e.source_distinct_values<>1 or cardinality(e.source_row_ids)=0 or not e.canonical_empty then raise exception 'F5_6_PREVIEW_NOT_APPLY_ELIGIBLE'; end if;

  select * into c from public.aos_f5_canonical_classification_v1 where cluster_id=e.cluster_id;
  if c.classification<>'MATCH' or c.target_patient_id is distinct from e.target_patient_id
     or c.canonical_dni_conflict or c.canonical_email_conflict or c.canonical_dob_conflict or c.canonical_sex_conflict
     or c.target_missing or c.target_collision or c.source_strong_conflict then raise exception 'F5_6_MATCH_SAFETY_INVALID'; end if;

  select * into fp from public.aos_f5_apply_field_policy_v1 where field_name=e.field_name;
  if not found or not fp.apply_allowed or fp.risk_class<>'LOW' or e.field_name not in ('Sexo','distrito','departamento','ciudad') then raise exception 'F5_6_LIVE_POLICY_BLOCKED'; end if;

  select to_jsonb(p) into v_patient
  from public.aos_pacientes p
  where p."ID_PACIENTE"=e.target_patient_id
  for update;
  if v_patient is null then raise exception 'F5_6_TARGET_PATIENT_NOT_FOUND'; end if;
  v_current:=v_patient->e.field_name;
  if v_current is not null and v_current<>'null'::jsonb and nullif(btrim(v_current#>>'{}'),'') is not null then raise exception 'F5_6_CANONICAL_FIELD_NOT_EMPTY'; end if;

  v_before_hash:=encode(extensions.digest(convert_to(v_patient::text,'UTF8'),'sha256'),'hex');
  v_review_hash:=encode(extensions.digest(convert_to(jsonb_build_object(
    'cluster_id',e.cluster_id,
    'target_patient_id',e.target_patient_id,
    'field_name',e.field_name,
    'proposed_value',e.proposed_value,
    'source_row_ids',to_jsonb(e.source_row_ids),
    'source_distinct_values',e.source_distinct_values,
    'policy_updated_at',fp.updated_at,
    'canonical_hash',v_before_hash
  )::text,'UTF8'),'sha256'),'hex');
  if e.reviewed_snapshot_hash is null or e.reviewed_snapshot_hash<>v_review_hash then raise exception 'F5_6_REVIEW_SNAPSHOT_CHANGED'; end if;

  v_target_hash:=encode(extensions.digest(convert_to(e.target_patient_id,'UTF8'),'sha256'),'hex');
  v_value_hash:=encode(extensions.digest(convert_to(e.proposed_value,'UTF8'),'sha256'),'hex');

  if v_mode='DRY_RUN' then
    return jsonb_build_object('ok',true,'mode','DRY_RUN','scope',v_scope,'field_name',e.field_name,'target_hash',v_target_hash,'value_hash',v_value_hash,'canonical_before_hash',v_before_hash,'review_snapshot_hash',v_review_hash);
  end if;

  -- Row is already locked and was verified empty above; this update cannot race.
  v_sql:=format('update public.aos_pacientes set %I=$1 where "ID_PACIENTE"=$2',e.field_name);
  execute v_sql using e.proposed_value,e.target_patient_id;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then raise exception 'F5_6_CONCURRENT_CANONICAL_CHANGE'; end if;

  select to_jsonb(p) into v_patient from public.aos_pacientes p where p."ID_PACIENTE"=e.target_patient_id;
  v_after_hash:=encode(extensions.digest(convert_to(v_patient::text,'UTF8'),'sha256'),'hex');
  if v_after_hash=v_before_hash then raise exception 'F5_6_APPLY_HASH_UNCHANGED'; end if;

  insert into public.aos_f5_canonical_apply_events_v1(
    cluster_id,target_patient_id,actor_user_id,before_patch,applied_patch,after_patch,preview_snapshot_hash,
    field_name,canonical_before_hash,canonical_after_hash,apply_scope
  ) values(
    e.cluster_id,e.target_patient_id,p_actor_user_id,
    jsonb_build_object(e.field_name,coalesce(v_current,'null'::jsonb)),
    jsonb_build_object(e.field_name,e.proposed_value),
    jsonb_build_object(e.field_name,e.proposed_value),
    v_review_hash,e.field_name,v_before_hash,v_after_hash,v_scope
  ) returning id into v_event;

  update public.aos_f5_enrichment_preview_v1
  set applied_at=now(),apply_event_id=v_event
  where cluster_id=e.cluster_id and field_name=e.field_name;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,actor_user_id,details)
  values('ENRICHMENT_FIELD_APPLIED','F5_ENRICHMENT_FIELD',e.cluster_id::text||':'||e.field_name,p_actor_user_id,
    jsonb_build_object('event_id',v_event,'scope',v_scope,'field_name',e.field_name,'target_hash',v_target_hash,'value_hash',v_value_hash,'canonical_before_hash',v_before_hash,'canonical_after_hash',v_after_hash,'review_snapshot_hash',v_review_hash));

  return jsonb_build_object('ok',true,'mode','APPLY','scope',v_scope,'field_name',e.field_name,'event_id',v_event,'target_hash',v_target_hash,'value_hash',v_value_hash,'canonical_before_hash',v_before_hash,'canonical_after_hash',v_after_hash);
end
$$;

revoke all on function public.aos_f5_apply_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) from public,anon,authenticated;
grant execute on function public.aos_f5_apply_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) to service_role;

insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
values('FIELD_APPLY_SQL_REPAIRED','F5','REV-F5.6',jsonb_build_object(
  'reason','LOCKED_ROW_UPDATE_REMOVES_REDUNDANT_DYNAMIC_EMPTY_PREDICATE',
  'canonical_mutation',false,
  'repaired_at',now()
));
