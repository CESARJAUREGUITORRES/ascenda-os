-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6
-- Recovery for 20260821234500_mkt_loop6_credit_ownership_rules_v2.sql
-- Restores exact pre-addendum function definitions captured before mutation.

do $rollback$
declare r record;
begin
  for r in
    select definition
    from public.aos_loop6_function_backups_v1
    where backup_key='20260821_credit_rules_v2'
    order by function_name,function_args
  loop
    execute r.definition;
  end loop;
end
$rollback$;

drop function if exists public.aos_callcenter_policy_log_v1(uuid,text,text,text,text,text,text,text,text,text,jsonb);
drop function if exists public.aos_callcenter_credit_context_v2(text,timestamptz);
drop function if exists public.aos_callcenter_agenda_slot_v1(date,text);
drop function if exists public.aos_callcenter_try_timestamptz_v1(text);

drop table if exists public.aos_callcenter_policy_events_v1;

alter table public.aos_callcenter_actions_v1
  drop column if exists credited_advisor,
  drop column if exists credited_advisor_id,
  drop column if exists commercial_owner,
  drop column if exists commercial_owner_id,
  drop column if exists beneficiary_scope,
  drop column if exists eligibility_status,
  drop column if exists eligibility_reason,
  drop column if exists prior_agenda_id,
  drop column if exists prior_advisor,
  drop column if exists prior_advisor_id,
  drop column if exists ownership_transfer,
  drop column if exists rule_context;

-- Keep aos_loop6_function_backups_v1 as control evidence. It is restricted to service_role.
