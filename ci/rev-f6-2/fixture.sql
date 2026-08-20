\set ON_ERROR_STOP on

alter table public.aos_f5_patient_source_rows_v1 add column if not exists last_appointment date;
alter table public.aos_f5_patient_source_rows_v1 add column if not exists next_appointment date;

insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email","N° documento","SEDE_PRINCIPAL","FUENTE","FECHA_REGISTRO","ESTADO_PACIENTE",numero_limpio)
values
 ('P3','New','Patient','999300003','p3@example.test','30000003','SAN ISIDRO','TEST','2026-08-01','PACIENTE','999300003'),
 ('P4','Reactivated','Patient','999400004','p4@example.test','40000004','SAN ISIDRO','TEST','2025-01-01','PACIENTE','999400004'),
 ('P5','Active','Repeat','999500005','p5@example.test','50000005','PUEBLO LIBRE','TEST','2026-01-01','PACIENTE','999500005'),
 ('P6','Returning','Patient','999600006','p6@example.test','60000006','PUEBLO LIBRE','TEST','2026-01-01','PACIENTE','999600006'),
 ('P7','Dormant','Patient','999700007','p7@example.test','70000007','SAN ISIDRO','TEST','2025-01-01','PACIENTE','999700007'),
 ('P8','Future','Return','999800008','p8@example.test','80000008','SAN ISIDRO','TEST','2025-01-01','PACIENTE','999800008')
on conflict ("ID_PACIENTE") do nothing;

with b as (select id bid from public.aos_f5_source_batches_v1 order by id::text limit 1)
insert into public.aos_f5_patient_source_rows_v1(id,batch_id,source_row_num,source_patient_id,phone_key,document_key,email_key,last_appointment)
select * from (
  select 101,b.bid,101,'S-P4-H','999400004','40000004','p4@example.test','2025-12-01'::date from b
  union all select 102,b.bid,102,'S-P7-H','999700007','70000007','p7@example.test','2025-12-01'::date from b
  union all select 103,b.bid,103,'S-P8-H','999800008','80000008','p8@example.test','2025-12-01'::date from b
) x
on conflict (id) do nothing;

insert into public.aos_f5_identity_clusters_v1(id,status,confidence,source_row_count) values
 ('44444444-4444-4444-4444-444444444444','AUTO_CANDIDATE','HIGH',1),
 ('77777777-7777-7777-7777-777777777777','AUTO_CANDIDATE','HIGH',1),
 ('88888888-8888-8888-8888-888888888888','AUTO_CANDIDATE','HIGH',1)
on conflict (id) do nothing;

insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule,match_score) values
 ('44444444-4444-4444-4444-444444444444',101,'TEST',100),
 ('77777777-7777-7777-7777-777777777777',102,'TEST',100),
 ('88888888-8888-8888-8888-888888888888',103,'TEST',100);

insert into public.aos_f5_canonical_classification_v1(cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score) values
 ('44444444-4444-4444-4444-444444444444','P4','AUTO_CANDIDATE','MATCH','TEST','DNI_NAME+PHONE_NAME',100),
 ('77777777-7777-7777-7777-777777777777','P7','AUTO_CANDIDATE','MATCH','TEST','DNI_NAME+PHONE_NAME',100),
 ('88888888-8888-8888-8888-888888888888','P8','AUTO_CANDIDATE','MATCH','TEST','DNI_NAME+PHONE_NAME',100)
on conflict (cluster_id) do nothing;

insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,estado_cita,asesor) values
 ('F62-P3-1','2026-08-10','09:00','TEST','CONTROL','SAN ISIDRO','999300003','999300003','ASISTIO','ASESOR'),
 ('F62-P4-1','2026-08-10','09:00','TEST','CONTROL','SAN ISIDRO','999400004','999400004','ASISTIO','ASESOR'),
 ('F62-P5-1','2026-06-10','09:00','TEST','CONTROL','PUEBLO LIBRE','999500005','999500005','ASISTIO','ASESOR'),
 ('F62-P5-2','2026-08-10','09:00','TEST','CONTROL','PUEBLO LIBRE','999500005','999500005','EFECTIVA','ASESOR'),
 ('F62-P6-1','2026-04-15','09:00','TEST','CONTROL','PUEBLO LIBRE','999600006','999600006','ASISTIO','ASESOR'),
 ('F62-P8-F','2026-08-25','09:00','TEST','CONTROL','SAN ISIDRO','999800008','999800008','CITA CONFIRMADA','ASESOR')
on conflict (id) do nothing;
