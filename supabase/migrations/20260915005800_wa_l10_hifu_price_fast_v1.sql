-- WA-L10 R10 hotpath resilience: serve generic facial HIFU prices from the
-- already-certified WA4A1C price authority instead of broad knowledge retrieval.
-- No autonomous authority transition is performed by this migration.

create or replace function public.aos_wa4_hifu_price_fast_v1()
returns table(
  entity_id uuid,
  entity_type text,
  entity_name text,
  category text,
  mapping_state text,
  mapping_confidence numeric,
  precio_base numeric,
  precio_oferta numeric,
  quote_price numeric,
  price_state text,
  freshness_state text,
  ready_for_quote boolean,
  moneda text,
  price_evidence_ref text
)
language sql
stable
security definer
set search_path=''
as $$
  select c.entity_id,c.entity_type,c.entity_name,c.category,c.mapping_state,c.mapping_confidence,
         c.precio_base,c.precio_oferta,c.quote_price,c.price_state,c.freshness_state,c.ready_for_quote,
         c.moneda,c.price_evidence_ref
  from public.aos_wa4_process_entity_context_v1 c
  where c.mapping_state='MAPPED'
    and c.ready_for_quote is true
    and c.price_state='READY'
    and c.freshness_state='FRESH'
    and upper(c.category)='HIFU'
    and upper(c.entity_name) like 'ZI FROZEN%'
  order by c.quote_price,c.entity_name
  limit 8
$$;

revoke all on function public.aos_wa4_hifu_price_fast_v1() from public,anon,authenticated;
grant execute on function public.aos_wa4_hifu_price_fast_v1() to service_role;

comment on function public.aos_wa4_hifu_price_fast_v1()
is 'WA4A1C-governed, service-role-only facial HIFU price fast lane for ZI FROZEN. Reads only mapped READY/FRESH canonical price authority rows.';
