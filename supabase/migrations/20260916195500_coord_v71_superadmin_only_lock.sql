begin;

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
  v_uid uuid;
  v_name text;
  v_level integer;
  v_row record;
begin
  v_auth:=public.aos_cia_verify_app_session_v1(p_token);
  if coalesce((v_auth->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  begin v_uid:=(v_auth->>'user_id')::uuid; exception when others then v_uid:=null; end;
  select upper(trim(coalesce(nombre,''))),coalesce(nivel_jerarquia,999)
    into v_name,v_level
  from public.aos_usuarios
  where id=v_uid and activo=true
  limit 1;

  if v_uid is null or v_level<>1 then
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

commit;