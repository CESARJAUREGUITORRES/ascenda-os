-- WA-4A Knowledge Fabric V1 rollback/recovery
-- Derived objects only. Canonical source tables are never mutated.
begin;

revoke all on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) from public,anon,authenticated,service_role;
drop function if exists public.aos_wa4a_knowledge_search_v1(text,integer,text[]);

drop view if exists public.aos_wa4a_knowledge_issues_v1;
drop view if exists public.aos_wa4a_knowledge_items_v1;
drop view if exists public.aos_wa4a_knowledge_authority_v1;

revoke all on function public.aos_wa4a_norm_v1(text) from public,anon,authenticated,service_role;
drop function if exists public.aos_wa4a_norm_v1(text);

commit;
