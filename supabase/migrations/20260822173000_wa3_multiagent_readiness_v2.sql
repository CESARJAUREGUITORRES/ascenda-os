-- ASCENDA Conversations — WA-3 V2 multiagent readiness.
-- Additive only: preserves WA-3 V1 routing/ownership and keeps auto-routing / AI send unchanged.

create table if not exists public.aos_wa_agent_presence_v1 (
  user_id uuid primary key references public.aos_usuarios(id) on delete cascade,
  status text not null default 'OFFLINE' check (status in ('AVAILABLE','AWAY','OFFLINE')),
  last_seen_at timestamptz not null default now(),
  available_since timestamptz,
  updated_by uuid references public.aos_usuarios(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aos_wa_agent_presence_v1 enable row level security;
alter table public.aos_wa_agent_presence_v1 force row level security;
revoke all on table public.aos_wa_agent_presence_v1 from public, anon, authenticated;
grant select, insert, update, delete on table public.aos_wa_agent_presence_v1 to service_role;

create or replace function public.aos_wa3_agent_presence_touch_v1(
  p_actor_id uuid,
  p_status text default 'AVAILABLE'
) returns jsonb
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_status text:=upper(coalesce(nullif(trim(p_status),''),'AVAILABLE'));
  v_user record;
  v_prev text;
  v_since timestamptz;
begin
  if v_status not in ('AVAILABLE','AWAY','OFFLINE') then
    return jsonb_build_object('ok',false,'error','WA3_INVALID_PRESENCE_STATUS');
  end if;

  select id,activo,nivel_jerarquia,paneles_acceso
    into v_user
  from public.aos_usuarios
  where id=p_actor_id;

  if v_user.id is null or v_user.activo is not true then
    return jsonb_build_object('ok',false,'error','WA3_USER_INACTIVE');
  end if;

  if not (
    coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['whatsapp-agent']::text[]
    or (
      coalesce(v_user.nivel_jerarquia,99)<=2
      and coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[]
    )
  ) then
    return jsonb_build_object('ok',false,'error','WA3_AGENT_PANEL_REQUIRED');
  end if;

  select status,available_since into v_prev,v_since
  from public.aos_wa_agent_presence_v1
  where user_id=p_actor_id
  for update;

  if v_status='AVAILABLE' then
    if v_prev is distinct from 'AVAILABLE' or v_since is null then v_since:=now(); end if;
  else
    v_since:=null;
  end if;

  insert into public.aos_wa_agent_presence_v1(
    user_id,status,last_seen_at,available_since,updated_by,updated_at
  ) values (
    p_actor_id,v_status,now(),v_since,p_actor_id,now()
  )
  on conflict(user_id) do update set
    status=excluded.status,
    last_seen_at=excluded.last_seen_at,
    available_since=excluded.available_since,
    updated_by=excluded.updated_by,
    updated_at=excluded.updated_at;

  if v_prev is distinct from v_status then
    insert into public.aos_wa_routing_events_v1(event_type,actor_id,payload)
    values('agent.presence_changed',p_actor_id,jsonb_build_object('from',v_prev,'to',v_status));
  end if;

  return jsonb_build_object(
    'ok',true,
    'user_id',p_actor_id,
    'status',v_status,
    'ready',v_status='AVAILABLE',
    'last_seen_at',now(),
    'available_since',v_since,
    'fresh_for_seconds',120
  );
end
$$;

create or replace function public.aos_wa3_queue_summary_v1(
  p_actor_id uuid
) returns jsonb
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare
  v_user record;
  v_presence record;
  v_ready boolean:=false;
  v_boxes jsonb:='[]'::jsonb;
  v_total integer:=0;
begin
  select id,activo,nivel_jerarquia,paneles_acceso
    into v_user
  from public.aos_usuarios
  where id=p_actor_id;

  if v_user.id is null or v_user.activo is not true then
    return jsonb_build_object('ok',false,'error','WA3_USER_INACTIVE');
  end if;

  if not (
    coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['whatsapp-agent']::text[]
    or (
      coalesce(v_user.nivel_jerarquia,99)<=2
      and coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[]
    )
  ) then
    return jsonb_build_object('ok',false,'error','WA3_AGENT_PANEL_REQUIRED');
  end if;

  select status,last_seen_at,available_since
    into v_presence
  from public.aos_wa_agent_presence_v1
  where user_id=p_actor_id;

  v_ready := v_presence.status='AVAILABLE'
    and v_presence.last_seen_at is not null
    and v_presence.last_seen_at >= now()-interval '120 seconds';

  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'box_id',q.box_id,
        'code',q.code,
        'name',q.name,
        'queued_count',q.queued_count,
        'active_load',q.active_load,
        'max_active',q.max_active,
        'priority',q.priority,
        'can_claim',v_ready and (q.max_active is null or q.active_load<q.max_active)
      ) order by q.priority desc,q.name asc
    ),'[]'::jsonb),
    coalesce(sum(q.queued_count),0)::integer
  into v_boxes,v_total
  from (
    select
      b.id as box_id,
      b.code,
      b.name,
      m.max_active,
      m.priority,
      (select count(*)::integer from public.aos_wa_assignments_v1 a where a.box_id=b.id and a.state='QUEUED') as queued_count,
      (select count(*)::integer from public.aos_wa_assignments_v1 a where a.owner_user_id=p_actor_id and a.state='ACTIVE') as active_load
    from public.aos_wa_box_members_v1 m
    join public.aos_wa_boxes_v1 b on b.id=m.box_id and b.status='ACTIVE'
    where m.user_id=p_actor_id and m.active is true
  ) q;

  return jsonb_build_object(
    'ok',true,
    'actor_id',p_actor_id,
    'presence',jsonb_build_object(
      'status',coalesce(v_presence.status,'OFFLINE'),
      'last_seen_at',v_presence.last_seen_at,
      'available_since',v_presence.available_since,
      'ready',v_ready,
      'stale',coalesce(v_presence.last_seen_at < now()-interval '120 seconds',true)
    ),
    'total_queued',v_total,
    'boxes',v_boxes
  );
end
$$;

create or replace function public.aos_wa3_claim_next_v2(
  p_box_id uuid,
  p_actor_id uuid
) returns jsonb
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_presence record;
begin
  select status,last_seen_at into v_presence
  from public.aos_wa_agent_presence_v1
  where user_id=p_actor_id;

  if v_presence.status is distinct from 'AVAILABLE'
     or v_presence.last_seen_at is null
     or v_presence.last_seen_at < now()-interval '120 seconds' then
    return jsonb_build_object('ok',false,'error','WA3_AGENT_NOT_READY');
  end if;

  return public.aos_wa3_claim_next_v1(p_box_id,p_actor_id);
end
$$;

revoke all on function public.aos_wa3_agent_presence_touch_v1(uuid,text) from public, anon, authenticated;
revoke all on function public.aos_wa3_queue_summary_v1(uuid) from public, anon, authenticated;
revoke all on function public.aos_wa3_claim_next_v2(uuid,uuid) from public, anon, authenticated;
grant execute on function public.aos_wa3_agent_presence_touch_v1(uuid,text) to service_role;
grant execute on function public.aos_wa3_queue_summary_v1(uuid) to service_role;
grant execute on function public.aos_wa3_claim_next_v2(uuid,uuid) to service_role;

comment on table public.aos_wa_agent_presence_v1 is 'Ephemeral WA agent readiness. Stale rows are effectively OFFLINE; no customer data is stored here.';
comment on function public.aos_wa3_queue_summary_v1(uuid) is 'Returns aggregate queue counts for boxes where the actor is an active member. Never exposes unowned conversation content.';
comment on function public.aos_wa3_claim_next_v2(uuid,uuid) is 'WA-3 V2 presence-aware claim wrapper. Preserves WA-3 V1 ownership/capacity semantics.';
