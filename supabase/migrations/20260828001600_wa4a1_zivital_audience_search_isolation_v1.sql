-- WA-4A.1 hardening — search only within the requested audience projection.
begin;
create or replace function public.aos_wa4a_knowledge_search_v2(
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
with params as (
  select trim(coalesce(p_query,'')) q,
         case when upper(coalesce(p_audience,'PUBLIC_CLIENT')) in ('PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE')
              then upper(coalesce(p_audience,'PUBLIC_CLIENT')) else 'PUBLIC_CLIENT' end audience,
         greatest(1,least(coalesce(p_limit,12),24)) lim
),
base as (
  select b.* from params p
  cross join lateral public.aos_wa4a_knowledge_search_v1(p.q,p.lim,p_domains) b
  where p_domains is null or b.domain=any(p_domains)
),
clinic_source as (
  select n.*,p.*,
    case p.audience
      when 'PUBLIC_CLIENT' then n.public_client
      when 'ADVISOR_INTERNAL' then n.advisor_internal
      when 'OWNER_ADMIN' then n.owner_admin
      when 'CLINICAL_RESTRICTED' then n.clinical_restricted
      when 'SYSTEM_REFERENCE' then concat_ws(' ',n.owner_admin,n.advisor_internal,n.public_client,n.system_reference::text)
    end as audience_text
  from public.aos_knowledge_nodes_v1 n cross join params p
  where n.status='APPROVED'
),
clinic as (
  select
    'clinic:'||n.code as knowledge_id,
    'CLINIC_KNOWLEDGE'::text as domain,
    n.node_type::text as subject_type,
    n.code::text as subject_id,
    n.title::text,
    jsonb_strip_nulls(jsonb_build_object(
      'code',n.code,'node_type',n.node_type,'parent_code',n.parent_code,'title',n.title,'aliases',n.aliases,
      'answer',case n.audience when 'SYSTEM_REFERENCE' then coalesce(n.owner_admin,n.advisor_internal,n.public_client) else n.audience_text end,
      'public_summary',case when n.audience in ('ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE') then n.public_client end,
      'system_reference',case when n.audience in ('OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE') then n.system_reference end,
      'risk_level',n.risk_level,'audience',n.audience
    )) as facts,
    15::smallint as authority_tier,
    'public.aos_knowledge_nodes_v1'::text as source_relation,
    n.code::text as source_pk,
    n.updated_at as source_updated_at,
    'GOVERNED'::text as freshness_state,
    'CLEAR'::text as conflict_state,
    case when coalesce(n.audience_text,'')='' then 'BLOCKED_AUDIENCE' else 'READY' end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_knowledge_nodes_v1','pk',n.code,'version',n.version::text,'source_code',n.source_code,'source_locator',n.source_locator,'audience',n.audience) as evidence_ref,
    (case
      when public.aos_wa4a_norm_v1(n.title)=public.aos_wa4a_norm_v1(n.q) then 140
      when public.aos_wa4a_norm_v1(n.title) like '%'||public.aos_wa4a_norm_v1(n.q)||'%' then 110
      when public.aos_wa4a_norm_v1(n.aliases::text) like '%'||public.aos_wa4a_norm_v1(n.q)||'%' then 90
      when public.aos_wa4a_norm_v1(array_to_string(n.keywords,' ')) like '%'||public.aos_wa4a_norm_v1(n.q)||'%' then 80
      when public.aos_wa4a_norm_v1(n.audience_text) like '%'||public.aos_wa4a_norm_v1(n.q)||'%' then 60
      else 10 end)::integer as score
  from clinic_source n
  where (p_domains is null or 'CLINIC_KNOWLEDGE'=any(p_domains))
    and coalesce(n.audience_text,'')<>''
    and (n.q='' or public.aos_wa4a_norm_v1(concat_ws(' ',n.title,n.aliases::text,array_to_string(n.keywords,' '),n.audience_text)) like '%'||public.aos_wa4a_norm_v1(n.q)||'%')
),
all_rows as (
  select * from base
  union all
  select * from clinic where retrieval_state='READY'
)
select * from all_rows order by score desc,authority_tier asc,title limit (select lim from params);
$$;
revoke all on function public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]) to service_role;
commit;
