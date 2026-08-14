create or replace function public.aos_cia_advisor_work_universe_v1(
  p_advisor_user_id uuid,
  p_include_terminal boolean default false,
  p_include_snoozed boolean default false
)
returns table(
  assignment_id uuid,plan_id uuid,activation_id uuid,contact_key text,advisor_user_id uuid,
  advisor_name text,advisor_code text,assignment_state text,assigned_at timestamptz,must_start_before timestamptz,
  expires_at timestamptz,started_at timestamptz,completed_at timestamptz,terminal_reason text,contact_name text,
  patient_state text,branch text,value_tier text,lifecycle text,engagement text,followup_pending integer,followup_overdue integer,
  next_followup_at date,latest_call_status text,last_call_at timestamptz,pinned boolean,snoozed_until timestamptz,
  priority_override text,is_snoozed boolean,work_bucket text,priority_score integer,requestable boolean,
  last_claim_at timestamptz,last_consume_at timestamptz,last_route_selected text
)
language sql
stable
set search_path=public
as $$
with owned as (
  select x.* from public.aos_cia_assignments x
  where x.advisor_user_id=p_advisor_user_id
    and (coalesce(p_include_terminal,false) or x.state in ('RESERVED','ASSIGNED','IN_PROGRESS'))
), enriched as (
  select
    x.id assignment_id,x.plan_id,x.activation_id,x.contact_key,x.advisor_user_id,
    u.nombre advisor_name,u.codigo_asesor advisor_code,x.state assignment_state,
    x.assigned_at,x.must_start_before,x.expires_at,x.started_at,x.completed_at,x.terminal_reason,
    trim(concat_ws(' ',pf.canonical_names,pf.canonical_surnames)) contact_name,
    pf.patient_state,pf.raw_branch branch,sg.value_tier,sg.lifecycle,sg.engagement,
    coalesce(ff.pending_count,0)::integer followup_pending,coalesce(ff.overdue_count,0)::integer followup_overdue,
    ff.next_followup_at,cl.latest_call_status,cl.last_call_at,
    coalesce(w.pinned,false) pinned,w.snoozed_until,coalesce(w.priority_override,'NORMAL') priority_override,
    (w.snoozed_until is not null and w.snoozed_until>statement_timestamp()) is_snoozed,
    r.last_claim_at,r.last_consume_at,r.last_route_selected
  from owned x
  join public.aos_usuarios u on u.id=x.advisor_user_id
  left join public.aos_cia_advisor_work_preferences w on w.advisor_user_id=x.advisor_user_id and w.assignment_id=x.id
  left join public.aos_cia_profile_fast_v2 pf on pf.contact_key=x.contact_key
  left join public.aos_cia_followup_facts_v1 ff on ff.contact_key=x.contact_key
  left join public.aos_cia_segment_runtime_cache_v2 sg on sg.contact_key=x.contact_key
  left join lateral (
    select upper(nullif(btrim(c.estado),'')) latest_call_status,c.created_at last_call_at
    from public.aos_llamadas c
    where public.aos_cia_normalize_contact_key_v1(c.numero_limpio)=x.contact_key
    order by c.created_at desc nulls last,c.fecha desc,c.id desc limit 1
  ) cl on true
  left join lateral (
    select max(e.occurred_at) filter(where e.event_type='CLAIM') last_claim_at,
           max(e.occurred_at) filter(where e.event_type='CONSUME') last_consume_at,
           (array_agg(e.route_selected order by e.occurred_at desc,e.id desc) filter(where e.route_selected is not null))[1] last_route_selected
    from public.aos_cia_call_routing_events e where e.assignment_id=x.id
  ) r on true
)
select
  e.assignment_id,e.plan_id,e.activation_id,e.contact_key,e.advisor_user_id,e.advisor_name,e.advisor_code,e.assignment_state,
  e.assigned_at,e.must_start_before,e.expires_at,e.started_at,e.completed_at,e.terminal_reason,e.contact_name,e.patient_state,e.branch,
  e.value_tier,e.lifecycle,e.engagement,e.followup_pending,e.followup_overdue,e.next_followup_at,e.latest_call_status,e.last_call_at,
  e.pinned,e.snoozed_until,e.priority_override,e.is_snoozed,
  case
    when e.assignment_state='IN_PROGRESS' then 'IN_PROGRESS'
    when e.assignment_state='ASSIGNED' and e.must_start_before<=statement_timestamp() then 'OVERDUE_TO_START'
    when e.assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and e.expires_at<=statement_timestamp()+interval '60 minutes' then 'EXPIRING_SOON'
    when e.followup_overdue>0 then 'FOLLOWUP_OVERDUE'
    when e.followup_pending>0 then 'FOLLOWUP_PENDING'
    when e.value_tier in ('DIAMANTE','GOLD','PREMIUM') then 'HIGH_VALUE'
    when e.assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') then 'ACTIVE_OWNERSHIP'
    else 'HISTORY' end work_bucket,
  (case when e.pinned then 10000 else 0 end
   + case e.priority_override when 'HIGH' then 1000 when 'LOW' then -100 else 0 end
   + case when e.assignment_state='IN_PROGRESS' then 900 else 0 end
   + case when e.assignment_state='ASSIGNED' and e.must_start_before<=statement_timestamp() then 800 else 0 end
   + case when e.assignment_state in ('RESERVED','ASSIGNED','IN_PROGRESS') and e.expires_at<=statement_timestamp()+interval '60 minutes' then 700 else 0 end
   + case when e.followup_overdue>0 then 600 else 0 end
   + case when e.followup_pending>0 then 500 else 0 end
   + case e.value_tier when 'DIAMANTE' then 400 when 'GOLD' then 300 when 'PREMIUM' then 200 else 0 end)::integer priority_score,
  (e.assignment_state in ('ASSIGNED','IN_PROGRESS') and e.expires_at>statement_timestamp()) requestable,
  e.last_claim_at,e.last_consume_at,e.last_route_selected
from enriched e
where coalesce(p_include_snoozed,false) or not e.is_snoozed;
$$;

revoke all on function public.aos_cia_advisor_work_universe_v1(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.aos_cia_advisor_work_universe_v1(uuid,boolean,boolean) to service_role;
