-- ASCENDA OS — Phase 3 Product Canonical v1
-- Additive only. Never rewrites aos_ventas.descripcion or financial/client fields.

create table if not exists public.aos_product_identity_v1 (
  product_key text primary key,
  canonical_name text not null unique,
  catalog_service_id uuid null references public.aos_catalogo_servicios(id) on delete set null,
  lifecycle_status text not null check (lifecycle_status in ('CATALOG','CURRENT_UNCATALOGED','LEGACY','REVIEW')),
  product_group text null,
  variant_label text null,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_product_alias_v2 (
  alias_key text primary key,
  alias_text text not null,
  product_key text not null references public.aos_product_identity_v1(product_key) on delete restrict,
  default_qty numeric null check (default_qty is null or default_qty >= 0),
  default_is_pack boolean null,
  source text not null,
  confidence text not null check (confidence in ('OWNER_CONFIRMED','CATALOG_EXACT','EXPLICIT_ALIAS','INVENTORY_EVIDENCE','LEGACY_CONFIRMED')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_product_sale_fact_v1 (
  sale_id bigint primary key,
  product_key text null references public.aos_product_identity_v1(product_key) on delete restrict,
  raw_alias_key text null,
  physical_qty numeric null check (physical_qty is null or physical_qty >= 0),
  is_pack boolean null,
  resolution_status text not null check (resolution_status in ('RESOLVED','EXCLUDED','REVIEW_REQUIRED')),
  resolution_source text not null,
  locked boolean not null default false,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aos_product_identity_v1 enable row level security;
alter table public.aos_product_alias_v2 enable row level security;
alter table public.aos_product_sale_fact_v1 enable row level security;

revoke all on table public.aos_product_identity_v1 from public, anon, authenticated;
revoke all on table public.aos_product_alias_v2 from public, anon, authenticated;
revoke all on table public.aos_product_sale_fact_v1 from public, anon, authenticated;
grant all on table public.aos_product_identity_v1 to service_role;
grant all on table public.aos_product_alias_v2 to service_role;
grant all on table public.aos_product_sale_fact_v1 to service_role;

create or replace function public.aos_product_normalize_alias_v2(p_value text)
returns text
language sql
immutable
set search_path='pg_catalog'
as $function$
  select nullif(
    regexp_replace(
      translate(upper(btrim(coalesce(p_value,''))),
        'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ',
        'AAAAAEEEEIIIIOOOOOUUUUNC'),
      '[^A-Z0-9]+','','g'
    ),
    ''
  );
$function$;

revoke all on function public.aos_product_normalize_alias_v2(text) from public;
grant execute on function public.aos_product_normalize_alias_v2(text) to service_role;

create or replace function public.aos_product_resolve_sale_v1(p_sale_id bigint)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_sale record;
  v_existing record;
  v_alias text;
  v_match record;
begin
  select v.id,v.tipo,v.tratamiento,v.descripcion
    into v_sale
  from public.aos_ventas v
  where v.id=p_sale_id;

  if v_sale.id is null then
    return pg_catalog.jsonb_build_object('ok',false,'status','NOT_FOUND');
  end if;

  select f.* into v_existing
  from public.aos_product_sale_fact_v1 f
  where f.sale_id=p_sale_id;

  if v_existing.sale_id is not null and coalesce(v_existing.locked,false) then
    return pg_catalog.jsonb_build_object('ok',true,'status','LOCKED_REVIEW_PRESERVED','sale_id',p_sale_id);
  end if;

  if pg_catalog.upper(pg_catalog.btrim(coalesce(v_sale.tipo,''))) <> 'PRODUCTO'
     and pg_catalog.upper(pg_catalog.btrim(coalesce(v_sale.tratamiento,''))) not like '%COMPRA%PRODUCTO%' then
    delete from public.aos_product_sale_fact_v1
    where sale_id=p_sale_id and locked=false;
    return pg_catalog.jsonb_build_object('ok',true,'status','NOT_PRODUCT','sale_id',p_sale_id);
  end if;

  v_alias:=public.aos_product_normalize_alias_v2(v_sale.descripcion);

  select a.product_key,a.default_qty,a.default_is_pack,a.confidence
    into v_match
  from public.aos_product_alias_v2 a
  where a.alias_key=v_alias and a.active=true
  limit 1;

  if v_match.product_key is null then
    insert into public.aos_product_sale_fact_v1(
      sale_id,product_key,raw_alias_key,physical_qty,is_pack,
      resolution_status,resolution_source,locked,note,updated_at
    ) values (
      p_sale_id,null,v_alias,null,null,
      'REVIEW_REQUIRED','AUTO_ALIAS_V2',false,'No confirmed alias for current description',pg_catalog.now()
    )
    on conflict (sale_id) do update set
      product_key=excluded.product_key,
      raw_alias_key=excluded.raw_alias_key,
      physical_qty=excluded.physical_qty,
      is_pack=excluded.is_pack,
      resolution_status=excluded.resolution_status,
      resolution_source=excluded.resolution_source,
      note=excluded.note,
      updated_at=pg_catalog.now()
    where public.aos_product_sale_fact_v1.locked=false;

    return pg_catalog.jsonb_build_object('ok',true,'status','REVIEW_REQUIRED','sale_id',p_sale_id,'alias_key',v_alias);
  end if;

  insert into public.aos_product_sale_fact_v1(
    sale_id,product_key,raw_alias_key,physical_qty,is_pack,
    resolution_status,resolution_source,locked,note,updated_at
  ) values (
    p_sale_id,v_match.product_key,v_alias,coalesce(v_match.default_qty,1),coalesce(v_match.default_is_pack,false),
    'RESOLVED','AUTO_ALIAS_V2',false,'Resolved from confirmed Phase 3 alias',pg_catalog.now()
  )
  on conflict (sale_id) do update set
    product_key=excluded.product_key,
    raw_alias_key=excluded.raw_alias_key,
    physical_qty=excluded.physical_qty,
    is_pack=excluded.is_pack,
    resolution_status=excluded.resolution_status,
    resolution_source=excluded.resolution_source,
    note=excluded.note,
    updated_at=pg_catalog.now()
  where public.aos_product_sale_fact_v1.locked=false;

  return pg_catalog.jsonb_build_object('ok',true,'status','RESOLVED','sale_id',p_sale_id,'product_key',v_match.product_key);
end
$function$;

revoke all on function public.aos_product_resolve_sale_v1(bigint) from public, anon, authenticated;
grant execute on function public.aos_product_resolve_sale_v1(bigint) to service_role;

create or replace function public.aos_product_sync_sale_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  perform public.aos_product_resolve_sale_v1(new.id);
  return new;
end
$function$;

revoke all on function public.aos_product_sync_sale_trigger_v1() from public, anon, authenticated;
grant execute on function public.aos_product_sync_sale_trigger_v1() to service_role;

drop trigger if exists trg_aos_product_sync_sale_v1 on public.aos_ventas;
create trigger trg_aos_product_sync_sale_v1
after insert or update of tipo,tratamiento,descripcion on public.aos_ventas
for each row execute function public.aos_product_sync_sale_trigger_v1();

create or replace function public.aos_product_backfill_unlocked_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_id bigint;
  v_total integer:=0;
begin
  for v_id in
    select v.id
    from public.aos_ventas v
    where pg_catalog.upper(pg_catalog.btrim(coalesce(v.tipo,'')))='PRODUCTO'
       or pg_catalog.upper(pg_catalog.btrim(coalesce(v.tratamiento,''))) like '%COMPRA%PRODUCTO%'
    order by v.id
  loop
    perform public.aos_product_resolve_sale_v1(v_id);
    v_total:=v_total+1;
  end loop;
  return pg_catalog.jsonb_build_object('ok',true,'processed',v_total);
end
$function$;

revoke all on function public.aos_product_backfill_unlocked_v1() from public, anon, authenticated;
grant execute on function public.aos_product_backfill_unlocked_v1() to service_role;

create or replace view public.aos_product_sale_fact_current_v1 as
select
  f.sale_id,
  v.fecha,
  v.sede,
  v.descripcion as raw_description,
  f.raw_alias_key,
  f.resolution_status,
  f.resolution_source,
  f.physical_qty,
  f.is_pack,
  f.locked,
  i.product_key,
  i.canonical_name,
  i.lifecycle_status,
  i.catalog_service_id
from public.aos_product_sale_fact_v1 f
join public.aos_ventas v on v.id=f.sale_id
left join public.aos_product_identity_v1 i on i.product_key=f.product_key;

revoke all on table public.aos_product_sale_fact_current_v1 from public, anon, authenticated;
grant select on table public.aos_product_sale_fact_current_v1 to service_role;
