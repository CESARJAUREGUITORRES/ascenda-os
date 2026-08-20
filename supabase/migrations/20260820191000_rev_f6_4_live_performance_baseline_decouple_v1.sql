-- REV-F6.4 LIVE performance hotfix: remove expensive full Metric Trust baseline rebuild from each V3 request.
-- Historical 2024/2025 state remains the already-certified F6.3 semantic until F6.5 replaces it with a dynamic plug-in contract.
-- This patch is formatting-independent: it replaces only the expensive function expression inside pg_get_functiondef().

do $$
declare
  v_oid regprocedure := 'public.aos_rev_sales_intelligence_v3(integer,text,text)'::regprocedure;
  v_ddl text;
  v_target text := 'public.aos_rev_metric_trust_baseline_v1()';
  v_replacement text := 'jsonb_build_object(''TRANSACTIONAL_SALES_2024'',jsonb_build_object(''value'',null,''source_status'',''NO_CERTIFIED_SOURCE'',''trust_level'',''UNAVAILABLE''),''TRANSACTIONAL_SALES_2025'',jsonb_build_object(''value'',null,''source_status'',''NO_CERTIFIED_SOURCE'',''trust_level'',''UNAVAILABLE''))';
begin
  v_ddl := pg_get_functiondef(v_oid);
  if position(v_target in v_ddl)>0 then
    v_ddl := replace(v_ddl,v_target,v_replacement);
    execute v_ddl;
  elsif position('NO_CERTIFIED_SOURCE' in v_ddl)>0 then
    -- Idempotent replay: the function is already decoupled.
    null;
  else
    raise exception 'REV-F6.4 performance hotfix target not found and no certified replacement present; fail closed';
  end if;
end $$;
