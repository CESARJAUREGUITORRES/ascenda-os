-- REV-F6.3 recovery — restore certified F6.2 gateway and remove F6.3 trust layer.
-- Does not restore any weaker legacy browser path.

begin;

drop function if exists public.aos_patient_commercial_360_v2(text,text,text);

do $$
begin
  if to_regprocedure('public.aos_patient_commercial_360_v2_f6_2_base(text,text,text)') is not null then
    alter function public.aos_patient_commercial_360_v2_f6_2_base(text,text,text) rename to aos_patient_commercial_360_v2;
  end if;
end $$;

revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

drop function if exists public.aos_rev_f6_3_contract_v1();
drop function if exists public.aos_rev_metric_trust_baseline_v1();
drop function if exists public.aos_rev_metric_trust_envelope_v1(text,jsonb,bigint,bigint,text,bigint,text,text,timestamptz,timestamptz,timestamptz,text,jsonb,jsonb,jsonb);
drop function if exists public.aos_rev_identity_confidence_summary_v1();
drop function if exists public.aos_rev_identity_confidence_by_patient_v1(text);
drop view if exists public.aos_rev_identity_confidence_current_v1;

select pg_notify('pgrst','reload schema');
commit;
