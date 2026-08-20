\set ON_ERROR_STOP on

-- HIGH: reviewed F5 MATCH + non-conflicting aliases.
insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email","N° documento","SEDE_PRINCIPAL","FUENTE","FECHA_REGISTRO","ESTADO_PACIENTE",numero_limpio)
values
 ('F63-HIGH','High','Trust','999630001','high63@example.test','63000001','SAN ISIDRO','TEST','2026-01-01','PACIENTE','999630001'),
 ('F63-MEDIUM','Medium','Trust','999630002','medium63@example.test','63000002','PUEBLO LIBRE','TEST','2026-01-01','PACIENTE','999630002'),
 ('F63-FUSED','Fused','Trust','999630003','fused63@example.test','63000003','SAN ISIDRO','TEST','2026-01-01','FUSIONADO','999630003');

with b as (select id bid from public.aos_f5_source_batches_v1 order by id::text limit 1)
insert into public.aos_f5_patient_source_rows_v1(id,batch_id,source_row_num,source_patient_id,phone_key,document_key,email_key)
select 6301,b.bid,6301,'SRC-F63-HIGH','51999630001','63000001','high63@example.test' from b;

insert into public.aos_f5_identity_clusters_v1(id,status,confidence,source_row_count)
values ('63630000-0000-0000-0000-000000000001','AUTO_CANDIDATE','HIGH',1);
insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule,match_score)
values ('63630000-0000-0000-0000-000000000001',6301,'F63_UNIQUE_STRONG',100);
insert into public.aos_f5_canonical_classification_v1(cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score)
values ('63630000-0000-0000-0000-000000000001','F63-HIGH','AUTO_CANDIDATE','MATCH','F63_TEST','DNI_NAME+PHONE_NAME',100);
