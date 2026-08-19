-- REV-F5.6 — Review & Apply v2
-- Field-level, fill-only, active-admin-2FA gated, optimistic and reversible.
-- Reuses F5 classification, enrichment preview and canonical apply-event ledger.

alter table public.aos_f5_enrichment_preview_v1
  add column if not exists review_decision text,
  add column if not exists review_reason text,
  add column if not exists reviewed_by uuid,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_snapshot_hash text,
  add column if not exists applied_at timestamptz,
  add column if not exists apply_event_id uuid;

alter table public.aos_f5_canonical_apply_events_v1
  add column if not exists field_name text,
  add column if not exists canonical_before_hash text,
  add column if not exists canonical_after_hash text,
  add column if not exists rollback_after_hash text,
  add column if not exists apply_scope text not null default 'LEGACY';

create unique index if not exists aos_f5_one_active_field_apply_v2
  on public.aos_f5_canonical_apply_events_v1(cluster_id,field_name)
  where field_name is not null and rolled_back_at is null;

-- Existing risk-class contract is intentionally preserved:
-- LOW / MEDIUM / IDENTITY_ANCHOR / BLOCKED.
insert into public.aos_f5_apply_field_policy_v1(field_name,risk_class,apply_allowed,notes)
values
  ('Sexo','LOW',true,'REV-F5.6 fill-only after explicit field review; canonical must still be empty'),
  ('distrito','LOW',true,'REV-F5.6 fill-only after explicit field review; canonical must still be empty'),
  ('departamento','LOW',true,'REV-F5.6 fill-only after explicit field review; canonical must still be empty'),
  ('ciudad','LOW',true,'REV-F5.6 fill-only after explicit field review; canonical must still be empty'),
  ('Email','IDENTITY_ANCHOR',false,'Blocked in REV-F5.6; identity anchor requires a later dedicated contract'),
  ('N° documento','IDENTITY_ANCHOR',false,'Blocked in REV-F5.6; identity anchor requires a later dedicated contract'),
  ('Teléfono','IDENTITY_ANCHOR',false,'Blocked in REV-F5.6; identity/contact anchor requires a later dedicated contract'),
  ('Fecha de nacimiento','BLOCKED',false,'Blocked in REV-F5.6; identity-sensitive field'),
  ('Dirección','MEDIUM',false,'Blocked in REV-F5.6; historical address may be stale'),
  ('Ocupación','MEDIUM',false,'Blocked in REV-F5.6; historical occupation may be stale'),
  ('FUENTE','BLOCKED',false,'Blocked until historical acquisition-channel mapping is contractually defined'),
  ('fuente_datos','BLOCKED',false,'Blocked until historical acquisition-channel mapping is contractually defined'),
  ('ULTIMA_VISITA','BLOCKED',false,'Blocked until latest-appointment canonical semantics are defined'),
  ('ult_visita','BLOCKED',false,'Blocked until latest-appointment canonical semantics are defined'),
  ('NOTAS','BLOCKED',false,'Clinical/free-text notes are excluded from automatic commercial enrichment'),
  ('Alergias','BLOCKED',false,'Clinical allergy data is excluded from automatic commercial enrichment')
on conflict (field_name) do update
set risk_class=excluded.risk_class,
    apply_allowed=excluded.apply_allowed,
    notes=excluded.notes,
    updated_at=now();

update public.aos_f5_enrichment_preview_v1 e
set policy_state=case when fp.apply_allowed then 'APPLY_ALLOWED' else 'POLICY_BLOCKED' end,
    policy_risk_class=fp.risk_class,
    policy_apply_allowed=fp.apply_allowed,
    apply_eligible=false,
    requires_human=true
from public.aos_f5_apply_field_policy_v1 fp
where fp.field_name=e.field_name;

create or replace function public.aos_f5_assert_active_admin_2fa_v2(p_actor_user_id uuid)
returns void
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
begin
  if p_actor_user_id is null or not exists (
    select 1
    from public.aos_usuarios u
    where u.id=p_actor_user_id
      and u.activo is true
      and lower(coalesce(u.rol,''))='admin'
      and u.nivel_jerarquia=1
      and u.two_factor is true
  ) then
    raise exception 'F5_6_ACTIVE_ADMIN_2FA_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.aos_app_sessions_v3 s
    where s.user_id=p_actor_user_id
      and s.revoked=false
      and s.expires_at>now()
      and s.assurance_level='PASSWORD_2FA'
  ) then
    raise exception 'F5_6_ACTIVE_2FA_SESSION_REQUIRED';
  end if;
end
$$;

create or replace function public.aos_f5_review_enrichment_field_v2(
  p_cluster_id uuid,
  p_field_name text,
  p_actor_user_id uuid,
  p_expected_generated_at timestamptz,
  p_decision text,
  p_reason text
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
  v_decision text:=upper(coalesce(p_decision,''));
  v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
  v_patient jsonb;
  v_current jsonb;
  v_canonical_hash text;
  v_review_hash text;
  v_target_hash text;
begin
  perform public.aos_f5_assert_active_admin_2fa_v2(p_actor_user_id);
  if v_decision not in ('APPROVE_FIELD','REJECT_FIELD','DEFER') then raise exception 'F5_6_INVALID_REVIEW_DECISION'; end if;

  select * into e
  from public.aos_f5_enrichment_preview_v1
  where cluster_id=p_cluster_id and field_name=p_field_name
  for update;
  if not found then raise exception 'F5_6_ENRICHMENT_PREVIEW_NOT_FOUND'; end if;
  if p_expected_generated_at is null or e.generated_at<>p_expected_generated_at then raise exception 'F5_6_STALE_ENRICHMENT_PREVIEW'; end if;
  if e.applied_at is not null then raise exception 'F5_6_FIELD_ALREADY_APPLIED'; end if;
  if e.source_distinct_values<>1 or cardinality(e.source_row_ids)=0 or not e.canonical_empty or not e.requires_human then raise exception 'F5_6_PREVIEW_SAFETY_INVALID'; end if;

  select * into c from public.aos_f5_canonical_classification_v1 where cluster_id=e.cluster_id;
  if c.classification<>'MATCH' or c.target_patient_id is distinct from e.target_patient_id
     or c.canonical_dni_conflict or c.canonical_email_conflict or c.canonical_dob_conflict or c.canonical_sex_conflict
     or c.target_missing or c.target_collision or c.source_strong_conflict then
    raise exception 'F5_6_MATCH_SAFETY_INVALID';
  end if;

  select * into fp from public.aos_f5_apply_field_policy_v1 where field_name=e.field_name;
  if not found then raise exception 'F5_6_FIELD_POLICY_MISSING'; end if;

  if v_decision='APPROVE_FIELD' then
    if not fp.apply_allowed or fp.risk_class<>'LOW' or e.field_name not in ('Sexo','distrito','departamento','ciudad') then
      raise exception 'F5_6_FIELD_NOT_APPROVABLE';
    end if;
    if coalesce(length(v_reason),0)<20 then raise exception 'F5_6_APPROVAL_REASON_REQUIRED'; end if;
  elsif v_decision='REJECT_FIELD' and coalesce(length(v_reason),0)<10 then
    raise exception 'F5_6_REJECTION_REASON_REQUIRED';
  end if;

  select to_jsonb(p) into v_patient from public.aos_pacientes p where p."ID_PACIENTE"=e.target_patient_id;
  if v_patient is null then raise exception 'F5_6_TARGET_PATIENT_NOT_FOUND'; end if;
  v_current:=v_patient->e.field_name;
  if v_decision='APPROVE_FIELD' and v_current is not null and v_current<>'null'::jsonb and nullif(btrim(v_current#>>'{}'),'') is not null then
    raise exception 'F5_6_CANONICAL_FIELD_NOT_EMPTY';
  end if;

  v_canonical_hash:=encode(extensions.digest(convert_to(v_patient::text,'UTF8'),'sha256'),'hex');
  v_review_hash:=encode(extensions.digest(convert_to(jsonb_build_object(
    'cluster_id',e.cluster_id,
    'target_patient_id',e.target_patient_id,
    'field_name',e.field_name,
    'proposed_value',e.proposed_value,
    'source_row_ids',to_jsonb(e.source_row_ids),
    'source_distinct_values',e.source_distinct_values,
    'policy_updated_at',fp.updated_at,
    'canonical_hash',v_canonical_hash
  )::text,'UTF8'),'sha256'),'hex');
  v_target_hash:=encode(extensions.digest(convert_to(e.target_patient_id,'UTF8'),'sha256'),'hex');

  update public.aos_f5_enrichment_preview_v1
  set review_decision=v_decision,
      review_reason=v_reason,
      reviewed_by=case when v_decision='DEFER' then null else p_actor_user_id end,
      reviewed_at=case when v_decision='DEFER' then null else now() end,
      reviewed_snapshot_hash=case when v_decision='DEFER' then null else v_review_hash end,
      apply_eligible=case when v_decision='APPROVE_FIELD' then true else false end
  where cluster_id=e.cluster_id and field_name=e.field_name;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,actor_user_id,details)
  values('ENRICHMENT_FIELD_REVIEWED','F5_ENRICHMENT_FIELD',e.cluster_id::text||':'||e.field_name,p_actor_user_id,
    jsonb_build_object('decision',v_decision,'field_name',e.field_name,'target_hash',v_target_hash,'review_snapshot_hash',v_review_hash,'policy_risk_class',fp.risk_class,'policy_apply_allowed',fp.apply_allowed));

  return jsonb_build_object('ok',true,'decision',v_decision,'field_name',e.field_name,'target_hash',v_target_hash,'review_snapshot_hash',v_review_hash);
end
$$;

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
  if e.applied_at is not null then
    return jsonb_build_object('ok',true,'idempotent',true,'field_name',e.field_name,'event_id',e.apply_event_id,'applied',true);
  end if;
  if not e.apply_eligible or e.source_distinct_values<>1 or cardinality(e.source_row_ids)=0 or not e.canonical_empty then raise exception 'F5_6_PREVIEW_NOT_APPLY_ELIGIBLE'; end if;

  select * into c from public.aos_f5_canonical_classification_v1 where cluster_id=e.cluster_id;
  if c.classification<>'MATCH' or c.target_patient_id is distinct from e.target_patient_id
     or c.canonical_dni_conflict or c.canonical_email_conflict or c.canonical_dob_conflict or c.canonical_sex_conflict
     or c.target_missing or c.target_collision or c.source_strong_conflict then
    raise exception 'F5_6_MATCH_SAFETY_INVALID';
  end if;

  select * into fp from public.aos_f5_apply_field_policy_v1 where field_name=e.field_name;
  if not found or not fp.apply_allowed or fp.risk_class<>'LOW' or e.field_name not in ('Sexo','distrito','departamento','ciudad') then
    raise exception 'F5_6_LIVE_POLICY_BLOCKED';
  end if;

  select to_jsonb(p) into v_patient from public.aos_pacientes p where p."ID_PACIENTE"=e.target_patient_id for update;
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

  v_sql:=format('update public.aos_pacientes set %I=$1 where "ID_PACIENTE"=$2 and nullif(btrim(coalesce(%I,'')),'''') is null',e.field_name,e.field_name);
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

create or replace function public.aos_f5_rollback_enrichment_field_v2(
  p_event_id uuid,
  p_actor_user_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  ev public.aos_f5_canonical_apply_events_v1%rowtype;
  v_patient jsonb;
  v_current jsonb;
  v_expected jsonb;
  v_current_hash text;
  v_rollback_hash text;
  v_target_hash text;
  v_sql text;
  v_rows integer;
begin
  perform public.aos_f5_assert_active_admin_2fa_v2(p_actor_user_id);
  if coalesce(length(btrim(coalesce(p_reason,''))),0)<20 then raise exception 'F5_6_ROLLBACK_REASON_REQUIRED'; end if;

  select * into ev from public.aos_f5_canonical_apply_events_v1 where id=p_event_id for update;
  if not found then raise exception 'F5_6_APPLY_EVENT_NOT_FOUND'; end if;
  if ev.field_name is null or ev.canonical_before_hash is null or ev.canonical_after_hash is null then raise exception 'F5_6_NOT_A_V2_FIELD_EVENT'; end if;
  if ev.rolled_back_at is not null then return jsonb_build_object('ok',true,'idempotent',true,'rolled_back',true,'event_id',p_event_id); end if;
  if ev.field_name not in ('Sexo','distrito','departamento','ciudad') then raise exception 'F5_6_ROLLBACK_FIELD_INVALID'; end if;

  select to_jsonb(p) into v_patient from public.aos_pacientes p where p."ID_PACIENTE"=ev.target_patient_id for update;
  if v_patient is null then raise exception 'F5_6_TARGET_PATIENT_NOT_FOUND'; end if;
  v_current_hash:=encode(extensions.digest(convert_to(v_patient::text,'UTF8'),'sha256'),'hex');
  if v_current_hash<>ev.canonical_after_hash then raise exception 'F5_6_ROLLBACK_BLOCKED_BY_NEWER_ROW_CHANGE'; end if;

  v_current:=v_patient->ev.field_name;
  v_expected:=ev.after_patch->ev.field_name;
  if v_current is distinct from v_expected then raise exception 'F5_6_ROLLBACK_BLOCKED_BY_NEWER_FIELD_CHANGE'; end if;

  v_sql:=format('update public.aos_pacientes set %I=$1 where "ID_PACIENTE"=$2',ev.field_name);
  execute v_sql using (ev.before_patch->>ev.field_name),ev.target_patient_id;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then raise exception 'F5_6_ROLLBACK_TARGET_UPDATE_FAILED'; end if;

  select to_jsonb(p) into v_patient from public.aos_pacientes p where p."ID_PACIENTE"=ev.target_patient_id;
  v_rollback_hash:=encode(extensions.digest(convert_to(v_patient::text,'UTF8'),'sha256'),'hex');
  if v_rollback_hash<>ev.canonical_before_hash then raise exception 'F5_6_ROLLBACK_HASH_MISMATCH'; end if;

  update public.aos_f5_canonical_apply_events_v1
  set rolled_back_at=now(),rolled_back_by=p_actor_user_id,rollback_reason=btrim(p_reason),rollback_after_hash=v_rollback_hash
  where id=ev.id;

  update public.aos_f5_enrichment_preview_v1
  set applied_at=null,apply_event_id=null
  where cluster_id=ev.cluster_id and field_name=ev.field_name and apply_event_id=ev.id;

  v_target_hash:=encode(extensions.digest(convert_to(ev.target_patient_id,'UTF8'),'sha256'),'hex');
  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,actor_user_id,details)
  values('ENRICHMENT_FIELD_ROLLED_BACK','F5_ENRICHMENT_FIELD',ev.cluster_id::text||':'||ev.field_name,p_actor_user_id,
    jsonb_build_object('event_id',ev.id,'scope',ev.apply_scope,'field_name',ev.field_name,'target_hash',v_target_hash,'canonical_after_hash',ev.canonical_after_hash,'rollback_after_hash',v_rollback_hash,'reason',btrim(p_reason)));

  return jsonb_build_object('ok',true,'rolled_back',true,'event_id',ev.id,'scope',ev.apply_scope,'field_name',ev.field_name,'target_hash',v_target_hash,'rollback_after_hash',v_rollback_hash);
end
$$;

revoke all on function public.aos_f5_assert_active_admin_2fa_v2(uuid) from public,anon,authenticated;
revoke all on function public.aos_f5_review_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) from public,anon,authenticated;
revoke all on function public.aos_f5_apply_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) from public,anon,authenticated;
revoke all on function public.aos_f5_rollback_enrichment_field_v2(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.aos_f5_assert_active_admin_2fa_v2(uuid) to service_role;
grant execute on function public.aos_f5_review_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) to service_role;
grant execute on function public.aos_f5_apply_enrichment_field_v2(uuid,text,uuid,timestamptz,text,text) to service_role;
grant execute on function public.aos_f5_rollback_enrichment_field_v2(uuid,uuid,text) to service_role;

-- Legacy mutators stay server-only; REV-F5.6 certification uses v2 field functions.
revoke all on function public.aos_f5_review_decision_v1(uuid,uuid,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.aos_f5_apply_reviewed_patch_v1(uuid,uuid,timestamptz,text) from public,anon,authenticated;
revoke all on function public.aos_f5_rollback_apply_v1(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.aos_f5_review_decision_v1(uuid,uuid,text,text,timestamptz) to service_role;
grant execute on function public.aos_f5_apply_reviewed_patch_v1(uuid,uuid,timestamptz,text) to service_role;
grant execute on function public.aos_f5_rollback_apply_v1(uuid,uuid,text) to service_role;

insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
values('REVIEW_APPLY_V2_POLICY_INSTALLED','F5','REV-F5.6',jsonb_build_object(
  'mode','FIELD_LEVEL_FILL_ONLY',
  'active_admin_2fa_required',true,
  'optimistic_review_snapshot',true,
  'canonical_before_after_hashes',true,
  'rollback_hash_required',true,
  'allowed_fields',jsonb_build_array('Sexo','distrito','departamento','ciudad'),
  'identity_anchors_blocked',true,
  'clinical_fields_blocked',true,
  'installed_at',now()
));
