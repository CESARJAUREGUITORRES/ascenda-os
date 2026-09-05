-- WA4A retrieval relevance V2
-- Fixes R3 real-turn failure where generic commercial words ("informacion", "precio")
-- outranked the actual treatment terms. Preserves function signature, candidate-prefilter
-- architecture, authority/conflict gates and callers.

create or replace function public.aos_wa4a_knowledge_search_v1(
  p_query text,
  p_limit integer default 12,
  p_domains text[] default null::text[]
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
set search_path to ''
as $function$
declare
  v_q text := public.aos_wa4a_norm_v1(p_query);
  v_limit integer := greatest(1,least(coalesce(p_limit,12),24));
  v_raw_tokens text[];
  v_tokens text[];
begin
  if length(v_q) < 2 then
    return;
  end if;

  select coalesce(array_agg(distinct w),array[]::text[])
    into v_raw_tokens
  from unnest(string_to_array(v_q,' ')) w
  where length(w) >= 3;

  -- Remove conversational/commercial filler before candidate selection. These words
  -- occur in nearly every catalog FAQ and previously swamped the treatment signal.
  select coalesce(array_agg(distinct token),array[]::text[])
    into v_tokens
  from (
    select w as token
    from unnest(v_raw_tokens) w
    where w <> all(array[
      'hola','buenas','buenos','dias','tardes','noches',
      'quiero','quisiera','necesito','informacion','sobre','saber',
      'precio','precios','cuanto','cuesta','costo','costos',
      'dame','favor','porfavor','para','como','puedo','puede','tener',
      'mas','del','una','uno','unos','unas','que'
    ]::text[])
    union all
    -- Commercial synonym only for retrieval. It does not alter governed facts.
    select 'toxina'
    where exists (
      select 1 from unnest(v_raw_tokens) w where w in ('botox','botulinica')
    )
  ) s;

  -- For an unusually generic query, retain the legacy token behavior rather than
  -- manufacturing a treatment match.
  if coalesce(cardinality(v_tokens),0) = 0 then
    v_tokens := v_raw_tokens;
  end if;

  return query
  with folded as materialized (
    select
      k.knowledge_id,k.domain,k.subject_type,k.subject_id,k.title,k.search_text,k.facts,k.authority_tier,
      k.source_relation,k.source_pk,k.source_updated_at,k.freshness_state,k.conflict_state,
      k.retrieval_state,k.evidence_ref,
      lower(translate(coalesce(k.title,''),'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) as fold_title,
      lower(translate(concat_ws(' ',
        k.title,
        k.facts->>'nombre',
        k.facts->>'nombre_corto',
        k.facts->>'categoria'
      ),'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) as fold_structured,
      lower(translate(coalesce(k.search_text,''),'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) as fold_search
    from public.aos_wa4a_knowledge_items_v1 k
    where k.retrieval_state in ('READY','READY_WITH_WARNING')
      and k.conflict_state='CLEAR'
      and (p_domains is null or cardinality(p_domains)=0 or k.domain=any(p_domains))
  ), candidates as materialized (
    select f.*
    from folded f
    where exists (
      select 1
      from unnest(v_tokens) w
      where f.fold_structured like '%'||w||'%'
         or f.fold_search like '%'||w||'%'
    )
  ), prepared as materialized (
    select
      c.*,
      public.aos_wa4a_norm_v1(c.title) as norm_title,
      public.aos_wa4a_norm_v1(concat_ws(' ',
        c.title,
        c.facts->>'nombre',
        c.facts->>'nombre_corto',
        c.facts->>'categoria'
      )) as norm_structured,
      public.aos_wa4a_norm_v1(c.search_text) as norm_search
    from candidates c
  ), ranked as (
    select
      p.*,
      (
        case when p.norm_title=v_q then 140 else 0 end
        + case when p.norm_title like '%'||v_q||'%' then 45 else 0 end
        + case when p.norm_search like '%'||v_q||'%' then 25 else 0 end
        + coalesce((select count(*)::integer*90 from unnest(v_tokens) w where p.norm_title like '%'||w||'%'),0)
        + coalesce((select count(*)::integer*60 from unnest(v_tokens) w where p.norm_structured like '%'||w||'%'),0)
        + coalesce((select count(*)::integer*8 from unnest(v_tokens) w where p.norm_search like '%'||w||'%'),0)
        + case when p.authority_tier=10 then 5 else 0 end
        -- Generic toxin inquiries should see the standard zone SKUs before
        -- indication-specific variants such as hyperhidrosis/platisma.
        + case
            when 'toxina'=any(v_tokens)
             and public.aos_wa4a_norm_v1(p.facts->>'categoria')='toxina'
             and p.norm_title ~ '(^| )(1|2|3|[0-9]+) zona(s)?( |$)'
            then 50 else 0
          end
      )::integer as rank_score
    from prepared p
  ), scored as (
    select r.*,max(r.rank_score) over() as max_score
    from ranked r
  )
  select
    s.knowledge_id,s.domain,s.subject_type,s.subject_id,s.title,s.facts,s.authority_tier,
    s.source_relation,s.source_pk,s.source_updated_at,s.freshness_state,s.conflict_state,
    s.retrieval_state,s.evidence_ref,s.rank_score
  from scored s
  where s.rank_score >= greatest(8,ceil(s.max_score*0.35)::integer)
  order by s.rank_score desc,s.authority_tier asc,s.title asc
  limit v_limit;
end
$function$;

comment on function public.aos_wa4a_knowledge_search_v1(text,integer,text[])
is 'WA4A governed retrieval V2: stopword-resistant structured relevance + conservative toxin synonym routing with cheap candidate prefilter.';
