-- ASCENDA OS · WA-L5 deterministic UUID treatment resolver fix V1
-- Additive hardening only. No control flags, traffic or Agenda rows are mutated.
begin;

create or replace function public.aos_wa_l5_appointment_treatment_v1(p_appointment_id text)
returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_tid uuid;
  v_name text;
  v_count integer;
begin
  select o.treatment_id into v_tid
  from public.aos_booking_operations_v2 o
  where o.appointment_id=p_appointment_id
  order by o.created_at asc
  limit 1;
  if v_tid is not null then return v_tid; end if;

  select a.treatment_id into v_tid
  from public.aos_wa4_booking_actions_v1 a
  where a.agenda_id=p_appointment_id
  order by a.created_at asc
  limit 1;
  if v_tid is not null then return v_tid; end if;

  select c.tratamiento into v_name
  from public.aos_agenda_citas c
  where c.id=p_appointment_id;
  if coalesce(btrim(v_name),'')='' then return null; end if;

  select count(*)::integer into v_count
  from public.aos_catalogo_servicios s
  where upper(btrim(s.nombre))=upper(btrim(v_name))
    and upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO';
  if v_count<>1 then return null; end if;

  select s.id into v_tid
  from public.aos_catalogo_servicios s
  where upper(btrim(s.nombre))=upper(btrim(v_name))
    and upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
  limit 1;

  return v_tid;
end
$$;

revoke all on function public.aos_wa_l5_appointment_treatment_v1(text) from public,anon,authenticated;
grant execute on function public.aos_wa_l5_appointment_treatment_v1(text) to service_role;
comment on function public.aos_wa_l5_appointment_treatment_v1(text) is 'WA-L5 deterministic appointment treatment resolver. Name fallback resolves only when exactly one active service matches.';

select pg_notify('pgrst','reload schema');
commit;
