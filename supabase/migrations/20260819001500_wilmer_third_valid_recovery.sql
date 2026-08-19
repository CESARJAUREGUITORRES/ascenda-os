-- Restore third valid Wilmer recovery under corrected rule.
insert into public.aos_llamadas
select (jsonb_populate_record(null::public.aos_llamadas,g.call_payload)).*
from public.aos_gestiones_no_comerciales g
where g.source_call_id=36962
on conflict(id) do nothing;

update public.aos_agenda_citas
set origen_cita='CALL_CENTER',
    origen='MARKETING',
    lead_id_origen=5198,
    llamada_id_origen=36962,
    etiqueta_campana=coalesce(nullif(etiqueta_campana,''),'CAPILAR')
where id='10c9dc32-a04c-4526-a0b3-ad4bceaf061b';

update public.aos_gestiones_no_comerciales
set clasificacion='RESTORED_VALID_RECOVERY',
    motivo='Corrección HOTFIX-3B: lead CAPILAR recuperado tras NO ASISTIO previo, sin venta/atención/asistencia previa; conversión Call Center válida.',
    source='HOTFIX3_VALID_RECOVERY'
where source_call_id=36962;
