create table if not exists public.aos_gestiones_no_comerciales (
  id bigserial primary key,
  source_call_id bigint unique,
  archived_at timestamptz not null default now(),
  clasificacion text not null,
  motivo text,
  asesor text,
  numero_limpio text,
  fecha date,
  lead_id_origen bigint,
  call_payload jsonb not null,
  agenda_ids jsonb,
  source text not null default 'HOTFIX-2'
);
create index if not exists idx_aos_gnc_num_fecha on public.aos_gestiones_no_comerciales(numero_limpio,fecha);

create or replace function public.aos_hotfix_call_guard_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_num text; v_call_ts timestamptz; v_eff_trat text;
  v_prior_count integer:=0; v_match_count integer:=0; v_any_leads integer:=0;
  v_lead_id bigint; v_lead_trat text; v_lead_anuncio text;
  v_noncommercial text; v_reason text;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
  new.numero_limpio:=v_num;
  if upper(trim(coalesce(new.estado,'')))<>'CITA CONFIRMADA' or v_num='' then return new; end if;
  v_call_ts:=public.aos_llamada_event_ts(coalesce(new.fecha,current_date),new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);

  if exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<coalesce(new.fecha,current_date))
     or exists(select 1 from public.aos_atenciones a where a.numero_limpio=v_num and a.fecha<coalesce(new.fecha,current_date))
     or exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and a.fecha_cita<coalesce(new.fecha,current_date) and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))
     or upper(coalesce(new.observacion,'')) ~ '(ANTIGU|SESION|SESIÓN|CONTROL|DEUDA|APLICACION|APLICACIÓN)'
  then
      v_noncommercial:='PACIENTE_CONTINUIDAD';
      v_reason:='Paciente/continuidad: evidencia clínica, venta, asistencia o texto operativo previo.';
  elsif exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and a.fecha_cita<coalesce(new.fecha,current_date) and upper(coalesce(a.estado_cita,'')) in ('NO ASISTIO','NO ASISTIÓ','CANCELADA')) then
      v_noncommercial:='REAGENDA_NO_COMERCIAL';
      v_reason:='Reagenda: existía cita previa vencida/no asistida/cancelada; no es nueva conversión.';
  end if;

  if v_noncommercial is not null then
    insert into public.aos_gestiones_no_comerciales(source_call_id,clasificacion,motivo,asesor,numero_limpio,fecha,lead_id_origen,call_payload,agenda_ids,source)
    values(new.id,v_noncommercial,v_reason,new.asesor,v_num,coalesce(new.fecha,current_date),new.lead_id_origen,to_jsonb(new),null,'CALL_GUARD_V2')
    on conflict(source_call_id) do nothing;
    return null;
  end if;

  if exists(select 1 from public.aos_llamadas l where l.numero_limpio=v_num and l.fecha=coalesce(new.fecha,current_date) and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(l.estado,''))='CITA CONFIRMADA') then
    new.estado:='SEGUIMIENTO'; new.sub_estado:='CITA YA EXISTENTE'; new.origen:=coalesce(nullif(new.origen,''),'FOLLOWUP_EXISTING_CITA');
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
    new.lead_id_origen:=v_lead_id; new.origen:='MARKETING'; new.anuncio:=coalesce(nullif(new.anuncio,''),v_lead_anuncio);
    if nullif(trim(coalesce(new.tratamiento,'')),'') is null or upper(coalesce(new.tratamiento,''))='ORGANICO' then new.tratamiento:=v_lead_trat; end if;
  else
    select count(*) into v_any_leads from public.aos_leads l where l.numero_limpio=v_num;
    if v_any_leads=0 then
      new.origen:='ORGANICO'; if upper(coalesce(new.tratamiento,''))<>'ORGANICO' then new.anuncio:=coalesce(nullif(new.anuncio,''),nullif(new.tratamiento,'')); new.tratamiento:='ORGANICO'; end if;
    else new.origen:=coalesce(nullif(new.origen,''),'MARKETING_UNRESOLVED'); end if;
  end if;
  return new;
end $$;

create or replace function public.aos_hotfix_reconcile_late_lead_agenda_only_v2()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_num text; v_lead_ts timestamptz; v_day date; v_same_day integer;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.celular,''),'[^0-9]','','g');
  if v_num='' or new.fecha is null then return new; end if;
  v_day:=new.fecha; v_lead_ts:=public.aos_lead_event_ts(new.fecha,new.hora_ingreso,new.created_at);
  select count(*) into v_same_day from public.aos_leads l where l.numero_limpio=v_num and l.fecha=v_day;
  if v_same_day<>1 then return new; end if;
  update public.aos_agenda_citas a
     set lead_id_origen=new.id,
         origen=case when nullif(trim(coalesce(a.origen,'')),'') is null then 'MARKETING' else a.origen end,
         etiqueta_campana=coalesce(nullif(a.etiqueta_campana,''),nullif(new.tratamiento,''))
   where a.numero_limpio=v_num and a.lead_id_origen is null
     and upper(coalesce(a.origen_cita,'')) in ('AGENDA','CITA_MANUAL')
     and a.ts_creado is not null and a.ts_creado<v_lead_ts and v_lead_ts<=a.ts_creado+interval '12 hours'
     and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=v_num and abs(extract(epoch from (public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-a.ts_creado)))<=600)
     and not exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<(a.ts_creado at time zone 'America/Lima')::date)
     and not exists(select 1 from public.aos_atenciones at where at.numero_limpio=v_num and at.fecha<(a.ts_creado at time zone 'America/Lima')::date)
     and not exists(select 1 from public.aos_agenda_citas p where p.numero_limpio=v_num and p.fecha_cita<(a.ts_creado at time zone 'America/Lima')::date and upper(coalesce(p.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'));
  return new;
end $$;

drop trigger if exists trg_aos_hotfix_reconcile_late_lead_agenda_only_v2 on public.aos_leads;
create trigger trg_aos_hotfix_reconcile_late_lead_agenda_only_v2 after insert on public.aos_leads for each row execute function public.aos_hotfix_reconcile_late_lead_agenda_only_v2();

insert into public.aos_gestiones_no_comerciales(source_call_id,clasificacion,motivo,asesor,numero_limpio,fecha,lead_id_origen,call_payload,agenda_ids,source)
select l.id,
 case when l.id in (36962,37045,37060) then 'REAGENDA_NO_COMERCIAL' else 'PACIENTE_CONTINUIDAD' end,
 case when l.id in (36962,37045,37060) then 'Wilmer 2026-08-18: reagenda/lead con cita previa; conservar Agenda, excluir KPIs comerciales.' else 'Wilmer 2026-08-18: paciente/continuidad; conservar Agenda, excluir KPIs comerciales.' end,
 l.asesor,l.numero_limpio,l.fecha,l.lead_id_origen,to_jsonb(l),
 (select coalesce(jsonb_agg(a.id order by a.ts_creado),'[]'::jsonb)
    from public.aos_agenda_citas a
   where a.numero_limpio=l.numero_limpio and upper(coalesce(a.asesor,''))='WILMER'
     and abs(extract(epoch from (coalesce(a.ts_creado,a.fecha_cita::timestamptz)-public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log))))<=600),
 'WILMER_HOTFIX2'
from public.aos_llamadas l where l.id in (36918,36934,36937,36962,36965,36966,36967,36969,36988,37005,37045,37060)
on conflict(source_call_id) do nothing;

update public.aos_agenda_citas set origen_cita='CONTINUIDAD'
where id in ('8a88edc2-30f5-43e1-a05d-86ebe98ff532','4d164241-0b61-4d27-85e0-97226891efbd','734a6e93-3441-4dca-a542-9ad9f282a8a9','1cbc5dfd-fdfa-42fa-80f9-5c4da1344a7a','b6e194f5-6389-4dc5-bc87-9e44b86d326e','781b31cd-cab1-4b3f-9bf0-d6410c01a078','ecbaad35-b24b-4b5a-940d-18c72e05cad1','d794efb3-b586-46f6-b144-62793d748783','c2710e09-9847-4eb8-a754-258ae0df7a15');
update public.aos_agenda_citas set origen_cita='REAGENDADA'
where id in ('10c9dc32-a04c-4526-a0b3-ad4bceaf061b','2fd19466-246f-4daa-9e57-f0f0c3d9c394','5a04bdf0-1456-48de-8d87-69ca1f261cb0');
update public.aos_agenda_citas set lead_id_origen=5000,origen='MARKETING',etiqueta_campana=coalesce(nullif(etiqueta_campana,''),'CAPILAR') where id='2fd19466-246f-4daa-9e57-f0f0c3d9c394';
update public.aos_agenda_citas set lead_id_origen=4003,origen='MARKETING',etiqueta_campana=coalesce(nullif(etiqueta_campana,''),'ENZIMAS FACIALES') where id='5a04bdf0-1456-48de-8d87-69ca1f261cb0';
update public.aos_agenda_citas set lead_id_origen=4610,origen='MARKETING',etiqueta_campana=coalesce(nullif(etiqueta_campana,''),'ENZIMAS FACIALES') where id='795b954c-8b01-454a-b669-bc3a09b92747' and lead_id_origen is null;

delete from public.aos_llamadas where id in (36918,36934,36937,36962,36965,36966,36967,36969,36988,37005,37045,37060);
