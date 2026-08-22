-- Roll back only the Loop 6 V2 idempotency precheck wrapper.
-- Restores the policy implementation to the canonical core function name.

drop function if exists public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text);

alter function public.aos_callcenter_commit_action_core_impl_v2(uuid,text,text,jsonb,text)
  rename to aos_callcenter_commit_action_core_v1;

revoke all on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  to service_role;
