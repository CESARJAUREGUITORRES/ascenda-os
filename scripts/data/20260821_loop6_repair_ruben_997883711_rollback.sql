do $rollback$
declare
  v_key text:='repair-ruben-997883711-20260821-193506';
  v_call bigint;
begin
  select llamada_id into v_call from public.aos_callcenter_actions_v1 where idempotency_key=v_key;
  if v_call is null then raise exception 'RUBEN_REPAIR_JOURNAL_NOT_FOUND'; end if;

  update public.aos_agenda_citas
  set lead_id_origen=null,
      llamada_id_origen=null,
      origen_cita='CITA_MANUAL',
      ts_actualizado='2026-08-22T00:35:07.336729+00:00'
  where id='2c581c52-89e9-465f-89be-0e3818eda309' and llamada_id_origen=v_call and lead_id_origen=5884;

  update public.aos_seguimientos
  set "ESTADO"='PENDIENTE',
      "TS_ACTUALIZADO"='2026-08-21T23:23:41.097Z',
      lead_id_origen=null
  where "ID"='SEG-1787354621097-4zle' and lead_id_origen=5884;

  delete from public.aos_callcenter_actions_v1 where idempotency_key=v_key and llamada_id=v_call;
  delete from public.aos_llamadas
  where id=v_call and numero_limpio='997883711' and upper(coalesce(asesor,''))='MIREYA'
    and tipo_gestion='FOLLOWUP_CONVERSION' and lead_id_origen=5884;
end
$rollback$;
