-- Phase 10 scaling correction: overview health must not re-resolve F8 once per plan.
-- Exact live source/candidate/depletion remains available through F9 GET_PLAN for a selected plan.
create or replace function public.aos_cia_advisor_control_plan_health_v1(
  p_include_terminal boolean default false,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
set search_path=public
as $$
declare v_items jsonb;
begin
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_items
 from (
   select p.id plan_id,p.state,p.strategy,p.ownership_scope,p.topup_policy,p.created_at,
          c.nombre activation_name,c.channel,c.mode,c.purpose,aud.nombre audience_name,
          aes.estado activation_state,
          lr.run_type last_run_type,lr.created_at last_run_at,
          lr.source_available_count last_source_available,
          lr.candidate_count last_candidate_count,
          lr.assigned_count last_assigned_count,
          case when lr.id is null then null else greatest(lr.candidate_count-lr.assigned_count,0) end last_candidate_remaining,
          case when lr.id is null or lr.source_available_count<=0 then null
               else round(((lr.source_available_count-greatest(lr.candidate_count-lr.assigned_count,0))::numeric/lr.source_available_count::numeric)*100,2)
          end depletion_pct_last_run_estimate,
          'LAST_RUN_SNAPSHOT'::text availability_mode,
          jsonb_build_object(
            'total',count(x.id),
            'active',count(x.id) filter(where x.state in('RESERVED','ASSIGNED','IN_PROGRESS')),
            'reserved',count(x.id) filter(where x.state='RESERVED'),
            'assigned',count(x.id) filter(where x.state='ASSIGNED'),
            'in_progress',count(x.id) filter(where x.state='IN_PROGRESS'),
            'completed',count(x.id) filter(where x.state='COMPLETED'),
            'released',count(x.id) filter(where x.state='RELEASED'),
            'expired',count(x.id) filter(where x.state='EXPIRED')
          ) counts,
          coalesce(tg.targets,'[]'::jsonb) targets,
          count(x.id) filter(where x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())::integer overdue_to_start,
          count(x.id) filter(where x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')::integer expiring_60m,
          case when p.state='ACTIVE' and coalesce(aes.estado,'')<>'ACTIVE' then 'BLOCKED_CONTEXT'
               when count(x.id) filter(where x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())>0 then 'ATTENTION'
               when count(x.id) filter(where x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')>0 then 'ATTENTION'
               when lr.id is null then 'NO_RUN'
               when p.state='ACTIVE' and greatest(lr.candidate_count-lr.assigned_count,0)=0 then 'DEPLETED_LAST_RUN'
               else 'OK' end health_state
   from public.aos_cia_assignment_plans p
   join public.aos_audiencia_activaciones aa on aa.id=p.activation_id
   join public.aos_audiencia_activacion_config c on c.activacion_id=p.activation_id
   left join public.aos_audiencia_activacion_estado aes on aes.activacion_id=p.activation_id
   join public.aos_audiencias aud on aud.id=aa.audiencia_id
   left join lateral (
     select r.* from public.aos_cia_assignment_runs r where r.plan_id=p.id order by r.created_at desc,r.id desc limit 1
   ) lr on true
   left join lateral (
     select jsonb_agg(jsonb_build_object(
       'advisor_user_id',t.advisor_user_id,'name',u.nombre,'code',u.codigo_asesor,'priority',t.priority,
       'capacity_limit',t.capacity_limit,'weight_percent',t.weight_percent,'fixed_quantity',t.fixed_quantity
     ) order by t.priority,t.advisor_user_id) targets
     from public.aos_cia_assignment_targets t join public.aos_usuarios u on u.id=t.advisor_user_id where t.plan_id=p.id
   ) tg on true
   left join public.aos_cia_assignments x on x.plan_id=p.id
   where p_include_terminal or p.state not in('CLOSED','CANCELLED')
   group by p.id,p.state,p.strategy,p.ownership_scope,p.topup_policy,p.created_at,c.nombre,c.channel,c.mode,c.purpose,aud.nombre,aes.estado,
            lr.id,lr.run_type,lr.created_at,lr.source_available_count,lr.candidate_count,lr.assigned_count,tg.targets
   order by p.created_at desc
   limit least(greatest(coalesce(p_limit,25),1),50) offset greatest(coalesce(p_offset,0),0)
 ) q;
 return jsonb_build_object('ok',true,'items',v_items,'availability_mode','LAST_RUN_SNAPSHOT','exact_live_detail_action','GET_PLAN','limit',least(greatest(coalesce(p_limit,25),1),50),'offset',greatest(coalesce(p_offset,0),0),'observed_at',statement_timestamp());
end;
$$;
revoke all on function public.aos_cia_advisor_control_plan_health_v1(boolean,integer,integer) from public,anon,authenticated;
grant execute on function public.aos_cia_advisor_control_plan_health_v1(boolean,integer,integer) to service_role;
