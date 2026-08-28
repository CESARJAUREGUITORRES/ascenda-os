-- ASCENDA OS — WA-4A.1 Zi Vital Governed Knowledge V1
-- TEST-first / PROD-ready. Depends on WA-4A Knowledge Fabric.
-- User-provided PDF content is transformed into explicit audience columns.
begin;

do $$
begin
  if to_regprocedure('public.aos_wa4a_norm_v1(text)') is null then
    raise exception 'WA4A1_REQUIRES_WA4A_KNOWLEDGE_FABRIC';
  end if;
end
$$;

create table if not exists public.aos_zi_knowledge_sources_v1 (
  source_key text primary key,
  title text not null,
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  page_count integer not null check (page_count > 0),
  source_version text not null,
  approval_state text not null default 'APPROVED' check (approval_state in ('DRAFT','APPROVED','RETIRED')),
  ingested_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_zi_knowledge_entities_v1 (
  entity_key text primary key,
  entity_type text not null check (entity_type in ('SYSTEM','PRINCIPLE','CROSS_LAYER','DOMAIN','APPROACH','PROCESS','ROLE','CARE_PHASE')),
  canonical_name text not null,
  aliases text[] not null default '{}',
  parent_entity_key text references public.aos_zi_knowledge_entities_v1(entity_key) on update cascade on delete restrict,
  source_key text not null references public.aos_zi_knowledge_sources_v1(source_key) on update cascade on delete restrict,
  page_start integer not null check (page_start > 0),
  page_end integer not null check (page_end >= page_start),
  canonical_summary text not null,
  public_client text not null,
  advisor_internal text not null,
  owner_admin text not null,
  clinical_restricted text not null,
  system_reference jsonb not null default '{}'::jsonb,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','REVIEW','RETIRED')),
  version text not null default 'ZI_KNOWLEDGE_V1_20260827',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_zi_knowledge_entities_lookup_idx
  on public.aos_zi_knowledge_entities_v1(entity_type,status);

create or replace view public.aos_wa4a1_zi_knowledge_items_v1
with (security_invoker=true)
as
select
  'zi:'||e.entity_key||':'||v.audience as knowledge_id,
  'ZI_VITAL'::text as domain,
  e.entity_type as subject_type,
  e.entity_key as subject_id,
  public.aos_wa4a_norm_v1(e.canonical_name) as subject_key,
  e.canonical_name as title,
  concat_ws(' ',e.canonical_name,array_to_string(e.aliases,' '),e.canonical_summary,v.content,e.system_reference::text) as search_text,
  jsonb_build_object(
    'entity_key',e.entity_key,
    'entity_type',e.entity_type,
    'canonical_name',e.canonical_name,
    'aliases',to_jsonb(e.aliases),
    'parent_entity_key',e.parent_entity_key,
    'audience',v.audience,
    'content',v.content,
    'payload',case when v.audience='SYSTEM_REFERENCE' then e.system_reference else '{}'::jsonb end,
    'risk_level',v.risk_level,
    'answerable',v.answerable,
    'requires_human',v.requires_human
  ) as facts,
  15::smallint as authority_tier,
  'public.aos_zi_knowledge_entities_v1'::text as source_relation,
  e.entity_key||':'||v.audience as source_pk,
  e.updated_at as source_updated_at,
  null::timestamptz as valid_from,
  null::timestamptz as valid_to,
  'FRESH'::text as freshness_state,
  'CLEAR'::text as conflict_state,
  case when e.status='ACTIVE' then 'READY' else 'BLOCKED_INACTIVE' end::text as retrieval_state,
  jsonb_build_object(
    'relation','public.aos_zi_knowledge_entities_v1',
    'pk',e.entity_key||':'||v.audience,
    'version',e.version,
    'source_key',e.source_key,
    'pages',jsonb_build_array(e.page_start,e.page_end),
    'sha256',src.sha256
  ) as evidence_ref
from public.aos_zi_knowledge_entities_v1 e
join public.aos_zi_knowledge_sources_v1 src on src.source_key=e.source_key
cross join lateral (
  values
    ('PUBLIC_CLIENT'::text,e.public_client,'LOW'::text,true,false),
    ('ADVISOR_INTERNAL',e.advisor_internal,'LOW',true,false),
    ('OWNER_ADMIN',e.owner_admin,'LOW',true,false),
    ('CLINICAL_RESTRICTED',e.clinical_restricted,'HIGH',false,true),
    ('SYSTEM_REFERENCE',coalesce(e.system_reference->>'summary',e.canonical_summary),'LOW',true,false)
) v(audience,content,risk_level,answerable,requires_human)
where src.approval_state='APPROVED';

create or replace function public.aos_wa4a1_zi_knowledge_search_v1(
  p_query text,
  p_audience text,
  p_limit integer default 12
)
returns table (
  knowledge_id text, domain text, subject_type text, subject_id text, subject_key text, title text,
  facts jsonb, authority_tier smallint, source_relation text, source_pk text, source_updated_at timestamptz,
  valid_from timestamptz, valid_to timestamptz, freshness_state text, conflict_state text,
  retrieval_state text, evidence_ref jsonb, rank_score integer
)
language sql stable security definer set search_path=''
as $$
  with q as (
    select public.aos_wa4a_norm_v1(coalesce(p_query,'')) as nq,
           upper(coalesce(p_audience,'')) as audience,
           greatest(1,least(coalesce(p_limit,12),24)) as lim
  ),
  ranked as (
    select i.*,
      (
        case
          when public.aos_wa4a_norm_v1(i.title)=q.nq and q.nq<>'' then 100
          when public.aos_wa4a_norm_v1(i.title) like '%'||q.nq||'%' and q.nq<>'' then 70
          when public.aos_wa4a_norm_v1(i.search_text) like '%'||q.nq||'%' and q.nq<>'' then 50
          when q.nq='' then 10 else 0
        end
        + coalesce((
          select count(*)::integer*10
          from regexp_split_to_table(q.nq,'\s+') tok
          where length(tok)>=3
            and public.aos_wa4a_norm_v1(i.search_text) like '%'||tok||'%'
        ),0)
      )::integer as rank_score
    from public.aos_wa4a1_zi_knowledge_items_v1 i
    cross join q
    where i.facts->>'audience'=q.audience
      and i.retrieval_state='READY'
      and q.audience in ('PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE')
  )
  select knowledge_id,domain,subject_type,subject_id,subject_key,title,facts,authority_tier,
         source_relation,source_pk,source_updated_at,valid_from,valid_to,freshness_state,
         conflict_state,retrieval_state,evidence_ref,rank_score
  from ranked,q
  where rank_score>0
  order by rank_score desc, authority_tier asc, title asc
  limit (select lim from q);
$$;

revoke all on table public.aos_zi_knowledge_sources_v1 from public,anon,authenticated;
revoke all on table public.aos_zi_knowledge_entities_v1 from public,anon,authenticated;
revoke all on table public.aos_wa4a1_zi_knowledge_items_v1 from public,anon,authenticated;
revoke all on function public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer) from public,anon,authenticated;
grant select on table public.aos_zi_knowledge_sources_v1,public.aos_zi_knowledge_entities_v1,public.aos_wa4a1_zi_knowledge_items_v1 to service_role;
grant execute on function public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer) to service_role;

insert into public.aos_zi_knowledge_sources_v1(source_key,title,sha256,page_count,source_version,approval_state)
values
('ZI_DOMAINS_20260827','EL SISTEMA DE DOMINIOS ZI VITAL','cbb2a3cf2ff0458203004d41522595d5322c30dc1d084eb4e9c4f591b81ad901',14,'2026-08-27','APPROVED'),
('ZI_ATTENTION_20260827','PROCESO ATENCIÓN ZI VITAL','ac9a61cfd19368a308f78e900b37108c24021ee419fe578cc7635f1000af3254',8,'2026-08-27','APPROVED')
on conflict (source_key) do update set title=excluded.title,sha256=excluded.sha256,page_count=excluded.page_count,source_version=excluded.source_version,approval_state=excluded.approval_state,updated_at=now();

commit;
