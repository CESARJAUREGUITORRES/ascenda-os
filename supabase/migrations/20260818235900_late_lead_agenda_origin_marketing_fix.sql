create or replace function public.aos_hotfix_reconcile_late_lead_agenda_only_v2()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_num text; v_lead_ts timestamptz; v_day date; v_same_day integer;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.celular,''),'[^0-9]','','g');
  if v_num='' or new.fecha is null then return new; end if;
  v_day:=new.fecha;
  v_lead_ts:=public.aos_lead_event_ts(new.fecha,new.hora_ingreso,new.created_at);
  select count(*) into v_same_day from public.aos_leads l where l.numero_limpio=v_num and l.fecha=v_day;
  if v_same_day<>1 then return new; end if;

  update public.aos_agenda_citas a
     set lead_id_origen=new.id,
         origen='MARKETING',
         etiqueta_campana=coalesce(nullif(a.etiqueta_campana,''),nullif(new.tratamiento,''))
   where a.numero_limpio=v_num
     and a.lead_id_origen is null
     and upper(coalesce(a.origen_cita,'')) in ('AGENDA','CITA_MANUAL')
     and a.ts_creado is not null
     and a.ts_creado<v_lead_ts
     and v_lead_ts<=a.ts_creado+interval '12 hours'
     and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=v_num and abs(extract(epoch from (public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-a.ts_creado)))<=600)
     and not exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<(a.ts_creado at time zone 'America/Lima')::date)
     and not exists(select 1 from public.aos_atenciones at where at.numero_limpio=v_num and at.fecha<(a.ts_creado at time zone 'America/Lima')::date)
     and not exists(select 1 from public.aos_agenda_citas p where p.numero_limpio=v_num and p.fecha_cita<(a.ts_creado at time zone 'America/Lima')::date and upper(coalesce(p.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'));
  return new;
end $$;
