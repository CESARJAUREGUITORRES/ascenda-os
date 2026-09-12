-- APP-PWA-V2 #517 — additive Device Registry + ASCENDA app presence.
-- PREPARED ONLY. Do not apply to production until APP-G2 gate.
-- This migration does not modify Meta/WhatsApp routing or AI authorities.

create table if not exists public.aos_devices_v1 (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  installation_id uuid not null,
  device_name text,
  os_family text,
  form_factor text,
  runtime_surface text not null default 'WEB',
  app_version text,
  service_worker_version text,
  notification_permission text,
  push_supported boolean not null default false,
  badge_supported boolean not null default false,
  tel_supported boolean not null default false,
  standalone boolean not null default false,
  native_bridge boolean not null default false,
  channel_preferences jsonb not null default '{}'::jsonb,
  quiet_hours jsonb not null default '{}'::jsonb,
  last_seen_at timestamptz,
  last_push_handled_at timestamptz,
  last_notification_opened_at timestamptz,
  last_failure_code text,
  last_failure_at timestamptz,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, installation_id)
);

create index if not exists aos_devices_v1_user_active_idx
  on public.aos_devices_v1(user_id, active, last_seen_at desc);

alter table public.aos_devices_v1 enable row level security;
revoke all on public.aos_devices_v1 from anon, authenticated;
grant select, insert, update, delete on public.aos_devices_v1 to service_role;

alter table public.aos_push_subscriptions_v1
  add column if not exists device_id uuid references public.aos_devices_v1(id) on delete set null;

create index if not exists aos_push_subscriptions_v1_device_active_idx
  on public.aos_push_subscriptions_v1(device_id, active);

create table if not exists public.aos_app_presence_v1 (
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  device_id uuid not null references public.aos_devices_v1(id) on delete cascade,
  labor_state text,
  heartbeat_at timestamptz not null default now(),
  focused boolean,
  visible boolean,
  runtime_surface text,
  session_started_at timestamptz,
  state_started_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(user_id, device_id)
);

create index if not exists aos_app_presence_v1_heartbeat_idx
  on public.aos_app_presence_v1(heartbeat_at desc);

alter table public.aos_app_presence_v1 enable row level security;
revoke all on public.aos_app_presence_v1 from anon, authenticated;
grant select, insert, update, delete on public.aos_app_presence_v1 to service_role;

create or replace function public.aos_device_upsert_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_installation uuid;
  v_id uuid;
begin
  begin
    v_user := nullif(p_payload->>'user_id','')::uuid;
    v_installation := nullif(p_payload->>'installation_id','')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_DEVICE_IDENTITY');
  end;

  if v_user is null or v_installation is null then
    return jsonb_build_object('ok',false,'error','DEVICE_IDENTITY_REQUIRED');
  end if;

  if not exists(select 1 from public.aos_usuarios u where u.id=v_user and u.activo=true) then
    return jsonb_build_object('ok',false,'error','ACTIVE_USER_REQUIRED');
  end if;

  insert into public.aos_devices_v1(
    user_id,installation_id,device_name,os_family,form_factor,runtime_surface,
    app_version,service_worker_version,notification_permission,push_supported,
    badge_supported,tel_supported,standalone,native_bridge,last_seen_at,metadata,active,updated_at
  )
  values(
    v_user,v_installation,
    left(nullif(trim(coalesce(p_payload->>'device_name','')),''),160),
    left(nullif(trim(coalesce(p_payload->>'os_family','')),''),80),
    left(nullif(trim(coalesce(p_payload->>'form_factor','')),''),40),
    left(coalesce(nullif(trim(p_payload->>'runtime_surface'),''),'WEB'),40),
    left(nullif(trim(coalesce(p_payload->>'app_version','')),''),80),
    left(nullif(trim(coalesce(p_payload->>'service_worker_version','')),''),80),
    left(nullif(trim(coalesce(p_payload->>'notification_permission','')),''),32),
    coalesce((p_payload->>'push_supported')::boolean,false),
    coalesce((p_payload->>'badge_supported')::boolean,false),
    coalesce((p_payload->>'tel_supported')::boolean,false),
    coalesce((p_payload->>'standalone')::boolean,false),
    coalesce((p_payload->>'native_bridge')::boolean,false),
    now(),
    coalesce(p_payload->'metadata','{}'::jsonb),
    true,
    now()
  )
  on conflict(user_id,installation_id) do update set
    device_name=coalesce(excluded.device_name,aos_devices_v1.device_name),
    os_family=coalesce(excluded.os_family,aos_devices_v1.os_family),
    form_factor=coalesce(excluded.form_factor,aos_devices_v1.form_factor),
    runtime_surface=excluded.runtime_surface,
    app_version=coalesce(excluded.app_version,aos_devices_v1.app_version),
    service_worker_version=coalesce(excluded.service_worker_version,aos_devices_v1.service_worker_version),
    notification_permission=coalesce(excluded.notification_permission,aos_devices_v1.notification_permission),
    push_supported=excluded.push_supported,
    badge_supported=excluded.badge_supported,
    tel_supported=excluded.tel_supported,
    standalone=excluded.standalone,
    native_bridge=excluded.native_bridge,
    last_seen_at=now(),
    metadata=aos_devices_v1.metadata || excluded.metadata,
    active=true,
    updated_at=now()
  returning id into v_id;

  return jsonb_build_object('ok',true,'device_id',v_id);
end
$$;

create or replace function public.aos_app_presence_touch_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_device uuid;
  v_state text := upper(trim(coalesce(p_payload->>'labor_state','')));
  v_now timestamptz := now();
begin
  begin
    v_user := nullif(p_payload->>'user_id','')::uuid;
    v_device := nullif(p_payload->>'device_id','')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_PRESENCE_IDENTITY');
  end;

  if not exists(
    select 1 from public.aos_devices_v1 d
    where d.id=v_device and d.user_id=v_user and d.active=true
  ) then
    return jsonb_build_object('ok',false,'error','ACTIVE_DEVICE_REQUIRED');
  end if;

  update public.aos_devices_v1
     set last_seen_at=v_now,
         app_version=coalesce(nullif(trim(p_payload->>'app_version'),''),app_version),
         service_worker_version=coalesce(nullif(trim(p_payload->>'service_worker_version'),''),service_worker_version),
         updated_at=v_now
   where id=v_device and user_id=v_user;

  insert into public.aos_app_presence_v1(
    user_id,device_id,labor_state,heartbeat_at,focused,visible,runtime_surface,
    session_started_at,state_started_at,metadata,updated_at
  )
  values(
    v_user,v_device,nullif(v_state,''),v_now,
    case when p_payload ? 'focused' then (p_payload->>'focused')::boolean else null end,
    case when p_payload ? 'visible' then (p_payload->>'visible')::boolean else null end,
    nullif(trim(p_payload->>'runtime_surface'),''),
    coalesce(nullif(p_payload->>'session_started_at','')::timestamptz,v_now),
    coalesce(nullif(p_payload->>'state_started_at','')::timestamptz,v_now),
    coalesce(p_payload->'metadata','{}'::jsonb),
    v_now
  )
  on conflict(user_id,device_id) do update set
    labor_state=coalesce(nullif(excluded.labor_state,''),aos_app_presence_v1.labor_state),
    heartbeat_at=v_now,
    focused=excluded.focused,
    visible=excluded.visible,
    runtime_surface=coalesce(excluded.runtime_surface,aos_app_presence_v1.runtime_surface),
    session_started_at=coalesce(aos_app_presence_v1.session_started_at,excluded.session_started_at),
    state_started_at=case
      when excluded.labor_state is distinct from aos_app_presence_v1.labor_state then v_now
      else aos_app_presence_v1.state_started_at
    end,
    metadata=aos_app_presence_v1.metadata || excluded.metadata,
    updated_at=v_now;

  return jsonb_build_object('ok',true,'heartbeat_at',v_now);
end
$$;

create or replace function public.aos_effective_presence_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_stale_seconds integer := greatest(30, least(coalesce(nullif(p_payload->>'stale_seconds','')::integer,120),900));
  v_last public.aos_app_presence_v1%rowtype;
  v_age numeric;
begin
  begin v_user := nullif(p_payload->>'user_id','')::uuid;
  exception when others then return jsonb_build_object('ok',false,'error','INVALID_USER_ID'); end;

  select p.* into v_last
  from public.aos_app_presence_v1 p
  join public.aos_devices_v1 d on d.id=p.device_id and d.active=true
  where p.user_id=v_user
  order by p.heartbeat_at desc
  limit 1;

  if not found then
    return jsonb_build_object('ok',true,'status','OFFLINE','stale',true,'reason','NO_HEARTBEAT');
  end if;

  v_age := extract(epoch from (now()-v_last.heartbeat_at));
  if v_age > v_stale_seconds then
    return jsonb_build_object(
      'ok',true,'status','OFFLINE','stale',true,'reason','HEARTBEAT_STALE',
      'last_seen_at',v_last.heartbeat_at,'age_seconds',round(v_age)
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',coalesce(nullif(v_last.labor_state,''),'ACTIVO'),
    'stale',false,
    'last_seen_at',v_last.heartbeat_at,
    'age_seconds',round(v_age),
    'focused',v_last.focused,
    'visible',v_last.visible,
    'device_id',v_last.device_id,
    'state_started_at',v_last.state_started_at
  );
end
$$;

revoke all on function public.aos_device_upsert_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_app_presence_touch_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_effective_presence_v1(jsonb) from public, anon, authenticated;
grant execute on function public.aos_device_upsert_v1(jsonb) to service_role;
grant execute on function public.aos_app_presence_touch_v1(jsonb) to service_role;
grant execute on function public.aos_effective_presence_v1(jsonb) to service_role;
