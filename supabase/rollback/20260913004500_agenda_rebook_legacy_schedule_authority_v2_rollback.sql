-- Roll back schedule-authority V2 to the certified legacy bridge V1.
-- AGV2 legacy-treatment rebook bridge.
-- Preserves the same appointment row and falls back only when canonical treatment resolution is impossible.

create or replace function public.aos_agenda_rebook_legacy_safe_v1(
  p_token text,
  p_idempotency_key text,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_actor uuid;
  v_cita public.aos_agenda_citas%rowtype;
  v_cfg public.aos_config_horarios%rowtype;
  v_site text;
  v_date date;
  v_time time;
  v_role text;
  v_prof_name text;
  v_reason text;
  v_dow integer;
  v_count integer := 0;
  v_limit integer := 1;
  v_before jsonb;
  v_after jsonb;
begin
  if coalesce(length(btrim(p_idempotency_key)),0) < 16 or length(p_idempotency_key) > 160 then
    return jsonb_build_object('ok',false,'error','AGV2_IDEMPOTENCY_KEY_INVALID');
  end if;
  if coalesce(btrim(p_appointment_id),'')='' or p_payload is null or jsonb_typeof(p_payload)<>'object' then
    return jsonb_build_object('ok',false,'error','AGV2_CONTEXT_OR_PAYLOAD_INVALID');
  end if;

  v_actor:=public.aos_app_actor_v3(p_token,'advisor-agenda',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-agenda',true); end if;
  if v_actor is null then
    return jsonb_build_object('ok',false,'error','AGENDA_2FA_PANEL_REQUIRED');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('agenda-rebook-legacy:'||p_idempotency_key,0));

  select * into v_cita
  from public.aos_agenda_citas
  where id=p_appointment_id
  for update;

  if not found then return jsonb_build_object('ok',false,'error','AGV2_APPOINTMENT_NOT_FOUND'); end if;
  if upper(coalesce(v_cita.estado_cita,'PENDIENTE')) not in ('PENDIENTE','CITA CONFIRMADA') then
    return jsonb_build_object('ok',false,'error','AGV2_REBOOK_STATE_BLOCKED','current_status',v_cita.estado_cita);
  end if;

  v_site:=upper(replace(btrim(coalesce(p_payload->>'site','')),'_',' '));
  begin
    v_date:=(p_payload->>'date')::date;
    v_time:=(p_payload->>'time')::time;
  exception when others then
    return jsonb_build_object('ok',false,'error','AGV2_DATE_TIME_INVALID');
  end;
  v_role:=upper(btrim(coalesce(p_payload->>'slot_role',v_cita.tipo_atencion,'ENFERMERIA')));
  v_prof_name:=nullif(btrim(coalesce(p_payload->>'professional_name',v_cita.doctora,'')),'');
  v_reason:=nullif(btrim(p_payload->>'reason'),'');

  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','AGV2_SITE_INVALID');
  end if;
  if v_role not in ('DOCTORA','ENFERMERIA') then
    return jsonb_build_object('ok',false,'error','AGV2_SLOT_ROLE_REQUIRED');
  end if;

  if v_site=upper(replace(btrim(coalesce(v_cita.sede,'')),'_',' '))
     and v_date=v_cita.fecha_cita
     and to_char(v_time,'HH24:MI')=left(coalesce(v_cita.hora_cita,''),5)
     and v_role=upper(coalesce(v_cita.tipo_atencion,'ENFERMERIA'))
     and (v_role='ENFERMERIA' or upper(coalesce(v_prof_name,''))=upper(coalesce(v_cita.doctora,''))) then
    return jsonb_build_object('ok',true,'status','NO_CHANGE','appointment_id',p_appointment_id,'bridge_mode','LEGACY_SAFE','google_queue_required',false);
  end if;

  v_dow:=extract(isodow from v_date)::integer;
  select * into v_cfg
  from public.aos_config_horarios
  where upper(sede)=v_site and dia_semana=v_dow and activo=true
  order by updated_at desc nulls last
  limit 1;

  if not found then
    return jsonb_build_object('ok',false,'error','AGV2_LEGACY_SITE_CLOSED','site',v_site,'date',v_date);
  end if;

  if v_time < v_cfg.hora_apertura or v_time > v_cfg.hora_cierre then
    return jsonb_build_object(
      'ok',false,'error','AGV2_LEGACY_OUTSIDE_BUSINESS_HOURS',
      'opens',to_char(v_cfg.hora_apertura,'HH24:MI'),'closes',to_char(v_cfg.hora_cierre,'HH24:MI')
    );
  end if;

  if v_role='DOCTORA' then
    if v_prof_name is null then
      return jsonb_build_object('ok',false,'error','AGV2_EXACT_PROVIDER_REQUIRED');
    end if;
    if not exists(
      select 1 from public.aos_horarios_personal h
      where h.fecha=v_date
        and upper(h.sede)=v_site
        and upper(h.personal)=upper(v_prof_name)
        and h.activo=true
        and v_time >= nullif(h.hora_inicio,'')::time
        and v_time <= nullif(h.hora_fin,'')::time
    ) then
      return jsonb_build_object('ok',false,'error','AGV2_LEGACY_PROVIDER_NOT_SCHEDULED','professional_name',v_prof_name);
    end if;
    v_limit:=1;
    select count(*) into v_count
    from public.aos_agenda_citas c
    where c.id<>p_appointment_id
      and c.fecha_cita=v_date
      and upper(c.sede)=v_site
      and left(coalesce(c.hora_cita,''),5)=to_char(v_time,'HH24:MI')
      and upper(coalesce(c.doctora,''))=upper(v_prof_name)
      and upper(coalesce(c.estado_cita,'PENDIENTE')) not in ('CANCELADA','REAGENDADA','NO ASISTIO');
  else
    v_limit:=greatest(1,coalesce(v_cfg.max_citas_hora,1));
    select count(*) into v_count
    from public.aos_agenda_citas c
    where c.id<>p_appointment_id
      and c.fecha_cita=v_date
      and upper(c.sede)=v_site
      and left(coalesce(c.hora_cita,''),5)=to_char(v_time,'HH24:MI')
      and upper(coalesce(c.tipo_atencion,'ENFERMERIA'))='ENFERMERIA'
      and upper(coalesce(c.estado_cita,'PENDIENTE')) not in ('CANCELADA','REAGENDADA','NO ASISTIO');
  end if;

  if v_count >= v_limit then
    return jsonb_build_object('ok',false,'error','AGV2_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true);
  end if;

  v_before:=jsonb_build_object(
    'appointment_id',v_cita.id,'treatment',v_cita.tratamiento,'site',v_cita.sede,
    'date',v_cita.fecha_cita,'time',left(coalesce(v_cita.hora_cita,''),5),
    'role',v_cita.tipo_atencion,'professional_name',v_cita.doctora,'status',v_cita.estado_cita
  );

  update public.aos_agenda_citas
  set fecha_cita=v_date,
      hora_cita=to_char(v_time,'HH24:MI'),
      sede=v_site,
      doctora=case when v_role='DOCTORA' then v_prof_name else null end,
      tipo_atencion=v_role,
      estado_cita='PENDIENTE',
      obs=coalesce(v_reason,obs),
      ts_actualizado=now()
  where id=p_appointment_id;

  v_after:=jsonb_build_object(
    'appointment_id',p_appointment_id,'treatment',v_cita.tratamiento,'site',v_site,
    'date',v_date,'time',to_char(v_time,'HH24:MI'),'role',v_role,
    'professional_name',case when v_role='DOCTORA' then v_prof_name else 'Enfermería' end,
    'status','PENDIENTE'
  );

  return jsonb_build_object(
    'ok',true,'status','REBOOKED','appointment_id',p_appointment_id,
    'bridge_mode','LEGACY_SAFE','google_queue_required',true,
    'before',v_before,'after',v_after
  );
end
$$;

revoke all on function public.aos_agenda_rebook_legacy_safe_v1(text,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.aos_agenda_rebook_legacy_safe_v1(text,text,text,jsonb) to service_role;

create or replace function public.aos_agenda_rebook_bridge_v1(
  p_token text,
  p_idempotency_key text,
  p_appointment_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, pg_temp
as $$
declare
  v_result jsonb;
begin
  v_result:=public.aos_agenda_rebook_v2(p_token,p_idempotency_key,p_appointment_id,p_payload);

  if coalesce((v_result->>'ok')::boolean,false)=true then
    return jsonb_set(v_result,'{bridge_mode}','"CORE_V2"'::jsonb,true);
  end if;

  if coalesce(v_result->>'error','')<>'AGV2_REBOOK_TREATMENT_UNRESOLVED' then
    return v_result;
  end if;

  return public.aos_agenda_rebook_legacy_safe_v1(
    p_token,
    left(p_idempotency_key||':legacy',160),
    p_appointment_id,
    p_payload
  );
end
$$;

revoke all on function public.aos_agenda_rebook_bridge_v1(text,text,text,jsonb) from public;
grant execute on function public.aos_agenda_rebook_bridge_v1(text,text,text,jsonb) to anon, authenticated, service_role;
