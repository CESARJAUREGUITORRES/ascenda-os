-- WA-4A.1B explicit exception mapping: do not force non-aesthetic/operational rows into branded approaches.
begin;

insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('CROSS_DOMAIN_FUNCTIONAL','APPROACH','ZV_SYSTEM','Atención funcional fuera de enfoques estéticos','["Funcional"]',
 'Algunos servicios responden a una necesidad funcional y no forman parte de los enfoques estéticos principales.',
 'Explícalos por su objetivo funcional y deriva la indicación al profesional; no los fuerces dentro de Skin, Harmony o Sculpt.',
 'Clasificación explícita para mantener completa la ontología sin convertir una excepción clínica en un enfoque comercial de marca.',
 'La evaluación, indicación, dosis y técnica permanecen bajo autoridad clínica.',
 '{"cross_domain":true,"branded_approach":false,"exception_class":"FUNCTIONAL_CLINICAL"}',
 array['funcional','hiperhidrosis','excepcion'],'HIGH','ZV_COMMERCIAL_ARCH_2026','Derived governance rule: domain is framework, not package; explicit exception to avoid false mapping','APPROVED',now()),
('CROSS_DOMAIN_OPERATIONAL','APPROACH','ZV_SYSTEM','Soporte operativo no comercial','["Insumo operativo"]',
 null,
 'Esta fila existe en catálogo por operación/facturación, pero no debe explicarse al paciente como enfoque, tratamiento independiente o recomendación de IA.',
 'Clasificación para consumibles/cargos operativos mal ubicados como SERVICIO. Mantener visible para auditoría y evitar contaminar recomendaciones.',
 null,
 '{"cross_domain":true,"branded_approach":false,"exception_class":"OPERATIONAL","recommendable":false}',
 array['operativo','insumo','canula'],'LOW','ZV_COMMERCIAL_ARCH_2026','Governance exception derived from current canonical catalog + commercial architecture','APPROVED',now())
on conflict(code) do update set
 title=excluded.title,aliases=excluded.aliases,public_client=excluded.public_client,
 advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,
 clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,
 keywords=excluded.keywords,risk_level=excluded.risk_level,source_locator=excluded.source_locator,
 status='APPROVED',approved_at=now(),updated_at=now();

-- Hiperhidrosis: functional clinical service, not a branded aesthetic approach.
update public.aos_knowledge_entity_map_v1
set domain_codes=array['CORPORAL'],
    approach_codes=array['CROSS_DOMAIN_FUNCTIONAL'],
    commercial_phase_codes=array['COMMERCIAL_F2_INTERVENTION'],
    clinical_lifecycle=array['ACTIVATE'],
    zi_function='ATENCION_FUNCIONAL_HIPERHIDROSIS',
    mapping_state='MAPPED_NA_EXPLICIT',
    mapping_confidence=0.950,
    advisor_positioning='Servicio funcional: explicar el objetivo y derivar la indicación/técnica al profesional. No presentarlo como Sculpt Body ni como enfoque estético de marca.',
    source_locator='WA-4A.1B explicit functional exception · canonical TOXINA/HIPERHIDROSIS',
    updated_at=now()
where entity_type='SERVICE' and upper(entity_name) like 'HIPERHIDROSIS%';

-- Cannulas: current canonical catalog rows are operational consumables/charges, not patient-facing services.
update public.aos_knowledge_entity_map_v1
set domain_codes=array['FACIAL','CORPORAL','CAPILAR'],
    approach_codes=array['CROSS_DOMAIN_OPERATIONAL'],
    commercial_phase_codes=array['PRE_PHASE_EVALUATION'],
    clinical_lifecycle=array['PREPARE'],
    zi_function='SOPORTE_OPERATIVO_INSUMO',
    public_positioning=null,
    advisor_positioning='Fila operativa/insumo. No recomendar ni explicar como tratamiento o enfoque al cliente.',
    mapping_state='MAPPED_NA_EXPLICIT',
    mapping_confidence=1.000,
    composition_state='NOT_APPLICABLE_OPERATIONAL',
    source_locator='WA-4A.1B explicit operational exception · canonical CONSULTA/cannula rows',
    updated_at=now()
where entity_type='SERVICE' and upper(entity_name) like 'CÁNULAS %';

-- Peptonas: current service content describes bio-stimulation/regenerative support; keep review confidence but place in closest governed approach.
update public.aos_knowledge_entity_map_v1
set domain_codes=array['FACIAL'],
    approach_codes=array['FACIAL_BIOREGEN_FACE'],
    commercial_phase_codes=array['COMMERCIAL_F2_INTERVENTION'],
    clinical_lifecycle=array['REGENERATE'],
    zi_function='SOPORTE_BIOREGENERATIVO',
    mapping_state='MAPPED',
    mapping_confidence=0.800,
    advisor_positioning='Se ubica como soporte bioregenerativo facial según el contenido clínico actual del catálogo; la composición exacta sigue pendiente de fuente específica.',
    source_locator='WA-4A.1B mapped from current PEPTONAS service content + BioRegen semantics',
    updated_at=now()
where entity_type='SERVICE' and category='PEPTONAS';

-- Refresh approach relations for the updated exceptions.
delete from public.aos_knowledge_relations_v1
where source_locator like 'WA-4A.1B explicit exception%';

insert into public.aos_knowledge_relations_v1
(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select a, 'RELATED_SERVICE','SERVICE',m.entity_name,m.entity_id,
       case when a='CROSS_DOMAIN_OPERATIONAL' then 'INTERNAL' else 'REFERENCE' end,
       'WA-4A.1B explicit exception mapping'
from public.aos_knowledge_entity_map_v1 m
cross join lateral unnest(m.approach_codes) a
where m.entity_type='SERVICE'
  and (upper(m.entity_name) like 'HIPERHIDROSIS%' or upper(m.entity_name) like 'CÁNULAS %' or m.category='PEPTONAS')
on conflict(knowledge_code,relation_type,target_type,target_key) do update set
 target_id=excluded.target_id,relation_scope=excluded.relation_scope,source_locator=excluded.source_locator;

commit;
