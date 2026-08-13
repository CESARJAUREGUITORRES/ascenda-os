-- ASCENDA OS — CIA Phase 4 product catalog reconciliation
begin;
create or replace view public.aos_cia_product_catalog_alias_v1 with(security_invoker=true) as
with catalog as (
 select nombre,nombre_corto,categoria
 from public.aos_catalogo_servicios
 where upper(btrim(coalesce(tipo,'')))='PRODUCTO'
), candidates as (
 select public.aos_cia_normalize_item_label_v1(nombre_corto) alias_key,nombre_corto canonical_short_name,categoria,'CATALOG_SHORT'::text source from catalog
 union all
 select public.aos_cia_normalize_item_label_v1(nombre),nombre_corto,categoria,'CATALOG_NAME' from catalog
 union all
 select public.aos_cia_normalize_item_label_v1(o.alias_text),c.nombre_corto,c.categoria,'EXPLICIT_ALIAS'
 from public.aos_product_alias_overrides o
 join catalog c on upper(btrim(c.nombre_corto))=upper(btrim(o.canonical_short_name))
 where o.active=true
), u as (
 select alias_key,min(canonical_short_name) canonical_short_name,min(categoria) category,
 case when bool_or(source='EXPLICIT_ALIAS') then 'EXPLICIT_ALIAS' else 'CATALOG_EXACT' end::text confidence,
 count(distinct canonical_short_name) canonical_count
 from candidates where alias_key is not null group by alias_key
)
select alias_key,canonical_short_name,category,confidence from u where canonical_count=1;

create or replace view public.aos_cia_product_sale_reconciliation_v1 with(security_invoker=true) as
select v.id::text sale_row_id,
 public.aos_cia_normalize_contact_key_v1(v.numero_limpio) contact_key,
 v.fecha,
 nullif(btrim(v.descripcion),'') raw_description,
 public.aos_cia_normalize_item_label_v1(v.descripcion) alias_key,
 a.canonical_short_name,
 a.category product_category,
 coalesce(a.confidence,'UNKNOWN')::text reconciliation_confidence
from public.aos_ventas v
left join public.aos_cia_product_catalog_alias_v1 a
 on a.alias_key=public.aos_cia_normalize_item_label_v1(v.descripcion)
where upper(btrim(coalesce(v.tipo,'')))='PRODUCTO'
 and public.aos_cia_normalize_contact_key_v1(v.numero_limpio) is not null;

revoke all on public.aos_cia_product_catalog_alias_v1,public.aos_cia_product_sale_reconciliation_v1 from public,anon,authenticated;
grant select on public.aos_cia_product_catalog_alias_v1,public.aos_cia_product_sale_reconciliation_v1 to service_role;
commit;
