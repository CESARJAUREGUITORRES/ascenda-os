\set ON_ERROR_STOP on

select case when (select count(*) from public.aos_knowledge_sources_v1)=2 then 'ok 1 sources' else 'not ok 1 sources' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where status='APPROVED')=22 then 'ok 2 nodes' else 'not ok 2 nodes' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where node_type='DOMAIN')=3 then 'ok 3 domains' else 'not ok 3 domains' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where node_type='APPROACH')=8 then 'ok 4 approaches' else 'not ok 4 approaches' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where node_type='PHASE')=7 then 'ok 5 phases' else 'not ok 5 phases' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where node_type='ROLE')=3 then 'ok 6 roles' else 'not ok 6 roles' end;

-- Public client must only receive public answer and never internal/system/clinical text.
with x as (
  select * from public.aos_wa4a_knowledge_search_v2('Skin Signature','PUBLIC_CLIENT',10,array['CLINIC_KNOWLEDGE'])
)
select case when exists(select 1 from x where subject_id='FACIAL_SKIN_SIGNATURE' and facts->>'audience'='PUBLIC_CLIENT' and facts ? 'answer' and not (facts ? 'system_reference') and not (facts ? 'public_summary'))
then 'ok 7 public isolation' else 'not ok 7 public isolation' end;

-- Advisor gets advisor answer plus public summary, never system_reference.
with x as (
  select * from public.aos_wa4a_knowledge_search_v2('Skin Signature','ADVISOR_INTERNAL',10,array['CLINIC_KNOWLEDGE'])
)
select case when exists(select 1 from x where subject_id='FACIAL_SKIN_SIGNATURE' and facts->>'audience'='ADVISOR_INTERNAL' and facts ? 'answer' and facts ? 'public_summary' and not (facts ? 'system_reference'))
then 'ok 8 advisor isolation' else 'not ok 8 advisor isolation' end;

-- Owner/admin can receive system_reference.
with x as (
  select * from public.aos_wa4a_knowledge_search_v2('Sculpt Body','OWNER_ADMIN',10,array['CLINIC_KNOWLEDGE'])
)
select case when exists(select 1 from x where subject_id='CORPORAL_SCULPT_BODY' and facts ? 'system_reference')
then 'ok 9 owner system refs' else 'not ok 9 owner system refs' end;

-- Clinical restricted is only returned when explicitly requested.
with pub as (
  select facts from public.aos_wa4a_knowledge_search_v2('dutasteride','PUBLIC_CLIENT',20,array['CLINIC_KNOWLEDGE'])
), cli as (
  select facts from public.aos_wa4a_knowledge_search_v2('dutasteride','CLINICAL_RESTRICTED',20,array['CLINIC_KNOWLEDGE'])
)
select case when not exists(select 1 from pub where lower(facts->>'answer') like '%dutasteride%') and exists(select 1 from cli where lower(facts->>'answer') like '%dutasteride%')
then 'ok 10 clinical isolation' else 'not ok 10 clinical isolation' end;

-- Aliases resolve without duplicate concepts.
select case when (select count(*) from public.aos_knowledge_nodes_v1 where code='CAPILAR_ACTIVACION_REGENERACION' and aliases @> '["Hair Revival"]'::jsonb)=1
then 'ok 11 alias canonical' else 'not ok 11 alias canonical' end;
select case when (select count(*) from public.aos_knowledge_nodes_v1 where code='CORPORAL_SCULPT_BODY' and aliases @> '["Contour Sculpt"]'::jsonb)=1
then 'ok 12 alias sculpt' else 'not ok 12 alias sculpt' end;

-- Exact catalog links are additive references; no canonical catalog mutation required.
select case when exists(select 1 from public.aos_knowledge_relations_v1 r join public.aos_catalogo_servicios s on s.id=r.target_id where r.knowledge_code='FACIAL_SKIN_SIGNATURE' and s.nombre='PINK GLOW 1ML')
then 'ok 13 catalog relation' else 'not ok 13 catalog relation' end;

-- ACLs: anon/authenticated must have no table privileges.
select case when not has_table_privilege('anon','public.aos_knowledge_nodes_v1','select') and not has_table_privilege('authenticated','public.aos_knowledge_nodes_v1','select')
then 'ok 14 acl' else 'not ok 14 acl' end;

-- Search V2 service_role only.
select case when has_function_privilege('service_role','public.aos_wa4a_knowledge_search_v2(text,text,integer,text[])','execute') and not has_function_privilege('anon','public.aos_wa4a_knowledge_search_v2(text,text,integer,text[])','execute')
then 'ok 15 rpc acl' else 'not ok 15 rpc acl' end;

\echo WA4A1_ZIVITAL_GOVERNED_KNOWLEDGE_PASS
