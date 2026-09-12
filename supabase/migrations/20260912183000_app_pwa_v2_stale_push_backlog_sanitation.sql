-- APP-PWA-V2 #517 · APP-G6 stale push backlog sanitation
-- PREPARED ONLY. Apply only after #519 is merged and exact PROD preflight confirms:
--   1) generic notification pump remains protected / not draining this backlog;
--   2) no rows in the captured cohort are actively CLAIMED;
--   3) current main + production SHA are reconciled.
--
-- Safety invariant: preserve in-app history, permanently disable stale OS push eligibility,
-- and never mass-replay the captured backlog.

begin;

do $sanitation$
declare
  v_cutoff constant timestamptz := '2026-09-12 16:31:05.089661+00';
  v_key constant text := 'APP_PWA_V2_G6_20260912';
  v_changed integer := 0;
begin
  update public.aos_notificaciones n
     set push_enabled = false,
         push_status = 'EXPIRED',
         expira_at = least(coalesce(n.expira_at, now()), now()),
         push_claimed_at = null,
         metadata = coalesce(n.metadata,'{}'::jsonb) || jsonb_build_object(
           'push_sanitation_key', v_key,
           'push_sanitized_at', now(),
           'push_previous_status', n.push_status,
           'push_sanitation_reason', 'STALE_PRE_PUSH_V2_BACKLOG_NO_REPLAY'
         ),
         updated_at = now()
   where n.push_enabled = true
     and n.push_status = 'PENDING'
     and n.created_at <= v_cutoff
     and (
       (n.channel='AGENDA' and n.event_type in (
         'ADMIN_APPOINTMENT_DIGEST',
         'APPOINTMENT_CREATED',
         'ADMIN_ATTENDED_DIGEST',
         'ADMIN_NO_SHOW_DIGEST',
         'APPOINTMENT_NO_SHOW',
         'APPOINTMENT_ATTENDED'
       ))
       or
       (n.channel='SALES' and n.event_type in (
         'ADMIN_SALES_DIGEST',
         'SALE_ADDED'
       ))
     );

  get diagnostics v_changed = row_count;
  raise notice 'APP_PWA_V2_G6_SANITIZED=% cutoff=%', v_changed, v_cutoff;
end
$sanitation$;

commit;
