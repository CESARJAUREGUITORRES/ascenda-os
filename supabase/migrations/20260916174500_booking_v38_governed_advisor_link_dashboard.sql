begin;
create or replace function public.aos_booking_advisor_link_dashboard_v38(p_token text)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  auth jsonb;
  uid text;
  u record;
  l record;
  g integer:=0;
  e integer:=0;
  p integer:=0;
begin
  auth:=public.aos_cia_verify_app_session_v1(p_token);
  if coalesce((auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=auth->>'user_id';
  select id,nombre,rol into u from public.aos_usuarios where activo=true and id::text=uid limit 1;
  if not found then return jsonb_build_object('ok',false,'error','USER_NOT_ACTIVE'); end if;

  select * into l
  from public.aos_links_agenda
  where asesor_codigo=uid
    and tipo='asesor_permanente'
    and coalesce(estado,'ACTIVO')='ACTIVO'
    and (expira_at is null or expira_at>now())
  order by created_at desc
  limit 1;

  if not found then
    perform public.aos_booking_advisor_permanent_link_v32(uid);
    select * into l
    from public.aos_links_agenda
    where asesor_codigo=uid
      and tipo='asesor_permanente'
      and coalesce(estado,'ACTIVO')='ACTIVO'
      and (expira_at is null or expira_at>now())
    order by created_at desc
    limit 1;
  end if;

  if not found then return jsonb_build_object('ok',false,'error','LINK_UNAVAILABLE'); end if;

  select count(*)::integer,
         count(*) filter(where upper(coalesce(c.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))::integer,
         count(*) filter(where upper(coalesce(c.estado_cita,'')) not in ('ASISTIO','ASISTIÓ','EFECTIVA','CANCELADA','NO ASISTIO','NO ASISTIÓ'))::integer
    into g,e,p
  from public.aos_agenda_citas c
  where c.source_channel='ADVISOR_LINK'
    and c.source_link_token=l.token;

  return jsonb_build_object(
    'ok',true,
    'token',l.token,
    'advisor_code',uid,
    'advisor_name',u.nombre,
    'user_role',u.rol,
    'source_channel','ADVISOR_LINK',
    'stats',jsonb_build_object(
      'generated',g,
      'effective',e,
      'pending',p,
      'conversion_pct',case when g>0 then trim(to_char(round(100.0*e/g,1),'FM999990D0'))||'%' else '0%' end
    )
  );
end
$$;
revoke all on function public.aos_booking_advisor_link_dashboard_v38(text) from public;
grant execute on function public.aos_booking_advisor_link_dashboard_v38(text) to anon,authenticated,service_role;
commit;