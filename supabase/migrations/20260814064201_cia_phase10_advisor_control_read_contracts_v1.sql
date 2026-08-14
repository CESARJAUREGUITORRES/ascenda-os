create or replace function public.aos_cia_advisor_control_overview_v1()
returns jsonb
language sql
stable
set search_path=public
as $$
with advisors as (
  select u.id advisor_user_id,u.nombre advisor_name,u.codigo_asesor advisor_code,u.area
  from public.aos_usuarios u
  where u.activo=true and lower(coalesce(u.rol,''))='asesor'
), wl as (
  select x.advisor_user_id,
    count(*) filter(where x.state in('RESERVED','ASSIGNED','IN_PROGRESS'))::integer active,
    count(*) filter(where x.state='RESERVED')::integer reserved,
    count(*) filter(where x.state='ASSIGNED')::integer assigned,
    count(*) filter(where x.state='IN_PROGRESS')::integer in_progress,
    count(*) filter(where x.state='COMPLETED')::integer completed,
    count(*) filter(where x.state='RELEASED')::integer released,
    count(*) filter(where x.state='EXPIRED')::integer expired,
    count(distinct x.plan_id) filter(where x.state in('RESERVED','ASSIGNED','IN_PROGRESS'))::integer active_plans,
    count(*) filter(where x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())::integer overdue_to_start,
    count(*) filter(where x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')::integer expiring_60m,
    min(x.assigned_at) filter(where x.state in('RESERVED','ASSIGNED','IN_PROGRESS')) oldest_active_at
  from public.aos_cia_assignments x
  group by x.advisor_user_id
), cap as (
  select t.advisor_user_id,
    count(*)::integer open_target_count,
    count(*) filter(where t.capacity_limit is not null)::integer bounded_target_count,
    count(*) filter(where t.capacity_limit is null)::integer unbounded_target_count,
    coalesce(sum(t.capacity_limit) filter(where t.capacity_limit is not null),0)::integer capacity_known,
    count(distinct t.plan_id)::integer target_open_plans
  from public.aos_cia_assignment_targets t
  join public.aos_cia_assignment_plans p on p.id=t.plan_id and p.state in('ACTIVE','PAUSED')
  group by t.advisor_user_id
), advisor_rows as (
  select a.*,
    coalesce(w.active,0) active,coalesce(w.reserved,0) reserved,coalesce(w.assigned,0) assigned,
    coalesce(w.in_progress,0) in_progress,coalesce(w.completed,0) completed,coalesce(w.released,0) released,
    coalesce(w.expired,0) expired,coalesce(w.active_plans,0) active_plans,
    coalesce(w.overdue_to_start,0) overdue_to_start,coalesce(w.expiring_60m,0) expiring_60m,w.oldest_active_at,
    coalesce(c.open_target_count,0) open_target_count,coalesce(c.bounded_target_count,0) bounded_target_count,
    coalesce(c.unbounded_target_count,0) unbounded_target_count,coalesce(c.capacity_known,0) capacity_known,
    coalesce(c.target_open_plans,0) target_open_plans,
    case when coalesce(c.open_target_count,0)=0 then 'NO_OPEN_PLANS'
         when coalesce(c.unbounded_target_count,0)=0 then 'BOUNDED'
         when coalesce(c.bounded_target_count,0)=0 then 'UNBOUNDED'
         else 'MIXED' end capacity_mode,
    case when coalesce(c.open_target_count,0)>0 and coalesce(c.unbounded_target_count,0)=0 and coalesce(c.capacity_known,0)>0
         then round((coalesce(w.active,0)::numeric/c.capacity_known::numeric)*100,2)
         else null end utilization_pct,
    case when coalesce(c.open_target_count,0)>0 and coalesce(c.unbounded_target_count,0)=0 and coalesce(c.capacity_known,0)>0
         then greatest(c.capacity_known-coalesce(w.active,0),0)
         else null end capacity_remaining
  from advisors a left join wl w using(advisor_user_id) left join cap c using(advisor_user_id)
), plans as (
  select count(*)::integer total,
    count(*) filter(where state='DRAFT')::integer draft,
    count(*) filter(where state='ACTIVE')::integer active,
    count(*) filter(where state='PAUSED')::integer paused,
    count(*) filter(where state in('DRAFT','ACTIVE','PAUSED'))::integer open,
    count(*) filter(where state='CLOSED')::integer closed,
    count(*) filter(where state='CANCELLED')::integer cancelled
  from public.aos_cia_assignment_plans
)
select jsonb_build_object(
  'ok',true,
  'advisors',coalesce((select jsonb_agg(to_jsonb(r) order by r.active desc,r.advisor_name) from advisor_rows r),'[]'::jsonb),
  'totals',jsonb_build_object(
    'advisors',(select count(*) from advisor_rows),
    'active_ownership',coalesce((select sum(active) from advisor_rows),0),
    'assigned',coalesce((select sum(assigned) from advisor_rows),0),
    'in_progress',coalesce((select sum(in_progress) from advisor_rows),0),
    'completed',coalesce((select sum(completed) from advisor_rows),0),
    'released',coalesce((select sum(released) from advisor_rows),0),
    'expired',coalesce((select sum(expired) from advisor_rows),0),
    'overdue_to_start',coalesce((select sum(overdue_to_start) from advisor_rows),0),
    'expiring_60m',coalesce((select sum(expiring_60m) from advisor_rows),0),
    'bounded_over_capacity',coalesce((select count(*) from advisor_rows where capacity_mode='BOUNDED' and active>capacity_known),0),
    'plans',(select to_jsonb(p) from plans p)
  ),
  'observed_at',statement_timestamp()
);
$$;

create or replace function public.aos_cia_advisor_control_advisor_detail_v1(
  p_advisor_user_id uuid,
  p_state text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
set search_path=public
as $$
declare v_user record;v_summary jsonb;v_items jsonb;v_plans jsonb;v_state text:=nullif(upper(coalesce(p_state,'')),'');
begin
 select id,nombre,codigo_asesor,area,activo,rol into v_user from public.aos_usuarios where id=p_advisor_user_id;
 if v_user.id is null then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_FOUND');end if;
 select q into v_summary from (
   select to_jsonb(x) q
   from jsonb_array_elements(coalesce(public.aos_cia_advisor_control_overview_v1()->'advisors','[]'::jsonb)) x
   where (x->>'advisor_user_id')::uuid=p_advisor_user_id limit 1
 ) s;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.assigned_at desc,q.assignment_id),'[]'::jsonb) into v_items
 from (
   select x.id assignment_id,x.plan_id,x.activation_id,x.contact_key,x.state,x.source_rank,x.assigned_at,x.must_start_before,x.expires_at,
          x.started_at,x.completed_at,x.released_at,x.expired_at,x.terminal_reason,
          p.state plan_state,p.strategy,p.ownership_scope,c.nombre activation_name,c.channel,c.mode,c.purpose,aud.nombre audience_name,
          case when x.state='ASSIGNED' and x.must_start_before<=clock_timestamp() then 'OVERDUE_TO_START'
               when x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes' then 'EXPIRING_60M'
               else 'OK' end deadline_status,
          round(extract(epoch from(x.expires_at-clock_timestamp()))/60.0,1) minutes_to_expiry
   from public.aos_cia_assignments x
   join public.aos_cia_assignment_plans p on p.id=x.plan_id
   join public.aos_audiencia_activacion_config c on c.activacion_id=x.activation_id
   join public.aos_audiencia_activaciones aa on aa.id=x.activation_id
   join public.aos_audiencias aud on aud.id=aa.audiencia_id
   where x.advisor_user_id=p_advisor_user_id and(v_state is null or x.state=v_state)
   order by x.assigned_at desc,x.id
   limit least(greatest(coalesce(p_limit,50),1),100) offset greatest(coalesce(p_offset,0),0)
 ) q;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.active desc,q.created_at desc),'[]'::jsonb) into v_plans
 from (
   select p.id plan_id,p.state,p.strategy,p.ownership_scope,p.created_at,c.nombre activation_name,c.channel,
          count(x.id) filter(where x.state in('RESERVED','ASSIGNED','IN_PROGRESS'))::integer active,
          count(x.id) filter(where x.state='ASSIGNED')::integer assigned,
          count(x.id) filter(where x.state='IN_PROGRESS')::integer in_progress,
          count(x.id) filter(where x.state='COMPLETED')::integer completed,
          count(x.id) filter(where x.state='RELEASED')::integer released,
          count(x.id) filter(where x.state='EXPIRED')::integer expired,
          t.capacity_limit
   from public.aos_cia_assignment_targets t
   join public.aos_cia_assignment_plans p on p.id=t.plan_id
   join public.aos_audiencia_activacion_config c on c.activacion_id=p.activation_id
   left join public.aos_cia_assignments x on x.plan_id=p.id and x.advisor_user_id=p_advisor_user_id
   where t.advisor_user_id=p_advisor_user_id
   group by p.id,p.state,p.strategy,p.ownership_scope,p.created_at,c.nombre,c.channel,t.capacity_limit
 ) q;
 return jsonb_build_object('ok',true,'advisor',jsonb_build_object('advisor_user_id',v_user.id,'advisor_name',v_user.nombre,'advisor_code',v_user.codigo_asesor,'area',v_user.area,'active_user',v_user.activo,'role',v_user.rol),'summary',v_summary,'plans',v_plans,'items',v_items,'limit',least(greatest(coalesce(p_limit,50),1),100),'offset',greatest(coalesce(p_offset,0),0),'observed_at',statement_timestamp());
end;
$$;

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
   select p.id plan_id,p.state,p.strategy,p.ownership_scope,p.topup_policy,p.created_at,c.nombre activation_name,c.channel,c.mode,c.purpose,aud.nombre audience_name,
          coalesce((s.summary->>'source_available_now')::integer,0) source_available_now,
          coalesce((s.summary->>'candidate_remaining')::integer,0) candidate_remaining,
          coalesce((s.summary->>'depletion_pct')::numeric,0) depletion_pct,
          coalesce(s.summary->'counts','{}'::jsonb) counts,coalesce(s.summary->'targets','[]'::jsonb) targets,coalesce(s.summary->'context','{}'::jsonb) context,
          count(x.id) filter(where x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())::integer overdue_to_start,
          count(x.id) filter(where x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')::integer expiring_60m,
          case when p.state='ACTIVE' and coalesce(s.summary->'context'->>'activation_state','')<>'ACTIVE' then 'BLOCKED_CONTEXT'
               when p.state='ACTIVE' and coalesce((s.summary->>'candidate_remaining')::integer,0)=0 then 'DEPLETED'
               when count(x.id) filter(where x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())>0 then 'ATTENTION'
               when count(x.id) filter(where x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')>0 then 'ATTENTION'
               else 'OK' end health_state
   from public.aos_cia_assignment_plans p
   join public.aos_audiencia_activaciones aa on aa.id=p.activation_id
   join public.aos_audiencia_activacion_config c on c.activacion_id=p.activation_id
   join public.aos_audiencias aud on aud.id=aa.audiencia_id
   cross join lateral (select public.aos_cia_assignment_plan_summary_v1(p.id) summary) s
   left join public.aos_cia_assignments x on x.plan_id=p.id
   where p_include_terminal or p.state not in('CLOSED','CANCELLED')
   group by p.id,p.state,p.strategy,p.ownership_scope,p.topup_policy,p.created_at,c.nombre,c.channel,c.mode,c.purpose,aud.nombre,s.summary
   order by p.created_at desc
   limit least(greatest(coalesce(p_limit,25),1),50) offset greatest(coalesce(p_offset,0),0)
 ) q;
 return jsonb_build_object('ok',true,'items',v_items,'limit',least(greatest(coalesce(p_limit,25),1),50),'offset',greatest(coalesce(p_offset,0),0),'observed_at',statement_timestamp());
end;
$$;

create or replace function public.aos_cia_advisor_control_alerts_v1(p_limit integer default 50)
returns jsonb
language sql
stable
set search_path=public
as $$
with q as (
 select x.id assignment_id,x.plan_id,x.contact_key,x.advisor_user_id,u.nombre advisor_name,u.codigo_asesor advisor_code,x.state,
        x.assigned_at,x.must_start_before,x.expires_at,c.nombre activation_name,c.channel,
        array_remove(array[
          case when x.state='ASSIGNED' and x.must_start_before<=clock_timestamp() then 'OVERDUE_TO_START' end,
          case when x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes' then 'EXPIRING_60M' end
        ],null)::text[] alert_types,
        round(extract(epoch from(x.expires_at-clock_timestamp()))/60.0,1) minutes_to_expiry
 from public.aos_cia_assignments x
 join public.aos_usuarios u on u.id=x.advisor_user_id
 join public.aos_audiencia_activacion_config c on c.activacion_id=x.activation_id
 where (x.state='ASSIGNED' and x.must_start_before<=clock_timestamp())
    or (x.state in('ASSIGNED','IN_PROGRESS') and x.expires_at<=clock_timestamp()+interval '60 minutes')
 order by x.expires_at asc,x.must_start_before asc,x.id
 limit least(greatest(coalesce(p_limit,50),1),100)
)
select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb),'observed_at',statement_timestamp()) from q;
$$;

create or replace function public.aos_cia_advisor_control_f11_readiness_v1()
returns jsonb
language sql
stable
set search_path=public
as $$
with global_conflicts as (
  select count(*)::integer n from (
    select x.contact_key
    from public.aos_cia_assignments x join public.aos_cia_assignment_plans p on p.id=x.plan_id
    where p.ownership_scope='GLOBAL' and x.state in('RESERVED','ASSIGNED','IN_PROGRESS')
    group by x.contact_key having count(*)>1
  ) z
), invalid_ownership_advisor as (
  select count(*)::integer n
  from public.aos_cia_assignments x left join public.aos_usuarios u on u.id=x.advisor_user_id
  where x.state in('RESERVED','ASSIGNED','IN_PROGRESS') and (u.id is null or u.activo is not true or lower(coalesce(u.rol,''))<>'asesor')
), invalid_targets as (
  select count(*)::integer n
  from public.aos_cia_assignment_targets t join public.aos_cia_assignment_plans p on p.id=t.plan_id
  left join public.aos_usuarios u on u.id=t.advisor_user_id
  where p.state in('ACTIVE','PAUSED') and (u.id is null or u.activo is not true or lower(coalesce(u.rol,''))<>'asesor')
), deadline_errors as (
  select count(*)::integer n from public.aos_cia_assignments
  where state in('RESERVED','ASSIGNED','IN_PROGRESS') and (must_start_before is null or expires_at is null or must_start_before>expires_at)
), activation_errors as (
  select count(*)::integer n
  from public.aos_cia_assignment_plans p left join public.aos_audiencia_activacion_estado s on s.activacion_id=p.activation_id
  where p.state='ACTIVE' and coalesce(s.estado,'')<>'ACTIVE'
), totals as (
 select count(*)::integer active_leases,
        count(*) filter(where state='ASSIGNED' and must_start_before<=clock_timestamp())::integer overdue_to_start,
        count(*) filter(where state in('ASSIGNED','IN_PROGRESS') and expires_at<=clock_timestamp()+interval '60 minutes')::integer expiring_60m
 from public.aos_cia_assignments where state in('RESERVED','ASSIGNED','IN_PROGRESS')
), plans as (
 select count(*) filter(where state='DRAFT')::integer draft,
        count(*) filter(where state='ACTIVE')::integer active,
        count(*) filter(where state='PAUSED')::integer paused,
        count(*) filter(where state in('DRAFT','ACTIVE','PAUSED'))::integer open
 from public.aos_cia_assignment_plans
), advisors as (
 select count(*)::integer n from public.aos_usuarios where activo=true and lower(coalesce(rol,''))='asesor'
), gate as (
 select g.n global_conflicts,i.n invalid_ownership_advisor,t.n invalid_targets,d.n deadline_errors,a.n active_plan_activation_errors,
        (g.n=0 and i.n=0 and t.n=0 and d.n=0 and a.n=0) ready
 from global_conflicts g cross join invalid_ownership_advisor i cross join invalid_targets t cross join deadline_errors d cross join activation_errors a
)
select jsonb_build_object(
 'ok',true,
 'f11_engineering_ready',gate.ready,
 'status',case when not gate.ready then 'BLOCKED' when totals.active_leases=0 then 'READY_NO_ACTIVE_OWNERSHIP' else 'READY' end,
 'active_advisors',advisors.n,
 'plans',jsonb_build_object('draft',plans.draft,'active',plans.active,'paused',plans.paused,'open',plans.open),
 'active_leases',totals.active_leases,'overdue_to_start',totals.overdue_to_start,'expiring_60m',totals.expiring_60m,
 'violations',jsonb_build_object('global_active_conflicts',gate.global_conflicts,'invalid_ownership_advisor',gate.invalid_ownership_advisor,'invalid_open_targets',gate.invalid_targets,'deadline_errors',gate.deadline_errors,'active_plan_activation_not_active',gate.active_plan_activation_errors),
 'routing_modified',false,
 'next_phase_note','F11 still requires parallel V3 routing, feature flag and V2 fallback; this function does not modify Call Center.',
 'observed_at',statement_timestamp()
)
from gate cross join totals cross join plans cross join advisors;
$$;

revoke all on function public.aos_cia_advisor_control_overview_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_advisor_control_advisor_detail_v1(uuid,text,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_cia_advisor_control_plan_health_v1(boolean,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_cia_advisor_control_alerts_v1(integer) from public,anon,authenticated;
revoke all on function public.aos_cia_advisor_control_f11_readiness_v1() from public,anon,authenticated;
grant execute on function public.aos_cia_advisor_control_overview_v1() to service_role;
grant execute on function public.aos_cia_advisor_control_advisor_detail_v1(uuid,text,integer,integer) to service_role;
grant execute on function public.aos_cia_advisor_control_plan_health_v1(boolean,integer,integer) to service_role;
grant execute on function public.aos_cia_advisor_control_alerts_v1(integer) to service_role;
grant execute on function public.aos_cia_advisor_control_f11_readiness_v1() to service_role;
