-- MKT-INTEGRITY-V3 — Loop 6 reentry data repair
-- Applied to Supabase LIVE on 2026-08-21 America/Lima after owner validation.
-- This file is idempotent evidence of the exact repair; it is not a schema migration.

begin;

-- Mireya — validated new prospects whose CITA_MANUAL calls were removed by cleanup.
insert into public.aos_llamadas
(id,fecha,numero,tratamiento,estado,hora_llamada,asesor,numero_limpio,id_asesor,anuncio,origen,intento,created_at,tipo_gestion,lead_id_origen,observacion)
select 37185,'2026-08-18','977555153','CAPILAR','CITA CONFIRMADA','21:11:45','MIREYA','977555153','ZIV-003','CAPILAR- INJERTO REEL4','MARKETING',1,'2026-08-19 02:11:45.701+00','LLAMADA_MANUAL_COMERCIAL',5687,'REPAIR VALIDADO 2026-08-21: llamada comercial real de prospecto nuevo; restaurada tras cleanup incorrecto.'
where not exists (select 1 from public.aos_llamadas where sync_key='977555153_2026-08-18_21:11:45_MIREYA');

insert into public.aos_llamadas
(id,fecha,numero,tratamiento,estado,hora_llamada,asesor,numero_limpio,id_asesor,anuncio,origen,intento,created_at,tipo_gestion,lead_id_origen,observacion)
select 37813,'2026-08-20','943980019','RADIOFRECUENCIA FRACCIONADA','CITA CONFIRMADA','18:53:37','MIREYA','943980019','ZIV-003','HIFU- FROZEN 2','MARKETING',1,'2026-08-20 23:53:37.154+00','LLAMADA_MANUAL_COMERCIAL',5829,'REPAIR VALIDADO 2026-08-21: llamada comercial real de prospecto nuevo; restaurada tras cleanup incorrecto.'
where not exists (select 1 from public.aos_llamadas where sync_key='943980019_2026-08-20_18:53:37_MIREYA');

insert into public.aos_llamadas
(id,fecha,numero,tratamiento,estado,hora_llamada,asesor,numero_limpio,id_asesor,anuncio,origen,intento,created_at,tipo_gestion,lead_id_origen,observacion)
select 38012,'2026-08-21','924706580','BIOESTIMULADOR','CITA CONFIRMADA','14:18:01','MIREYA','924706580','ZIV-003','BIOES- APLICACION REEL3','MARKETING',1,'2026-08-21 19:18:01.384+00','LLAMADA_MANUAL_COMERCIAL',5830,'REPAIR VALIDADO 2026-08-21: llamada comercial real de prospecto nuevo; restaurada tras cleanup incorrecto.'
where not exists (select 1 from public.aos_llamadas where sync_key='924706580_2026-08-21_14:18:01_MIREYA');

-- Ruvila — Alberto: one real conversion; first Agenda was a duplicate technical retry.
insert into public.aos_llamadas
(id,fecha,numero,tratamiento,estado,hora_llamada,asesor,numero_limpio,id_asesor,anuncio,origen,intento,created_at,tipo_gestion,lead_id_origen,observacion)
select 38168,'2026-08-21','948903052','CONSULTA MEDICA','CITA CONFIRMADA','16:10:12','RUVILA','948903052','ZIV-002','BIOES- APLICACION REEL3','MARKETING',1,'2026-08-21 21:10:12.815+00','LLAMADA_MANUAL_COMERCIAL',5018,'REPAIR VALIDADO 2026-08-21: recuperación comercial real; segunda Agenda era duplicado técnico.'
where not exists (select 1 from public.aos_llamadas where sync_key='948903052_2026-08-21_16:10:12_RUVILA');

-- Ruvila — Lidia: CALL_CENTER Agenda persisted but no call INSERT existed at all.
insert into public.aos_llamadas
(id,fecha,numero,tratamiento,estado,hora_llamada,asesor,numero_limpio,id_asesor,anuncio,origen,intento,created_at,tipo_gestion,lead_id_origen,observacion)
select 38186,'2026-08-21','964197925','HIFU','CITA CONFIRMADA','15:17:12','RUVILA','964197925','ZIV-002','HIFU- FROZEN 2','MARKETING',1,'2026-08-21 20:17:12.479+00','LLAMADA_MANUAL_COMERCIAL',5876,'REPAIR VALIDADO 2026-08-21: llamada comercial real; Agenda persistió pero llamada original no llegó a insertarse.'
where not exists (select 1 from public.aos_llamadas where sync_key='964197925_2026-08-21_15:17:12_RUVILA');

-- Direct trace links.
update public.aos_agenda_citas set lead_id_origen=5687,llamada_id_origen=37185 where id='8fd61e56-60a6-4d68-96c9-20a98a3d3c9e';
update public.aos_agenda_citas set lead_id_origen=5829,llamada_id_origen=37813 where id='eae7f420-73f7-4dee-9c55-0a06cbbb7a00';
update public.aos_agenda_citas set lead_id_origen=5830,llamada_id_origen=38012 where id='5f8f317d-31af-4f5d-8642-5955a77014ec';
update public.aos_agenda_citas set lead_id_origen=5018,llamada_id_origen=38168 where id='c9397f9c-f7ae-489a-bbcf-b1806a65bd51';
update public.aos_agenda_citas set lead_id_origen=5876,llamada_id_origen=38186 where id='87bf92b1-b10b-4986-9bff-75304d7868da';

-- Exact duplicate technical Agendas only.
delete from public.aos_agenda_citas where id='89490590-77ef-46f8-a304-bb73096e89f0'; -- Alberto 16:06 retry duplicate; keep c9397f9c...
delete from public.aos_agenda_citas where id='2120d8fb-0fb2-474c-9fc8-b4d522c71e25'; -- Alan 12:35:05 duplicate; keep 3e21556f... + call 36701

commit;
