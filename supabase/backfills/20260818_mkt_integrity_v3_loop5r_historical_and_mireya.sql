-- MKT-INTEGRITY-HOTFIX-V3 / LOOP 5R
-- Requires cleanup semantic migration already applied.
-- Atomic targeted repair: 2 observed Mireya calls + 4 explicitly inferred historical calls.

begin;

-- Exact observed historical calls.
insert into public.aos_llamadas(id,fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion)
select 37108,'2026-08-18'::date,'991144656','991144656','CAPILAR','CITA CONFIRMADA','19:16:08','MIREYA','ZIV-003',1,'2026-08-19T00:16:08.933Z'::timestamptz,'LLAMADA_MANUAL_COMERCIAL'
where not exists(select 1 from public.aos_llamadas where id=37108);

insert into public.aos_llamadas(id,fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion)
select 37110,'2026-08-18'::date,'980547287','980547287','CAPILAR','CITA CONFIRMADA','19:23:27','MIREYA','ZIV-003',1,'2026-08-19T00:23:27.821Z'::timestamptz,'LLAMADA_MANUAL_COMERCIAL'
where not exists(select 1 from public.aos_llamadas where id=37110);

-- Existing Agenda direct links for observed calls.
update public.aos_agenda_citas
set lead_id_origen=5664,llamada_id_origen=37108
where id='6b1c4962-a597-45d8-8b72-d721d71c20f4'
  and lead_id_origen is null and llamada_id_origen is null;

update public.aos_agenda_citas
set lead_id_origen=5599,llamada_id_origen=37110
where id='d80a4d17-5f2e-4169-8814-c5d5c50eac5c'
  and lead_id_origen is null and llamada_id_origen is null;

-- Historical inferred calls: proxy date = lead date; 00:00:00 is an explicit sentinel/proxy, not an observed time.
insert into public.aos_llamadas(fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion,lead_id_origen,origen,anuncio,observacion)
select '2026-01-14','954848810','954848810','CAPILAR','CITA CONFIRMADA','00:00:00','WILMER','ZIV-004',1,now(),'INFERIDA_HISTORICA',51,'MARKETING','CAPILAR - Cabello debil','[AOS HISTÓRICO] Gestión inferida por lead previo + primera conversión. Fecha proxy=fecha del lead; hora real no disponible.'
where not exists(select 1 from public.aos_llamadas where sync_key='954848810_2026-01-14_00:00:00_WILMER');

insert into public.aos_llamadas(fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion,lead_id_origen,origen,anuncio,observacion)
select '2026-01-22','960381839','960381839','ENZIMAS FACIALES','CITA CONFIRMADA','00:00:00','MIREYA','ZIV-003',1,now(),'INFERIDA_HISTORICA',571,'MARKETING','ENZI . Solucion papada marcada','[AOS HISTÓRICO] Gestión inferida por lead previo + primera conversión. Fecha proxy=fecha del lead; hora real no disponible.'
where not exists(select 1 from public.aos_llamadas where sync_key='960381839_2026-01-22_00:00:00_MIREYA');

insert into public.aos_llamadas(fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion,lead_id_origen,origen,anuncio,observacion)
select '2026-01-26','964633863','964633863','CRIOLIPOLISIS','CITA CONFIRMADA','00:00:00','MIREYA','ZIV-003',1,now(),'INFERIDA_HISTORICA',667,'MARKETING','CRIO - reedfine tu cilueta','[AOS HISTÓRICO] Gestión inferida por lead previo + primera conversión. Fecha proxy=fecha del lead; hora real no disponible.'
where not exists(select 1 from public.aos_llamadas where sync_key='964633863_2026-01-26_00:00:00_MIREYA');

insert into public.aos_llamadas(fecha,numero,numero_limpio,tratamiento,estado,hora_llamada,asesor,id_asesor,intento,created_at,tipo_gestion,lead_id_origen,origen,anuncio,observacion)
select '2026-01-26','930260184','930260184','CRIOLIPOLISIS','CITA CONFIRMADA','00:00:00','WILMER','ZIV-004',1,now(),'INFERIDA_HISTORICA',661,'MARKETING','CRIO - reedfine tu cilueta','[AOS HISTÓRICO] Gestión inferida por lead previo + primera conversión. Fecha proxy=fecha del lead; hora real no disponible.'
where not exists(select 1 from public.aos_llamadas where sync_key='930260184_2026-01-26_00:00:00_WILMER');

-- Link the historical conversion Agenda to the inferred direct call.
update public.aos_agenda_citas set lead_id_origen=51,llamada_id_origen=(select id from public.aos_llamadas where sync_key='954848810_2026-01-14_00:00:00_WILMER') where id='f0dec87b-38f1-4a07-b128-1c563ad508ac' and lead_id_origen is null and llamada_id_origen is null;
update public.aos_agenda_citas set lead_id_origen=571,llamada_id_origen=(select id from public.aos_llamadas where sync_key='960381839_2026-01-22_00:00:00_MIREYA') where id='ec5533f7-4ab7-4ca4-a3d3-8a1a079ba60b' and lead_id_origen is null and llamada_id_origen is null;
update public.aos_agenda_citas set lead_id_origen=667,llamada_id_origen=(select id from public.aos_llamadas where sync_key='964633863_2026-01-26_00:00:00_MIREYA') where id='fedb1bab-4cd2-4d90-9b4e-7f5d785caf26' and lead_id_origen is null and llamada_id_origen is null;
update public.aos_agenda_citas set lead_id_origen=661,llamada_id_origen=(select id from public.aos_llamadas where sync_key='930260184_2026-01-26_00:00:00_WILMER') where id='76334df7-21e1-492e-9a09-72e588932c59' and lead_id_origen is null and llamada_id_origen is null;

-- Assertions: two observed + four inferred calls and six Agenda links must exist.
do $$
begin
  if (select count(*) from public.aos_llamadas where id in (37108,37110)) <> 2 then raise exception 'Loop5R expected 2 observed Mireya calls'; end if;
  if (select count(*) from public.aos_llamadas where tipo_gestion='INFERIDA_HISTORICA' and sync_key in ('954848810_2026-01-14_00:00:00_WILMER','960381839_2026-01-22_00:00:00_MIREYA','964633863_2026-01-26_00:00:00_MIREYA','930260184_2026-01-26_00:00:00_WILMER')) <> 4 then raise exception 'Loop5R expected 4 inferred historical calls'; end if;
  if (select count(*) from public.aos_agenda_citas where id in ('6b1c4962-a597-45d8-8b72-d721d71c20f4','d80a4d17-5f2e-4169-8814-c5d5c50eac5c','f0dec87b-38f1-4a07-b128-1c563ad508ac','ec5533f7-4ab7-4ca4-a3d3-8a1a079ba60b','fedb1bab-4cd2-4d90-9b4e-7f5d785caf26','76334df7-21e1-492e-9a09-72e588932c59') and lead_id_origen is not null and llamada_id_origen is not null) <> 6 then raise exception 'Loop5R expected 6 Agenda links'; end if;
end $$;

commit;
