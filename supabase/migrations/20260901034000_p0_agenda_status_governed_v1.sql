-- ASCENDA OS · P0 Agenda status governed write V1
-- Replaces the browser's multi-request PATCH/DELETE/POST sequence for status
-- changes with one authenticated transaction. This also allows a human Agenda
-- operator to update a WHATSAPP-origin appointment without weakening the WA-4C
-- direct-write trigger.

create or replace function public.aos_agenda_set_status_v1(
  p_token text,
  p_cita_id text,
  p_estado text,
  p_asistente text default null,
  p_nota text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_actor_code text;
  v_cita public.aos_agenda_citas%rowtype;
  v_estado text:=upper(pg_catalog.btrim(coalesce(p_estado,'')));
  v_asistente text:=pg_catalog.btrim(coalesce(p_asistente,''));
  v_nota text:=coalesce(p_nota,'');
  v_es_doctora boolean:=false;
  v_prof_nombre text:='';
  v_prof_tipo text:='';
  v_asist_nombre text:='';
  v_atencion_id text;
  v_has_notes boolean:=false;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-agenda',false);
  if v_actor is null then
    v_actor:=public.aos_app_actor_v3(p_token,'admin-agenda',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','AGENDA_2FA_PANEL_REQUIRED');
  end if;

  select u.codigo_asesor into v_actor_code
  from public.aos_usuarios u
  where u.id=v_actor and u.activo=true;

  if v_estado not in ('PENDIENTE','CITA CONFIRMADA','ASISTIO','EFECTIVA','NO ASISTIO','CANCELADA') then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_APPOINTMENT_STATUS');
  end if;

  select * into v_cita
  from public.aos_agenda_citas a
  where a.id=p_cita_id
  for update;
  if not found then
    return pg_catalog.jsonb_build_object('ok',false,'error','APPOINTMENT_NOT_FOUND');
  end if;

  -- Human-governed Agenda writes are allowed to mutate a WhatsApp-created row;
  -- direct browser writes remain blocked by the existing trigger.
  perform pg_catalog.set_config('aos.wa4_governed_booking_write','1',true);

  if v_estado in ('ASISTIO','EFECTIVA') then
    v_es_doctora:=upper(coalesce(v_cita.tipo_atencion,'')) like '%DOCTOR%';
    if v_es_doctora then
      v_prof_nombre:=pg_catalog.btrim(coalesce(v_cita.doctora,''));
      if v_prof_nombre='' or upper(v_prof_nombre) in ('SIN ASIGNAR','SIN DOCTORA ESE DIA','BUSCANDO...','BUSCANDO') then
        return pg_catalog.jsonb_build_object('ok',false,'error','DOCTOR_AUTHORITY_REQUIRED');
      end if;
      v_prof_tipo:='DOCTORA';
      v_asist_nombre:=v_asistente;
    else
      v_prof_nombre:=v_asistente;
      v_prof_tipo:='ENFERMERIA';
      v_asist_nombre:='';
      if v_prof_nombre='' or upper(v_prof_nombre) in ('--','NO APLICA') then
        return pg_catalog.jsonb_build_object('ok',false,'error','ATTENDING_NURSE_REQUIRED');
      end if;
    end if;
  end if;

  update public.aos_agenda_citas
  set estado_cita=v_estado,
      obs=case when v_nota is distinct from coalesce(obs,'') then v_nota else obs end,
      ts_actualizado=pg_catalog.now()
  where id=v_cita.id;

  if v_estado in ('ASISTIO','EFECTIVA') then
    select a.id into v_atencion_id
    from public.aos_atenciones a
    where a.cita_id=v_cita.id
    order by a.created_at desc nulls last,a.id desc
    limit 1
    for update;

    if v_atencion_id is null then
      v_atencion_id:=pg_catalog.gen_random_uuid()::text;
      insert into public.aos_atenciones(
        id,numero_limpio,fecha,sede,profesional_nombre,profesional_tipo,
        asistente_nombre,estado,paciente_nombre,paciente_telefono,cita_id,
        tratamiento_principal,tipo_atencion,observaciones,created_at,updated_at
      ) values(
        v_atencion_id,v_cita.numero_limpio,v_cita.fecha_cita,coalesce(v_cita.sede,'SAN ISIDRO'),
        v_prof_nombre,v_prof_tipo,nullif(v_asist_nombre,''),'PENDIENTE',
        pg_catalog.btrim(concat_ws(' ',coalesce(v_cita.nombre,''),coalesce(v_cita.apellido,''))),
        v_cita.numero_limpio,v_cita.id,coalesce(v_cita.tratamiento,''),'CONSULTA',v_nota,
        pg_catalog.now(),pg_catalog.now()
      );
    else
      update public.aos_atenciones
      set profesional_nombre=v_prof_nombre,
          profesional_tipo=v_prof_tipo,
          asistente_nombre=nullif(v_asist_nombre,''),
          sede=coalesce(v_cita.sede,sede),
          tratamiento_principal=coalesce(nullif(v_cita.tratamiento,''),tratamiento_principal),
          observaciones=v_nota,
          updated_at=pg_catalog.now()
      where id=v_atencion_id;
    end if;
  elsif v_estado in ('PENDIENTE','CITA CONFIRMADA') then
    select exists(
      select 1 from public.aos_notas_clinicas n
      where n.numero_limpio=v_cita.numero_limpio and n.fecha=v_cita.fecha_cita
    ) into v_has_notes;
    if not v_has_notes then
      delete from public.aos_atenciones a
      where a.numero_limpio=v_cita.numero_limpio and a.fecha=v_cita.fecha_cita;
    end if;
  end if;

  insert into public.aos_log_auditoria(
    timestamp_reg,asesor,accion,referencia,detalle,tabla,usuario,registro_id,datos_new,metadata
  ) values(
    pg_catalog.now(),coalesce(v_actor_code,'AGENDA'),'AGENDA_STATUS_GOVERNED',v_cita.id,
    'Estado de cita actualizado por transacción gobernada','aos_agenda_citas',coalesce(v_actor_code,'AGENDA'),v_cita.id,
    pg_catalog.jsonb_build_object('estado',v_estado,'atencion_id',v_atencion_id,'has_clinical_notes',v_has_notes),
    pg_catalog.jsonb_build_object('source','AGENDA_STATUS_GOVERNED_V1','actor_id',v_actor)
  );

  return pg_catalog.jsonb_build_object(
    'ok',true,'appointmentId',v_cita.id,'status',v_estado,
    'attentionId',v_atencion_id,'clinicalNotesPreserved',v_has_notes
  );
end
$function$;

revoke all on function public.aos_agenda_set_status_v1(text,text,text,text,text) from public;
grant execute on function public.aos_agenda_set_status_v1(text,text,text,text,text) to anon,authenticated,service_role;
