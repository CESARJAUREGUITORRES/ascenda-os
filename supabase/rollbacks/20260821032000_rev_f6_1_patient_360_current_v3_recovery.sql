-- Recovery for REV Patient 360 Current V3 hotfix.
-- Restore the pre-hotfix fail-closed state without reopening browser access.

drop function if exists public.aos_patient_360_current_v3(text,text);

alter function public.aos_paciente_360(text)
  set search_path = '';

revoke all on function public.aos_paciente_360(text) from public, anon, authenticated;
grant execute on function public.aos_paciente_360(text) to service_role;
