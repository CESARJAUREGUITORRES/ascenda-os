-- P0 2026-09-24 / 2026-09-25 UTC
-- Prevent stale browser runtimes from recreating historical appointments as new rows.
-- Trusted service-role/server backfills remain possible.

create or replace function public.aos_guard_client_agenda_insert_v1()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $$
declare
  v_claims jsonb := '{}'::jsonb;
  v_role text := '';
  v_today date := (pg_catalog.now() at time zone 'America/Lima')::date;
begin
  begin
    v_claims := coalesce(nullif(pg_catalog.current_setting('request.jwt.claims', true),''),'{}')::jsonb;
    v_role := coalesce(v_claims->>'role','');
  exception when others then
    v_role := '';
  end;

  if v_role in ('anon','authenticated')
     and new.fecha_cita is not null
     and new.fecha_cita < v_today then
    raise exception using
      errcode='P0001',
      message='AOS_PAST_APPOINTMENT_INSERT_BLOCKED',
      detail='La app no puede crear una cita nueva en una fecha pasada. Usa edición/reprogramación o un proceso administrativo gobernado.';
  end if;

  if v_role in ('anon','authenticated')
     and upper(coalesce(new.origen_cita,''))='AGENDA'
     and nullif(trim(coalesce(new.source_channel,'')),'') is null then
    new.source_channel := 'APP_AGENDA';
  end if;

  if v_role in ('anon','authenticated') then
    new.ts_creado := coalesce(new.ts_creado, pg_catalog.now());
    new.ts_actualizado := coalesce(new.ts_actualizado, new.ts_creado, pg_catalog.now());
  end if;

  return new;
end
$$;

drop trigger if exists trg_0000_aos_guard_client_agenda_insert_v1 on public.aos_agenda_citas;
create trigger trg_0000_aos_guard_client_agenda_insert_v1
before insert on public.aos_agenda_citas
for each row execute function public.aos_guard_client_agenda_insert_v1();
