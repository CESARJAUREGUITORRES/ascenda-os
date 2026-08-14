-- ASCENDA OS — F14 Commercial Intelligence Shadow read-only audit
-- Safe: SELECT-only. Intended for recovery, CI-equivalent validation and post-merge smoke.

select public.aos_cia_request_f14_readiness_v1() as f13_to_f14;
select public.aos_cia_intelligence_f15_readiness_v1() as f14_to_f15;

select id,engine_version,status,started_at,completed_at,recommendation_count,source_counts,source_freshness,metadata
from public.aos_cia_intelligence_shadow_runs
order by completed_at desc nulls last,created_at desc
limit 5;

with latest as (
  select id from public.aos_cia_intelligence_shadow_runs
  where status='COMPLETE'
  order by completed_at desc nulls last,created_at desc
  limit 1
)
select opportunity_type,confidence,freshness_status,count(*)::int as n,
       min(priority_score) as min_score,max(priority_score) as max_score
from public.aos_cia_intelligence_recommendations
where run_id=(select id from latest)
group by opportunity_type,confidence,freshness_status
order by opportunity_type,confidence,freshness_status;

select c.relname as table_name,c.relrowsecurity as rls_enabled,
       (select count(*) from pg_policies p where p.schemaname='public' and p.tablename=c.relname)::int as policy_count,
       (has_table_privilege('anon','public.'||c.relname,'SELECT') or
        has_table_privilege('anon','public.'||c.relname,'INSERT') or
        has_table_privilege('anon','public.'||c.relname,'UPDATE') or
        has_table_privilege('anon','public.'||c.relname,'DELETE')) as anon_direct_access,
       (has_table_privilege('authenticated','public.'||c.relname,'SELECT') or
        has_table_privilege('authenticated','public.'||c.relname,'INSERT') or
        has_table_privilege('authenticated','public.'||c.relname,'UPDATE') or
        has_table_privilege('authenticated','public.'||c.relname,'DELETE')) as authenticated_direct_access
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in ('aos_cia_intelligence_shadow_runs','aos_cia_intelligence_recommendations','aos_cia_intelligence_events')
order by c.relname;

select
 has_function_privilege('anon','public.aos_cia_intelligence_shadow_refresh_v1(uuid)','EXECUTE') as anon_refresh,
 has_function_privilege('anon','public.aos_cia_intelligence_f15_readiness_v1()','EXECUTE') as anon_f15_readiness,
 has_function_privilege('anon','public.aos_cia_intelligence_link_request_v1(uuid,uuid)','EXECUTE') as anon_link,
 has_function_privilege('anon','public.aos_cia_intelligence_admin_gateway_v1(text,text,jsonb)','EXECUTE') as anon_admin_gateway,
 has_function_privilege('anon','public.aos_cia_intelligence_advisor_list_v1(text,text,integer,integer)','EXECUTE') as anon_advisor_list;

select version,name
from supabase_migrations.schema_migrations
where version in ('20260814181106','20260814181136','20260814181209')
order by version;

select
 (select count(*) from public.aos_cia_assignments)::int as assignments,
 (select count(*) from public.aos_cia_requests)::int as requests,
 (select count(*) from public.aos_cia_call_routing_events)::int as routing_events,
 (select count(*) from public.aos_cia_intelligence_shadow_runs)::int as intelligence_runs,
 (select count(*) from public.aos_cia_intelligence_recommendations)::int as intelligence_recommendations,
 (select count(*) from public.aos_cia_intelligence_events)::int as intelligence_events;
