-- ASCENDA CIA V3 — Phase 11 output contract for Phase 12.

create or replace function public.aos_cia_call_routing_f12_readiness_v1()
returns jsonb
language sql
stable
set search_path = public
as $function$
with ctl as (
  select global_enabled from public.aos_cia_call_routing_control where id=1
), cfg as (
  select count(*) filter(where mode in ('V3_CANARY','V3_PREFERRED'))::integer v3_advisors,
         count(*) filter(where mode='V3_CANARY')::integer canary_advisors,
         count(*) filter(where mode='V3_PREFERRED')::integer preferred_advisors
  from public.aos_cia_call_routing_advisors
), ev as (
  select count(*) filter(where route_selected='V3' and event_type='CLAIM')::integer v3_claims_24h,
         count(*) filter(where event_type='CONSUME')::integer consumes_24h,
         count(*) filter(where event_type='FALLBACK')::integer fallbacks_24h,
         count(*) filter(where event_type='ERROR')::integer errors_24h,
         max(occurred_at) filter(where route_selected='V3') last_v3_at
  from public.aos_cia_call_routing_events
  where occurred_at >= clock_timestamp()-interval '24 hours'
), ownership as (
  select count(*) filter(where x.state='IN_PROGRESS')::integer in_progress,
         count(*) filter(where x.state='ASSIGNED')::integer assigned,
         count(*) filter(where x.state='IN_PROGRESS' and x.expires_at<=clock_timestamp())::integer expired_in_progress,
         count(*) filter(where x.state='IN_PROGRESS' and not exists(
           select 1 from public.aos_cia_call_routing_events e
           where e.assignment_id=x.id and e.event_type='CLAIM'
         ))::integer in_progress_without_claim_event
  from public.aos_cia_assignments x
  join public.aos_cia_assignment_plans p on p.id=x.plan_id
  join public.aos_audiencia_activacion_context ac on ac.activation_id=x.activation_id
  join public.aos_cia_context_policies cp on cp.policy_key=ac.policy_key and cp.version=ac.policy_version
  where p.state in ('ACTIVE','PAUSED') and cp.channel='CALL'
), f10 as (
  select public.aos_cia_advisor_control_f11_readiness_v1() j
), gate as (
  select coalesce((select global_enabled from ctl),false) global_enabled,
         cfg.v3_advisors,cfg.canary_advisors,cfg.preferred_advisors,
         ev.v3_claims_24h,ev.consumes_24h,ev.fallbacks_24h,ev.errors_24h,ev.last_v3_at,
         ownership.in_progress,ownership.assigned,ownership.expired_in_progress,ownership.in_progress_without_claim_event,
         f10.j f10_readiness
  from cfg cross join ev cross join ownership cross join f10
)
select jsonb_build_object(
  'ok',true,
  'ready_for_f12',
    coalesce((gate.f10_readiness->>'f11_engineering_ready')::boolean,false)
    and gate.expired_in_progress=0
    and gate.in_progress_without_claim_event=0,
  'status',case
    when not coalesce((gate.f10_readiness->>'f11_engineering_ready')::boolean,false) then 'BLOCKED_F10_INVARIANT'
    when gate.expired_in_progress>0 then 'BLOCKED_EXPIRED_IN_PROGRESS'
    when gate.in_progress_without_claim_event>0 then 'BLOCKED_UNAUDITED_IN_PROGRESS'
    when not gate.global_enabled or gate.v3_advisors=0 then 'READY_NO_LIVE_V3'
    when gate.errors_24h>0 then 'READY_WITH_ROUTING_ERRORS'
    else 'READY'
  end,
  'global_enabled',gate.global_enabled,
  'rollout',jsonb_build_object('v3_advisors',gate.v3_advisors,'canary',gate.canary_advisors,'preferred',gate.preferred_advisors),
  'events_24h',jsonb_build_object('claims',gate.v3_claims_24h,'consumes',gate.consumes_24h,'fallbacks',gate.fallbacks_24h,'errors',gate.errors_24h,'last_v3_at',gate.last_v3_at),
  'call_ownership',jsonb_build_object('assigned',gate.assigned,'in_progress',gate.in_progress,'expired_in_progress',gate.expired_in_progress,'in_progress_without_claim_event',gate.in_progress_without_claim_event),
  'f10_readiness',gate.f10_readiness,
  'observed_at',statement_timestamp(),
  'next_phase_note','F12 must consume F9 ownership and F11 routing state/events; it must not infer ownership from raw calls.'
) from gate;
$function$;

revoke execute on function public.aos_cia_call_routing_f12_readiness_v1() from public, anon, authenticated;
grant execute on function public.aos_cia_call_routing_f12_readiness_v1() to service_role;
