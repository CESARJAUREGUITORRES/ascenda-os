-- ASCENDA S15 — bridge the canonical notification projection into the existing app-shell bell.
-- The shell already calls these RPC names; production currently has no implementation.

create or replace function public.aos_list_notificaciones(
  p_id_asesor text,
  p_hoy date default current_date
) returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  uid uuid:=public.aos_notification_resolve_user_v1(p_id_asesor);
  uname text;
  is_admin boolean:=false;
  items jsonb;
  unread_notifs integer:=0;
  unread_msgs integer:=0;
begin
  if uid is not null then
    select nombre,(upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
      into uname,is_admin from public.aos_usuarios where id=uid and activo=true;
  end if;
  if uid is null then
    return jsonb_build_object('ok',true,'unreadNotifs',0,'unreadMsgs',0,'items','[]'::jsonb);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,
    'titulo',x.titulo,
    'cuerpo',x.contenido,
    'tipo',x.tipo,
    'channel',x.channel,
    'event_type',x.event_type,
    'route',x.route,
    'entity_id',x.entity_id,
    'icon',x.icon,
    'fecha',to_char(x.created_at at time zone 'America/Lima','YYYY-MM-DD'),
    'hora',to_char(x.created_at at time zone 'America/Lima','HH24:MI:SS'),
    'tsLeido',case when (x.leido_por ? uname) or (x.leido_por ? p_id_asesor) then x.created_at else null end
  ) order by x.created_at desc),'[]'::jsonb)
  into items
  from (
    select n.*
      from public.aos_notificaciones n
     where n.in_app_enabled=true
       and (n.expira_at is null or n.expira_at>now())
       and (
         n.para_user_id=uid
         or (n.para_user_id is null and n.para is null)
         or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(trim(coalesce(uname,p_id_asesor,''))))
         or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(trim(coalesce(p_id_asesor,''))))
         or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
       )
     order by n.created_at desc
     limit 30
  ) x;

  select count(*) into unread_notifs
    from public.aos_notificaciones n
   where n.in_app_enabled=true
     and (n.expira_at is null or n.expira_at>now())
     and not ((n.leido_por ? uname) or (n.leido_por ? p_id_asesor))
     and (
       n.para_user_id=uid
       or (n.para_user_id is null and n.para is null)
       or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(trim(coalesce(uname,p_id_asesor,''))))
       or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(trim(coalesce(p_id_asesor,''))))
       or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
     );

  select count(*) into unread_msgs
    from public.aos_mensajes m
    join public.aos_canales c on c.id=m.canal
   where coalesce(m.eliminado,false)=false
     and upper(trim(coalesce(m.de,'')))<>upper(trim(coalesce(uname,p_id_asesor,'')))
     and (
       coalesce(c.participantes,'[]'::jsonb) ? coalesce(uname,'')
       or coalesce(c.participantes,'[]'::jsonb) ? coalesce(p_id_asesor,'')
     )
     and not (
       coalesce(m.leido_por,'[]'::jsonb) ? coalesce(uname,'')
       or coalesce(m.leido_por,'[]'::jsonb) ? coalesce(p_id_asesor,'')
     );

  return jsonb_build_object(
    'ok',true,
    'unreadNotifs',coalesce(unread_notifs,0),
    'unreadMsgs',coalesce(unread_msgs,0),
    'items',coalesce(items,'[]'::jsonb)
  );
end;
$$;

create or replace function public.aos_mark_notif_read(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  uid uuid;
  marker text;
  n integer;
begin
  select para_user_id,para into uid,marker from public.aos_notificaciones where id=p_id for update;
  if not found then return jsonb_build_object('ok',false,'error','NOTIFICATION_NOT_FOUND'); end if;
  if uid is not null then
    select nombre into marker from public.aos_usuarios where id=uid;
  end if;
  marker:=coalesce(nullif(trim(marker),''),'BROADCAST');
  update public.aos_notificaciones
     set leido_por=case when coalesce(leido_por,'[]'::jsonb) ? marker then coalesce(leido_por,'[]'::jsonb) else coalesce(leido_por,'[]'::jsonb)||to_jsonb(marker) end,
         updated_at=now()
   where id=p_id;
  get diagnostics n=row_count;
  return jsonb_build_object('ok',n=1,'id',p_id);
end;
$$;

grant execute on function public.aos_list_notificaciones(text,date) to anon,authenticated,service_role;
grant execute on function public.aos_mark_notif_read(uuid) to anon,authenticated,service_role;

comment on function public.aos_list_notificaciones(text,date) is 'S15 compatibility bridge: canonical aos_notificaciones -> app-shell notification bell.';
