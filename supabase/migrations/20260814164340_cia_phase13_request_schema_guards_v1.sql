create table public.aos_cia_requests (
  id uuid primary key default gen_random_uuid(),
  request_type text not null,
  state text not null default 'PENDING',
  requester_user_id uuid not null references public.aos_usuarios(id),
  assignment_id uuid not null references public.aos_cia_assignments(id),
  plan_id uuid not null,
  activation_id uuid not null,
  owner_snapshot_user_id uuid not null,
  assignment_state_snapshot text not null,
  assignment_expires_at_snapshot timestamptz not null,
  reason text not null,
  request_payload jsonb not null default '{}'::jsonb,
  policy_snapshot jsonb not null default '{}'::jsonb,
  request_expires_at timestamptz not null,
  approved_by_user_id uuid references public.aos_usuarios(id),
  approved_at timestamptz,
  rejected_by_user_id uuid references public.aos_usuarios(id),
  rejected_at timestamptz,
  decision_reason text,
  executed_by_user_id uuid references public.aos_usuarios(id),
  executed_at timestamptz,
  execution_result jsonb,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint aos_cia_requests_type_chk check (request_type in ('RELEASE_ASSIGNMENT')),
  constraint aos_cia_requests_state_chk check (state in ('PENDING','APPROVED','REJECTED','EXPIRED','EXECUTED')),
  constraint aos_cia_requests_reason_chk check (length(btrim(reason)) between 3 and 1000),
  constraint aos_cia_requests_expiry_chk check (request_expires_at > created_at)
);

create unique index aos_cia_requests_open_unique_v1
  on public.aos_cia_requests(assignment_id,request_type)
  where state in ('PENDING','APPROVED');
create index aos_cia_requests_requester_created_v1
  on public.aos_cia_requests(requester_user_id,created_at desc);
create index aos_cia_requests_state_created_v1
  on public.aos_cia_requests(state,created_at desc);
create index aos_cia_requests_assignment_v1
  on public.aos_cia_requests(assignment_id,created_at desc);

create table public.aos_cia_request_events (
  id bigserial primary key,
  request_id uuid not null references public.aos_cia_requests(id),
  event_type text not null,
  from_state text,
  to_state text not null,
  actor_user_id uuid references public.aos_usuarios(id),
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default statement_timestamp()
);
create index aos_cia_request_events_request_v1
  on public.aos_cia_request_events(request_id,occurred_at,id);

alter table public.aos_cia_requests enable row level security;
alter table public.aos_cia_request_events enable row level security;
revoke all on table public.aos_cia_requests from anon, authenticated;
revoke all on table public.aos_cia_request_events from anon, authenticated;
revoke all on sequence public.aos_cia_request_events_id_seq from anon, authenticated;

create or replace function public.aos_cia_request_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $function$
declare
  a record;
begin
  if tg_op='DELETE' then
    raise exception 'CIA_REQUEST_IMMUTABLE_DELETE';
  end if;

  if new.request_type not in ('RELEASE_ASSIGNMENT') then
    raise exception 'CIA_REQUEST_TYPE_BLOCKED';
  end if;

  if tg_op='INSERT' then
    if new.state <> 'PENDING' then raise exception 'CIA_REQUEST_MUST_START_PENDING'; end if;
    if new.approved_by_user_id is not null or new.approved_at is not null
       or new.rejected_by_user_id is not null or new.rejected_at is not null
       or new.executed_by_user_id is not null or new.executed_at is not null
       or new.execution_result is not null then
      raise exception 'CIA_REQUEST_INVALID_INITIAL_DECISION';
    end if;
    if not exists (
      select 1 from public.aos_usuarios u
      where u.id=new.requester_user_id and u.activo=true and lower(coalesce(u.rol,''))='asesor'
    ) then raise exception 'CIA_REQUEST_INVALID_REQUESTER'; end if;

    select x.id,x.plan_id,x.activation_id,x.advisor_user_id,x.state,x.expires_at
      into a
    from public.aos_cia_assignments x
    where x.id=new.assignment_id;
    if a.id is null then raise exception 'CIA_REQUEST_ASSIGNMENT_NOT_FOUND'; end if;
    if a.advisor_user_id<>new.requester_user_id or new.owner_snapshot_user_id<>a.advisor_user_id then
      raise exception 'CIA_REQUEST_NOT_OWNED';
    end if;
    if a.state not in ('ASSIGNED','IN_PROGRESS') or a.expires_at<=statement_timestamp() then
      raise exception 'CIA_REQUEST_ASSIGNMENT_NOT_REQUESTABLE';
    end if;
    if new.plan_id<>a.plan_id or new.activation_id<>a.activation_id
       or new.assignment_state_snapshot<>a.state
       or new.assignment_expires_at_snapshot<>a.expires_at then
      raise exception 'CIA_REQUEST_SNAPSHOT_MISMATCH';
    end if;
    if new.request_expires_at>a.expires_at or new.request_expires_at>statement_timestamp()+interval '24 hours' then
      raise exception 'CIA_REQUEST_EXPIRY_OUT_OF_BOUNDS';
    end if;
  else
    if new.id is distinct from old.id
       or new.request_type is distinct from old.request_type
       or new.requester_user_id is distinct from old.requester_user_id
       or new.assignment_id is distinct from old.assignment_id
       or new.plan_id is distinct from old.plan_id
       or new.activation_id is distinct from old.activation_id
       or new.owner_snapshot_user_id is distinct from old.owner_snapshot_user_id
       or new.assignment_state_snapshot is distinct from old.assignment_state_snapshot
       or new.assignment_expires_at_snapshot is distinct from old.assignment_expires_at_snapshot
       or new.reason is distinct from old.reason
       or new.request_payload is distinct from old.request_payload
       or new.policy_snapshot is distinct from old.policy_snapshot
       or new.request_expires_at is distinct from old.request_expires_at
       or new.created_at is distinct from old.created_at then
      raise exception 'CIA_REQUEST_IDENTITY_IMMUTABLE';
    end if;
    if old.state in ('REJECTED','EXPIRED','EXECUTED') then
      raise exception 'CIA_REQUEST_TERMINAL';
    end if;
    if new.state=old.state then raise exception 'CIA_REQUEST_NO_STATE_CHANGE'; end if;
    if not ((old.state='PENDING' and new.state in ('APPROVED','REJECTED','EXPIRED'))
         or (old.state='APPROVED' and new.state in ('EXECUTED','EXPIRED'))) then
      raise exception 'CIA_REQUEST_INVALID_TRANSITION:%->%',old.state,new.state;
    end if;

    if new.state='APPROVED' then
      if new.approved_by_user_id is null or new.approved_at is null then raise exception 'CIA_REQUEST_APPROVER_REQUIRED'; end if;
      if not exists(select 1 from public.aos_usuarios u where u.id=new.approved_by_user_id and u.activo=true and lower(coalesce(u.rol,''))='admin') then
        raise exception 'CIA_REQUEST_INVALID_APPROVER';
      end if;
      if new.rejected_by_user_id is not null or new.rejected_at is not null or new.executed_by_user_id is not null or new.executed_at is not null then
        raise exception 'CIA_REQUEST_APPROVAL_FIELDS_INVALID';
      end if;
    elsif new.state='REJECTED' then
      if new.rejected_by_user_id is null or new.rejected_at is null then raise exception 'CIA_REQUEST_REJECTOR_REQUIRED'; end if;
      if not exists(select 1 from public.aos_usuarios u where u.id=new.rejected_by_user_id and u.activo=true and lower(coalesce(u.rol,''))='admin') then
        raise exception 'CIA_REQUEST_INVALID_REJECTOR';
      end if;
      if new.approved_by_user_id is not null or new.approved_at is not null or new.executed_by_user_id is not null or new.executed_at is not null then
        raise exception 'CIA_REQUEST_REJECTION_FIELDS_INVALID';
      end if;
    elsif new.state='EXECUTED' then
      if new.approved_by_user_id is null or new.approved_at is null or new.executed_by_user_id is null or new.executed_at is null or new.execution_result is null then
        raise exception 'CIA_REQUEST_EXECUTION_FIELDS_REQUIRED';
      end if;
      if not exists(select 1 from public.aos_usuarios u where u.id=new.executed_by_user_id and u.activo=true and lower(coalesce(u.rol,''))='admin') then
        raise exception 'CIA_REQUEST_INVALID_EXECUTOR';
      end if;
      if new.rejected_by_user_id is not null or new.rejected_at is not null then raise exception 'CIA_REQUEST_EXECUTION_REJECTED'; end if;
    elsif new.state='EXPIRED' then
      if new.executed_by_user_id is not null or new.executed_at is not null then raise exception 'CIA_REQUEST_EXPIRED_EXECUTED'; end if;
    end if;
    new.updated_at:=clock_timestamp();
  end if;
  return new;
end
$function$;

create trigger trg_cia_request_guard_v1
before insert or update or delete on public.aos_cia_requests
for each row execute function public.aos_cia_request_guard_v1();

create or replace function public.aos_cia_request_event_immutable_v1()
returns trigger
language plpgsql
set search_path=public
as $function$
begin
  raise exception 'CIA_REQUEST_EVENT_APPEND_ONLY';
end
$function$;
create trigger trg_cia_request_event_immutable_v1
before update or delete on public.aos_cia_request_events
for each row execute function public.aos_cia_request_event_immutable_v1();

create or replace function public.aos_cia_request_event_emit_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_actor uuid;
  v_type text;
begin
  if tg_op='INSERT' then
    v_type:='CREATED'; v_actor:=new.requester_user_id;
    insert into public.aos_cia_request_events(request_id,event_type,from_state,to_state,actor_user_id,payload)
    values(new.id,v_type,null,new.state,v_actor,jsonb_build_object('request_type',new.request_type));
  elsif new.state is distinct from old.state then
    v_type:=new.state;
    v_actor:=case new.state
      when 'APPROVED' then new.approved_by_user_id
      when 'REJECTED' then new.rejected_by_user_id
      when 'EXECUTED' then new.executed_by_user_id
      else null end;
    insert into public.aos_cia_request_events(request_id,event_type,from_state,to_state,actor_user_id,payload)
    values(new.id,v_type,old.state,new.state,v_actor,jsonb_build_object('request_type',new.request_type,'decision_reason',new.decision_reason));
  end if;
  return new;
end
$function$;
create trigger trg_cia_request_event_emit_v1
after insert or update of state on public.aos_cia_requests
for each row execute function public.aos_cia_request_event_emit_v1();

revoke all on function public.aos_cia_request_guard_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_request_event_immutable_v1() from public, anon, authenticated;
revoke all on function public.aos_cia_request_event_emit_v1() from public, anon, authenticated;
