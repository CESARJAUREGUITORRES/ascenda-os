create or replace function public.aos_cia_assignment_plan_guard_v1()
returns trigger language plpgsql set search_path=public as $$
begin
  if tg_op='DELETE' then raise exception 'ASSIGNMENT_PLAN_IMMUTABLE_DELETE'; end if;
  if tg_op='INSERT' then if new.state <> 'DRAFT' then raise exception 'ASSIGNMENT_PLAN_MUST_START_DRAFT'; end if; return new; end if;
  if old.state in ('CLOSED','CANCELLED') then raise exception 'ASSIGNMENT_PLAN_TERMINAL'; end if;
  if new.id is distinct from old.id or new.activation_id is distinct from old.activation_id or new.strategy is distinct from old.strategy or new.ownership_scope is distinct from old.ownership_scope or new.source_limit is distinct from old.source_limit or new.lease_minutes is distinct from old.lease_minutes or new.must_start_minutes is distinct from old.must_start_minutes or new.topup_policy is distinct from old.topup_policy or new.topup_target_per_advisor is distinct from old.topup_target_per_advisor or new.allow_reassign_released is distinct from old.allow_reassign_released or new.allow_reassign_expired is distinct from old.allow_reassign_expired or new.idempotency_key is distinct from old.idempotency_key or new.created_by_user_id is distinct from old.created_by_user_id or new.metadata is distinct from old.metadata or new.created_at is distinct from old.created_at then raise exception 'ASSIGNMENT_PLAN_CONFIG_IMMUTABLE'; end if;
  if new.state = old.state then raise exception 'ASSIGNMENT_PLAN_NO_STATE_CHANGE'; end if;
  if not ((old.state='DRAFT' and new.state in ('ACTIVE','CANCELLED')) or (old.state='ACTIVE' and new.state in ('PAUSED','CLOSED','CANCELLED')) or (old.state='PAUSED' and new.state in ('ACTIVE','CLOSED','CANCELLED'))) then raise exception 'ASSIGNMENT_PLAN_INVALID_TRANSITION:%->%',old.state,new.state; end if;
  new.updated_at:=clock_timestamp();
  if new.state='ACTIVE' and old.state='DRAFT' then new.activated_at:=coalesce(new.activated_at,clock_timestamp()); end if;
  if new.state='PAUSED' then new.paused_at:=coalesce(new.paused_at,clock_timestamp()); end if;
  if new.state='CLOSED' then new.closed_at:=coalesce(new.closed_at,clock_timestamp()); end if;
  if new.state='CANCELLED' then new.cancelled_at:=coalesce(new.cancelled_at,clock_timestamp()); end if;
  return new;
end$$;
drop trigger if exists trg_cia_assignment_plan_guard_v1 on public.aos_cia_assignment_plans;
create trigger trg_cia_assignment_plan_guard_v1 before insert or update or delete on public.aos_cia_assignment_plans for each row execute function public.aos_cia_assignment_plan_guard_v1();

create or replace function public.aos_cia_assignment_target_guard_v1()
returns trigger language plpgsql set search_path=public as $$
declare p record; u record;
begin
  if tg_op in ('UPDATE','DELETE') then raise exception 'ASSIGNMENT_TARGET_IMMUTABLE'; end if;
  select strategy,state into p from public.aos_cia_assignment_plans where id=new.plan_id;
  if p.state is null then raise exception 'ASSIGNMENT_PLAN_NOT_FOUND'; end if;
  if p.state<>'DRAFT' then raise exception 'ASSIGNMENT_TARGET_PLAN_NOT_DRAFT'; end if;
  select id,activo,lower(coalesce(rol,'')) rol into u from public.aos_usuarios where id=new.advisor_user_id;
  if u.id is null or not u.activo or u.rol<>'asesor' then raise exception 'ASSIGNMENT_TARGET_INVALID_ADVISOR'; end if;
  if p.strategy in ('ONE','EQUAL') and (new.weight_percent is not null or new.fixed_quantity is not null) then raise exception 'ASSIGNMENT_TARGET_FIELD_MISMATCH'; end if;
  if p.strategy='PERCENTAGE' and (new.weight_percent is null or new.fixed_quantity is not null) then raise exception 'ASSIGNMENT_TARGET_FIELD_MISMATCH'; end if;
  if p.strategy='FIXED' and (new.fixed_quantity is null or new.weight_percent is not null) then raise exception 'ASSIGNMENT_TARGET_FIELD_MISMATCH'; end if;
  return new;
end$$;
drop trigger if exists trg_cia_assignment_target_guard_v1 on public.aos_cia_assignment_targets;
create trigger trg_cia_assignment_target_guard_v1 before insert or update or delete on public.aos_cia_assignment_targets for each row execute function public.aos_cia_assignment_target_guard_v1();

create or replace function public.aos_cia_assignment_append_only_guard_v1() returns trigger language plpgsql set search_path=public as $$ begin raise exception 'ASSIGNMENT_APPEND_ONLY'; end $$;
drop trigger if exists trg_cia_assignment_runs_append_only_v1 on public.aos_cia_assignment_runs;
create trigger trg_cia_assignment_runs_append_only_v1 before update or delete on public.aos_cia_assignment_runs for each row execute function public.aos_cia_assignment_append_only_guard_v1();
drop trigger if exists trg_cia_assignment_events_append_only_v1 on public.aos_cia_assignment_events;
create trigger trg_cia_assignment_events_append_only_v1 before update or delete on public.aos_cia_assignment_events for each row execute function public.aos_cia_assignment_append_only_guard_v1();

create or replace function public.aos_cia_assignment_lease_guard_v1()
returns trigger language plpgsql set search_path=public as $$
declare p record;
begin
  if tg_op='DELETE' then raise exception 'ASSIGNMENT_LEASE_IMMUTABLE_DELETE'; end if;
  select activation_id,ownership_scope,state into p from public.aos_cia_assignment_plans where id=new.plan_id;
  if p.activation_id is null then raise exception 'ASSIGNMENT_PLAN_NOT_FOUND'; end if;
  if new.activation_id<>p.activation_id then raise exception 'ASSIGNMENT_ACTIVATION_MISMATCH'; end if;
  if not exists(select 1 from public.aos_cia_assignment_targets t where t.plan_id=new.plan_id and t.advisor_user_id=new.advisor_user_id) then raise exception 'ASSIGNMENT_ADVISOR_NOT_TARGET'; end if;
  if tg_op='INSERT' then
    if new.state<>'RESERVED' then raise exception 'ASSIGNMENT_LEASE_MUST_START_RESERVED'; end if;
    if p.state<>'ACTIVE' then raise exception 'ASSIGNMENT_PLAN_NOT_ACTIVE'; end if;
    if new.must_start_before<=new.assigned_at or new.expires_at<=new.assigned_at then raise exception 'ASSIGNMENT_INVALID_DEADLINE'; end if;
    if new.started_at is not null or new.completed_at is not null or new.released_at is not null or new.expired_at is not null then raise exception 'ASSIGNMENT_INVALID_INITIAL_TIMESTAMPS'; end if;
  else
    if new.id is distinct from old.id or new.run_id is distinct from old.run_id or new.plan_id is distinct from old.plan_id or new.activation_id is distinct from old.activation_id or new.contact_key is distinct from old.contact_key or new.advisor_user_id is distinct from old.advisor_user_id or new.source_rank is distinct from old.source_rank or new.assigned_at is distinct from old.assigned_at or new.must_start_before is distinct from old.must_start_before or new.expires_at is distinct from old.expires_at or new.created_by_user_id is distinct from old.created_by_user_id or new.metadata is distinct from old.metadata or new.created_at is distinct from old.created_at then raise exception 'ASSIGNMENT_LEASE_IDENTITY_IMMUTABLE'; end if;
    if old.state in ('COMPLETED','RELEASED','EXPIRED') then raise exception 'ASSIGNMENT_LEASE_TERMINAL'; end if;
    if new.state=old.state then raise exception 'ASSIGNMENT_LEASE_NO_STATE_CHANGE'; end if;
    if not ((old.state='RESERVED' and new.state in ('ASSIGNED','RELEASED','EXPIRED')) or (old.state='ASSIGNED' and new.state in ('IN_PROGRESS','COMPLETED','RELEASED','EXPIRED')) or (old.state='IN_PROGRESS' and new.state in ('COMPLETED','RELEASED','EXPIRED'))) then raise exception 'ASSIGNMENT_LEASE_INVALID_TRANSITION:%->%',old.state,new.state; end if;
    new.updated_at:=clock_timestamp();
    if new.state='IN_PROGRESS' then new.started_at:=coalesce(new.started_at,clock_timestamp()); end if;
    if new.state='COMPLETED' then new.completed_at:=coalesce(new.completed_at,clock_timestamp()); end if;
    if new.state='RELEASED' then new.released_at:=coalesce(new.released_at,clock_timestamp()); end if;
    if new.state='EXPIRED' then new.expired_at:=coalesce(new.expired_at,clock_timestamp()); end if;
  end if;
  if new.state in ('RESERVED','ASSIGNED','IN_PROGRESS') then
    if p.ownership_scope='GLOBAL' then
      if exists(select 1 from public.aos_cia_assignments x where x.contact_key=new.contact_key and x.state in ('RESERVED','ASSIGNED','IN_PROGRESS') and x.id<>new.id) then raise exception 'ASSIGNMENT_GLOBAL_OWNERSHIP_CONFLICT'; end if;
    else
      if exists(select 1 from public.aos_cia_assignments x join public.aos_cia_assignment_plans xp on xp.id=x.plan_id where x.contact_key=new.contact_key and x.state in ('RESERVED','ASSIGNED','IN_PROGRESS') and x.id<>new.id and xp.ownership_scope='GLOBAL') then raise exception 'ASSIGNMENT_GLOBAL_OWNERSHIP_CONFLICT'; end if;
    end if;
  end if;
  return new;
end$$;
drop trigger if exists trg_cia_assignment_lease_guard_v1 on public.aos_cia_assignments;
create trigger trg_cia_assignment_lease_guard_v1 before insert or update or delete on public.aos_cia_assignments for each row execute function public.aos_cia_assignment_lease_guard_v1();

create or replace function public.aos_cia_assignment_plan_event_emit_v1() returns trigger language plpgsql set search_path=public as $$
declare ev text;
begin
  if tg_op='INSERT' then ev:='CREATE_PLAN'; elsif new.state<>old.state then ev:=case when new.state='ACTIVE' and old.state='DRAFT' then 'ACTIVATE_PLAN' when new.state='PAUSED' then 'PAUSE_PLAN' when new.state='ACTIVE' and old.state='PAUSED' then 'RESUME_PLAN' when new.state='CLOSED' then 'CLOSE_PLAN' when new.state='CANCELLED' then 'CANCEL_PLAN' else 'PLAN_STATE' end; else return new; end if;
  insert into public.aos_cia_assignment_events(plan_id,event_type,actor_user_id,payload,occurred_at) values(new.id,ev,case when tg_op='INSERT' then new.created_by_user_id else new.updated_by_user_id end,jsonb_build_object('state',new.state),clock_timestamp()); return new;
end$$;
drop trigger if exists trg_cia_assignment_plan_event_emit_v1 on public.aos_cia_assignment_plans;
create trigger trg_cia_assignment_plan_event_emit_v1 after insert or update on public.aos_cia_assignment_plans for each row execute function public.aos_cia_assignment_plan_event_emit_v1();

create or replace function public.aos_cia_assignment_lease_event_emit_v1() returns trigger language plpgsql set search_path=public as $$
declare ev text;
begin
  if tg_op='INSERT' then ev:='RESERVE'; elsif new.state<>old.state then ev:=case when new.state='ASSIGNED' then 'ASSIGN' when new.state='IN_PROGRESS' then 'START' when new.state='COMPLETED' then 'COMPLETE' when new.state='RELEASED' then 'RELEASE' when new.state='EXPIRED' then 'EXPIRE' else 'LEASE_STATE' end; else return new; end if;
  insert into public.aos_cia_assignment_events(plan_id,assignment_id,event_type,actor_user_id,payload,occurred_at) values(new.plan_id,new.id,ev,case when tg_op='INSERT' then new.created_by_user_id else new.updated_by_user_id end,jsonb_build_object('state',new.state,'advisor_user_id',new.advisor_user_id,'contact_key',new.contact_key,'reason',new.terminal_reason),clock_timestamp()); return new;
end$$;
drop trigger if exists trg_cia_assignment_lease_event_emit_v1 on public.aos_cia_assignments;
create trigger trg_cia_assignment_lease_event_emit_v1 after insert or update on public.aos_cia_assignments for each row execute function public.aos_cia_assignment_lease_event_emit_v1();
