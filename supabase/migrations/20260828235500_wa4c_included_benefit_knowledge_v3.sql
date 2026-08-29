-- WA-4C readiness hardening — expose CURRENT per-SKU commercial facts without creating a new business master.
-- Source remains public.aos_catalogo_servicios.info_extendida for certified September 2026 catalog lineage.
-- v3 preserves v2 audience isolation and only augments CATALOG service facts with allowlisted CURRENT SKU data.
begin;

create or replace function public.aos_wa4a_knowledge_search_v3(
  p_query text,
  p_audience text default 'PUBLIC_CLIENT',
  p_limit integer default 12,
  p_domains text[] default null
)
returns table(
  knowledge_id text, domain text, subject_type text, subject_id text, title text,
  facts jsonb, authority_tier smallint, source_relation text, source_pk text,
  source_updated_at timestamptz, freshness_state text, conflict_state text,
  retrieval_state text, evidence_ref jsonb, score integer
)
language sql
stable
security definer
set search_path='public'
as $$
select
  b.knowledge_id,
  b.domain,
  b.subject_type,
  b.subject_id,
  b.title,
  b.facts
    || case when g.included_benefit is not null then jsonb_build_object(
         'included_benefit',g.included_benefit,
         'included_benefit_source','CATALOG_SEP2026_CURRENT_SKU'
       ) else '{}'::jsonb end
    || case when i.safe_identity <> '{}'::jsonb then jsonb_build_object(
         'catalog_identity',i.safe_identity,
         'catalog_identity_source','CATALOG_SEP2026_CURRENT_SKU'
       ) else '{}'::jsonb end as facts,
  b.authority_tier,
  b.source_relation,
  b.source_pk,
  b.source_updated_at,
  b.freshness_state,
  b.conflict_state,
  b.retrieval_state,
  b.evidence_ref
    || case when g.included_benefit is not null then jsonb_build_object(
         'included_benefit_path','info_extendida.catalog_sep2026.gift_raw'
       ) else '{}'::jsonb end
    || case when i.safe_identity <> '{}'::jsonb then jsonb_build_object(
         'catalog_identity_path','info_extendida.treatment_identity',
         'catalog_identity_verified_at',nullif(btrim(s.info_extendida #>> '{treatment_identity,verified_at}'),'')
       ) else '{}'::jsonb end as evidence_ref,
  b.score
from public.aos_wa4a_knowledge_search_v2(p_query,p_audience,p_limit,p_domains) b
left join public.aos_catalogo_servicios s
  on b.domain='CATALOG'
 and upper(coalesce(b.subject_type,'')) in ('SERVICIO','SERVICE')
 and b.subject_id=s.id::text
 and coalesce(s.estado,'ACTIVO')='ACTIVO'
left join lateral (
  select nullif(btrim(s.info_extendida #>> '{catalog_sep2026,gift_raw}'),'') as included_benefit
) g on true
left join lateral (
  select case
    when coalesce(s.info_extendida #>> '{treatment_identity,source}','')='SEP2026_PRICE_LIST'
     and coalesce(s.info_extendida #>> '{treatment_identity,current_status}','')='CURRENT'
     and lower(coalesce(s.info_extendida #>> '{treatment_identity,public_catalog}','false'))='true'
    then jsonb_strip_nulls(jsonb_build_object(
      'family_name',nullif(btrim(s.info_extendida #>> '{treatment_identity,family_name}'),''),
      'commercial_variant',nullif(btrim(s.info_extendida #>> '{treatment_identity,commercial_variant}'),''),
      'clinical_sessions',case when coalesce(s.info_extendida #>> '{treatment_identity,clinical_sessions}','') ~ '^[0-9]+([.][0-9]+)?$' then (s.info_extendida #>> '{treatment_identity,clinical_sessions}')::numeric end,
      'brand',nullif(btrim(s.info_extendida #>> '{treatment_identity,brand}'),''),
      'zones',case when coalesce(s.info_extendida #>> '{treatment_identity,zones}','') ~ '^[0-9]+([.][0-9]+)?$' then (s.info_extendida #>> '{treatment_identity,zones}')::numeric end,
      'unit_cap',case when coalesce(s.info_extendida #>> '{treatment_identity,unit_cap}','') ~ '^[0-9]+([.][0-9]+)?$' then (s.info_extendida #>> '{treatment_identity,unit_cap}')::numeric end,
      'syringes',case when coalesce(s.info_extendida #>> '{treatment_identity,syringes}','') ~ '^[0-9]+([.][0-9]+)?$' then (s.info_extendida #>> '{treatment_identity,syringes}')::numeric end,
      'volume_ml',case when coalesce(s.info_extendida #>> '{treatment_identity,volume_ml}','') ~ '^[0-9]+([.][0-9]+)?$' then (s.info_extendida #>> '{treatment_identity,volume_ml}')::numeric end
    ))
    else '{}'::jsonb
  end as safe_identity
) i on true
order by b.score desc,b.authority_tier asc,b.title;
$$;

revoke all on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) to service_role;

comment on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) is
'WA-4C governed search: preserves v2 audience isolation and surfaces only allowlisted CURRENT per-SKU September 2026 catalog facts; no promotion inference and no clinical claim expansion.';

commit;
