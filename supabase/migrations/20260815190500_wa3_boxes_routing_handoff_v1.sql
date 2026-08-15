-- ASCENDA Conversations — WA-3 Boxes, Routing & Human Handoff V1
-- Additive ownership/control layer over WA-2. AI outbound remains disabled in WA-3.

begin;

create table if not exists public.aos_wa_routing_control_v1 (
  id smallint primary key default 1 check (id = 1),
  auto_routing_enabled boolean not null default false,
  human_send_enabled boolean not null default false,
  ai_send_enabled boolean not null default false check (ai_send_enabled = false),
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.aos_wa_routing_control_v1(id) values (1) on conflict (id) do nothing;
alter table public.aos_wa_routing_control_v1 enable row level security;
alter table public.aos_wa_routing_control_v1 force row level security;
revoke all on table public.aos_wa_routing_control_v1 from public, anon, authenticated;
grant select, update on table public.aos_wa_routing_control_v1 to service_role;

create table if not exists public.aos_wa_boxes_v1 (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (char_length(trim(name)) between 2 and 80),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','PAUSED','ARCHIVED')),
  routing_strategy text not null default 'MANUAL' check (routing_strategy in ('MANUAL','LEAST_ACTIVE')),
  is_default boolean not null default false,
  priority integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.aos_usuarios(id) on delete set null,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists aos_wa_boxes_v1_one_default_idx
  on public.aos_wa_boxes_v1((is_default)) where is_default is true and status='ACTIVE';
create index if not exists aos_wa_boxes_v1_status_idx
  on public.aos_wa_boxes_v1(status, priority desc, name);
alter table public.aos_wa_boxes_v1 enable row level security;
alter table public.aos_wa_boxes_v1 force row level security;
revoke all on table public.aos_wa_boxes_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_boxes_v1 to service_role;

create table if not exists public.aos_wa_box_members_v1 (
  box_id uuid not null references public.aos_wa_boxes_v1(id) on delete restrict,
  user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  active boolean not null default true,
  max_active integer check (max_active is null or max_active > 0),
  priority integer not null default 0,
  last_assigned_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.aos_usuarios(id) on delete set null,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (box_id,user_id)
);
create index if not exists aos_wa_box_members_v1_user_idx on public.aos_wa_box_members_v1(user_id,active);
alter table public.aos_wa_box_members_v1 enable row level security;
alter table public.aos_wa_box_members_v1 force row level security;
revoke all on table public.aos_wa_box_members_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_box_members_v1 to service_role;

alter table public.aos_wa_conversations_v1
  add column if not exists box_id uuid references public.aos_wa_boxes_v1(id) on delete restrict,
  add column if not exists owner_user_id uuid references public.aos_usuarios(id) on delete restrict,
  add column if not exists ownership_version bigint not null default 0,
  add column if not exists handoff_requested_at timestamptz,
  add column if not exists human_takeover_at timestamptz;
create index if not exists aos_wa_conversations_v1_owner_idx on public.aos_wa_conversations_v1(owner_user_id,last_message_at desc nulls last);
create index if not exists aos_wa_conversations_v1_box_idx on public.aos_wa_conversations_v1(box_id,state,last_message_at desc nulls last);

create table if not exists public.aos_wa_assignments_v1 (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  box_id uuid not null references public.aos_wa_boxes_v1(id) on delete restrict,
  owner_user_id uuid references public.aos_usuarios(id) on delete restrict,
  state text not null check (state in ('QUEUED','ACTIVE','RELEASED','REASSIGNED','CLOSED')),
  assigned_at timestamptz not null default now(),
  claimed_at timestamptz,
  released_at timestamptz,
  terminal_reason text,
  assigned_by uuid references public.aos_usuarios(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((state='QUEUED' and owner_user_id is null) or state<>'QUEUED')
);
create unique index if not exists aos_wa_assignments_v1_one_current_idx on public.aos_wa_assignments_v1(conversation_id) where state in ('QUEUED','ACTIVE');
create index if not exists aos_wa_assignments_v1_owner_idx on public.aos_wa_assignments_v1(owner_user_id,state,assigned_at);
create index if not exists aos_wa_assignments_v1_box_queue_idx on public.aos_wa_assignments_v1(box_id,state,assigned_at);
alter table public.aos_wa_assignments_v1 enable row level security;
alter table public.aos_wa_assignments_v1 force row level security;
revoke all on table public.aos_wa_assignments_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_assignments_v1 to service_role;

create table if not exists public.aos_wa_routing_events_v1 (
  id bigint generated always as identity primary key,
  conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict,
  box_id uuid references public.aos_wa_boxes_v1(id) on delete restrict,
  assignment_id uuid references public.aos_wa_assignments_v1(id) on delete restrict,
  event_type text not null,
  actor_id uuid references public.aos_usuarios(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists aos_wa_routing_events_v1_conv_idx on public.aos_wa_routing_events_v1(conversation_id,created_at desc);
create index if not exists aos_wa_routing_events_v1_box_idx on public.aos_wa_routing_events_v1(box_id,created_at desc);
alter table public.aos_wa_routing_events_v1 enable row level security;
alter table public.aos_wa_routing_events_v1 force row level security;
revoke all on table public.aos_wa_routing_events_v1 from public, anon, authenticated;
grant select, insert on table public.aos_wa_routing_events_v1 to service_role;

insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,descripcion,orden)
values ('whatsapp-agent','WhatsApp Inbox','💬','ventas','Inbox WhatsApp asignado por ownership. Requiere 2FA y asignación explícita.',78)
on conflict (id) do nothing;

create or replace function public.aos_wa3_routing_event_append_guard_v1()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin raise exception 'WA3_ROUTING_EVENT_APPEND_ONLY' using errcode='55000'; end
$$;
drop trigger if exists trg_aos_wa3_routing_event_append_guard_v1 on public.aos_wa_routing_events_v1;
create trigger trg_aos_wa3_routing_event_append_guard_v1 before update or delete on public.aos_wa_routing_events_v1 for each row execute function public.aos_wa3_routing_event_append_guard_v1();

create or replace function public.aos_wa3_is_admin_v1(p_actor_id uuid)
returns boolean language sql stable set search_path=public,pg_temp as $$
  select exists(select 1 from public.aos_usuarios u where u.id=p_actor_id and u.activo is true and coalesce(u.nivel_jerarquia,99)<=2 and coalesce(u.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[])
$$;

create or replace function public.aos_wa3_actor_v1(p_token text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid;
begin
  v_uid:=public.aos_app_actor_v3(p_token,'admin-whatsapp',true);
  if v_uid is not null and public.aos_wa3_is_admin_v1(v_uid) then return jsonb_build_object('ok',true,'actor_id',v_uid,'is_admin',true); end if;
  v_uid:=public.aos_app_actor_v3(p_token,'whatsapp-agent',true);
  if v_uid is not null then return jsonb_build_object('ok',true,'actor_id',v_uid,'is_admin',false); end if;
  return jsonb_build_object('ok',false,'error','WA3_2FA_PANEL_REQUIRED');
end
$$;

create or replace function public.aos_wa3_box_upsert_v1(p_actor_id uuid,p_box_id uuid,p_code text,p_name text,p_strategy text default 'MANUAL',p_status text default 'ACTIVE',p_is_default boolean default false,p_priority integer default 0)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_id uuid:=coalesce(p_box_id,gen_random_uuid()); v_code text:=upper(trim(coalesce(p_code,''))); v_name text:=trim(coalesce(p_name,''));
begin
  if not public.aos_wa3_is_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA3_ADMIN_REQUIRED'); end if;
  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{1,31}$' then return jsonb_build_object('ok',false,'error','WA3_INVALID_BOX_CODE'); end if;
  if char_length(v_name) not between 2 and 80 then return jsonb_build_object('ok',false,'error','WA3_INVALID_BOX_NAME'); end if;
  if p_strategy not in ('MANUAL','LEAST_ACTIVE') then return jsonb_build_object('ok',false,'error','WA3_INVALID_STRATEGY'); end if;
  if p_status not in ('ACTIVE','PAUSED','ARCHIVED') then return jsonb_build_object('ok',false,'error','WA3_INVALID_BOX_STATUS'); end if;
  if coalesce(p_is_default,false) and p_status='ACTIVE' then update public.aos_wa_boxes_v1 set is_default=false,updated_by=p_actor_id,updated_at=now() where is_default is true and id<>v_id; end if;
  insert into public.aos_wa_boxes_v1(id,code,name,status,routing_strategy,is_default,priority,created_by,updated_by)
  values(v_id,v_code,v_name,p_status,p_strategy,coalesce(p_is_default,false),coalesce(p_priority,0),p_actor_id,p_actor_id)
  on conflict(id) do update set code=excluded.code,name=excluded.name,status=excluded.status,routing_strategy=excluded.routing_strategy,is_default=excluded.is_default,priority=excluded.priority,updated_by=p_actor_id,updated_at=now();
  insert into public.aos_wa_routing_events_v1(box_id,event_type,actor_id,payload) values(v_id,'box.upserted',p_actor_id,jsonb_build_object('code',v_code,'status',p_status,'strategy',p_strategy,'is_default',coalesce(p_is_default,false)));
  return jsonb_build_object('ok',true,'box_id',v_id);
exception when unique_violation then return jsonb_build_object('ok',false,'error','WA3_BOX_CONFLICT');
end
$$;

create or replace function public.aos_wa3_box_member_set_v1(p_actor_id uuid,p_box_id uuid,p_user_id uuid,p_active boolean default true,p_max_active integer default null,p_priority integer default 0)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_user record;
begin
  if not public.aos_wa3_is_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA3_ADMIN_REQUIRED'); end if;
  if not exists(select 1 from public.aos_wa_boxes_v1 where id=p_box_id and status<>'ARCHIVED') then return jsonb_build_object('ok',false,'error','WA3_BOX_NOT_FOUND'); end if;
  select id,activo,nivel_jerarquia,paneles_acceso into v_user from public.aos_usuarios where id=p_user_id;
  if v_user.id is null then return jsonb_build_object('ok',false,'error','WA3_USER_NOT_FOUND'); end if;
  if coalesce(p_active,true) and (v_user.activo is not true or not (coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['whatsapp-agent']::text[] or (coalesce(v_user.nivel_jerarquia,99)<=2 and coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-whatsapp']::text[]))) then return jsonb_build_object('ok',false,'error','WA3_AGENT_PANEL_REQUIRED'); end if;
  if p_max_active is not null and p_max_active<=0 then return jsonb_build_object('ok',false,'error','WA3_INVALID_CAPACITY'); end if;
  insert into public.aos_wa_box_members_v1(box_id,user_id,active,max_active,priority,created_by,updated_by) values(p_box_id,p_user_id,coalesce(p_active,true),p_max_active,coalesce(p_priority,0),p_actor_id,p_actor_id)
  on conflict(box_id,user_id) do update set active=excluded.active,max_active=excluded.max_active,priority=excluded.priority,updated_by=p_actor_id,updated_at=now();
  insert into public.aos_wa_routing_events_v1(box_id,event_type,actor_id,payload) values(p_box_id,'box.member_set',p_actor_id,jsonb_build_object('user_id',p_user_id,'active',coalesce(p_active,true),'max_active',p_max_active,'priority',coalesce(p_priority,0)));
  return jsonb_build_object('ok',true,'box_id',p_box_id,'user_id',p_user_id,'active',coalesce(p_active,true));
end
$$;

create or replace function public.aos_wa3_route_v1(p_conversation_id uuid,p_box_id uuid,p_owner_user_id uuid default null,p_actor_id uuid default null,p_reason text default null)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_conv public.aos_wa_conversations_v1%rowtype; v_box public.aos_wa_boxes_v1%rowtype; v_owner uuid:=p_owner_user_id; v_current public.aos_wa_assignments_v1%rowtype; v_assignment uuid; v_cap integer; v_load integer;
begin
  if p_actor_id is not null and not public.aos_wa3_is_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA3_ADMIN_REQUIRED'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.state in ('CLOSED','WON','LOST') then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_TERMINAL'); end if;
  select * into v_box from public.aos_wa_boxes_v1 where id=p_box_id and status='ACTIVE';
  if v_box.id is null then return jsonb_build_object('ok',false,'error','WA3_ACTIVE_BOX_REQUIRED'); end if;
  if v_owner is null and v_box.routing_strategy='LEAST_ACTIVE' then
    select m.user_id into v_owner from public.aos_wa_box_members_v1 m join public.aos_usuarios u on u.id=m.user_id and u.activo is true
    left join lateral (select count(*)::integer active_count from public.aos_wa_assignments_v1 a where a.owner_user_id=m.user_id and a.state='ACTIVE') l on true
    where m.box_id=v_box.id and m.active is true and (m.max_active is null or l.active_count<m.max_active)
    order by l.active_count asc,m.priority desc,m.last_assigned_at asc nulls first,m.user_id asc limit 1;
  end if;
  if v_owner is not null then
    select m.max_active into v_cap from public.aos_wa_box_members_v1 m join public.aos_usuarios u on u.id=m.user_id and u.activo is true where m.box_id=v_box.id and m.user_id=v_owner and m.active is true;
    if not found then return jsonb_build_object('ok',false,'error','WA3_OWNER_NOT_ACTIVE_MEMBER'); end if;
    select count(*) into v_load from public.aos_wa_assignments_v1 where owner_user_id=v_owner and state='ACTIVE' and conversation_id<>p_conversation_id;
    if v_cap is not null and v_load>=v_cap then return jsonb_build_object('ok',false,'error','WA3_CAPACITY_REACHED'); end if;
  end if;
  select * into v_current from public.aos_wa_assignments_v1 where conversation_id=p_conversation_id and state in ('QUEUED','ACTIVE') order by assigned_at desc limit 1 for update;
  if v_current.id is not null and v_current.box_id=v_box.id and v_current.owner_user_id is not distinct from v_owner then return jsonb_build_object('ok',true,'idempotent',true,'assignment_id',v_current.id,'box_id',v_box.id,'owner_user_id',v_owner,'state',v_current.state); end if;
  if v_current.id is not null then update public.aos_wa_assignments_v1 set state='REASSIGNED',released_at=now(),terminal_reason=coalesce(nullif(trim(p_reason),''),'REASSIGNED'),updated_at=now() where id=v_current.id; end if;
  insert into public.aos_wa_assignments_v1(conversation_id,box_id,owner_user_id,state,claimed_at,assigned_by,metadata)
  values(p_conversation_id,v_box.id,v_owner,case when v_owner is null then 'QUEUED' else 'ACTIVE' end,case when v_owner is null then null else now() end,p_actor_id,jsonb_build_object('reason',coalesce(p_reason,''))) returning id into v_assignment;
  if v_owner is not null then update public.aos_wa_box_members_v1 set last_assigned_at=now(),updated_at=now() where box_id=v_box.id and user_id=v_owner; end if;
  update public.aos_wa_conversations_v1 set box_id=v_box.id,owner_user_id=v_owner,state=case when v_owner is null then 'HUMAN_REQUESTED' else 'HUMAN_ACTIVE' end,handoff_requested_at=case when v_owner is null then coalesce(handoff_requested_at,now()) else handoff_requested_at end,human_takeover_at=case when v_owner is null then human_takeover_at else now() end,ownership_version=ownership_version+1,updated_at=now() where id=p_conversation_id;
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,assignment_id,event_type,actor_id,payload) values(p_conversation_id,v_box.id,v_assignment,'conversation.routed',p_actor_id,jsonb_build_object('owner_user_id',v_owner,'reason',coalesce(p_reason,''),'strategy',v_box.routing_strategy));
  return jsonb_build_object('ok',true,'idempotent',false,'assignment_id',v_assignment,'box_id',v_box.id,'owner_user_id',v_owner,'state',case when v_owner is null then 'QUEUED' else 'ACTIVE' end);
end
$$;

create or replace function public.aos_wa3_claim_next_v1(p_box_id uuid,p_actor_id uuid)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_member public.aos_wa_box_members_v1%rowtype; v_assignment public.aos_wa_assignments_v1%rowtype; v_load integer; v_conv uuid;
begin
  select * into v_member from public.aos_wa_box_members_v1 where box_id=p_box_id and user_id=p_actor_id and active is true;
  if v_member.user_id is null then return jsonb_build_object('ok',false,'error','WA3_NOT_BOX_MEMBER'); end if;
  if not exists(select 1 from public.aos_usuarios where id=p_actor_id and activo is true) then return jsonb_build_object('ok',false,'error','WA3_USER_INACTIVE'); end if;
  select count(*) into v_load from public.aos_wa_assignments_v1 where owner_user_id=p_actor_id and state='ACTIVE';
  if v_member.max_active is not null and v_load>=v_member.max_active then return jsonb_build_object('ok',false,'error','WA3_CAPACITY_REACHED'); end if;
  select * into v_assignment from public.aos_wa_assignments_v1 where box_id=p_box_id and state='QUEUED' order by assigned_at asc,id asc limit 1 for update skip locked;
  if v_assignment.id is null then return jsonb_build_object('ok',true,'claimed',false,'reason','NO_WORK'); end if;
  update public.aos_wa_assignments_v1 set owner_user_id=p_actor_id,state='ACTIVE',claimed_at=now(),updated_at=now() where id=v_assignment.id returning conversation_id into v_conv;
  update public.aos_wa_conversations_v1 set owner_user_id=p_actor_id,state='HUMAN_ACTIVE',human_takeover_at=now(),ownership_version=ownership_version+1,updated_at=now() where id=v_conv;
  update public.aos_wa_box_members_v1 set last_assigned_at=now(),updated_at=now() where box_id=p_box_id and user_id=p_actor_id;
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,assignment_id,event_type,actor_id,payload) values(v_conv,p_box_id,v_assignment.id,'conversation.claimed',p_actor_id,'{}'::jsonb);
  return jsonb_build_object('ok',true,'claimed',true,'conversation_id',v_conv,'assignment_id',v_assignment.id);
end
$$;

create or replace function public.aos_wa3_release_v1(p_conversation_id uuid,p_actor_id uuid,p_reason text default null)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_assignment public.aos_wa_assignments_v1%rowtype; v_queue uuid; v_is_admin boolean;
begin
  v_is_admin:=public.aos_wa3_is_admin_v1(p_actor_id);
  select * into v_assignment from public.aos_wa_assignments_v1 where conversation_id=p_conversation_id and state='ACTIVE' order by assigned_at desc limit 1 for update;
  if v_assignment.id is null then
    if exists(select 1 from public.aos_wa_assignments_v1 where conversation_id=p_conversation_id and state='QUEUED') then return jsonb_build_object('ok',true,'idempotent',true,'state','QUEUED'); end if;
    return jsonb_build_object('ok',false,'error','WA3_ACTIVE_ASSIGNMENT_REQUIRED');
  end if;
  if v_assignment.owner_user_id<>p_actor_id and not v_is_admin then return jsonb_build_object('ok',false,'error','WA3_NOT_OWNER'); end if;
  update public.aos_wa_assignments_v1 set state='RELEASED',released_at=now(),terminal_reason=coalesce(nullif(trim(p_reason),''),'RELEASED'),updated_at=now() where id=v_assignment.id;
  insert into public.aos_wa_assignments_v1(conversation_id,box_id,owner_user_id,state,assigned_by,metadata) values(p_conversation_id,v_assignment.box_id,null,'QUEUED',p_actor_id,jsonb_build_object('released_from',v_assignment.id,'reason',coalesce(p_reason,''))) returning id into v_queue;
  update public.aos_wa_conversations_v1 set owner_user_id=null,state='HUMAN_REQUESTED',handoff_requested_at=coalesce(handoff_requested_at,now()),ownership_version=ownership_version+1,updated_at=now() where id=p_conversation_id;
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,assignment_id,event_type,actor_id,payload) values(p_conversation_id,v_assignment.box_id,v_queue,'conversation.released',p_actor_id,jsonb_build_object('previous_assignment_id',v_assignment.id,'reason',coalesce(p_reason,'')));
  return jsonb_build_object('ok',true,'idempotent',false,'state','QUEUED','assignment_id',v_queue);
end
$$;

create or replace function public.aos_wa3_set_mode_v1(p_conversation_id uuid,p_actor_id uuid,p_mode text)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_conv public.aos_wa_conversations_v1%rowtype; v_mode text:=upper(trim(coalesce(p_mode,''))); v_is_admin boolean;
begin
  if v_mode not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA3_MODE_NOT_ALLOWED'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is null then return jsonb_build_object('ok',false,'error','WA3_OWNER_REQUIRED'); end if;
  v_is_admin:=public.aos_wa3_is_admin_v1(p_actor_id);
  if v_conv.owner_user_id<>p_actor_id and not v_is_admin then return jsonb_build_object('ok',false,'error','WA3_NOT_OWNER'); end if;
  update public.aos_wa_conversations_v1 set state=v_mode,ownership_version=ownership_version+1,updated_at=now() where id=p_conversation_id;
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,event_type,actor_id,payload) values(p_conversation_id,v_conv.box_id,'conversation.mode_changed',p_actor_id,jsonb_build_object('from',v_conv.state,'to',v_mode));
  return jsonb_build_object('ok',true,'state',v_mode,'owner_user_id',v_conv.owner_user_id);
end
$$;

create or replace function public.aos_wa3_request_handoff_v1(p_conversation_id uuid,p_reason text default null)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_conv public.aos_wa_conversations_v1%rowtype; v_default uuid; v_result jsonb;
begin
  select * into v_conv from public.aos_wa_conversations_v1 where id=p_conversation_id for update;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is not null and v_conv.state in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',true,'idempotent',true,'state',v_conv.state,'owner_user_id',v_conv.owner_user_id); end if;
  update public.aos_wa_conversations_v1 set state='HUMAN_REQUESTED',handoff_requested_at=coalesce(handoff_requested_at,now()),updated_at=now() where id=p_conversation_id;
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,event_type,actor_id,payload) values(p_conversation_id,v_conv.box_id,'handoff.requested',null,jsonb_build_object('reason',coalesce(p_reason,'')));
  select id into v_default from public.aos_wa_boxes_v1 where status='ACTIVE' and is_default is true limit 1;
  if v_default is not null and not exists(select 1 from public.aos_wa_assignments_v1 where conversation_id=p_conversation_id and state in ('QUEUED','ACTIVE')) then
    v_result:=public.aos_wa3_route_v1(p_conversation_id,v_default,null,null,coalesce(p_reason,'HANDOFF_REQUEST'));
    return v_result || jsonb_build_object('handoff_requested',true);
  end if;
  return jsonb_build_object('ok',true,'handoff_requested',true,'state','HUMAN_REQUESTED','box_id',v_conv.box_id);
end
$$;

create or replace function public.aos_wa3_admin_set_control_v1(p_actor_id uuid,p_auto_routing_enabled boolean default null,p_human_send_enabled boolean default null)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare v_row public.aos_wa_routing_control_v1%rowtype;
begin
  if not public.aos_wa3_is_admin_v1(p_actor_id) then return jsonb_build_object('ok',false,'error','WA3_ADMIN_REQUIRED'); end if;
  update public.aos_wa_routing_control_v1 set auto_routing_enabled=coalesce(p_auto_routing_enabled,auto_routing_enabled),human_send_enabled=coalesce(p_human_send_enabled,human_send_enabled),ai_send_enabled=false,updated_by=p_actor_id,updated_at=now() where id=1 returning * into v_row;
  insert into public.aos_wa_routing_events_v1(event_type,actor_id,payload) values('control.updated',p_actor_id,jsonb_build_object('auto_routing_enabled',v_row.auto_routing_enabled,'human_send_enabled',v_row.human_send_enabled,'ai_send_enabled',false));
  return jsonb_build_object('ok',true,'auto_routing_enabled',v_row.auto_routing_enabled,'human_send_enabled',v_row.human_send_enabled,'ai_send_enabled',false);
end
$$;

create or replace function public.aos_wa3_human_send_authorize_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor jsonb; v_uid uuid; v_conv record; v_enabled boolean;
begin
  v_actor:=public.aos_wa3_actor_v1(p_token);
  if coalesce((v_actor->>'ok')::boolean,false) is not true then return v_actor; end if;
  v_uid:=(v_actor->>'actor_id')::uuid;
  select human_send_enabled into v_enabled from public.aos_wa_routing_control_v1 where id=1;
  if coalesce(v_enabled,false) is not true then return jsonb_build_object('ok',false,'error','WA3_HUMAN_SEND_DISABLED'); end if;
  select c.id,c.contact_number,c.owner_user_id,c.state,c.box_id into v_conv from public.aos_wa_conversations_v1 c where c.id=p_conversation_id;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from v_uid then return jsonb_build_object('ok',false,'error','WA3_NOT_OWNER'); end if;
  if v_conv.state not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA3_HUMAN_MODE_REQUIRED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=v_uid and a.state='ACTIVE') then return jsonb_build_object('ok',false,'error','WA3_ACTIVE_ASSIGNMENT_REQUIRED'); end if;
  return jsonb_build_object('ok',true,'actor_id',v_uid,'conversation_id',v_conv.id,'to_number',v_conv.contact_number,'state',v_conv.state,'box_id',v_conv.box_id);
end
$$;

create or replace function public.aos_wa3_auto_route_new_conversation_v1()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_enabled boolean; v_box uuid; v_result jsonb;
begin
  select auto_routing_enabled into v_enabled from public.aos_wa_routing_control_v1 where id=1;
  if coalesce(v_enabled,false) is not true then return new; end if;
  select id into v_box from public.aos_wa_boxes_v1 where status='ACTIVE' and is_default is true limit 1;
  if v_box is null then return new; end if;
  v_result:=public.aos_wa3_route_v1(new.id,v_box,null,null,'AUTO_DEFAULT');
  if coalesce((v_result->>'ok')::boolean,false) is not true then insert into public.aos_wa_routing_events_v1(conversation_id,box_id,event_type,actor_id,payload) values(new.id,v_box,'auto_route.rejected',null,coalesce(v_result,'{}'::jsonb)); end if;
  return new;
exception when others then
  insert into public.aos_wa_routing_events_v1(conversation_id,box_id,event_type,actor_id,payload) values(new.id,v_box,'auto_route.failed',null,jsonb_build_object('sqlstate',sqlstate));
  return new;
end
$$;
drop trigger if exists trg_aos_wa3_auto_route_new_conversation_v1 on public.aos_wa_conversations_v1;
create trigger trg_aos_wa3_auto_route_new_conversation_v1 after insert on public.aos_wa_conversations_v1 for each row execute function public.aos_wa3_auto_route_new_conversation_v1();

revoke all on function public.aos_wa3_routing_event_append_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_wa3_is_admin_v1(uuid) from public,anon,authenticated;
revoke all on function public.aos_wa3_box_upsert_v1(uuid,uuid,text,text,text,text,boolean,integer) from public,anon,authenticated;
revoke all on function public.aos_wa3_box_member_set_v1(uuid,uuid,uuid,boolean,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_wa3_route_v1(uuid,uuid,uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa3_claim_next_v1(uuid,uuid) from public,anon,authenticated;
revoke all on function public.aos_wa3_release_v1(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa3_set_mode_v1(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa3_request_handoff_v1(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_wa3_admin_set_control_v1(uuid,boolean,boolean) from public,anon,authenticated;
revoke all on function public.aos_wa3_auto_route_new_conversation_v1() from public,anon,authenticated;
revoke all on function public.aos_wa3_actor_v1(text) from public;
revoke all on function public.aos_wa3_human_send_authorize_v1(text,uuid) from public;

grant execute on function public.aos_wa3_is_admin_v1(uuid) to service_role;
grant execute on function public.aos_wa3_box_upsert_v1(uuid,uuid,text,text,text,text,boolean,integer) to service_role;
grant execute on function public.aos_wa3_box_member_set_v1(uuid,uuid,uuid,boolean,integer,integer) to service_role;
grant execute on function public.aos_wa3_route_v1(uuid,uuid,uuid,uuid,text) to service_role;
grant execute on function public.aos_wa3_claim_next_v1(uuid,uuid) to service_role;
grant execute on function public.aos_wa3_release_v1(uuid,uuid,text) to service_role;
grant execute on function public.aos_wa3_set_mode_v1(uuid,uuid,text) to service_role;
grant execute on function public.aos_wa3_request_handoff_v1(uuid,text) to service_role;
grant execute on function public.aos_wa3_admin_set_control_v1(uuid,boolean,boolean) to service_role;
grant execute on function public.aos_wa3_actor_v1(text) to anon,authenticated,service_role;
grant execute on function public.aos_wa3_human_send_authorize_v1(text,uuid) to anon,authenticated,service_role;

comment on table public.aos_wa_boxes_v1 is 'WA-3 governed WhatsApp work boxes. No automatic user grants.';
comment on table public.aos_wa_assignments_v1 is 'WA-3 conversation ownership history. One QUEUED/ACTIVE row max per conversation.';
comment on table public.aos_wa_routing_events_v1 is 'WA-3 append-only audit of box, assignment, takeover, release and control changes.';
comment on function public.aos_wa3_human_send_authorize_v1(text,uuid) is 'Token+2FA+panel+ownership+mode+kill-switch gate for owned human outbound.';
comment on function public.aos_wa3_set_mode_v1(uuid,uuid,text) is 'WA-3 mode lock. AI_ACTIVE is intentionally impossible until WA-4.';

commit;
