begin;

alter table public.aos_canales
  add column if not exists bloqueado boolean not null default false,
  add column if not exists bloqueado_por text null,
  add column if not exists bloqueado_at timestamptz null;

comment on column public.aos_canales.bloqueado is
'When true, human messages/files are blocked and only CITA_AUTO operational reports may be inserted.';

create or replace function public.aos_coord_set_channel_lock_v1(
  p_token text,
  p_canal text,
  p_locked boolean
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_auth jsonb;
  v_name text;
  v_role text;
  v_row record;
begin
  v_auth:=public.aos_cia_verify_app_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_name:=upper(trim(coalesce(v_auth->>'nombre','')));
  v_role:=upper(trim(coalesce(v_auth->>'rol','')));

  if v_role <> 'ADMIN' then
    return jsonb_build_object('ok',false,'error','FORBIDDEN');
  end if;

  update public.aos_canales
  set bloqueado=coalesce(p_locked,false),
      bloqueado_por=case when coalesce(p_locked,false) then v_name else null end,
      bloqueado_at=case when coalesce(p_locked,false) then now() else null end,
      updated_at=now()
  where id=p_canal
  returning id,nombre,bloqueado,bloqueado_por,bloqueado_at into v_row;

  if v_row.id is null then
    return jsonb_build_object('ok',false,'error','CHANNEL_NOT_FOUND');
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_name,
         case when v_row.bloqueado then 'coord_channel_locked' else 'coord_channel_unlocked' end,
         jsonb_build_object('channel_id',v_row.id,'channel_name',v_row.nombre));

  return jsonb_build_object(
    'ok',true,
    'channel_id',v_row.id,
    'channel_name',v_row.nombre,
    'locked',v_row.bloqueado,
    'locked_by',v_row.bloqueado_por,
    'locked_at',v_row.bloqueado_at
  );
end
$$;

revoke all on function public.aos_coord_set_channel_lock_v1(text,text,boolean) from public;
grant execute on function public.aos_coord_set_channel_lock_v1(text,text,boolean) to anon,authenticated,service_role;

create or replace function public.aos_coord_search_messages_v1(
  p_token text,
  p_canal text,
  p_query text
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_auth jsonb;
  v_name text;
  v_role text;
  v_q text;
  v_allowed boolean:=false;
  v_matches jsonb;
begin
  v_auth:=public.aos_cia_verify_app_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_name:=upper(trim(coalesce(v_auth->>'nombre','')));
  v_role:=upper(trim(coalesce(v_auth->>'rol','')));
  v_q:=trim(coalesce(p_query,''));

  if length(v_q)<2 then
    return jsonb_build_object('ok',true,'count',0,'matches','[]'::jsonb);
  end if;

  select exists(
    select 1
    from public.aos_canales c
    where c.id=p_canal
      and (
        v_role='ADMIN'
        or c.participantes ? v_name
      )
  ) into v_allowed;

  if not v_allowed then
    return jsonb_build_object('ok',false,'error','FORBIDDEN');
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
  into v_matches
  from (
    select m.id,m.canal,m.de,m.tipo,m.mensaje,m.created_at
    from public.aos_mensajes m
    where m.canal=p_canal
      and coalesce(m.eliminado,false)=false
      and (
        coalesce(m.mensaje,'') ilike '%'||v_q||'%'
        or coalesce(m.de,'') ilike '%'||v_q||'%'
      )
    order by m.created_at desc
    limit 100
  ) x;

  return jsonb_build_object(
    'ok',true,
    'count',jsonb_array_length(v_matches),
    'matches',v_matches
  );
end
$$;

revoke all on function public.aos_coord_search_messages_v1(text,text,text) from public;
grant execute on function public.aos_coord_search_messages_v1(text,text,text) to anon,authenticated,service_role;

create or replace function public.aos_enviar_mensaje(
  p_canal text,
  p_de text,
  p_para text default null::text,
  p_mensaje text default ''::text,
  p_tipo text default 'MENSAJE'::text
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_id uuid;
  v_locked boolean:=false;
begin
  select coalesce(c.bloqueado,false)
    into v_locked
  from public.aos_canales c
  where c.id=p_canal
  limit 1;

  if coalesce(v_locked,false) and upper(coalesce(p_tipo,'MENSAJE')) <> 'CITA_AUTO' then
    return jsonb_build_object('ok',false,'error','CHANNEL_LOCKED');
  end if;

  insert into public.aos_mensajes(canal,de,para,mensaje,tipo)
  values(p_canal,p_de,p_para,p_mensaje,p_tipo)
  returning id into v_id;

  update public.aos_canales
  set ultimo_mensaje=left(p_mensaje,100),
      ultimo_mensaje_at=now(),
      updated_at=now()
  where id=p_canal;

  return jsonb_build_object('ok',true,'id',v_id);
end
$$;

revoke all on function public.aos_enviar_mensaje(text,text,text,text,text) from public;
grant execute on function public.aos_enviar_mensaje(text,text,text,text,text) to anon,authenticated,service_role;

create or replace function public.aos_coord_message_lock_guard_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_channel text;
  v_locked boolean:=false;
begin
  v_channel:=case when tg_op='DELETE' then old.canal else new.canal end;

  select coalesce(c.bloqueado,false)
    into v_locked
  from public.aos_canales c
  where c.id=v_channel
  limit 1;

  if not coalesce(v_locked,false) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  if tg_op='INSERT' then
    if upper(coalesce(new.tipo,'MENSAJE'))='CITA_AUTO' then return new; end if;
    raise exception 'CHANNEL_LOCKED' using errcode='P0001';
  elsif tg_op='UPDATE' then
    if new.mensaje is distinct from old.mensaje
       or new.eliminado is distinct from old.eliminado
       or new.archivo_id is distinct from old.archivo_id
       or new.tipo is distinct from old.tipo
       or new.tipo_contenido is distinct from old.tipo_contenido then
      raise exception 'CHANNEL_LOCKED' using errcode='P0001';
    end if;
    return new;
  elsif tg_op='DELETE' then
    raise exception 'CHANNEL_LOCKED' using errcode='P0001';
  end if;

  return new;
end
$$;

drop trigger if exists trg_aos_coord_message_lock_guard_v1 on public.aos_mensajes;
create trigger trg_aos_coord_message_lock_guard_v1
before insert or update or delete on public.aos_mensajes
for each row execute function public.aos_coord_message_lock_guard_v1();

create or replace function public.aos_mis_mensajes(p_usuario text)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_result jsonb;
  uid uuid:=public.aos_notification_resolve_user_v1(p_usuario);
  is_admin boolean:=false;
begin
  if uid is not null then
    select (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
      into is_admin
    from public.aos_usuarios
    where id=uid;
  end if;

  select jsonb_build_object(
    'canales',(select coalesce(jsonb_agg(row_to_json(c) order by c.ultimo_mensaje_at desc nulls last),'[]'::jsonb) from (
      select ch.id,ch.nombre,ch.tipo,ch.ultimo_mensaje,ch.ultimo_mensaje_at,ch.cerrado,ch.participantes,
             ch.bloqueado,ch.bloqueado_por,ch.bloqueado_at,
        (select count(*) from public.aos_mensajes m where m.canal=ch.id and not (m.leido_por ? p_usuario) and m.de<>p_usuario) as no_leidos
      from public.aos_canales ch
      where (ch.participantes ? p_usuario)
        and (ch.cerrado=false or ch.cerrado is null)
    ) c),
    'grupos',(select coalesce(jsonb_agg(row_to_json(g)),'[]'::jsonb) from (
      select g.id,g.nombre,g.color,g.tipo,jsonb_array_length(g.miembros) as n_miembros
      from public.aos_grupos g
      where g.activo=true and g.miembros ? p_usuario
    ) g),
    'tareas',(select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) from (
      select id,titulo,estado,prioridad,items,fecha_limite,vencida,tiempo_estimado_min,asignado_grupo,created_at
      from public.aos_tareas
      where (asignado_a=p_usuario or asignado_grupo in (select g.id from public.aos_grupos g where g.miembros ? p_usuario))
        and estado<>'COMPLETADA'
      order by case when vencida then 0 else 1 end,
               case prioridad when 'URGENTE' then 0 when 'ALTA' then 1 else 2 end,
               fecha_limite asc nulls last
    ) t),
    'notificaciones',(select coalesce(jsonb_agg(row_to_json(n) order by n.created_at desc),'[]'::jsonb) from (
      select n.id,n.titulo,n.contenido,n.tipo,n.prioridad,n.created_at,n.channel,n.event_type,n.route,n.entity_id,n.icon,
             (n.leido_por ? p_usuario) as leido
      from public.aos_notificaciones n
      where n.in_app_enabled=true
        and (n.expira_at is null or n.expira_at>now())
        and (
          n.para_user_id=uid
          or (n.para_user_id is null and n.para is null)
          or (n.para_user_id is null and upper(coalesce(n.para,''))=upper(p_usuario))
          or (n.para_user_id is null and upper(coalesce(n.para,''))='ADMIN' and is_admin)
        )
      order by n.created_at desc
      limit 30
    ) n)
  ) into v_result;

  return v_result;
end
$$;

commit;