\set ON_ERROR_STOP on
begin;
select plan(30);

select has_table('public','aos_f5_source_batches_v1','1 source batches exists');
select has_table('public','aos_f5_patient_source_rows_v1','2 source rows exists');
select has_table('public','aos_f5_identity_clusters_v1','3 identity clusters exists');
select has_table('public','aos_f5_identity_cluster_members_v1','4 cluster members exists');
select has_table('public','aos_f5_patient_link_preview_v1','5 link preview exists');
select has_table('public','aos_f5_audit_v1','6 audit exists');

select ok((select relrowsecurity from pg_class where oid='public.aos_f5_source_batches_v1'::regclass),'7 batches RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.aos_f5_patient_source_rows_v1'::regclass),'8 source rows RLS enabled');

select is(has_table_privilege('anon','public.aos_f5_source_batches_v1','SELECT'),false,'9 anon cannot select batches');
select is(has_table_privilege('anon','public.aos_f5_patient_source_rows_v1','SELECT'),false,'10 anon cannot select source rows');
select is(has_table_privilege('anon','public.aos_f5_identity_clusters_v1','SELECT'),false,'11 anon cannot select clusters');
select is(has_table_privilege('anon','public.aos_f5_identity_cluster_members_v1','SELECT'),false,'12 anon cannot select members');
select is(has_table_privilege('anon','public.aos_f5_patient_link_preview_v1','SELECT'),false,'13 anon cannot select preview');
select is(has_table_privilege('anon','public.aos_f5_audit_v1','SELECT'),false,'14 anon cannot select audit');

insert into public.aos_f5_source_batches_v1(source_sha256,source_filename,source_sede,source_year,source_rows,source_columns,schema_hash)
values('sha-test-1','SAN ISIDRO 2024.xlsx','SAN ISIDRO',2024,1,27,'schema-1');
select is((select status from public.aos_f5_source_batches_v1 where source_sha256='sha-test-1'),'STAGED','15 batch defaults STAGED');
select throws_ok($$insert into public.aos_f5_source_batches_v1(source_sha256,source_filename,source_sede,source_year,source_rows,source_columns,schema_hash) values('sha-test-1','dup.xlsx','SAN ISIDRO',2024,1,27,'schema-1')$$,'23505','16 source SHA is idempotent');

select lives_ok($$insert into public.aos_f5_patient_source_rows_v1(batch_id,source_row_num,source_patient_id,phone_raw,phone_key,phone_type,names_raw,surnames_raw,name_key,row_content_hash,identity_seed_hash,raw_payload) select id,2,'123','+51 999111222','999111222','PERU_9','ANA','PEREZ','ANA PEREZ','rowhash-1','seed-1','{"Nombres":"ANA","Teléfono":"+51 999111222"}'::jsonb from public.aos_f5_source_batches_v1 where source_sha256='sha-test-1'$$,'17 source evidence insert works');
select throws_ok($$insert into public.aos_f5_patient_source_rows_v1(batch_id,source_row_num,source_patient_id,row_content_hash,raw_payload) select id,2,'456','rowhash-2','{}'::jsonb from public.aos_f5_source_batches_v1 where source_sha256='sha-test-1'$$,'23505','18 duplicate source row blocked');
select is((select raw_payload->>'Nombres' from public.aos_f5_patient_source_rows_v1 where row_content_hash='rowhash-1'),'ANA','19 raw payload preserved');
select is((select count(*)::integer from public.aos_f5_patient_source_rows_v1),1,'20 exactly one source row');

select lives_ok($$insert into public.aos_f5_identity_clusters_v1(cluster_key,confidence,source_row_count,canonical_preview,evidence) values('cluster-1','HIGH',1,'{"name":"ANA PEREZ"}'::jsonb,'{"rules":["name_phone"]}'::jsonb)$$,'21 cluster insert works');
select is((select status from public.aos_f5_identity_clusters_v1 where cluster_key='cluster-1'),'PROPOSED','22 cluster defaults PROPOSED');
select lives_ok($$insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule,match_score) select c.id,r.id,'EXACT_NAME_PHONE',100 from public.aos_f5_identity_clusters_v1 c cross join public.aos_f5_patient_source_rows_v1 r where c.cluster_key='cluster-1' and r.row_content_hash='rowhash-1'$$,'23 cluster member insert works');
select throws_ok($$insert into public.aos_f5_identity_clusters_v1(cluster_key,confidence,source_row_count) values('cluster-2','HIGH',1); insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule) select c.id,r.id,'DUP' from public.aos_f5_identity_clusters_v1 c cross join public.aos_f5_patient_source_rows_v1 r where c.cluster_key='cluster-2' and r.row_content_hash='rowhash-1'$$,'23505','24 source row cannot belong to two clusters');

select lives_ok($$insert into public.aos_f5_patient_link_preview_v1(cluster_id,match_status,match_method,match_score,evidence,current_snapshot,proposed_patch) select id,'AUTO_CANDIDATE','PHONE_NAME',100,'{"phone":"match"}'::jsonb,'{}'::jsonb,'{"distrito":"PUEBLO LIBRE"}'::jsonb from public.aos_f5_identity_clusters_v1 where cluster_key='cluster-1'$$,'25 preview insert works');
select is((select requires_human from public.aos_f5_patient_link_preview_v1 p join public.aos_f5_identity_clusters_v1 c on c.id=p.cluster_id where c.cluster_key='cluster-1'),true,'26 preview defaults human review');
select is((select proposed_patch->>'distrito' from public.aos_f5_patient_link_preview_v1 p join public.aos_f5_identity_clusters_v1 c on c.id=p.cluster_id where c.cluster_key='cluster-1'),'PUEBLO LIBRE','27 proposed patch stored separately');

select is(has_table_privilege('authenticated','public.aos_f5_patient_source_rows_v1','SELECT'),false,'28 authenticated cannot read PII staging');
select is(has_table_privilege('authenticated','public.aos_f5_patient_link_preview_v1','SELECT'),false,'29 authenticated cannot read merge preview');
select ok(exists(select 1 from public.aos_security_log where accion='F5_IDENTITY_FOUNDATION_SCHEMA'),'30 schema action audited');

select * from finish();
rollback;
