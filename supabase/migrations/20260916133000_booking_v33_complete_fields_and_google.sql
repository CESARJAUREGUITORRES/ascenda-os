begin;

create or replace function public.aos_agendar_publica_v2(
  p_token text,p_nombre text,p_apellido text,p_telefono text,p_treatment_id uuid,p_fecha date,p_hora text,p_sede text,
  p_profesional_id text default null,p_dni text default '',p_email text default '',p_nota text default '',p_tipo_cita text default 'CONSULTA NUEVA'
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare l record; t record; num text; paciente record; advisor text; site text; avail jsonb; slot jsonb; prof_name text; idv text; attr jsonb; ch text; camp text;
begin
  select * into t from public.aos_booking_treatment_ref_v32(p_treatment_id); if not found then return jsonb_build_object('ok',false,'error','TREATMENT_NOT_ACTIVE'); end if;
  if coalesce(trim(p_token),'') in ('','__permanent__') then advisor:='ORGANICO'; else select * into l from public.aos_links_agenda where token=p_token and expira_at>now(); if not found then return jsonb_build_object('ok',false,'error','LINK_INVALID_OR_EXPIRED'); end if; advisor:=coalesce(nullif(trim(l.asesor_codigo),''),'ORGANICO'); end if;
  attr:=public.aos_booking_attribution_v1(p_token); ch:=coalesce(attr->>'source_channel','WEB'); camp:=nullif(attr->>'source_campaign','');
  site:=upper(replace(trim(coalesce(p_sede,'')),'_',' ')); if site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','SITE_INVALID'); end if;
  if p_fecha<current_date or extract(isodow from p_fecha)=7 then return jsonb_build_object('ok',false,'error','DATE_INVALID'); end if;
  if t.role='DOCTORA' and nullif(trim(p_profesional_id),'') is null then return jsonb_build_object('ok',false,'error','EXACT_PROVIDER_REQUIRED'); end if;
  perform pg_advisory_xact_lock(hashtextextended('public-booking-v33:'||t.role||':'||site||':'||p_fecha::text||':'||p_hora,0));
  avail:=coalesce(public.aos_booking_availability_v2(p_treatment_id,p_fecha,site,case when t.role='DOCTORA' then p_profesional_id else null end),'{}'::jsonb);
  if coalesce((avail->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','BOOKING_AUTHORITY_BLOCKED','authority_status',coalesce(avail->>'status','UNKNOWN')); end if;
  select s into slot from jsonb_array_elements(coalesce(avail->'slots','[]'::jsonb)) s where s->>'hora'=substring(p_hora from 1 for 5) and coalesce((s->>'disponible')::boolean,false)=true and (t.role='ENFERMERIA' or s->>'professional_id'=p_profesional_id) limit 1;
  if slot is null then return jsonb_build_object('ok',false,'error','SLOT_NO_LONGER_AVAILABLE'); end if;
  prof_name:=case when t.role='DOCTORA' then nullif(slot->>'professional_name','') else 'ENFERMERIA' end;
  num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g'); if length(num)<7 then return jsonb_build_object('ok',false,'error','PHONE_REQUIRED'); end if;
  if coalesce(trim(p_nombre),'')='' then return jsonb_build_object('ok',false,'error','NAME_REQUIRED'); end if;
  select * into paciente from public.aos_pacientes where numero_limpio=num limit 1;
  if not found then
    insert into public.aos_pacientes(numero_limpio,"Nombres","Apellidos","Email","N° documento","ESTADO_PACIENTE","FECHA_REGISTRO","FUENTE") values(num,upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),nullif(trim(p_email),''),nullif(trim(p_dni),''),'PROSPECTO',current_date,case when ch='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end);
  else
    update public.aos_pacientes set "Email"=case when coalesce(trim(p_email),'')<>'' then trim(p_email) else "Email" end, "N° documento"=case when coalesce(trim(p_dni),'')<>'' then trim(p_dni) else "N° documento" end where numero_limpio=num;
  end if;
  idv:=gen_random_uuid()::text;
  insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,nombre,apellido,dni,correo,numero,numero_limpio,tratamiento,sede,doctora,asesor,id_asesor,estado_cita,tipo_cita,tipo_atencion,origen_cita,origen,etiqueta_campana,obs,ts_creado,source_channel,source_campaign,source_link_token)
  values(idv,p_fecha,substring(p_hora from 1 for 5),upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),nullif(trim(p_dni),''),nullif(trim(p_email),''),num,num,t.tratamiento,site,case when t.role='DOCTORA' then prof_name else null end,advisor,case when advisor='ORGANICO' then null else advisor end,'PENDIENTE',upper(trim(coalesce(p_tipo_cita,'CONSULTA NUEVA'))),t.role,case when ch='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end,ch,camp,trim(coalesce(p_nota,''))||case when t.role='ENFERMERIA' then case when coalesce(trim(p_nota),'')='' then '' else ' | ' end||'BOOKING_MODE=SITE_POOL' else '' end,now(),ch,camp,case when coalesce(trim(p_token),'') in ('','__permanent__') then null else p_token end);
  if coalesce(trim(p_token),'') not in ('','__permanent__') then update public.aos_links_agenda set usado=true where token=p_token and tipo='paciente_especifico'; end if;
  perform public.aos_google_enqueue_authorized_appointment_v1(idv,'CALENDAR_UPSERT','PUBLIC_BOOKING_V33');
  return jsonb_build_object('ok',true,'status','BOOKED','agenda_id',idv,'fecha',p_fecha,'hora',substring(p_hora from 1 for 5),'sede',site,'role',t.role,'mode',t.mode,'treatment',t.tratamiento,'professional_name',case when t.role='DOCTORA' then prof_name else 'Enfermería' end,'source_channel',ch,'source_campaign',camp,'advisor_code',advisor,'email',nullif(trim(p_email),''));
end $$;

commit;
