-- Rollback WA-4C Professional Skill Hierarchy V1
-- Restores parent-skill-only availability from Team Skill Authority V2.
begin;

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

drop function if exists public.aos_team_skill_hierarchy_audit_v1();
drop function if exists public.aos_team_save_skill_hierarchy_v1(uuid,text[],jsonb,text);
drop function if exists public.aos_team_skill_hierarchy_v1(text);
drop function if exists public.aos_professional_can_service_v1(text,uuid);
drop function if exists public.aos_booking_procedure_for_service_v1(uuid);
drop function if exists public.aos_booking_procedure_name_v1(text,text);

drop table if exists public.aos_team_skill_audit_v1;
drop table if exists public.aos_professional_procedure_scope_v1;
drop table if exists public.aos_booking_procedure_map_v1;

commit;
