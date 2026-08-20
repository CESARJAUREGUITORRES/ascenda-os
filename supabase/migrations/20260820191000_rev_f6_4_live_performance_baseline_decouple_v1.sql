-- REV-F6.4 LIVE performance hotfix: remove expensive full Metric Trust baseline rebuild from each V3 request.
-- Historical 2024/2025 state remains the already-certified F6.3 semantic until F6.5 replaces it with a dynamic plug-in contract.

do $$
declare
  v_oid regprocedure := 'public.aos_rev_sales_intelligence_v3(integer,text,text)'::regprocedure;
  v_ddl text;
  v_old text := 'v_metric_baseline:=public.aos_rev_metric_trust_baseline_v1(); v_hist_2024:=v_metric_baseline->''TRANSACTIONAL_SALES_2024''; v_hist_2025:=v_metric_baseline->''TRANSACTIONAL_SALES_2025'';';
  v_new text := 'v_metric_baseline:=jsonb_build_object(''TRANSACTIONAL_SALES_2024'',jsonb_build_object(''value'',null,''source_status'',''NO_CERTIFIED_SOURCE'',''trust_level'',''UNAVAILABLE''),''TRANSACTIONAL_SALES_2025'',jsonb_build_object(''value'',null,''source_status'',''NO_CERTIFIED_SOURCE'',''trust_level'',''UNAVAILABLE'')); v_hist_2024:=v_metric_baseline->''TRANSACTIONAL_SALES_2024''; v_hist_2025:=v_metric_baseline->''TRANSACTIONAL_SALES_2025'';';
begin
  v_ddl := pg_get_functiondef(v_oid);
  if position(v_old in v_ddl)=0 then
    raise exception 'REV-F6.4 performance hotfix target not found; fail closed';
  end if;
  v_ddl := replace(v_ddl,v_old,v_new);
  execute v_ddl;
end $$;
