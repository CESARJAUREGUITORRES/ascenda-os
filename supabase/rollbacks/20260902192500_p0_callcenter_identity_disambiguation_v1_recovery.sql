-- ASCENDA OS · P0 Call Center Identity Disambiguation V1 · RECOVERY
-- Restore the exact pre-P0 public prepare/commit routing and remove additive helpers.

create or replace function public.aos_callcenter_prepare_action_v1(p_token text,p_numero text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare v_actor uuid;v_state jsonb;v_user record;v_allowed jsonb;begin v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false);if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true);end if;if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');end if;select u.nombre,u.apellidos,u.codigo_asesor,u.rol into v_user from public.aos_usuarios u where u.id=v_actor and u.activo=true limit 1;v_state:=public.aos_callcenter_credit_context_v2(p_numero,pg_catalog.now());if coalesce((v_state->>'ok')::boolean,false)=false then return v_state||pg_catalog.jsonb_build_object('actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor);end if;if v_state->>'patientState'='CONVERTED_PATIENT' then v_allowed:='["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb;else v_allowed:='["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb;end if;return v_state||pg_catalog.jsonb_build_object('actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor,'allowedActions',v_allowed);end $function$;

revoke all on function public.aos_callcenter_prepare_action_v1(text,text) from public;
grant execute on function public.aos_callcenter_prepare_action_v1(text,text) to anon,authenticated,service_role;

create or replace function public.aos_callcenter_commit_action_v1(
  p_token text,
  p_idempotency_key text,
  p_action_type text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare v_actor uuid;v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false); if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true); end if;
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  v_payload:=(v_payload-'event_ts'-'business_date')||pg_catalog.jsonb_build_object('event_ts',pg_catalog.now());
  return public.aos_callcenter_commit_action_core_v1(v_actor,p_idempotency_key,p_action_type,v_payload,null);
end $function$;

revoke all on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) from public;
grant execute on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) to anon,authenticated,service_role;

drop function if exists public.aos_callcenter_commit_manual_agenda_selected_v1(uuid,text,jsonb);
drop function if exists public.aos_callcenter_selected_active_appointment_v1(text,text,timestamptz);
drop function if exists public.aos_callcenter_manual_agenda_identity_v1(text,jsonb);
