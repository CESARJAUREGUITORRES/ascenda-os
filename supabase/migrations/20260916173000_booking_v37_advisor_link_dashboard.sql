begin;
create or replace function public.aos_booking_advisor_link_dashboard_v37(p_user text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare u record; l record; g integer:=0; e integer:=0; code text:=trim(coalesce(p_user,''));
begin
  select id,nombre,rol into u from public.aos_usuarios where activo=true and id::text=code limit 1;
  if not found then return jsonb_build_object('ok',false,'error','USER_NOT_ACTIVE'); end if;
  select * into l from public.aos_links_agenda where asesor_codigo=code and tipo='asesor_permanente' and coalesce(estado,'ACTIVO')='ACTIVO' and (expira_at is null or expira_at>now()) order by created_at desc limit 1;
  if not found then
    return public.aos_booking_advisor_permanent_link_v32(code) || jsonb_build_object('stats',jsonb_build_object('generated',0,'effective',0,'conversion_pct','0%'));
  end if;
  select count(*)::integer,
         count(*) filter(where upper(coalesce(c.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))::integer
    into g,e
  from public.aos_agenda_citas c
  where c.source_channel='ADVISOR_LINK'
    and (c.source_link_token=l.token or c.id_asesor=code or c.asesor=code);
  return jsonb_build_object('ok',true,'token',l.token,'advisor_code',code,'advisor_name',u.nombre,'source_channel','ADVISOR_LINK','stats',jsonb_build_object('generated',g,'effective',e,'conversion_pct',case when g>0 then trim(to_char(round(100.0*e/g,1),'FM999990D0'))||'%' else '0%' end));
end $$;
revoke all on function public.aos_booking_advisor_link_dashboard_v37(text) from public;
grant execute on function public.aos_booking_advisor_link_dashboard_v37(text) to anon,authenticated,service_role;
commit;