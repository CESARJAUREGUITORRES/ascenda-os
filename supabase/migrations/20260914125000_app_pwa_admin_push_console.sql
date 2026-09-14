-- ASCENDA APP-PWA — admin Push operations console.
-- Read-only fleet health + governed diagnostic Push target resolution.

begin;

update public.aos_paneles_disponibles
set categoria='admin',
    descripcion='Centro administrativo de dispositivos, salud Push y pruebas controladas del equipo.'
where id='devices-notifications';

update public.aos_usuarios
set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'devices-notifications'),
    updated_at=now()
where activo=true
  and not (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
  and 'devices-notifications'=any(coalesce(paneles_acceso,'{}'::text[]));

create or replace function public.aos_push_admin_overview_v1(p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_actor uuid;
  v_users jsonb;
begin
  begin v_actor := nullif(p_payload->>'actor_id','')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','INVALID_ACTOR_ID'); end;

  if not exists(
    select 1 from public.aos_usuarios u
    where u.id=v_actor and u.activo=true
      and (upper(coalesce(u.rol,''))='ADMIN' or coalesce(u.nivel_jerarquia,999)=1)
  ) then
    return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',u.id,
    'nombre',u.nombre,
    'codigo_asesor',u.codigo_asesor,
    'rol',u.rol,
    'nivel_jerarquia',u.nivel_jerarquia,
    'devices',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',d.id,
        'device_name',d.device_name,
        'os_family',d.os_family,
        'form_factor',d.form_factor,
        'runtime_surface',d.runtime_surface,
        'notification_permission',d.notification_permission,
        'push_supported',d.push_supported,
        'standalone',d.standalone,
        'last_seen_at',d.last_seen_at,
        'last_failure_code',d.last_failure_code,
        'active_subscriptions',(select count(*) from public.aos_push_subscriptions_v1 s where s.device_id=d.id and s.active=true),
        'last_success_at',(select max(s.last_success_at) from public.aos_push_subscriptions_v1 s where s.device_id=d.id and s.active=true),
        'last_failure_at',(select max(s.last_failure_at) from public.aos_push_subscriptions_v1 s where s.device_id=d.id and s.active=true)
      ) order by d.last_seen_at desc nulls last)
      from public.aos_devices_v1 d
      where d.user_id=u.id and d.active=true
    ),'[]'::jsonb),
    'legacy_active_subscriptions',(
      select count(*) from public.aos_push_subscriptions_v1 s
      where s.user_id=u.id and s.active=true and s.device_id is null
    )
  ) order by coalesce(u.nivel_jerarquia,999),u.nombre),'[]'::jsonb)
  into v_users
  from public.aos_usuarios u
  where u.activo=true;

  return jsonb_build_object('ok',true,'actor_id',v_actor,'users',v_users,'generated_at',now());
end
$$;

create or replace function public.aos_push_admin_targets_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_actor uuid;
  v_device uuid;
  v_user uuid;
  v_all boolean := coalesce((p_payload->>'all')::boolean,false);
  v_rows jsonb;
begin
  begin
    v_actor := nullif(p_payload->>'actor_id','')::uuid;
    v_device := nullif(p_payload->>'device_id','')::uuid;
    v_user := nullif(p_payload->>'user_id','')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET');
  end;

  if not exists(
    select 1 from public.aos_usuarios u
    where u.id=v_actor and u.activo=true
      and (upper(coalesce(u.rol,''))='ADMIN' or coalesce(u.nivel_jerarquia,999)=1)
  ) then
    return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED');
  end if;

  if v_device is null and v_user is null and not v_all then
    return jsonb_build_object('ok',false,'error','TARGET_REQUIRED');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',s.id,
    'user_id',s.user_id,
    'endpoint',s.endpoint,
    'p256dh',s.p256dh,
    'auth',s.auth,
    'device_id',s.device_id,
    'device_name',coalesce(d.device_name,s.device_label,'Dispositivo'),
    'os_family',d.os_family,
    'runtime_surface',d.runtime_surface
  ) order by coalesce(d.last_seen_at,s.updated_at) desc),'[]'::jsonb)
  into v_rows
  from public.aos_push_subscriptions_v1 s
  join public.aos_usuarios u on u.id=s.user_id and u.activo=true
  left join public.aos_devices_v1 d on d.id=s.device_id and d.active=true
  where s.active=true
    and (
      (v_device is not null and s.device_id=v_device)
      or (v_device is null and v_user is not null and s.user_id=v_user)
      or (v_device is null and v_user is null and v_all and s.device_id is not null)
    );

  return jsonb_build_object('ok',true,'rows',v_rows);
end
$$;

revoke all on function public.aos_push_admin_overview_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_push_admin_targets_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_push_admin_overview_v1(jsonb) to service_role;
grant execute on function public.aos_push_admin_targets_v1(jsonb) to service_role;

commit;
