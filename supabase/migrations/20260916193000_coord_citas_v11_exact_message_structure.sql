begin;

-- COORD-CITAS-V1.1
-- Keep the automatic appointment report concise and in the exact operational order
-- used by the team. Classification remains the first line; internal IDs/channels are
-- intentionally omitted from the human-facing message.

create or replace function public.aos_coord_appointment_report_payload_v1(p_appointment_id text)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  a public.aos_agenda_citas%rowtype;
  l record;
  v_class text;
  v_label text;
  v_sender text;
  v_phone text;
  v_email text;
  v_obs text;
  v_attention text;
  v_channel text;
  v_msg text;
begin
  select * into a from public.aos_agenda_citas where id=p_appointment_id limit 1;
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
        or (nullif(trim(coalesce(a.dni,'')),'') is not null and trim(coalesce(p."N° documento",''))=trim(a.dni))
      )
    order by case when coalesce(p."ESTADO_PACIENTE",'')='ACTIVO' then 0 else 1 end,
             p."FECHA_REGISTRO" desc nulls last
    limit 1;
  end if;

  if a.llamada_id_origen is not null then
    select tipo_gestion,sub_estado into l
    from public.aos_llamadas
    where id=a.llamada_id_origen
    limit 1;
  end if;

  v_channel:=upper(trim(coalesce(a.source_channel,'')));

  if v_channel='WEB' then
    v_class:='WEB';
    v_label:='🌐 CITA WEB · ORGÁNICO';
  elsif v_channel='ADVISOR_LINK' then
    v_class:='ADVISOR_LINK';
    v_label:='🔗 CITA WEB · LINK PERSONAL';
  elsif v_channel='EMAIL' then
    v_class:='EMAIL';
    v_label:='✉️ CITA WEB · EMAIL';
  else
    v_class:=public.aos_callcenter_appointment_class_v1(
      a.origen_cita,
      coalesce(l.tipo_gestion,''),
      coalesce(l.sub_estado,''),
      a.llamada_id_origen
    );
    v_label:=case v_class
      when 'REACTIVADA' then '♻️ CITA REACTIVADA'
      when 'AGENDA_DIRECTA' then '🗓️ AGENDA DIRECTA'
      when 'IGNORAR' then '🔁 CITA REAGENDADA'
      else '✅ CITA NUEVA'
    end;
  end if;

  v_sender:=upper(trim(coalesce(nullif(a.asesor,''),'')));
  if v_sender='' or v_sender in ('ORGANICO','ORGÁNICO','NO APLICA') then
    v_sender:=case
      when v_channel='WEB' then 'WEB'
      when v_channel='EMAIL' then 'EMAIL MKT'
      else coalesce(nullif(v_sender,''),'SISTEMA')
    end;
  end if;

  v_attention:=upper(trim(coalesce(a.tipo_atencion,'')));
  if v_attention='' then v_attention:='POR DEFINIR'; end if;
  if v_attention like '%DOCTOR%' and nullif(trim(coalesce(a.doctora,'')),'') is not null then
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

-- Reformat already-generated automatic cards using the same canonical formatter.
update public.aos_mensajes m
set mensaje = p.payload->>'message',
    updated_at = now()
from public.aos_coord_appointment_reports r
cross join lateral public.aos_coord_appointment_report_payload_v1(r.appointment_id) p(payload)
where m.id=r.message_id
  and m.tipo='CITA_AUTO'
  and coalesce((p.payload->>'ok')::boolean,false)=true;

-- Keep channel preview aligned with the last human-facing automatic report.
update public.aos_canales ch
set ultimo_mensaje = left(m.mensaje,100),
    ultimo_mensaje_at = m.created_at,
    updated_at = now()
from lateral (
  select mensaje,created_at
  from public.aos_mensajes
  where canal='CH-GRP-COMERCIAL' and coalesce(eliminado,false)=false
  order by created_at desc
  limit 1
) m
where ch.id='CH-GRP-COMERCIAL';

commit;