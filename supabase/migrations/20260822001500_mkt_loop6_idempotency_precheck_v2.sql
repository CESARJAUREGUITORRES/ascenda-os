-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6 V2
-- Retry/idempotency hardening: resolve an existing action journal entry before
-- re-evaluating patient state, active appointment or ownership policy.

alter function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  rename to aos_callcenter_commit_action_core_impl_v2;

revoke all on function public.aos_callcenter_commit_action_core_impl_v2(uuid,text,text,jsonb,text)
  from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_action_core_impl_v2(uuid,text,text,jsonb,text)
  to service_role;

create or replace function public.aos_callcenter_commit_action_core_v1(
  p_actor uuid,
  p_idempotency_key text,
  p_action_type text,
  p_payload jsonb,
  p_test_fail_stage text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_key text:=pg_catalog.btrim(coalesce(p_idempotency_key,''));
  v_action text:=upper(pg_catalog.btrim(coalesce(p_action_type,'')));
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_source_mode text:=upper(pg_catalog.btrim(coalesce(v_payload->>'source_mode','QUEUE')));
  v_num text:=pg_catalog.regexp_replace(coalesce(v_payload->>'numero',''),'[^0-9]','','g');
  v_hash text;
  v_existing record;
begin
  if p_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if pg_catalog.length(v_key)<16 or pg_catalog.length(v_key)>160 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY'); end if;
  if v_action not in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT','REACTIVATION','PATIENT_FOLLOWUP','AGENDA_ONLY') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTION');
  end if;
  if v_source_mode not in ('QUEUE','MANUAL','CALLBACK','FOLLOWUP') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_SOURCE_MODE');
  end if;
  if pg_catalog.length(v_num)<7 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE'); end if;

  v_hash:=pg_catalog.encode(
    extensions.digest(v_action||'|'||(v_payload-'event_ts'-'business_date')::text,'sha256'),
    'hex'
  );

  select * into v_existing
  from public.aos_callcenter_actions_v1 a
  where a.idempotency_key=v_key;

  if found then
    if v_existing.actor_user_id<>p_actor then
      return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_ACTOR_CONFLICT');
    end if;
    if v_existing.request_hash<>v_hash then
      return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT');
    end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then
      return v_existing.result||pg_catalog.jsonb_build_object('idempotent',true);
    end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;

  return public.aos_callcenter_commit_action_core_impl_v2(
    p_actor,p_idempotency_key,p_action_type,p_payload,p_test_fail_stage
  );
end
$function$;

revoke all on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  to service_role;
