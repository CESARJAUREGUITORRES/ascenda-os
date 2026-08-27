\set ON_ERROR_STOP on

DO $$
BEGIN
  IF (select count(*) from public.aos_wa4a_knowledge_authority_v1) < 8 then raise exception 'WA4A_AUTHORITY_MATRIX_INCOMPLETE'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_authority_v1 where domain='EXCLUDED' and source_relation='generic_llm_knowledge' and authority_state='NON_AUTHORITY') then raise exception 'WA4A_GENERIC_LLM_NOT_EXCLUDED'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_authority_v1 where domain='HOURS' and source_relation='public.aos_config_horarios' and authority_tier=10) then raise exception 'WA4A_HOURS_AUTHORITY_MISSING'; end if;
END $$;

DO $$
DECLARE f jsonb;
BEGIN
  select facts into f from public.aos_wa4a_knowledge_items_v1 where knowledge_id='service:10000000-0000-4000-8000-000000000001';
  IF f is null then raise exception 'WA4A_SERVICE_FACT_MISSING'; end if;
  IF f ? 'descripcion_clinica' or f ? 'indicaciones' or f ? 'contraindicaciones' or f ? 'perfil_paciente' or f ? 'composicion' or f ? 'mecanismo_accion' then
    raise exception 'WA4A_CLINICAL_FIELD_LEAK';
  end if;
  IF not (f ? 'precio_base' and f ? 'descripcion_comercial' and f ? 'faqs') then raise exception 'WA4A_COMMERCIAL_FACTS_INCOMPLETE'; end if;
END $$;

DO $$
BEGIN
  IF not exists(select 1 from public.aos_wa4a_knowledge_items_v1 where knowledge_id='service:10000000-0000-4000-8000-000000000001' and retrieval_state='READY' and freshness_state='FRESH' and conflict_state='CLEAR') then raise exception 'WA4A_READY_SERVICE_FAILED'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_issues_v1 where knowledge_id='service:10000000-0000-4000-8000-000000000002' and retrieval_state='BLOCKED_STALE') then raise exception 'WA4A_STALE_FAIL_CLOSED_FAILED'; end if;
  IF (select count(*) from public.aos_wa4a_knowledge_issues_v1 where subject_key=public.aos_wa4a_norm_v1('Laser Conflict') and retrieval_state='BLOCKED_CONFLICT') <> 2 then raise exception 'WA4A_SERVICE_CONFLICT_FAILED'; end if;
END $$;

DO $$
BEGIN
  IF not exists(select 1 from public.aos_wa4a_knowledge_items_v1 where knowledge_id='promotion:20000000-0000-4000-8000-000000000001' and retrieval_state='READY') then raise exception 'WA4A_PROMO_VALIDITY_FAILED'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_issues_v1 where knowledge_id='promotion:20000000-0000-4000-8000-000000000002' and retrieval_state='BLOCKED_EXPIRED') then raise exception 'WA4A_EXPIRED_PROMO_FAIL_CLOSED_FAILED'; end if;
END $$;

DO $$
DECLARE f jsonb;
BEGIN
  select facts into f from public.aos_wa4a_knowledge_items_v1 where domain='BRANCH' and subject_key=public.aos_wa4a_norm_v1('SAN ISIDRO');
  IF f is null then raise exception 'WA4A_BRANCH_FACT_MISSING'; end if;
  IF f ? 'horario_lv' or f ? 'horario_finde' then raise exception 'WA4A_CONFLICTING_GEO_HOURS_LEAK'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_items_v1 where domain='BRANCH' and subject_key=public.aos_wa4a_norm_v1('SAN ISIDRO') and retrieval_state='READY_WITH_WARNING' and freshness_state='UNKNOWN') then raise exception 'WA4A_BRANCH_FRESHNESS_WARNING_FAILED'; end if;
END $$;

DO $$
BEGIN
  IF (select count(*) from public.aos_wa4a_knowledge_issues_v1 where domain='HOURS' and subject_key like public.aos_wa4a_norm_v1('SAN ISIDRO')||':%' and retrieval_state='BLOCKED_CONFLICT') <> 2 then raise exception 'WA4A_CROSS_SOURCE_HOURS_CONFLICT_FAILED'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_items_v1 where domain='HOURS' and subject_key=public.aos_wa4a_norm_v1('MIRAFLORES TEST')||':1' and retrieval_state='READY') then raise exception 'WA4A_READY_HOURS_FAILED'; end if;
END $$;

DO $$
BEGIN
  IF not exists(select 1 from public.aos_wa4a_knowledge_search_v1('botox precio',12,array['CATALOG']) where knowledge_id='service:10000000-0000-4000-8000-000000000001' and (evidence_ref->>'relation')='public.aos_catalogo_servicios' and score>0) then raise exception 'WA4A_RETRIEVAL_GROUNDED_SERVICE_FAILED'; end if;
  IF exists(select 1 from public.aos_wa4a_knowledge_search_v1('laser conflict',12,array['CATALOG']) where subject_id in ('10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000004')) then raise exception 'WA4A_CONFLICT_RETURNED_TO_RETRIEVAL'; end if;
  IF exists(select 1 from public.aos_wa4a_knowledge_search_v1('san isidro',12,array['HOURS'])) then raise exception 'WA4A_CONFLICTING_HOURS_RETURNED'; end if;
  IF not exists(select 1 from public.aos_wa4a_knowledge_search_v1('miraflores',12,array['HOURS']) where domain='HOURS') then raise exception 'WA4A_READY_HOURS_RETRIEVAL_FAILED'; end if;
  IF exists(select 1 from public.aos_wa4a_knowledge_search_v1('promo expirada',12,array['PROMOTION'])) then raise exception 'WA4A_EXPIRED_PROMO_RETURNED'; end if;
END $$;

DO $$
BEGIN
  IF has_table_privilege('anon','public.aos_wa4a_knowledge_items_v1','SELECT') then raise exception 'WA4A_ANON_VIEW_ACCESS'; end if;
  IF has_table_privilege('authenticated','public.aos_wa4a_knowledge_items_v1','SELECT') then raise exception 'WA4A_AUTHENTICATED_VIEW_ACCESS'; end if;
  IF not has_table_privilege('service_role','public.aos_wa4a_knowledge_items_v1','SELECT') then raise exception 'WA4A_SERVICE_VIEW_ACCESS_MISSING'; end if;
  IF has_function_privilege('anon','public.aos_wa4a_knowledge_search_v1(text,integer,text[])','EXECUTE') then raise exception 'WA4A_ANON_RPC_ACCESS'; end if;
  IF has_function_privilege('authenticated','public.aos_wa4a_knowledge_search_v1(text,integer,text[])','EXECUTE') then raise exception 'WA4A_AUTHENTICATED_RPC_ACCESS'; end if;
  IF not has_function_privilege('service_role','public.aos_wa4a_knowledge_search_v1(text,integer,text[])','EXECUTE') then raise exception 'WA4A_SERVICE_RPC_ACCESS_MISSING'; end if;
END $$;

DO $$
BEGIN
  IF (select count(*) from public.aos_catalogo_servicios) <> 4 then raise exception 'WA4A_SOURCE_CATALOG_MUTATED'; end if;
  IF (select count(*) from public.aos_promociones) <> 2 then raise exception 'WA4A_SOURCE_PROMO_MUTATED'; end if;
  IF (select count(*) from public.aos_sedes_geo) <> 2 then raise exception 'WA4A_SOURCE_BRANCH_MUTATED'; end if;
  IF (select count(*) from public.aos_config_horarios) <> 3 then raise exception 'WA4A_SOURCE_HOURS_MUTATED'; end if;
  IF (select count(*) from public.aos_catalogo_categorias) <> 1 then raise exception 'WA4A_SOURCE_CATEGORY_MUTATED'; end if;
END $$;

select 'WA4A_KNOWLEDGE_FABRIC_PASS' as result;
