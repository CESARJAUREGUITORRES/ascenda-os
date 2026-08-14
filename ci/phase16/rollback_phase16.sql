-- CIA F16 Zero-Cost rollback/recovery proof.
-- Drops only additive F16 objects created by the two migrations under test.

drop function if exists public.aos_cia_email_admin_gateway_v1(text,text,jsonb);
drop function if exists public.aos_cia_email_f17_readiness_v1();
drop function if exists public.aos_cia_email_prepare_request_v1(uuid,uuid,text,uuid);
drop function if exists public.aos_cia_email_template_version_activate_v1(uuid,uuid);
drop function if exists public.aos_cia_email_template_version_create_v1(uuid,text,text,text,text,text[],uuid);
drop function if exists public.aos_cia_email_preview_activation_v1(uuid,text,integer,integer);
drop function if exists public.aos_cia_email_eligibility_v1(uuid,text,text);

drop trigger if exists trg_aos_cia_email_send_events_append_only_v1 on public.aos_cia_email_send_events;
drop trigger if exists trg_aos_cia_email_request_guard_v1 on public.aos_cia_email_send_requests;
drop trigger if exists trg_aos_cia_email_template_guard_v1 on public.aos_cia_email_template_versions;
drop trigger if exists trg_aos_cia_email_control_events_append_only_v1 on public.aos_cia_email_recipient_control_events;
drop trigger if exists trg_aos_cia_email_control_audit_v1 on public.aos_cia_email_recipient_controls;

drop function if exists public.aos_cia_email_request_guard_v1();
drop function if exists public.aos_cia_email_template_guard_v1();
drop function if exists public.aos_cia_email_append_only_guard_v1();
drop function if exists public.aos_cia_email_control_audit_v1();

drop table if exists public.aos_cia_email_send_events;
drop table if exists public.aos_cia_email_send_requests;
drop table if exists public.aos_cia_email_template_versions;
drop table if exists public.aos_cia_email_recipient_control_events;
drop table if exists public.aos_cia_email_recipient_controls;

select case when count(*)=0 then 'CIA_PHASE16_ROLLBACK=PASS' else 'CIA_PHASE16_ROLLBACK=FAIL' end as rollback_result
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in (
  'aos_cia_email_recipient_controls','aos_cia_email_recipient_control_events','aos_cia_email_template_versions','aos_cia_email_send_requests','aos_cia_email_send_events'
);
