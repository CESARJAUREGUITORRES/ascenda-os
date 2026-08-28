\set ON_ERROR_STOP on

-- Source and ontology.
do $$ begin
  if not exists(select 1 from public.aos_knowledge_sources_v1 where source_code='ZV_COMMERCIAL_ARCH_2026' and authority_state='AUTHORITATIVE_INTERNAL') then
    raise exception 'third Zi Vital master source missing';
  end if;
  if (select count(*) from public.aos_knowledge_nodes_v1 where node_type='PRINCIPLE' and source_code='ZV_COMMERCIAL_ARCH_2026') <> 6 then
    raise exception 'expected six commercial principles';
  end if;
  if (select count(*) from public.aos_knowledge_nodes_v1 where node_type='KPI' and source_code='ZV_COMMERCIAL_ARCH_2026') <> 4 then
    raise exception 'expected four KPI layers';
  end if;
  if (select count(*) from public.aos_knowledge_nodes_v1 where node_type='OKR' and source_code='ZV_COMMERCIAL_ARCH_2026') <> 3 then
    raise exception 'expected three OKRs';
  end if;
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='FACIAL_SKIN_SIGNATURE' and aliases ? 'Skin Quality') then
    raise exception 'Skin Quality alias missing';
  end if;
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='FACIAL_HARMONY_DESIGN' and aliases ? 'Harmony Face') then
    raise exception 'Harmony Face alias missing';
  end if;
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='FACIAL_BIOREGEN_FACE' and aliases ? 'Bioregeneración') then
    raise exception 'Bioregeneracion alias missing';
  end if;
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='TAX_COMMERCIAL_PHASES') or
     not exists(select 1 from public.aos_knowledge_nodes_v1 where code='TAX_CLINICAL_LIFECYCLE') then
    raise exception 'phase taxonomy normalization missing';
  end if;
end $$;

-- Exact CURRENT-shape coverage in isolated TEST: 167 active services + 50 products.
do $$ begin
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE') <> 167 then
    raise exception 'service graph must cover 167/167';
  end if;
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='PRODUCT') <> 50 then
    raise exception 'product graph must cover 50/50';
  end if;
  if exists(select 1 from public.aos_knowledge_entity_map_v1 where cardinality(domain_codes)=0 or cardinality(approach_codes)=0 or cardinality(commercial_phase_codes)=0 or cardinality(clinical_lifecycle)=0 or nullif(btrim(zi_function),'') is null) then
    raise exception 'blank graph dimensions detected';
  end if;
  if exists(select 1 from public.aos_knowledge_entity_map_issues_v1) then
    raise exception 'unresolved graph code detected';
  end if;
end $$;

-- Composition debt classification: exactly the 43 service gaps are split into 17 N/A + 26 real missing.
do $$ begin
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and composition_state in ('NOT_APPLICABLE_TECHNOLOGY','NOT_APPLICABLE_OPERATIONAL')) <> 17 then
    raise exception 'expected 17 service composition N/A rows';
  end if;
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and composition_state='REAL_MISSING_REVIEW') <> 26 then
    raise exception 'expected 26 real-missing service compositions';
  end if;
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and category='VITAMINAS' and composition_state='CATEGORY_TEMPLATE_REVIEW') <> 39 then
    raise exception 'all 39 Vitaminas formulas must be marked category-template review';
  end if;
  if not exists(select 1 from public.aos_knowledge_entity_map_v1 where entity_type='PRODUCT' and entity_name='APLICADOR MULTIZONA CAPILAR' and composition_state='NOT_APPLICABLE_OPERATIONAL') then
    raise exception 'physical applicator must be N/A, not missing clinical formula';
  end if;
end $$;

-- Explicit exception semantics.
do $$ begin
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and entity_name like 'HIPERHIDROSIS%' and approach_codes=array['CROSS_DOMAIN_FUNCTIONAL']) <> 2 then
    raise exception 'hyperhidrosis functional classification missing';
  end if;
  if (select count(*) from public.aos_knowledge_entity_map_v1 where entity_type='SERVICE' and entity_name like 'CÁNULAS %' and approach_codes=array['CROSS_DOMAIN_OPERATIONAL']) <> 2 then
    raise exception 'operational cannula classification missing';
  end if;
  if exists(select 1 from public.aos_knowledge_relations_v1 r join public.aos_knowledge_entity_map_v1 m on m.entity_id=r.target_id where m.entity_name like 'CÁNULAS %' and r.knowledge_code<>'CROSS_DOMAIN_OPERATIONAL') then
    raise exception 'cannula leaked into a clinical/commercial approach';
  end if;
end $$;

-- Product continuity + examples from the actual commercial taxonomy.
do $$ begin
  if exists(select 1 from public.aos_knowledge_entity_map_v1 where entity_type='PRODUCT' and not (commercial_phase_codes @> array['COMMERCIAL_F3_CONTINUITY'])) then
    raise exception 'every product must participate in continuity phase';
  end if;
  if not exists(select 1 from public.aos_knowledge_entity_map_v1 where entity_name='BEAUTY MAKER 330G' and approach_codes @> array['FACIAL_BIOREGEN_FACE','CAPILAR_MANTENIMIENTO_PREVENCION']) then
    raise exception 'Beauty Maker multi-approach mapping missing';
  end if;
  if not exists(select 1 from public.aos_knowledge_entity_map_v1 where entity_name='REDUFAST' and domain_codes=array['CORPORAL']) then
    raise exception 'Redufast corporal mapping missing';
  end if;
end $$;

-- Commercial source must never become price authority.
do $$ begin
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='RULE_QUOTE_PROCESS' and system_reference->>'price_authority'='aos_catalogo_servicios' and (system_reference->>'example_prices_are_authority')::boolean=false) then
    raise exception 'runtime catalog price authority contract missing';
  end if;
  if not exists(select 1 from public.aos_knowledge_nodes_v1 where code='POLICY_REFUND_ALIGNMENT' and (system_reference->>'public_authority')::boolean=false and (system_reference->>'requires_legal_alignment')::boolean=true) then
    raise exception 'refund policy must remain non-public until legal alignment';
  end if;
end $$;

-- Entity context is service-role only.
do $$ begin
  if has_function_privilege('anon','public.aos_wa4a_entity_context_v1(uuid,text)','EXECUTE') or
     has_function_privilege('authenticated','public.aos_wa4a_entity_context_v1(uuid,text)','EXECUTE') then
    raise exception 'entity context RPC leaked to end-user roles';
  end if;
  if not has_function_privilege('service_role','public.aos_wa4a_entity_context_v1(uuid,text)','EXECUTE') then
    raise exception 'service_role missing entity context RPC';
  end if;
end $$;

select 'WA4A1B_ZIVITAL_COMMERCIAL_GRAPH_PASS' as certification;
