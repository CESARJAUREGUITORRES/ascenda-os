-- Exact rollback contract for MKT-INTEGRITY-HOTFIX-V3 / LOOP 5R.
-- Run only if the AFTER values still match this repair.

begin;

-- Clear inferred historical Agenda links first, resolving call ids by exact sync_key.
update public.aos_agenda_citas a
set lead_id_origen=null,llamada_id_origen=null
where (a.id,a.lead_id_origen,a.llamada_id_origen) in (
  select 'f0dec87b-38f1-4a07-b128-1c563ad508ac'::uuid,51::bigint,l.id from public.aos_llamadas l where l.sync_key='954848810_2026-01-14_00:00:00_WILMER' and l.tipo_gestion='INFERIDA_HISTORICA'
  union all
  select 'ec5533f7-4ab7-4ca4-a3d3-8a1a079ba60b'::uuid,571::bigint,l.id from public.aos_llamadas l where l.sync_key='960381839_2026-01-22_00:00:00_MIREYA' and l.tipo_gestion='INFERIDA_HISTORICA'
  union all
  select 'fedb1bab-4cd2-4d90-9b4e-7f5d785caf26'::uuid,667::bigint,l.id from public.aos_llamadas l where l.sync_key='964633863_2026-01-26_00:00:00_MIREYA' and l.tipo_gestion='INFERIDA_HISTORICA'
  union all
  select '76334df7-21e1-492e-9a09-72e588932c59'::uuid,661::bigint,l.id from public.aos_llamadas l where l.sync_key='930260184_2026-01-26_00:00:00_WILMER' and l.tipo_gestion='INFERIDA_HISTORICA'
);

-- Clear Mireya direct links only if they still point to the exact restored calls/leads.
update public.aos_agenda_citas set lead_id_origen=null,llamada_id_origen=null where id='6b1c4962-a597-45d8-8b72-d721d71c20f4' and lead_id_origen=5664 and llamada_id_origen=37108;
update public.aos_agenda_citas set lead_id_origen=null,llamada_id_origen=null where id='d80a4d17-5f2e-4169-8814-c5d5c50eac5c' and lead_id_origen=5599 and llamada_id_origen=37110;

-- Delete inferred rows only when all semantic identifiers match.
delete from public.aos_llamadas where tipo_gestion='INFERIDA_HISTORICA' and sync_key in (
 '954848810_2026-01-14_00:00:00_WILMER',
 '960381839_2026-01-22_00:00:00_MIREYA',
 '964633863_2026-01-26_00:00:00_MIREYA',
 '930260184_2026-01-26_00:00:00_WILMER'
) and upper(coalesce(estado,''))='CITA CONFIRMADA' and upper(coalesce(origen,''))='MARKETING';

-- Delete restored observed rows only if exact AFTER semantics still match.
delete from public.aos_llamadas where id=37108 and numero_limpio='991144656' and asesor='MIREYA' and estado='CITA CONFIRMADA' and tipo_gestion='LLAMADA_MANUAL_COMERCIAL' and lead_id_origen=5664 and origen='MARKETING';
delete from public.aos_llamadas where id=37110 and numero_limpio='980547287' and asesor='MIREYA' and estado='CITA CONFIRMADA' and tipo_gestion='LLAMADA_MANUAL_COMERCIAL' and lead_id_origen=5599 and origen='MARKETING';

-- Restore previous cleanup definition exactly if a full Loop 5R rollback is required.
create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare v_call_ts timestamptz; v_agenda_ts timestamptz; v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g'); v_agenda_ts:=coalesce(new.ts_creado,now());
    delete from public.aos_llamadas l where l.numero_limpio=v_num and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and (upper(coalesce(l.estado,''))='CITA CONFIRMADA' or (upper(coalesce(l.estado,''))='SEGUIMIENTO' and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE')) and abs(extract(epoch from(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts)))<=10;
    return new;
  end if;
  if tg_table_name='aos_llamadas' then
    if not (upper(coalesce(new.estado,''))='CITA CONFIRMADA' or (upper(coalesce(new.estado,''))='SEGUIMIENTO' and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE')) then return new; end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g'); v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
    if exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(a.origen_cita,''))='CITA_MANUAL' and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10) then delete from public.aos_llamadas where id=new.id; end if;
    return new;
  end if;
  return new;
end;
$function$;

commit;
