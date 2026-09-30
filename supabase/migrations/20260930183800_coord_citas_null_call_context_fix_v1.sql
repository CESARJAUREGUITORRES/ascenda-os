begin;

-- P0 COORD-CITAS: appointments created without a call (Agenda, WEB, advisor links)
-- must still produce the canonical Comercial report. A PL/pgSQL record variable was
-- previously left unassigned when llamada_id_origen was null, causing the formatter
-- to fail before message creation. Use initialized scalar values instead.

create or replace function public.aos_coord_appointment_report_payload_v1(p_appointment_id text)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  a public.aos_agenda_citas%rowtype;
  v_tipo_gestion text:='';
  v_sub_estado text:='';
  v_class text;
  v_label text;
  v_sender text;
  v_advisor text;
  v_phone text;
  v_email text;
  v_obs text;
  v_attention text;
  v_channel text;
  v_msg text;
begin
  select * into a
  from public.aos_agenda_citas
  where id=p_appointment_id
  limit 1;

  if not found then
    return jsonb_build_object('ok',false,'error','APPOINTMENT_NOT_FOUND');
  end if;

  v_phone:=regexp_replace(coalesce(a.numero,''),'[^0-9]','','g');
  v_email:=nullif(trim(coalesce(a.correo,'')),'');

  if v_email is null then
    select nullif(trim(coalesce(p."Email",'')),'')
      into v_email
    from public.aos_pacientes p
    where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
      and (
        (v_phone<>'' and coalesce(p.numero_limpio,regexp_replace(coalesce(p."Teléfono",''),'[^0-9]','','g'))=v_phone)
        or
        (nullif(trim(coalesce(a.dni,'')),'') is not null and trim(coalesce(p."N° documento",''))=trim(a.dni))
      )
    order by
      case when coalesce(p."ESTADO_PACIENTE",'')='ACTIVO' then 0 else 1 end,
      p."FECHA_REGISTRO" desc nulls last
    limit 1;
  end if;

  if a.llamada_id_origen is not null then
    select coalesce(tipo_gestion,''),coalesce(sub_estado,'')
      into v_tipo_gestion,v_sub_estado
    from public.aos_llamadas
    where id=a.llamada_id_origen
    limit 1;
  end if;

  v_channel:=upper(trim(coalesce(a.source_channel,'')));
  v_advisor:=public.aos_booking_advisor_display_v12(a.id_asesor,a.asesor,a.source_link_token);

  if v_channel='WEB' then
    v_class:='WEB';
    v_label:='🌐 CITA WEB · ORGÁNICO';
    v_sender:='LINK WEB';
  elsif v_channel='ADVISOR_LINK' then
    v_class:='ADVISOR_LINK';
    v_sender:=coalesce(nullif(v_advisor,''),'LINK PERSONAL');
    v_label:='🔗 CITA WEB · LINK '||v_sender;
  elsif v_channel in ('EMAIL','EMAIL_MARKETING') then
    v_class:='EMAIL';
    v_label:='✉️ CITA WEB · EMAIL';
    v_sender:='EMAIL MKT';
  else
    v_class:=public.aos_callcenter_appointment_class_v1(
      a.origen_cita,
      v_tipo_gestion,
      v_sub_estado,
      a.llamada_id_origen
    );
    v_label:=case v_class
      when 'REACTIVADA' then '♻️ CITA REACTIVADA'
      when 'AGENDA_DIRECTA' then '🗓️ AGENDA DIRECTA'
      when 'IGNORAR' then '🔁 CITA REAGENDADA'
      else '✅ CITA NUEVA'
    end;
    v_sender:=coalesce(
      nullif(v_advisor,''),
      case
        when upper(trim(coalesce(a.asesor,''))) in ('ORGANICO','ORGÁNICO','NO APLICA','') then 'SISTEMA'
        else upper(trim(a.asesor))
      end
    );
  end if;

  v_attention:=upper(trim(coalesce(a.tipo_atencion,'')));
  if v_attention='' then v_attention:='POR DEFINIR'; end if;

  if v_attention like '%DOCTOR%'
     and nullif(trim(coalesce(a.doctora,'')),'') is not null then
    v_attention:=v_attention||' · '||trim(a.doctora);
  end if;

  v_obs:=trim(regexp_replace(coalesce(a.obs,''),'\[ASCENDA_BOOKING_[^\]]+\]','','gi'));
  if v_obs ~* 'OBS\s*:' then
    v_obs:=regexp_replace(v_obs,'(?is)^.*OBS\s*:\s*','','');
    v_obs:=regexp_replace(v_obs,'(?is)\s*ASESOR\s*:?.*$','','');
  end if;
  v_obs:=trim(v_obs);
  if v_obs='' then v_obs:='Sin observaciones'; end if;

  v_msg:=
    v_label || E'\n\n' ||
    '👤 Paciente: ' || trim(concat_ws(' ',a.nombre,a.apellido)) || E'\n' ||
    '🪪 DNI / C.E.: ' || coalesce(nullif(trim(a.dni),''),'No registrado') || E'\n' ||
    '📱 Teléfono: ' || coalesce(nullif(trim(a.numero),''),'No registrado') || E'\n' ||
    '✉️ Correo: ' || coalesce(v_email,'No registrado') || E'\n' ||
    '🏥 Sede: ' || coalesce(nullif(trim(a.sede),''),'Por definir') || E'\n' ||
    '📅 Fecha: ' || coalesce(to_char(a.fecha_cita,'DD/MM/YYYY'),'Por definir') || E'\n' ||
    '🕐 Hora: ' || coalesce(nullif(trim(a.hora_cita),''),'Por definir') || E'\n' ||
    '💉 Tratamiento: ' || coalesce(nullif(trim(a.tratamiento),''),'Por definir') || E'\n' ||
    '🩺 Atención: ' || v_attention || E'\n\n' ||
    '📝 Observaciones: ' || v_obs || E'\n\n' ||
    '👥 Asesor / origen: ' || v_sender;

  return jsonb_build_object(
    'ok',true,
    'appointment_id',a.id,
    'sender',v_sender,
    'classification',v_class,
    'classification_label',v_label,
    'message',v_msg
  );
end
$$;

revoke all on function public.aos_coord_appointment_report_payload_v1(text) from public;
grant execute on function public.aos_coord_appointment_report_payload_v1(text) to authenticated,service_role;

commit;
