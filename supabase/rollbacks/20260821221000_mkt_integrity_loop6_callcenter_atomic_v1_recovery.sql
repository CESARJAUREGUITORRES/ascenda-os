-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6 rollback
-- Does not touch repaired calls/agendas or restore removed duplicates.

begin;

revoke execute on function public.aos_callcenter_commit_action_v1(text,text,text,jsonb) from anon, authenticated, service_role;
revoke execute on function public.aos_callcenter_prepare_action_v1(text,text) from anon, authenticated, service_role;

drop function if exists public.aos_callcenter_commit_action_v1(text,text,text,jsonb);
drop function if exists public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text);
drop function if exists public.aos_callcenter_prepare_action_v1(text,text);
drop function if exists public.aos_callcenter_patient_state_v1(text,timestamptz);
drop table if exists public.aos_callcenter_actions_v1;

-- Restore cleanup fingerprint baseline a6f918f64ac56f587a75ed0aebde0e09.
create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_call_ts timestamptz;
  v_agenda_ts timestamptz;
  v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_agenda_ts:=coalesce(new.ts_creado,now());
    delete from public.aos_llamadas l
    where l.numero_limpio=v_num
      and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,''))
      and upper(coalesce(l.tipo_gestion,'LLAMADA')) not in ('LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA')
      and (upper(coalesce(l.estado,''))='CITA CONFIRMADA' or (upper(coalesce(l.estado,''))='SEGUIMIENTO' and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE'))
      and abs(extract(epoch from(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts)))<=10;
    return new;
  end if;
  if tg_table_name='aos_llamadas' then
    if upper(coalesce(new.tipo_gestion,'LLAMADA')) in ('LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA') then return new; end if;
    if not (upper(coalesce(new.estado,''))='CITA CONFIRMADA' or (upper(coalesce(new.estado,''))='SEGUIMIENTO' and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE')) then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
    if exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(a.origen_cita,''))='CITA_MANUAL' and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10) then
      delete from public.aos_llamadas where id=new.id;
    end if;
    return new;
  end if;
  return new;
end;
$function$;

-- Restore call guard fingerprint baseline d05de50205e7c716cc048c4a5e6923a2.
create or replace function public.aos_hotfix_call_guard_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_num text; v_call_ts timestamptz; v_eff_trat text;
  v_prior_count integer:=0; v_match_count integer:=0; v_any_leads integer:=0;
  v_lead_id bigint; v_lead_trat text; v_lead_anuncio text;
  v_noncommercial text; v_reason text;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
  new.numero_limpio:=v_num;
  if upper(trim(coalesce(new.estado,'')))<>'CITA CONFIRMADA' or v_num='' then return new; end if;
  v_call_ts:=public.aos_llamada_event_ts(coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);

  if exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
     or exists(select 1 from public.aos_atenciones a where a.numero_limpio=v_num and a.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
     or exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and a.fecha_cita<coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))
     or upper(coalesce(new.observacion,'')) ~ '(ANTIGU|SESION|SESIÓN|CONTROL|DEUDA|APLICACION|APLICACIÓN)'
  then
    v_noncommercial:='PACIENTE_CONTINUIDAD';
    v_reason:='Paciente/continuidad: evidencia clínica, venta, asistencia o texto operativo previo.';
  end if;

  if v_noncommercial is not null then
    insert into public.aos_gestiones_no_comerciales(source_call_id,clasificacion,motivo,asesor,numero_limpio,fecha,lead_id_origen,call_payload,agenda_ids,source)
    values(new.id,v_noncommercial,v_reason,new.asesor,v_num,coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.lead_id_origen,to_jsonb(new),null,'CALL_GUARD_V3')
    on conflict(source_call_id) do nothing;
    return null;
  end if;

  if exists(select 1 from public.aos_llamadas l where l.numero_limpio=v_num and l.fecha=coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(l.estado,''))='CITA CONFIRMADA') then
    new.estado:='SEGUIMIENTO';
    new.sub_estado:='CITA YA EXISTENTE';
    new.origen:=coalesce(nullif(new.origen,''),'FOLLOWUP_EXISTING_CITA');
    new.observacion:=trim(concat_ws(' | ',nullif(new.observacion,''),'No suma nueva conversión: ya existía CITA CONFIRMADA para este número/asesor en el día.'));
    return new;
  end if;

  v_eff_trat:=case when upper(coalesce(new.tratamiento,''))='ORGANICO' then coalesce(nullif(new.anuncio,''),new.tratamiento,'') else coalesce(new.tratamiento,'') end;
  select count(*) into v_prior_count from public.aos_marketing_touchpoints_v2(null,null) t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts;
  if v_prior_count=1 then
    select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts order by t.lead_ts desc,t.lead_id desc limit 1;
  elsif v_prior_count>1 and nullif(trim(v_eff_trat),'') is not null then
    select count(*) into v_match_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g');
    if v_match_count=1 then
      select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g') order by t.lead_ts desc,t.lead_id desc limit 1;
    end if;
  end if;

  if v_lead_id is not null then
    new.lead_id_origen:=v_lead_id;
    new.origen:='MARKETING';
    new.anuncio:=coalesce(nullif(new.anuncio,''),v_lead_anuncio);
    if nullif(trim(coalesce(new.tratamiento,'')),'') is null or upper(coalesce(new.tratamiento,''))='ORGANICO' then new.tratamiento:=v_lead_trat; end if;
  else
    select count(*) into v_any_leads from public.aos_leads l where l.numero_limpio=v_num;
    if v_any_leads=0 then
      new.origen:='ORGANICO';
      if upper(coalesce(new.tratamiento,''))<>'ORGANICO' then
        new.anuncio:=coalesce(nullif(new.anuncio,''),nullif(new.tratamiento,''));
        new.tratamiento:='ORGANICO';
      end if;
    else
      new.origen:=coalesce(nullif(new.origen,''),'MARKETING_UNRESOLVED');
    end if;
  end if;
  return new;
end
$function$;

commit;
