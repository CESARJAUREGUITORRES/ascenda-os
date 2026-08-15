\set ON_ERROR_STOP on
begin;
select plan(12);

insert into public.aos_f5_source_batches_v1(source_sha256,source_filename,source_sede,source_year,source_rows,source_columns,schema_hash,status)
values(repeat('a',64),'SAN ISIDRO 2024.xlsx','SAN ISIDRO',2024,2,27,'schema','PROFILED');

select is(has_function_privilege('anon','public.aos_f5_ingest_source_rows_v1(text,jsonb)','EXECUTE'),false,'1 anon cannot execute private ingest');
select is(has_function_privilege('authenticated','public.aos_f5_ingest_source_rows_v1(text,jsonb)','EXECUTE'),false,'2 authenticated cannot execute private ingest');
select is(has_function_privilege('service_role','public.aos_f5_ingest_source_rows_v1(text,jsonb)','EXECUTE'),true,'3 service role can execute private ingest');

create temporary table r(j jsonb);
insert into r values(jsonb_build_array(
 jsonb_build_object('source_row_num',2,'source_patient_id','SRC-1','phone_raw','+51 999111222','phone_key','999111222','phone_type','PERU_9','names_raw','ANA','surnames_raw','PEREZ','name_key','ANA PEREZ','row_content_hash',repeat('1',64),'identity_seed_hash',repeat('b',64),'raw_payload',jsonb_build_object('Nombres','ANA')),
 jsonb_build_object('source_row_num',3,'source_patient_id','SRC-2','phone_raw','999222333','phone_key','999222333','phone_type','PERU_9','names_raw','LUIS','surnames_raw','ROJAS','name_key','LUIS ROJAS','row_content_hash',repeat('2',64),'identity_seed_hash',repeat('c',64),'raw_payload',jsonb_build_object('Nombres','LUIS'))
));

select is((public.aos_f5_ingest_source_rows_v1(repeat('a',64),(select j from r))->>'inserted')::integer,2,'4 first ingest inserts two');
select is((select count(*)::integer from public.aos_f5_patient_source_rows_v1),2,'5 two source rows persisted in transaction');
select is((select raw_payload->>'Nombres' from public.aos_f5_patient_source_rows_v1 where source_row_num=2),'ANA','6 raw payload preserved');
select is((public.aos_f5_ingest_source_rows_v1(repeat('a',64),(select j from r))->>'inserted')::integer,0,'7 rerun is idempotent');
select is((select count(*)::integer from public.aos_f5_patient_source_rows_v1),2,'8 rerun does not duplicate');
select is((select (metadata->>'staging_complete')::boolean from public.aos_f5_source_batches_v1 where source_sha256=repeat('a',64)),true,'9 batch marked complete when row count matches manifest');
select throws_ok($$select public.aos_f5_ingest_source_rows_v1(repeat('a',64),jsonb_build_array(jsonb_build_object('source_row_num',2,'source_patient_id','SRC-1','row_content_hash',repeat('9',64),'raw_payload','{}'::jsonb)))$$,'P0001','SOURCE_ROW_HASH_CONFLICT','10 changed content for same source row is rejected');
select throws_ok($$select public.aos_f5_ingest_source_rows_v1(repeat('d',64),'[]'::jsonb)$$,'P0001','CHUNK_SIZE_OUT_OF_RANGE','11 empty chunks rejected');
select ok(exists(select 1 from public.aos_f5_audit_v1 where action='SOURCE_ROWS_CHUNK_INGESTED'),'12 ingest is audited');

select * from finish();
rollback;
