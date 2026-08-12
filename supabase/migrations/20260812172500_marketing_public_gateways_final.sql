-- ASCENDA OS — Marketing V3 public aggregate gateways
-- Browser-facing functions expose aggregate/no-PII reporting only.
-- Internal attribution/matching helpers remain non-public.

create or replace function public.aos_marketing_ltv_public_v2(p_anio integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.mes), '[]'::jsonb)
  from public.aos_marketing_cohortes_ltv_v2_preview(p_anio) x;
$$;

create or replace function public.aos_marketing_anuncios_public_v2(
  p_anio integer,
  p_mes integer default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0,
  p_order text default 'fact_acum'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v jsonb;
begin
  if p_mes is null then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v
    from public.aos_marketing_anuncios_v2_anio_preview(p_anio,p_search,p_limit,p_offset,p_order) x;
  else
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v
    from public.aos_marketing_anuncios_v2_preview(p_mes,p_anio,p_search,p_limit,p_offset,p_order) x;
  end if;
  return v;
end;
$$;

create or replace function public.aos_marketing_campanas_public_v2(
  p_anio integer,
  p_mes integer default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0,
  p_order text default 'fact_acum'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v jsonb;
begin
  if p_mes is null then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v
    from public.aos_marketing_campanas_v2_anio_preview(p_anio,p_search,p_limit,p_offset,p_order) x;
  else
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v
    from public.aos_marketing_campanas_v2_preview(p_mes,p_anio,p_search,p_limit,p_offset,p_order) x;
  end if;
  return v;
end;
$$;

create or replace function public.aos_marketing_intent_public_v2(p_mes integer,p_anio integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.tratamiento_interes, x.facturacion desc), '[]'::jsonb)
  from public.aos_marketing_intent_to_purchase_v2_preview(p_mes,p_anio) x;
$$;

create or replace function public.aos_marketing_attribution_public_v2(p_mes integer,p_anio integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.aos_marketing_attribution_summary_v2_preview(p_mes,p_anio);
$$;

create or replace function public.aos_marketing_attribution_public_v2_anio(p_anio integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.aos_marketing_attribution_summary_v2_anio_preview(p_anio);
$$;

revoke all on function public.aos_marketing_ltv_public_v2(integer) from public;
revoke all on function public.aos_marketing_anuncios_public_v2(integer,integer,text,integer,integer,text) from public;
revoke all on function public.aos_marketing_campanas_public_v2(integer,integer,text,integer,integer,text) from public;
revoke all on function public.aos_marketing_intent_public_v2(integer,integer) from public;
revoke all on function public.aos_marketing_attribution_public_v2(integer,integer) from public;
revoke all on function public.aos_marketing_attribution_public_v2_anio(integer) from public;

grant execute on function public.aos_marketing_ltv_public_v2(integer) to anon, authenticated;
grant execute on function public.aos_marketing_anuncios_public_v2(integer,integer,text,integer,integer,text) to anon, authenticated;
grant execute on function public.aos_marketing_campanas_public_v2(integer,integer,text,integer,integer,text) to anon, authenticated;
grant execute on function public.aos_marketing_intent_public_v2(integer,integer) to anon, authenticated;
grant execute on function public.aos_marketing_attribution_public_v2(integer,integer) to anon, authenticated;
grant execute on function public.aos_marketing_attribution_public_v2_anio(integer) to anon, authenticated;
