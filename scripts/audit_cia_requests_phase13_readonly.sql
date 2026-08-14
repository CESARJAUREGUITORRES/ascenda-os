-- ASCENDA OS · CIA V3 · Phase 13 read-only audit
-- Safe to run repeatedly. No writes.

select public.aos_cia_advisor_work_f13_readiness_v1() as f12_to_f13;
select public.aos_cia_request_f14_readiness_v1() as f13_to_f14;

select
  count(*)::integer as requests_total,
  count(*) filter (where state='PENDING')::integer as pending,
  count(*) filter (where state='APPROVED')::integer as approved,
  count(*) filter (where state='REJECTED')::integer as rejected,
  count(*) filter (where state='EXPIRED')::integer as expired,
  count(*) filter (where state='EXECUTED')::integer as executed
from public.aos_cia_requests;

select count(*)::integer as stale_open_requests
from public.aos_cia_requests r
left join public.aos_cia_assignments a on a.id=r.assignment_id
where r.state in ('PENDING','APPROVED')
  and (
    r.request_expires_at<=statement_timestamp()
    or a.id is null
    or a.advisor_user_id is distinct from r.requester_user_id
    or a.state not in ('ASSIGNED','IN_PROGRESS')
    or a.expires_at<=statement_timestamp()
  );

select count(*)::integer as owner_mismatch
from public.aos_cia_requests r
join public.aos_cia_assignments a on a.id=r.assignment_id
where r.state in ('PENDING','APPROVED')
  and (
    a.advisor_user_id is distinct from r.requester_user_id
    or a.advisor_user_id is distinct from r.owner_snapshot_user_id
  );

select count(*)::integer as duplicate_open
from (
  select assignment_id,request_type
  from public.aos_cia_requests
  where state in ('PENDING','APPROVED')
  group by assignment_id,request_type
  having count(*)>1
) d;

select
  public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','RELEASE_ASSIGNMENT') as f14_release_policy,
  public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT') as kronia_release_policy,
  public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','AUTO_ASSIGN') as auto_assign_policy;

select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       (select count(*) from pg_policy pol where pol.polrelid=c.oid) as policy_count,
       has_table_privilege('anon',c.oid,'SELECT') as anon_select,
       has_table_privilege('anon',c.oid,'INSERT') as anon_insert,
       has_table_privilege('anon',c.oid,'UPDATE') as anon_update,
       has_table_privilege('anon',c.oid,'DELETE') as anon_delete,
       has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select,
       has_table_privilege('authenticated',c.oid,'INSERT') as authenticated_insert,
       has_table_privilege('authenticated',c.oid,'UPDATE') as authenticated_update,
       has_table_privilege('authenticated',c.oid,'DELETE') as authenticated_delete
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in ('aos_cia_requests','aos_cia_request_events')
order by c.relname;

select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer,
       array_to_string(coalesce(p.proconfig,array[]::text[]),',') as function_config,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname like 'aos_cia_request%'
order by p.proname,args;

select version,name
from supabase_migrations.schema_migrations
where version in (
  '20260814164340','20260814164639','20260814164751','20260814164841',
  '20260814165455','20260814165749','20260814170410'
)
order by version;
