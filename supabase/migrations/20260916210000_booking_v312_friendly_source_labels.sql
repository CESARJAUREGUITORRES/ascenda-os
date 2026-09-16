begin;

-- BOOKING-V3.12 / COORD-CITAS-V1.2
-- Human-facing attribution only: never expose UUIDs, tokens or full links in push/in-app/chat.
-- Booking persistence, availability, Google/email and canonical attribution fields remain unchanged.

create or replace function public.aos_booking_advisor_display_v12(
  p_id_asesor text,
  p_asesor text,
  p_source_link_token text default null
)
returns text
language plpgsql
stable
security definer
set search_path='public','pg_temp'
as $$
declare
  v_name text;
  v_raw text:=trim(coalesce(p_asesor,''));
begin
  select upper(trim(u.nombre))
    into v_name
  from public.aos_usuarios u
  where u.activo=true
    and (
      (nullif(trim(coalesce(p_id_asesor,'')),'') is not null and u.id::text=trim(p_id_asesor))
      or (v_raw<>'' and u.id::text=v_raw)
      or (v_raw<>'' and upper(trim(coalesce(u.nombre,'')))=upper(v_raw))
      or (v_raw<>'' and upper(trim(coalesce(u.codigo_asesor,'')))=upper(v_raw))
    )
  order by case
    when u.id::text=trim(coalesce(p_id_asesor,'')) then 0
    when u.id::text=v_raw then 1
    when upper(trim(coalesce(u.nombre,'')))=upper(v_raw) then 2
    else 3
  end
  limit 1;

  if v_name is null and nullif(trim(coalesce(p_source_link_token,'')),'') is not null then
    select upper(trim(u.nombre))
      into v_name
    from public.aos_links_agenda l
    join public.aos_usuarios u on u.id=l.asesor_user_id
    where l.token=trim(p_source_link_token)
      and coalesce(l.activo,true)=true
      and u.activo=true
    limit 1;
  end if;

  if v_name is not null and v_name<>'' then
    return v_name;
  end if;

  if v_raw ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     or v_raw ~ '^[A-Za-z0-9_-]{24,}$' then
    return null;
  end if;

  return nullif(upper(v_raw),'');
end
$$;

revoke all on function public.aos_booking_advisor_display_v12(text,text,text) from public;
grant execute on function public.aos_booking_advisor_display_v12(text,text,text) to authenticated,service_role;

create or replace function public.aos_booking_source_label_v1(
  p_channel text,
  p_campaign text,
  p_advisor text
)
returns text
language sql
stable
as $$
  select case upper(coalesce($1,''))
    when 'WEB' then 'Web orgánico'
    when 'EMAIL' then 'Email marketing'
    when 'EMAIL_MARKETING' then 'Email marketing'
    when 'ADVISOR_LINK' then
      case
        when coalesce(trim($3),'')='' then 'Link personal'
        when trim($3) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then 'Link personal'
        when trim($3) ~ '^[A-Za-z0-9_-]{24,}$' then 'Link personal'
        else 'Link '||initcap(lower(trim($3)))
      end
    when 'WHATSAPP' then 'WhatsApp'
    when 'CALL_CENTER' then 'Call Center'
    when 'MANUAL' then 'Manual'
    else initcap(replace(coalesce(nullif($1,''),'Otro'),'_',' '))
  end
$$;

create or replace function public.aos_notification_agenda_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  uid uuid;
  patient text;
  st text;
  oldst text;
  ev text;
  adm_ev text;
  adm record;
  peer record;
  tg text;
  substate text;
  cls text;
  subtype text;
  daily_total integer:=1;
  advisor_name text;
  meta jsonb;
  src text;
  camp text;
  src_label text;
begin
  uid:=public.aos_notification_resolve_user_v1(coalesce(nullif(new.id_asesor,''),new.asesor));
  patient:=trim(concat_ws(' ',nullif(new.nombre,''),nullif(new.apellido,'')));

  if tg_op='INSERT' then
    if new.llamada_id_origen is not null then
      select l.tipo_gestion,l.sub_estado into tg,substate
      from public.aos_llamadas l
      where l.id=new.llamada_id_origen;
    end if;

    cls:=public.aos_callcenter_appointment_class_v1(new.origen_cita,tg,substate,new.llamada_id_origen);
    subtype:=public.aos_callcenter_appointment_subtype_v1(new.origen_cita,tg,substate,new.llamada_id_origen);

    advisor_name:=public.aos_booking_advisor_display_v12(
      new.id_asesor,
      new.asesor,
      new.source_link_token
    );

    src:=coalesce(
      nullif(new.source_channel,''),
      case
        when new.origen_cita='WEB-PUBLICA' then 'WEB'
        when new.origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK'
        else coalesce(new.origen_cita,'OTHER')
      end
    );
    camp:=nullif(new.source_campaign,'');
    src_label:=public.aos_booking_source_label_v1(src,camp,advisor_name);

    if cls<>'IGNORAR' and nullif(advisor_name,'') is not null then
      select count(*) into daily_total
      from public.aos_agenda_citas a
      left join public.aos_llamadas l on l.id=a.llamada_id_origen
      where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=(now() at time zone 'America/Lima')::date
        and (
          (nullif(new.id_asesor,'') is not null and a.id_asesor=new.id_asesor)
          or
          (nullif(new.id_asesor,'') is null and upper(trim(coalesce(a.asesor,'')))=upper(trim(coalesce(new.asesor,''))))
        )
        and public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)=cls;
    end if;

    meta:=jsonb_build_object(
      'count',1,
      'last_patient',patient,
      'date',coalesce(new.fecha_cita::text,''),
      'time',coalesce(new.hora_cita,''),
      'last_sede',coalesce(new.sede,''),
      'last_treatment',coalesce(new.tratamiento,''),
      'advisor_name',coalesce(advisor_name,case when upper(coalesce(src,''))='WEB' then 'WEB' else 'ASCENDA' end),
      'appointment_class',cls,
      'appointment_subtype',subtype,
      'daily_total',greatest(1,daily_total),
      'source_channel',src,
      'source_campaign',camp,
      'source_label',src_label
    );

    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','APPOINTMENT_CREATED',
        'recipient_user_id',uid,
        'entity_id',new.id,
        'group_key',case when cls='IGNORAR' then 'advisor' else null end,
        'metadata',meta
      ));
    end if;

    for adm in
      select id
      from public.aos_usuarios
      where activo=true
        and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)<=2)
        and (uid is null or id<>uid)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','ADMIN_APPOINTMENT_DIGEST',
        'recipient_user_id',adm.id,
        'entity_id',new.id,
        'dedupe_key','admin-appointment-score:'||new.id||':'||adm.id::text,
        'metadata',meta
      ));
    end loop;

    if cls<>'IGNORAR' then
      for peer in
        select id
        from public.aos_usuarios
        where activo=true
          and lower(coalesce(rol,''))='asesor'
          and coalesce(paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
          and (uid is null or id<>uid)
      loop
        perform public.aos_notification_emit_v1(jsonb_build_object(
          'event_type','TEAM_APPOINTMENT_SCORE',
          'recipient_user_id',peer.id,
          'entity_id',new.id,
          'dedupe_key','team-appointment-score:'||new.id||':'||peer.id::text,
          'metadata',meta
        ));
      end loop;
    end if;

    return new;
  end if;

  st:=upper(trim(coalesce(new.estado_cita,'')));
  oldst:=upper(trim(coalesce(old.estado_cita,'')));
  if st=oldst then return new; end if;

  if st in ('ASISTIO','EFECTIVA') and oldst not in ('ASISTIO','EFECTIVA') then
    ev:='APPOINTMENT_ATTENDED'; adm_ev:='ADMIN_ATTENDED_DIGEST';
  elsif st='NO ASISTIO' then
    ev:='APPOINTMENT_NO_SHOW'; adm_ev:='ADMIN_NO_SHOW_DIGEST';
  elsif st='CANCELADA' then
    ev:='APPOINTMENT_CANCELLED';
  elsif st='REAGENDADA' then
    ev:='APPOINTMENT_RESCHEDULED';
  else
    return new;
  end if;

  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type',ev,
      'recipient_user_id',uid,
      'entity_id',new.id,
      'dedupe_key','agenda:'||lower(ev)||':'||new.id||':'||md5(st),
      'metadata',jsonb_build_object(
        'count',1,
        'last_patient',patient,
        'date',coalesce(new.fecha_cita::text,''),
        'time',coalesce(new.hora_cita,''),
        'last_sede',coalesce(new.sede,''),
        'last_treatment',coalesce(new.tratamiento,'')
      )
    ));
  end if;

  if adm_ev is not null then
    for adm in
      select id
      from public.aos_usuarios
      where activo=true
        and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type',adm_ev,
        'recipient_user_id',adm.id,
        'entity_id',new.id,
        'group_key','all-attendance',
        'metadata',jsonb_build_object('count',1)
      ));
    end loop;
  end if;

  return new;
end
$$;

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
    select tipo_gestion,sub_estado
      into l
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

-- Rewrite existing human-facing notification labels from the canonical appointment.
with n as (
  select
    no.id,
    no.event_type,
    no.entity_id,
    a.id_asesor,
    a.asesor,
    a.source_link_token,
    coalesce(
      nullif(a.source_channel,''),
      case
        when a.origen_cita='WEB-PUBLICA' then 'WEB'
        when a.origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK'
        else coalesce(a.origen_cita,'OTHER')
      end
    ) src,
    nullif(a.source_campaign,'') camp,
    public.aos_booking_advisor_display_v12(a.id_asesor,a.asesor,a.source_link_token) advisor_name,
    no.metadata
  from public.aos_notificaciones no
  join public.aos_agenda_citas a on a.id=no.entity_id
  where no.event_type in ('APPOINTMENT_CREATED','ADMIN_APPOINTMENT_DIGEST','TEAM_APPOINTMENT_SCORE')
)
update public.aos_notificaciones no
set metadata=n.metadata || jsonb_build_object(
      'advisor_name',coalesce(n.advisor_name,case when upper(n.src)='WEB' then 'WEB' else 'ASCENDA' end),
      'source_channel',n.src,
      'source_campaign',n.camp,
      'source_label',public.aos_booking_source_label_v1(n.src,n.camp,n.advisor_name)
    ),
    updated_at=now()
from n
where no.id=n.id;

do $$
declare
  x record;
  f jsonb;
begin
  for x in
    select id,event_type,metadata
    from public.aos_notificaciones
    where event_type in ('APPOINTMENT_CREATED','ADMIN_APPOINTMENT_DIGEST','TEAM_APPOINTMENT_SCORE')
      and entity_id in (select id from public.aos_agenda_citas)
  loop
    if x.event_type in ('APPOINTMENT_CREATED','ADMIN_APPOINTMENT_DIGEST') then
      f:=public.aos_notification_format_booking_v31(x.event_type,x.metadata);
    else
      f:=public.aos_notification_format_v1(x.event_type,x.metadata);
    end if;

    update public.aos_notificaciones
    set titulo=f->>'title',
        contenido=f->>'body',
        updated_at=now()
    where id=x.id;
  end loop;
end
$$;

-- Historical automatic Comercial cards are intentionally not rewritten here:
-- the Coordination channel is lock-guarded. New reports use the friendly labels immediately.

commit;
