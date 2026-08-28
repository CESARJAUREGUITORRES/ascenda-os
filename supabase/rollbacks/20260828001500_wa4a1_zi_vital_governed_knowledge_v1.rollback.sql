-- WA-4A.1 rollback — remove Zi Vital derived governed knowledge only.
begin;
drop function if exists public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer);
drop view if exists public.aos_wa4a1_zi_knowledge_items_v1;
drop table if exists public.aos_zi_knowledge_entities_v1;
drop table if exists public.aos_zi_knowledge_sources_v1;
commit;
