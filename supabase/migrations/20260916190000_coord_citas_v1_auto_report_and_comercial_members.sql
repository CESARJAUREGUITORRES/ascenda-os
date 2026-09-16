begin;

-- BOOKING-V3.9 / COORD-CITAS-V1
-- Centralized appointment -> Coordination/Comercial report.
-- The trigger is attached to the canonical appointment ledger, so every insert path
-- (Agenda, Call Center, direct Agenda, WEB, advisor link, future governed surfaces)
-- emits the same operational report without duplicating booking logic.

create table if not exists public.aos_coord_appointment_reports (
  appointment_id text primary key references public.aos_agenda_citas(id) on delete cascade,
  channel_id text not null default 'CH-GRP-COMERCIAL',
  message_id uuid null,
  report_status text not null default 'PENDING',
  error_text text null,
  created_at timestamptz not null default now(),
  sent_at timestamptz null
);

comment on table public.aos_coord_appointment_reports is
'Idempotency/audit ledger for automatic appointment reports sent to Coordination > Comercial.';

-- Comercial = commercial/call-center operational staff.
-- Preserve legacy ADMIN/SRA CARMEN while adding every active advisor who has Calls + Coordination.
update public.aos_canales
set participantes = jsonb_build_array(
      'ADMIN','CESAR','SRA CARMEN','MIREYA','RODRIGO','RUVILA','WILMER'
    ),
    updated_at = now()
where id='CH-GRP-COMERCIAL' and lower(coalesce(nombre,''))='comercial';

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
  v_campaign text;
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
  v_campaign:=nullif(trim(coalesce(a.source_campaign,'')),'');

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

  -- Extract the useful free-text observation from legacy appointment templates
  -- and remove internal booking markers.
  v_obs:=trim(regexp_replace(coalesce(a.obs,''),'\[ASCENDA_BOOKING_[^\]]+\]','','gi'));
  if v_obs ~* 'OBS\s*:' then
    v_obs:=regexp_replace(v_obs,'(?is)^.*OBS\s*:\s*','','');
    v_obs:=regexp_replace(v_obs,'(?is)\s*ASESOR\s*:?.*$','','');
  end if;
  v_obs:=trim(v_obs);
  if v_obs='' then v_obs:='Sin observaciones'; end if;

  v_msg:=
    '📌 CITA REGISTRADA' || E'\n' ||
    v_label || E'\n\n' ||
    '👤 Paciente: ' || trim(concat_ws(' ',a.nombre,a.apellido)) || E'\n' ||
    '🪪 DNI / C.E.: ' || coalesce(nullif(trim(a.dni),''),'No registrado') || E'\n' ||
    '📱 Teléfono: ' || coalesce(nullif(trim(a.numero),''),'No registrado') || E'\n' ||
    '✉️ Correo: ' || coalesce(v_email,'No registrado') || E'\n\n' ||
    '🏥 Sede: ' || coalesce(nullif(trim(a.sede),''),'Por definir') || E'\n' ||
    '📅 Fecha: ' || coalesce(to_char(a.fecha_cita,'DD/MM/YYYY'),'Por definir') || E'\n' ||
    '🕐 Hora: ' || coalesce(nullif(trim(a.hora_cita),''),'Por definir') || E'\n' ||
    '💉 Tratamiento: ' || coalesce(nullif(trim(a.tratamiento),''),'Por definir') || E'\n' ||
    '🩺 Atención: ' || v_attention || E'\n\n' ||
    '📝 Observaciones: ' || v_obs || E'\n\n' ||
    '👥 Asesor / origen: ' || v_sender ||
    case when v_channel<>'' then E'\n🏷️ Canal: '||v_channel else '' end ||
    case when v_campaign is not null then E'\n📣 Campaña: '||v_campaign else '' end ||
    E'\n🔎 ID cita: ' || a.id;

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

create or replace function public.aos_coord_appointment_report_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_claimed text;
  v_payload jsonb;
  v_send jsonb;
  v_mid uuid;
begin
  -- A prior dedupe/cleanup trigger may have removed the row. Never report a row
  -- that no longer exists in the canonical ledger.
  if not exists(select 1 from public.aos_agenda_citas where id=new.id) then
    return new;
  end if;

  insert into public.aos_coord_appointment_reports(appointment_id,channel_id,report_status)
  values(new.id,'CH-GRP-COMERCIAL','PENDING')
  on conflict (appointment_id) do nothing
  returning appointment_id into v_claimed;

  if v_claimed is null then return new; end if;

  begin
    v_payload:=public.aos_coord_appointment_report_payload_v1(new.id);
    if coalesce((v_payload->>'ok')::boolean,false) is not true then
      update public.aos_coord_appointment_reports
      set report_status='ERROR',error_text=coalesce(v_payload->>'error','PAYLOAD_ERROR')
      where appointment_id=new.id;
      return new;
    end if;

    v_send:=public.aos_enviar_mensaje(
      'CH-GRP-COMERCIAL',
      coalesce(nullif(v_payload->>'sender',''),'SISTEMA'),
      null,
      v_payload->>'message',
      'CITA_AUTO'
    );

    if coalesce((v_send->>'ok')::boolean,false) then
      v_mid:=(v_send->>'id')::uuid;
      update public.aos_coord_appointment_reports
      set report_status='SENT',message_id=v_mid,sent_at=now(),error_text=null
      where appointment_id=new.id;
    else
      update public.aos_coord_appointment_reports
      set report_status='ERROR',error_text='MESSAGE_SEND_REJECTED'
      where appointment_id=new.id;
    end if;
  exception when others then
    update public.aos_coord_appointment_reports
    set report_status='ERROR',error_text=left(sqlerrm,500)
    where appointment_id=new.id;
    -- Reporting must never block booking persistence.
    return new;
  end;

  return new;
end
$$;

drop trigger if exists trg_zzz_aos_coord_appointment_report_v1 on public.aos_agenda_citas;
create trigger trg_zzz_aos_coord_appointment_report_v1
after insert on public.aos_agenda_citas
for each row execute function public.aos_coord_appointment_report_trigger_v1();

commit;