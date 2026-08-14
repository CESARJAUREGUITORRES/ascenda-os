-- ASCENDA CIA V3 — Phase 11 public dispatcher + assignment consume ACK.
-- Contract compatible with aos_siguiente_lead_v2. Global kill switch defaults OFF.

create or replace function public.aos_siguiente_lead_v3(
  p_asesor text,
  p_id_asesor text,
  p_hoy date
)
returns json
language plpgsql
security definer
set search_path = public
as $function$
declare
  global_on boolean := false;
  advisor_id uuid;
  mode_info jsonb;
  effective_mode text := 'V2_ONLY';
  v3 jsonb;
  v2 jsonb;
  fallback_reason text;
  started_at_ts timestamptz := clock_timestamp();
  elapsed integer;
begin
  select coalesce(global_enabled,false) into global_on
  from public.aos_cia_call_routing_control where id=1;

  -- Absolute kill switch: zero behavior change vs V2.
  if not coalesce(global_on,false) then
    return public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy);
  end if;

  advisor_id := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if advisor_id is null then
    return public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy);
  end if;

  mode_info := public.aos_cia_call_routing_effective_mode_v1(advisor_id);
  effective_mode := coalesce(mode_info->>'effective_mode','V2_ONLY');

  if effective_mode='V2_ONLY' then
    v2 := public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy)::jsonb;
    elapsed := greatest(0,round(extract(epoch from(clock_timestamp()-started_at_ts))*1000)::integer);
    insert into public.aos_cia_call_routing_events(
      event_type,advisor_user_id,routing_mode,route_selected,fallback_reason,latency_ms,payload
    ) values(
      'ROUTE',advisor_id,effective_mode,'V2','ADVISOR_V2_ONLY',elapsed,
      jsonb_build_object('clinic_day',(clock_timestamp() at time zone 'America/Lima')::date,'client_day',p_hoy)
    );
    return (coalesce(v2,'{}'::jsonb) || jsonb_build_object('routingV3',jsonb_build_object(
      'route','V2','mode',effective_mode,'fallbackUsed',false,'reason','ADVISOR_V2_ONLY','latencyMs',elapsed
    )))::json;
  end if;

  v3 := public.aos_cia_call_routing_try_v3_v1(p_asesor,p_id_asesor,p_hoy,effective_mode);
  if coalesce((v3->>'ok')::boolean,false) then
    return v3::json;
  end if;

  fallback_reason := coalesce(v3->>'error','V3_UNAVAILABLE');
  v2 := public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy)::jsonb;
  elapsed := greatest(0,round(extract(epoch from(clock_timestamp()-started_at_ts))*1000)::integer);

  insert into public.aos_cia_call_routing_events(
    event_type,advisor_user_id,routing_mode,route_selected,fallback_reason,latency_ms,payload
  ) values(
    'FALLBACK',advisor_id,effective_mode,'V2',left(fallback_reason,200),elapsed,
    jsonb_build_object(
      'clinic_day',(clock_timestamp() at time zone 'America/Lima')::date,
      'client_day',p_hoy,
      'v3_error',left(coalesce(v3->>'detail',''),300)
    )
  );

  return (coalesce(v2,'{}'::jsonb) || jsonb_build_object('routingV3',jsonb_build_object(
    'route','V2','mode',effective_mode,'fallbackUsed',true,'reason',fallback_reason,'latencyMs',elapsed
  )))::json;
exception when others then
  -- Availability-first rollback: never strand the Call Center because V3 metadata failed.
  begin
    return public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy);
  exception when others then
    return json_build_object('ok',false,'error','ROUTER_V3_AND_V2_FAILED');
  end;
end;
$function$;

create or replace function public.aos_cia_call_routing_consume_v1(
  p_asesor text,
  p_id_asesor text,
  p_assignment_id uuid,
  p_result text,
  p_hoy date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  advisor_id uuid;
  a record;
  tr jsonb;
  result_label text := left(upper(trim(coalesce(p_result,''))),100);
  clinic_day date := (clock_timestamp() at time zone 'America/Lima')::date;
  final_state text;
begin
  if p_assignment_id is null then
    return jsonb_build_object('ok',true,'noop',true,'reason','NO_ASSIGNMENT');
  end if;

  advisor_id := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if advisor_id is null then
    return jsonb_build_object('ok',false,'error','INVALID_ADVISOR_IDENTITY');
  end if;

  select * into a from public.aos_cia_assignments where id=p_assignment_id for update;
  if a.id is null then
    return jsonb_build_object('ok',false,'error','ASSIGNMENT_NOT_FOUND');
  end if;
  if a.advisor_user_id<>advisor_id then
    return jsonb_build_object('ok',false,'error','ASSIGNMENT_ADVISOR_MISMATCH');
  end if;

  if a.state='COMPLETED' then
    delete from public.aos_leads_en_curso
     where upper(trim(asesor))=upper(trim(p_asesor))
       and numero_limpio in (a.contact_key,'51'||a.contact_key)
       and fecha in (clinic_day,p_hoy);
    return jsonb_build_object('ok',true,'assignment_id',a.id,'state','COMPLETED','idempotent',true);
  end if;

  if a.state in ('RELEASED','EXPIRED') then
    delete from public.aos_leads_en_curso
     where upper(trim(asesor))=upper(trim(p_asesor))
       and numero_limpio in (a.contact_key,'51'||a.contact_key)
       and fecha in (clinic_day,p_hoy);
    insert into public.aos_cia_call_routing_events(
      event_type,advisor_user_id,routing_mode,route_selected,assignment_id,plan_id,activation_id,contact_key,payload
    ) values(
      'CONSUME',advisor_id,'V3','V3',a.id,a.plan_id,a.activation_id,a.contact_key,
      jsonb_build_object('result',result_label,'terminal_noop',true,'state',a.state)
    );
    return jsonb_build_object('ok',true,'assignment_id',a.id,'state',a.state,'terminal_noop',true);
  end if;

  if a.state='ASSIGNED' then
    tr := public.aos_cia_assignment_lease_transition_internal_v1(a.id,'START',advisor_id,'CALL_ROUTER_V3_LATE_START');
    if not coalesce((tr->>'ok')::boolean,false) then
      return jsonb_build_object('ok',false,'error','START_FAILED','detail',tr);
    end if;
  elsif a.state<>'IN_PROGRESS' then
    return jsonb_build_object('ok',false,'error','INVALID_ASSIGNMENT_STATE','state',a.state);
  end if;

  tr := public.aos_cia_assignment_lease_transition_internal_v1(
    a.id,'COMPLETE',advisor_id,'CALL_CENTER_RESULT:'||coalesce(nullif(result_label,''),'UNSPECIFIED')
  );
  if not coalesce((tr->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','COMPLETE_FAILED','detail',tr);
  end if;

  final_state := coalesce(tr->>'state','COMPLETED');

  delete from public.aos_leads_en_curso
   where upper(trim(asesor))=upper(trim(p_asesor))
     and numero_limpio in (a.contact_key,'51'||a.contact_key)
     and fecha in (clinic_day,p_hoy);

  insert into public.aos_cia_call_routing_events(
    event_type,advisor_user_id,routing_mode,route_selected,assignment_id,plan_id,activation_id,contact_key,payload
  ) values(
    'CONSUME',advisor_id,'V3','V3',a.id,a.plan_id,a.activation_id,a.contact_key,
    jsonb_build_object('result',result_label,'state',final_state,'clinic_day',clinic_day,'client_day',p_hoy)
  );

  return jsonb_build_object('ok',true,'assignment_id',a.id,'state',final_state,'idempotent',false);
exception when others then
  return jsonb_build_object('ok',false,'error','CONSUME_ERROR','detail',left(sqlerrm,400));
end;
$function$;

revoke execute on function public.aos_siguiente_lead_v3(text,text,date) from public;
revoke execute on function public.aos_cia_call_routing_consume_v1(text,text,uuid,text,date) from public;
grant execute on function public.aos_siguiente_lead_v3(text,text,date) to anon, authenticated, service_role;
grant execute on function public.aos_cia_call_routing_consume_v1(text,text,uuid,text,date) to anon, authenticated, service_role;
