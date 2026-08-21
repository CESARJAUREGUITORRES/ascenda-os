-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6
-- Explicit Call Center semantics + F6 patient state + atomic Call↔Agenda + durable idempotency.

create table if not exists public.aos_callcenter_actions_v1 (
  idempotency_key text primary key,
  request_hash text not null,
  actor_user_id uuid not null,
  asesor text not null,
  id_asesor text,
  numero_limpio text not null,
  action_type text not null,
  source_mode text not null default 'QUEUE',
  patient_state text,
  identity_status text,
  canonical_patient_id text,
  lead_id_origen bigint,
  origen text,
  llamada_id bigint,
  agenda_id text,
  status text not null default 'PROCESSING',
  result jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint aos_callcenter_actions_v1_action_ck check (action_type in (
    'COMMERCIAL_CALL_APPOINTMENT',
    'CALLBACK_INBOUND_APPOINTMENT',
    'REACTIVATION',
    'PATIENT_FOLLOWUP',
    'AGENDA_ONLY'
  )),
  constraint aos_callcenter_actions_v1_status_ck check (status in ('PROCESSING','COMPLETE','ERROR'))
);

create index if not exists idx_aos_callcenter_actions_v1_created
  on public.aos_callcenter_actions_v1(created_at desc);
create index if not exists idx_aos_callcenter_actions_v1_num
  on public.aos_callcenter_actions_v1(numero_limpio,created_at desc);

revoke all on table public.aos_callcenter_actions_v1 from public, anon, authenticated;
grant select,insert,update on table public.aos_callcenter_actions_v1 to service_role;

create or replace function public.aos_callcenter_patient_state_v1(
  p_numero text,
  p_event_ts timestamptz default now()
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_num text := pg_catalog.regexp_replace(coalesce(p_numero,''),'[^0-9]','','g');
  v_event_ts timestamptz := coalesce(p_event_ts,pg_catalog.now());
  v_day date := (v_event_ts at time zone 'America/Lima')::date;
  v_identity jsonb;
  v_lifecycle jsonb;
  v_identity_status text;
  v_canonical text;
  v_sale boolean := false;
  v_attention boolean := false;
  v_attended boolean := false;
  v_historical boolean := false;
  v_last_sale jsonb;
  v_last_attention jsonb;
  v_last_attended jsonb;
  v_state text;
begin
  if pg_catalog.length(v_num) < 7 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE','patientState','REVIEW');
  end if;

  v_identity := public.aos_rev_resolve_patient_identity_v2('PHONE',v_num);
  v_identity_status := coalesce(v_identity->>'status','UNRESOLVED');
  v_canonical := v_identity->>'canonical_patient_id';

  if v_identity_status='IDENTITY_CONFLICT' then
    return pg_catalog.jsonb_build_object(
      'ok',false,'error','IDENTITY_CONFLICT','identity',v_identity,
      'identityStatus',v_identity_status,'patientState','REVIEW','converted',false
    );
  end if;

  if v_identity_status='MATCH' then
    v_lifecycle := public.aos_rev_customer_lifecycle_v1('PHONE',v_num,v_day);
  else
    v_lifecycle := null;
  end if;

  select pg_catalog.jsonb_build_object(
           'fecha',v.fecha,'monto',v.monto,'tratamiento',v.tratamiento,
           'asesor',v.asesor,'created_at',v.created_at
         )
    into v_last_sale
  from public.aos_ventas v
  where v.numero_limpio=v_num
    and (
      v.fecha < v_day
      or (v.fecha=v_day and v.created_at is not null and v.created_at < v_event_ts)
    )
  order by v.fecha desc,v.created_at desc nulls last,v.id desc
  limit 1;
  v_sale := v_last_sale is not null;

  select pg_catalog.jsonb_build_object(
           'fecha',a.fecha,'estado',a.estado,'tratamiento',a.tratamiento_principal,
           'created_at',a.created_at
         )
    into v_last_attention
  from public.aos_atenciones a
  where a.numero_limpio=v_num
    and (
      a.fecha < v_day
      or (a.fecha=v_day and a.created_at is not null and a.created_at < v_event_ts)
    )
  order by a.fecha desc,a.created_at desc nulls last,a.id desc
  limit 1;
  v_attention := v_last_attention is not null;

  select pg_catalog.jsonb_build_object(
           'fecha',a.fecha_cita,'estado',a.estado_cita,'tratamiento',a.tratamiento,
           'asesor',a.asesor,'ts_actualizado',a.ts_actualizado,'ts_creado',a.ts_creado
         )
    into v_last_attended
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA')
    and (
      a.fecha_cita < v_day
      or (
        a.fecha_cita=v_day
        and coalesce(a.ts_actualizado,a.ts_creado) is not null
        and coalesce(a.ts_actualizado,a.ts_creado) < v_event_ts
      )
    )
  order by a.fecha_cita desc,coalesce(a.ts_actualizado,a.ts_creado) desc nulls last,a.id desc
  limit 1;
  v_attended := v_last_attended is not null;

  select exists(
    select 1 from public.aos_leads l
    where l.numero_limpio=v_num
      and coalesce(l.hora_ingreso,l.created_at,(l.fecha::timestamp at time zone 'America/Lima')) < v_event_ts
  ) or exists(
    select 1 from public.aos_llamadas l
    where l.numero_limpio=v_num
      and coalesce(l.created_at,l.ult_ts,l.ts_log,(l.fecha::timestamp at time zone 'America/Lima')) < v_event_ts
  ) or exists(
    select 1 from public.aos_agenda_citas a
    where a.numero_limpio=v_num and coalesce(a.ts_creado,(a.fecha_cita::timestamp at time zone 'America/Lima')) < v_event_ts
  ) into v_historical;

  if v_sale or v_attention or v_attended then
    v_state := 'CONVERTED_PATIENT';
  elsif v_identity_status='MATCH' or v_historical then
    v_state := 'HISTORICAL_PROSPECT';
  else
    v_state := 'PROSPECT';
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'numero',v_num,
    'eventTs',v_event_ts,
    'businessDate',v_day,
    'identityStatus',v_identity_status,
    'canonicalPatientId',v_canonical,
    'patientState',v_state,
    'converted',(v_state='CONVERTED_PATIENT'),
    'identity',v_identity,
    'lifecycle',v_lifecycle,
    'evidence',pg_catalog.jsonb_build_object(
      'priorSale',v_sale,
      'priorAttention',v_attention,
      'priorAttendedAppointment',v_attended,
      'lastSale',v_last_sale,
      'lastAttention',v_last_attention,
      'lastAttendedAppointment',v_last_attended
    )
  );
end
$function$;

revoke all on function public.aos_callcenter_patient_state_v1(text,timestamptz) from public, anon, authenticated;
grant execute on function public.aos_callcenter_patient_state_v1(text,timestamptz) to service_role;

create or replace function public.aos_callcenter_prepare_action_v1(
  p_token text,
  p_numero text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_state jsonb;
  v_user record;
  v_allowed jsonb;
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then
    v_actor := public.aos_app_actor_v3(p_token,'admin-calls',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  select u.nombre,u.apellidos,u.codigo_asesor,u.rol into v_user
  from public.aos_usuarios u where u.id=v_actor and u.activo=true limit 1;

  v_state := public.aos_callcenter_patient_state_v1(p_numero,pg_catalog.now());
  if coalesce((v_state->>'ok')::boolean,false)=false then
    return v_state || pg_catalog.jsonb_build_object(
      'actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor
    );
  end if;

  if v_state->>'patientState'='CONVERTED_PATIENT' then
    v_allowed := '["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb;
  else
    v_allowed := '["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb;
  end if;

  return v_state || pg_catalog.jsonb_build_object(
    'actorUserId',v_actor,
    'asesor',upper(coalesce(v_user.nombre,'')),
    'idAsesor',v_user.codigo_asesor,
    'allowedActions',v_allowed
  );
end
$function$;

revoke all on function public.aos_callcenter_prepare_action_v1(text,text) from public;
grant execute on function public.aos_callcenter_prepare_action_v1(text,text) to anon, authenticated, service_role;

create or replace function public.aos_callcenter_commit_action_core_v1(
  p_actor uuid,
  p_idempotency_key text,
  p_action_type text,
  p_payload jsonb,
  p_test_fail_stage text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_key text := pg_catalog.btrim(coalesce(p_idempotency_key,''));
  v_action text := upper(pg_catalog.btrim(coalesce(p_action_type,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_source_mode text := upper(pg_catalog.btrim(coalesce(v_payload->>'source_mode','QUEUE')));
  v_num text := pg_catalog.regexp_replace(coalesce(v_payload->>'numero',''),'[^0-9]','','g');
  v_event_ts timestamptz := coalesce(nullif(v_payload->>'event_ts','')::timestamptz,pg_catalog.now());
  v_day date := (v_event_ts at time zone 'America/Lima')::date;
  v_hash text;
  v_inserted boolean := false;
  v_existing record;
  v_user record;
  v_state jsonb;
  v_patient_state text;
  v_identity_status text;
  v_canonical text;
  v_is_converted boolean := false;
  v_need_call boolean := false;
  v_need_agenda boolean := false;
  v_call_state text;
  v_sub_state text;
  v_tipo_gestion text;
  v_origin text;
  v_agenda_origin text;
  v_lead_id bigint;
  v_lead_anuncio text;
  v_lead_trat text;
  v_explicit_lead bigint;
  v_prior_count integer := 0;
  v_match_count integer := 0;
  v_treatment text := pg_catalog.btrim(coalesce(v_payload->>'tratamiento',''));
  v_attempt integer := 1;
  v_call_id bigint;
  v_call_actual_state text;
  v_call_actual_type text;
  v_call_actual_origin text;
  v_call_actual_lead bigint;
  v_agenda_id text;
  v_fecha_cita date;
  v_hora_cita text;
  v_result jsonb;
  v_fail text := upper(pg_catalog.btrim(coalesce(p_test_fail_stage,'')));
begin
  if p_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  if pg_catalog.length(v_key)<16 or pg_catalog.length(v_key)>160 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY');
  end if;
  if v_action not in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT','REACTIVATION','PATIENT_FOLLOWUP','AGENDA_ONLY') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTION');
  end if;
  if v_source_mode not in ('QUEUE','MANUAL','CALLBACK','FOLLOWUP') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_SOURCE_MODE');
  end if;
  if pg_catalog.length(v_num)<7 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE');
  end if;

  select u.nombre,u.apellidos,u.codigo_asesor,u.rol,u.paneles_acceso into v_user
  from public.aos_usuarios u where u.id=p_actor and u.activo=true limit 1;
  if v_user.nombre is null or v_user.codigo_asesor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTOR');
  end if;

  v_state := public.aos_callcenter_patient_state_v1(v_num,v_event_ts);
  if coalesce((v_state->>'ok')::boolean,false)=false then
    return v_state;
  end if;
  v_patient_state := v_state->>'patientState';
  v_identity_status := v_state->>'identityStatus';
  v_canonical := v_state->>'canonicalPatientId';
  v_is_converted := coalesce((v_state->>'converted')::boolean,false);

  if v_identity_status='IDENTITY_CONFLICT' or v_patient_state='REVIEW' then
    return pg_catalog.jsonb_build_object('ok',false,'error','IDENTITY_CONFLICT','patient',v_state);
  end if;
  if v_is_converted and v_action in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT') then
    return pg_catalog.jsonb_build_object('ok',false,'error','PATIENT_ACTION_REQUIRED','patient',v_state,
      'allowedActions','["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb);
  end if;
  if not v_is_converted and v_action in ('REACTIVATION','PATIENT_FOLLOWUP') then
    return pg_catalog.jsonb_build_object('ok',false,'error','PATIENT_NOT_CONVERTED','patient',v_state,
      'allowedActions','["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb);
  end if;

  v_need_call := v_action<>'AGENDA_ONLY';
  v_need_agenda := v_action<>'PATIENT_FOLLOWUP' or nullif(v_payload->>'fecha_cita','') is not null;

  if v_need_agenda then
    begin
      v_fecha_cita := nullif(v_payload->>'fecha_cita','')::date;
    exception when others then
      return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_APPOINTMENT_DATE');
    end;
    v_hora_cita := pg_catalog.btrim(coalesce(v_payload->>'hora_cita',''));
    if v_fecha_cita is null or v_hora_cita='' then
      return pg_catalog.jsonb_build_object('ok',false,'error','APPOINTMENT_REQUIRED');
    end if;
  end if;

  if v_action='COMMERCIAL_CALL_APPOINTMENT' then
    v_call_state := 'CITA CONFIRMADA';
    v_sub_state := null;
    v_tipo_gestion := case when v_source_mode='MANUAL' then 'LLAMADA_MANUAL_COMERCIAL' else 'LLAMADA' end;
    v_agenda_origin := case when v_source_mode='MANUAL' then 'CITA_MANUAL' else 'CALL_CENTER' end;
  elsif v_action='CALLBACK_INBOUND_APPOINTMENT' then
    v_call_state := 'CITA CONFIRMADA';
    v_sub_state := 'CALLBACK_INBOUND';
    v_tipo_gestion := 'CALLBACK_INBOUND';
    v_agenda_origin := 'CALL_CENTER';
  elsif v_action='REACTIVATION' then
    v_call_state := 'SEGUIMIENTO';
    v_sub_state := 'REACTIVACION';
    v_tipo_gestion := 'REACTIVACION';
    v_agenda_origin := 'CALL_CENTER_REACTIVACION';
  elsif v_action='PATIENT_FOLLOWUP' then
    v_call_state := 'SEGUIMIENTO';
    v_sub_state := 'PACIENTE';
    v_tipo_gestion := 'SEGUIMIENTO_PACIENTE';
    v_agenda_origin := 'CALL_CENTER_SEGUIMIENTO';
  else
    v_agenda_origin := 'CALL_CENTER_SOLO_AGENDAR';
  end if;

  -- Only prospect commercial/callback actions may bind a Marketing lead.
  if not v_is_converted and v_action in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT') then
    begin v_explicit_lead := nullif(v_payload->>'lead_id','')::bigint; exception when others then v_explicit_lead:=null; end;

    if v_explicit_lead is not null then
      select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio
      from public.aos_marketing_touchpoints_v2(null,null) t
      where t.lead_id=v_explicit_lead and t.numero_limpio=v_num
        and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts
      limit 1;
    end if;

    if v_lead_id is null then
      select count(*) into v_prior_count
      from public.aos_marketing_touchpoints_v2(null,null) t
      where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts;

      if v_prior_count>0 and nullif(v_treatment,'') is not null then
        select count(*) into v_match_count
        from public.aos_marketing_touchpoints_v2(null,null) t
        where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts
          and pg_catalog.regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=
              pg_catalog.regexp_replace(upper(v_treatment),'[^A-Z0-9]+','','g');
        if v_match_count>0 then
          select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio
          from public.aos_marketing_touchpoints_v2(null,null) t
          where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts
            and pg_catalog.regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=
                pg_catalog.regexp_replace(upper(v_treatment),'[^A-Z0-9]+','','g')
          order by t.lead_ts desc,t.lead_id desc limit 1;
        end if;
      elsif v_prior_count>0 then
        select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio
        from public.aos_marketing_touchpoints_v2(null,null) t
        where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts
        order by t.lead_ts desc,t.lead_id desc limit 1;
      end if;
    end if;

    if v_lead_id is not null then
      v_origin := 'MARKETING';
    elsif v_prior_count>0 then
      v_origin := 'MARKETING_REVIEW';
    else
      v_origin := 'ORGANICO';
    end if;
  else
    v_lead_id := null;
    v_origin := case when v_is_converted then 'PACIENTE_EXISTENTE' else 'ORGANICO' end;
  end if;

  v_hash := pg_catalog.encode(extensions.digest(
    v_action||'|'||(v_payload - 'event_ts' - 'business_date')::text,'sha256'
  ),'hex');

  insert into public.aos_callcenter_actions_v1(
    idempotency_key,request_hash,actor_user_id,asesor,id_asesor,numero_limpio,
    action_type,source_mode,patient_state,identity_status,canonical_patient_id,
    lead_id_origen,origen,status,created_at,updated_at
  ) values (
    v_key,v_hash,p_actor,upper(v_user.nombre),v_user.codigo_asesor,v_num,
    v_action,v_source_mode,v_patient_state,v_identity_status,v_canonical,
    v_lead_id,v_origin,'PROCESSING',v_event_ts,pg_catalog.now()
  ) on conflict(idempotency_key) do nothing
  returning true into v_inserted;

  if not coalesce(v_inserted,false) then
    select * into v_existing from public.aos_callcenter_actions_v1 a
    where a.idempotency_key=v_key for update;
    if v_existing.request_hash<>v_hash then
      return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT');
    end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then
      return v_existing.result || pg_catalog.jsonb_build_object('idempotent',true);
    end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;

  if v_need_call then
    select count(*)::integer+1 into v_attempt from public.aos_llamadas l where l.numero_limpio=v_num;
    insert into public.aos_llamadas(
      fecha,numero,numero_limpio,tratamiento,estado,sub_estado,observacion,hora_llamada,
      asesor,id_asesor,anuncio,origen,intento,created_at,duracion_seg,tipo_gestion,
      desde_dispositivo,lead_id_origen
    ) values (
      v_day,v_num,v_num,coalesce(nullif(v_treatment,''),v_lead_trat,''),v_call_state,v_sub_state,
      coalesce(v_payload->>'obs',''),to_char(v_event_ts at time zone 'America/Lima','HH24:MI:SS'),
      upper(v_user.nombre),v_user.codigo_asesor,coalesce(v_lead_anuncio,v_payload->>'anuncio',''),v_origin,
      v_attempt,v_event_ts,greatest(0,coalesce(nullif(v_payload->>'duracion_seg','')::integer,0)),
      v_tipo_gestion,coalesce(nullif(v_payload->>'desde_dispositivo',''),'web'),v_lead_id
    ) returning id,estado,tipo_gestion,origen,lead_id_origen
      into v_call_id,v_call_actual_state,v_call_actual_type,v_call_actual_origin,v_call_actual_lead;

    if v_call_id is null then
      raise exception 'CALL_INSERT_SUPPRESSED';
    end if;
    if v_fail='AFTER_CALL' then
      raise exception 'LOOP6_TEST_FAIL_AFTER_CALL';
    end if;
  end if;

  if v_need_agenda then
    v_agenda_id := pg_catalog.gen_random_uuid()::text;
    insert into public.aos_agenda_citas(
      id,fecha_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,nombre,apellido,dni,correo,
      asesor,id_asesor,estado_cita,obs,ts_creado,hora_cita,doctora,tipo_atencion,origen_cita,origen,
      lead_id_origen,llamada_id_origen
    ) values (
      v_agenda_id,v_fecha_cita,v_treatment,coalesce(nullif(v_payload->>'tipo_cita',''),'CONSULTA NUEVA'),
      coalesce(v_payload->>'sede',''),v_num,v_num,coalesce(v_payload->>'nombre',''),coalesce(v_payload->>'apellido',''),
      coalesce(v_payload->>'dni',''),coalesce(v_payload->>'correo',''),upper(v_user.nombre),v_user.codigo_asesor,
      'PENDIENTE',coalesce(v_payload->>'obs',''),v_event_ts,v_hora_cita,coalesce(v_payload->>'doctora',''),
      coalesce(v_payload->>'tipo_atencion',''),v_agenda_origin,'MANUAL',
      case when v_action in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT') then coalesce(v_call_actual_lead,v_lead_id) else null end,
      v_call_id
    );

    if not exists(select 1 from public.aos_agenda_citas a where a.id=v_agenda_id) then
      raise exception 'AGENDA_INSERT_SUPPRESSED';
    end if;
    if v_fail='AFTER_AGENDA' then
      raise exception 'LOOP6_TEST_FAIL_AFTER_AGENDA';
    end if;
  end if;

  if nullif(v_payload->>'followup_id','') is not null then
    update public.aos_seguimientos
       set "ESTADO"='COMPLETADO',"TS_ACTUALIZADO"=pg_catalog.now()
     where "ID"=v_payload->>'followup_id';
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'ok',true,
    'idempotent',false,
    'actionType',v_action,
    'patientState',v_patient_state,
    'identityStatus',v_identity_status,
    'canonicalPatientId',v_canonical,
    'converted',v_is_converted,
    'callId',v_call_id,
    'agendaId',v_agenda_id,
    'leadId',coalesce(v_call_actual_lead,v_lead_id),
    'origin',coalesce(v_call_actual_origin,v_origin),
    'callState',v_call_actual_state,
    'tipoGestion',v_call_actual_type,
    'businessDate',v_day,
    'advisor',upper(v_user.nombre),
    'advisorId',v_user.codigo_asesor
  );

  update public.aos_callcenter_actions_v1
     set status='COMPLETE',llamada_id=v_call_id,agenda_id=v_agenda_id,
         lead_id_origen=coalesce(v_call_actual_lead,v_lead_id),origen=coalesce(v_call_actual_origin,v_origin),
         result=v_result,updated_at=pg_catalog.now()
   where idempotency_key=v_key;

  return v_result;
end
$function$;

revoke all on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) from public, anon, authenticated;
grant execute on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) to service_role;

create or replace function public.aos_callcenter_commit_action_v1(
  p_token text,
  p_idempotency_key text,
  p_action_type text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
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

  -- Business clock is server-owned. Browser timestamps cannot choose KPI day.
  v_payload := (v_payload - 'event_ts' - 'business_date') ||
    pg_catalog.jsonb_build_object('event_ts',pg_catalog.now());

  return public.aos_callcenter_commit_action_core_v1(
    v_actor,p_idempotency_key,p_action_type,v_payload,null
  );
end
$function$;

revoke all on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) from public;
grant execute on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) to anon, authenticated, service_role;

-- Explicit Loop 6 semantics must never be deleted solely by ±10 second proximity.
create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_call_ts timestamptz;
  v_agenda_ts timestamptz;
  v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_agenda_ts:=coalesce(new.ts_creado,now());
    delete from public.aos_llamadas l
    where l.numero_limpio=v_num
      and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,''))
      and upper(coalesce(l.tipo_gestion,'LLAMADA')) not in (
        'LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA','REACTIVACION','SEGUIMIENTO_PACIENTE'
      )
      and (upper(coalesce(l.estado,''))='CITA CONFIRMADA' or (upper(coalesce(l.estado,''))='SEGUIMIENTO' and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE'))
      and abs(extract(epoch from(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts)))<=10;
    return new;
  end if;
  if tg_table_name='aos_llamadas' then
    if upper(coalesce(new.tipo_gestion,'LLAMADA')) in (
      'LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA','REACTIVACION','SEGUIMIENTO_PACIENTE'
    ) then return new; end if;
    if not (upper(coalesce(new.estado,''))='CITA CONFIRMADA' or (upper(coalesce(new.estado,''))='SEGUIMIENTO' and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE')) then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
    if exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(a.origen_cita,''))='CITA_MANUAL' and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10) then
      delete from public.aos_llamadas where id=new.id;
    end if;
    return new;
  end if;
  return new;
end;
$function$;

-- Keep strong converted-patient evidence as a fail-safe, but do not let free-text
-- words such as CONTROL erase an explicitly classified real commercial call.
create or replace function public.aos_hotfix_call_guard_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_num text; v_call_ts timestamptz; v_eff_trat text;
  v_prior_count integer:=0; v_match_count integer:=0; v_any_leads integer:=0;
  v_lead_id bigint; v_lead_trat text; v_lead_anuncio text;
  v_noncommercial text; v_reason text;
  v_explicit_commercial boolean:=false;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
  new.numero_limpio:=v_num;
  if upper(trim(coalesce(new.estado,'')))<>'CITA CONFIRMADA' or v_num='' then return new; end if;
  v_call_ts:=public.aos_llamada_event_ts(coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
  v_explicit_commercial:=upper(coalesce(new.tipo_gestion,'')) in ('LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND');

  if exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
     or exists(select 1 from public.aos_atenciones a where a.numero_limpio=v_num and a.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
     or exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and a.fecha_cita<coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))
  then
    v_noncommercial:='PACIENTE_CONTINUIDAD';
    v_reason:='Paciente/continuidad: evidencia clínica, venta o asistencia previa.';
  elsif not v_explicit_commercial and upper(coalesce(new.observacion,'')) ~ '(ANTIGU|SESION|SESIÓN|CONTROL|DEUDA|APLICACION|APLICACIÓN)' then
    v_noncommercial:='PACIENTE_CONTINUIDAD';
    v_reason:='Continuidad legacy inferida por texto operativo; no aplica a semántica comercial explícita Loop 6.';
  end if;

  if v_noncommercial is not null then
    insert into public.aos_gestiones_no_comerciales(source_call_id,clasificacion,motivo,asesor,numero_limpio,fecha,lead_id_origen,call_payload,agenda_ids,source)
    values(new.id,v_noncommercial,v_reason,new.asesor,v_num,coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.lead_id_origen,to_jsonb(new),null,'CALL_GUARD_V3')
    on conflict(source_call_id) do nothing;
    return null;
  end if;

  if exists(select 1 from public.aos_llamadas l where l.numero_limpio=v_num and l.fecha=coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(l.estado,''))='CITA CONFIRMADA') then
    new.estado:='SEGUIMIENTO';
    new.sub_estado:='CITA YA EXISTENTE';
    new.origen:=coalesce(nullif(new.origen,''),'FOLLOWUP_EXISTING_CITA');
    new.observacion:=trim(concat_ws(' | ',nullif(new.observacion,''),'No suma nueva conversión: ya existía CITA CONFIRMADA para este número/asesor en el día.'));
    return new;
  end if;

  v_eff_trat:=case when upper(coalesce(new.tratamiento,''))='ORGANICO' then coalesce(nullif(new.anuncio,''),new.tratamiento,'') else coalesce(new.tratamiento,'') end;
  select count(*) into v_prior_count from public.aos_marketing_touchpoints_v2(null,null) t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts;
  if v_prior_count=1 then
    select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts order by t.lead_ts desc,t.lead_id desc limit 1;
  elsif v_prior_count>1 and nullif(trim(v_eff_trat),'') is not null then
    select count(*) into v_match_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g');
    if v_match_count>=1 then
      select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g') order by t.lead_ts desc,t.lead_id desc limit 1;
    end if;
  end if;

  if v_lead_id is not null then
    new.lead_id_origen:=v_lead_id;
    new.origen:='MARKETING';
    new.anuncio:=coalesce(nullif(new.anuncio,''),v_lead_anuncio);
    if nullif(trim(coalesce(new.tratamiento,'')),'') is null or upper(coalesce(new.tratamiento,''))='ORGANICO' then new.tratamiento:=v_lead_trat; end if;
  else
    select count(*) into v_any_leads from public.aos_leads l where l.numero_limpio=v_num;
    if v_any_leads=0 then
      new.origen:='ORGANICO';
      if upper(coalesce(new.tratamiento,''))<>'ORGANICO' then
        new.anuncio:=coalesce(nullif(new.anuncio,''),nullif(new.tratamiento,''));
        new.tratamiento:='ORGANICO';
      end if;
    else
      new.origen:=coalesce(nullif(new.origen,''),'MARKETING_UNRESOLVED');
    end if;
  end if;
  return new;
end
$function$;
