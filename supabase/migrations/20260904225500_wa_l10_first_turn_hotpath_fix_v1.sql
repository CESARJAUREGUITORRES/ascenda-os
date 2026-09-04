-- WA-L10 first-turn remediation — bounded governed knowledge search + complete fail-closed audit vocabulary.
-- Root cause observed in PROD 2026-09-04: v1 repeatedly normalized the same derived search text
-- inside phrase + per-token predicates, causing concurrent WA4 governed-knowledge calls to hit statement_timeout.
-- This patch preserves ranking/authority semantics and computes normalization once per eligible row.
-- No statement_timeout inflation, sender/authority change, allowlist mutation, or CANARY activation is introduced.

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
  with prepared as materialized (
    select
      k.knowledge_id,k.domain,k.subject_type,k.subject_id,k.title,k.facts,k.authority_tier,
      k.source_relation,k.source_pk,k.source_updated_at,k.freshness_state,k.conflict_state,
      k.retrieval_state,k.evidence_ref,
      public.aos_wa4a_norm_v1(k.title) as norm_title,
      public.aos_wa4a_norm_v1(k.search_text) as norm_search
    from public.aos_wa4a_knowledge_items_v1 k
    where k.retrieval_state in ('READY','READY_WITH_WARNING')
      and k.conflict_state='CLEAR'
      and (p_domains is null or cardinality(p_domains)=0 or k.domain=any(p_domains))
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

-- The WA4 Copilot intentionally records a SALES_PLAYBOOK fail-closed audit when governed
-- knowledge cannot be loaded. PROD showed the logger itself was rejected by the old task CHECK.
alter table public.aos_wa_ai_runs_v1
  drop constraint if exists aos_wa_ai_runs_v1_task_check;
alter table public.aos_wa_ai_runs_v1
  add constraint aos_wa_ai_runs_v1_task_check
  check (task = any(array['SALES_COPILOT'::text,'SALES_PLAYBOOK'::text,'MODEL_EVAL'::text]));

comment on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) is
'WA4A governed search hot-path v1: authority/ranking semantics preserved; eligible derived rows are normalized once via MATERIALIZED prepared set to prevent repeated regex normalization per token.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
