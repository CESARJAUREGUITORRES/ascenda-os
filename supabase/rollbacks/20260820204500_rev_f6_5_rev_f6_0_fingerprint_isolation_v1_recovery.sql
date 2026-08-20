-- REV-F6.5 terminal fingerprint-isolation recovery.
-- Restores the original certified F6.0 function/fingerprint semantics.

begin;

do $$
begin
  if to_regprocedure('public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp()') is not null then
    if to_regprocedure('public.aos_rev_f6_data_contract_v1()') is not null then
      drop function public.aos_rev_f6_data_contract_v1();
    end if;
    alter function public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp() rename to aos_rev_f6_data_contract_v1;
  end if;
end $$;

revoke all on function public.aos_rev_f6_data_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_data_contract_v1() to service_role;

drop function if exists public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb);

select pg_notify('pgrst','reload schema');
commit;
