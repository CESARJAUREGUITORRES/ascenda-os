-- WA-4A.1B hardening: explicit pre-phase evaluation node and mapping integrity semantics.
begin;

insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('PRE_PHASE_EVALUATION','PHASE','ZV_SYSTEM','Pre-fase — Evaluación y priorización','["Evaluación previa","Consulta"]',
 'Antes de definir un proceso, la evaluación ayuda a ordenar prioridades y decidir qué corresponde trabajar.',
 'No fuerces una consulta dentro de Fase 1/2/3: es una pre-fase que define dominio, objetivo y prioridades antes de cotizar.',
 'Representa el punto previo a las fases comerciales. Su salida esperada es un plan clínico estructurado, no una venta.',
 'Diagnóstico, indicación, dosis y selección terapéutica pertenecen al profesional clínico autorizado.',
 '{"kind":"PRE_COMMERCIAL_PHASE","before":["COMMERCIAL_F1_PREP_ACT","COMMERCIAL_F2_INTERVENTION","COMMERCIAL_F3_CONTINUITY"]}',
 array['evaluacion','consulta','pre fase','priorizacion'],'HIGH','ZV_PATIENT_PROCESS_2026','Proceso Atención Zi Vital; evaluación/consulta antes de aterrizaje comercial','APPROVED',now())
on conflict(code) do update set
 title=excluded.title,aliases=excluded.aliases,public_client=excluded.public_client,
 advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,
 clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,
 keywords=excluded.keywords,risk_level=excluded.risk_level,source_code=excluded.source_code,
 source_locator=excluded.source_locator,status='APPROVED',approved_at=now(),updated_at=now();

-- Every non-sentinel mapping code must resolve to a governed node.
-- Kept as a view so CI/admin can audit future catalog drift without mutating catalog data.
create or replace view public.aos_knowledge_entity_map_issues_v1 as
with expanded as (
  select entity_type,entity_id,entity_name,'DOMAIN'::text as code_kind,x as code
  from public.aos_knowledge_entity_map_v1 cross join lateral unnest(domain_codes) x
  union all
  select entity_type,entity_id,entity_name,'APPROACH',x
  from public.aos_knowledge_entity_map_v1 cross join lateral unnest(approach_codes) x
  where x <> 'NOT_APPLICABLE_FUNCTIONAL'
  union all
  select entity_type,entity_id,entity_name,'COMMERCIAL_PHASE',x
  from public.aos_knowledge_entity_map_v1 cross join lateral unnest(commercial_phase_codes) x
)
select e.entity_type,e.entity_id,e.entity_name,e.code_kind,e.code,
       'UNRESOLVED_KNOWLEDGE_CODE'::text as issue_code
from expanded e
left join public.aos_knowledge_nodes_v1 n on n.code=e.code and n.status='APPROVED'
where n.code is null;

revoke all on table public.aos_knowledge_entity_map_issues_v1 from public,anon,authenticated;
grant select on table public.aos_knowledge_entity_map_issues_v1 to service_role;

commit;
