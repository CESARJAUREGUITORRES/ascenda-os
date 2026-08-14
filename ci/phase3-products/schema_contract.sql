\set ON_ERROR_STOP on

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.aos_catalogo_servicios (
  id uuid primary key default extensions.gen_random_uuid(),
  nombre text not null,
  nombre_corto text,
  tipo text,
  categoria text,
  estado text default 'ACTIVO'
);

create table if not exists public.aos_ventas (
  id bigint primary key,
  fecha date,
  tratamiento text,
  descripcion text,
  sede text,
  tipo text
);

create table if not exists public.aos_product_alias_overrides (
  alias_text text primary key,
  canonical_short_name text not null,
  reason text,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create or replace function public.aos_cia_normalize_item_label_v1(p_value text)
returns text language sql immutable set search_path='pg_catalog' as $$
  select nullif(regexp_replace(translate(upper(btrim(coalesce(p_value,''))),
    'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ','AAAAAEEEEIIIIOOOOOUUUUNC'),'[^A-Z0-9]+','','g'),'');
$$;

create or replace view public.aos_cia_product_catalog_alias_v1 as
with catalog as (
  select nombre,nombre_corto,categoria
  from public.aos_catalogo_servicios
  where upper(btrim(coalesce(tipo,'')))='PRODUCTO'
), candidates as (
  select public.aos_cia_normalize_item_label_v1(nombre_corto) alias_key,nombre_corto canonical_short_name,categoria,'CATALOG_SHORT'::text source from catalog
  union all
  select public.aos_cia_normalize_item_label_v1(nombre),nombre_corto,categoria,'CATALOG_NAME'::text from catalog
  union all
  select public.aos_cia_normalize_item_label_v1(o.alias_text),c.nombre_corto,c.categoria,'EXPLICIT_ALIAS'::text
  from public.aos_product_alias_overrides o join catalog c on upper(btrim(c.nombre_corto))=upper(btrim(o.canonical_short_name))
  where o.active=true
), u as (
  select alias_key,min(canonical_short_name) canonical_short_name,min(categoria) category,
         case when bool_or(source='EXPLICIT_ALIAS') then 'EXPLICIT_ALIAS' else 'CATALOG_EXACT' end confidence,
         count(distinct canonical_short_name) canonical_count
  from candidates where alias_key is not null group by alias_key
)
select alias_key,canonical_short_name,category,confidence from u where canonical_count=1;

insert into public.aos_catalogo_servicios(nombre,nombre_corto,tipo,categoria,estado) values
('LIFTING B 30GR','LIFTING B','PRODUCTO','FACIAL ZV','ACTIVO'),
('BEAUTY MAKER 300G','BEAUTY MAKER','PRODUCTO','NUTRICIONAL','ACTIVO'),
('NF CAPS MEN/WOMEN','NF CAPS','PRODUCTO','CAPILAR ZV','ACTIVO'),
('HYALURONIC MOISTURE NORMAL/DRY ISDIN','HYAL MOIST ND','PRODUCTO','ISDIN','ACTIVO'),
('HYALURONIC MOISTURE OILY ISDIN','HYAL MOIST OILY','PRODUCTO','ISDIN','ACTIVO'),
('MENTONERA SILICONA','FAJA PAPADA SIL','PRODUCTO','FAJAS','ACTIVO'),
('PRUNEX STICK x1','PRUNEX x1','PRODUCTO','NUTRICIONAL','ACTIVO'),
('RETINAL INTENSE SERUM 50ML ISDIN','RETINAL ISDIN','PRODUCTO','ISDIN','ACTIVO'),
('SHAMPOO MINOXIDIL+VITS 120G','SHAMPOO MINOX','PRODUCTO','CAPILAR ZV','ACTIVO')
on conflict do nothing;

insert into public.aos_product_alias_overrides(alias_text,canonical_short_name,reason,active) values
('LIFTIN B','LIFTING B','LEGACY_TYPO',true),
('SERUM LIFTING B','LIFTING B','LEGACY_ALIAS',true)
on conflict (alias_text) do update set canonical_short_name=excluded.canonical_short_name,active=true;

-- Owner-seed fixture IDs used by negative/consistency checks.
insert into public.aos_ventas(id,fecha,tratamiento,descripcion,sede,tipo) values
(909,'2026-02-07','COMPRA DE PRODUCTO','PERFECT- B 90GR','SAN ISIDRO','PRODUCTO'),
(1644,'2026-05-27','COMPRA DE PRODUCTO','LYMDHARIAL GOTAS','SAN ISIDRO','PRODUCTO'),
(1631,'2026-05-23','COMPRA DE PRODUCTO','GOTAS LYNDHARIAL','PUEBLO LIBRE','PRODUCTO'),
(1632,'2026-05-23','COMPRA DE PRODUCTO','GOTAS LYNDHARIAL','PUEBLO LIBRE','PRODUCTO'),
(1637,'2026-05-27','COMPRA DE PRODUCTO','1ER PARTE SERUM LIFTING B','SAN ISIDRO','PRODUCTO'),
(1638,'2026-05-27','COMPRA DE PRODUCTO','2DO PARTE SERUM LIFTING B','SAN ISIDRO','PRODUCTO')
on conflict (id) do nothing;
