-- WA-4C readiness hardening — expose CURRENT per-SKU included benefits without creating a new commercial master.
-- Source remains public.aos_catalogo_servicios.info_extendida.catalog_sep2026.gift_raw.
-- v3 preserves v2 audience isolation and only augments CATALOG service facts.
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
  case
    when b.domain='CATALOG'
      and upper(coalesce(b.subject_type,'')) in ('SERVICIO','SERVICE')
      and nullif(btrim(s.info_extendida #>> '{catalog_sep2026,gift_raw}'),'') is not null
    then b.facts || jsonb_build_object(
      'included_benefit', nullif(btrim(s.info_extendida #>> '{catalog_sep2026,gift_raw}'),''),
      'included_benefit_source', 'CATALOG_SEP2026_CURRENT_SKU'
    )
    else b.facts
  end as facts,
  b.authority_tier,
  b.source_relation,
  b.source_pk,
  b.source_updated_at,
  b.freshness_state,
  b.conflict_state,
  b.retrieval_state,
  case
    when b.domain='CATALOG'
      and upper(coalesce(b.subject_type,'')) in ('SERVICIO','SERVICE')
      and nullif(btrim(s.info_extendida #>> '{catalog_sep2026,gift_raw}'),'') is not null
    then b.evidence_ref || jsonb_build_object(
      'included_benefit_path','info_extendida.catalog_sep2026.gift_raw'
    )
    else b.evidence_ref
  end as evidence_ref,
  b.score
from public.aos_wa4a_knowledge_search_v2(p_query,p_audience,p_limit,p_domains) b
left join public.aos_catalogo_servicios s
  on b.domain='CATALOG'
 and b.subject_id=s.id::text
order by b.score desc,b.authority_tier asc,b.title;
$$;

revoke all on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) to service_role;

comment on function public.aos_wa4a_knowledge_search_v3(text,text,integer,text[]) is
'WA-4C governed search: preserves v2 audience isolation and surfaces only canonical CURRENT per-SKU included benefits from catalog lineage; no promotion inference.';

commit;
