-- Rollback for WA-L10 first-turn hot-path remediation.
-- Refuses to narrow the audit task CHECK if SALES_PLAYBOOK evidence already exists.

begin;

do $$
begin
  if exists(select 1 from public.aos_wa_ai_runs_v1 where task='SALES_PLAYBOOK' limit 1) then
    raise exception 'WA_L10_RECOVERY_BLOCKED_SALES_PLAYBOOK_AUDIT_HISTORY' using errcode='55000';
  end if;
end
$$;

create or replace function public.aos_wa4a_knowledge_search_v1(
  p_query text,
  p_limit integer default 12,
  p_domains text[] default null
)
returns table(
  knowledge_id text, domain text, subject_type text, subject_id text, title text,
  facts jsonb, authority_tier smallint, source_relation text, source_pk text,
  source_updated_at timestamptz, freshness_state text, conflict_state text,
  retrieval_state text, evidence_ref jsonb, score integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_q text := public.aos_wa4a_norm_v1(p_query);
  v_limit integer := greatest(1,least(coalesce(p_limit,12),24));
begin
  if length(v_q)<2 then return; end if;
  return query
  select k.knowledge_id,k.domain,k.subject_type,k.subject_id,k.title,k.facts,k.authority_tier,
    k.source_relation,k.source_pk,k.source_updated_at,k.freshness_state,k.conflict_state,k.retrieval_state,k.evidence_ref,
    (case when public.aos_wa4a_norm_v1(k.title)=v_q then 100 else 0 end
      + case when public.aos_wa4a_norm_v1(k.title) like '%'||v_q||'%' then 45 else 0 end
      + case when public.aos_wa4a_norm_v1(k.search_text) like '%'||v_q||'%' then 25 else 0 end
      + coalesce((select count(*)::integer*6 from unnest(string_to_array(v_q,' ')) w where length(w)>=3 and public.aos_wa4a_norm_v1(k.search_text) like '%'||w||'%'),0)
      + case when k.authority_tier=10 then 5 else 0 end)::integer as score
  from public.aos_wa4a_knowledge_items_v1 k
  where k.retrieval_state in ('READY','READY_WITH_WARNING')
    and k.conflict_state='CLEAR'
    and (p_domains is null or cardinality(p_domains)=0 or k.domain=any(p_domains))
    and (public.aos_wa4a_norm_v1(k.title) like '%'||v_q||'%'
      or public.aos_wa4a_norm_v1(k.search_text) like '%'||v_q||'%'
      or exists(select 1 from unnest(string_to_array(v_q,' ')) w where length(w)>=3 and public.aos_wa4a_norm_v1(k.search_text) like '%'||w||'%'))
  order by score desc,k.authority_tier asc,k.title asc
  limit v_limit;
end
$$;

revoke all on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v1(text,integer,text[]) to service_role;

alter table public.aos_wa_ai_runs_v1
  drop constraint if exists aos_wa_ai_runs_v1_task_check;
alter table public.aos_wa_ai_runs_v1
  add constraint aos_wa_ai_runs_v1_task_check
  check (task = any(array['SALES_COPILOT'::text,'MODEL_EVAL'::text]));

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
