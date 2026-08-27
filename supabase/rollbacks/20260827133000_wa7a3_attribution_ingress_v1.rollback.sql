-- WA-7A.3 guarded rollback.
-- Accepted acquisition evidence is historical truth and must not be silently removed.

begin;

do $$
begin
  if exists(select 1 from public.aos_wa_events_v1 where event_type='attribution.touchpoint') then
    raise exception 'WA7A3_ROLLBACK_BLOCKED_REAL_TOUCHPOINT_EVIDENCE_EXISTS';
  end if;
end
$$;

drop view if exists public.aos_wa_attribution_touchpoints_v1;
drop trigger if exists trg_aos_wa7a3_touchpoint_immutable_guard_v1 on public.aos_wa_events_v1;
drop function if exists public.aos_wa7a3_touchpoint_immutable_guard_v1();

-- Deliberately do not restore UPDATE/DELETE/TRUNCATE on the existing event ledger.
-- WA-1 originally defined runtime event storage as append-only; the revoke is drift reconciliation.

select pg_notify('pgrst','reload schema');

commit;
