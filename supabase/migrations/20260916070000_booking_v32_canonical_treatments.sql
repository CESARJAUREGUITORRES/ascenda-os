-- BOOKING-V3.2 — expose the same canonical treatment taxonomy used by Agenda/Call Center
-- while preserving the public V2 RPC signatures consumed by agendar-v2.html.
begin;

create or replace function public.aos_booking_treatment_ref_v32(p_treatment_id uuid)
returns table(tratamiento text,categoria text,role text,mode text)
language sql stable security definer set search_path='public','pg_temp' as $$
  select c.tratamiento,c.categoria,r.role,
         case when r.role='DOCTORA' then 'EXACT_PROVIDER' else 'SITE_POOL' end
  from public.aos_cat_tratamientos c
  cross join lateral (values ('DOCTORA',coalesce(c.requiere_doctora,false)),('ENFERMERIA',coalesce(c.requiere_enfermeria,false))) r(role,allowed)
  where c.estado='ACTIVO' and r.allowed
    and md5('BOOKING-V32|'||upper(trim(c.tratamiento))||'|'||r.role)::uuid=p_treatment_id
  limit 1;
$$;
revoke all on function public.aos_booking_treatment_ref_v32(uuid) from public;
grant execute on function public.aos_booking_treatment_ref_v32(uuid) to anon,authenticated,service_role;

create or replace function public.aos_booking_public_catalog_v2()
returns jsonb language sql stable security definer set search_path='public','pg_temp' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',md5('BOOKING-V32|'||upper(trim(c.tratamiento))||'|'||r.role)::uuid,
   'nombre',c.tratamiento,'categoria',coalesce(c.categoria,'GENERAL'),
   'capability',c.tratamiento,'role',r.role,
   'mode',case when r.role='DOCTORA' then 'EXACT_PROVIDER' else 'SITE_POOL' end
 ) order by c.orden nulls last,c.tratamiento,r.role),'[]'::jsonb)
 from public.aos_cat_tratamientos c
 cross join lateral (values ('DOCTORA',coalesce(c.requiere_doctora,false)),('ENFERMERIA',coalesce(c.requiere_enfermeria,false))) r(role,allowed)
 where c.estado='ACTIVO' and r.allowed;
$$;
revoke all on function public.aos_booking_public_catalog_v2() from public;
grant execute on function public.aos_booking_public_catalog_v2() to anon,authenticated,service_role;

create or replace function public.aos_booking_availability_v2(p_treatment_id uuid,p_fecha date,p_sede text,p_profesional_id text default null)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare t record; site text; latest date; slots jsonb:='[]'::jsonb; providers jsonb:='[]'::jsonb; p record; h record; tm time; step interval; occupied int; members int; names jsonb; min_start time; max_end time;
begin
 select * into t from public.aos_booking_treatment_ref_v32(p_treatment_id); if not found then return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE'); end if;
 site:=upper(replace(trim(coalesce(p_sede,'')),'_',' ')); if p_fecha is null or site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE'); end if;
 if t.role='DOCTORA' then
   if nullif(trim(p_profesional_id),'') is null then return jsonb_build_object('ok',false,'status','EXACT_PROVIDER_REQUIRED'); end if;
   select max(fecha) into latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='DOCTORA';
   if latest is null or latest<p_fecha then return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE'); end if;
   step:=interval '30 minutes';
   for p in select * from public.aos_perfiles_profesional where coalesce(visible,true)=true and upper(coalesce(tipo,''))='DOCTORA' and id::text=p_profesional_id loop
    for h in select * from public.aos_horarios_personal where activo=true and fecha=p_fecha and upper(sede)=site and upper(coalesce(rol,''))='DOCTORA' and public.aos_booking_norm_v1(personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%' loop
     tm:=h.hora_inicio::time; while tm+step<=h.hora_fin::time loop
      select count(*) into occupied from public.aos_agenda_citas a where a.fecha_cita=p_fecha and upper(coalesce(a.sede,''))=site and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(tm,'HH24:MI') and upper(coalesce(a.doctora,'')) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%' and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
      if occupied<1 then slots:=slots||jsonb_build_array(jsonb_build_object('hora',to_char(tm,'HH24:MI'),'sede',site,'disponible',true,'libres',1-occupied,'capacidad',1,'professional_id',p.id,'professional_name',p.nombre_publico,'role','DOCTORA','mode','EXACT_PROVIDER')); end if;
      tm:=tm+step;
     end loop;
    end loop;
    providers:=providers||jsonb_build_array(jsonb_build_object('id',p.id,'name',p.nombre_publico,'role','DOCTORA'));
   end loop;
 else
   select max(fecha) into latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='ENFERMERIA';
   if latest is null or latest<p_fecha then return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE'); end if;
   step:=interval '45 minutes';
   select min(h.hora_inicio::time),max(h.hora_fin::time) into min_start,max_end from public.aos_horarios_personal h where h.activo=true and h.fecha=p_fecha and upper(h.sede)=site and upper(coalesce(h.rol,''))='ENFERMERIA';
   tm:=min_start; while tm is not null and max_end is not null and tm+step<=max_end loop
    select count(*),coalesce(jsonb_agg(personal),'[]'::jsonb) into members,names from public.aos_horarios_personal h where h.activo=true and h.fecha=p_fecha and upper(h.sede)=site and upper(coalesce(h.rol,''))='ENFERMERIA' and tm>=h.hora_inicio::time and tm+step<=h.hora_fin::time;
    if members>0 then
     select count(*) into occupied from public.aos_agenda_citas a where a.fecha_cita=p_fecha and upper(coalesce(a.sede,''))=site and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(tm,'HH24:MI') and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA' and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
     if occupied<members*2 then slots:=slots||jsonb_build_array(jsonb_build_object('hora',to_char(tm,'HH24:MI'),'sede',site,'disponible',true,'libres',members*2-occupied,'capacidad',members*2,'member_names',names,'professional_id',null,'professional_name','Enfermería','role','ENFERMERIA','mode','SITE_POOL')); end if;
    end if; tm:=tm+step;
   end loop;
 end if;
 return jsonb_build_object('ok',true,'status',case when jsonb_array_length(slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,'treatment_id',p_treatment_id,'treatment',t.tratamiento,'role',t.role,'mode',t.mode,'fecha',p_fecha,'sede',site,'schedule_source_max_date',latest,'eligible_professionals',providers,'slots',slots);
end $$;
revoke all on function public.aos_booking_availability_v2(uuid,date,text,text) from public;
grant execute on function public.aos_booking_availability_v2(uuid,date,text,text) to anon,authenticated,service_role;

create or replace function public.aos_agendar_publica_v2(
 p_token text,p_nombre text,p_apellido text,p_telefono text,p_treatment_id uuid,p_fecha date,p_hora text,p_sede text,
 p_profesional_id text default null,p_dni text default '',p_email text default '',p_nota text default '',p_tipo_cita text default 'CONSULTA NUEVA')
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare l record; t record; num text; paciente record; advisor text; site text; avail jsonb; slot jsonb; prof_name text; idv text; attr jsonb; ch text; camp text;
begin
 select * into t from public.aos_booking_treatment_ref_v32(p_treatment_id); if not found then return jsonb_build_object('ok',false,'error','TREATMENT_NOT_ACTIVE'); end if;
 if coalesce(trim(p_token),'') in ('','__permanent__') then advisor:='ORGANICO'; else select * into l from public.aos_links_agenda where token=p_token and expira_at>now(); if not found then return jsonb_build_object('ok',false,'error','LINK_INVALID_OR_EXPIRED'); end if; advisor:=coalesce(nullif(trim(l.asesor_codigo),''),'ORGANICO'); end if;
 attr:=public.aos_booking_attribution_v1(p_token); ch:=coalesce(attr->>'source_channel','WEB'); camp:=nullif(attr->>'source_campaign','');
 site:=upper(replace(trim(coalesce(p_sede,'')),'_',' ')); if site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','SITE_INVALID'); end if;
 if p_fecha<current_date or extract(isodow from p_fecha)=7 then return jsonb_build_object('ok',false,'error','DATE_INVALID'); end if;
 if t.role='DOCTORA' and nullif(trim(p_profesional_id),'') is null then return jsonb_build_object('ok',false,'error','EXACT_PROVIDER_REQUIRED'); end if;
 perform pg_advisory_xact_lock(hashtextextended('public-booking-v32:'||t.role||':'||site||':'||p_fecha::text||':'||p_hora,0));
 avail:=coalesce(public.aos_booking_availability_v2(p_treatment_id,p_fecha,site,case when t.role='DOCTORA' then p_profesional_id else null end),'{}'::jsonb);
 if coalesce((avail->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','BOOKING_AUTHORITY_BLOCKED','authority_status',coalesce(avail->>'status','UNKNOWN')); end if;
 select s into slot from jsonb_array_elements(coalesce(avail->'slots','[]'::jsonb)) s where s->>'hora'=substring(p_hora from 1 for 5) and coalesce((s->>'disponible')::boolean,false)=true and (t.role='ENFERMERIA' or s->>'professional_id'=p_profesional_id) limit 1;
 if slot is null then return jsonb_build_object('ok',false,'error','SLOT_NO_LONGER_AVAILABLE'); end if;
 prof_name:=case when t.role='DOCTORA' then nullif(slot->>'professional_name','') else 'ENFERMERIA' end;
 num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g'); if length(num)<7 then return jsonb_build_object('ok',false,'error','PHONE_REQUIRED'); end if; if coalesce(trim(p_nombre),'')='' then return jsonb_build_object('ok',false,'error','NAME_REQUIRED'); end if;
 select * into paciente from public.aos_pacientes where numero_limpio=num limit 1;
 if not found then insert into public.aos_pacientes(numero_limpio,"Nombres","Apellidos","Email","N° documento","ESTADO_PACIENTE","FECHA_REGISTRO","FUENTE") values(num,upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),nullif(trim(p_email),''),nullif(trim(p_dni),''),'PROSPECTO',current_date,case when ch='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end); elsif (paciente."Email" is null or paciente."Email"='') and coalesce(trim(p_email),'')<>'' then update public.aos_pacientes set "Email"=trim(p_email) where numero_limpio=num; end if;
 idv:=gen_random_uuid()::text;
 insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,nombre,apellido,numero,numero_limpio,tratamiento,sede,doctora,asesor,estado_cita,tipo_cita,tipo_atencion,origen_cita,obs,ts_creado,source_channel,source_campaign,source_link_token)
 values(idv,p_fecha,substring(p_hora from 1 for 5),upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),num,num,t.tratamiento,site,case when t.role='DOCTORA' then prof_name else null end,advisor,'PENDIENTE',upper(trim(coalesce(p_tipo_cita,'CONSULTA NUEVA'))),t.role,case when ch='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end,trim(coalesce(p_nota,''))||case when t.role='ENFERMERIA' then case when coalesce(trim(p_nota),'')='' then '' else ' | ' end||'BOOKING_MODE=SITE_POOL' else '' end,now(),ch,camp,case when coalesce(trim(p_token),'') in ('','__permanent__') then null else p_token end);
 if coalesce(trim(p_token),'') not in ('','__permanent__') then update public.aos_links_agenda set usado=true where token=p_token and tipo='paciente_especifico'; end if;
 return jsonb_build_object('ok',true,'status','BOOKED','agenda_id',idv,'fecha',p_fecha,'hora',substring(p_hora from 1 for 5),'sede',site,'role',t.role,'mode',t.mode,'treatment',t.tratamiento,'professional_name',case when t.role='DOCTORA' then prof_name else 'Enfermería' end,'source_channel',ch,'source_campaign',camp,'advisor_code',advisor);
end $$;
revoke all on function public.aos_agendar_publica_v2(text,text,text,text,uuid,date,text,text,text,text,text,text,text) from public;
grant execute on function public.aos_agendar_publica_v2(text,text,text,text,uuid,date,text,text,text,text,text,text,text) to anon,authenticated,service_role;

commit;
