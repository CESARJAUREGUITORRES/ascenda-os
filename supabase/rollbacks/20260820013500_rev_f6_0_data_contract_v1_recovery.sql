-- REV-F6.0 fail-closed recovery.
-- This recovery NEVER reopens legacy aos_paciente_360 to browser roles.

begin;

revoke all on function public.aos_patient_history_summary_v1(text,text) from public, anon, authenticated;
grant execute on function public.aos_patient_history_summary_v1(text,text) to service_role;

revoke all on function public.aos_paciente_360(text) from public, anon, authenticated;
grant execute on function public.aos_paciente_360(text) to service_role;

revoke all on function public.aos_rev_f6_data_contract_v1() from public, anon, authenticated;
grant execute on function public.aos_rev_f6_data_contract_v1() to service_role;

select pg_notify('pgrst','reload schema');

commit;
