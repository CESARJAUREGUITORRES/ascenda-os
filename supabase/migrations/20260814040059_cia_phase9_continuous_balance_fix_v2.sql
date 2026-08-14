-- Phase 9 QA hardening: CONTINUOUS top-up restores the cumulative target mix instead of restarting allocation from priority 1.
create or replace function public.aos_cia_assignment_allocate_internal_v1(p_plan_id uuid,p_run_type text,p_actor_user_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 p record;t record;v_existing jsonb;v_ctx jsonb;v_source_count integer:=0;v_keys text[]:=array[]::text[];v_candidate_count integer:=0;v_target_count integer:=0;
 v_total_limit integer:=0;v_base integer:=0;v_remainder integer:=0;v_floor_sum integer:=0;v_idx integer:=0;v_active integer:=0;v_current_active_total integer:=0;v_total_after integer:=0;v_desired integer:=0;
 v_cap_remaining integer:=0;v_quota integer:=0;v_cursor integer:=0;v_requested integer:=0;v_inserted integer:=0;v_quotas jsonb:='{}'::jsonb;v_run_id uuid:=gen_random_uuid();v_now timestamptz:=clock_timestamp();v_result jsonb;v_run_type text:=upper(coalesce(p_run_type,''));
begin
 if v_run_type not in('INITIAL','TOPUP')then return jsonb_build_object('ok',false,'error','INVALID_RUN_TYPE');end if;
 if p_idempotency_key is null or length(p_idempotency_key)not between 12 and 160 then return jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY');end if;
 if not exists(select 1 from public.aos_usuarios where id=p_actor_user_id and activo=true)then return jsonb_build_object('ok',false,'error','INVALID_ACTOR');end if;
 perform pg_advisory_xact_lock(hashtextextended('aos_cia_assignment_engine_v1',0));
 select result into v_existing from public.aos_cia_assignment_runs where idempotency_key=p_idempotency_key;if v_existing is not null then return v_existing||jsonb_build_object('idempotent',true);end if;
 if v_run_type='INITIAL'then select result into v_existing from public.aos_cia_assignment_runs where plan_id=p_plan_id and run_type='INITIAL'limit 1;if v_existing is not null then return v_existing||jsonb_build_object('idempotent',true);end if;end if;
 select*into p from public.aos_cia_assignment_plans where id=p_plan_id for update;if p.id is null then return jsonb_build_object('ok',false,'error','PLAN_NOT_FOUND');end if;if p.state<>'ACTIVE'then return jsonb_build_object('ok',false,'error','PLAN_NOT_ACTIVE','state',p.state);end if;if v_run_type='TOPUP'and p.topup_policy='NONE'then return jsonb_build_object('ok',false,'error','TOPUP_DISABLED');end if;
 v_ctx:=public.aos_cia_activation_context_summary_v1(p.activation_id);if not coalesce((v_ctx->>'ok')::boolean,false)then return jsonb_build_object('ok',false,'error',coalesce(v_ctx->>'error','CONTEXT_NOT_READY'));end if;if coalesce(v_ctx->>'activation_state','')<>'ACTIVE'then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_ACTIVE');end if;v_source_count:=coalesce((v_ctx->>'assignable_now')::integer,0);
 select coalesce(array_agg(contact_key order by contact_key),array[]::text[])into v_keys from public.aos_cia_assignment_candidate_keys_v1(p_plan_id);v_candidate_count:=coalesce(cardinality(v_keys),0);select count(*)::integer into v_target_count from public.aos_cia_assignment_targets where plan_id=p_plan_id;if v_target_count<1 then return jsonb_build_object('ok',false,'error','NO_TARGETS');end if;
 select count(*)::integer into v_current_active_total from public.aos_cia_assignments where plan_id=p_plan_id and state in('RESERVED','ASSIGNED','IN_PROGRESS');
 if p.topup_policy='CONTINUOUS'then v_total_limit:=v_candidate_count;v_total_after:=v_current_active_total+v_total_limit;
 elsif p.topup_policy='MAINTAIN_TARGET'then v_total_limit:=least(v_candidate_count,coalesce(p.source_limit,v_candidate_count));v_total_after:=v_current_active_total+v_total_limit;
 elsif v_run_type='INITIAL'then v_total_limit:=least(v_candidate_count,coalesce(p.source_limit,v_candidate_count));v_total_after:=v_current_active_total+v_total_limit;
 else v_total_limit:=v_candidate_count;v_total_after:=v_current_active_total+v_total_limit;end if;
 if p.topup_policy='CONTINUOUS'and p.strategy='EQUAL'then v_base:=floor(v_total_after::numeric/v_target_count)::integer;v_remainder:=v_total_after-(v_base*v_target_count);
 elsif p.topup_policy='CONTINUOUS'and p.strategy='PERCENTAGE'then select coalesce(sum(floor(v_total_after*(weight_percent/100.0)))::integer,0)into v_floor_sum from public.aos_cia_assignment_targets where plan_id=p_plan_id;v_remainder:=greatest(v_total_after-v_floor_sum,0);
 elsif p.topup_policy<>'MAINTAIN_TARGET'and p.strategy='EQUAL'then v_base:=floor(v_total_limit::numeric/v_target_count)::integer;v_remainder:=v_total_limit-(v_base*v_target_count);
 elsif p.topup_policy<>'MAINTAIN_TARGET'and p.strategy='PERCENTAGE'then select coalesce(sum(floor(v_total_limit*(weight_percent/100.0)))::integer,0)into v_floor_sum from public.aos_cia_assignment_targets where plan_id=p_plan_id;v_remainder:=greatest(v_total_limit-v_floor_sum,0);end if;
 v_cursor:=0;v_idx:=0;
 for t in select*from public.aos_cia_assignment_targets where plan_id=p_plan_id order by priority,advisor_user_id loop
  v_idx:=v_idx+1;select count(*)::integer into v_active from public.aos_cia_assignments where plan_id=p_plan_id and advisor_user_id=t.advisor_user_id and state in('RESERVED','ASSIGNED','IN_PROGRESS');v_cap_remaining:=case when t.capacity_limit is null then 100000000 else greatest(t.capacity_limit-v_active,0)end;
  if p.topup_policy='MAINTAIN_TARGET'then v_quota:=greatest(coalesce(p.topup_target_per_advisor,0)-v_active,0);
  elsif p.topup_policy='CONTINUOUS'then
    if p.strategy='ONE'then v_desired:=v_active+v_candidate_count;
    elsif p.strategy='EQUAL'then v_desired:=v_base+case when v_idx<=v_remainder then 1 else 0 end;
    elsif p.strategy='PERCENTAGE'then v_desired:=floor(v_total_after*(t.weight_percent/100.0))::integer+case when v_idx<=v_remainder then 1 else 0 end;
    elsif p.strategy='FIXED'then v_desired:=coalesce(t.fixed_quantity,0);else v_desired:=v_active;end if;
    v_quota:=greatest(v_desired-v_active,0);
  elsif p.strategy='ONE'then v_quota:=v_total_limit;
  elsif p.strategy='EQUAL'then v_quota:=v_base+case when v_idx<=v_remainder then 1 else 0 end;
  elsif p.strategy='PERCENTAGE'then v_quota:=floor(v_total_limit*(t.weight_percent/100.0))::integer+case when v_idx<=v_remainder then 1 else 0 end;
  elsif p.strategy='FIXED'then v_quota:=coalesce(t.fixed_quantity,0);else v_quota:=0;end if;
  v_quota:=greatest(least(v_quota,v_cap_remaining,greatest(v_total_limit-v_cursor,0),greatest(v_candidate_count-v_cursor,0)),0);v_quotas:=v_quotas||jsonb_build_object(t.advisor_user_id::text,v_quota);v_cursor:=v_cursor+v_quota;if v_cursor>=v_total_limit then exit;end if;
 end loop;v_requested:=v_cursor;
 v_result:=jsonb_build_object('ok',true,'run_id',v_run_id,'plan_id',p_plan_id,'run_type',v_run_type,'source_available_count',v_source_count,'candidate_count',v_candidate_count,'requested_count',v_requested,'assigned_count',v_requested,'quotas',v_quotas,'active_before',v_current_active_total,'executed_at',v_now);
 insert into public.aos_cia_assignment_runs(id,plan_id,run_type,idempotency_key,source_available_count,candidate_count,requested_count,assigned_count,result,created_by_user_id,created_at)values(v_run_id,p_plan_id,v_run_type,p_idempotency_key,v_source_count,v_candidate_count,v_requested,v_requested,v_result,p_actor_user_id,v_now);
 v_cursor:=0;for t in select*from public.aos_cia_assignment_targets where plan_id=p_plan_id order by priority,advisor_user_id loop v_quota:=coalesce((v_quotas->>t.advisor_user_id::text)::integer,0);if v_quota>0 then insert into public.aos_cia_assignments(run_id,plan_id,activation_id,contact_key,advisor_user_id,state,source_rank,assigned_at,must_start_before,expires_at,created_by_user_id,updated_by_user_id,metadata,created_at,updated_at)select v_run_id,p.id,p.activation_id,k,t.advisor_user_id,'RESERVED',ord::integer,v_now,v_now+make_interval(mins=>p.must_start_minutes),v_now+make_interval(mins=>p.lease_minutes),p_actor_user_id,p_actor_user_id,jsonb_build_object('run_type',v_run_type),v_now,v_now from unnest(v_keys)with ordinality q(k,ord)where ord>v_cursor and ord<=v_cursor+v_quota;get diagnostics v_inserted=row_count;if v_inserted<>v_quota then raise exception'ASSIGNMENT_ALLOCATION_CARDINALITY_MISMATCH expected %, got %',v_quota,v_inserted;end if;v_cursor:=v_cursor+v_quota;end if;if v_cursor>=v_requested then exit;end if;end loop;
 update public.aos_cia_assignments set state='ASSIGNED',updated_by_user_id=p_actor_user_id,updated_at=clock_timestamp()where run_id=v_run_id and state='RESERVED';insert into public.aos_cia_assignment_events(plan_id,event_type,actor_user_id,payload,occurred_at)values(p_plan_id,case when v_run_type='INITIAL'then'INITIAL_RUN'else'TOPUP'end,p_actor_user_id,v_result,v_now);return v_result;
exception when unique_violation then return jsonb_build_object('ok',false,'error','ALLOCATION_CONFLICT');end$$;
revoke all on function public.aos_cia_assignment_allocate_internal_v1(uuid,text,uuid,text) from public,anon,authenticated;
