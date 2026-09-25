-- P0 hardening v2: keep browser/session appointment writes clean.
-- Adds natural duplicate protection on top of the historical-date guard.

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
  v_num text := regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
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

  if v_role in ('anon','authenticated') and v_num<>'' and exists (
    select 1
    from public.aos_agenda_citas a
    where regexp_replace(coalesce(nullif(a.numero_limpio,''),a.numero,''),'[^0-9]','','g')=v_num
      and a.fecha_cita=new.fecha_cita
      and left(coalesce(a.hora_cita,''),5)=left(coalesce(new.hora_cita,''),5)
      and regexp_replace(upper(coalesce(a.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(coalesce(new.tratamiento,'')),'[^A-Z0-9]+','','g')
      and upper(coalesce(a.sede,''))=upper(coalesce(new.sede,''))
      and upper(coalesce(a.tipo_cita,''))=upper(coalesce(new.tipo_cita,''))
      and upper(coalesce(a.estado_cita,''))<>'CANCELADA'
  ) then
    raise exception using
      errcode='P0001',
      message='AOS_DUPLICATE_APPOINTMENT_BLOCKED',
      detail='Ya existe una cita activa para el mismo paciente, fecha, hora, tratamiento, sede y tipo.';
  end if;

  if v_role in ('anon','authenticated')
     and upper(coalesce(new.origen_cita,''))='AGENDA'
     and nullif(trim(coalesce(new.source_channel,'')),'') is null then
    new.source_channel := 'APP_AGENDA';
  end if;

  if v_role in ('anon','authenticated') then
    new.numero_limpio := case when v_num<>'' then v_num else new.numero_limpio end;
    new.ts_creado := coalesce(new.ts_creado, pg_catalog.now());
    new.ts_actualizado := coalesce(new.ts_actualizado, new.ts_creado, pg_catalog.now());
  end if;

  return new;
end
$$;
