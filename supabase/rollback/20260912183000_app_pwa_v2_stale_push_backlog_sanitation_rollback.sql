-- APP-PWA-V2 #517 · APP-G6 sanitation safety rollback
--
-- INTENTIONALLY NON-REPLAYING.
-- Historical push eligibility is NOT restored because doing so could emit stale
-- agenda/sales notifications in bulk. In-app notification rows remain intact.
-- A product rollback should disable/rollback Push V2 runtime separately; it must
-- never set these sanitized rows back to PENDING or push_enabled=true.

begin;

do $gate$
begin
  if exists (
    select 1
    from public.aos_notificaciones n
    where n.metadata->>'push_sanitation_key'='APP_PWA_V2_G6_20260912'
      and (n.push_enabled=true or n.push_status in ('PENDING','CLAIMED'))
  ) then
    raise exception 'APP_PWA_V2_G6_ROLLBACK_REPLAY_GUARD_FAILED';
  end if;
end
$gate$;

commit;
