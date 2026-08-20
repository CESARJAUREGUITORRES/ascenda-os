-- REV-F6.1 recovery: remove F6.1 read surfaces without reopening the weak legacy Patient 360 path.
begin;

revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public, anon, authenticated, service_role;
revoke all on function public.aos_patient_search_v2(text,text,integer) from public, anon, authenticated, service_role;
revoke all on function public.aos_rev_resolve_patient_identity_v2(text,text) from public, anon, authenticated, service_role;
revoke all on public.aos_rev_patient_identity_alias_v2 from public, anon, authenticated, service_role;
revoke all on function public.aos_rev_normalize_patient_identifier_v2(text,text) from public, anon, authenticated, service_role;

drop function if exists public.aos_patient_commercial_360_v2(text,text,text);
drop function if exists public.aos_patient_search_v2(text,text,integer);
drop function if exists public.aos_rev_resolve_patient_identity_v2(text,text);
drop view if exists public.aos_rev_patient_identity_alias_v2;
drop function if exists public.aos_rev_normalize_patient_identifier_v2(text,text);

-- F6.0 security boundary remains authoritative after recovery.
revoke all on function public.aos_paciente_360(text) from public, anon, authenticated;
grant execute on function public.aos_paciente_360(text) to service_role;

select pg_notify('pgrst','reload schema');
commit;
