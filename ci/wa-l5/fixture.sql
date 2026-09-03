-- WA-L5 TEST-ONLY fixture. No production PII/PHI.

create table if not exists public.aos_rev_customer_agenda_identity_v1(
  appointment_id text primary key,
  fecha_cita date,
  estado_cita text,
  canonical_patient_id text,
  candidate_count integer,
  identity_status text,
  match_methods jsonb default '[]'::jsonb
);

update public.aos_usuarios
set nivel_jerarquia=1,
    paneles_acceso=case when 'admin-whatsapp'=any(coalesce(paneles_acceso,'{}'::text[])) then paneles_acceso else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-whatsapp') end,
    activo=true,two_factor=true
where id='11111111-1111-4111-8111-111111111111'::uuid;

insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email","N° documento","SEDE_PRINCIPAL","ESTADO_PACIENTE",numero_limpio)
values('P-L5-TEST-1','PACIENTE','SINTETICO','51933333333',null,'12345678','SAN ISIDRO','ACTIVO','51933333333')
on conflict("ID_PACIENTE") do update set "Nombres"='PACIENTE',"Apellidos"='SINTETICO',"N° documento"='12345678',numero_limpio='51933333333',"ESTADO_PACIENTE"='ACTIVO';

create or replace function public.aos_rev_resolve_patient_identity_v2(p_lookup_type text,p_lookup_value text)
returns jsonb
language plpgsql
stable
as $$
declare v text:=regexp_replace(coalesce(p_lookup_value,''),'[^0-9]','','g');
begin
  if upper(coalesce(p_lookup_type,''))<>'PHONE' then return jsonb_build_object('status','UNRESOLVED','candidate_count',0); end if;
  if v='51922222222' then return jsonb_build_object('status','IDENTITY_CONFLICT','candidate_count',2,'confidence_band','CONFLICT'); end if;
  if v='51933333333' then return jsonb_build_object('status','MATCH','candidate_count',1,'canonical_patient_id','P-L5-TEST-1','confidence_band','HIGH'); end if;
  return jsonb_build_object('status','UNRESOLVED','candidate_count',0,'confidence_band','NONE');
end
$$;

grant execute on function public.aos_rev_resolve_patient_identity_v2(text,text) to service_role;

insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,phone_number_id,state,campaign_source,contact_address,contact_address_type)
values
('55555555-5555-4555-8555-555555555551'::uuid,'wa-l5-book:51911111111','51911111111','CLIENTE BOOK','local-phone-id','AI_ACTIVE','L5_SYNTHETIC','51911111111','PHONE'),
('55555555-5555-4555-8555-555555555552'::uuid,'wa-l5-rebook:51933333333','51933333333','PACIENTE SINTETICO','local-phone-id','AI_ACTIVE','L5_SYNTHETIC','51933333333','PHONE'),
('55555555-5555-4555-8555-555555555553'::uuid,'wa-l5-conflict:51922222222','51922222222','CONFLICT TEST','local-phone-id','AI_ACTIVE','L5_SYNTHETIC','51922222222','PHONE')
on conflict(id) do update set state='AI_ACTIVE',human_takeover_at=null,contact_number=excluded.contact_number,contact_address=excluded.contact_address,contact_address_type='PHONE';

-- Align the synthetic provider with the exact governed capability selected by the
-- canonical booking fixture. AGV2 requires treatment -> capability -> team skill ->
-- date/site schedule intersection; this creates a real TEST-only eligible slot.
update public.aos_perfiles_profesional p
set servicios=array[s.nombre]::text[]
from public.aos_wa4c_booking_test_fixture f
join public.aos_catalogo_servicios s on s.id=f.treatment_id
where f.id=1 and p.id=f.professional_id;

-- The production WA4 trigger intentionally blocks direct WhatsApp Agenda writes.
-- This TEST-ONLY fixture enters the same governed transaction-local boundary rather
-- than weakening or bypassing the production trigger contract.
begin;
select set_config('aos.wa4_governed_booking_write','1',true);
with f as (
  select treatment_id,target_date from public.aos_wa4c_booking_test_fixture where id=1
), s as (
  select c.nombre,f.target_date from f join public.aos_catalogo_servicios c on c.id=f.treatment_id
)
insert into public.aos_agenda_citas(
  id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,dni,correo,asesor,id_asesor,estado_cita,
  ts_creado,ts_actualizado,hora_cita,doctora,tipo_atencion,origen_cita,numero_limpio,origen,llamada_id_origen
)
select 'L5-REBOOK-APPT-1',s.target_date,s.nombre,'CONSULTA NUEVA','SAN ISIDRO','51933333333','PACIENTE','SINTETICO','12345678',null,
       'WHATSAPP','00000000-0000-4000-8000-000000000004','PENDIENTE',now(),now(),'10:30','DRA. TEST','DOCTORA','WHATSAPP','51933333333','WHATSAPP_ORGANIC',null
from s
on conflict(id) do update set fecha_cita=excluded.fecha_cita,hora_cita='10:30',sede='SAN ISIDRO',estado_cita='PENDIENTE',numero='51933333333',numero_limpio='51933333333';
commit;

insert into public.aos_rev_customer_agenda_identity_v1(appointment_id,fecha_cita,estado_cita,canonical_patient_id,candidate_count,identity_status,match_methods)
select a.id,a.fecha_cita,a.estado_cita,'P-L5-TEST-1',1,'RESOLVED','["DOCUMENT_EXACT","PHONE_CONTEXT"]'::jsonb
from public.aos_agenda_citas a where a.id='L5-REBOOK-APPT-1'
on conflict(appointment_id) do update set fecha_cita=excluded.fecha_cita,estado_cita=excluded.estado_cita,canonical_patient_id='P-L5-TEST-1',candidate_count=1,identity_status='RESOLVED';
