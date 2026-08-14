-- REMOTE SYNC: already applied live as 20260813211247.
create or replace function public.aos_cia_snapshot_member_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
declare st text;
begin
  if tg_op in ('UPDATE','DELETE') then raise exception 'SNAPSHOT_MEMBER_IMMUTABLE'; end if;
  select estado into st from public.aos_audiencia_snapshots where id=new.snapshot_id;
  if st is distinct from 'BUILDING' then raise exception 'SNAPSHOT_ALREADY_SEALED'; end if;
  return new;
end;$$;