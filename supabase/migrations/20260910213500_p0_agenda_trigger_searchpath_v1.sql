-- P0 #492 · Agenda ASISTIO/EFECTIVA trigger search_path hardening.
-- Root cause: the governed Agenda RPC executes with search_path='', while two
-- legacy trigger functions referenced aos_pacientes without schema qualification.
-- PostgreSQL therefore raised 42P01 before the governed transaction could finish.

create or replace function public.fn_asignar_hc()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_hc text;
  v_mes text;
  v_seq int;
  v_numero text;
begin
  if new.estado_cita = 'ASISTIO'
     and (old.estado_cita is null or old.estado_cita <> 'ASISTIO') then
    v_numero := coalesce(
      new.numero_limpio,
      pg_catalog.regexp_replace(coalesce(new.numero,''), '[^0-9]', '', 'g')
    );
    if v_numero is null or v_numero = '' then
      return new;
    end if;

    select p.codigo_hc
      into v_hc
      from public.aos_pacientes p
     where p.numero_limpio = v_numero
     limit 1;

    if v_hc is not null then
      return new;
    end if;

    v_mes := pg_catalog.to_char(current_date, 'YYYYMM');

    select coalesce(max(
      pg_catalog.regexp_replace(p.codigo_hc, 'HC-' || v_mes || '-', '')::int
    ),0) + 1
      into v_seq
      from public.aos_pacientes p
     where p.codigo_hc like 'HC-' || v_mes || '-%';

    v_hc := 'HC-' || v_mes || '-' || pg_catalog.lpad(v_seq::text,4,'0');

    update public.aos_pacientes p
       set codigo_hc = v_hc
     where p.numero_limpio = v_numero
       and p.codigo_hc is null;
  end if;

  return new;
end
$function$;

create or replace function public.fn_enriquecer_paciente_cita()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if new.numero_limpio is not null
     and new.numero_limpio <> ''
     and pg_catalog.length(new.numero_limpio) >= 7 then

    update public.aos_pacientes p
       set "N° documento" = case
             when coalesce(p."N° documento",'') = ''
              and coalesce(new.dni,'') <> ''
             then new.dni else p."N° documento" end,
           "Email" = case
             when coalesce(p."Email",'') = ''
              and coalesce(new.correo,'') <> ''
              and new.correo like '%@%'
             then new.correo else p."Email" end,
           "Nombres" = case
             when coalesce(p."Nombres",'') = ''
              and coalesce(new.nombre,'') <> ''
             then new.nombre else p."Nombres" end,
           "Apellidos" = case
             when coalesce(p."Apellidos",'') = ''
              and coalesce(new.apellido,'') <> ''
             then new.apellido else p."Apellidos" end,
           updated_at = pg_catalog.now()
     where p.numero_limpio = new.numero_limpio
       and (
         (coalesce(p."N° documento",'') = '' and coalesce(new.dni,'') <> '')
         or (coalesce(p."Email",'') = '' and coalesce(new.correo,'') <> '' and new.correo like '%@%')
         or (coalesce(p."Nombres",'') = '' and coalesce(new.nombre,'') <> '')
         or (coalesce(p."Apellidos",'') = '' and coalesce(new.apellido,'') <> '')
       );
  end if;

  return new;
end
$function$;

comment on function public.fn_asignar_hc()
is 'Agenda HC trigger hardened for governed RPC search_path; P0 #492.';

comment on function public.fn_enriquecer_paciente_cita()
is 'Agenda patient enrichment trigger hardened for governed RPC search_path; P0 #492.';

select pg_notify('pgrst','reload schema');
