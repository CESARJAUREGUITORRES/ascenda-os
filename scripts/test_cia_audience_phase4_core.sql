-- ASCENDA OS — CIA Phase 4 core contract tests
begin;

do $$ declare a int;b int;d int; begin
 select count(*) into a from public.aos_cia_commercial_facts_v1;
 select count(*),count(*)-count(distinct contact_key) into b,d from public.aos_cia_audience_source_v1_1;
 if a<>b or d<>0 then raise exception 'P4 source grain facts=% source=% dup=%',a,b,d; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from public.aos_audience_filter_registry r where active=true and public.aos_cia_audience_effective_field_type_v1(r.field_key) is null;
 if n<>0 then raise exception 'P4 registry fields without type=%',n; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from public.aos_audience_presets p where active=true and not coalesce((public.aos_cia_audience_validate_v1(p.dsl)->>'valid')::boolean,false);
 if n<>0 then raise exception 'P4 invalid presets=%',n; end if;
end $$;

do $$ declare v jsonb; begin
 v:=public.aos_cia_audience_validate_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"evil.sql","operator":"eq","value":"x"}]}}');
 if coalesce((v->>'valid')::boolean,false) then raise exception 'P4 unknown field accepted'; end if;
end $$;

do $$ declare v jsonb; begin
 v:=public.aos_cia_audience_validate_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"sales.total","operator":"contains","value":"1"}]}}');
 if coalesce((v->>'valid')::boolean,false) then raise exception 'P4 invalid operator accepted'; end if;
end $$;

do $$ declare v jsonb; begin
 v:=public.aos_cia_audience_validate_v1('{"version":1,"root":{"op":"AND","rules":[{"field":"sales.total","operator":"gte","value":0},{"op":"OR","rules":[{"field":"segment.value_tier","operator":"eq","value":"GOLD"},{"field":"segment.value_tier","operator":"eq","value":"DIAMANTE"}]}]}}');
 if not coalesce((v->>'valid')::boolean,false) then raise exception 'P4 allowed nesting rejected %',v; end if;
end $$;

do $$ declare v jsonb; begin
 v:=public.aos_cia_audience_validate_v1('{"version":1,"root":{"op":"AND","rules":[{"op":"OR","rules":[{"op":"AND","rules":[{"field":"sales.total","operator":"gte","value":0}]}]}]}}');
 if coalesce((v->>'valid')::boolean,false) then raise exception 'P4 third group level accepted'; end if;
end $$;

do $$ declare f jsonb;v jsonb; begin
 select jsonb_build_object('version',1,'root',jsonb_build_object('op','AND','rules',jsonb_agg(jsonb_build_object('field','sales.total','operator','gte','value',0)))) into f from generate_series(1,26);
 v:=public.aos_cia_audience_validate_v1(f);
 if coalesce((v->>'valid')::boolean,false) then raise exception 'P4 >25 rules accepted'; end if;
end $$;

do $$ declare p1 bigint;p2 bigint;s1 bigint;s2 bigint; begin
 select sum(product_row_count),sum(service_row_count) into p1,s1 from public.aos_cia_purchase_detail_facts_v1;
 select sum(product_count),sum(service_count) into p2,s2 from public.aos_cia_commercial_facts_v1;
 if p1<>p2 or s1<>s2 then raise exception 'P4 purchase mismatch products %/% services %/%',p1,p2,s1,s2; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from public.aos_cia_purchase_detail_facts_v1 where product_mapped_count+product_unresolved_count<>product_row_count;
 if n<>0 then raise exception 'P4 product partition mismatch=%',n; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from public.aos_product_alias_overrides o where o.active=true and not exists(select 1 from public.aos_catalogo_servicios c where upper(btrim(coalesce(c.tipo,'')))='PRODUCTO' and upper(btrim(c.nombre_corto))=upper(btrim(o.canonical_short_name)));
 if n<>0 then raise exception 'P4 missing alias catalog targets=%',n; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from (select alias_key from public.aos_cia_product_catalog_alias_v1 group by alias_key having count(*)>1)d;
 if n<>0 then raise exception 'P4 ambiguous alias keys=%',n; end if;
end $$;

rollback;
