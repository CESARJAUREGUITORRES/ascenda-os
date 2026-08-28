\set ON_ERROR_STOP on

-- Knowledge Graph must remap the reconciled CURRENT shape, not the historical 167-service shape.
do $$ begin
 if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE')<>184 then raise exception 'SEP26 graph services !=184'; end if;
 if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='PRODUCT')<>50 then raise exception 'SEP26 graph products !=50'; end if;
 if (select count(*) from public.aos_knowledge_entity_map_v1)<>234 then raise exception 'SEP26 graph total !=234'; end if;
 if exists(select 1 from public.aos_knowledge_entity_map_issues_v1) then raise exception 'SEP26 unresolved graph codes'; end if;
 if exists(
   select 1 from public.aos_catalogo_servicios c
   left join public.aos_knowledge_entity_map_v1 m on m.entity_id=c.id
   where c.estado='ACTIVO' and c.tipo in ('SERVICIO','PRODUCTO') and m.entity_id is null
 ) then raise exception 'SEP26 active catalog entity missing graph map'; end if;
 if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and entity_name like 'HIPERHIDROSIS%' and approach_codes=array['CROSS_DOMAIN_FUNCTIONAL'])<>2 then raise exception 'SEP26 hyperhidrosis functional mapping missing'; end if;
 if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and entity_name like 'CÁNULAS %' and approach_codes=array['CROSS_DOMAIN_OPERATIONAL'])<>2 then raise exception 'SEP26 cannula operational mapping missing'; end if;
 if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and category='VITAMINAS')<>41 then raise exception 'SEP26 Vitaminas graph !=41'; end if;
 if exists(select 1 from public.aos_knowledge_entity_map_v1 where cardinality(domain_codes)=0 or cardinality(approach_codes)=0 or cardinality(commercial_phase_codes)=0 or cardinality(clinical_lifecycle)=0 or nullif(btrim(zi_function),'') is null) then raise exception 'SEP26 blank graph dimension'; end if;
end $$;

-- 1C authority must follow 184 services + 50 products and 9 toppings with explicit currency.
-- Legacy products remain unchanged and are allowed to stay fail-closed if their old price state requires review.
do $$ begin
 if (select count(*) from public.aos_wa4_price_authority_v1)<>234 then raise exception 'SEP26 1C price authority !=234'; end if;
 if (select count(*) from public.aos_wa4_process_entity_context_v1)<>234 then raise exception 'SEP26 1C process context !=234'; end if;
 if (select count(*) from public.aos_wa4_topping_authority_v1)<>9 then raise exception 'SEP26 1C topping authority !=9'; end if;
 if (select count(*) from public.aos_wa4_price_authority_v1 where entity_type='SERVICIO' and moneda='USD')<>3 then raise exception 'SEP26 1C USD service rows !=3'; end if;
 if exists(select 1 from public.aos_wa4_price_authority_v1 where entity_type='SERVICIO' and moneda not in ('PEN','USD')) then raise exception 'SEP26 service currency invalid'; end if;
 if exists(select 1 from public.aos_wa4_price_authority_v1 where entity_type='SERVICIO' and not ready_for_quote) then raise exception 'SEP26 reconciled service price not quote-ready'; end if;
 if exists(select 1 from public.aos_wa4_process_entity_context_v1 where moneda is null) then raise exception 'SEP26 process context lost currency'; end if;
 if exists(select 1 from public.aos_wa4_topping_authority_v1 where moneda<>'PEN') then raise exception 'SEP26 topping currency unexpected'; end if;
end $$;

-- Quote-preview currency contract: one currency succeeds; mixed currency fails closed.
do $$
declare
 v_pen uuid;
 v_pen_phase text;
 v_usd uuid;
 v_usd_phase text;
 v_pen_result jsonb;
 v_usd_result jsonb;
 v_mixed jsonb;
begin
 select entity_id,commercial_phase_codes[1] into v_pen,v_pen_phase
 from public.aos_wa4_process_entity_context_v1
 where entity_type='SERVICIO' and moneda='PEN' and ready_for_quote
 order by entity_name limit 1;

 select entity_id,commercial_phase_codes[1] into v_usd,v_usd_phase
 from public.aos_wa4_process_entity_context_v1
 where entity_type='SERVICIO' and moneda='USD' and ready_for_quote
 order by entity_name limit 1;

 if v_pen is null or v_usd is null then raise exception 'SEP26 quote preview lacks PEN or USD candidate'; end if;

 select public.aos_wa4_quote_preview_v1(
   jsonb_build_array(jsonb_build_object('source_id',v_pen::text,'phase_code',v_pen_phase,'role','OPTIONAL_SUPPORT')),
   'COMPLETE',false
 ) into v_pen_result;
 if not coalesce((v_pen_result->>'ok')::boolean,false) or v_pen_result->>'currency'<>'PEN' or v_pen_result#>>'{lines,0,currency}'<>'PEN' then
   raise exception 'SEP26 PEN preview failed: %',v_pen_result;
 end if;

 select public.aos_wa4_quote_preview_v1(
   jsonb_build_array(jsonb_build_object('source_id',v_usd::text,'phase_code',v_usd_phase,'role','OPTIONAL_SUPPORT')),
   'COMPLETE',false
 ) into v_usd_result;
 if not coalesce((v_usd_result->>'ok')::boolean,false) or v_usd_result->>'currency'<>'USD' or v_usd_result#>>'{lines,0,currency}'<>'USD' then
   raise exception 'SEP26 USD preview failed: %',v_usd_result;
 end if;

 select public.aos_wa4_quote_preview_v1(
   jsonb_build_array(
     jsonb_build_object('source_id',v_pen::text,'phase_code',v_pen_phase,'role','OPTIONAL_SUPPORT'),
     jsonb_build_object('source_id',v_usd::text,'phase_code',v_usd_phase,'role','OPTIONAL_SUPPORT')
   ),
   'COMPLETE',false
 ) into v_mixed;
 if v_mixed->>'error'<>'MIXED_CURRENCY_NOT_SUPPORTED' then
   raise exception 'SEP26 mixed currency did not fail closed: %',v_mixed;
 end if;
end $$;

-- Price fingerprint and evidence include currency.
do $$ begin
 if nullif(public.aos_wa4_price_fingerprint_v1(),'') is null then raise exception 'SEP26 price fingerprint missing'; end if;
 if exists(select 1 from public.aos_wa4_price_authority_v1 where evidence_ref not like '%:'||moneda||':%') then raise exception 'SEP26 evidence ref lacks currency'; end if;
end $$;

select 'SEP26_WA4A1B_WA4A1C_REVALIDATION_PASS' as certification;
