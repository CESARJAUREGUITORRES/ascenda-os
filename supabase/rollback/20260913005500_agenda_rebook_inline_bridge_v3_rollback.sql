-- Rollback Agenda rebook inline bridge V3 to the previous nested bridge.
create or replace function public.aos_agenda_rebook_bridge_v1(
  p_token text,
  p_idempotency_key text,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_result jsonb;
begin
  v_result:=public.aos_agenda_rebook_v2(p_token,p_idempotency_key,p_appointment_id,p_payload);

  if coalesce((v_result->>'ok')::boolean,false)=true then
    return jsonb_set(v_result,'{bridge_mode}','"CORE_V2"'::jsonb,true);
  end if;

  if coalesce(v_result->>'error','')<>'AGV2_REBOOK_TREATMENT_UNRESOLVED' then
    return v_result;
  end if;

  return public.aos_agenda_rebook_legacy_safe_v1(
    p_token,
    left(p_idempotency_key||':legacy',160),
    p_appointment_id,
    p_payload
  );
end
$$;

revoke all on function public.aos_agenda_rebook_bridge_v1(text,text,text,jsonb) from public;
grant execute on function public.aos_agenda_rebook_bridge_v1(text,text,text,jsonb) to anon, authenticated, service_role;
