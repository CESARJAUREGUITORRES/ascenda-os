-- WA-4C governed booking write V2 semantics on the existing v1 RPC name.
-- DOCTORA: exact provider. ENFERMERIA: site pool; no nurse is promised/frozen at booking time.
-- HUMAN_ONLY boundary remains unchanged.

begin;

create or replace function public.aos_wa4_commit_booking_v1(
  p_actor_id uuid,
  p_idempotency_key text,
  p_conversation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_existing public.aos_wa4_booking_actions_v1%rowtype;
  v_treatment public.aos_catalogo_servicios%rowtype;
  v_patient public.aos_pacientes%rowtype;
  v_identity jsonb := '{}'::jsonb;
  v_identity_status text := 'UNRESOLVED';
  v_canonical text := null;
  v_hash text;
  v_site text;
  v_date date;
  v_time time;
  v_time_text text;
  v_role text;
  v_professional_id text;
  v_prof_name text;
  v_booking_mode text;
  v_availability jsonb;
  v_slot_ok boolean := false;
  v_agenda_id text;
  v_name text;
  v_last text;
  v_dni text;
  v_email text;
  v_appointment_type text;
  v_source text;
  v_lead_bigint bigint := null;
begin
  if p_actor_id is null or p_conversation_id is null then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_ACTOR_AND_CONVERSATION_REQUIRED');
  end if;
  if coalesce(length(btrim(p_idempotency_key)),0)<16 or length(p_idempotency_key)>160 then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDEMPOTENCY_KEY_INVALID');
  end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_PAYLOAD_INVALID');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('wa4-booking-idem:'||p_idempotency_key,0));
  v_hash:=encode(digest(convert_to(p_conversation_id::text||'|'||p_payload::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from public.aos_wa4_booking_actions_v1 where idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then
      return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDEMPOTENCY_MISMATCH');
    end if;
    return jsonb_build_object('ok',true,'status',v_existing.status,'agenda_id',v_existing.agenda_id,'idempotent_replay',true,'confirmation_allowed',true);
  end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from p_actor_id then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_NOT_CONVERSATION_OWNER');
  end if;
  if upper(coalesce(v_conv.state,'')) not in ('HUMAN_ACTIVE','AI_COPILOT') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_STATE_BLOCKED');
  end if;
  if not exists (
    select 1 from public.aos_wa_assignments_v1 a
    where a.conversation_id=p_conversation_id and a.owner_user_id=p_actor_id and a.state='ACTIVE'
  ) then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;
  if coalesce(regexp_replace(v_conv.contact_number,'[^0-9]','','g'),'')='' then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_TRUSTED_PHONE_REQUIRED');
  end if;

  v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',v_conv.contact_number),'{}'::jsonb);
  v_identity_status:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
  if v_identity_status='IDENTITY_CONFLICT' then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDENTITY_CONFLICT','requires_human',true);
  end if;
  if v_identity_status not in ('MATCH','UNRESOLVED') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDENTITY_NOT_READY','identity_state',v_identity_status,'requires_human',true);
  end if;
  if v_identity_status='MATCH' then
    v_canonical:=nullif(btrim(v_identity->>'canonical_patient_id'),'');
    if v_canonical is null then
      return jsonb_build_object('ok',false,'error','WA4_BOOKING_CANONICAL_ID_MISSING','requires_human',true);
    end if;
    select * into v_patient from public.aos_pacientes where "ID_PACIENTE"::text=v_canonical limit 1;
    if not found then
      return jsonb_build_object('ok',false,'error','WA4_BOOKING_CANONICAL_TARGET_MISSING','requires_human',true);
    end if;
  end if;

  begin
    select * into v_treatment
    from public.aos_catalogo_servicios
    where id=(p_payload->>'treatment_id')::uuid
      and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
      and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  exception when others then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_ID_INVALID');
  end;
  if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_NOT_ACTIVE'); end if;

  if coalesce(v_treatment.requiere_doctora,false) and coalesce(v_treatment.requiere_enfermeria,false) then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_DUAL_ROLE_REQUIRES_HUMAN','requires_human',true);
  elsif coalesce(v_treatment.requiere_doctora,false) then
    v_role:='DOCTORA'; v_booking_mode:='EXACT_PROVIDER';
  elsif coalesce(v_treatment.requiere_enfermeria,false) then
    v_role:='ENFERMERIA'; v_booking_mode:='SITE_POOL';
  else
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_ROLE_NOT_GOVERNED','requires_human',true);
  end if;

  v_site:=upper(replace(btrim(coalesce(p_payload->>'site','')),'_',' '));
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_SITE_INVALID');
  end if;
  begin
    v_date:=(p_payload->>'date')::date;
    v_time:=(p_payload->>'time')::time;
  exception when others then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_DATE_TIME_INVALID');
  end;
  if v_date<current_date then return jsonb_build_object('ok',false,'error','WA4_BOOKING_DATE_IN_PAST'); end if;
  if extract(isodow from v_date)=7 then return jsonb_build_object('ok',false,'error','WA4_BOOKING_SUNDAY_CLOSED'); end if;
  v_time_text:=to_char(v_time,'HH24:MI');

  if v_role='DOCTORA' then
    v_professional_id:=nullif(btrim(p_payload->>'professional_id'),'');
    if v_professional_id is null then
      return jsonb_build_object('ok',false,'error','WA4_BOOKING_EXACT_PROVIDER_REQUIRED');
    end if;
  else
    -- Never bind an individual nurse during booking. Assignment happens operationally at attention time.
    v_professional_id:=null;
  end if;

  v_availability:=coalesce(public.aos_booking_availability_v2(v_treatment.id,v_date,v_site,v_professional_id),'{}'::jsonb);
  if coalesce((v_availability->>'ok')::boolean,false) is not true then
    return jsonb_build_object(
      'ok',false,'error','WA4_BOOKING_AUTHORITY_BLOCKED','authority_status',coalesce(v_availability->>'status','UNKNOWN'),
      'requires_human',true
    );
  end if;
  if upper(coalesce(v_availability->>'role',''))<>v_role or upper(coalesce(v_availability->>'mode',''))<>v_booking_mode then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_AUTHORITY_ROLE_MODE_MISMATCH','requires_human',true);
  end if;

  select exists(
    select 1 from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text
      and coalesce((s->>'disponible')::boolean,false)=true
      and (v_role='ENFERMERIA' or s->>'professional_id'=v_professional_id)
  ) into v_slot_ok;
  if not v_slot_ok then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true);
  end if;

  if v_role='DOCTORA' then
    select s->>'professional_name' into v_prof_name
    from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text and s->>'professional_id'=v_professional_id
    limit 1;
    if coalesce(btrim(v_prof_name),'')='' then
      return jsonb_build_object('ok',false,'error','WA4_BOOKING_PROFESSIONAL_NOT_AVAILABLE');
    end if;
  else
    v_professional_id:='POOL:'||replace(v_site,' ','_');
    v_prof_name:='ENFERMERIA';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('wa4-slot:'||v_professional_id||':'||v_date::text||':'||v_time_text||':'||v_site,0));
  -- Re-read after lock to prevent a stale capacity decision.
  v_availability:=coalesce(public.aos_booking_availability_v2(v_treatment.id,v_date,v_site,case when v_role='DOCTORA' then replace(v_professional_id,'POOL:','') else null end),'{}'::jsonb);
  select exists(
    select 1 from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text
      and coalesce((s->>'disponible')::boolean,false)=true
      and (v_role='ENFERMERIA' or s->>'professional_id'=v_professional_id)
  ) into v_slot_ok;
  if not v_slot_ok then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true);
  end if;

  v_name:=nullif(btrim(p_payload->>'name'),'');
  v_last:=nullif(btrim(p_payload->>'last_name'),'');
  v_dni:=nullif(btrim(p_payload->>'dni'),'');
  v_email:=nullif(btrim(p_payload->>'email'),'');
  if v_identity_status='MATCH' then
    v_name:=coalesce(v_name,nullif(btrim(v_patient."Nombres"),''));
    v_last:=coalesce(v_last,nullif(btrim(v_patient."Apellidos"),''));
    v_dni:=coalesce(v_dni,nullif(btrim(v_patient."N° documento"),''));
    v_email:=coalesce(v_email,nullif(btrim(v_patient."Email"),''));
  end if;
  v_name:=coalesce(v_name,nullif(btrim(v_conv.contact_name),''));
  if v_name is null then return jsonb_build_object('ok',false,'error','WA4_BOOKING_NAME_REQUIRED'); end if;

  v_appointment_type:=upper(btrim(coalesce(p_payload->>'appointment_type','CONSULTA NUEVA')));
  if v_appointment_type not in ('CONSULTA NUEVA','APLICACION','CONTROL') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_APPOINTMENT_TYPE_INVALID');
  end if;
  v_source:=case when coalesce(v_conv.ad_id,'')<>'' or upper(coalesce(v_conv.campaign_source,'')) like '%META%' then 'WHATSAPP_META' else 'WHATSAPP_ORGANIC' end;
  if coalesce(v_conv.lead_id,'')~'^[0-9]+$' then v_lead_bigint:=v_conv.lead_id::bigint; end if;

  v_agenda_id:=gen_random_uuid()::text;
  perform set_config('aos.wa4_governed_booking_write','1',true);
  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,dni,correo,
    asesor,id_asesor,estado_cita,obs,ts_creado,ts_actualizado,hora_cita,etiqueta_campana,
    doctora,tipo_atencion,origen_cita,numero_limpio,origen,lead_id_origen,llamada_id_origen
  ) values (
    v_agenda_id,v_date,v_treatment.nombre,v_appointment_type,v_site,v_conv.contact_number,v_name,coalesce(v_last,''),v_dni,v_email,
    'WHATSAPP',p_actor_id::text,'PENDIENTE',case when v_role='ENFERMERIA' then 'WA4_BOOKING_MODE=SITE_POOL' else null end,now(),now(),v_time_text,v_conv.campaign_source,
    case when v_role='DOCTORA' then v_prof_name else null end,v_role,'WHATSAPP',regexp_replace(v_conv.contact_number,'[^0-9]','','g'),v_source,v_lead_bigint,null
  );

  insert into public.aos_wa4_booking_actions_v1(
    idempotency_key,request_hash,conversation_id,actor_id,agenda_id,treatment_id,professional_id,
    site,appointment_date,appointment_time,identity_state,source_channel,campaign_source,ad_id,lead_id,status
  ) values (
    p_idempotency_key,v_hash,p_conversation_id,p_actor_id,v_agenda_id,v_treatment.id,v_professional_id,
    v_site,v_date,v_time,v_identity_status,'WHATSAPP',v_conv.campaign_source,v_conv.ad_id,v_conv.lead_id,'BOOKED'
  );

  return jsonb_build_object(
    'ok',true,'status','BOOKED','agenda_id',v_agenda_id,'idempotent_replay',false,
    'confirmation_allowed',true,'identity_state',v_identity_status,'site',v_site,
    'date',v_date,'time',v_time_text,'professional_role',v_role,'booking_mode',v_booking_mode,
    'professional_id',case when v_role='DOCTORA' then v_professional_id else null end,
    'professional_name',case when v_role='DOCTORA' then v_prof_name else 'Enfermería' end,
    'source',v_source
  );
end
$$;

revoke all on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) to service_role;

comment on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) is
'WA-4C HUMAN_ONLY booking commit. Catalog role + Team skill + date/site schedule authority. Doctors are exact providers; nursing is a site pool and never promises an individual nurse.';

commit;
