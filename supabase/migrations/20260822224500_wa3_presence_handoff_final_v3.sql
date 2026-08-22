-- ASCENDA Conversations — WA-3 FINAL: global presence + explicit human handoff queue.
-- Additive/replace-in-place contracts only. No auto-routing or AI activation.

create index if not exists aos_wa_conversations_v1_handoff_queue_idx
  on public.aos_wa_conversations_v1(box_id,handoff_requested_at,last_message_at)
  where state='HUMAN_REQUESTED' and owner_user_id is null and handoff_requested_at is not null;

create or replace function public.aos_wa3_effective_presence_v2(p_actor_id uuid)
returns jsonb
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare
  v_user record;
  v_presence record;
  v_labor_state text;
  v_normalized text;
  v_effective text:='OFFLINE';
  v_fresh boolean:=false;
begin
  select id,activo,nivel_jerarquia,paneles_acceso,codigo_asesor,nombre
    into v_user
  from public.aos_usuarios
  where id=p_actor_id;

  if v_user.id is null or v_user.activo is not true then
    return jsonb_build_object('ok',false,'error','WA3_USER_INACTIVE','status','OFFLINE','ready',false);
  end if;

  select status,last_seen_at,available_since
    into v_presence
  from public.aos_wa_agent_presence_v1
  where user_id=p_actor_id;

  v_fresh := v_presence.last_seen_at is not null
    and v_presence.last_seen_at >= now()-interval '60 seconds';

  if not v_fresh then
    return jsonb_build_object(
      'ok',true,'status','OFFLINE','ready',false,'stale',true,
      'last_seen_at',v_presence.last_seen_at,'available_since',null,'labor_state',null,
      'presence_source','ASCENDA_GLOBAL'
    );
  end if;

  -- Admin/supervisor connectivity is global session presence. Operational labor-state
  -- eligibility applies to advisors; admins intervene explicitly rather than auto-route.
  if coalesce(v_user.nivel_jerarquia,99)<=2
     and coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[] then
    v_effective:='AVAILABLE';
  else
    select e.estado
      into v_labor_state
    from public.aos_estado_equipo e
    where (v_user.codigo_asesor is not null and e.codigo_asesor=v_user.codigo_asesor)
       or upper(trim(e.asesor))=upper(trim(v_user.nombre))
    order by e.updated_at desc nulls last
    limit 1;

    v_normalized:=upper(trim(translate(coalesce(v_labor_state,''),'ÁÉÍÓÚÜÑ','AEIOUUN')));

    if v_normalized in ('DESCONECTADO','OFFLINE','SALIDA','SALIO','FUERA','NO LOGEADO') then
      v_effective:='OFFLINE';
    elsif v_normalized='' or v_normalized in ('LOGEADO','ACTIVO','DISPONIBLE','ONLINE','TRABAJO') then
      v_effective:='AVAILABLE';
    else
      -- BREAK, BANO, LIMPIEZA, ATENCION, CAPACITACION, REUNION, OTROS, etc.
      v_effective:='AWAY';
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',v_effective,
    'ready',v_effective='AVAILABLE',
    'stale',false,
    'last_seen_at',v_presence.last_seen_at,
    'available_since',case when v_effective='AVAILABLE' then v_presence.available_since else null end,
    'labor_state',v_labor_state,
    'presence_source','ASCENDA_GLOBAL'
  );
end
$$;

create or replace function public.aos_wa3_agent_presence_touch_v1(
  p_actor_id uuid,
  p_status text default 'AVAILABLE'
) returns jsonb
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_signal text:=upper(coalesce(nullif(trim(p_status),''),'AVAILABLE'));
  v_user record;
  v_prev text;
  v_prev_since timestamptz;
  v_effective jsonb;
  v_status text;
  v_since timestamptz;
begin
  if v_signal not in ('AVAILABLE','AWAY','OFFLINE','HEARTBEAT') then
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

  select status,available_since into v_prev,v_prev_since
  from public.aos_wa_agent_presence_v1
  where user_id=p_actor_id
  for update;

  if v_signal='OFFLINE' then
    insert into public.aos_wa_agent_presence_v1(user_id,status,last_seen_at,available_since,updated_by,metadata,updated_at)
    values(p_actor_id,'OFFLINE',now()-interval '61 seconds',null,p_actor_id,jsonb_build_object('presence_source','ASCENDA_GLOBAL','signal','OFFLINE'),now())
    on conflict(user_id) do update set
      status='OFFLINE',last_seen_at=excluded.last_seen_at,available_since=null,updated_by=p_actor_id,
      metadata=coalesce(public.aos_wa_agent_presence_v1.metadata,'{}'::jsonb)||excluded.metadata,updated_at=now();
    v_status:='OFFLINE';
    v_since:=null;
  else
    -- AVAILABLE/AWAY from old clients are treated as heartbeat signals only.
    -- The effective state is derived from ASCENDA labor state, never a WA button.
    insert into public.aos_wa_agent_presence_v1(user_id,status,last_seen_at,available_since,updated_by,metadata,updated_at)
    values(p_actor_id,'AVAILABLE',now(),coalesce(v_prev_since,now()),p_actor_id,jsonb_build_object('presence_source','ASCENDA_GLOBAL','signal','HEARTBEAT'),now())
    on conflict(user_id) do update set
      last_seen_at=now(),updated_by=p_actor_id,
      metadata=coalesce(public.aos_wa_agent_presence_v1.metadata,'{}'::jsonb)||excluded.metadata,updated_at=now();

    v_effective:=public.aos_wa3_effective_presence_v2(p_actor_id);
    v_status:=coalesce(v_effective->>'status','OFFLINE');
    if v_status='AVAILABLE' then
      if v_prev is distinct from 'AVAILABLE' or v_prev_since is null then v_since:=now(); else v_since:=v_prev_since; end if;
    else
      v_since:=null;
    end if;

    update public.aos_wa_agent_presence_v1
    set status=v_status,available_since=v_since,
        metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('labor_state',v_effective->>'labor_state','effective_status',v_status),
        updated_at=now()
    where user_id=p_actor_id;
  end if;

  if v_prev is distinct from v_status then
    insert into public.aos_wa_routing_events_v1(event_type,actor_id,payload)
    values('agent.presence_changed',p_actor_id,jsonb_build_object('from',v_prev,'to',v_status,'source','ASCENDA_GLOBAL'));
  end if;

  v_effective:=public.aos_wa3_effective_presence_v2(p_actor_id);
  return coalesce(v_effective,'{}'::jsonb)||jsonb_build_object(
    'ok',true,'user_id',p_actor_id,'fresh_for_seconds',60,'automatic',true
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
  v_presence jsonb;
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

  v_presence:=public.aos_wa3_effective_presence_v2(p_actor_id);
  v_ready:=coalesce((v_presence->>'ready')::boolean,false);

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
        'can_claim',v_ready and (q.max_active is null or q.active_load<q.max_active),
        'queue_contract','HUMAN_HANDOFF_ONLY'
      ) order by q.priority desc,q.name asc
    ),'[]'::jsonb),
    coalesce(sum(q.queued_count),0)::integer
  into v_boxes,v_total
  from (
    select
      b.id as box_id,b.code,b.name,m.max_active,m.priority,
      (
        select count(*)::integer
        from public.aos_wa_assignments_v1 a
        join public.aos_wa_conversations_v1 c on c.id=a.conversation_id
        where a.box_id=b.id and a.state='QUEUED'
          and c.state='HUMAN_REQUESTED'
          and c.owner_user_id is null
          and c.handoff_requested_at is not null
      ) as queued_count,
      (
        select count(*)::integer
        from public.aos_wa_assignments_v1 a
        where a.owner_user_id=p_actor_id and a.state='ACTIVE'
      ) as active_load
    from public.aos_wa_box_members_v1 m
    join public.aos_wa_boxes_v1 b on b.id=m.box_id and b.status='ACTIVE'
    where m.user_id=p_actor_id and m.active is true
  ) q;

  return jsonb_build_object(
    'ok',true,'actor_id',p_actor_id,'presence',v_presence,
    'total_queued',v_total,'boxes',v_boxes,'queue_contract','HUMAN_HANDOFF_ONLY'
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
  v_presence jsonb;
  v_member public.aos_wa_box_members_v1%rowtype;
  v_assignment public.aos_wa_assignments_v1%rowtype;
  v_load integer;
  v_conv uuid;
begin
  v_presence:=public.aos_wa3_effective_presence_v2(p_actor_id);
  if coalesce(v_presence->>'status','OFFLINE')<>'AVAILABLE'
     or not coalesce((v_presence->>'ready')::boolean,false) then
    return jsonb_build_object('ok',false,'error','WA3_AGENT_NOT_READY','presence',v_presence);
  end if;

  select * into v_member
  from public.aos_wa_box_members_v1
  where box_id=p_box_id and user_id=p_actor_id and active is true;
  if v_member.user_id is null then return jsonb_build_object('ok',false,'error','WA3_NOT_BOX_MEMBER'); end if;

  select count(*) into v_load
  from public.aos_wa_assignments_v1
  where owner_user_id=p_actor_id and state='ACTIVE';
  if v_member.max_active is not null and v_load>=v_member.max_active then
    return jsonb_build_object('ok',false,'error','WA3_CAPACITY_REACHED');
  end if;

  select a.* into v_assignment
  from public.aos_wa_assignments_v1 a
  join public.aos_wa_conversations_v1 c on c.id=a.conversation_id
  where a.box_id=p_box_id and a.state='QUEUED'
    and c.state='HUMAN_REQUESTED'
    and c.owner_user_id is null
    and c.handoff_requested_at is not null
  order by a.assigned_at asc,a.id asc
  limit 1
  for update of a skip locked;

  if v_assignment.id is null then
    return jsonb_build_object('ok',true,'claimed',false,'reason','NO_HUMAN_HANDOFF_WORK');
  end if;

  update public.aos_wa_assignments_v1
  set owner_user_id=p_actor_id,state='ACTIVE',claimed_at=now(),updated_at=now()
  where id=v_assignment.id
  returning conversation_id into v_conv;

  update public.aos_wa_conversations_v1
  set owner_user_id=p_actor_id,state='HUMAN_ACTIVE',human_takeover_at=now(),
      ownership_version=ownership_version+1,updated_at=now()
  where id=v_conv;

  update public.aos_wa_box_members_v1
  set last_assigned_at=now(),updated_at=now()
  where box_id=p_box_id and user_id=p_actor_id;

  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,assignment_id,event_type,actor_id,payload)
  values(v_conv,p_box_id,v_assignment.id,'conversation.claimed',p_actor_id,jsonb_build_object('queue_contract','HUMAN_HANDOFF_ONLY'));

  return jsonb_build_object('ok',true,'claimed',true,'conversation_id',v_conv,'assignment_id',v_assignment.id,'queue_contract','HUMAN_HANDOFF_ONLY');
end
$$;

create or replace function public.aos_wa3_handoff_request_v1(
  p_conversation_id uuid,
  p_box_id uuid default null,
  p_actor_id uuid default null,
  p_reason text default null
) returns jsonb
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_box uuid:=p_box_id;
  v_current public.aos_wa_assignments_v1%rowtype;
  v_assignment uuid;
begin
  if p_actor_id is not null and not public.aos_wa3_is_admin_v1(p_actor_id) then
    return jsonb_build_object('ok',false,'error','WA3_ADMIN_REQUIRED');
  end if;

  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.state in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_TERMINAL'); end if;

  select * into v_current
  from public.aos_wa_assignments_v1
  where conversation_id=p_conversation_id and state in ('QUEUED','ACTIVE')
  order by assigned_at desc limit 1 for update;

  if v_current.id is not null and v_current.state='ACTIVE' then
    return jsonb_build_object('ok',false,'error','WA3_ALREADY_HUMAN_ACTIVE');
  end if;
  if v_current.id is not null and v_current.state='QUEUED'
     and v_conv.state='HUMAN_REQUESTED' and v_conv.handoff_requested_at is not null then
    return jsonb_build_object('ok',true,'idempotent',true,'state','HUMAN_REQUESTED','assignment_id',v_current.id);
  end if;

  if v_box is null then
    select id into v_box from public.aos_wa_boxes_v1 where status='ACTIVE' and is_default is true limit 1;
  end if;
  if v_box is null or not exists(select 1 from public.aos_wa_boxes_v1 where id=v_box and status='ACTIVE') then
    return jsonb_build_object('ok',false,'error','WA3_ACTIVE_BOX_REQUIRED');
  end if;

  insert into public.aos_wa_assignments_v1(conversation_id,box_id,owner_user_id,state,assigned_by,metadata)
  values(p_conversation_id,v_box,null,'QUEUED',p_actor_id,
         jsonb_build_object('reason',coalesce(p_reason,''),'queue_contract','HUMAN_HANDOFF_ONLY'))
  returning id into v_assignment;

  update public.aos_wa_conversations_v1
  set box_id=v_box,owner_user_id=null,state='HUMAN_REQUESTED',handoff_requested_at=now(),
      ownership_version=ownership_version+1,updated_at=now()
  where id=p_conversation_id;

  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,assignment_id,event_type,actor_id,payload)
  values(p_conversation_id,v_box,v_assignment,'conversation.handoff_requested',p_actor_id,
         jsonb_build_object('reason',coalesce(p_reason,''),'queue_contract','HUMAN_HANDOFF_ONLY'));

  return jsonb_build_object('ok',true,'idempotent',false,'state','HUMAN_REQUESTED','assignment_id',v_assignment,'box_id',v_box);
end
$$;

revoke all on function public.aos_wa3_effective_presence_v2(uuid) from public,anon,authenticated;
revoke all on function public.aos_wa3_handoff_request_v1(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.aos_wa3_effective_presence_v2(uuid) to service_role;
grant execute on function public.aos_wa3_handoff_request_v1(uuid,uuid,uuid,text) to service_role;

comment on table public.aos_wa_agent_presence_v1 is 'Global ASCENDA session heartbeat for WA-eligible staff. Effective AVAILABLE/AWAY is derived from labor state; stale heartbeat is OFFLINE.';
comment on function public.aos_wa3_effective_presence_v2(uuid) is 'Derives WA operational presence from global ASCENDA connectivity plus canonical labor state.';
comment on function public.aos_wa3_queue_summary_v1(uuid) is 'Aggregate HUMAN_HANDOFF_ONLY queue summary; never exposes unowned customer content.';
comment on function public.aos_wa3_claim_next_v2(uuid,uuid) is 'Claims only explicit HUMAN_REQUESTED queued conversations; bot-normal conversations are never claimable.';
comment on function public.aos_wa3_handoff_request_v1(uuid,uuid,uuid,text) is 'Explicitly moves a nonterminal bot/unowned conversation into the governed human handoff queue.';
