-- ASCENDA OS · AGV2 L2 — Slot Authority V2
-- Business authority: 30-minute reservation grid, soft capacity 5, overflow 6.
-- Clinical duration controls valid start-time fit, but does NOT consume/block later reservation slots.
-- Existing V1/public availability remains untouched; AGV2 V2 selected-slot authority is rewired here.
begin;

create table if not exists public.aos_booking_timing_authority_v2 (
  capability text not null,
  procedure_key text not null default '*',
  execution_min_min integer not null check (execution_min_min > 0),
  execution_max_min integer not null check (execution_max_min >= execution_min_min),
  execution_default_min integer not null check (execution_default_min between execution_min_min and execution_max_min),
  prep_default_min integer not null default 0 check (prep_default_min >= 0),
  reservation_grid_min integer not null default 30 check (reservation_grid_min = 30),
  soft_capacity integer not null default 5 check (soft_capacity >= 1),
  overflow_capacity integer not null default 6 check (overflow_capacity >= soft_capacity),
  autonomous_overflow_enabled boolean not null default false,
  duration_blocks_future_booking boolean not null default false,
  hard_resource_constraint boolean not null default false,
  resource_key text null,
  active boolean not null default true,
  evidence_ref text not null default 'BUSINESS_REVALIDATION_2026-09-01',
  updated_at timestamptz not null default now(),
  primary key(capability,procedure_key),
  check (hard_resource_constraint is false or resource_key is not null)
);

revoke all on table public.aos_booking_timing_authority_v2 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_booking_timing_authority_v2 to service_role;

-- Capability defaults. Procedure overrides below win over '*'.
insert into public.aos_booking_timing_authority_v2
(capability,procedure_key,execution_min_min,execution_max_min,execution_default_min,prep_default_min)
values
('CONSULTA MEDICA','*',20,30,30,0),
('TOXINA','*',15,30,30,0),
('ACIDO HIALURONICO','*',60,60,60,0),
('BIOESTIMULADOR','*',60,60,60,0),
('HIFU','*',45,60,60,0),
('HIDROFACIAL','*',60,60,60,0),
('CRIOLIPOLISIS','*',90,90,90,0),
('ENZIMAS CORPORALES','*',45,45,45,0),
('ENZIMAS FACIALES','*',45,45,45,0),
('GLUTEOS','*',90,90,90,0),
('PRP CAPILAR','*',45,60,60,0),
('CAPILAR','*',30,60,60,0),
('MESOTERAPIA CAPILAR','*',30,60,60,0),
('RADIOFRECUENCIA FRACCIONADA','*',45,60,60,0),
('CARBOXITERAPIA','*',45,60,60,0),
('DETOX','*',25,40,40,0),
('EXOSOMAS','*',60,60,60,0),
('EXOSOMAS CAPILARES','*',60,60,60,0),
('HIDROENZIMAS','*',45,45,45,0),
('MESOTERAPIA CORPORAL','*',45,45,45,0),
('MESOTERAPIA FACIAL','*',60,60,60,0),
('MICRONEEDLING FACIAL','*',60,60,60,0),
('NANO GLOW','*',45,60,60,0),
('PEELINGS','*',30,30,30,0),
('PEPTONAS','*',30,45,45,0),
('PINK INTIMATE','*',45,60,60,0),
('PQ AGE','*',30,45,45,0),
('VITAMINAS','*',45,60,60,0),
('BIOREVITALIZACION FACIAL','*',45,60,60,0),
('FACIALES','*',20,60,60,0)
on conflict(capability,procedure_key) do update set
 execution_min_min=excluded.execution_min_min,
 execution_max_min=excluded.execution_max_min,
 execution_default_min=excluded.execution_default_min,
 prep_default_min=excluded.prep_default_min,
 reservation_grid_min=30,
 soft_capacity=5,
 overflow_capacity=6,
 autonomous_overflow_enabled=false,
 duration_blocks_future_booking=false,
 active=true,
 evidence_ref='BUSINESS_REVALIDATION_2026-09-01',
 updated_at=now();

-- Explicit procedure timings supplied by clinic operations.
insert into public.aos_booking_timing_authority_v2
(capability,procedure_key,execution_min_min,execution_max_min,execution_default_min,prep_default_min)
values
('BIOREVITALIZACION FACIAL','ACIDO SUCCINICO AMBER',30,30,30,0),
('BIOREVITALIZACION FACIAL','ACIDO TRANEXAMICO',30,30,30,0),
('BIOREVITALIZACION FACIAL','CELLBOOSTER GLOW',30,30,30,0),
('BIOREVITALIZACION FACIAL','CELLBOOSTER LIFT',30,30,30,0),
('BIOREVITALIZACION FACIAL','MESOGLOW',45,60,60,0),
('BIOREVITALIZACION FACIAL','NANOPLASMA FACIAL',45,60,60,0),
('BIOREVITALIZACION FACIAL','PINK GLOW ROSTRO',45,60,60,0),
('FACIALES','FACIAL CELULAS MADRE',20,30,30,0),
('FACIALES','FACIAL COREANO',90,120,120,0),
('FACIALES','FACIAL DIAMANTE',60,60,60,0),
('FACIALES','HIDROVITAL PASCOE',60,60,60,0),
('FACIALES','MASCARILLA ESTHEMAX',15,20,20,0),
('FACIALES','MASCARILLA Q10',15,20,20,0),
('FACIALES','SKIN PREP',15,20,20,0),
('BIOESTIMULADOR','POWERFILL GLUTEOS',90,90,90,0),
('GLUTEOS','AH SKINFILL GLUTEOS',90,90,90,0)
on conflict(capability,procedure_key) do update set
 execution_min_min=excluded.execution_min_min,
 execution_max_min=excluded.execution_max_min,
 execution_default_min=excluded.execution_default_min,
 prep_default_min=excluded.prep_default_min,
 reservation_grid_min=30,
 soft_capacity=5,
 overflow_capacity=6,
 autonomous_overflow_enabled=false,
 duration_blocks_future_booking=false,
 active=true,
 evidence_ref='BUSINESS_REVALIDATION_2026-09-01',
 updated_at=now();

create or replace function public.aos_booking_timing_for_service_v2(p_treatment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_proc jsonb;
  v_row public.aos_booking_timing_authority_v2%rowtype;
begin
  v_proc:=public.aos_booking_procedure_for_service_v1(p_treatment_id);
  if v_proc is null then
    return jsonb_build_object('ok',false,'status','PROCEDURE_UNMAPPED','requires_human',true);
  end if;

  select * into v_row
  from public.aos_booking_timing_authority_v2 t
  where t.active=true
    and public.aos_booking_norm_v1(t.capability)=public.aos_booking_norm_v1(v_proc->>'capability')
    and t.procedure_key in (v_proc->>'procedure_key','*')
  order by case when t.procedure_key=v_proc->>'procedure_key' then 0 else 1 end
  limit 1;

  if not found then
    return jsonb_build_object(
      'ok',false,'status','TIMING_AUTHORITY_MISSING','requires_human',true,
      'capability',v_proc->>'capability','procedure_key',v_proc->>'procedure_key','procedure_name',v_proc->>'procedure_name'
    );
  end if;

  if v_row.hard_resource_constraint and v_row.resource_key is not null then
    return jsonb_build_object(
      'ok',false,'status','HARD_RESOURCE_AUTHORITY_NOT_WIRED','requires_human',true,
      'resource_key',v_row.resource_key,'capability',v_proc->>'capability','procedure_key',v_proc->>'procedure_key'
    );
  end if;

  return jsonb_build_object(
    'ok',true,'status','TIMING_READY',
    'capability',v_proc->>'capability','procedure_key',v_proc->>'procedure_key','procedure_name',v_proc->>'procedure_name',
    'execution_min_min',v_row.execution_min_min,'execution_max_min',v_row.execution_max_min,'execution_default_min',v_row.execution_default_min,
    'prep_default_min',v_row.prep_default_min,'reservation_grid_min',v_row.reservation_grid_min,
    'soft_capacity',v_row.soft_capacity,'overflow_capacity',v_row.overflow_capacity,
    'autonomous_overflow_enabled',v_row.autonomous_overflow_enabled,
    'duration_blocks_future_booking',v_row.duration_blocks_future_booking,
    'hard_resource_constraint',v_row.hard_resource_constraint,'resource_key',v_row.resource_key,
    'evidence_ref',v_row.evidence_ref
  );
end
$$;

-- Dormant AGV2 slot resolver with the real 30-minute commercial grid and 5/6 capacity model.
create or replace function public.aos_booking_slot_authority_v2(
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
  v_timing jsonb;
  v_proc jsonb;
  v_site text;
  v_doc_allowed boolean;
  v_nurse_allowed boolean;
  v_doc_latest date;
  v_nurse_latest date;
  v_exec int;
  v_soft int;
  v_over int;
  v_step interval:=interval '30 minutes';
  v_slots jsonb:='[]'::jsonb;
  v_providers jsonb:='[]'::jsonb;
  v_p record;
  v_h record;
  v_time time;
  v_min_start time;
  v_max_end time;
  v_members int;
  v_names jsonb;
  v_occupied int;
begin
  v_site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if p_fecha is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE');
  end if;
  if p_fecha<current_date or extract(isodow from p_fecha)=7 then
    return jsonb_build_object('ok',false,'status',case when p_fecha<current_date then 'DATE_IN_PAST' else 'SUNDAY_CLOSED' end);
  end if;

  select * into v_t from public.aos_catalogo_servicios
  where id=p_treatment_id and upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE'); end if;

  v_timing:=public.aos_booking_timing_for_service_v2(v_t.id);
  if coalesce((v_timing->>'ok')::boolean,false) is not true then return v_timing; end if;
  v_proc:=public.aos_booking_procedure_for_service_v1(v_t.id);
  v_exec:=(v_timing->>'execution_default_min')::int;
  v_soft:=(v_timing->>'soft_capacity')::int;
  v_over:=(v_timing->>'overflow_capacity')::int;
  v_doc_allowed:=coalesce(v_t.requiere_doctora,false);
  v_nurse_allowed:=coalesce(v_t.requiere_enfermeria,false);

  if v_doc_allowed then select max(fecha) into v_doc_latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='DOCTORA'; end if;
  if v_nurse_allowed then select max(fecha) into v_nurse_latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='ENFERMERIA'; end if;
  if (v_doc_allowed and (v_doc_latest is null or v_doc_latest<p_fecha)) and (not v_nurse_allowed or p_profesional_id is not null) then
    return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE','requires_human',true,'role','DOCTORA');
  end if;
  if v_nurse_allowed and p_profesional_id is null and (v_nurse_latest is null or v_nurse_latest<p_fecha) and not v_doc_allowed then
    return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE','requires_human',true,'role','ENFERMERIA');
  end if;

  if v_doc_allowed and v_doc_latest>=p_fecha then
    for v_p in
      select p.* from public.aos_perfiles_profesional p
      where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='DOCTORA'
        and (p_profesional_id is null or p.id::text=p_profesional_id)
        and public.aos_professional_can_service_v1(p.id::text,v_t.id)
        and exists(select 1 from public.aos_horarios_personal h where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site and upper(coalesce(h.rol,''))='DOCTORA' and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%')
      order by p.orden nulls last,p.nombre_publico
    loop
      v_providers:=v_providers||jsonb_build_array(jsonb_build_object('id',v_p.id,'name',v_p.nombre_publico,'role','DOCTORA'));
      for v_h in
        select h.* from public.aos_horarios_personal h
        where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site and upper(coalesce(h.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
      loop
        v_time:=v_h.hora_inicio::time;
        while v_time + make_interval(mins=>v_exec) <= v_h.hora_fin::time loop
          select count(*) into v_occupied from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.tipo_atencion,''))='DOCTORA'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<v_soft then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'ocupadas',v_occupied,'libres',v_soft-v_occupied,'capacidad',v_soft,'overflow_capacity',v_over,'overflow_available',v_occupied<v_over,
              'professional_id',v_p.id,'professional_name',v_p.nombre_publico,'role','DOCTORA','mode','EXACT_PROVIDER',
              'execution_default_min',v_exec,'duration_blocks_future_booking',false,
              'procedure_key',v_proc->>'procedure_key','procedure_name',v_proc->>'procedure_name'
            ));
          end if;
          v_time:=v_time+v_step;
        end loop;
      end loop;
    end loop;
  end if;

  if v_nurse_allowed and p_profesional_id is null and v_nurse_latest>=p_fecha then
    select min(h.hora_inicio::time),max(h.hora_fin::time) into v_min_start,v_max_end
    from public.aos_perfiles_profesional p join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA' and public.aos_professional_can_service_v1(p.id::text,v_t.id);

    if v_min_start is not null and v_max_end is not null then
      v_time:=v_min_start;
      while v_time+make_interval(mins=>v_exec)<=v_max_end loop
        select count(distinct p.id),coalesce(jsonb_agg(distinct p.nombre_publico),'[]'::jsonb) into v_members,v_names
        from public.aos_perfiles_profesional p join public.aos_horarios_personal h
          on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site and upper(coalesce(h.rol,''))='ENFERMERIA'
         and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
          and public.aos_professional_can_service_v1(p.id::text,v_t.id)
          and v_time>=h.hora_inicio::time and v_time+make_interval(mins=>v_exec)<=h.hora_fin::time;
        if coalesce(v_members,0)>0 then
          select count(*) into v_occupied from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<v_soft then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'ocupadas',v_occupied,'libres',v_soft-v_occupied,'capacidad',v_soft,'overflow_capacity',v_over,'overflow_available',v_occupied<v_over,
              'member_count',v_members,'member_names',v_names,'professional_id',null,'professional_name','Enfermería','role','ENFERMERIA','mode','SITE_POOL',
              'execution_default_min',v_exec,'duration_blocks_future_booking',false,
              'procedure_key',v_proc->>'procedure_key','procedure_name',v_proc->>'procedure_name'
            ));
          end if;
        end if;
        v_time:=v_time+v_step;
      end loop;
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'status',case when jsonb_array_length(v_slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',v_t.id,'treatment',v_t.nombre,'capability',v_proc->>'capability','procedure',v_proc,'timing',v_timing,
    'fecha',p_fecha,'sede',v_site,'eligible_professionals',v_providers,'slots',v_slots
  );
end
$$;

-- V2 BOOK/REBOOK uses L2 authority; V1/public surfaces remain unchanged until their own rollout gate.
create or replace function public.aos_booking_resolve_selected_slot_v2(
  p_treatment_id uuid,p_date date,p_site text,p_time time,p_professional_id text default null,p_slot_role text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_av jsonb; v_slot jsonb; v_role text:=upper(btrim(coalesce(p_slot_role,''))); v_prof text:=nullif(btrim(coalesce(p_professional_id,'')),'');
begin
  v_av:=coalesce(public.aos_booking_slot_authority_v2(p_treatment_id,p_date,p_site,v_prof),'{}'::jsonb);
  if coalesce((v_av->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','AGV2_AUTHORITY_BLOCKED','authority_status',coalesce(v_av->>'status','UNKNOWN'),'requires_human',true,'authority',v_av);
  end if;
  if v_role='' then
    if v_prof is not null then v_role:='DOCTORA'; else v_role:='ENFERMERIA'; end if;
  end if;
  if v_role not in ('DOCTORA','ENFERMERIA') then return jsonb_build_object('ok',false,'error','AGV2_SLOT_ROLE_REQUIRED'); end if;
  if v_role='DOCTORA' and v_prof is null then return jsonb_build_object('ok',false,'error','AGV2_EXACT_PROVIDER_REQUIRED'); end if;
  if v_role='ENFERMERIA' then v_prof:=null; end if;

  select s into v_slot from jsonb_array_elements(coalesce(v_av->'slots','[]'::jsonb)) s
  where s->>'hora'=to_char(p_time,'HH24:MI') and upper(coalesce(s->>'role',''))=v_role
    and coalesce((s->>'disponible')::boolean,false)=true
    and (v_role='ENFERMERIA' or s->>'professional_id'=v_prof)
  limit 1;
  if v_slot is null then return jsonb_build_object('ok',false,'error','AGV2_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true); end if;

  return jsonb_build_object(
    'ok',true,'role',v_role,'booking_mode',case when v_role='DOCTORA' then 'EXACT_PROVIDER' else 'SITE_POOL' end,
    'professional_id',case when v_role='DOCTORA' then v_prof else null end,
    'professional_ref',case when v_role='DOCTORA' then v_prof else 'POOL:'||replace(upper(replace(btrim(p_site),'_',' ')),' ','_') end,
    'professional_name',case when v_role='DOCTORA' then v_slot->>'professional_name' else 'Enfermería' end,
    'site',upper(replace(btrim(p_site),'_',' ')),'date',p_date,'time',to_char(p_time,'HH24:MI'),
    'capacity',(v_slot->>'capacidad')::int,'overflow_capacity',(v_slot->>'overflow_capacity')::int,
    'execution_default_min',(v_slot->>'execution_default_min')::int,'authority_status',v_av->>'status'
  );
end
$$;

revoke all on function public.aos_booking_timing_for_service_v2(uuid) from public,anon,authenticated;
revoke all on function public.aos_booking_slot_authority_v2(uuid,date,text,text) from public,anon,authenticated;
revoke all on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) from public,anon,authenticated;
grant execute on function public.aos_booking_timing_for_service_v2(uuid) to service_role;
grant execute on function public.aos_booking_slot_authority_v2(uuid,date,text,text) to service_role;
grant execute on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) to service_role;

comment on table public.aos_booking_timing_authority_v2 is 'AGV2 L2 clinical execution timing and 30-minute commercial capacity authority. Duration does not consume later slots.';
comment on function public.aos_booking_slot_authority_v2(uuid,date,text,text) is 'Dormant AGV2 slot authority: 30-min grid, soft 5/overflow 6, clinical duration only validates start-time fit.';

commit;