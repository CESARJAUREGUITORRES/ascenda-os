\set ON_ERROR_STOP on

DO $$
BEGIN
  IF (select count(*) from public.aos_zi_knowledge_sources_v1) <> 2 then raise exception 'WA4A1_SOURCE_COUNT'; end if;
  IF (select count(*) from public.aos_zi_knowledge_entities_v1) <> 26 then raise exception 'WA4A1_ENTITY_COUNT'; end if;
  IF (select count(*) from public.aos_wa4a1_zi_knowledge_items_v1) <> 130 then raise exception 'WA4A1_AUDIENCE_PROJECTION_COUNT'; end if;
  IF exists(
    select 1 from (values ('PUBLIC_CLIENT'),('ADVISOR_INTERNAL'),('OWNER_ADMIN'),('CLINICAL_RESTRICTED'),('SYSTEM_REFERENCE')) a(audience)
    where (select count(*) from public.aos_wa4a1_zi_knowledge_items_v1 i where i.facts->>'audience'=a.audience) <> 26
  ) then raise exception 'WA4A1_AUDIENCE_BALANCE'; end if;
END $$;

DO $$
BEGIN
  IF (select sha256 from public.aos_zi_knowledge_sources_v1 where source_key='ZI_DOMAINS_20260827') <> 'cbb2a3cf2ff0458203004d41522595d5322c30dc1d084eb4e9c4f591b81ad901' then raise exception 'WA4A1_DOMAINS_HASH'; end if;
  IF (select page_count from public.aos_zi_knowledge_sources_v1 where source_key='ZI_DOMAINS_20260827') <> 14 then raise exception 'WA4A1_DOMAINS_PAGES'; end if;
  IF (select sha256 from public.aos_zi_knowledge_sources_v1 where source_key='ZI_ATTENTION_20260827') <> 'ac9a61cfd19368a308f78e900b37108c24021ee419fe578cc7635f1000af3254' then raise exception 'WA4A1_ATTENTION_HASH'; end if;
  IF (select page_count from public.aos_zi_knowledge_sources_v1 where source_key='ZI_ATTENTION_20260827') <> 8 then raise exception 'WA4A1_ATTENTION_PAGES'; end if;
END $$;

DO $$
BEGIN
  IF not ((select aliases from public.aos_zi_knowledge_entities_v1 where entity_key='APP_SCULPT_BODY') @> array['Contour Sculpt']::text[]) then raise exception 'WA4A1_ALIAS_CONTOUR_SCULPT'; end if;
  IF not ((select aliases from public.aos_zi_knowledge_entities_v1 where entity_key='APP_SCULPT_BOOTY') @> array['Volume & Firm']::text[]) then raise exception 'WA4A1_ALIAS_VOLUME_FIRM'; end if;
  IF not ((select aliases from public.aos_zi_knowledge_entities_v1 where entity_key='APP_HAIR_REVIVAL') @> array['Hair Revival']::text[]) then raise exception 'WA4A1_ALIAS_HAIR_REVIVAL'; end if;
  IF not ((select aliases from public.aos_zi_knowledge_entities_v1 where entity_key='APP_HAIR_GUARD') @> array['Hair Guard']::text[]) then raise exception 'WA4A1_ALIAS_HAIR_GUARD'; end if;
END $$;

DO $$
BEGIN
  IF jsonb_array_length((select system_reference->'triage_questions' from public.aos_zi_knowledge_entities_v1 where entity_key='CARE_F2')) <> 10 then raise exception 'WA4A1_TRIAGE_QUESTION_COUNT'; end if;
  IF jsonb_array_length((select system_reference->'subphases' from public.aos_zi_knowledge_entities_v1 where entity_key='CARE_F6')) <> 4 then raise exception 'WA4A1_F6_SUBPHASE_COUNT'; end if;
END $$;

DO $$
DECLARE f jsonb;
BEGIN
  select facts into f from public.aos_wa4a1_zi_knowledge_items_v1
  where subject_id='APP_SKIN_SIGNATURE' and facts->>'audience'='PUBLIC_CLIENT';
  IF f is null then raise exception 'WA4A1_PUBLIC_SKIN_SIGNATURE_MISSING'; end if;
  IF f->>'audience' <> 'PUBLIC_CLIENT' then raise exception 'WA4A1_PUBLIC_AUDIENCE_MISMATCH'; end if;
  IF f->'payload' <> '{}'::jsonb then raise exception 'WA4A1_PUBLIC_SYSTEM_REFERENCE_LEAK'; end if;
  IF f->>'content' ilike '%dutasteride%' then raise exception 'WA4A1_PUBLIC_CLINICAL_LEAK'; end if;
END $$;

DO $$
BEGIN
  IF not exists(
    select 1 from public.aos_wa4a1_zi_knowledge_search_v1('pink glow','PUBLIC_CLIENT',12)
    where subject_id='APP_SKIN_SIGNATURE' and facts->>'audience'='PUBLIC_CLIENT'
  ) then raise exception 'WA4A1_PINK_GLOW_TO_SKIN_SIGNATURE_FAILED'; end if;
  IF exists(
    select 1 from public.aos_wa4a1_zi_knowledge_search_v1('pink glow','PUBLIC_CLIENT',24)
    where facts->>'audience'<>'PUBLIC_CLIENT'
  ) then raise exception 'WA4A1_PUBLIC_CROSS_AUDIENCE_LEAK'; end if;
  IF not exists(
    select 1 from public.aos_wa4a1_zi_knowledge_search_v1('pink glow','ADVISOR_INTERNAL',12)
    where subject_id='APP_SKIN_SIGNATURE' and facts->>'audience'='ADVISOR_INTERNAL'
  ) then raise exception 'WA4A1_ADVISOR_RETRIEVAL_FAILED'; end if;
  IF not exists(
    select 1 from public.aos_wa4a1_zi_knowledge_search_v1('dutasteride','CLINICAL_RESTRICTED',12)
    where subject_id='APP_HAIR_REVIVAL'
      and facts->>'audience'='CLINICAL_RESTRICTED'
      and (facts->>'answerable')::boolean=false
      and (facts->>'requires_human')::boolean=true
      and facts->>'risk_level'='HIGH'
  ) then raise exception 'WA4A1_CLINICAL_HUMAN_ONLY_FAILED'; end if;
  IF exists(select 1 from public.aos_wa4a1_zi_knowledge_search_v1('dutasteride','PUBLIC_CLIENT',24) where facts->>'audience'<>'PUBLIC_CLIENT') then raise exception 'WA4A1_PUBLIC_RESTRICTED_AUDIENCE_LEAK'; end if;
END $$;

DO $$
BEGIN
  IF has_table_privilege('anon','public.aos_zi_knowledge_entities_v1','SELECT') then raise exception 'WA4A1_ANON_ENTITY_ACCESS'; end if;
  IF has_table_privilege('authenticated','public.aos_zi_knowledge_entities_v1','SELECT') then raise exception 'WA4A1_AUTH_ENTITY_ACCESS'; end if;
  IF not has_table_privilege('service_role','public.aos_zi_knowledge_entities_v1','SELECT') then raise exception 'WA4A1_SERVICE_ENTITY_ACCESS_MISSING'; end if;
  IF has_table_privilege('anon','public.aos_wa4a1_zi_knowledge_items_v1','SELECT') then raise exception 'WA4A1_ANON_VIEW_ACCESS'; end if;
  IF has_function_privilege('anon','public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer)','EXECUTE') then raise exception 'WA4A1_ANON_RPC_ACCESS'; end if;
  IF has_function_privilege('authenticated','public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer)','EXECUTE') then raise exception 'WA4A1_AUTH_RPC_ACCESS'; end if;
  IF not has_function_privilege('service_role','public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer)','EXECUTE') then raise exception 'WA4A1_SERVICE_RPC_ACCESS_MISSING'; end if;
END $$;

DO $$
BEGIN
  IF (select count(*) from public.aos_catalogo_servicios) <> 4 then raise exception 'WA4A1_CANONICAL_CATALOG_MUTATED'; end if;
  IF (select count(*) from public.aos_promociones) <> 2 then raise exception 'WA4A1_CANONICAL_PROMO_MUTATED'; end if;
  IF (select count(*) from public.aos_sedes_geo) <> 2 then raise exception 'WA4A1_CANONICAL_BRANCH_MUTATED'; end if;
END $$;

select 'WA4A1_ZI_VITAL_GOVERNED_KNOWLEDGE_PASS' as result;
