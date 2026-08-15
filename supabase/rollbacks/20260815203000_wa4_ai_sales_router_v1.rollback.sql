-- WA-4 fail-closed recovery. Preserve AI audit evidence and model registry, disable capability.
begin;
update public.aos_wa_ai_control_v1
set copilot_enabled=false,auto_reply_enabled=false,updated_at=now()
where id=1;
revoke all on function public.aos_wa4_authorize_copilot_v1(text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric) from public,anon,authenticated,service_role;
drop function if exists public.aos_wa4_authorize_copilot_v1(text,uuid);
drop function if exists public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric);
-- Intentionally retain aos_wa_ai_runs_v1 + append-only guard + FORCE RLS as evidence.
commit;
