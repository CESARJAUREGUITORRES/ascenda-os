-- ASCENDA OS · P0 Call Center Identity Disambiguation V1
-- Scope: manual AGENDA_ONLY only. No commercial credit/ownership semantics are relaxed.
-- Shared-phone conflicts remain fail-closed unless the form identity fields resolve one active patient exactly.

create or replace function public.aos_callcenter_manual_agenda_identity_v1(
  p_numero text,
  p_payload jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_num text:=public.aos_rev_normalize_patient_identifier_v2('PHONE',p_numero);
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_name text:=pg_catalog.regexp_replace(pg_catalog.upper(coalesce(v_payload->>'nombre','')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g');
  v_last text:=pg_catalog.regexp_replace(pg_catalog.upper(coalesce(v_payload->>'apellido','')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g');
  v_doc text:=pg_catalog.regexp_replace(coalesce(v_payload->>'dni',''),'[^0-9A-Za-z]','','g');
  v_email text:=pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload->>'correo','')));
  v_phone_candidates integer:=0;
  v_matches integer:=0;
  v_patient record;
begin
  if v_num is null or pg_catalog.length(v_num)<7 then
    return pg_catalog.jsonb_build_object('status','INVALID_PHONE','candidate_count',0,'match_count',0);
  end if;

  select count(*)::integer into v_phone_candidates
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2(
      'PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")
    )=v_num;

  -- Strong form identity is required for shared-phone disambiguation.
  -- Full name is mandatory; document/email are additional exact constraints when supplied.
  if v_name='' or v_last='' then
    return pg_catalog.jsonb_build_object(
      'status','INSUFFICIENT_EXPLICIT_IDENTITY',
      'candidate_count',v_phone_candidates,
      'match_count',0
    );
  end if;

  with matches as (
    select p.*
    from public.aos_pacientes p
    where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
      and public.aos_rev_normalize_patient_identifier_v2(
        'PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")
      )=v_num
      and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(p."Nombres",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_name
      and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(p."Apellidos",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_last
      and (
        v_doc=''
        or pg_catalog.regexp_replace(coalesce(p."N° documento",''),'[^0-9A-Za-z]','','g')=v_doc
      )
      and (
        v_email=''
        or pg_catalog.lower(pg_catalog.btrim(coalesce(p."Email",'')))=v_email
      )
  )
  select count(*)::integer into v_matches from matches;

  if v_matches<>1 then
    return pg_catalog.jsonb_build_object(
      'status',case when v_matches=0 then 'NO_EXACT_SELECTED_MATCH' else 'EXPLICIT_IDENTITY_STILL_AMBIGUOUS' end,
      'candidate_count',v_phone_candidates,
      'match_count',v_matches
    );
  end if;

  select p.* into v_patient
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2(
      'PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")
    )=v_num
    and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(p."Nombres",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_name
    and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(p."Apellidos",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_last
    and (v_doc='' or pg_catalog.regexp_replace(coalesce(p."N° documento",''),'[^0-9A-Za-z]','','g')=v_doc)
    and (v_email='' or pg_catalog.lower(pg_catalog.btrim(coalesce(p."Email",'')))=v_email)
  limit 1;

  return pg_catalog.jsonb_build_object(
    'status','MATCH_SELECTED',
    'lookup_type','PHONE_PLUS_EXPLICIT_FORM_IDENTITY',
    'canonical_patient_id',v_patient."ID_PACIENTE"::text,
    'candidate_count',v_phone_candidates,
    'match_count',1,
    'confidence_band','HIGH_EXPLICIT',
    'patient',pg_catalog.jsonb_build_object(
      'id',v_patient."ID_PACIENTE"::text,
      'nombres',coalesce(v_patient."Nombres",''),
      'apellidos',coalesce(v_patient."Apellidos",''),
      'dni',coalesce(v_patient."N° documento",''),
      'correo',coalesce(v_patient."Email",''),
      'numero',v_num
    )
  );
end
$function$;

revoke all on function public.aos_callcenter_manual_agenda_identity_v1(text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_callcenter_manual_agenda_identity_v1(text,jsonb) to service_role;

create or replace function public.aos_callcenter_selected_active_appointment_v1(
  p_numero text,
  p_canonical_patient_id text,
  p_event_ts timestamptz default now()
) returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_num text:=public.aos_rev_normalize_patient_identifier_v2('PHONE',p_numero);
  v_day date:=(coalesce(p_event_ts,pg_catalog.now()) at time zone 'America/Lima')::date;
  v_patient record;
  v_active record;
  v_name text;
  v_last text;
  v_doc text;
begin
  select p.* into v_patient
  from public.aos_pacientes p
  where p."ID_PACIENTE"::text=p_canonical_patient_id
    and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2(
      'PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")
    )=v_num
  limit 1;

  if not found then return null; end if;

  v_name:=pg_catalog.regexp_replace(pg_catalog.upper(coalesce(v_patient."Nombres",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g');
  v_last:=pg_catalog.regexp_replace(pg_catalog.upper(coalesce(v_patient."Apellidos",'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g');
  v_doc:=pg_catalog.regexp_replace(coalesce(v_patient."N° documento",''),'[^0-9A-Za-z]','','g');

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_active
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    and a.fecha_cita>=v_day
    and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(a.nombre,'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_name
    and pg_catalog.regexp_replace(pg_catalog.upper(coalesce(a.apellido,'')),'[^A-Z0-9ÁÉÍÓÚÜÑ]','','g')=v_last
    and (v_doc='' or pg_catalog.regexp_replace(coalesce(a.dni,''),'[^0-9A-Za-z]','','g')=v_doc)
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita),a.ts_creado nulls last
  limit 1;

  if v_active.id is null then return null; end if;
  return pg_catalog.jsonb_build_object(
    'id',v_active.id,'advisor',v_active.asesor,'advisorId',v_active.id_asesor,
    'date',v_active.fecha_cita,'time',v_active.hora_cita,'status',v_active.estado_cita,
    'slot',v_active.slot,'leadId',v_active.lead_id_origen
  );
end
$function$;

revoke all on function public.aos_callcenter_selected_active_appointment_v1(text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.aos_callcenter_selected_active_appointment_v1(text,text,timestamptz) to service_role;

create or replace function public.aos_callcenter_commit_manual_agenda_selected_v1(
  p_actor uuid,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_key text:=pg_catalog.btrim(coalesce(p_idempotency_key,''));
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_num text:=public.aos_rev_normalize_patient_identifier_v2('PHONE',v_payload->>'numero');
  v_event_ts timestamptz:=coalesce(nullif(v_payload->>'event_ts','')::timestamptz,pg_catalog.now());
  v_day date:=(v_event_ts at time zone 'America/Lima')::date;
  v_identity jsonb;
  v_patient jsonb;
  v_pid text;
  v_user record;
  v_active jsonb;
  v_hash text;
  v_inserted boolean:=false;
  v_existing record;
  v_fecha_cita date;
  v_hora_cita text;
  v_agenda_id text;
  v_result jsonb;
begin
  if p_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if pg_catalog.length(v_key)<16 or pg_catalog.length(v_key)>160 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY'); end if;
  if v_num is null or pg_catalog.length(v_num)<7 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE'); end if;

  select u.nombre,u.apellidos,u.codigo_asesor,u.rol,u.paneles_acceso into v_user
  from public.aos_usuarios u where u.id=p_actor and u.activo=true limit 1;
  if v_user.nombre is null or v_user.codigo_asesor is null then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTOR'); end if;

  v_identity:=public.aos_callcenter_manual_agenda_identity_v1(v_num,v_payload);
  if coalesce(v_identity->>'status','')<>'MATCH_SELECTED' then
    return pg_catalog.jsonb_build_object('ok',false,'error','IDENTITY_CONFLICT','identityResolution',v_identity);
  end if;
  v_pid:=v_identity->>'canonical_patient_id';
  v_patient:=v_identity->'patient';

  begin v_fecha_cita:=nullif(v_payload->>'fecha_cita','')::date;
  exception when others then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_APPOINTMENT_DATE'); end;
  v_hora_cita:=pg_catalog.btrim(coalesce(v_payload->>'hora_cita',''));
  if v_fecha_cita is null or v_hora_cita='' then return pg_catalog.jsonb_build_object('ok',false,'error','APPOINTMENT_REQUIRED'); end if;

  v_active:=public.aos_callcenter_selected_active_appointment_v1(v_num,v_pid,v_event_ts);
  if v_active is not null then
    return pg_catalog.jsonb_build_object(
      'ok',false,'error','ACTIVE_APPOINTMENT_EXISTS',
      'activeAppointment',v_active,
      'identityResolution',v_identity
    );
  end if;

  v_hash:=pg_catalog.encode(extensions.digest(
    'AGENDA_ONLY|'||(v_payload-'event_ts'-'business_date')::text,'sha256'
  ),'hex');

  insert into public.aos_callcenter_actions_v1(
    idempotency_key,request_hash,actor_user_id,asesor,id_asesor,numero_limpio,
    action_type,source_mode,patient_state,identity_status,canonical_patient_id,
    lead_id_origen,origen,status,created_at,updated_at,
    credited_advisor,credited_advisor_id,commercial_owner,commercial_owner_id,
    beneficiary_scope,eligibility_status,eligibility_reason,ownership_transfer,rule_context
  ) values (
    v_key,v_hash,p_actor,upper(v_user.nombre),v_user.codigo_asesor,v_num,
    'AGENDA_ONLY','MANUAL','SELECTED_PATIENT','MATCH_SELECTED',v_pid,
    null,'PACIENTE_EXISTENTE','PROCESSING',v_event_ts,pg_catalog.now(),
    null,null,null,null,'CLINIC','ALLOW_NO_COMMERCIAL_CREDIT','AGENDA_ONLY_SELECTED_IDENTITY',false,
    pg_catalog.jsonb_build_object('identityResolution',v_identity)
  ) on conflict(idempotency_key) do nothing
  returning true into v_inserted;

  if not coalesce(v_inserted,false) then
    select * into v_existing from public.aos_callcenter_actions_v1 a
    where a.idempotency_key=v_key for update;
    if v_existing.actor_user_id<>p_actor then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_ACTOR_CONFLICT'); end if;
    if v_existing.request_hash<>v_hash then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT'); end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then return v_existing.result||pg_catalog.jsonb_build_object('idempotent',true); end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;

  perform public.aos_callcenter_policy_log_v1(
    p_actor,v_num,'AGENDA_ONLY','ALLOW_NO_COMMERCIAL_CREDIT','AGENDA_ONLY_SELECTED_IDENTITY',
    null,null,null,null,'CLINIC',pg_catalog.jsonb_build_object('identityResolution',v_identity)
  );

  v_agenda_id:=pg_catalog.gen_random_uuid()::text;
  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,nombre,apellido,dni,correo,
    asesor,id_asesor,estado_cita,obs,ts_creado,hora_cita,doctora,tipo_atencion,origen_cita,origen,
    lead_id_origen,llamada_id_origen
  ) values (
    v_agenda_id,v_fecha_cita,pg_catalog.btrim(coalesce(v_payload->>'tratamiento','')),
    coalesce(nullif(v_payload->>'tipo_cita',''),'CONSULTA NUEVA'),coalesce(v_payload->>'sede',''),
    v_num,v_num,coalesce(v_patient->>'nombres',''),coalesce(v_patient->>'apellidos',''),
    coalesce(v_patient->>'dni',''),coalesce(nullif(v_payload->>'correo',''),v_patient->>'correo',''),
    upper(v_user.nombre),v_user.codigo_asesor,'PENDIENTE',coalesce(v_payload->>'obs',''),v_event_ts,
    v_hora_cita,coalesce(v_payload->>'doctora',''),coalesce(v_payload->>'tipo_atencion',''),
    'CALL_CENTER_SOLO_AGENDAR','MANUAL',null,null
  );

  if not exists(select 1 from public.aos_agenda_citas a where a.id=v_agenda_id) then
    raise exception 'AGENDA_INSERT_SUPPRESSED';
  end if;

  v_result:=pg_catalog.jsonb_build_object(
    'ok',true,'idempotent',false,'requestedAction','AGENDA_ONLY','effectiveAction','AGENDA_ONLY',
    'patientState','SELECTED_PATIENT','identityStatus','MATCH_SELECTED','canonicalPatientId',v_pid,
    'converted',null,'callId',null,'agendaId',v_agenda_id,'leadId',null,'origin','PACIENTE_EXISTENTE',
    'callState',null,'tipoGestion',null,'businessDate',v_day,'executedBy',upper(v_user.nombre),
    'executedById',v_user.codigo_asesor,'creditedAdvisor',null,'creditedAdvisorId',null,
    'commercialOwner',null,'commercialOwnerId',null,'beneficiaryScope','CLINIC',
    'eligibilityStatus','ALLOW_NO_COMMERCIAL_CREDIT','eligibilityReason','AGENDA_ONLY_SELECTED_IDENTITY',
    'ownershipTransfer',false,'identityResolution',v_identity
  );

  update public.aos_callcenter_actions_v1
     set status='COMPLETE',agenda_id=v_agenda_id,result=v_result,updated_at=pg_catalog.now()
   where idempotency_key=v_key;

  return v_result;
end
$function$;

revoke all on function public.aos_callcenter_commit_manual_agenda_selected_v1(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_manual_agenda_selected_v1(uuid,text,jsonb) to service_role;

-- Keep the existing prepare contract safe for queue/commercial flows, but let the manual
-- UI reach AGENDA_ONLY when identity is ambiguous. The error marker remains present so
-- lead classification continues to display REVIEW / IDENTIDAD.
create or replace function public.aos_callcenter_prepare_action_v1(p_token text,p_numero text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_state jsonb;
  v_user record;
  v_allowed jsonb;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true); end if;
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  select u.nombre,u.apellidos,u.codigo_asesor,u.rol into v_user
  from public.aos_usuarios u where u.id=v_actor and u.activo=true limit 1;

  v_state:=public.aos_callcenter_credit_context_v2(p_numero,pg_catalog.now());
  if coalesce((v_state->>'ok')::boolean,false)=false then
    if v_state->>'error'='IDENTITY_CONFLICT' then
      return v_state||pg_catalog.jsonb_build_object(
        'ok',true,
        'identityConflictDeferred',true,
        'actorUserId',v_actor,
        'asesor',upper(coalesce(v_user.nombre,'')),
        'idAsesor',v_user.codigo_asesor,
        'allowedActions','["AGENDA_ONLY"]'::jsonb
      );
    end if;
    return v_state||pg_catalog.jsonb_build_object(
      'actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor
    );
  end if;

  if v_state->>'patientState'='CONVERTED_PATIENT' then
    v_allowed:='["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb;
  else
    v_allowed:='["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb;
  end if;

  return v_state||pg_catalog.jsonb_build_object(
    'actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor,
    'allowedActions',v_allowed
  );
end
$function$;

revoke all on function public.aos_callcenter_prepare_action_v1(text,text) from public;
grant execute on function public.aos_callcenter_prepare_action_v1(text,text) to anon,authenticated,service_role;

-- Route only MANUAL AGENDA_ONLY through explicit form-identity disambiguation.
-- Every commercial/callback/reactivation/follow-up action keeps the existing governed core.
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
declare
  v_actor uuid;
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_action text:=upper(pg_catalog.btrim(coalesce(p_action_type,'')));
  v_source text:=upper(pg_catalog.btrim(coalesce(v_payload->>'source_mode','QUEUE')));
  v_identity jsonb;
  v_num text;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true); end if;
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  v_payload:=(v_payload-'event_ts'-'business_date')||pg_catalog.jsonb_build_object('event_ts',pg_catalog.now());
  v_num:=public.aos_rev_normalize_patient_identifier_v2('PHONE',v_payload->>'numero');

  if v_action='AGENDA_ONLY' and v_source='MANUAL' then
    v_identity:=public.aos_callcenter_manual_agenda_identity_v1(v_num,v_payload);
    if v_identity->>'status'='MATCH_SELECTED' then
      perform pg_catalog.set_config('aos.callcenter_phone',coalesce(v_num,''),true);
      perform pg_catalog.set_config('aos.loop6_governed_write','1',true);
      return public.aos_callcenter_commit_manual_agenda_selected_v1(
        v_actor,p_idempotency_key,v_payload
      );
    end if;
  end if;

  return public.aos_callcenter_commit_action_core_v1(
    v_actor,p_idempotency_key,p_action_type,v_payload,null
  );
end
$function$;

revoke all on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) from public;
grant execute on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) to anon,authenticated,service_role;

comment on function public.aos_callcenter_manual_agenda_identity_v1(text,jsonb) is
  'P0 identity disambiguation: resolves one active patient from shared phone + explicit manual form identity. Service-only; no commercial credit.';
comment on function public.aos_callcenter_commit_manual_agenda_selected_v1(uuid,text,jsonb) is
  'P0 manual AGENDA_ONLY selected-identity core. Creates Agenda only, no Call/lead/commercial credit; fail-closed unless one exact active patient matches.';
comment on function public.aos_callcenter_prepare_action_v1(text,text) is
  'Call Center prepare. P0 identity conflicts remain marked REVIEW but may proceed only to manual AGENDA_ONLY where commit requires exact form-identity disambiguation.';
