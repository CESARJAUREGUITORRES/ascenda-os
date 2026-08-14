-- REMOTE SYNC: already applied live as 20260813211320.
create or replace function public.aos_cia_activation_identity_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if tg_op in ('UPDATE','DELETE') then raise exception 'ACTIVATION_IDENTITY_IMMUTABLE'; end if;
  if not exists(select 1 from public.aos_audiencia_versiones v where v.id=new.audiencia_version_id and v.audiencia_id=new.audiencia_id) then raise exception 'ACTIVATION_AUDIENCE_VERSION_MISMATCH'; end if;
  return new;
end;$$;