-- Exact rollback for Carlos Aguilar Loop 6 V2.3 repair.
-- Removes ONLY rows created by repair key; preserves prior Call 38396.

do $rollback$
declare
  v_key text := 'repair-carlos-941764266-20260821-v23';
  v_call bigint;
  v_agenda text;
begin
  select a.llamada_id,a.agenda_id into v_call,v_agenda
  from public.aos_callcenter_actions_v1 a
  where a.idempotency_key=v_key
  limit 1;

  if v_call is null and v_agenda is null then return; end if;

  if v_agenda is not null then
    if not exists (
      select 1 from public.aos_agenda_citas x
      where x.id=v_agenda and x.numero_limpio='941764266' and x.llamada_id_origen=v_call and x.lead_id_origen=5894
    ) then raise exception 'CARLOS_ROLLBACK_AGENDA_PRECONDITION'; end if;
    delete from public.aos_agenda_citas where id=v_agenda;
  end if;

  if v_call is not null then
    if v_call=38396 then raise exception 'CARLOS_ROLLBACK_REFUSES_PRIOR_CALL'; end if;
    if not exists (
      select 1 from public.aos_llamadas l
      where l.id=v_call and l.numero_limpio='941764266' and l.estado='CITA CONFIRMADA' and l.lead_id_origen=5894
    ) then raise exception 'CARLOS_ROLLBACK_CALL_PRECONDITION'; end if;
    delete from public.aos_llamadas where id=v_call;
  end if;

  delete from public.aos_callcenter_actions_v1 where idempotency_key=v_key;
end
$rollback$;
