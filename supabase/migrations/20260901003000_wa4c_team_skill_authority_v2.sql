-- WA-4C · Team Skill Authority V2
-- Aligns detailed September catalog -> operational professional skills -> WhatsApp booking.
-- Key semantic: catalog role AMBOS means either an eligible doctor OR eligible nursing staff,
-- never that both must attend the same appointment.
-- HUMAN_ONLY / SAFE-OFF boundaries remain unchanged.

begin;

-- 1) Extend the operational skill master consumed by Admin > Equipo.
-- No professional is auto-granted a new skill here: assignment remains an explicit admin decision.
insert into public.aos_cat_tratamientos(
  tratamiento,estado,orden,ultima_edicion,editado_por,categoria,requiere_doctora,requiere_enfermeria
)
values
  ('MESOTERAPIA FACIAL','ACTIVO',310,now(),'WA4C_TEAM_SKILL_V2','FACIAL',true,true),
  ('MICRONEEDLING FACIAL','ACTIVO',311,now(),'WA4C_TEAM_SKILL_V2','FACIAL',true,true),
  ('NANO GLOW','ACTIVO',312,now(),'WA4C_TEAM_SKILL_V2','FACIAL',true,true),
  ('BIOREVITALIZACION FACIAL','ACTIVO',313,now(),'WA4C_TEAM_SKILL_V2','FACIAL',true,false),
  ('FACIALES','ACTIVO',314,now(),'WA4C_TEAM_SKILL_V2','FACIAL',false,true),
  ('APARATOLOGIA CORPORAL','ACTIVO',315,now(),'WA4C_TEAM_SKILL_V2','APARATOLOGÍA',false,true),
  ('CARBOXITERAPIA','ACTIVO',316,now(),'WA4C_TEAM_SKILL_V2','CORPORAL',false,true),
  ('HIDROENZIMAS','ACTIVO',317,now(),'WA4C_TEAM_SKILL_V2','CORPORAL',false,true),
  ('MESOTERAPIA CORPORAL','ACTIVO',318,now(),'WA4C_TEAM_SKILL_V2','CORPORAL',false,true),
  ('PEELINGS','ACTIVO',319,now(),'WA4C_TEAM_SKILL_V2','FACIAL',false,true)
on conflict(tratamiento) do update
set estado='ACTIVO',
    categoria=excluded.categoria,
    requiere_doctora=excluded.requiere_doctora,
    requiere_enfermeria=excluded.requiere_enfermeria,
    ultima_edicion=now(),
    editado_por='WA4C_TEAM_SKILL_V2';

-- 2) Deterministic service -> skill reconciliation.
-- Exact-name mapping has precedence over broad/fuzzy catalog matching.
insert into public.aos_booking_capability_map_v1(service_name_norm,capability,evidence_ref,active)
values
  -- Capilar: correct overly-broad legacy resolutions.
  (public.aos_booking_norm_v1('HAIR COCTEL MESO x1'),'MESOTERAPIA CAPILAR','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('HAIR COCTEL MESO x3'),'MESOTERAPIA CAPILAR','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESO CAPILAR VIT x1'),'MESOTERAPIA CAPILAR','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESO CAPILAR VIT x3'),'MESOTERAPIA CAPILAR','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('EXOSOMAS EXOSIGNAL HAIR x1'),'EXOSOMAS CAPILARES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('EXOSOMAS EXOSIGNAL HAIR x3'),'EXOSOMAS CAPILARES','TEAM_SKILL_V2:EXACT',true),

  -- Mesoterapia facial: explicit new operational skill requested in Panel Equipo.
  (public.aos_booking_norm_v1('MESOTERAPIA C/ PLASMA FACIAL x1'),'MESOTERAPIA FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESOTERAPIA C/ PLASMA FACIAL x3'),'MESOTERAPIA FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MICRONEEDLING C/ PLASMA x1'),'MICRONEEDLING FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MICRONEEDLING C/ PLASMA x3'),'MICRONEEDLING FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('NANO GLOW x1'),'NANO GLOW','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('NANO GLOW x3'),'NANO GLOW','TEAM_SKILL_V2:EXACT',true),

  -- Doctor-only biorevitalization family.
  (public.aos_booking_norm_v1('ÁC. SUCCÍNICO AMBER x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('ÁC. SUCCÍNICO AMBER x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('ÁC. TRANEXÁMICO x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('ÁC. TRANEXÁMICO x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CELLBOOSTER GLOW x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CELLBOOSTER GLOW x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CELLBOOSTER LIFT x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CELLBOOSTER LIFT x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESOGLOW x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESOGLOW x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('NANOPLASMA FACIAL x1'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('NANOPLASMA FACIAL x3'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('NANOPLASMA FACIAL ZONA ADICIONAL'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('PINK GLOW ROSTRO 0.5ML'),'BIOREVITALIZACION FACIAL','TEAM_SKILL_V2:EXACT',true),

  -- Nursing facial/apparatus/corporal families.
  (public.aos_booking_norm_v1('PACK APARATOLOGÍA REAFIRMANTE'),'APARATOLOGIA CORPORAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('PACK APARATOLOGÍA REDUCTOR'),'APARATOLOGIA CORPORAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('PACK POSTLIPO/POSTCIRUGÍA'),'APARATOLOGIA CORPORAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CARBOXI PACK 1 (2-4 zonas)'),'CARBOXITERAPIA','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CARBOXI PACK 2 (4-8 zonas)'),'CARBOXITERAPIA','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('CARBOXI PLUS'),'CARBOXITERAPIA','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('HIDROENZIMAS x3 EN 1 VISITA'),'HIDROENZIMAS','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESOTERAPIA CORPORAL 2 AMP x1'),'MESOTERAPIA CORPORAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MESOTERAPIA CORPORAL 4+2 AMP x3'),'MESOTERAPIA CORPORAL','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('DESCONGESTIVO PÁRPADOS'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL CÉLULAS MADRE x1'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL CÉLULAS MADRE x2'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL COREANO'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL DIAMANTE'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL DIAMANTE PREMIUM'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('FACIAL DIAMANTE R+C'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MASCARILLA ESTHEMAX'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('MASCARILLA Q10'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('SKIN PREP'),'FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('ZK 1 SESIÓN'),'PEELINGS','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('ZK x3'),'PEELINGS','TEAM_SKILL_V2:EXACT',true),

  -- Existing doctor enzyme skill is sufficient for these exact items.
  (public.aos_booking_norm_v1('EXO SLIM PAPADA x1'),'ENZIMAS FACIALES','TEAM_SKILL_V2:EXACT',true),
  (public.aos_booking_norm_v1('EXO SLIM PAPADA x3'),'ENZIMAS FACIALES','TEAM_SKILL_V2:EXACT',true)
on conflict(service_name_norm) do update
set capability=excluded.capability,
    evidence_ref=excluded.evidence_ref,
    active=true,
    updated_at=now();

-- Cannulas remain intentionally unmapped: they are active catalog rows but do not represent
-- a standalone bookable professional skill. They must be reviewed separately as catalog/insumo semantics.

-- 3) Exact-code replication: aos_usuarios is the editable Team authority;
-- aos_perfiles_profesional is the booking replica consumed by WA/public scheduling.
create or replace function public.aos_team_sync_professional_services_v2()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
begin
  if coalesce(btrim(new.codigo_asesor),'')<>'' then
    update public.aos_perfiles_profesional p
       set servicios=coalesce(new.servicios,array[]::text[])
     where p.codigo_asesor=new.codigo_asesor;
  end if;
  return new;
end
$$;

drop trigger if exists trg_aos_team_sync_professional_services_v2 on public.aos_usuarios;
create trigger trg_aos_team_sync_professional_services_v2
after insert or update of servicios,codigo_asesor on public.aos_usuarios
for each row execute function public.aos_team_sync_professional_services_v2();

-- Protect the booking replica from the current legacy fuzzy-name PATCH in admin-team.html.
-- If a profile is touched directly, its services are canonicalized back to its exact codigo_asesor user.
create or replace function public.aos_team_guard_profile_services_v2()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_services text[];
begin
  if coalesce(btrim(new.codigo_asesor),'')<>'' then
    select coalesce(u.servicios,array[]::text[])
      into v_services
      from public.aos_usuarios u
     where u.codigo_asesor=new.codigo_asesor
     order by u.activo desc nulls last,u.updated_at desc nulls last
     limit 1;
    if found then new.servicios:=v_services; end if;
  end if;
  return new;
end
$$;

drop trigger if exists trg_aos_team_guard_profile_services_v2 on public.aos_perfiles_profesional;
create trigger trg_aos_team_guard_profile_services_v2
before insert or update of servicios,codigo_asesor on public.aos_perfiles_profesional
for each row execute function public.aos_team_guard_profile_services_v2();

-- 4) Dual-role booking semantics.
-- For AMBOS services, availability can contain doctor exact-provider slots and nursing pool slots.
create or replace function public.aos_booking_availability_v2(
  p_treatment_id uuid,
  p_fecha date,
  p_sede text,
  p_profesional_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_capability text;
  v_site text;
  v_doc_allowed boolean;
  v_nurse_allowed boolean;
  v_do_doc boolean;
  v_do_nurse boolean;
  v_doc_latest date;
  v_nurse_latest date;
  v_slots jsonb := '[]'::jsonb;
  v_providers jsonb := '[]'::jsonb;
  v_np jsonb := '[]'::jsonb;
  v_p record;
  v_h record;
  v_time time;
  v_min_start time;
  v_max_end time;
  v_members int;
  v_capacity int;
  v_occupied int;
  v_names jsonb;
  v_step interval;
  v_role_out text;
  v_mode_out text;
begin
  v_site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if p_fecha is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE');
  end if;

  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE'); end if;

  v_doc_allowed:=coalesce(v_t.requiere_doctora,false);
  v_nurse_allowed:=coalesce(v_t.requiere_enfermeria,false);
  if not v_doc_allowed and not v_nurse_allowed then
    return jsonb_build_object('ok',false,'status','ROLE_UNSPECIFIED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  v_capability:=public.aos_booking_capability_for_service_v1(v_t.id);
  if v_capability is null then
    return jsonb_build_object('ok',false,'status','CAPABILITY_UNMAPPED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  -- A concrete professional id is an explicit doctor choice. Without one, an AMBOS service
  -- exposes both allowed role paths; each slot remains tagged with its own role/mode.
  v_do_doc:=v_doc_allowed;
  v_do_nurse:=v_nurse_allowed and p_profesional_id is null;

  if v_do_doc then
    select max(fecha) into v_doc_latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='DOCTORA';
    if v_doc_latest is null or v_doc_latest<p_fecha then v_do_doc:=false; end if;
  end if;
  if v_do_nurse then
    select max(fecha) into v_nurse_latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='ENFERMERIA';
    if v_nurse_latest is null or v_nurse_latest<p_fecha then v_do_nurse:=false; end if;
  end if;
  if not v_do_doc and not v_do_nurse then
    return jsonb_build_object(
      'ok',false,'status','SCHEDULE_SOURCE_STALE','capability',v_capability,
      'schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest)
    );
  end if;

  if v_do_doc then
    v_step:=interval '30 minutes';
    for v_p in
      select p.*
      from public.aos_perfiles_profesional p
      where coalesce(p.visible,true)=true
        and upper(coalesce(p.tipo,''))='DOCTORA'
        and (p_profesional_id is null or p.id=p_profesional_id)
        and exists (
          select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
          where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
        )
        and exists (
          select 1 from public.aos_horarios_personal h
          where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
            and upper(coalesce(h.rol,''))='DOCTORA'
            and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        )
      order by p.orden nulls last,p.nombre_publico
    loop
      v_providers:=v_providers||jsonb_build_array(jsonb_build_object(
        'id',v_p.id,'name',v_p.nombre_publico,'role','DOCTORA','capability',v_capability
      ));
      for v_h in
        select h.* from public.aos_horarios_personal h
        where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
          and upper(coalesce(h.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
      loop
        v_time:=v_h.hora_inicio::time;
        while v_time+v_step<=v_h.hora_fin::time loop
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.doctora,'')) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<1 then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',1-v_occupied,'capacidad',1,'professional_id',v_p.id,
              'professional_name',v_p.nombre_publico,'role','DOCTORA','mode','EXACT_PROVIDER'
            ));
          end if;
          v_time:=v_time+v_step;
        end loop;
      end loop;
    end loop;
  end if;

  if v_do_nurse then
    v_step:=interval '45 minutes';
    select min(h.hora_inicio::time),max(h.hora_fin::time)
      into v_min_start,v_max_end
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and exists (
        select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
        where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
      );

    select coalesce(jsonb_agg(distinct jsonb_build_object(
      'id',p.id,'name',p.nombre_publico,'role','ENFERMERIA','capability',v_capability
    )),'[]'::jsonb)
      into v_np
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and exists (
        select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
        where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
      );
    v_providers:=v_providers||v_np;

    if v_min_start is not null and v_max_end is not null then
      v_time:=v_min_start;
      while v_time+v_step<=v_max_end loop
        select count(distinct p.id),coalesce(jsonb_agg(distinct p.nombre_publico),'[]'::jsonb)
          into v_members,v_names
        from public.aos_perfiles_profesional p
        join public.aos_horarios_personal h
          on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
         and upper(coalesce(h.rol,''))='ENFERMERIA'
         and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
          and exists (
            select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
            where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
          )
          and v_time>=h.hora_inicio::time
          and v_time+v_step<=h.hora_fin::time;
        if coalesce(v_members,0)>0 then
          v_capacity:=v_members*2;
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<v_capacity then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',v_capacity-v_occupied,'capacidad',v_capacity,
              'member_count',v_members,'member_names',v_names,
              'professional_id',null,'professional_name','Enfermería',
              'role','ENFERMERIA','mode','SITE_POOL'
            ));
          end if;
        end if;
        v_time:=v_time+v_step;
      end loop;
    end if;
  end if;

  if v_doc_allowed and v_nurse_allowed and p_profesional_id is null then
    v_role_out:='MULTI_ROLE';v_mode_out:='MULTI_ROLE';
  elsif v_do_doc then
    v_role_out:='DOCTORA';v_mode_out:='EXACT_PROVIDER';
  else
    v_role_out:='ENFERMERIA';v_mode_out:='SITE_POOL';
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',case when jsonb_array_length(v_slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',v_t.id,'treatment',v_t.nombre,'capability',v_capability,
    'role',v_role_out,'mode',v_mode_out,
    'eligible_roles',jsonb_build_array(case when v_doc_allowed then 'DOCTORA' else null end,case when v_nurse_allowed then 'ENFERMERIA' else null end)-'null',
    'fecha',p_fecha,'sede',v_site,
    'schedule_source_max_date',greatest(v_doc_latest,v_nurse_latest),
    'schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest),
    'eligible_professionals',v_providers,'slots',v_slots
  );
end
$$;

revoke all on function public.aos_booking_availability_v2(uuid,date,text,text) from public;
grant execute on function public.aos_booking_availability_v2(uuid,date,text,text) to anon,authenticated,service_role;

-- 5) WhatsApp HUMAN_ONLY commit: for an AMBOS service the selected slot decides the role.
-- professional_id present => exact doctor; professional_id absent => nursing site pool.
create or replace function public.aos_wa4_commit_booking_v1(
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
    if v_existing.request_hash<>v_hash then return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDEMPOTENCY_MISMATCH'); end if;
    return jsonb_build_object('ok',true,'status',v_existing.status,'agenda_id',v_existing.agenda_id,'idempotent_replay',true,'confirmation_allowed',true);
  end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from p_actor_id then return jsonb_build_object('ok',false,'error','WA4_BOOKING_NOT_CONVERSATION_OWNER'); end if;
  if upper(coalesce(v_conv.state,'')) not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CONVERSATION_STATE_BLOCKED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=p_actor_id and a.state='ACTIVE') then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;
  if coalesce(regexp_replace(v_conv.contact_number,'[^0-9]','','g'),'')='' then return jsonb_build_object('ok',false,'error','WA4_BOOKING_TRUSTED_PHONE_REQUIRED'); end if;

  v_identity:=coalesce(public.aos_rev_resolve_patient_identity_v2('PHONE',v_conv.contact_number),'{}'::jsonb);
  v_identity_status:=upper(coalesce(v_identity->>'status','UNRESOLVED'));
  if v_identity_status='IDENTITY_CONFLICT' then return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDENTITY_CONFLICT','requires_human',true); end if;
  if v_identity_status not in ('MATCH','UNRESOLVED') then return jsonb_build_object('ok',false,'error','WA4_BOOKING_IDENTITY_NOT_READY','identity_state',v_identity_status,'requires_human',true); end if;
  if v_identity_status='MATCH' then
    v_canonical:=nullif(btrim(v_identity->>'canonical_patient_id'),'');
    if v_canonical is null then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CANONICAL_ID_MISSING','requires_human',true); end if;
    select * into v_patient from public.aos_pacientes where "ID_PACIENTE"::text=v_canonical limit 1;
    if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_CANONICAL_TARGET_MISSING','requires_human',true); end if;
  end if;

  begin
    select * into v_treatment from public.aos_catalogo_servicios
    where id=(p_payload->>'treatment_id')::uuid
      and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
      and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  exception when others then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_ID_INVALID');
  end;
  if not found then return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_NOT_ACTIVE'); end if;

  v_professional_id:=nullif(btrim(p_payload->>'professional_id'),'');
  if coalesce(v_treatment.requiere_doctora,false) and coalesce(v_treatment.requiere_enfermeria,false) then
    if v_professional_id is not null then v_role:='DOCTORA';v_booking_mode:='EXACT_PROVIDER';
    else v_role:='ENFERMERIA';v_booking_mode:='SITE_POOL'; end if;
  elsif coalesce(v_treatment.requiere_doctora,false) then
    v_role:='DOCTORA';v_booking_mode:='EXACT_PROVIDER';
  elsif coalesce(v_treatment.requiere_enfermeria,false) then
    v_role:='ENFERMERIA';v_booking_mode:='SITE_POOL';
  else
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_TREATMENT_ROLE_NOT_GOVERNED','requires_human',true);
  end if;

  v_site:=upper(replace(btrim(coalesce(p_payload->>'site','')),'_',' '));
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','WA4_BOOKING_SITE_INVALID'); end if;
  begin v_date:=(p_payload->>'date')::date;v_time:=(p_payload->>'time')::time;
  exception when others then return jsonb_build_object('ok',false,'error','WA4_BOOKING_DATE_TIME_INVALID'); end;
  if v_date<current_date then return jsonb_build_object('ok',false,'error','WA4_BOOKING_DATE_IN_PAST'); end if;
  if extract(isodow from v_date)=7 then return jsonb_build_object('ok',false,'error','WA4_BOOKING_SUNDAY_CLOSED'); end if;
  v_time_text:=to_char(v_time,'HH24:MI');

  if v_role='DOCTORA' and v_professional_id is null then return jsonb_build_object('ok',false,'error','WA4_BOOKING_EXACT_PROVIDER_REQUIRED'); end if;
  if v_role='ENFERMERIA' then v_professional_id:=null; end if;

  v_availability:=coalesce(public.aos_booking_availability_v2(v_treatment.id,v_date,v_site,v_professional_id),'{}'::jsonb);
  if coalesce((v_availability->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','WA4_BOOKING_AUTHORITY_BLOCKED','authority_status',coalesce(v_availability->>'status','UNKNOWN'),'requires_human',true);
  end if;
  select exists(
    select 1 from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text
      and upper(coalesce(s->>'role',''))=v_role
      and coalesce((s->>'disponible')::boolean,false)=true
      and (v_role='ENFERMERIA' or s->>'professional_id'=v_professional_id)
  ) into v_slot_ok;
  if not v_slot_ok then return jsonb_build_object('ok',false,'error','WA4_BOOKING_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true); end if;

  if v_role='DOCTORA' then
    select s->>'professional_name' into v_prof_name
    from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text and upper(coalesce(s->>'role',''))='DOCTORA' and s->>'professional_id'=v_professional_id
    limit 1;
    if coalesce(btrim(v_prof_name),'')='' then return jsonb_build_object('ok',false,'error','WA4_BOOKING_PROFESSIONAL_NOT_AVAILABLE'); end if;
  else
    v_professional_id:='POOL:'||replace(v_site,' ','_');v_prof_name:='ENFERMERIA';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('wa4-slot:'||v_professional_id||':'||v_date::text||':'||v_time_text||':'||v_site,0));
  v_availability:=coalesce(public.aos_booking_availability_v2(v_treatment.id,v_date,v_site,case when v_role='DOCTORA' then v_professional_id else null end),'{}'::jsonb);
  select exists(
    select 1 from jsonb_array_elements(coalesce(v_availability->'slots','[]'::jsonb)) s
    where s->>'hora'=v_time_text
      and upper(coalesce(s->>'role',''))=v_role
      and coalesce((s->>'disponible')::boolean,false)=true
      and (v_role='ENFERMERIA' or s->>'professional_id'=v_professional_id)
  ) into v_slot_ok;
  if not v_slot_ok then return jsonb_build_object('ok',false,'error','WA4_BOOKING_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true); end if;

  v_name:=nullif(btrim(p_payload->>'name'),'');v_last:=nullif(btrim(p_payload->>'last_name'),'');
  v_dni:=nullif(btrim(p_payload->>'dni'),'');v_email:=nullif(btrim(p_payload->>'email'),'');
  if v_identity_status='MATCH' then
    v_name:=coalesce(v_name,nullif(btrim(v_patient."Nombres"),''));
    v_last:=coalesce(v_last,nullif(btrim(v_patient."Apellidos"),''));
    v_dni:=coalesce(v_dni,nullif(btrim(v_patient."N° documento"),''));
    v_email:=coalesce(v_email,nullif(btrim(v_patient."Email"),''));
  end if;
  v_name:=coalesce(v_name,nullif(btrim(v_conv.contact_name),''));
  if v_name is null then return jsonb_build_object('ok',false,'error','WA4_BOOKING_NAME_REQUIRED'); end if;

  v_appointment_type:=upper(btrim(coalesce(p_payload->>'appointment_type','CONSULTA NUEVA')));
  if v_appointment_type not in ('CONSULTA NUEVA','APLICACION','CONTROL') then return jsonb_build_object('ok',false,'error','WA4_BOOKING_APPOINTMENT_TYPE_INVALID'); end if;
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
    'confirmation_allowed',true,'identity_state',v_identity_status,'site',v_site,'date',v_date,'time',v_time_text,
    'professional_role',v_role,'booking_mode',v_booking_mode,
    'professional_id',case when v_role='DOCTORA' then v_professional_id else null end,
    'professional_name',case when v_role='DOCTORA' then v_prof_name else 'Enfermería' end,'source',v_source
  );
end
$$;

revoke all on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) to service_role;

comment on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) is
'WA-4C HUMAN_ONLY booking commit. AMBOS means either eligible doctor exact-provider or eligible nursing site-pool; selected slot determines role. Explicit search_path includes extensions for pgcrypto. No autonomous WhatsApp send.';

-- 6) Audit surface for certification and future drift checks.
create or replace function public.aos_team_skill_alignment_audit_v2()
returns jsonb
language sql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
with services as (
  select s.id,s.nombre,s.categoria,s.requiere_doctora,s.requiere_enfermeria,
         public.aos_booking_capability_for_service_v1(s.id) capability
  from public.aos_catalogo_servicios s
  where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO' and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
), profiles as (
  select p.codigo_asesor,p.nombre_publico,p.tipo,p.servicios,
         u.servicios user_servicios
  from public.aos_perfiles_profesional p
  left join public.aos_usuarios u on u.codigo_asesor=p.codigo_asesor and u.activo is distinct from false
  where coalesce(p.visible,true)=true
)
select jsonb_build_object(
  'active_services',(select count(*) from services),
  'mapped_services',(select count(*) from services where capability is not null),
  'unmapped_services',(select count(*) from services where capability is null),
  'dual_role_services',(select count(*) from services where requiere_doctora and requiere_enfermeria),
  'active_skills',(select count(*) from public.aos_cat_tratamientos where upper(coalesce(estado,'ACTIVO'))='ACTIVO'),
  'visible_profiles',(select count(*) from profiles),
  'profile_user_service_drift',(select count(*) from profiles where user_servicios is distinct from servicios),
  'unmapped_names',coalesce((select jsonb_agg(nombre order by nombre) from services where capability is null),'[]'::jsonb)
);
$$;

revoke all on function public.aos_team_skill_alignment_audit_v2() from public,anon;
grant execute on function public.aos_team_skill_alignment_audit_v2() to authenticated,service_role;

commit;
