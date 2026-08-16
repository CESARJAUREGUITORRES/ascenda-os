\set ON_ERROR_STOP on
begin;
\i supabase/migrations/20260816000600_f5_cluster_fieldwise_enrichment_v1.sql
select plan(25);

insert into public.aos_f5_source_batches_v1(
  source_sha256,source_filename,source_sede,source_year,source_rows,source_columns,schema_hash,metadata
) values (
  repeat('a',64),'SAN ISIDRO 2024.xlsx','SAN ISIDRO',2024,7,27,repeat('b',64),'{}'
);

insert into public.aos_pacientes(
  "ID_PACIENTE","Nombres","Apellidos","Teléfono",numero_limpio,"Email","N° documento","Sexo",
  "Fecha de nacimiento","Dirección","Ocupación",distrito,departamento,ciudad
) values
('P1','ANA','LOPEZ','999111111','999111111',null,'12345678',null,null,null,null,null,null,null),
('P2','BEA','RUIZ','999222222','999222222',null,null,'F','1985-02-02',null,null,null,null,null),
('P3','OTRO','PACIENTE','999999999','999999999','otro@example.com','87654321','M','1980-01-01','LIMA','ING',null,null,null);

select ok(to_regprocedure('public.aos_f5_ingest_compact_rows_v1(text,jsonb)') is not null,'1 compact ingest exists');
select ok(to_regprocedure('public.aos_f5_rebuild_identity_preview_v1()') is not null,'2 preview rebuild exists');
select is(has_function_privilege('anon','public.aos_f5_ingest_compact_rows_v1(text,jsonb)','EXECUTE'),false,'3 anon cannot compact ingest');
select is(has_function_privilege('authenticated','public.aos_f5_ingest_compact_rows_v1(text,jsonb)','EXECUTE'),false,'4 authenticated cannot compact ingest');
select is(has_function_privilege('service_role','public.aos_f5_ingest_compact_rows_v1(text,jsonb)','EXECUTE'),true,'5 service can compact ingest');
select is(has_function_privilege('anon','public.aos_f5_rebuild_identity_preview_v1()','EXECUTE'),false,'6 anon cannot rebuild preview');
select is(has_function_privilege('service_role','public.aos_f5_rebuild_identity_preview_v1()','EXECUTE'),true,'7 service can rebuild preview');

create temporary table ingest_result(j jsonb);
insert into ingest_result
select public.aos_f5_ingest_compact_rows_v1(
  repeat('a',64),
  '[
    [2,{"0":"01/01/2024","1":"A-1","2":"+51 999111111","3":"Ana","4":"López","5":"ana@example.com","6":"12345678","7":"F","8":"01/01/1990","9":"Av Uno 123, Miraflores, Lima, Lima","10":"ABOGADA","21":"No","23":"10/01/2024"}],
    [3,{"0":"02/01/2024","1":"A-2","2":"999111111","3":"ANA","4":"LOPEZ","5":"ana@example.com","6":"12345678","7":"F","8":"01/01/1990","21":"No","23":"12/01/2024"}],
    [4,{"0":"03/01/2024","1":"B-1","2":"999222222","3":"BEA","4":"RUIZ","7":"F","8":"02/02/1985","21":"No"}],
    [5,{"0":"04/01/2024","1":"B-2","2":"+51 999222222","3":"Bea","4":"Ruiz","7":"F","8":"02/02/1985","21":"No"}],
    [6,{"0":"05/01/2024","1":"C-1","2":"999333333","3":"CARLA","4":"PEREZ","7":"F","21":"No"}],
    [7,{"0":"06/01/2024","1":"D-1","3":"DAN","4":"UNO","5":"conflict@example.com","6":"11111111","7":"M","8":"01/01/1970","21":"No"}],
    [8,{"0":"07/01/2024","1":"D-2","3":"EVA","4":"DOS","5":"conflict@example.com","6":"22222222","7":"F","8":"01/01/1980","21":"No"}]
  ]'::jsonb
);

select is((select (j->>'ok')::boolean from ingest_result),true,'8 compact ingest succeeds');
select is((select (j->>'inserted')::integer from ingest_result),7,'9 seven source rows inserted');
select is((select count(*)::integer from public.aos_f5_patient_source_rows_v1),7,'10 staged row count exact');
select is((select (metadata->>'staging_complete')::boolean from public.aos_f5_source_batches_v1),true,'11 batch staging complete');
select is((select count(*)::integer from public.aos_pacientes),3,'12 canonical patients unchanged after ingest');

delete from ingest_result;
insert into ingest_result
select public.aos_f5_ingest_compact_rows_v1(
  repeat('a',64),
  '[
    [2,{"0":"01/01/2024","1":"A-1","2":"+51 999111111","3":"Ana","4":"López","5":"ana@example.com","6":"12345678","7":"F","8":"01/01/1990","9":"Av Uno 123, Miraflores, Lima, Lima","10":"ABOGADA","21":"No","23":"10/01/2024"}],
    [3,{"0":"02/01/2024","1":"A-2","2":"999111111","3":"ANA","4":"LOPEZ","5":"ana@example.com","6":"12345678","7":"F","8":"01/01/1990","21":"No","23":"12/01/2024"}],
    [4,{"0":"03/01/2024","1":"B-1","2":"999222222","3":"BEA","4":"RUIZ","7":"F","8":"02/02/1985","21":"No"}],
    [5,{"0":"04/01/2024","1":"B-2","2":"+51 999222222","3":"Bea","4":"Ruiz","7":"F","8":"02/02/1985","21":"No"}],
    [6,{"0":"05/01/2024","1":"C-1","2":"999333333","3":"CARLA","4":"PEREZ","7":"F","21":"No"}],
    [7,{"0":"06/01/2024","1":"D-1","3":"DAN","4":"UNO","5":"conflict@example.com","6":"11111111","7":"M","8":"01/01/1970","21":"No"}],
    [8,{"0":"07/01/2024","1":"D-2","3":"EVA","4":"DOS","5":"conflict@example.com","6":"22222222","7":"F","8":"01/01/1980","21":"No"}]
  ]'::jsonb
);
select is((select (j->>'inserted')::integer from ingest_result),0,'13 repeated source is idempotent');
select is((select (j->>'existing')::integer from ingest_result),7,'14 repeated source reports existing rows');

create temporary table rebuild_result(j jsonb);
insert into rebuild_result select public.aos_f5_rebuild_identity_preview_v1();

select is((select (j->>'source_rows')::integer from rebuild_result),7,'15 rebuild covers seven source rows');
select is((select (j->>'clusters')::integer from rebuild_result),4,'16 conservative connected-components produce four clusters');
select is((select (j->>'members')::integer from rebuild_result),7,'17 every source row has exactly one cluster member');
select is((select (j->>'auto_candidates')::integer from rebuild_result),1,'18 one high-confidence current patient candidate');
select is((select (j->>'review_required')::integer from rebuild_result),2,'19 phone-only and source-conflict clusters require review');
select is((select (j->>'unmatched')::integer from rebuild_result),1,'20 one source cluster remains unmatched');
select is((select (j->>'source_conflict_clusters')::integer from rebuild_result),1,'21 conflicting email-linked source identity is isolated for review');

select is((
  select target_patient_id from public.aos_f5_patient_link_preview_v1
  where match_status='AUTO_CANDIDATE'
),'P1','22 strong DNI/name + phone/name cluster targets P1');

select ok((
  select proposed_patch ? 'Email' and proposed_patch ? 'distrito'
  from public.aos_f5_patient_link_preview_v1
  where target_patient_id='P1'
),'23 enrichment preview fills missing fields from latest non-null source evidence');

select ok(exists(
  select 1 from public.aos_f5_patient_link_preview_v1
  where match_status='REVIEW_REQUIRED'
    and target_patient_id is null
    and (conflicts->>'DNI_CONFLICT')::boolean
),'24 source strong-identifier conflict remains human review with no target');

select is((select count(*)::integer from public.aos_pacientes),3,'25 preview rebuild does not mutate canonical patient count');

select * from finish();
rollback;
