-- BOOKING-V3.5 — canonical WEB/EMAIL channels + advisor-link/web monitoring.
begin;

create unique index if not exists aos_links_agenda_channel_permanent_uq
on public.aos_links_agenda(source_channel)
where tipo='channel_permanent' and coalesce(estado,'ACTIVO')='ACTIVO';

create or replace function public.aos_booking_channel_permanent_link_v35(p_channel text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare l record; ch text:=upper(trim(coalesce(p_channel,'')));
begin
 if ch not in ('WEB','EMAIL') then return jsonb_build_object('ok',false,'error','CHANNEL_NOT_ALLOWED'); end if;
 select * into l from public.aos_links_agenda where tipo='channel_permanent' and upper(coalesce(source_channel,''))=ch and coalesce(estado,'ACTIVO')='ACTIVO' limit 1;
 if not found then
   insert into public.aos_links_agenda(tipo,asesor_codigo,expira_at,source_channel,estado,campaign_code,campaign_name)
   values('channel_permanent',null,now()+interval '10 years',ch,'ACTIVO',null,case when ch='WEB' then 'ASCENDA_CLINIC_WEB' else 'ASCENDA_EMAIL_MARKETING' end)
   returning * into l;
 end if;
 return jsonb_build_object('ok',true,'token',l.token,'source_channel',ch,'advisor_code',null,'link_type',l.tipo);
end $$;
revoke all on function public.aos_booking_channel_permanent_link_v35(text) from public;
grant execute on function public.aos_booking_channel_permanent_link_v35(text) to authenticated,service_role;

create or replace function public.aos_booking_attribution_v1(p_token text)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare l record; ch text; camp text;
begin
 if coalesce(trim(p_token),'') in ('','__permanent__') then return jsonb_build_object('source_channel','WEB','source_campaign',null,'advisor_code','ORGANICO','link_type','permanent'); end if;
 select * into l from public.aos_links_agenda where token=p_token and (expira_at is null or expira_at>now()) and coalesce(estado,'ACTIVO')='ACTIVO';
 if not found then return jsonb_build_object('source_channel','UNKNOWN','advisor_code','ORGANICO'); end if;
 ch:=upper(coalesce(nullif(trim(l.source_channel),''),case when lower(coalesce(l.tipo,'')) in ('asesor','asesor_permanente','paciente_especifico') then 'ADVISOR_LINK' else 'LINK' end));
 camp:=nullif(coalesce(nullif(trim(l.campaign_code),''),nullif(trim(l.campaign_name),'')),'');
 return jsonb_build_object('source_channel',ch,'source_campaign',camp,'advisor_code',case when l.asesor_codigo is null then 'ORGANICO' else trim(l.asesor_codigo) end,'link_type',l.tipo);
end $$;
revoke all on function public.aos_booking_attribution_v1(text) from public;
grant execute on function public.aos_booking_attribution_v1(text) to anon,authenticated,service_role;

select public.aos_booking_channel_permanent_link_v35('WEB');
select public.aos_booking_channel_permanent_link_v35('EMAIL');

-- Monitoring RPC now exposes citas_web and link_personal while preserving the existing score columns.
drop function if exists public.aos_monitoreo_equipo(date);
create function public.aos_monitoreo_equipo(p_hoy date default current_date)
returns table(nombre text,llamadas bigint,citas bigint,reactivadas bigint,agenda_directa bigint,citas_web bigint,link_personal bigint,conv_pct integer,ult_num text,ult_hora text,mins_sin integer)
language plpgsql as $$
begin
 return query
 with roster as (
   select upper(trim(l.asesor)) asesor from public.aos_llamadas l where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null
   union select upper(trim(a.asesor)) from public.aos_agenda_citas a where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy and nullif(trim(a.asesor),'') is not null
   union select 'WEB' where exists(select 1 from public.aos_agenda_citas a where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy and upper(coalesce(a.source_channel,''))='WEB' and nullif(trim(a.id_asesor),'') is null)
 ), ca as (
   select upper(trim(l.asesor)) asesor,count(*)::bigint llamadas from public.aos_llamadas l where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null group by 1
 ), aa as (
   select case when upper(coalesce(a.source_channel,''))='WEB' and nullif(trim(a.id_asesor),'') is null then 'WEB' else upper(trim(a.asesor)) end asesor,
     count(*) filter(where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='CITA' and upper(coalesce(a.source_channel,'')) not in ('WEB','ADVISOR_LINK'))::bigint citas,
     count(*) filter(where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='REACTIVADA')::bigint reactivadas,
     count(*) filter(where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='AGENDA_DIRECTA')::bigint agenda_directa,
     count(*) filter(where upper(coalesce(a.source_channel,'')) in ('WEB','ADVISOR_LINK'))::bigint citas_web,
     count(*) filter(where upper(coalesce(a.source_channel,''))='ADVISOR_LINK')::bigint link_personal
   from public.aos_agenda_citas a left join public.aos_llamadas l on l.id=a.llamada_id_origen
   where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy
     and (nullif(trim(a.asesor),'') is not null or upper(coalesce(a.source_channel,''))='WEB') group by 1
 )
 select r.asesor,coalesce(ca.llamadas,0),coalesce(aa.citas,0),coalesce(aa.reactivadas,0),coalesce(aa.agenda_directa,0),coalesce(aa.citas_web,0),coalesce(aa.link_personal,0),
   case when coalesce(ca.llamadas,0)>0 then round(coalesce(aa.citas,0)::numeric*100/coalesce(ca.llamadas,0))::integer else 0 end,
   (select l2.numero_limpio from public.aos_llamadas l2 where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1),
   (select l2.hora_llamada from public.aos_llamadas l2 where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1),
   case when (select l2.hora_llamada from public.aos_llamadas l2 where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1) is not null then (extract(epoch from (now() at time zone 'America/Lima'-(p_hoy::timestamp+(select l2.hora_llamada::time from public.aos_llamadas l2 where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1))))::integer/60) else null end
 from roster r left join ca on ca.asesor=r.asesor left join aa on aa.asesor=r.asesor
 order by coalesce(ca.llamadas,0) desc,(coalesce(aa.citas,0)+coalesce(aa.reactivadas,0)+coalesce(aa.agenda_directa,0)+coalesce(aa.citas_web,0)) desc,r.asesor;
end $$;
grant execute on function public.aos_monitoreo_equipo(date) to anon,authenticated,service_role;
commit;
