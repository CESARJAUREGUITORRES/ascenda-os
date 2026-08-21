\set ON_ERROR_STOP on

create or replace function pg_temp.f66_hot_signal(p_eval jsonb,p_id text)
returns jsonb language sql immutable as $$
  select value from jsonb_array_elements(p_eval->'signals') where value->>'signal_id'=p_id limit 1
$$;

create or replace function pg_temp.f66_hot_states(p_eval jsonb)
returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(value->>'signal_id',value->>'state'),'{}'::jsonb)
  from jsonb_array_elements(p_eval->'signals')
$$;

do $$
declare
  s jsonb;
  h jsonb;
  r jsonb;
  t0 timestamptz;
  ms numeric;
  i integer;
  v_unrelated_state text;
  v_baseline_summary jsonb;
  v_baseline_states jsonb;
begin
  if to_regprocedure('public.aos_sentinel_rev_f6_6_snapshot_full_v1()') is null then raise exception 'HOTFIX_FULL_SNAPSHOT_MISSING'; end if;
  if to_regprocedure('public.aos_sentinel_rev_f6_6_refresh_cache_v1()') is null then raise exception 'HOTFIX_REFRESH_MISSING'; end if;
  if to_regclass('public.aos_sentinel_rev_f6_6_sensor_cache_v1') is null then raise exception 'HOTFIX_CACHE_TABLE_MISSING'; end if;
  if has_function_privilege('anon','public.aos_sentinel_rev_f6_6_snapshot_full_v1()','EXECUTE') then raise exception 'HOTFIX_FULL_ANON'; end if;
  if has_function_privilege('authenticated','public.aos_sentinel_rev_f6_6_snapshot_full_v1()','EXECUTE') then raise exception 'HOTFIX_FULL_AUTH'; end if;
  if not has_function_privilege('service_role','public.aos_sentinel_rev_f6_6_snapshot_full_v1()','EXECUTE') then raise exception 'HOTFIX_FULL_SERVICE'; end if;
  if has_function_privilege('anon','public.aos_sentinel_rev_f6_6_refresh_cache_v1()','EXECUTE') then raise exception 'HOTFIX_REFRESH_ANON'; end if;
  if has_function_privilege('authenticated','public.aos_sentinel_rev_f6_6_refresh_cache_v1()','EXECUTE') then raise exception 'HOTFIX_REFRESH_AUTH'; end if;
  if not has_function_privilege('service_role','public.aos_sentinel_rev_f6_6_refresh_cache_v1()','EXECUTE') then raise exception 'HOTFIX_REFRESH_SERVICE'; end if;
  if has_table_privilege('anon','public.aos_sentinel_rev_f6_6_sensor_cache_v1','SELECT') then raise exception 'HOTFIX_CACHE_ANON'; end if;
  if has_table_privilege('authenticated','public.aos_sentinel_rev_f6_6_sensor_cache_v1','SELECT') then raise exception 'HOTFIX_CACHE_AUTH'; end if;

  s:=public.aos_sentinel_rev_f6_6_snapshot_v1();
  if s->>'cache_state'<>'CURRENT' then raise exception 'HOTFIX_CACHE_NOT_CURRENT:%',s->>'cache_state'; end if;
  if jsonb_array_length(coalesce(s->'cache_dirty_domains','[]'::jsonb))<>0 then raise exception 'HOTFIX_DIRTY_AFTER_PRIME'; end if;

  for i in 1..3 loop
    t0:=clock_timestamp();
    h:=public.aos_sentinel_rev_f6_6_integrity_health_v1();
    ms:=extract(epoch from (clock_timestamp()-t0))*1000;
    if ms>=1000 then raise exception 'HOTFIX_HEALTH_TOO_SLOW:%ms',ms; end if;
  end loop;

  v_baseline_summary:=h->'summary';
  v_baseline_states:=pg_temp.f66_hot_states(h);
  v_unrelated_state:=pg_temp.f66_hot_signal(h,'SEN-DQ-F5-001')->>'state';

  update public.aos_sentinel_rev_f6_6_sensor_cache_v1
  set dirty_domains=array['SALES']::text[]
  where singleton=true;

  s:=public.aos_sentinel_rev_f6_6_snapshot_v1();
  if s->>'cache_state'<>'STALE' then raise exception 'HOTFIX_STALE_MARKER_MISSING'; end if;

  h:=public.aos_sentinel_rev_f6_6_integrity_health_v1();
  if pg_temp.f66_hot_signal(h,'SEN-DQ-REV-001')->>'state'<>'UNKNOWN' then raise exception 'HOTFIX_SALES_PRODUCT_FALSE_GREEN'; end if;
  if pg_temp.f66_hot_signal(h,'SEN-DQ-REV-002')->>'state'<>'UNKNOWN' then raise exception 'HOTFIX_SALES_RECON_FALSE_GREEN'; end if;
  if pg_temp.f66_hot_signal(h,'SEN-DQ-F6-001')->>'state'<>'UNKNOWN' then raise exception 'HOTFIX_SALES_READMODEL_FALSE_GREEN'; end if;
  if pg_temp.f66_hot_signal(h,'SEN-DQ-F6-002')->>'state'<>'UNKNOWN' then raise exception 'HOTFIX_SALES_COVERAGE_FALSE_GREEN'; end if;
  if pg_temp.f66_hot_signal(h,'SEN-DQ-F5-001')->>'state' is distinct from v_unrelated_state then raise exception 'HOTFIX_UNRELATED_DOMAIN_REGRESSION'; end if;

  r:=public.aos_sentinel_rev_f6_6_refresh_cache_v1();
  if coalesce((r->>'ok')::boolean,false)=false or r->>'cache_state'<>'CURRENT' then raise exception 'HOTFIX_REFRESH_FAILED'; end if;

  h:=public.aos_sentinel_rev_f6_6_integrity_health_v1();
  if h->'summary' is distinct from v_baseline_summary then
    raise exception 'HOTFIX_POST_REFRESH_SUMMARY_DRIFT:baseline=% after=%',v_baseline_summary,h->'summary';
  end if;
  if pg_temp.f66_hot_states(h) is distinct from v_baseline_states then
    raise exception 'HOTFIX_POST_REFRESH_STATE_DRIFT:baseline=% after=%',v_baseline_states,pg_temp.f66_hot_states(h);
  end if;

  if h::text ~* '"(dni|address|birth_date|clinical_note|message_body|payment_reference|raw_payload|identifier_key|target_patient_id|canonical_patient_id)"[[:space:]]*:' then raise exception 'HOTFIX_PII_KEY'; end if;
  if h::text ~* '\b[0-9]{8,9}\b' then raise exception 'HOTFIX_IDENTIFIER_LIKE_VALUE'; end if;
  if h::text ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' then raise exception 'HOTFIX_EMAIL_LIKE_VALUE'; end if;
end $$;

select 'REV-F6.6_SENSOR_CACHE_PERFORMANCE_HOTFIX_PASS' as certificate;
