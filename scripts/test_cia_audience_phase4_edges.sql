-- ASCENDA OS — CIA Phase 4 edge/security contract tests
begin;

-- known product present => never_contains MISS
do $$ declare ck text;e jsonb; begin
 select contact_key into ck from public.aos_cia_audience_source_v1_1 where 'BEAUTY MAKER'=any(canonical_products) limit 1;
 if ck is null then raise exception 'P4 missing known product sample'; end if;
 e:=public.aos_cia_audience_explain_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"sales.products","operator":"never_contains","value":"BEAUTY MAKER"}]}}',ck);
 if e->>'evaluation_state'<>'MISS' then raise exception 'P4 expected MISS %',e; end if;
end $$;

-- safely absent => never_contains MATCH
do $$ declare ck text;e jsonb; begin
 select contact_key into ck from public.aos_cia_audience_source_v1_1 where product_unresolved_count=0 and not ('BEAUTY MAKER'=any(canonical_products)) limit 1;
 e:=public.aos_cia_audience_explain_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"sales.products","operator":"never_contains","value":"BEAUTY MAKER"}]}}',ck);
 if e->>'evaluation_state'<>'MATCH' then raise exception 'P4 expected MATCH %',e; end if;
end $$;

-- ambiguous absence => UNKNOWN
do $$ declare ck text;e jsonb; begin
 select contact_key into ck from public.aos_cia_audience_source_v1_1 where product_unresolved_count>0 and not ('BEAUTY MAKER'=any(canonical_products)) limit 1;
 if ck is null then raise exception 'P4 missing unresolved product sample'; end if;
 e:=public.aos_cia_audience_explain_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"sales.products","operator":"never_contains","value":"BEAUTY MAKER"}]}}',ck);
 if e->>'evaluation_state'<>'UNKNOWN' then raise exception 'P4 expected UNKNOWN %',e; end if;
end $$;

-- BOOLEAN3 UNKNOWN can be queried explicitly
do $$ declare r jsonb; begin
 r:=public.aos_cia_audience_count_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"email.never_sent","operator":"is_unknown"}]}}');
 if not coalesce((r->>'ok')::boolean,false) or (r->>'count')::bigint<=0 then raise exception 'P4 BOOLEAN3 unknown failed %',r; end if;
end $$;

-- preview and count agree; requested 1000 is clamped to 100
do $$ declare f jsonb;c jsonb;p jsonb; begin
 f:='{"version":1,"root":{"op":"AND","rules":[{"field":"followups.overdue_count","operator":"gt","value":0}]}}';
 c:=public.aos_cia_audience_count_v1(f); p:=public.aos_cia_audience_preview_v1(f,1000,0);
 if c->>'count'<>p->>'count' then raise exception 'P4 count preview mismatch'; end if;
 if (p->>'limit')::int<>100 or jsonb_array_length(p->'items')>100 then raise exception 'P4 preview limit failed'; end if;
end $$;

-- RPC membership equals direct evaluator
do $$ declare f jsonb;c bigint;d bigint; begin
 f:='{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.ever_no_show","operator":"is_true"},{"field":"appointments.has_future","operator":"is_false"}]}}';
 c:=(public.aos_cia_audience_count_v1(f)->>'count')::bigint;
 select count(*) into d from public.aos_cia_audience_source_v1_1 s where public.aos_cia_audience_eval_node_v1(to_jsonb(s),f->'root',1);
 if c<>d then raise exception 'P4 RPC/direct mismatch %/%',c,d; end if;
end $$;

-- No dynamic SQL in audience functions
do $$ declare n int; begin
 select count(*) into n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
 where ns.nspname='public' and p.proname like 'aos_cia_audience_%'
 and (pg_get_functiondef(p.oid) ~* '\mEXECUTE\M' or pg_get_functiondef(p.oid) ~* '\mFORMAT\s*\(');
 if n<>0 then raise exception 'P4 dynamic SQL functions=%',n; end if;
end $$;

-- Browser roles must not execute public resolver contracts directly
do $$ declare n int; begin
 select count(*) into n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
 where ns.nspname='public' and p.proname in ('aos_cia_audience_count_v1','aos_cia_audience_preview_v1','aos_cia_audience_explain_v1')
 and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'));
 if n<>0 then raise exception 'P4 browser execute grants=%',n; end if;
 if has_table_privilege('anon','public.aos_audience_filter_registry','SELECT') or has_table_privilege('authenticated','public.aos_audience_filter_registry','SELECT') then raise exception 'P4 browser registry SELECT present'; end if;
end $$;

rollback;
