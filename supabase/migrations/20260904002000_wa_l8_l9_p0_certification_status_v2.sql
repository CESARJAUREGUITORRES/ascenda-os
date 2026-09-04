-- P0 #457 / #432 — isolate production certification readbacks from global audit scans.
--
-- Root evidence (2026-09-03 incident): the legacy WA-L8 security status mixes
-- constant-time safety flags with several global COUNT(*) scans. One production
-- certification invocation reached ~10.6s while operational Call Center traffic
-- was active. Certification must never compete with foreground clinic work.
--
-- This migration is additive. It does not alter autonomous authority, message
-- routing, 2FA, statement_timeout, business ledgers, or the legacy cold-audit
-- functions. The v2 surfaces are intentionally safety-only and use indexed EXISTS
-- probes instead of global counts.

begin;

create or replace function public.aos_wa_l8_safety_status_v2()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'ok',true,
    'mode',a.mode,
    'kill_switch_engaged',a.kill_switch_engaged,
    'auto_reply_enabled',ai.auto_reply_enabled,
    'ai_send_enabled',r.ai_send_enabled,
    'auto_routing_enabled',r.auto_routing_enabled,
    'human_send_enabled',r.human_send_enabled,
    'autonomous_outbound',case when exists(
      select 1
      from public.aos_wa_messages_v1 m
      where m.send_origin='AUTO' and m.direction='OUTBOUND'
      limit 1
    ) then 1 else 0 end,
    'browser_message_write',(
      pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','INSERT')
      or pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','UPDATE')
      or pg_catalog.has_table_privilege('anon','public.aos_wa_messages_v1','DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','INSERT')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','UPDATE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_wa_messages_v1','DELETE')
    ),
    'browser_booking_write',(
      pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','INSERT')
      or pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','UPDATE')
      or pg_catalog.has_table_privilege('anon','public.aos_booking_operations_v2','DELETE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','INSERT')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','UPDATE')
      or pg_catalog.has_table_privilege('authenticated','public.aos_booking_operations_v2','DELETE')
    ),
    'readback_class','SAFETY_BOUNDED_V2'
  )
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

revoke all on function public.aos_wa_l8_safety_status_v2() from public,anon,authenticated;
grant execute on function public.aos_wa_l8_safety_status_v2() to service_role;

create or replace function public.aos_wa_l9_safety_status_v2()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'ok',true,
    'mode',a.mode,
    'kill_switch_engaged',a.kill_switch_engaged,
    'auto_reply_enabled',ai.auto_reply_enabled,
    'ai_send_enabled',r.ai_send_enabled,
    'auto_routing_enabled',r.auto_routing_enabled,
    'human_send_enabled',r.human_send_enabled,
    'provider_dispatch_runs',case when exists(
      select 1
      from public.aos_wa_l9_demo_runs_v1 d
      where d.provider_dispatch is true
      limit 1
    ) then 1 else 0 end,
    'autonomous_outbound',case when exists(
      select 1
      from public.aos_wa_messages_v1 m
      where m.send_origin='AUTO' and m.direction='OUTBOUND'
      limit 1
    ) then 1 else 0 end,
    'readback_class','SAFETY_BOUNDED_V2'
  )
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1
$$;

revoke all on function public.aos_wa_l9_safety_status_v2() from public,anon,authenticated;
grant execute on function public.aos_wa_l9_safety_status_v2() to service_role;

comment on function public.aos_wa_l8_safety_status_v2() is
  'P0-bounded WA-L8 production safety readback. No global audit counts; indexed EXISTS only. Use for deploy/prod certification.';
comment on function public.aos_wa_l9_safety_status_v2() is
  'P0-bounded WA-L9 production safety readback. No global audit counts; use for deploy/prod certification.';
comment on function public.aos_wa_l8_security_status_v1() is
  'COLD_AUDIT_ONLY after P0 #457. Includes global counts and MUST NOT be used as synchronous production deploy/readback gate; use aos_wa_l8_safety_status_v2().';
comment on function public.aos_wa_l9_status_v1() is
  'COLD_AUDIT_ONLY after P0 #457. Includes global counts and MUST NOT be used as synchronous production deploy/readback gate; use aos_wa_l9_safety_status_v2().';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
