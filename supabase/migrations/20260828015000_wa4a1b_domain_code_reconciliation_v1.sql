-- WA-4A.1B: reconcile human domain labels to the canonical WA-4A.1 knowledge node codes.
begin;

update public.aos_knowledge_entity_map_v1 m
set domain_codes = (
  select array_agg(case x
    when 'FACIAL' then 'DOMAIN_FACIAL'
    when 'CORPORAL' then 'DOMAIN_CORPORAL'
    when 'CAPILAR' then 'DOMAIN_CAPILAR'
    else x end order by ord)
  from unnest(m.domain_codes) with ordinality as u(x,ord)
), updated_at=now()
where m.domain_codes && array['FACIAL','CORPORAL','CAPILAR'];

commit;
