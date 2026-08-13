-- REMOTE SYNC: already applied live as 20260813211419.
-- Restrictive integrity guard only: forbids deletion and illegal lifecycle transitions.
create or replace function public.aos_cia_activation_state_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if tg_op='DELETE' then raise exception 'ACTIVATION_STATE_DELETE_FORBIDDEN'; end if;
  if tg_op='INSERT' then
    if new.estado not in ('DRAFT','ACTIVE') then raise exception 'INVALID_INITIAL_ACTIVATION_STATE'; end if;
    return new;
  end if;
  if new.activacion_id is distinct from old.activacion_id then raise exception 'ACTIVATION_STATE_ID_IMMUTABLE'; end if;
  if old.estado=new.estado then raise exception 'ACTIVATION_NO_STATE_CHANGE'; end if;
  if not ((old.estado='DRAFT' and new.estado in ('ACTIVE','CANCELLED')) or (old.estado='ACTIVE' and new.estado in ('PAUSED','COMPLETED','CANCELLED')) or (old.estado='PAUSED' and new.estado in ('ACTIVE','COMPLETED','CANCELLED'))) then raise exception 'INVALID_ACTIVATION_TRANSITION'; end if;
  new.updated_at:=now();
  return new;
end;$$;