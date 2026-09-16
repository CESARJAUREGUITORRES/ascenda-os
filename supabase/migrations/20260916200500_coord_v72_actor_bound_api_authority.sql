begin;

-- COORD-V7.2 — actor-bound lock/search authority behind same-origin F17 API.

create or replace function public.aos_coord_set_channel_lock_actor_v2(
  p_actor_id uuid,
  p_canal text,
  p_locked boolean
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_name text;
  v_level integer;
  v_row record;
begin
  select upper(trim(coalesce(nombre,''))),coalesce(nivel_jerarquia,999)
    into v_name,v_level
  from public.aos_usuarios
  where id=p_actor_id and activo=true
  limit 1;

  if v_name is null then
    return jsonb_build_object('ok',false,'error','ACTOR_NOT_FOUND');
  end if;
  if v_level<>1 then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_SUPERADMIN_ONLY');
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
  values(
    v_name,
    case when v_row.bloqueado then 'coord_channel_locked' else 'coord_channel_unlocked' end,
    jsonb_build_object('channel_id',v_row.id,'channel_name',v_row.nombre,'actor_id',p_actor_id)
  );

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

revoke all on function public.aos_coord_set_channel_lock_actor_v2(uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.aos_coord_set_channel_lock_actor_v2(uuid,text,boolean) to service_role;

create or replace function public.aos_coord_search_messages_actor_v2(
  p_actor_id uuid,
  p_canal text,
  p_query text
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_name text;
  v_level integer;
  v_q text;
  v_allowed boolean:=false;
  v_matches jsonb;
begin
  select upper(trim(coalesce(nombre,''))),coalesce(nivel_jerarquia,999)
    into v_name,v_level
  from public.aos_usuarios
  where id=p_actor_id and activo=true
  limit 1;

  if v_name is null then
    return jsonb_build_object('ok',false,'error','ACTOR_NOT_FOUND');
  end if;

  v_q:=trim(coalesce(p_query,''));
  if length(v_q)<2 then
    return jsonb_build_object('ok',true,'count',0,'matches','[]'::jsonb);
  end if;

  select exists(
    select 1
    from public.aos_canales c
    where c.id=p_canal
      and (
        v_level=1
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

  return jsonb_build_object('ok',true,'count',jsonb_array_length(v_matches),'matches',v_matches);
end
$$;

revoke all on function public.aos_coord_search_messages_actor_v2(uuid,text,text) from public,anon,authenticated;
grant execute on function public.aos_coord_search_messages_actor_v2(uuid,text,text) to service_role;

commit;