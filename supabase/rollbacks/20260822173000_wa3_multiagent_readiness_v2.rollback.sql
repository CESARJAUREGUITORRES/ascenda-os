-- WA-3 V2 rollback: remove additive readiness/queue layer only.
-- Preserves WA-3 V1 boxes, assignments, routing and human-send evidence.

revoke all on function public.aos_wa3_claim_next_v2(uuid,uuid) from public, anon, authenticated, service_role;
revoke all on function public.aos_wa3_queue_summary_v1(uuid) from public, anon, authenticated, service_role;
revoke all on function public.aos_wa3_agent_presence_touch_v1(uuid,text) from public, anon, authenticated, service_role;

drop function if exists public.aos_wa3_claim_next_v2(uuid,uuid);
drop function if exists public.aos_wa3_queue_summary_v1(uuid);
drop function if exists public.aos_wa3_agent_presence_touch_v1(uuid,text);

drop table if exists public.aos_wa_agent_presence_v1;
