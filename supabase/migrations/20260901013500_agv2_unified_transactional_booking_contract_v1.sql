-- ASCENDA OS · AGV2-2 — Unified Transactional Booking Contract V1
-- Additive/dormant rollout: creates a shared BOOK/REBOOK core for Agenda + WhatsApp.
-- Existing live WA v1 commit remains untouched until the V2 contract is certified/wired.

begin;

create table if not exists public.aos_booking_operations_v2 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  request_hash text not null,
  operation_type text not null check (operation_type in ('BOOK','REBOOK')),
  channel text not null check (channel in ('AGENDA','WHATSAPP')),
  actor_id uuid not null,
  conversation_id uuid null,
  appointment_id text not null,
  treatment_id uuid not null,
  professional_ref text not null,
  site text not null,
  appointment_date date not null,
  appointment_time time not null,
  identity_state text not null,
  campaign_source text null,
  ad_id text null,
  lead_id text null,
  status text not null,
  response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_aos_booking_operations_v2_appointment
  on public.aos_booking_operations_v2(appointment_id,created_at desc);
create index if not exists idx_aos_booking_operations_v2_conversation
  on public.aos_booking_operations_v2(conversation_id,created_at desc)
  where conversation_id is not null;

create table if not exists public.aos_agenda_events_v2 (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.aos_booking_operations_v2(id),
  appointment_id text not null,
  event_type text not null check (event_type in ('BOOKED','RESCHEDULED')),
  actor_id uuid not null,
  channel text not null check (channel in ('AGENDA','WHATSAPP')),
  conversation_id uuid null,
  reason text null,
  before_snapshot jsonb null,
  after_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique(operation_id,event_type)
);

create index if not exists idx_aos_agenda_events_v2_appointment
  on public.aos_agenda_events_v2(appointment_id,created_at desc);

create or replace function public.aos_agenda_events_v2_append_only_guard()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
begin
  raise exception using errcode='P0001',message='AGV2_EVENT_LEDGER_APPEND_ONLY';
end
$$;

drop trigger if exists trg_aos_agenda_events_v2_append_only on public.aos_agenda_events_v2;
create trigger trg_aos_agenda_events_v2_append_only
before update or delete on public.aos_agenda_events_v2
for each row execute function public.aos_agenda_events_v2_append_only_guard();

revoke all on table public.aos_booking_operations_v2 from public,anon,authenticated;
revoke all on table public.aos_agenda_events_v2 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_booking_operations_v2 to service_role;
grant select,insert on table public.aos_agenda_events_v2 to service_role;

-- Resolve one chosen slot against the same authority consumed by WA/public booking.
create or replace function public.aos_booking_resolve_selected_slot_v2(
  p_treatment_id uuid,
  p_date date,
  p_site text,
  p_time time,
  p_professional_id text default null,
  p_slot_role text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_site text;
  v_role text;
  v_prof text:=nullif(btrim(coalesce(p_professional_id,'')),'');
  v_av jsonb;
  v_slot jsonb;
  v_doc boolean;
  v_nurse boolean;
begin
  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'error','AGV2_TREATMENT_NOT_ACTIVE'); end if;

  v_site:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  if p_date is null or p_time is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','AGV2_DATE_TIME_SITE_INVALID');
  end if;
  if p_date<current_date then return jsonb_build_object('ok',false,'error','AGV2_DATE_IN_PAST'); end if;
  if extract(isodow from p_date)=7 then return jsonb_build_object('ok',false,'error','AGV2_SUNDAY_CLOSED'); end if;

  v_doc:=coalesce(v_t.requiere_doctora,false);
  v_nurse:=coalesce(v_t.requiere_enfermeria,false);
  v_role:=upper(btrim(coalesce(p_slot_role,'')));

  if v_role='' then
    if v_doc and v_nurse then v_role:=case when v_prof is null then 'ENFERMERIA' else 'DOCTORA' end;
    elsif v_doc then v_role:='DOCTORA';
    elsif v_nurse then v_role:='ENFERMERIA';
    end if;
  end if;

  if v_role not in ('DOCTORA','ENFERMERIA') then
    return jsonb_build_object('ok',false,'error','AGV2_SLOT_ROLE_REQUIRED');
  end if;
  if v_role='DOCTORA' and not v_doc then return jsonb_build_object('ok',false,'error','AGV2_ROLE_NOT_ALLOWED'); end if;
  if v_role='ENFERMERIA' and not v_nurse then return jsonb_build_object('ok',false,'error','AGV2_ROLE_NOT_ALLOWED'); end if;
  if v_role='DOCTORA' and v_prof is null then return jsonb_build_object('ok',false,'error','AGV2_EXACT_PROVIDER_REQUIRED'); end if;
  if v_role='ENFERMERIA' then v_prof:=null; end if;

  v_av:=coalesce(public.aos_booking_availability_v2(v_t.id,p_date,v_site,v_prof),'{}'::jsonb);
  if coalesce((v_av->>'ok')::boolean,false) is not true then
    return jsonb_build_object(
      'ok',false,'error','AGV2_AUTHORITY_BLOCKED',
      'authority_status',coalesce(v_av->>'status','UNKNOWN'),
      'requires_human',true
    );
  end if;

  select s into v_slot
  from jsonb_array_elements(coalesce(v_av->'slots','[]'::jsonb)) s
  where s->>'hora'=to_char(p_time,'HH24:MI')
    and upper(coalesce(s->>'role',''))=v_role
    and coalesce((s->>'disponible')::boolean,false)=true
    and (v_role='ENFERMERIA' or s->>'professional_id'=v_prof)
  limit 1;

  if v_slot is null then
    return jsonb_build_object('ok',false,'error','AGV2_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true);
  end if;

  return jsonb_build_object(
    'ok',true,
    'role',v_role,
    'booking_mode',case when v_role='DOCTORA' then 'EXACT_PROVIDER' else 'SITE_POOL' end,
    'professional_id',case when v_role='DOCTORA' then v_prof else null end,
    'professional_ref',case when v_role='DOCTORA' then v_prof else 'POOL:'||replace(v_site,' ','_') end,
    'professional_name',case when v_role='DOCTORA' then v_slot->>'professional_name' else 'Enfermería' end,
    'site',v_site,
    'date',p_date,
    'time',to_char(p_time,'HH24:MI'),
    'authority_status',v_av->>'status'
  );
end
$$;

-- Shared BOOK core. Wrappers authenticate the channel; core owns identity, slot and commit invariants.
create or replace function public.aos_booking_commit_core_v2(
  p_context jsonb,
  p_idempotency_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_existing public.aos_booking_operations_v2%rowtype;
  v_actor uuid;
  v_channel text;
  v_conv uuid;
  v_phone text;
  v_phone_norm text;
  v_contact_name text;
  v_campaign text;
  v_ad text;
  v_lead text;
  v_lead_bigint bigint:=null;
  v_hash text;
  v_t public.aos_catalogo_servicios%rowtype;
  v_treatment_id uuid;
  v_site text;
  v_date date;
  v_time time;
  v_prof text;
  v_slot_role text;
  v_slot jsonb;
  v_prof_ref text;
  v_prof_name text;
  v_role text;
  v_booking_mode text;
  v_identity jsonb:='{}'::jsonb;
  v_identity_state text:='UNRESOLVED';
  v_canonical text;
  v_patient public.aos_pacientes%rowtype;
  v_name text;
  v_last text;
  v_dni text;
  v_email text;
  v_type text;
  v_agenda_id text;
  v_op_id uuid:=gen_random_uuid();
  v_response jsonb;
  v_source text;
  v_actor_code text;
begin
  if p_context is null or jsonb_typeof(p_context)<>'object' or p_payload is null or jsonb_typeof(p_payload)<>'object' then
    return jsonb_build_object('ok',false,'error','AGV2_CONTEXT_OR_PAYLOAD_INVALID');
  end if;
  if coalesce(length(btrim(p_idempotency_key)),0)<16 or length(p_idempotency_key)>160 then
    return jsonb_build_object('ok',false,'error','AGV2_IDEMPOTENCY_KEY_INVALID');
  end if;

  begin v_actor:=(p_context->>'actor_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','AGV2_ACTOR_INVALID'); end;
  v_channel:=upper(btrim(coalesce(p_context->>'channel','')));
  if v_channel not in ('AGENDA','WHATSAPP') then return jsonb_build_object('ok',false,'error','AGV2_CHANNEL_INVALID'); end if;
  begin v_conv:=nullif(p_context->>'conversation_id','')::uuid; exception when others then return jsonb_build_object('ok',false,'error','AGV2_CONVERSATION_INVALID'); end;

  v_phone:=coalesce(nullif(btrim(p_context->>'contact_number'),''),nullif(btrim(p_payload->>'phone'),''));
  v_phone_norm:=regexp_replace(coalesce(v_phone,''),'[^0-9]','','g');
  if length(v_phone_norm)<7 then return jsonb_build_object('ok',false,'error','AGV2_TRUSTED_PHONE_REQUIRED'); end if;
  v_contact_name:=nullif(btrim(p_context->>'contact_name'),'');
  v_campaign:=nullif(btrim(p_context->>'campaign_source'),'');
  v_ad:=nullif(btrim(p_context->>'ad_id'),'');
  v_lead:=nullif(btrim(p_context->>'lead_id'),'');
  v_actor_code:=nullif(btrim(p_context->>'actor_code'),'');

  perform pg_advisory_xact_lock(hashtextextended('agv2-op:'||p_idempotency_key,0));
  v_hash:=encode(digest(convert_to(v_channel||'|'||coalesce(v_conv::text,'')||'|'||v_actor::text||'|'||p_payload::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from public.aos_booking_operations_v2 where idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then return jsonb_build_object('ok',false,'error','AGV2_IDEMPOTENCY_MISMATCH'); end if;
    return jsonb_set(v_existing.response,'{idempotent_replay}','true'::jsonb,true);
  end if;

  v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',v_phone_norm),'{}'::jsonb);
  v_identity_state:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
  if v_identity_state='IDENTITY_CONFLICT' then return jsonb_build_object('ok',false,'error','AGV2_IDENTITY_CONFLICT','requires_human',true); end if;
  if v_identity_state not in ('MATCH','UNRESOLVED') then
    return jsonb_build_object('ok',false,'error','AGV2_IDENTITY_NOT_READY','identity_state',v_identity_state,'requires_human',true);
  end if;
  if v_identity_state='MATCH' then
    v_canonical:=nullif(btrim(v_identity->>'canonical_patient_id'),'');
    if v_canonical is null then return jsonb_build_object('ok',false,'error','AGV2_CANONICAL_ID_MISSING','requires_human',true); end if;
    select * into v_patient from public.aos_pacientes where "ID_PACIENTE"::text=v_canonical limit 1;
    if not found then return jsonb_build_object('ok',false,'error','AGV2_CANONICAL_TARGET_MISSING','requires_human',true); end if;
  end if;

  begin v_treatment_id:=(p_payload->>'treatment_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','AGV2_TREATMENT_ID_INVALID'); end;
  select * into v_t from public.aos_catalogo_servicios
  where id=v_treatment_id and upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'error','AGV2_TREATMENT_NOT_ACTIVE'); end if;

  v_site:=upper(replace(btrim(coalesce(p_payload->>'site','')),'_',' '));
  begin v_date:=(p_payload->>'date')::date; v_time:=(p_payload->>'time')::time;
  exception when others then return jsonb_build_object('ok',false,'error','AGV2_DATE_TIME_INVALID'); end;
  v_prof:=nullif(btrim(p_payload->>'professional_id'),'');
  v_slot_role:=nullif(upper(btrim(p_payload->>'slot_role')),'');

  v_slot:=public.aos_booking_resolve_selected_slot_v2(v_t.id,v_date,v_site,v_time,v_prof,v_slot_role);
  if coalesce((v_slot->>'ok')::boolean,false) is not true then return v_slot; end if;
  v_prof_ref:=v_slot->>'professional_ref';
  v_prof_name:=v_slot->>'professional_name';
  v_role:=v_slot->>'role';
  v_booking_mode:=v_slot->>'booking_mode';

  -- Lock the exact provider/pool slot and re-read availability inside the same transaction.
  perform pg_advisory_xact_lock(hashtextextended('agv2-slot:'||v_prof_ref||':'||v_date::text||':'||to_char(v_time,'HH24:MI')||':'||v_site,0));
  v_slot:=public.aos_booking_resolve_selected_slot_v2(v_t.id,v_date,v_site,v_time,case when v_role='DOCTORA' then v_prof else null end,v_role);
  if coalesce((v_slot->>'ok')::boolean,false) is not true then return v_slot; end if;

  v_name:=nullif(btrim(p_payload->>'name'),'');
  v_last:=nullif(btrim(p_payload->>'last_name'),'');
  v_dni:=nullif(btrim(p_payload->>'dni'),'');
  v_email:=nullif(lower(btrim(p_payload->>'email')),'');
  if v_identity_state='MATCH' then
    v_name:=coalesce(v_name,nullif(btrim(v_patient."Nombres"),''));
    v_last:=coalesce(v_last,nullif(btrim(v_patient."Apellidos"),''));
    v_dni:=coalesce(v_dni,nullif(btrim(v_patient."N° documento"),''));
    v_email:=coalesce(v_email,nullif(lower(btrim(v_patient."Email")),''));
  end if;
  v_name:=coalesce(v_name,v_contact_name);
  if v_name is null then return jsonb_build_object('ok',false,'error','AGV2_NAME_REQUIRED'); end if;
  if v_channel='AGENDA' and coalesce(v_last,'')='' then return jsonb_build_object('ok',false,'error','AGV2_LAST_NAME_REQUIRED'); end if;
  if v_email is not null and v_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    return jsonb_build_object('ok',false,'error','AGV2_EMAIL_INVALID','email_optional',true);
  end if;

  v_type:=upper(btrim(coalesce(p_payload->>'appointment_type','CONSULTA NUEVA')));
  if v_type not in ('CONSULTA NUEVA','APLICACION','CONTROL') then return jsonb_build_object('ok',false,'error','AGV2_APPOINTMENT_TYPE_INVALID'); end if;
  if v_lead is not null and v_lead~'^[0-9]+$' then v_lead_bigint:=v_lead::bigint; end if;

  v_source:=case
    when v_channel='WHATSAPP' and (v_ad is not null or upper(coalesce(v_campaign,'')) like '%META%') then 'WHATSAPP_META'
    when v_channel='WHATSAPP' then 'WHATSAPP_ORGANIC'
    else 'AGENDA_INTERNAL'
  end;

  v_agenda_id:=gen_random_uuid()::text;
  if v_channel='WHATSAPP' then perform set_config('aos.wa4_governed_booking_write','1',true); end if;

  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,dni,correo,
    asesor,id_asesor,estado_cita,obs,ts_creado,ts_actualizado,hora_cita,etiqueta_campana,
    doctora,tipo_atencion,origen_cita,numero_limpio,origen,lead_id_origen,llamada_id_origen
  ) values (
    v_agenda_id,v_date,v_t.nombre,v_type,v_site,v_phone,v_name,coalesce(v_last,''),v_dni,v_email,
    case when v_channel='WHATSAPP' then 'WHATSAPP' else coalesce(v_actor_code,'AGENDA') end,
    v_actor::text,'PENDIENTE',case when v_role='ENFERMERIA' then 'AGV2_BOOKING_MODE=SITE_POOL' else null end,
    now(),now(),to_char(v_time,'HH24:MI'),v_campaign,
    case when v_role='DOCTORA' then v_prof_name else null end,v_role,
    case when v_channel='WHATSAPP' then 'WHATSAPP' else 'AGENDA_V2' end,
    v_phone_norm,v_source,v_lead_bigint,null
  );

  v_response:=jsonb_build_object(
    'ok',true,'status','BOOKED','appointment_id',v_agenda_id,'agenda_id',v_agenda_id,
    'operation_id',v_op_id,'idempotent_replay',false,'confirmation_allowed',true,
    'identity_state',v_identity_state,'site',v_site,'date',v_date,'time',to_char(v_time,'HH24:MI'),
    'professional_role',v_role,'booking_mode',v_booking_mode,
    'professional_id',case when v_role='DOCTORA' then v_prof else null end,
    'professional_name',v_prof_name,'source',v_source
  );

  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,conversation_id,appointment_id,
    treatment_id,professional_ref,site,appointment_date,appointment_time,identity_state,
    campaign_source,ad_id,lead_id,status,response
  ) values (
    v_op_id,p_idempotency_key,v_hash,'BOOK',v_channel,v_actor,v_conv,v_agenda_id,
    v_t.id,v_prof_ref,v_site,v_date,v_time,v_identity_state,v_campaign,v_ad,v_lead,'BOOKED',v_response
  );

  insert into public.aos_agenda_events_v2(
    operation_id,appointment_id,event_type,actor_id,channel,conversation_id,before_snapshot,after_snapshot
  ) values (
    v_op_id,v_agenda_id,'BOOKED',v_actor,v_channel,v_conv,null,
    jsonb_build_object(
      'appointment_id',v_agenda_id,'treatment_id',v_t.id,'treatment',v_t.nombre,
      'site',v_site,'date',v_date,'time',to_char(v_time,'HH24:MI'),
      'role',v_role,'professional_ref',v_prof_ref,'professional_name',v_prof_name,
      'status','PENDIENTE','source',v_source
    )
  );

  -- Preserve the existing WA booking attribution ledger for downstream analytics/canaries.
  if v_channel='WHATSAPP' and v_conv is not null then
    insert into public.aos_wa4_booking_actions_v1(
      idempotency_key,request_hash,conversation_id,actor_id,agenda_id,treatment_id,professional_id,
      site,appointment_date,appointment_time,identity_state,source_channel,campaign_source,ad_id,lead_id,status
    ) values (
      p_idempotency_key,v_hash,v_conv,v_actor,v_agenda_id,v_t.id,v_prof_ref,
      v_site,v_date,v_time,v_identity_state,'WHATSAPP',v_campaign,v_ad,v_lead,'BOOKED'
    ) on conflict(idempotency_key) do nothing;
  end if;

  return v_response;
end
$$;

-- Same logical appointment + append-only event ledger REBOOK.
create or replace function public.aos_booking_rebook_core_v2(
  p_context jsonb,
  p_idempotency_key text,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_existing public.aos_booking_operations_v2%rowtype;
  v_actor uuid;
  v_channel text;
  v_conv uuid;
  v_phone text;
  v_phone_norm text;
  v_hash text;
  v_cita public.aos_agenda_citas%rowtype;
  v_t public.aos_catalogo_servicios%rowtype;
  v_treatment_id uuid;
  v_site text;
  v_date date;
  v_time time;
  v_prof text;
  v_role text;
  v_slot jsonb;
  v_prof_ref text;
  v_prof_name text;
  v_booking_mode text;
  v_identity jsonb:='{}'::jsonb;
  v_identity_state text:='UNRESOLVED';
  v_op_id uuid:=gen_random_uuid();
  v_before jsonb;
  v_after jsonb;
  v_response jsonb;
  v_reason text;
  v_campaign text;
  v_ad text;
  v_lead text;
begin
  if p_context is null or jsonb_typeof(p_context)<>'object' or p_payload is null or jsonb_typeof(p_payload)<>'object' then
    return jsonb_build_object('ok',false,'error','AGV2_CONTEXT_OR_PAYLOAD_INVALID');
  end if;
  if coalesce(length(btrim(p_idempotency_key)),0)<16 or length(p_idempotency_key)>160 then return jsonb_build_object('ok',false,'error','AGV2_IDEMPOTENCY_KEY_INVALID'); end if;
  if coalesce(btrim(p_appointment_id),'')='' then return jsonb_build_object('ok',false,'error','AGV2_APPOINTMENT_REQUIRED'); end if;

  begin v_actor:=(p_context->>'actor_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','AGV2_ACTOR_INVALID'); end;
  v_channel:=upper(btrim(coalesce(p_context->>'channel','')));
  if v_channel not in ('AGENDA','WHATSAPP') then return jsonb_build_object('ok',false,'error','AGV2_CHANNEL_INVALID'); end if;
  begin v_conv:=nullif(p_context->>'conversation_id','')::uuid; exception when others then return jsonb_build_object('ok',false,'error','AGV2_CONVERSATION_INVALID'); end;
  v_phone:=coalesce(nullif(btrim(p_context->>'contact_number'),''),nullif(btrim(p_payload->>'phone'),''));
  v_phone_norm:=regexp_replace(coalesce(v_phone,''),'[^0-9]','','g');
  v_campaign:=nullif(btrim(p_context->>'campaign_source'),'');
  v_ad:=nullif(btrim(p_context->>'ad_id'),'');
  v_lead:=nullif(btrim(p_context->>'lead_id'),'');
  v_reason:=nullif(btrim(p_payload->>'reason'),'');

  perform pg_advisory_xact_lock(hashtextextended('agv2-op:'||p_idempotency_key,0));
  v_hash:=encode(digest(convert_to(v_channel||'|'||coalesce(v_conv::text,'')||'|'||v_actor::text||'|'||p_appointment_id||'|'||p_payload::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from public.aos_booking_operations_v2 where idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then return jsonb_build_object('ok',false,'error','AGV2_IDEMPOTENCY_MISMATCH'); end if;
    return jsonb_set(v_existing.response,'{idempotent_replay}','true'::jsonb,true);
  end if;

  select * into v_cita from public.aos_agenda_citas where id=p_appointment_id for update;
  if not found then return jsonb_build_object('ok',false,'error','AGV2_APPOINTMENT_NOT_FOUND'); end if;
  if upper(coalesce(v_cita.estado_cita,'PENDIENTE')) not in ('PENDIENTE','CITA CONFIRMADA') then
    return jsonb_build_object('ok',false,'error','AGV2_REBOOK_STATE_BLOCKED','current_status',v_cita.estado_cita);
  end if;
  if v_channel='WHATSAPP' then
    if length(v_phone_norm)<7 or v_phone_norm<>regexp_replace(coalesce(v_cita.numero_limpio,v_cita.numero,''),'[^0-9]','','g') then
      return jsonb_build_object('ok',false,'error','AGV2_REBOOK_APPOINTMENT_IDENTITY_MISMATCH','requires_human',true);
    end if;
  end if;

  if length(v_phone_norm)>=7 then
    v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',v_phone_norm),'{}'::jsonb);
    v_identity_state:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
    if v_identity_state='IDENTITY_CONFLICT' then return jsonb_build_object('ok',false,'error','AGV2_IDENTITY_CONFLICT','requires_human',true); end if;
    if v_identity_state not in ('MATCH','UNRESOLVED') then return jsonb_build_object('ok',false,'error','AGV2_IDENTITY_NOT_READY','requires_human',true); end if;
  end if;

  select treatment_id into v_treatment_id
  from public.aos_booking_operations_v2
  where appointment_id=p_appointment_id
  order by created_at asc
  limit 1;
  if v_treatment_id is null then
    select treatment_id into v_treatment_id from public.aos_wa4_booking_actions_v1 where agenda_id=p_appointment_id order by created_at asc limit 1;
  end if;
  if v_treatment_id is null then
    select id into v_treatment_id from public.aos_catalogo_servicios
    where upper(btrim(nombre))=upper(btrim(coalesce(v_cita.tratamiento,'')))
      and upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO'
    order by created_at desc nulls last limit 1;
  end if;
  if v_treatment_id is null then return jsonb_build_object('ok',false,'error','AGV2_REBOOK_TREATMENT_UNRESOLVED','requires_human',true); end if;
  select * into v_t from public.aos_catalogo_servicios where id=v_treatment_id;

  v_site:=upper(replace(btrim(coalesce(p_payload->>'site','')),'_',' '));
  begin v_date:=(p_payload->>'date')::date; v_time:=(p_payload->>'time')::time;
  exception when others then return jsonb_build_object('ok',false,'error','AGV2_DATE_TIME_INVALID'); end;
  v_prof:=nullif(btrim(p_payload->>'professional_id'),'');
  v_role:=nullif(upper(btrim(p_payload->>'slot_role')),'');

  if v_site=upper(replace(btrim(coalesce(v_cita.sede,'')),'_',' '))
     and v_date=v_cita.fecha_cita
     and to_char(v_time,'HH24:MI')=left(coalesce(v_cita.hora_cita,''),5)
     and (
       (upper(coalesce(v_cita.tipo_atencion,''))='ENFERMERIA' and coalesce(v_role,'ENFERMERIA')='ENFERMERIA')
       or (upper(coalesce(v_cita.tipo_atencion,''))='DOCTORA' and upper(coalesce(v_cita.doctora,''))=upper(coalesce((select nombre_publico from public.aos_perfiles_profesional where id=v_prof limit 1),'')))
     ) then
    return jsonb_build_object('ok',true,'status','NO_CHANGE','appointment_id',p_appointment_id,'idempotent_replay',false);
  end if;

  v_slot:=public.aos_booking_resolve_selected_slot_v2(v_t.id,v_date,v_site,v_time,v_prof,v_role);
  if coalesce((v_slot->>'ok')::boolean,false) is not true then return v_slot; end if;
  v_prof_ref:=v_slot->>'professional_ref';v_prof_name:=v_slot->>'professional_name';v_role:=v_slot->>'role';v_booking_mode:=v_slot->>'booking_mode';

  perform pg_advisory_xact_lock(hashtextextended('agv2-slot:'||v_prof_ref||':'||v_date::text||':'||to_char(v_time,'HH24:MI')||':'||v_site,0));
  v_slot:=public.aos_booking_resolve_selected_slot_v2(v_t.id,v_date,v_site,v_time,case when v_role='DOCTORA' then v_prof else null end,v_role);
  if coalesce((v_slot->>'ok')::boolean,false) is not true then return v_slot; end if;

  v_before:=jsonb_build_object(
    'appointment_id',v_cita.id,'treatment',v_cita.tratamiento,'site',v_cita.sede,'date',v_cita.fecha_cita,
    'time',left(coalesce(v_cita.hora_cita,''),5),'role',v_cita.tipo_atencion,'professional_name',v_cita.doctora,
    'status',v_cita.estado_cita
  );

  if upper(coalesce(v_cita.origen_cita,''))='WHATSAPP' then perform set_config('aos.wa4_governed_booking_write','1',true); end if;
  update public.aos_agenda_citas
  set fecha_cita=v_date,
      hora_cita=to_char(v_time,'HH24:MI'),
      sede=v_site,
      doctora=case when v_role='DOCTORA' then v_prof_name else null end,
      tipo_atencion=v_role,
      estado_cita='PENDIENTE',
      ts_actualizado=now()
  where id=p_appointment_id;

  v_after:=jsonb_build_object(
    'appointment_id',p_appointment_id,'treatment_id',v_t.id,'treatment',v_t.nombre,'site',v_site,'date',v_date,
    'time',to_char(v_time,'HH24:MI'),'role',v_role,'professional_ref',v_prof_ref,'professional_name',v_prof_name,
    'booking_mode',v_booking_mode,'status','PENDIENTE'
  );

  v_response:=jsonb_build_object(
    'ok',true,'status','REBOOKED','appointment_id',p_appointment_id,'operation_id',v_op_id,
    'idempotent_replay',false,'confirmation_allowed',true,'identity_state',v_identity_state,
    'site',v_site,'date',v_date,'time',to_char(v_time,'HH24:MI'),'professional_role',v_role,
    'booking_mode',v_booking_mode,'professional_id',case when v_role='DOCTORA' then v_prof else null end,
    'professional_name',v_prof_name
  );

  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,conversation_id,appointment_id,
    treatment_id,professional_ref,site,appointment_date,appointment_time,identity_state,
    campaign_source,ad_id,lead_id,status,response
  ) values (
    v_op_id,p_idempotency_key,v_hash,'REBOOK',v_channel,v_actor,v_conv,p_appointment_id,
    v_t.id,v_prof_ref,v_site,v_date,v_time,v_identity_state,v_campaign,v_ad,v_lead,'REBOOKED',v_response
  );

  insert into public.aos_agenda_events_v2(
    operation_id,appointment_id,event_type,actor_id,channel,conversation_id,reason,before_snapshot,after_snapshot
  ) values (v_op_id,p_appointment_id,'RESCHEDULED',v_actor,v_channel,v_conv,v_reason,v_before,v_after);

  return v_response;
end
$$;

-- Internal Agenda wrapper: strong session / Agenda permission, no direct browser write.
create or replace function public.aos_agenda_commit_booking_v2(
  p_token text,
  p_idempotency_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_actor uuid;
  v_code text;
  v_ctx jsonb;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-agenda',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-agenda',true); end if;
  if v_actor is null then return jsonb_build_object('ok',false,'error','AGENDA_2FA_PANEL_REQUIRED'); end if;
  select codigo_asesor into v_code from public.aos_usuarios where id=v_actor and activo=true;
  v_ctx:=jsonb_build_object(
    'actor_id',v_actor,'actor_code',coalesce(v_code,'AGENDA'),'channel','AGENDA',
    'contact_number',p_payload->>'phone','contact_name',concat_ws(' ',p_payload->>'name',p_payload->>'last_name')
  );
  return public.aos_booking_commit_core_v2(v_ctx,p_idempotency_key,p_payload);
end
$$;

create or replace function public.aos_agenda_rebook_v2(
  p_token text,
  p_idempotency_key text,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_actor uuid;
  v_code text;
  v_cita public.aos_agenda_citas%rowtype;
  v_ctx jsonb;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-agenda',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-agenda',true); end if;
  if v_actor is null then return jsonb_build_object('ok',false,'error','AGENDA_2FA_PANEL_REQUIRED'); end if;
  select * into v_cita from public.aos_agenda_citas where id=p_appointment_id;
  if not found then return jsonb_build_object('ok',false,'error','AGV2_APPOINTMENT_NOT_FOUND'); end if;
  select codigo_asesor into v_code from public.aos_usuarios where id=v_actor and activo=true;
  v_ctx:=jsonb_build_object(
    'actor_id',v_actor,'actor_code',coalesce(v_code,'AGENDA'),'channel','AGENDA',
    'contact_number',coalesce(v_cita.numero_limpio,v_cita.numero),'contact_name',concat_ws(' ',v_cita.nombre,v_cita.apellido)
  );
  return public.aos_booking_rebook_core_v2(v_ctx,p_idempotency_key,p_appointment_id,p_payload);
end
$$;

-- WA V2 wrappers. They preserve HUMAN_ONLY ownership/assignment before entering the shared core.
create or replace function public.aos_wa4_commit_booking_v2(
  p_actor_id uuid,
  p_idempotency_key text,
  p_conversation_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_ctx jsonb;
begin
  if p_actor_id is null or p_conversation_id is null then return jsonb_build_object('ok',false,'error','WA4_BOOKING_ACTOR_AND_CONVERSATION_REQUIRED'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from p_actor_id then return jsonb_build_object('ok',false,'error','WA4_BOOKING_NOT_CONVERSATION_OWNER'); end if;
  if upper(coalesce(v_conv.state,'')) not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_STATE_BLOCKED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=p_actor_id and a.state='ACTIVE') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;
  if coalesce(regexp_replace(v_conv.contact_number,'[^0-9]','','g'),'')='' then return jsonb_build_object('ok',false,'error','WA4_BOOKING_TRUSTED_PHONE_REQUIRED'); end if;
  v_ctx:=jsonb_build_object(
    'actor_id',p_actor_id,'channel','WHATSAPP','conversation_id',p_conversation_id,
    'contact_number',v_conv.contact_number,'contact_name',v_conv.contact_name,
    'campaign_source',v_conv.campaign_source,'ad_id',v_conv.ad_id,'lead_id',v_conv.lead_id
  );
  return public.aos_booking_commit_core_v2(v_ctx,p_idempotency_key,p_payload);
end
$$;

create or replace function public.aos_wa4_rebook_booking_v2(
  p_actor_id uuid,
  p_idempotency_key text,
  p_conversation_id uuid,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_ctx jsonb;
begin
  if p_actor_id is null or p_conversation_id is null then return jsonb_build_object('ok',false,'error','WA4_REBOOK_ACTOR_AND_CONVERSATION_REQUIRED'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA4_REBOOK_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from p_actor_id then return jsonb_build_object('ok',false,'error','WA4_REBOOK_NOT_CONVERSATION_OWNER'); end if;
  if upper(coalesce(v_conv.state,'')) not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA4_REBOOK_CONVERSATION_STATE_BLOCKED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=p_actor_id and a.state='ACTIVE') then
    return jsonb_build_object('ok',false,'error','WA4_REBOOK_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;
  v_ctx:=jsonb_build_object(
    'actor_id',p_actor_id,'channel','WHATSAPP','conversation_id',p_conversation_id,
    'contact_number',v_conv.contact_number,'contact_name',v_conv.contact_name,
    'campaign_source',v_conv.campaign_source,'ad_id',v_conv.ad_id,'lead_id',v_conv.lead_id
  );
  return public.aos_booking_rebook_core_v2(v_ctx,p_idempotency_key,p_appointment_id,p_payload);
end
$$;

revoke all on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) from public,anon,authenticated;
revoke all on function public.aos_booking_commit_core_v2(jsonb,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_booking_rebook_core_v2(jsonb,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_wa4_commit_booking_v2(uuid,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.aos_wa4_rebook_booking_v2(uuid,text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) to service_role;
grant execute on function public.aos_booking_commit_core_v2(jsonb,text,jsonb) to service_role;
grant execute on function public.aos_booking_rebook_core_v2(jsonb,text,text,jsonb) to service_role;
grant execute on function public.aos_wa4_commit_booking_v2(uuid,text,uuid,jsonb) to service_role;
grant execute on function public.aos_wa4_rebook_booking_v2(uuid,text,uuid,text,jsonb) to service_role;

revoke all on function public.aos_agenda_commit_booking_v2(text,text,jsonb) from public;
revoke all on function public.aos_agenda_rebook_v2(text,text,text,jsonb) from public;
grant execute on function public.aos_agenda_commit_booking_v2(text,text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_agenda_rebook_v2(text,text,text,jsonb) to anon,authenticated,service_role;

comment on table public.aos_booking_operations_v2 is 'AGV2-2 idempotent BOOK/REBOOK operation ledger shared by Agenda and WhatsApp.';
comment on table public.aos_agenda_events_v2 is 'AGV2-2 append-only appointment event ledger. REBOOK preserves the same logical appointment id.';
comment on function public.aos_agenda_commit_booking_v2(text,text,jsonb) is 'AGV2-2 strong-session Agenda BOOK wrapper over unified transactional authority.';
comment on function public.aos_wa4_commit_booking_v2(uuid,text,uuid,jsonb) is 'AGV2-2 HUMAN_ONLY WhatsApp BOOK wrapper over unified transactional authority; v1 remains live until rollout certification.';

commit;
