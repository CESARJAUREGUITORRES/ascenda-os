-- Reconcile stale generic relations after explicit exception reclassification.
begin;

delete from public.aos_knowledge_relations_v1 r
using public.aos_knowledge_entity_map_v1 m
where r.target_id=m.entity_id
  and r.target_type=m.entity_type
  and r.source_locator like 'WA-4A.1B entity map%'
  and (
    upper(m.entity_name) like 'CÁNULAS %'
    or upper(m.entity_name) like 'HIPERHIDROSIS%'
    or m.category='PEPTONAS'
  );

insert into public.aos_knowledge_relations_v1
(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select a,
       case when m.entity_type='PRODUCT' then 'RELATED_PRODUCT' else 'RELATED_SERVICE' end,
       m.entity_type,m.entity_name,m.entity_id,
       case when a='CROSS_DOMAIN_OPERATIONAL' then 'INTERNAL' else 'REFERENCE' end,
       'WA-4A.1B reconciled entity relation'
from public.aos_knowledge_entity_map_v1 m
cross join lateral unnest(m.approach_codes) a
join public.aos_knowledge_nodes_v1 n on n.code=a and n.status='APPROVED'
where upper(m.entity_name) like 'CÁNULAS %'
   or upper(m.entity_name) like 'HIPERHIDROSIS%'
   or m.category='PEPTONAS'
on conflict(knowledge_code,relation_type,target_type,target_key) do update set
 target_id=excluded.target_id,relation_scope=excluded.relation_scope,source_locator=excluded.source_locator;

commit;
