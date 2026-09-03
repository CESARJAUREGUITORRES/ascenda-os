-- WA-L7 recovery. Existing WA-1/WA-4/L6 ledgers remain untouched.

begin;

do $$
begin
  if to_regclass('public.aos_wa_l7_pricing_authority_v1') is not null
     and exists(select 1 from public.aos_wa_l7_pricing_authority_v1) then
    raise exception 'WA_L7_RECOVERY_BLOCKED_PRICING_HISTORY';
  end if;
end
$$;

drop function if exists public.aos_wa_l7_journey_cost_v1(uuid);
drop function if exists public.aos_wa_l7_conversation_cost_v1(uuid);
drop view if exists public.aos_wa_l7_ai_cost_events_v1;
drop view if exists public.aos_wa_l7_meta_cost_events_v1;
drop function if exists public.aos_wa_l7_pricing_authority_append_v1(text,jsonb);
drop trigger if exists trg_aos_wa_l7_pricing_append_guard_v1 on public.aos_wa_l7_pricing_authority_v1;
drop function if exists public.aos_wa_l7_pricing_append_guard_v1();
drop table if exists public.aos_wa_l7_pricing_authority_v1;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
