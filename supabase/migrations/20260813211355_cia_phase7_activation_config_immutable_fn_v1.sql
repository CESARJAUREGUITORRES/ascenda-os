-- REMOTE SYNC: already applied live as 20260813211355.
create or replace function public.aos_cia_activation_config_immutable_v1()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if tg_op in ('UPDATE','DELETE') then raise exception 'ACTIVATION_CONFIG_IMMUTABLE'; end if;
  return new;
end;$$;