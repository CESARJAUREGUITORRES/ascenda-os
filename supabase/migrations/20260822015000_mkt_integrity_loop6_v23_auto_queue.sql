-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6 V2.3
-- Server-authoritative queue confirmation. No browser-selected commercial action type.

create or replace function public.aos_callcenter_confirm_queue_core_v1(
  p_actor uuid,
  p_idempotency_key text,
  p_payload jsonb,
  p_test_fail_stage text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_num text := pg_catalog.regexp_replace(coalesce(v_payload->>'numero',''),'[^0-9]','','g');
  v_lead_id bigint;
  v_followup_id text := nullif(pg_catalog.btrim(coalesce(v_payload->>'followup_id','')),'');
  v_action text;
  v_source_mode text;
  v_event_ts timestamptz := coalesce(nullif(v_payload->>'event_ts','')::timestamptz,pg_catalog.now());
  v_user record;
  v_lead record;
  v_followup record;
  v_result jsonb;
begin
  if p_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  if pg_catalog.length(v_num) < 7 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE');
  end if;

  begin
    v_lead_id := nullif(v_payload->>'lead_id','')::bigint;
  exception when others then
    v_lead_id := null;
  end;
  if v_lead_id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','QUEUE_LEAD_REQUIRED');
  end if;

  select u.nombre,u.codigo_asesor,u.rol
    into v_user
  from public.aos_usuarios u
  where u.id=p_actor and u.activo=true
  limit 1;
  if v_user.nombre is null or v_user.codigo_asesor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTOR');
  end if;

  select t.lead_id,t.numero_limpio,t.tratamiento,t.anuncio,t.lead_ts
    into v_lead
  from public.aos_marketing_touchpoints_v2(null,null) t
  where t.lead_id=v_lead_id
    and t.numero_limpio=v_num
    and not t.es_duplicado_tecnico_probable
    and t.lead_ts<=v_event_ts
  order by t.lead_ts desc
  limit 1;
  if v_lead.lead_id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','QUEUE_LEAD_MISMATCH','leadId',v_lead_id,'numero',v_num);
  end if;

  if v_followup_id is not null then
    select s."ID",pg_catalog.regexp_replace(coalesce(s."NUMERO",''),'[^0-9]','','g') numero_limpio,
           upper(coalesce(s."ASESOR",'')) asesor,s."ID_ASESOR" id_asesor,s.lead_id_origen
      into v_followup
    from public.aos_seguimientos s
    where s."ID"=v_followup_id
    limit 1;
    if v_followup."ID" is null then
      return pg_catalog.jsonb_build_object('ok',false,'error','FOLLOWUP_NOT_FOUND');
    end if;
    if v_followup.numero_limpio<>v_num then
      return pg_catalog.jsonb_build_object('ok',false,'error','FOLLOWUP_PHONE_MISMATCH');
    end if;
    if v_followup.lead_id_origen is not null and v_followup.lead_id_origen<>v_lead_id then
      return pg_catalog.jsonb_build_object('ok',false,'error','FOLLOWUP_LEAD_MISMATCH');
    end if;
    if coalesce(v_followup.id_asesor,'')<>coalesce(v_user.codigo_asesor,'')
       and upper(coalesce(v_followup.asesor,''))<>upper(coalesce(v_user.nombre,'')) then
      return pg_catalog.jsonb_build_object('ok',false,'error','FOLLOWUP_NOT_OWNED');
    end if;
    v_action := 'CALLBACK_INBOUND_APPOINTMENT';
    v_source_mode := 'FOLLOWUP';
  else
    v_action := 'COMMERCIAL_CALL_APPOINTMENT';
    v_source_mode := 'QUEUE';
  end if;

  -- Browser cannot choose source/action. Keep only server-derived values.
  v_payload := (v_payload - 'source_mode' - 'event_ts' - 'business_date')
    || pg_catalog.jsonb_build_object(
         'numero',v_num,
         'lead_id',v_lead_id,
         'source_mode',v_source_mode,
         'event_ts',v_event_ts,
         'anuncio',coalesce(v_lead.anuncio,v_payload->>'anuncio',''),
         'tratamiento',coalesce(nullif(v_payload->>'tratamiento',''),v_lead.tratamiento,'')
       );

  v_result := public.aos_callcenter_commit_action_core_v1(
    p_actor,p_idempotency_key,v_action,v_payload,p_test_fail_stage
  );
  if coalesce((v_result->>'ok')::boolean,false) then
    return v_result || pg_catalog.jsonb_build_object(
      'queueAuto',true,
      'derivedAction',v_action,
      'queueLeadId',v_lead_id,
      'queueSourceMode',v_source_mode
    );
  end if;
  return v_result || pg_catalog.jsonb_build_object(
    'queueAuto',true,
    'derivedAction',v_action,
    'queueLeadId',v_lead_id,
    'queueSourceMode',v_source_mode
  );
end
$function$;

create or replace function public.aos_callcenter_confirm_queue_appointment_v1(
  p_token text,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then
    v_actor := public.aos_app_actor_v3(p_token,'admin-calls',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  -- Production event time is authoritative server time.
  v_payload := (v_payload - 'event_ts' - 'business_date')
    || pg_catalog.jsonb_build_object('event_ts',pg_catalog.now());
  return public.aos_callcenter_confirm_queue_core_v1(v_actor,p_idempotency_key,v_payload,null);
end
$function$;

revoke all on function public.aos_callcenter_confirm_queue_core_v1(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.aos_callcenter_confirm_queue_core_v1(uuid,text,jsonb,text) to service_role;

revoke all on function public.aos_callcenter_confirm_queue_appointment_v1(text,text,jsonb) from public;
grant execute on function public.aos_callcenter_confirm_queue_appointment_v1(text,text,jsonb) to anon,authenticated,service_role;
