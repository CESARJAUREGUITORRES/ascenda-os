-- WA-4A.1B feature rollback. Does NOT undo the separately governed Vitaminas/Detox business-content DML patch.
begin;

drop view if exists public.aos_knowledge_entity_map_issues_v1;
drop function if exists public.aos_wa4a_entity_context_v1(uuid,text);
drop table if exists public.aos_knowledge_entity_map_v1;

delete from public.aos_knowledge_relations_v1
where source_locator like 'WA-4A.1B%';

delete from public.aos_knowledge_nodes_v1 where code in (
  'TAX_COMMERCIAL_PHASES','COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F2_INTERVENTION','COMMERCIAL_F3_CONTINUITY',
  'TAX_CLINICAL_LIFECYCLE','PRE_PHASE_EVALUATION','CROSS_DOMAIN_SUPPORT','CROSS_DOMAIN_EVALUATION',
  'CROSS_DOMAIN_FUNCTIONAL','CROSS_DOMAIN_OPERATIONAL',
  'PRINCIPLE_PROCESS_NOT_PROCEDURE','PRINCIPLE_NO_DISCOUNT','PRINCIPLE_STRUCTURED_PERSONALIZATION',
  'PRINCIPLE_CLINICAL_COHERENCE','PRINCIPLE_LONG_TERM','PRINCIPLE_TRANSPARENCY_WITHOUT_FRAGMENTATION',
  'GLOSSARY_PUBLIC_PROCESS_LANGUAGE','GLOSSARY_INTERNAL_ONLY',
  'RULE_MEDICAL_PLAN_TO_COMMERCIAL','RULE_QUOTE_PROCESS','RULE_RECALCULATE_PROCESS','RULE_PAYMENT_SCENARIOS',
  'RULE_TOPPINGS_BENEFITS','RULE_ETHICAL_UPSELL','RULE_PRODUCTS_AS_EXTENSION','POLICY_REFUND_ALIGNMENT',
  'KPI_EXPERIENCE_TRUST','KPI_COMMERCIAL_COHERENCE','KPI_FINANCIAL_HEALTH','KPI_PATIENT_CONTINUITY',
  'OKR_PREMIUM_COHERENCE','OKR_PATIENT_COMMITMENT','OKR_COMMERCIAL_HEALTH'
);

delete from public.aos_knowledge_sources_v1 where source_code='ZV_COMMERCIAL_ARCH_2026';

update public.aos_knowledge_nodes_v1
set aliases='["Calidad Cutánea · Salud · Glow Consciente"]'::jsonb,updated_at=now()
where code='FACIAL_SKIN_SIGNATURE';
update public.aos_knowledge_nodes_v1
set aliases='["Equilibrio Estructural · Expresión · Soporte"]'::jsonb,updated_at=now()
where code='FACIAL_HARMONY_DESIGN';
update public.aos_knowledge_nodes_v1
set aliases='["Regeneración · Longevidad · Sostén Biológico"]'::jsonb,updated_at=now()
where code='FACIAL_BIOREGEN_FACE';

alter table public.aos_knowledge_nodes_v1 drop constraint if exists aos_knowledge_nodes_v1_node_type_check;
alter table public.aos_knowledge_nodes_v1
  add constraint aos_knowledge_nodes_v1_node_type_check
  check (node_type in ('SYSTEM','DOMAIN','APPROACH','PATIENT_JOURNEY','PHASE','ROLE'));

commit;
