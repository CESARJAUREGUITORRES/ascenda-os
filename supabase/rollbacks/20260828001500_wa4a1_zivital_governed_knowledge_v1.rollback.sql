begin;
revoke all on function public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]) from public,anon,authenticated,service_role;
drop function if exists public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]);
drop table if exists public.aos_knowledge_relations_v1;
drop table if exists public.aos_knowledge_nodes_v1;
drop table if exists public.aos_knowledge_sources_v1;
commit;
