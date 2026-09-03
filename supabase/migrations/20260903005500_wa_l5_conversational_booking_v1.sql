-- ASCENDA OS · WA-L5 Conversational BOOK/REBOOK Wiring V1
-- Additive/dormant production contract. This migration never enables CANARY or autonomous traffic.
begin;

create table if not exists public.aos_wa_l5_booking_memory_v1 (
  conversation_id uuid primary key references public.aos_wa_conversations_v1(id) on delete cascade,
  flow text not null default 'BOOK' check (flow in ('BOOK','REBOOK')),
  state text not null default 'COLLECTING' check (state in ('COLLECTING','SLOT_SELECTED','AWAITING_CONFIRMATION','CONFIRMED','RESELECT_REQUIRED','COMMITTED','HANDOFF')),
  treatment_id uuid references public.aos_catalogo_servicios(id) on delete restrict,
  site text check (site is null or site in ('SAN ISIDRO','PUEBLO LIBRE')),
  target_date date,
  selected_time time,
  professional_id text,
  slot_role text check (slot_role is null or slot_role in ('DOCTORA','ENFERMERIA')),
  appointment_id text,
  canonical_patient_id text,
  given_name text,
  family_name text,
  identity_state text not null default 'UNRESOLVED',
  confirmation_nonce uuid,
  confirmation_prepared_at timestamptz,
  confirmation_expires_at timestamptz,
  confirmation_message_id text,
  confirmed_at timestamptz,
  operation_id uuid,
  last_error_code text,
  revision bigint not null default 0 check (revision>=0),
  updated_at timestamptz not null default now()
);
create unique index if not exists idx_aos_wa_l5_booking_memory_nonce_v1
  on public.aos_wa_l5_booking_memory_v1(confirmation_nonce)
  where confirmation_nonce is not null;
create index if not exists idx_aos_wa_l5_booking_memory_state_v1
  on public.aos_wa_l5_booking_memory_v1(state,updated_at desc);

create table if not exists public.aos_wa_l5_booking_events_v1 (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  event_type text not null check (event_type in ('VERIFIED','PREPARED','CONFIRMED','COMMITTED','RESELECT_REQUIRED','HANDOFF')),
  flow text not null check (flow in ('BOOK','REBOOK')),
  state text not null,
  revision bigint not null,
  appointment_id text,
  operation_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_aos_wa_l5_booking_events_conv_v1
  on public.aos_wa_l5_booking_events_v1(conversation_id,created_at desc);

alter table public.aos_wa_l5_booking_memory_v1 enable row level security;
alter table public.aos_wa_l5_booking_memory_v1 force row level security;
alter table public.aos_wa_l5_booking_events_v1 enable row level security;
alter table public.aos_wa_l5_booking_events_v1 force row level security;
revoke all on table public.aos_wa_l5_booking_memory_v1 from public,anon,authenticated,service_role;
revoke all on table public.aos_wa_l5_booking_events_v1 from public,anon,authenticated,service_role;
grant select on table public.aos_wa_l5_booking_memory_v1 to service_role;
grant select on table public.aos_wa_l5_booking_events_v1 to service_role;

create or replace function public.aos_wa_l5_append_guard_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  raise exception 'WA_L5_APPEND_ONLY' using errcode='55000';
end
$$;
drop trigger if exists trg_aos_wa_l5_booking_events_append_guard_v1 on public.aos_wa_l5_booking_events_v1;
create trigger trg_aos_wa_l5_booking_events_append_guard_v1
before update or delete on public.aos_wa_l5_booking_events_v1
for each row execute function public.aos_wa_l5_append_guard_v1();

create or replace function public.aos_wa_l5_log_event_v1(
  p_conversation_id uuid,
  p_event_type text,
  p_flow text,
  p_state text,
  p_revision bigint,
  p_appointment_id text default null,
  p_operation_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into public.aos_wa_l5_booking_events_v1(
    conversation_id,event_type,flow,state,revision,appointment_id,operation_id,metadata
  ) values(
    p_conversation_id,p_event_type,p_flow,p_state,p_revision,p_appointment_id,p_operation_id,
    coalesce(p_metadata,'{}'::jsonb) - 'document' - 'dni' - 'email' - 'message_body' - 'raw_text' - 'prompt' - 'reply'
  );
end
$$;

create or replace function public.aos_wa_l5_is_explicit_affirmative_v1(p_text text)
returns boolean
language sql
immutable
set search_path=''
as $$
  select lower(btrim(coalesce(p_text,''))) ~
    '^(si|sí|confirmo|confirmar|confirmado|confirmar cita|confirmo la cita|si confirmo|sí confirmo|de acuerdo|de acuerdo confirmo|ok|okay|dale|correcto|esta bien|está bien)[[:space:][:punct:]]*$'
$$;

create or replace function public.aos_wa_l5_status_v1(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v public.aos_wa_l5_booking_memory_v1%rowtype;
begin
  if p_conversation_id is null then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_REQUIRED'); end if;
  select * into v from public.aos_wa_l5_booking_memory_v1 where conversation_id=p_conversation_id;
  if not found then
    return jsonb_build_object('ok',true,'version','WA-L5-V1','state','IDLE','flow',null,'confirmation_required',false);
  end if;
  return jsonb_build_object(
    'ok',true,'version','WA-L5-V1','flow',v.flow,'state',v.state,'treatment_id',v.treatment_id,
    'site',v.site,'date',v.target_date,'time',case when v.selected_time is null then null else to_char(v.selected_time,'HH24:MI') end,
    'professional_id',v.professional_id,'slot_role',v.slot_role,'appointment_id',v.appointment_id,
    'identity_state',v.identity_state,'confirmation_required',v.state='AWAITING_CONFIRMATION',
    'confirmation_expires_at',v.confirmation_expires_at,'confirmed_at',v.confirmed_at,
    'operation_id',v.operation_id,'last_error_code',v.last_error_code,'revision',v.revision,'updated_at',v.updated_at
  );
end
$$;

create or replace function public.aos_wa_l5_availability_v1(
  p_conversation_id uuid,
  p_treatment_id uuid,
  p_site text,
  p_start_date date default null,
  p_professional_id text default null,
  p_slot_role text default null,
  p_search_days integer default 14
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_site text:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  v_role text:=nullif(upper(btrim(coalesce(p_slot_role,''))), '');
  v_start date:=coalesce(p_start_date,current_date);
  v_days integer:=least(greatest(coalesce(p_search_days,14),1),21);
  v_i integer;
  v_date date;
  v_av jsonb;
  v_slots jsonb;
  v_dates jsonb:='[]'::jsonb;
  v_count integer:=0;
begin
  if p_conversation_id is null or p_treatment_id is null then return jsonb_build_object('ok',false,'error','WA_L5_AVAILABILITY_INPUT_REQUIRED'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id;
  if not found then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_NOT_FOUND'); end if;
  if upper(coalesce(v_conv.state,'')) in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_TERMINAL'); end if;
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','WA_L5_SITE_REQUIRED'); end if;
  if v_role is not null and v_role not in ('DOCTORA','ENFERMERIA') then return jsonb_build_object('ok',false,'error','WA_L5_SLOT_ROLE_INVALID'); end if;
  if not exists(select 1 from public.aos_catalogo_servicios s where s.id=p_treatment_id and upper(coalesce(s.estado,'ACTIVO'))='ACTIVO' and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO') then
    return jsonb_build_object('ok',false,'error','WA_L5_TREATMENT_NOT_ACTIVE');
  end if;

  for v_i in 0..v_days-1 loop
    v_date:=v_start+v_i;
    if v_date<current_date or extract(isodow from v_date)=7 then continue; end if;
    v_av:=coalesce(public.aos_booking_availability_v2(
      p_treatment_id,v_date,v_site,
      case when v_role='ENFERMERIA' then null else nullif(btrim(coalesce(p_professional_id,'')),'') end
    ),'{}'::jsonb);
    if coalesce((v_av->>'ok')::boolean,false) is not true then continue; end if;

    select coalesce(jsonb_agg(q.slot order by q.hora),'[]'::jsonb) into v_slots
    from (
      select s->>'hora' as hora,
        jsonb_build_object(
          'date',v_date,
          'time',s->>'hora',
          'site',v_site,
          'role',s->>'role',
          'professional_id',nullif(s->>'professional_id',''),
          'professional_name',nullif(s->>'professional_name','')
        ) as slot
      from jsonb_array_elements(coalesce(v_av->'slots','[]'::jsonb)) s
      where coalesce((s->>'disponible')::boolean,false)=true
        and (v_role is null or upper(coalesce(s->>'role',''))=v_role)
        and (
          nullif(btrim(coalesce(p_professional_id,'')),'') is null
          or v_role='ENFERMERIA'
          or s->>'professional_id'=nullif(btrim(coalesce(p_professional_id,'')),'')
        )
      order by s->>'hora'
      limit 5
    ) q;

    if jsonb_array_length(v_slots)>0 then
      v_dates:=v_dates||jsonb_build_array(jsonb_build_object('date',v_date,'slots',v_slots));
      v_count:=v_count+1;
      exit when v_count>=3;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'status',case when v_count>0 then 'REAL_AVAILABILITY_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',p_treatment_id,'site',v_site,'dates',v_dates,'max_dates',3,'max_slots_per_date',5,
    'free_text_allowed',true,'authority','aos_booking_availability_v2'
  );
end
$$;

create or replace function public.aos_wa_l5_verify_patient_v1(
  p_conversation_id uuid,
  p_document text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_identity jsonb;
  v_status text;
  v_canonical text;
  v_doc text:=regexp_replace(coalesce(p_document,''),'[^0-9]','','g');
  v_expected text;
  v_mem public.aos_wa_l5_booking_memory_v1%rowtype;
begin
  if p_conversation_id is null or length(v_doc)<6 then return jsonb_build_object('ok',false,'error','WA_L5_VERIFICATION_FAILED','requires_human',true); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found or upper(coalesce(v_conv.state,'')) in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA_L5_VERIFICATION_FAILED','requires_human',true); end if;
  v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',regexp_replace(coalesce(v_conv.contact_number,''),'[^0-9]','','g')),'{}'::jsonb);
  v_status:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
  v_canonical:=nullif(btrim(v_identity->>'canonical_patient_id'),'');
  if v_status<>'MATCH' or v_canonical is null then return jsonb_build_object('ok',false,'error','WA_L5_VERIFICATION_FAILED','requires_human',true); end if;
  select regexp_replace(coalesce(p."N° documento",''),'[^0-9]','','g') into v_expected
  from public.aos_pacientes p
  where p."ID_PACIENTE"::text=v_canonical and upper(coalesce(p."ESTADO_PACIENTE",'ACTIVO'))<>'FUSIONADO'
  limit 1;
  if coalesce(v_expected,'')='' or v_expected<>v_doc then return jsonb_build_object('ok',false,'error','WA_L5_VERIFICATION_FAILED','requires_human',true); end if;

  insert into public.aos_wa_l5_booking_memory_v1(conversation_id,flow,state,canonical_patient_id,identity_state,revision,updated_at)
  values(p_conversation_id,'REBOOK','COLLECTING',v_canonical,'VERIFIED',1,now())
  on conflict(conversation_id) do update
  set flow='REBOOK',state=case when public.aos_wa_l5_booking_memory_v1.state='COMMITTED' then 'COLLECTING' else public.aos_wa_l5_booking_memory_v1.state end,
      canonical_patient_id=v_canonical,identity_state='VERIFIED',last_error_code=null,
      revision=public.aos_wa_l5_booking_memory_v1.revision+1,updated_at=now()
  returning * into v_mem;
  perform public.aos_wa_l5_log_event_v1(p_conversation_id,'VERIFIED','REBOOK',v_mem.state,v_mem.revision,null,null,jsonb_build_object('method','DOCUMENT_EXACT','document_stored',false));
  return jsonb_build_object('ok',true,'status','VERIFIED','identity_state','VERIFIED','document_stored',false,'revision',v_mem.revision);
end
$$;

create or replace function public.aos_wa_l5_active_appointments_v1(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_mem public.aos_wa_l5_booking_memory_v1%rowtype;
  v_total integer:=0;
  v_options jsonb:='[]'::jsonb;
begin
  if p_conversation_id is null then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_REQUIRED'); end if;
  select * into v_mem from public.aos_wa_l5_booking_memory_v1 where conversation_id=p_conversation_id;
  if not found or v_mem.identity_state<>'VERIFIED' or coalesce(v_mem.canonical_patient_id,'')='' then
    return jsonb_build_object('ok',false,'error','WA_L5_REBOOK_VERIFICATION_REQUIRED','requires_verification',true);
  end if;

  select count(*)::integer into v_total
  from public.aos_rev_customer_agenda_identity_v1 i
  join public.aos_agenda_citas a on a.id=i.appointment_id
  where i.canonical_patient_id=v_mem.canonical_patient_id
    and upper(coalesce(i.identity_status,''))='RESOLVED'
    and a.fecha_cita>=current_date
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA');

  select coalesce(jsonb_agg(x.j order by x.fecha,x.hora),'[]'::jsonb) into v_options
  from (
    select a.fecha_cita as fecha,left(coalesce(a.hora_cita,''),5) as hora,
      jsonb_build_object(
        'appointment_id',a.id,'date',a.fecha_cita,'time',left(coalesce(a.hora_cita,''),5),
        'site',a.sede,'treatment',a.tratamiento,'status',a.estado_cita
      ) as j
    from public.aos_rev_customer_agenda_identity_v1 i
    join public.aos_agenda_citas a on a.id=i.appointment_id
    where i.canonical_patient_id=v_mem.canonical_patient_id
      and upper(coalesce(i.identity_status,''))='RESOLVED'
      and a.fecha_cita>=current_date
      and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    order by a.fecha_cita,left(coalesce(a.hora_cita,''),5)
    limit 5
  ) x;

  return jsonb_build_object(
    'ok',true,
    'status',case when v_total=0 then 'NO_ACTIVE_APPOINTMENT' when v_total=1 then 'ACTIVE_APPOINTMENT_READY' else 'APPOINTMENT_SELECTION_REQUIRED' end,
    'count',v_total,'options',v_options,'requires_selection',v_total>1
  );
end
$$;

create or replace function public.aos_wa_l5_appointment_treatment_v1(p_appointment_id text)
returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_tid uuid; v_name text; v_count integer; begin
  select o.treatment_id into v_tid from public.aos_booking_operations_v2 o where o.appointment_id=p_appointment_id order by o.created_at asc limit 1;
  if v_tid is not null then return v_tid; end if;
  select a.treatment_id into v_tid from public.aos_wa4_booking_actions_v1 a where a.agenda_id=p_appointment_id order by a.created_at asc limit 1;
  if v_tid is not null then return v_tid; end if;
  select c.tratamiento into v_name from public.aos_agenda_citas c where c.id=p_appointment_id;
  if coalesce(btrim(v_name),'')='' then return null; end if;
  select count(*)::integer,min(s.id) into v_count,v_tid from public.aos_catalogo_servicios s
  where upper(btrim(s.nombre))=upper(btrim(v_name)) and upper(coalesce(s.estado,'ACTIVO'))='ACTIVO' and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO';
  if v_count<>1 then return null; end if;
  return v_tid;
end
$$;

create or replace function public.aos_wa_l5_prepare_confirmation_v1(
  p_conversation_id uuid,
  p_flow text,
  p_treatment_id uuid,
  p_site text,
  p_date date,
  p_time time,
  p_professional_id text default null,
  p_slot_role text default null,
  p_appointment_id text default null,
  p_given_name text default null,
  p_family_name text default null,
  p_confirmation_ttl_seconds integer default 600
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_existing public.aos_wa_l5_booking_memory_v1%rowtype;
  v_mem public.aos_wa_l5_booking_memory_v1%rowtype;
  v_flow text:=upper(btrim(coalesce(p_flow,'')));
  v_site text:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  v_role text:=nullif(upper(btrim(coalesce(p_slot_role,''))), '');
  v_prof text:=nullif(btrim(coalesce(p_professional_id,'')),'');
  v_tid uuid:=p_treatment_id;
  v_identity jsonb;
  v_identity_status text;
  v_canonical text;
  v_slot jsonb;
  v_nonce uuid:=gen_random_uuid();
  v_ttl integer:=least(greatest(coalesce(p_confirmation_ttl_seconds,600),60),1800);
  v_name text:=nullif(btrim(coalesce(p_given_name,'')),'');
  v_last text:=nullif(btrim(coalesce(p_family_name,'')),'');
begin
  if p_conversation_id is null or v_flow not in ('BOOK','REBOOK') or p_date is null or p_time is null then
    return jsonb_build_object('ok',false,'error','WA_L5_PREPARE_INPUT_INVALID');
  end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_NOT_FOUND'); end if;
  if upper(coalesce(v_conv.state,'')) in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_TERMINAL'); end if;
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','WA_L5_SITE_REQUIRED'); end if;

  v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',regexp_replace(coalesce(v_conv.contact_number,''),'[^0-9]','','g')),'{}'::jsonb);
  v_identity_status:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
  v_canonical:=nullif(btrim(v_identity->>'canonical_patient_id'),'');
  if v_identity_status='IDENTITY_CONFLICT' then
    insert into public.aos_wa_l5_booking_memory_v1(conversation_id,flow,state,identity_state,last_error_code,revision,updated_at)
    values(p_conversation_id,v_flow,'HANDOFF','IDENTITY_CONFLICT','WA_L5_IDENTITY_CONFLICT',1,now())
    on conflict(conversation_id) do update set flow=v_flow,state='HANDOFF',identity_state='IDENTITY_CONFLICT',last_error_code='WA_L5_IDENTITY_CONFLICT',revision=public.aos_wa_l5_booking_memory_v1.revision+1,updated_at=now()
    returning * into v_mem;
    perform public.aos_wa_l5_log_event_v1(p_conversation_id,'HANDOFF',v_flow,'HANDOFF',v_mem.revision,p_appointment_id,null,jsonb_build_object('reason','IDENTITY_CONFLICT'));
    return jsonb_build_object('ok',false,'error','WA_L5_IDENTITY_CONFLICT','requires_human',true);
  end if;

  if v_flow='BOOK' then
    if v_identity_status not in ('MATCH','UNRESOLVED') then return jsonb_build_object('ok',false,'error','WA_L5_IDENTITY_NOT_READY','requires_human',true); end if;
    if v_identity_status='MATCH' and v_canonical is null then return jsonb_build_object('ok',false,'error','WA_L5_CANONICAL_ID_MISSING','requires_human',true); end if;
    if v_identity_status='UNRESOLVED' and (v_name is null or v_last is null) then
      return jsonb_build_object('ok',false,'error','WA_L5_NAME_AND_LAST_NAME_REQUIRED','email_optional',true,'dni_optional',true);
    end if;
    if v_tid is null then return jsonb_build_object('ok',false,'error','WA_L5_TREATMENT_REQUIRED'); end if;
  else
    select * into v_existing from public.aos_wa_l5_booking_memory_v1 where conversation_id=p_conversation_id for update;
    if not found or v_existing.identity_state<>'VERIFIED' or coalesce(v_existing.canonical_patient_id,'')='' then
      return jsonb_build_object('ok',false,'error','WA_L5_REBOOK_VERIFICATION_REQUIRED','requires_verification',true);
    end if;
    if coalesce(btrim(p_appointment_id),'')='' then return jsonb_build_object('ok',false,'error','WA_L5_APPOINTMENT_REQUIRED'); end if;
    if not exists(
      select 1 from public.aos_rev_customer_agenda_identity_v1 i
      join public.aos_agenda_citas a on a.id=i.appointment_id
      where i.appointment_id=p_appointment_id and i.canonical_patient_id=v_existing.canonical_patient_id
        and upper(coalesce(i.identity_status,''))='RESOLVED' and a.fecha_cita>=current_date
        and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    ) then return jsonb_build_object('ok',false,'error','WA_L5_APPOINTMENT_NOT_VERIFIED','requires_human',true); end if;
    v_canonical:=v_existing.canonical_patient_id;
    v_identity_status:='VERIFIED';
    v_tid:=public.aos_wa_l5_appointment_treatment_v1(p_appointment_id);
    if v_tid is null then return jsonb_build_object('ok',false,'error','WA_L5_REBOOK_TREATMENT_UNRESOLVED','requires_human',true); end if;
    if p_treatment_id is not null and p_treatment_id<>v_tid then return jsonb_build_object('ok',false,'error','WA_L5_REBOOK_TREATMENT_CHANGE_FORBIDDEN'); end if;
  end if;

  v_slot:=public.aos_booking_resolve_selected_slot_v2(v_tid,p_date,v_site,p_time,v_prof,v_role);
  if coalesce((v_slot->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error',coalesce(v_slot->>'error','WA_L5_SLOT_NOT_READY'),'slot',v_slot,'requires_reselection',true);
  end if;

  insert into public.aos_wa_l5_booking_memory_v1(
    conversation_id,flow,state,treatment_id,site,target_date,selected_time,professional_id,slot_role,appointment_id,
    canonical_patient_id,given_name,family_name,identity_state,confirmation_nonce,confirmation_prepared_at,confirmation_expires_at,
    confirmation_message_id,confirmed_at,operation_id,last_error_code,revision,updated_at
  ) values(
    p_conversation_id,v_flow,'AWAITING_CONFIRMATION',v_tid,v_site,p_date,p_time,
    case when v_slot->>'role'='DOCTORA' then nullif(v_slot->>'professional_id','') else null end,
    v_slot->>'role',case when v_flow='REBOOK' then p_appointment_id else null end,
    v_canonical,v_name,v_last,v_identity_status,v_nonce,now(),now()+make_interval(secs=>v_ttl),null,null,null,null,1,now()
  ) on conflict(conversation_id) do update set
    flow=excluded.flow,state=excluded.state,treatment_id=excluded.treatment_id,site=excluded.site,target_date=excluded.target_date,
    selected_time=excluded.selected_time,professional_id=excluded.professional_id,slot_role=excluded.slot_role,appointment_id=excluded.appointment_id,
    canonical_patient_id=excluded.canonical_patient_id,
    given_name=case when excluded.given_name is null then public.aos_wa_l5_booking_memory_v1.given_name else excluded.given_name end,
    family_name=case when excluded.family_name is null then public.aos_wa_l5_booking_memory_v1.family_name else excluded.family_name end,
    identity_state=excluded.identity_state,confirmation_nonce=excluded.confirmation_nonce,
    confirmation_prepared_at=excluded.confirmation_prepared_at,confirmation_expires_at=excluded.confirmation_expires_at,
    confirmation_message_id=null,confirmed_at=null,operation_id=null,last_error_code=null,
    revision=public.aos_wa_l5_booking_memory_v1.revision+1,updated_at=now()
  returning * into v_mem;

  perform public.aos_wa_l5_log_event_v1(
    p_conversation_id,'PREPARED',v_flow,'AWAITING_CONFIRMATION',v_mem.revision,v_mem.appointment_id,null,
    jsonb_build_object('treatment_id',v_tid,'site',v_site,'date',p_date,'time',to_char(p_time,'HH24:MI'),'role',v_mem.slot_role,'professional_id_present',v_mem.professional_id is not null,'confirmation_ttl_seconds',v_ttl)
  );

  return jsonb_build_object(
    'ok',true,'status','AWAITING_CONFIRMATION','flow',v_flow,'confirmation_required',true,
    'confirmation_nonce',v_nonce,'confirmation_expires_at',v_mem.confirmation_expires_at,
    'selection',jsonb_build_object('treatment_id',v_tid,'site',v_site,'date',p_date,'time',to_char(p_time,'HH24:MI'),'slot_role',v_mem.slot_role,'professional_id',v_mem.professional_id,'professional_name',v_slot->>'professional_name','appointment_id',v_mem.appointment_id),
    'identity_state',v_identity_status,'email_optional',true,'dni_optional',true,'revision',v_mem.revision
  );
end
$$;

create or replace function public.aos_wa_l5_mark_explicit_confirmation_v1(
  p_conversation_id uuid,
  p_confirmation_nonce uuid,
  p_provider_message_id text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_mem public.aos_wa_l5_booking_memory_v1%rowtype;
  v_msg public.aos_wa_messages_v1%rowtype;
  v_revision bigint;
begin
  if p_conversation_id is null or p_confirmation_nonce is null or coalesce(btrim(p_provider_message_id),'')='' then
    return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_INPUT_INVALID');
  end if;
  select * into v_mem from public.aos_wa_l5_booking_memory_v1 where conversation_id=p_conversation_id for update;
  if not found or v_mem.state<>'AWAITING_CONFIRMATION' then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_NOT_PENDING'); end if;
  if v_mem.confirmation_nonce is distinct from p_confirmation_nonce then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_NONCE_MISMATCH'); end if;
  if v_mem.confirmation_expires_at is null or v_mem.confirmation_expires_at<=now() then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_EXPIRED','requires_reselection',true); end if;
  select * into v_msg from public.aos_wa_messages_v1
  where provider_message_id=p_provider_message_id and conversation_id=p_conversation_id and direction='INBOUND'
  limit 1;
  if not found or v_msg.created_at<v_mem.confirmation_prepared_at then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_MESSAGE_INVALID'); end if;
  if public.aos_wa_l5_is_explicit_affirmative_v1(v_msg.message_body) is not true then return jsonb_build_object('ok',false,'error','WA_L5_EXPLICIT_CONFIRMATION_REQUIRED'); end if;

  update public.aos_wa_l5_booking_memory_v1
  set state='CONFIRMED',confirmation_message_id=p_provider_message_id,confirmed_at=now(),last_error_code=null,revision=revision+1,updated_at=now()
  where conversation_id=p_conversation_id returning revision into v_revision;
  perform public.aos_wa_l5_log_event_v1(p_conversation_id,'CONFIRMED',v_mem.flow,'CONFIRMED',v_revision,v_mem.appointment_id,null,jsonb_build_object('provider_message_id',p_provider_message_id,'raw_text_stored',false));
  return jsonb_build_object('ok',true,'status','CONFIRMED','flow',v_mem.flow,'provider_message_id',p_provider_message_id,'raw_text_stored',false,'revision',v_revision);
end
$$;

create or replace function public.aos_wa_l5_commit_confirmed_v1(
  p_conversation_id uuid,
  p_confirmation_nonce uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_mem public.aos_wa_l5_booking_memory_v1%rowtype;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_auth public.aos_wa_auto_authority_v1%rowtype;
  v_ai public.aos_wa_ai_control_v1%rowtype;
  v_route public.aos_wa_routing_control_v1%rowtype;
  v_phone text;
  v_allow boolean:=false;
  v_ctx jsonb;
  v_payload jsonb;
  v_out jsonb;
  v_operation uuid;
  v_appointment text;
  v_revision bigint;
  v_state text;
  v_error text;
begin
  if p_conversation_id is null or p_confirmation_nonce is null or coalesce(length(btrim(p_idempotency_key)),0)<16 or length(p_idempotency_key)>160 then
    return jsonb_build_object('ok',false,'error','WA_L5_COMMIT_INPUT_INVALID');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('wa-l5-commit:'||p_conversation_id::text,0));
  select * into v_mem from public.aos_wa_l5_booking_memory_v1 where conversation_id=p_conversation_id for update;
  if not found or v_mem.state<>'CONFIRMED' then return jsonb_build_object('ok',false,'error','WA_L5_NOT_CONFIRMED'); end if;
  if v_mem.confirmation_nonce is distinct from p_confirmation_nonce then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_NONCE_MISMATCH'); end if;
  if v_mem.confirmation_expires_at is null or v_mem.confirmation_expires_at<=now() then return jsonb_build_object('ok',false,'error','WA_L5_CONFIRMATION_EXPIRED','requires_reselection',true); end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA_L5_CONVERSATION_NOT_FOUND'); end if;
  if upper(coalesce(v_conv.state,'')) not in ('AI_ACTIVE','WAITING_CUSTOMER','APPOINTMENT_PENDING') or v_conv.human_takeover_at is not null then
    return jsonb_build_object('ok',false,'error','WA_L5_AUTONOMOUS_CONVERSATION_STATE_BLOCKED','requires_human',true);
  end if;

  select * into v_auth from public.aos_wa_auto_authority_v1 where id=1;
  select * into v_ai from public.aos_wa_ai_control_v1 where id=1;
  select * into v_route from public.aos_wa_routing_control_v1 where id=1;
  if v_auth.id is null or v_auth.mode='AUTO_OFF' then return jsonb_build_object('ok',false,'error','WA_L5_AUTO_OFF'); end if;
  if v_auth.kill_switch_engaged is true then return jsonb_build_object('ok',false,'error','WA_L5_KILL_SWITCH'); end if;
  if v_auth.mode not in ('CANARY','PROD') or v_ai.auto_reply_enabled is not true or v_route.ai_send_enabled is not true then
    return jsonb_build_object('ok',false,'error','WA_L5_AUTONOMOUS_FLAGS_NOT_READY');
  end if;

  v_phone:=regexp_replace(coalesce(v_conv.contact_number,''),'[^0-9]','','g');
  if v_auth.mode='CANARY' then
    select exists(
      select 1 from public.aos_wa_auto_allowlist_v1 a
      where a.active is true and (a.expires_at is null or a.expires_at>now()) and (
        (a.subject_kind='CONVERSATION' and a.subject_key=p_conversation_id::text)
        or (a.subject_kind='PHONE' and a.subject_key=v_phone)
        or (a.subject_kind='BSUID' and upper(coalesce(v_conv.contact_address_type,''))='BSUID' and a.subject_key=coalesce(v_conv.contact_address,''))
        or (a.subject_kind='CAMPAIGN' and coalesce(v_conv.campaign_source,'')<>'' and a.subject_key=v_conv.campaign_source)
      )
    ) into v_allow;
    if not v_allow then return jsonb_build_object('ok',false,'error','WA_L5_CANARY_NOT_ALLOWLISTED'); end if;
  end if;

  if v_auth.autonomous_actor_id is null then return jsonb_build_object('ok',false,'error','WA_L5_AUTONOMOUS_ACTOR_MISSING'); end if;
  v_ctx:=jsonb_build_object(
    'actor_id',v_auth.autonomous_actor_id,'channel','WHATSAPP','conversation_id',p_conversation_id,
    'contact_number',v_conv.contact_number,'contact_name',v_conv.contact_name,
    'campaign_source',v_conv.campaign_source,'ad_id',v_conv.ad_id,'lead_id',v_conv.lead_id
  );
  v_payload:=jsonb_strip_nulls(jsonb_build_object(
    'treatment_id',v_mem.treatment_id,'site',v_mem.site,'date',v_mem.target_date,'time',to_char(v_mem.selected_time,'HH24:MI'),
    'professional_id',v_mem.professional_id,'slot_role',v_mem.slot_role,'name',v_mem.given_name,'last_name',v_mem.family_name,
    'appointment_type','CONSULTA NUEVA','reason',case when v_mem.flow='REBOOK' then 'CONVERSATIONAL_REBOOK' else null end
  ));

  if v_mem.flow='BOOK' then
    v_out:=public.aos_booking_commit_core_v2(v_ctx,p_idempotency_key,v_payload);
  else
    if coalesce(v_mem.appointment_id,'')='' or v_mem.identity_state<>'VERIFIED' then return jsonb_build_object('ok',false,'error','WA_L5_REBOOK_VERIFICATION_REQUIRED','requires_human',true); end if;
    v_out:=public.aos_booking_rebook_core_v2(v_ctx,p_idempotency_key,v_mem.appointment_id,v_payload);
  end if;

  if coalesce((v_out->>'ok')::boolean,false) is true then
    v_appointment:=coalesce(nullif(v_out->>'appointment_id',''),v_mem.appointment_id);
    begin v_operation:=nullif(v_out->>'operation_id','')::uuid; exception when others then v_operation:=null; end;
    update public.aos_wa_l5_booking_memory_v1
    set state='COMMITTED',appointment_id=v_appointment,operation_id=v_operation,last_error_code=null,revision=revision+1,updated_at=now()
    where conversation_id=p_conversation_id returning revision into v_revision;
    perform public.aos_wa_l5_log_event_v1(p_conversation_id,'COMMITTED',v_mem.flow,'COMMITTED',v_revision,v_appointment,v_operation,jsonb_build_object('agv2_status',v_out->>'status','idempotent_replay',coalesce((v_out->>'idempotent_replay')::boolean,false)));
    return jsonb_build_object('ok',true,'status',v_out->>'status','flow',v_mem.flow,'appointment_id',v_appointment,'operation_id',v_operation,'agv2',v_out,'revision',v_revision);
  end if;

  v_error:=coalesce(v_out->>'error','WA_L5_AGV2_REJECTED');
  if v_error in ('AGV2_SLOT_NO_LONGER_AVAILABLE','AGV2_AUTHORITY_BLOCKED','AGV2_DATE_IN_PAST','AGV2_SUNDAY_CLOSED','AGV2_DATE_TIME_INVALID') then v_state:='RESELECT_REQUIRED'; else v_state:='HANDOFF'; end if;
  update public.aos_wa_l5_booking_memory_v1
  set state=v_state,last_error_code=v_error,confirmation_nonce=null,confirmation_prepared_at=null,confirmation_expires_at=null,confirmation_message_id=null,confirmed_at=null,revision=revision+1,updated_at=now()
  where conversation_id=p_conversation_id returning revision into v_revision;
  perform public.aos_wa_l5_log_event_v1(p_conversation_id,case when v_state='RESELECT_REQUIRED' then 'RESELECT_REQUIRED' else 'HANDOFF' end,v_mem.flow,v_state,v_revision,v_mem.appointment_id,null,jsonb_build_object('reason',v_error));
  return jsonb_build_object('ok',false,'error',v_error,'state',v_state,'requires_reselection',v_state='RESELECT_REQUIRED','requires_human',v_state='HANDOFF','agv2',v_out,'revision',v_revision);
end
$$;

revoke all on function public.aos_wa_l5_append_guard_v1() from public,anon,authenticated,service_role;
revoke all on function public.aos_wa_l5_log_event_v1(uuid,text,text,text,bigint,text,uuid,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.aos_wa_l5_is_explicit_affirmative_v1(text) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_status_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_availability_v1(uuid,uuid,text,date,text,text,integer) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_verify_patient_v1(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_active_appointments_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_appointment_treatment_v1(text) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_prepare_confirmation_v1(uuid,text,uuid,text,date,time,text,text,text,text,text,integer) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_mark_explicit_confirmation_v1(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa_l5_commit_confirmed_v1(uuid,uuid,text) from public,anon,authenticated;

grant execute on function public.aos_wa_l5_is_explicit_affirmative_v1(text) to service_role;
grant execute on function public.aos_wa_l5_status_v1(uuid) to service_role;
grant execute on function public.aos_wa_l5_availability_v1(uuid,uuid,text,date,text,text,integer) to service_role;
grant execute on function public.aos_wa_l5_verify_patient_v1(uuid,text) to service_role;
grant execute on function public.aos_wa_l5_active_appointments_v1(uuid) to service_role;
grant execute on function public.aos_wa_l5_appointment_treatment_v1(text) to service_role;
grant execute on function public.aos_wa_l5_prepare_confirmation_v1(uuid,text,uuid,text,date,time,text,text,text,text,text,integer) to service_role;
grant execute on function public.aos_wa_l5_mark_explicit_confirmation_v1(uuid,uuid,text) to service_role;
grant execute on function public.aos_wa_l5_commit_confirmed_v1(uuid,uuid,text) to service_role;

comment on table public.aos_wa_l5_booking_memory_v1 is 'WA-L5 bounded conversational BOOK/REBOOK state. No raw chat, clinical notes, DNI or email.';
comment on table public.aos_wa_l5_booking_events_v1 is 'WA-L5 append-only sanitized booking state events. Destructive rollback is forbidden after COMMITTED lineage.';
comment on function public.aos_wa_l5_commit_confirmed_v1(uuid,uuid,text) is 'WA-L5 autonomous BOOK/REBOOK bridge. Requires explicit inbound confirmation plus effective L4 CANARY/PROD authority; AUTO_OFF always blocks.';

select pg_notify('pgrst','reload schema');
commit;
