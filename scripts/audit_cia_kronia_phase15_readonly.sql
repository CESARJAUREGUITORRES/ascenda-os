-- ASCENDA OS CIA V3 — Phase 15 read-only audit
-- Safe to run against live. Does not intentionally mutate business/ownership state.

select public.aos_cia_intelligence_f15_readiness_v1() as f14_to_f15;
select public.aos_cia_kronia_f16_readiness_v1() as f15_to_f16;

select tool_key,version,display_name,operation_class,risk_class,request_type,active
from public.aos_cia_kronia_tool_registry
order by tool_key,version;

select agent_key,version,display_name,agent_class,allowed_tools,execution_mode,active
from public.aos_cia_kronia_agent_registry
order by agent_key,version;

select
  count(*) as tool_calls,
  count(*) filter (where status='SUCCEEDED') as succeeded,
  count(*) filter (where status='BLOCKED') as blocked,
  count(*) filter (where status='FAILED') as failed,
  count(*) filter (where auto_execute) as auto_execute_violations,
  round(avg(duration_ms),3) as avg_duration_ms,
  max(duration_ms) as max_duration_ms
from public.aos_cia_kronia_tool_calls;

select
  count(*) as proposals,
  count(*) filter (where state='REQUIRES_APPROVAL') as requires_approval,
  count(*) filter (where state='BLOCKED') as blocked,
  count(*) filter (where auto_execute) as auto_execute_violations
from public.aos_cia_kronia_proposals;

select
  public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT') as release_policy,
  public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','AUTO_ASSIGN') as autoassign_policy,
  public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RAW_SQL') as raw_sql_policy;

select c.relname as table_name,c.relrowsecurity as rls,
       (select count(*) from pg_policy p where p.polrelid=c.oid) as policy_count,
       has_table_privilege('anon',c.oid,'SELECT') as anon_select,
       has_table_privilege('anon',c.oid,'INSERT') as anon_insert,
       has_table_privilege('anon',c.oid,'UPDATE') as anon_update,
       has_table_privilege('anon',c.oid,'DELETE') as anon_delete,
       has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select,
       has_table_privilege('authenticated',c.oid,'INSERT') as authenticated_insert,
       has_table_privilege('authenticated',c.oid,'UPDATE') as authenticated_update,
       has_table_privilege('authenticated',c.oid,'DELETE') as authenticated_delete
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relname like 'aos_cia_kronia_%'
order by c.relname;

select p.proname,pg_get_function_identity_arguments(p.oid) as args,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
  'aos_cia_kronia_tool_invoke_v1',
  'aos_cia_kronia_link_request_v1',
  'aos_cia_kronia_request_outcome_sync_v1',
  'aos_cia_kronia_f16_readiness_v1',
  'aos_cia_kronia_admin_gateway_v1',
  'aos_execute_agent_query'
)
order by p.proname;

select
  has_table_privilege('anon','public.aos_agente_tareas','INSERT') as task_insert_anon,
  has_table_privilege('anon','public.aos_agente_tareas','UPDATE') as task_update_anon,
  has_table_privilege('anon','public.aos_agente_tareas','DELETE') as task_delete_anon,
  has_table_privilege('authenticated','public.aos_agente_tareas','INSERT') as task_insert_authenticated,
  has_table_privilege('authenticated','public.aos_agente_tareas','UPDATE') as task_update_authenticated,
  has_table_privilege('authenticated','public.aos_agente_tareas','DELETE') as task_delete_authenticated,
  obj_description('public.aos_execute_agent_query(text)'::regprocedure,'pg_proc') as legacy_query_guard;

select version,name
from supabase_migrations.schema_migrations
where version between '20260814184100' and '20260814184500'
order by version;

select
  (select count(*) from public.aos_cia_assignments) as assignments,
  (select count(*) from public.aos_cia_requests) as requests,
  (select count(*) from public.aos_cia_call_routing_events) as routing_events,
  (select count(*) from public.aos_cia_kronia_agent_runs) as f15_runs,
  (select count(*) from public.aos_cia_kronia_tool_calls) as f15_tool_calls,
  (select count(*) from public.aos_cia_kronia_proposals) as f15_proposals;
