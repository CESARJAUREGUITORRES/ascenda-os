-- HOTFIX-3: correct recovery semantics for Call Center.
-- Prior NO ASISTIO/CANCELADA alone does not make a lead non-commercial.
-- Only proven patient continuity (sale/clinical attention/assisted appointment/explicit session-control text) is excluded.

create or replace function public.aos_hotfix_call_guard_v1()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $$
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
end $$;

insert into public.aos_llamadas
select (jsonb_populate_record(null::public.aos_llamadas,g.call_payload)).*
from public.aos_gestiones_no_comerciales g
where g.source_call_id in (37045,37060)
on conflict (id) do nothing;

update public.aos_agenda_citas
set origen_cita='CALL_CENTER',origen='MARKETING',lead_id_origen=5000,llamada_id_origen=37045
where id='2fd19466-246f-4daa-9e57-f0f0c3d9c394';

update public.aos_agenda_citas
set origen_cita='CALL_CENTER',origen='MARKETING',lead_id_origen=4003,llamada_id_origen=37060
where id='5a04bdf0-1456-48de-8d87-69ca1f261cb0';

update public.aos_gestiones_no_comerciales
set clasificacion='RESTORED_VALID_RECOVERY',
    motivo='Corrección HOTFIX-3: lead/prospecto sin conversión clínica previa; recuperación comercial válida aunque existiera NO ASISTIO/CANCELADA.',
    source='HOTFIX3_VALID_RECOVERY'
where source_call_id in (37045,37060);
