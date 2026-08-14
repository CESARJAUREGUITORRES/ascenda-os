create table if not exists public.aos_cia_advisor_work_preferences (
  advisor_user_id uuid not null references public.aos_usuarios(id),
  assignment_id uuid not null references public.aos_cia_assignments(id),
  pinned boolean not null default false,
  snoozed_until timestamptz,
  priority_override text not null default 'NORMAL' check (priority_override in ('HIGH','NORMAL','LOW')),
  updated_at timestamptz not null default statement_timestamp(),
  primary key (advisor_user_id, assignment_id)
);

alter table public.aos_cia_advisor_work_preferences enable row level security;

create or replace function public.aos_cia_advisor_work_preference_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_owner uuid;
begin
  if tg_op='UPDATE' and (new.advisor_user_id<>old.advisor_user_id or new.assignment_id<>old.assignment_id) then
    raise exception 'WORK_PREFERENCE_IDENTITY_IMMUTABLE';
  end if;

  select x.advisor_user_id into v_owner
  from public.aos_cia_assignments x
  where x.id=new.assignment_id;

  if v_owner is null or v_owner<>new.advisor_user_id then
    raise exception 'WORK_PREFERENCE_NOT_OWNER';
  end if;

  if new.snoozed_until is not null and new.snoozed_until > statement_timestamp()+interval '30 days' then
    raise exception 'WORK_SNOOZE_TOO_LONG';
  end if;

  new.updated_at := statement_timestamp();
  return new;
end;
$$;

drop trigger if exists trg_cia_advisor_work_preference_guard_v1 on public.aos_cia_advisor_work_preferences;
create trigger trg_cia_advisor_work_preference_guard_v1
before insert or update on public.aos_cia_advisor_work_preferences
for each row execute function public.aos_cia_advisor_work_preference_guard_v1();

revoke all on table public.aos_cia_advisor_work_preferences from public, anon, authenticated;
grant select on table public.aos_cia_advisor_work_preferences to service_role;
revoke all on function public.aos_cia_advisor_work_preference_guard_v1() from public, anon, authenticated;
