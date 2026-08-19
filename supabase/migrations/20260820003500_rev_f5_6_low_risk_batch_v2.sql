-- REV-F5.6 progressive expansion after mandatory canary+rollback proof.
-- Each field is reviewed and applied sequentially so a patient with more than one
-- fill receives a fresh optimistic snapshot for every mutation.

create or replace function public.aos_f5_apply_low_risk_batch_v2(
  p_actor_user_id uuid,
  p_limit integer default 10,
  p_reason text default 'Owner-authorized REV-F5.6 progressive LOW-risk fill-only batch'
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  r record;
  v_limit integer:=least(greatest(coalesce(p_limit,10),1),50);
  v_reason text:=btrim(coalesce(p_reason,''));
  v_review jsonb;
  v_apply jsonb;
  v_reviewed_at timestamptz;
  v_processed integer:=0;
  v_events_before bigint;
  v_events_after bigint;
  v_applied_before bigint;
  v_applied_after bigint;
  v_canon_count_before bigint;
  v_canon_count_after bigint;
  v_canon_fp_before text;
  v_canon_fp_after text;
begin
  perform public.aos_f5_assert_active_admin_2fa_v2(p_actor_user_id);
  if length(v_reason)<20 then raise exception 'F5_6_BATCH_REASON_REQUIRED'; end if;

  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_count_before,v_canon_fp_before
  from public.aos_pacientes p;
  select count(*) into v_events_before from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is null;
  select count(*) into v_applied_before from public.aos_f5_enrichment_preview_v1 where applied_at is not null;

  for r in
    select e.cluster_id,e.field_name,e.generated_at,e.target_patient_id
    from public.aos_f5_enrichment_preview_v1 e
    join public.aos_f5_canonical_classification_v1 c on c.cluster_id=e.cluster_id
    join public.aos_f5_apply_field_policy_v1 fp on fp.field_name=e.field_name
    where e.applied_at is null
      and e.requires_human is true
      and e.canonical_empty is true
      and e.source_distinct_values=1
      and cardinality(e.source_row_ids)>0
      and c.classification='MATCH'
      and c.target_patient_id=e.target_patient_id
      and not c.canonical_dni_conflict and not c.canonical_email_conflict
      and not c.canonical_dob_conflict and not c.canonical_sex_conflict
      and not c.target_missing and not c.target_collision and not c.source_strong_conflict
      and fp.apply_allowed is true and fp.risk_class='LOW'
      and e.field_name in ('Sexo','distrito','departamento','ciudad')
    order by encode(extensions.digest(convert_to(e.target_patient_id||'|'||e.field_name,'UTF8'),'sha256'),'hex')
    limit v_limit
  loop
    v_review:=public.aos_f5_review_enrichment_field_v2(
      r.cluster_id,r.field_name,p_actor_user_id,r.generated_at,'APPROVE_FIELD',v_reason
    );
    select reviewed_at into v_reviewed_at
    from public.aos_f5_enrichment_preview_v1
    where cluster_id=r.cluster_id and field_name=r.field_name;
    if v_reviewed_at is null then raise exception 'F5_6_BATCH_REVIEW_NOT_PERSISTED'; end if;

    v_apply:=public.aos_f5_apply_enrichment_field_v2(
      r.cluster_id,r.field_name,p_actor_user_id,v_reviewed_at,'APPLY','BATCH'
    );
    if coalesce((v_apply->>'ok')::boolean,false) is not true then raise exception 'F5_6_BATCH_APPLY_FAILED'; end if;
    v_processed:=v_processed+1;
  end loop;

  select count(*) into v_events_after from public.aos_f5_canonical_apply_events_v1 where rolled_back_at is null;
  select count(*) into v_applied_after from public.aos_f5_enrichment_preview_v1 where applied_at is not null;
  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_canon_count_after,v_canon_fp_after
  from public.aos_pacientes p;

  if v_canon_count_after<>v_canon_count_before then raise exception 'F5_6_BATCH_PATIENT_COUNT_CHANGED'; end if;
  if v_events_after-v_events_before<>v_processed then raise exception 'F5_6_BATCH_EVENT_DELTA_MISMATCH'; end if;
  if v_applied_after-v_applied_before<>v_processed then raise exception 'F5_6_BATCH_PREVIEW_DELTA_MISMATCH'; end if;
  if exists(
    select 1
    from public.aos_f5_enrichment_preview_v1 e
    join public.aos_f5_canonical_apply_events_v1 ev on ev.id=e.apply_event_id
    where e.applied_at is not null and ev.rolled_back_at is null
      and (e.field_name not in ('Sexo','distrito','departamento','ciudad') or not e.policy_apply_allowed or e.policy_risk_class<>'LOW')
  ) then raise exception 'F5_6_BATCH_POLICY_BOUNDARY_BROKEN'; end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,actor_user_id,details)
  values('LOW_RISK_BATCH_APPLIED','F5','REV-F5.6',p_actor_user_id,jsonb_build_object(
    'processed',v_processed,
    'requested_limit',v_limit,
    'active_events_before',v_events_before,
    'active_events_after',v_events_after,
    'applied_preview_before',v_applied_before,
    'applied_preview_after',v_applied_after,
    'canonical_count',v_canon_count_after,
    'canonical_fp_before',v_canon_fp_before,
    'canonical_fp_after',v_canon_fp_after,
    'policy','LOW_FILL_ONLY',
    'at',now()
  ));

  return jsonb_build_object(
    'ok',true,
    'processed',v_processed,
    'requested_limit',v_limit,
    'active_events_before',v_events_before,
    'active_events_after',v_events_after,
    'applied_preview_before',v_applied_before,
    'applied_preview_after',v_applied_after,
    'canonical_patient_count',v_canon_count_after,
    'canonical_fp_before',v_canon_fp_before,
    'canonical_fp_after',v_canon_fp_after
  );
end
$$;

revoke all on function public.aos_f5_apply_low_risk_batch_v2(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.aos_f5_apply_low_risk_batch_v2(uuid,integer,text) to service_role;

insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
values('LOW_RISK_BATCH_ENGINE_INSTALLED','F5','REV-F5.6',jsonb_build_object(
  'max_batch',50,
  'sequence','REVIEW_THEN_APPLY_PER_FIELD',
  'active_admin_2fa_required',true,
  'allowed_fields',jsonb_build_array('Sexo','distrito','departamento','ciudad'),
  'installed_at',now()
));
