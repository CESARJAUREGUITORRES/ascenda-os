create or replace function public.aos_cia_assignment_plan_guard_v1()
returns trigger language plpgsql set search_path=public as $$
declare v_targets integer;v_valid integer;v_sum numeric;v_active integer;
begin
 if tg_op='DELETE'then raise exception'ASSIGNMENT_PLAN_IMMUTABLE_DELETE';end if;
 if tg_op='INSERT'then if new.state<>'DRAFT'then raise exception'ASSIGNMENT_PLAN_MUST_START_DRAFT';end if;return new;end if;
 if old.state in('CLOSED','CANCELLED')then raise exception'ASSIGNMENT_PLAN_TERMINAL';end if;
 if new.id is distinct from old.id or new.activation_id is distinct from old.activation_id or new.strategy is distinct from old.strategy or new.ownership_scope is distinct from old.ownership_scope or new.source_limit is distinct from old.source_limit or new.lease_minutes is distinct from old.lease_minutes or new.must_start_minutes is distinct from old.must_start_minutes or new.topup_policy is distinct from old.topup_policy or new.topup_target_per_advisor is distinct from old.topup_target_per_advisor or new.allow_reassign_released is distinct from old.allow_reassign_released or new.allow_reassign_expired is distinct from old.allow_reassign_expired or new.idempotency_key is distinct from old.idempotency_key or new.created_by_user_id is distinct from old.created_by_user_id or new.metadata is distinct from old.metadata or new.created_at is distinct from old.created_at then raise exception'ASSIGNMENT_PLAN_CONFIG_IMMUTABLE';end if;
 if new.state=old.state then raise exception'ASSIGNMENT_PLAN_NO_STATE_CHANGE';end if;
 if not((old.state='DRAFT'and new.state in('ACTIVE','CANCELLED'))or(old.state='ACTIVE'and new.state in('PAUSED','CLOSED','CANCELLED'))or(old.state='PAUSED'and new.state in('ACTIVE','CLOSED','CANCELLED')))then raise exception'ASSIGNMENT_PLAN_INVALID_TRANSITION:%->%',old.state,new.state;end if;
 if old.state='DRAFT'and new.state='ACTIVE'then
  select count(*)::integer,count(*)filter(where u.id is not null and u.activo=true and lower(coalesce(u.rol,''))='asesor')::integer,coalesce(round(sum(t.weight_percent),4),0) into v_targets,v_valid,v_sum from public.aos_cia_assignment_targets t left join public.aos_usuarios u on u.id=t.advisor_user_id where t.plan_id=old.id;
  if v_targets<1 then raise exception'ASSIGNMENT_PLAN_NO_TARGETS';end if;if v_valid<>v_targets then raise exception'ASSIGNMENT_TARGET_INACTIVE_AT_ACTIVATION';end if;if old.strategy='ONE'and v_targets<>1 then raise exception'ASSIGNMENT_ONE_REQUIRES_ONE_TARGET';end if;if old.strategy='PERCENTAGE'and v_sum<>100.0000 then raise exception'ASSIGNMENT_PERCENTAGES_MUST_SUM_100';end if;
 end if;
 if new.state in('CLOSED','CANCELLED')then select count(*)::integer into v_active from public.aos_cia_assignments x where x.plan_id=old.id and x.state in('RESERVED','ASSIGNED','IN_PROGRESS');if v_active>0 then raise exception'ASSIGNMENT_PLAN_HAS_ACTIVE_LEASES';end if;end if;
 new.updated_at:=clock_timestamp();if new.state='ACTIVE'and old.state='DRAFT'then new.activated_at:=coalesce(new.activated_at,clock_timestamp());end if;if new.state='PAUSED'then new.paused_at:=coalesce(new.paused_at,clock_timestamp());end if;if new.state='CLOSED'then new.closed_at:=coalesce(new.closed_at,clock_timestamp());end if;if new.state='CANCELLED'then new.cancelled_at:=coalesce(new.cancelled_at,clock_timestamp());end if;return new;
end$$;
