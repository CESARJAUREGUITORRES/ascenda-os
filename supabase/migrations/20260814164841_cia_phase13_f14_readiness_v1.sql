create or replace function public.aos_cia_request_f14_readiness_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_f13 jsonb;
  v_total integer;
  v_open integer;
  v_stale integer;
  v_owner_mismatch integer;
  v_duplicate_open integer;
  v_policy_shadow jsonb;
  v_policy_kronia jsonb;
  v_policy_block jsonb;
  v_rls_requests boolean;
  v_rls_events boolean;
  v_anon_table boolean;
  v_auth_table boolean;
  v_ready boolean;
  v_status text;
begin
  v_f13 := public.aos_cia_advisor_work_f13_readiness_v1();

  select count(*)::integer,
         count(*) filter(where state in ('PENDING','APPROVED'))::integer
    into v_total,v_open
  from public.aos_cia_requests;

  select count(*)::integer into v_stale
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

  select count(*)::integer into v_owner_mismatch
  from public.aos_cia_requests r
  join public.aos_cia_assignments a on a.id=r.assignment_id
  where r.state in ('PENDING','APPROVED')
    and (a.advisor_user_id is distinct from r.requester_user_id or a.advisor_user_id is distinct from r.owner_snapshot_user_id);

  select count(*)::integer into v_duplicate_open
  from (
    select assignment_id,request_type
    from public.aos_cia_requests
    where state in ('PENDING','APPROVED')
    group by assignment_id,request_type
    having count(*)>1
  ) d;

  v_policy_shadow := public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','RELEASE_ASSIGNMENT');
  v_policy_kronia := public.aos_cia_request_policy_gate_v1('KRONIA','PROPOSE','RELEASE_ASSIGNMENT');
  v_policy_block := public.aos_cia_request_policy_gate_v1('F14_INTELLIGENCE','PROPOSE','AUTO_ASSIGN');

  select c.relrowsecurity into v_rls_requests
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='aos_cia_requests';
  select c.relrowsecurity into v_rls_events
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='aos_cia_request_events';

  select has_table_privilege('anon','public.aos_cia_requests','SELECT,INSERT,UPDATE,DELETE') into v_anon_table;
  select has_table_privilege('authenticated','public.aos_cia_requests','SELECT,INSERT,UPDATE,DELETE') into v_auth_table;

  v_ready := coalesce((v_f13->>'ready_for_f13')::boolean,false)
    and v_stale=0
    and v_owner_mismatch=0
    and v_duplicate_open=0
    and coalesce(v_policy_shadow->>'decision','')='REQUIRE_APPROVAL'
    and coalesce(v_policy_kronia->>'decision','')='REQUIRE_APPROVAL'
    and coalesce(v_policy_block->>'decision','')='BLOCK'
    and coalesce(v_rls_requests,false)
    and coalesce(v_rls_events,false)
    and not coalesce(v_anon_table,true)
    and not coalesce(v_auth_table,true);

  v_status := case
    when coalesce((v_f13->>'ready_for_f13')::boolean,false) is not true then 'BLOCKED_F12'
    when v_stale>0 or v_owner_mismatch>0 or v_duplicate_open>0 then 'BLOCKED_INTEGRITY'
    when coalesce(v_policy_shadow->>'decision','')<>'REQUIRE_APPROVAL'
      or coalesce(v_policy_kronia->>'decision','')<>'REQUIRE_APPROVAL'
      or coalesce(v_policy_block->>'decision','')<>'BLOCK' then 'BLOCKED_POLICY'
    when not coalesce(v_rls_requests,false) or not coalesce(v_rls_events,false)
      or coalesce(v_anon_table,true) or coalesce(v_auth_table,true) then 'BLOCKED_SECURITY'
    when v_total=0 then 'READY_NO_REQUESTS'
    else 'READY'
  end;

  return jsonb_build_object(
    'ok',true,
    'ready_for_f14',v_ready,
    'status',v_status,
    'f12_to_f13',v_f13,
    'requests_total',v_total,
    'open_requests',v_open,
    'stale_open_requests',v_stale,
    'owner_mismatch',v_owner_mismatch,
    'duplicate_open',v_duplicate_open,
    'policy_shadow',v_policy_shadow,
    'policy_kronia',v_policy_kronia,
    'policy_block_auto_assign',v_policy_block,
    'rls_requests',v_rls_requests,
    'rls_events',v_rls_events,
    'browser_direct_table_access',jsonb_build_object('anon',v_anon_table,'authenticated',v_auth_table)
  );
end
$function$;

revoke all on function public.aos_cia_request_f14_readiness_v1() from public,anon,authenticated;
