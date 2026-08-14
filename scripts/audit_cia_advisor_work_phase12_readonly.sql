-- ASCENDA OS — Phase 12 Advisor Work Views read-only audit
-- Safe: no writes.

select public.aos_cia_call_routing_f12_readiness_v1() as f11_to_f12;
select public.aos_cia_advisor_work_f13_readiness_v1() as f12_to_f13;

select
  c.relrowsecurity as rls_enabled,
  (select count(*) from pg_policies p where p.schemaname='public' and p.tablename='aos_cia_advisor_work_preferences') as policies,
  has_table_privilege('anon','public.aos_cia_advisor_work_preferences','SELECT') as anon_select,
  has_table_privilege('authenticated','public.aos_cia_advisor_work_preferences','SELECT') as authenticated_select
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='aos_cia_advisor_work_preferences';

select p.proname,p.prosecdef as security_definer,p.proconfig,
  has_function_privilege('anon',p.oid,'EXECUTE') as anon_exec,
  has_function_privilege('service_role',p.oid,'EXECUTE') as service_exec
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname like 'aos_cia_advisor_work_%'
order by p.proname;

select
  (select count(*) from public.aos_cia_advisor_work_preferences) as preferences,
  (select count(*) from public.aos_cia_assignment_plans) as plans,
  (select count(*) from public.aos_cia_assignment_targets) as targets,
  (select count(*) from public.aos_cia_assignment_runs) as runs,
  (select count(*) from public.aos_cia_assignments) as assignments,
  (select count(*) from public.aos_cia_assignment_events) as assignment_events,
  (select count(*) from public.aos_cia_call_routing_events) as routing_events,
  (select count(*) from public.aos_audiencias where nombre ilike 'QA12%') as qa_audiences;

select md5(pg_get_functiondef('public.aos_siguiente_lead(text,text,date)'::regprocedure)) as siguiente_lead_hash,
       md5(pg_get_functiondef('public.aos_siguiente_lead_v2(text,text,date)'::regprocedure)) as siguiente_lead_v2_current_hash;

select version,name
from supabase_migrations.schema_migrations
where name like 'cia_phase12_%'
order by version;
