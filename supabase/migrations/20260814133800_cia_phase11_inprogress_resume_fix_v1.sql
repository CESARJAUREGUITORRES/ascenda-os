-- Phase 11 correction: once a lease is IN_PROGRESS, F9 ownership is authoritative.
-- F8 availability is revalidated for new ASSIGNED claims only.

create or replace function public.aos_cia_call_routing_try_v3_v1(
  p_asesor text,
  p_id_asesor text,
  p_hoy date,
  p_mode text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  advisor_id uuid;
  readiness jsonb;
  effective_day date := (clock_timestamp() at time zone 'America/Lima')::date;
  cand record;
  picked record;
  transition_result jsonb;
  lead_row record;
  last_call record;
  attempts integer := 1;
  context_json jsonb := null;
  response_json jsonb;
  started_at_ts timestamptz := clock_timestamp();
  elapsed integer;
  candidate_found boolean := false;
begin
  advisor_id := public.aos_cia_call_routing_resolve_advisor_v1(p_asesor,p_id_asesor);
  if advisor_id is null then return jsonb_build_object('ok',false,'error','INVALID_ADVISOR_IDENTITY'); end if;

  readiness := public.aos_cia_advisor_control_f11_readiness_v1();
  if not coalesce((readiness->>'f11_engineering_ready')::boolean,false) then
    return jsonb_build_object('ok',false,'error','F11_READINESS_BLOCKED','readiness',readiness);
  end if;

  for cand in
    select x.id,x.plan_id,x.activation_id,x.contact_key,x.advisor_user_id,x.state,x.source_rank,
           x.assigned_at,x.must_start_before,x.expires_at
    from public.aos_cia_assignments x
    join public.aos_cia_assignment_plans p on p.id=x.plan_id and p.state='ACTIVE'
    join public.aos_audiencia_activacion_estado s on s.activacion_id=x.activation_id and s.estado='ACTIVE'
    join public.aos_audiencia_activacion_context ac on ac.activation_id=x.activation_id
    join public.aos_cia_context_policies cp on cp.policy_key=ac.policy_key and cp.version=ac.policy_version
    where x.advisor_user_id=advisor_id
      and x.state in ('IN_PROGRESS','ASSIGNED')
      and x.expires_at>clock_timestamp()
      and cp.channel='CALL' and cp.status='ACTIVE'
      and not exists(
        select 1 from public.aos_leads_en_curso lc
        where lc.fecha=effective_day
          and lc.numero_limpio in (x.contact_key,'51'||x.contact_key)
          and upper(trim(lc.asesor))<>upper(trim(p_asesor))
      )
    order by case when x.state='IN_PROGRESS' then 0 else 1 end,
             x.must_start_before asc,x.source_rank asc,x.assigned_at asc,x.id
    for update of x skip locked
    limit 8
  loop
    -- Existing work belongs to the advisor until terminal/released/expired.
    -- Only a not-yet-started ASSIGNED lease must still be available in F8.
    if cand.state='IN_PROGRESS' or exists(
      select 1 from public.aos_cia_activation_available_keys_v1(cand.activation_id) k
      where k.contact_key=cand.contact_key
    ) then
      perform pg_advisory_xact_lock(hashtextextended(cand.contact_key,911));
      if exists(
        select 1 from public.aos_leads_en_curso lc
        where lc.fecha=effective_day
          and lc.numero_limpio in (cand.contact_key,'51'||cand.contact_key)
          and upper(trim(lc.asesor))<>upper(trim(p_asesor))
      ) then continue; end if;
      picked := cand; candidate_found := true; exit;
    end if;
  end loop;

  if not candidate_found then
    return jsonb_build_object('ok',false,'error','NO_V3_AVAILABLE_ASSIGNMENT','advisor_user_id',advisor_id);
  end if;

  if picked.state='ASSIGNED' then
    transition_result := public.aos_cia_assignment_lease_transition_internal_v1(picked.id,'START',advisor_id,'CALL_ROUTER_V3_CLAIM');
    if not coalesce((transition_result->>'ok')::boolean,false) then
      return jsonb_build_object('ok',false,'error','ASSIGNMENT_START_FAILED','detail',transition_result);
    end if;
  end if;

  select ld.id,ld.numero_limpio,coalesce(ld.tratamiento,'') tratamiento,coalesce(ld.anuncio,'') anuncio,ld.fecha,ld.hora_ingreso
  into lead_row from public.aos_leads ld
  where ld.numero_limpio in (picked.contact_key,'51'||picked.contact_key)
  order by ld.fecha desc,ld.hora_ingreso desc nulls last,ld.id desc limit 1;

  select count(*)::integer+1 into attempts from public.aos_llamadas ll
  where ll.numero_limpio in (picked.contact_key,'51'||picked.contact_key);

  select ll.fecha,ll.estado,ll.asesor,ll.observacion,ll.intento into last_call
  from public.aos_llamadas ll where ll.numero_limpio in (picked.contact_key,'51'||picked.contact_key)
  order by coalesce(ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc limit 1;

  if last_call.fecha is not null then
    context_json := jsonb_build_object('ultimaLlamada',jsonb_build_object(
      'fecha',last_call.fecha,'estado',last_call.estado,'asesor',last_call.asesor,
      'obs',coalesce(last_call.observacion,''),'intento',last_call.intento));
  end if;

  insert into public.aos_leads_en_curso(asesor,numero_limpio,fecha,lead_id_origen)
  values(upper(trim(p_asesor)),picked.contact_key,effective_day,lead_row.id)
  on conflict(asesor,numero_limpio,fecha) do update
    set asignado_at=clock_timestamp(),lead_id_origen=coalesce(excluded.lead_id_origen,public.aos_leads_en_curso.lead_id_origen);

  elapsed := greatest(0,round(extract(epoch from(clock_timestamp()-started_at_ts))*1000)::integer);
  response_json := jsonb_build_object(
    'ok',true,
    'lead',jsonb_build_object('id',lead_row.id,'num',picked.contact_key,'trat',coalesce(lead_row.tratamiento,''),
      'anuncio',coalesce(lead_row.anuncio,''),'fecha',coalesce(lead_row.fecha,effective_day),'hora_ingreso',lead_row.hora_ingreso,
      'intento',coalesce(attempts,1),'rowNum',0,'attributionSource','CIA_ASSIGNMENT_V3','assignmentId',picked.id),
    'tier',case when picked.state='IN_PROGRESS' then 'V3 · EN CURSO' else 'V3 · ASIGNADO' end,
    'tierNum',0,'fromSupabase',true,'colaConfig','cia_v3','contexto',context_json,
    'routingV3',jsonb_build_object('route','V3','mode',upper(coalesce(p_mode,'V3_CANARY')),'fallbackUsed',false,
      'assignmentId',picked.id,'planId',picked.plan_id,'activationId',picked.activation_id,'advisorUserId',advisor_id,
      'contactKey',picked.contact_key,'state','IN_PROGRESS','sourceRank',picked.source_rank,
      'mustStartBefore',picked.must_start_before,'expiresAt',picked.expires_at,'clinicDay',effective_day,'clientDay',p_hoy,'latencyMs',elapsed)
  );

  insert into public.aos_cia_call_routing_events(event_type,advisor_user_id,routing_mode,route_selected,assignment_id,plan_id,activation_id,contact_key,latency_ms,payload)
  values('CLAIM',advisor_id,upper(coalesce(p_mode,'V3_CANARY')),'V3',picked.id,picked.plan_id,picked.activation_id,picked.contact_key,elapsed,
    jsonb_build_object('clinic_day',effective_day,'client_day',p_hoy,'previous_state',picked.state,'resume',picked.state='IN_PROGRESS'));
  return response_json;
exception when others then
  return jsonb_build_object('ok',false,'error','V3_CORE_ERROR','detail',left(sqlerrm,400));
end;
$function$;

revoke execute on function public.aos_cia_call_routing_try_v3_v1(text,text,date,text) from public, anon, authenticated;
grant execute on function public.aos_cia_call_routing_try_v3_v1(text,text,date,text) to service_role;
