-- ASCENDA S15.1 — notification authorization boundary, stage 1.
-- Browser identity parameters are no longer trusted for the new S15 notification readers.
-- This migration is additive/compatible: it creates server-only actor RPCs but intentionally
-- leaves legacy notification readers available until S15.2 is live and certified.

create or replace function public.aos_notification_inbox_actor_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  uid uuid;
  uname text;
  is_admin boolean:=false;
  lim integer:=least(100,greatest(1,coalesce((p_payload->>'limit')::integer,50)));
  rows jsonb;
  unread_notifs integer:=0;
  unread_msgs integer:=0;
begin
  begin uid:=(p_payload->>'actor_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTOR_ID'); end;
  select nombre,(upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
    into uname,is_admin
    from public.aos_usuarios
   where id=uid and activo=true;
  if uname is null then return jsonb_build_object('ok',false,'error','ACTIVE_ACTOR_REQUIRED'); end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,
    'titulo',x.titulo,
    'contenido',x.contenido,
    'cuerpo',x.contenido,
    'tipo',x.tipo,
    'prioridad',x.prioridad,
    'channel',x.channel,
    'event_type',x.event_type,
    'route',x.route,
    'entity_id',x.entity_id,
    'icon',x.icon,
    'created_at',x.created_at,
    'fecha',to_char(x.created_at at time zone 'America/Lima','YYYY-MM-DD'),
    'hora',to_char(x.created_at at time zone 'America/Lima','HH24:MI:SS'),
    'leido',(x.leido_por ? uname),
    'tsLeido',case when x.leido_por ? uname then x.created_at else null end
  ) order by x.created_at desc),'[]'::jsonb)
  into rows
  from (
    select n.*
      from public.aos_notificaciones n
     where n.in_app_enabled=true
       and (n.expira_at is null or n.expira_at>now())
       and (
         n.para_user_id=uid
         or (n.para_user_id is null and n.para is null)
         or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(uname))
         or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
       )
     order by n.created_at desc
     limit lim
  ) x;

  select count(*) into unread_notifs
    from public.aos_notificaciones n
   where n.in_app_enabled=true
     and (n.expira_at is null or n.expira_at>now())
     and not (n.leido_por ? uname)
     and (
       n.para_user_id=uid
       or (n.para_user_id is null and n.para is null)
       or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(uname))
       or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
     );

  select count(*) into unread_msgs
    from public.aos_mensajes m
    join public.aos_canales c on c.id=m.canal
   where coalesce(m.eliminado,false)=false
     and upper(trim(coalesce(m.de,'')))<>upper(uname)
     and coalesce(c.participantes,'[]'::jsonb) ? uname
     and not (coalesce(m.leido_por,'[]'::jsonb) ? uname);

  return jsonb_build_object(
    'ok',true,
    'actor_id',uid,
    'actor_name',uname,
    'is_admin',is_admin,
    'unreadNotifs',coalesce(unread_notifs,0),
    'unreadMsgs',coalesce(unread_msgs,0),
    'items',coalesce(rows,'[]'::jsonb),
    'rows',coalesce(rows,'[]'::jsonb)
  );
end;
$$;

create or replace function public.aos_notification_mark_read_actor_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  uid uuid;
  nid uuid;
  uname text;
  is_admin boolean:=false;
  allowed boolean:=false;
  n integer:=0;
begin
  begin
    uid:=(p_payload->>'actor_id')::uuid;
    nid:=(p_payload->>'notification_id')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_IDS');
  end;

  select nombre,(upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
    into uname,is_admin
    from public.aos_usuarios
   where id=uid and activo=true;
  if uname is null then return jsonb_build_object('ok',false,'error','ACTIVE_ACTOR_REQUIRED'); end if;

  select exists(
    select 1 from public.aos_notificaciones x
     where x.id=nid
       and x.in_app_enabled=true
       and (x.expira_at is null or x.expira_at>now())
       and (
         x.para_user_id=uid
         or (x.para_user_id is null and x.para is null)
         or (x.para_user_id is null and upper(coalesce(x.para,''))=upper(uname))
         or (x.para_user_id is null and upper(coalesce(x.para,''))='ADMIN' and is_admin)
       )
  ) into allowed;
  if not allowed then return jsonb_build_object('ok',false,'error','NOTIFICATION_NOT_VISIBLE_TO_ACTOR'); end if;

  update public.aos_notificaciones
     set leido_por=case when coalesce(leido_por,'[]'::jsonb) ? uname then coalesce(leido_por,'[]'::jsonb) else coalesce(leido_por,'[]'::jsonb)||to_jsonb(uname) end,
         updated_at=now()
   where id=nid;
  get diagnostics n=row_count;
  return jsonb_build_object('ok',n=1,'id',nid,'actor_id',uid);
end;
$$;

-- New actor-bound functions are server-only from the moment they exist.
revoke all on function public.aos_notification_inbox_actor_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_notification_mark_read_actor_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_notification_inbox_actor_v1(jsonb) to service_role;
grant execute on function public.aos_notification_mark_read_actor_v1(jsonb) to service_role;

-- IMPORTANT: legacy reader revocation is intentionally deferred until S15.2 Railway smoke passes.
-- See supabase/pending/s15_notification_legacy_acl_cutover_after_s15_2.sql.

comment on function public.aos_notification_inbox_actor_v1(jsonb) is 'S15.1 server-only notification inbox bound to verified ASCENDA actor UUID.';
comment on function public.aos_notification_mark_read_actor_v1(jsonb) is 'S15.1 server-only read marker enforcing notification visibility for verified actor.';