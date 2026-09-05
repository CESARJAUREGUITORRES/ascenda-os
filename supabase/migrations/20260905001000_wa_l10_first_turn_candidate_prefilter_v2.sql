-- WA-L10 first-turn remediation v2 — cheap candidate prefilter before exact normalization.
-- PROD evidence after v1 showed the exact real first-turn phrase can still exceed the 3 s boundary
-- because v1 normalizes every eligible multi-kilobyte knowledge search_text once per request.
-- v2 preserves the final v1 ranking/authority calculation, but first folds the source text with a
-- cheap accent/case transform, narrows to plausible candidates, and performs the expensive canonical
-- regexp normalization only on that candidate set.
-- No statement_timeout change, sender/authority mutation, allowlist mutation, polling, or CANARY activation.

begin;

create or replace function public.aos_wa4a_knowledge_search_v1(
  p_query text,
  p_limit integer default 12,
  p_domains text[] default null
)
returns table(
  knowledge_id text,
  domain text,
  subject_type text,
  subject_id text,
  title text,
  facts jsonb,
  authority_tier smallint,
  source_relation text,
  source_pk text,
  source_updated_at timestamptz,
  freshness_state text,
  conflict_state text,
  retrieval_state text,
  evidence_ref jsonb,
  score integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_q text := public.aos_wa4a_norm_v1(p_query);
  v_limit integer := greatest(1,least(coalesce(p_limit,12),24));
  v_tokens text[];
begin
  if length(v_q)<2 then return; end if;

  select coalesce(array_agg(distinct w),array[]::text[])
    into v_tokens
  from unnest(string_to_array(v_q,' ')) w
  where length(w)>=3;

  return query
  with folded as materialized (
    select
      k.knowledge_id,k.domain,k.subject_type,k.subject_id,k.title,k.search_text,k.facts,k.authority_tier,
      k.source_relation,k.source_pk,k.source_updated_at,k.freshness_state,k.conflict_state,
      k.retrieval_state,k.evidence_ref,
      public.aos_wa4a_norm_v1(k.title) as norm_title,
      lower(translate(coalesce(k.search_text,''),'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) as fold_search
    from public.aos_wa4a_knowledge_items_v1 k
    where k.retrieval_state in ('READY','READY_WITH_WARNING')
      and k.conflict_state='CLEAR'
      and (p_domains is null or cardinality(p_domains)=0 or k.domain=any(p_domains))
  ), candidates as materialized (
    select f.*
    from folded f
    where f.norm_title like '%'||v_q||'%'
       or f.fold_search like '%'||v_q||'%'
       or exists(select 1 from unnest(v_tokens) w where f.fold_search like '%'||w||'%')
  ), prepared as materialized (
    select
      c.knowledge_id,c.domain,c.subject_type,c.subject_id,c.title,c.facts,c.authority_tier,
      c.source_relation,c.source_pk,c.source_updated_at,c.freshness_state,c.conflict_state,
      c.retrieval_state,c.evidence_ref,c.norm_title,
      public.aos_wa4a_norm_v1(c.search_text) as norm_search
    from candidates c
  ), ranked as (
    select
      p.*,
      (
        case when p.norm_title=v_q then 100 else 0 end
        + case when p.norm_title like '%'||v_q||'%' then 45 else 0 end
        + case when p.norm_search like '%'||v_q||'%' then 25 else 0 end
        + coalesce((select count(*)::integer*6 from unnest(v_tokens) w where p.norm_search like '%'||w||'%'),0)
        + case when p.authority_tier=10 then 5 else 0 end
      )::integer as rank_score
    from prepared p
    where p.norm_title like '%'||v_q||'%'
       or p.norm_search like '%'||v_q||'%'
       or exists(select 1 from unnest(v_tokens) w where p.norm_search like '%'||w||'%')
  )
  select
    r.knowledge_id,r.domain,r.subject_type,r.subject_id,r.title,r.facts,r.authority_tier,
    r.source_relation,r.source_pk,r.source_updated_at,r.freshness_state,r.conflict_state,
    r.retrieval_state,r.evidence_ref,r.rank_score
  from ranked r
  order by r.rank_score desc,r.authority_tier asc,r.title asc
  limit v_limit;
end
$$;

revoke all on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) to service_role;

comment on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) is
'WA4A governed search hot-path v2: cheap accent/case folded candidate prefilter first; canonical regex normalization and original ranking are applied only to candidates. No timeout inflation.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
