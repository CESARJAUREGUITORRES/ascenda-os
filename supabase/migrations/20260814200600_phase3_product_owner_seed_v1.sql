-- ASCENDA OS — Phase 3 owner-confirmed product seed v1
-- Source: private user workbook Clientes_Productos 2026.xlsx.
-- PII is intentionally NOT embedded here. Only canonical product metadata and sale IDs.

-- 1) Owner-confirmed canonical identities.
with src as (
  select * from jsonb_to_recordset($json$
[{"canonical_name":"ASTAXANTINA 60 CAPS","lifecycle_status":"REVIEW"},{"canonical_name":"BEAUTY MAKER 300G","lifecycle_status":"REVIEW"},{"canonical_name":"CAPTOPRIL x30","lifecycle_status":"LEGACY"},{"canonical_name":"ESSENTIAL CLEANSING 200ML ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"FOTOPROTECTOR INVISIBLE STICK ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"FOTOPROTECTOR MINERAL BRUSH ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"FOTOPROTECTOR OIL CONTROL FUSION WATER 50 ML-ISDIN","lifecycle_status":"CURRENT_UNCATALOGED"},{"canonical_name":"FOTOPROTRCTOR MAGIC FUSION REPAIR COLOR ISDIN","lifecycle_status":"LEGACY"},{"canonical_name":"FOTOULTRA 100 ACTIVE UNIFY 50 ML","lifecycle_status":"REVIEW"},{"canonical_name":"HAPPYLASH BOOST 5 ml","lifecycle_status":"LEGACY"},{"canonical_name":"HELIOCARE 60 CAPS","lifecycle_status":"LEGACY"},{"canonical_name":"HYALURONIC CONCENTRATE 30ML ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"HYALURONIC MOINSTURE 30ML ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"HYALURONIC MOISTURE OILY 30ML ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"HYDRAINTENSIVE 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"HYDRASHIELD 30G","lifecycle_status":"REVIEW"},{"canonical_name":"LIFTING B 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"LIP BALM","lifecycle_status":"REVIEW"},{"canonical_name":"LIPO OUT 250GR","lifecycle_status":"REVIEW"},{"canonical_name":"LOCIÓN SPRAY MINOXIDIL 5%","lifecycle_status":"REVIEW"},{"canonical_name":"LYNDHARIAL CREMA","lifecycle_status":"LEGACY"},{"canonical_name":"LYNDHARIAL GOTAS","lifecycle_status":"LEGACY"},{"canonical_name":"MASCARILLA SECANTE 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"MELACLEAR ADVANCE 30ML ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"MENTONERA DE SILICONA","lifecycle_status":"REVIEW"},{"canonical_name":"NEUROVITAL 120 CAPS","lifecycle_status":"REVIEW"},{"canonical_name":"NF CAPS MEN","lifecycle_status":"REVIEW"},{"canonical_name":"NF CAPS WOMEN","lifecycle_status":"REVIEW"},{"canonical_name":"OK EYES ISDIN","lifecycle_status":"LEGACY"},{"canonical_name":"PERFECT FORM B 90GR","lifecycle_status":"REVIEW"},{"canonical_name":"PERFECT FORM F 90GR","lifecycle_status":"REVIEW"},{"canonical_name":"POWER 10 FIREFIGHTER 30ML","lifecycle_status":"REVIEW"},{"canonical_name":"POWER 10 HONEYDEW FAIRY 30 ML","lifecycle_status":"CURRENT_UNCATALOGED"},{"canonical_name":"POWER 10 PORE LUPIN 30ML","lifecycle_status":"REVIEW"},{"canonical_name":"POWER 10 SOAK UP HELPER 30ML","lifecycle_status":"REVIEW"},{"canonical_name":"PRUNEX STICK","lifecycle_status":"REVIEW"},{"canonical_name":"REDUFAST 120 CAPS","lifecycle_status":"REVIEW"},{"canonical_name":"REGUSHIELD 60GR","lifecycle_status":"REVIEW"},{"canonical_name":"RETINAL INTENSE  50 ML","lifecycle_status":"REVIEW"},{"canonical_name":"SENSICLEAN 120ML","lifecycle_status":"REVIEW"},{"canonical_name":"SENSISHIELD 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"SENSITONIC","lifecycle_status":"CURRENT_UNCATALOGED"},{"canonical_name":"SERUM ACNE CONTROL 30G","lifecycle_status":"REVIEW"},{"canonical_name":"SHAMPOO MINOXIDIL","lifecycle_status":"REVIEW"},{"canonical_name":"SHAMPOO MINOXIDIL GRASO","lifecycle_status":"REVIEW"},{"canonical_name":"SHAMPOO MINOXIDIL SECO","lifecycle_status":"REVIEW"},{"canonical_name":"SKINREGENERATION 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"ULTRA EYES ISDIN","lifecycle_status":"REVIEW"},{"canonical_name":"ULTRAGLOW 30GR","lifecycle_status":"REVIEW"},{"canonical_name":"VITAL EYES ISDIN","lifecycle_status":"LEGACY"},{"canonical_name":"ZINC 50MG x30","lifecycle_status":"REVIEW"}]
$json$::jsonb) as t(canonical_name text,lifecycle_status text)
)
insert into public.aos_product_identity_v1(product_key,canonical_name,lifecycle_status,metadata)
select 'F3:'||public.aos_product_normalize_alias_v2(canonical_name),canonical_name,lifecycle_status,
       jsonb_build_object('source','OWNER_XLSX_2026')
from src
on conflict (canonical_name) do update set
  lifecycle_status=case when public.aos_product_identity_v1.lifecycle_status in ('LEGACY','CURRENT_UNCATALOGED') then public.aos_product_identity_v1.lifecycle_status else excluded.lifecycle_status end,
  metadata=public.aos_product_identity_v1.metadata||excluded.metadata,
  updated_at=now();

-- 2) Match owner identities to current catalog when the existing catalog-alias contract is exact.
update public.aos_product_identity_v1 i
set catalog_service_id=c.id,
    lifecycle_status='CATALOG',
    updated_at=now()
from public.aos_cia_product_catalog_alias_v1 a
join public.aos_catalogo_servicios c
  on upper(btrim(c.nombre_corto))=upper(btrim(a.canonical_short_name))
where i.product_key like 'F3:%'
  and i.lifecycle_status='REVIEW'
  and a.alias_key=public.aos_product_normalize_alias_v2(i.canonical_name)
  and upper(btrim(c.tipo))='PRODUCTO';

-- 3) Explicit high-confidence catalog links where owner wording is intentionally more specific.
with m as (
  select * from jsonb_to_recordset($json$
[{"canonical_name":"HYALURONIC MOINSTURE 30ML ISDIN","catalog_short_name":"HYAL MOIST ND"},{"canonical_name":"HYALURONIC MOISTURE OILY 30ML ISDIN","catalog_short_name":"HYAL MOIST OILY"},{"canonical_name":"MENTONERA DE SILICONA","catalog_short_name":"FAJA PAPADA SIL"},{"canonical_name":"NF CAPS MEN","catalog_short_name":"NF CAPS"},{"canonical_name":"NF CAPS WOMEN","catalog_short_name":"NF CAPS"},{"canonical_name":"PRUNEX STICK","catalog_short_name":"PRUNEX x1"},{"canonical_name":"RETINAL INTENSE  50 ML","catalog_short_name":"RETINAL ISDIN"},{"canonical_name":"SHAMPOO MINOXIDIL","catalog_short_name":"SHAMPOO MINOX"},{"canonical_name":"SHAMPOO MINOXIDIL GRASO","catalog_short_name":"SHAMPOO MINOX"},{"canonical_name":"SHAMPOO MINOXIDIL SECO","catalog_short_name":"SHAMPOO MINOX"}]
$json$::jsonb) as t(canonical_name text,catalog_short_name text)
)
update public.aos_product_identity_v1 i
set catalog_service_id=c.id,lifecycle_status='CATALOG',updated_at=now()
from m
join public.aos_catalogo_servicios c on upper(btrim(c.nombre_corto))=upper(btrim(m.catalog_short_name)) and upper(btrim(c.tipo))='PRODUCTO'
where i.canonical_name=m.canonical_name;

-- REVIEW remaining owner identities are intentionally not auto-promoted.

-- 4) Ensure all current catalog products have an identity, without replacing owner identities.
insert into public.aos_product_identity_v1(product_key,canonical_name,catalog_service_id,lifecycle_status,metadata)
select 'CAT:'||public.aos_product_normalize_alias_v2(c.nombre_corto),c.nombre_corto,c.id,'CATALOG',jsonb_build_object('source','CATALOG_CURRENT')
from public.aos_catalogo_servicios c
where upper(btrim(coalesce(c.tipo,'')))='PRODUCTO' and upper(btrim(coalesce(c.estado,'')))='ACTIVO'
on conflict (canonical_name) do update set
  catalog_service_id=excluded.catalog_service_id,
  lifecycle_status=case when public.aos_product_identity_v1.lifecycle_status in ('LEGACY','CURRENT_UNCATALOGED') then public.aos_product_identity_v1.lifecycle_status else 'CATALOG' end,
  updated_at=now();

-- 5) Baseline current catalog aliases. Owner-confirmed aliases below have priority on conflict.
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack,source,confidence,active)
select a.alias_key,a.alias_key,i.product_key,null,null,'CIA_V1',
       case when a.confidence='EXPLICIT_ALIAS' then 'EXPLICIT_ALIAS' else 'CATALOG_EXACT' end,true
from public.aos_cia_product_catalog_alias_v1 a
join public.aos_catalogo_servicios c on upper(btrim(c.nombre_corto))=upper(btrim(a.canonical_short_name))
join lateral (
  select x.product_key
  from public.aos_product_identity_v1 x
  where x.catalog_service_id=c.id
  order by case when upper(btrim(x.canonical_name))=upper(btrim(c.nombre_corto)) then 0 else 1 end,x.product_key
  limit 1
) i on true
on conflict (alias_key) do nothing;

-- 6) Owner-confirmed historical sale facts. Grouped arrays keep this migration compact and PII-free.
with groups as (
  select * from jsonb_to_recordset($json$
[{"canonical_name":"ASTAXANTINA 60 CAPS","qty":1,"is_pack":false,"sale_ids":[696,707,714,724,779,975,986,1019,1073,1136,1162,1303,1317,1361,1488,1715,1824,2124,2133,2271,2050]},{"canonical_name":"BEAUTY MAKER 300G","qty":1,"is_pack":false,"sale_ids":[660,675,691,708,746,843,1015,1017,1036,1071,1085,1134,1135,1141,1360,1714,2049]},{"canonical_name":"BEAUTY MAKER 300G","qty":1,"is_pack":true,"sale_ids":[1056,1057,1087,1088,1172,1173,1299,1300,1327,1328,1490,1491,1600,1601,1615,1616,2128,2129,2200,2201,2214,2215]},{"canonical_name":"BEAUTY MAKER 300G","qty":2,"is_pack":true,"sale_ids":[1016,1018,1072,1804,2154,2160]},{"canonical_name":"CAPTOPRIL x30","qty":1,"is_pack":false,"sale_ids":[671]},{"canonical_name":"ESSENTIAL CLEANSING 200ML ISDIN","qty":1,"is_pack":false,"sale_ids":[1379,1707,2142,2164,2166]},{"canonical_name":"FOTOPROTECTOR INVISIBLE STICK ISDIN","qty":1,"is_pack":false,"sale_ids":[810,1100,1628,1708,2139,2145,2195,2219]},{"canonical_name":"FOTOPROTECTOR MINERAL BRUSH ISDIN","qty":1,"is_pack":false,"sale_ids":[1613,2148,2284]},{"canonical_name":"FOTOPROTECTOR OIL CONTROL FUSION WATER 50 ML-ISDIN","qty":1,"is_pack":false,"sale_ids":[2136]},{"canonical_name":"FOTOPROTRCTOR MAGIC FUSION REPAIR COLOR ISDIN","qty":1,"is_pack":false,"sale_ids":[1046]},{"canonical_name":"FOTOULTRA 100 ACTIVE UNIFY 50 ML","qty":0,"is_pack":false,"sale_ids":[1534]},{"canonical_name":"FOTOULTRA 100 ACTIVE UNIFY 50 ML","qty":1,"is_pack":false,"sale_ids":[902,1302,1514]},{"canonical_name":"HAPPYLASH BOOST 5 ml","qty":1,"is_pack":false,"sale_ids":[2287]},{"canonical_name":"HELIOCARE 60 CAPS","qty":1,"is_pack":false,"sale_ids":[2066]},{"canonical_name":"HYALURONIC CONCENTRATE 30ML ISDIN","qty":1,"is_pack":false,"sale_ids":[2150]},{"canonical_name":"HYALURONIC MOINSTURE 30ML ISDIN","qty":1,"is_pack":false,"sale_ids":[2151]},{"canonical_name":"HYALURONIC MOISTURE OILY 30ML ISDIN","qty":1,"is_pack":false,"sale_ids":[1744]},{"canonical_name":"HYDRAINTENSIVE 30GR","qty":1,"is_pack":false,"sale_ids":[1694,1713,2216,2069,2111]},{"canonical_name":"HYDRASHIELD 30G","qty":1,"is_pack":false,"sale_ids":[764,815,831,964,1074,1357,1397,1626,1639,2132,2093]},{"canonical_name":"LIFTING B 30GR","qty":0,"is_pack":false,"sale_ids":[1638]},{"canonical_name":"LIFTING B 30GR","qty":1,"is_pack":false,"sale_ids":[765,780,847,866,910,955,977,980,1034,1045,1054,1104,1115,1181,1336,1350,1301,1306,1358,1427,1462,1486,1617,1625,1637,1650,1685,1693,1751,1826,1774,1791,1823,1840,1849,2131,2152,2245,2180,2261,2324]},{"canonical_name":"LIP BALM","qty":1,"is_pack":false,"sale_ids":[1076,1168,1597]},{"canonical_name":"LIPO OUT 250GR","qty":1,"is_pack":false,"sale_ids":[742,791,2306,2229]},{"canonical_name":"LOCIÓN SPRAY MINOXIDIL 5%","qty":1,"is_pack":false,"sale_ids":[674,857,987,1121,1130,1150,1362,1363,1760,2292,2226,2046,2086,2092,2326]},{"canonical_name":"LYNDHARIAL CREMA","qty":1,"is_pack":false,"sale_ids":[697,848,849,1026,1090,2168]},{"canonical_name":"LYNDHARIAL GOTAS","qty":0,"is_pack":false,"sale_ids":[1632]},{"canonical_name":"LYNDHARIAL GOTAS","qty":1,"is_pack":false,"sale_ids":[846,978,1010,1055,1164,2329,1480,1570,1631,1644,1651,2155]},{"canonical_name":"MASCARILLA SECANTE 30GR","qty":1,"is_pack":false,"sale_ids":[2301]},{"canonical_name":"MELACLEAR ADVANCE 30ML ISDIN","qty":1,"is_pack":false,"sale_ids":[2144]},{"canonical_name":"MENTONERA DE SILICONA","qty":1,"is_pack":true,"sale_ids":[1497]},{"canonical_name":"NEUROVITAL 120 CAPS","qty":1,"is_pack":false,"sale_ids":[710,753,999,1035,1058,1075,1156,1318,1329,1554,1572,1670,2286,2051,2067]},{"canonical_name":"NF CAPS MEN","qty":1,"is_pack":false,"sale_ids":[917,1082,1123,1549,1761,2161,2274,2294,2075,2090]},{"canonical_name":"NF CAPS WOMEN","qty":1,"is_pack":false,"sale_ids":[1526,2293,2228,2048]},{"canonical_name":"OK EYES ISDIN","qty":1,"is_pack":false,"sale_ids":[2165]},{"canonical_name":"PERFECT FORM B 90GR","qty":1,"is_pack":false,"sale_ids":[909,1053,1138,2298,2078,2323]},{"canonical_name":"PERFECT FORM F 90GR","qty":1,"is_pack":false,"sale_ids":[783,823,1044,1307,1485,1581,1679,1739,2138]},{"canonical_name":"POWER 10 FIREFIGHTER 30ML","qty":1,"is_pack":false,"sale_ids":[1101]},{"canonical_name":"POWER 10 HONEYDEW FAIRY 30 ML","qty":1,"is_pack":false,"sale_ids":[1020]},{"canonical_name":"POWER 10 PORE LUPIN 30ML","qty":1,"is_pack":false,"sale_ids":[1068,1396,1541,1732]},{"canonical_name":"POWER 10 SOAK UP HELPER 30ML","qty":1,"is_pack":false,"sale_ids":[944,1380,1750]},{"canonical_name":"PRUNEX STICK","qty":1,"is_pack":false,"sale_ids":[1297,1320,1671]},{"canonical_name":"PRUNEX STICK","qty":3,"is_pack":true,"sale_ids":[743,752,776,784,852,1110,1142,1143,1492,1604,1658,1776,1808,2234]},{"canonical_name":"REDUFAST 120 CAPS","qty":1,"is_pack":false,"sale_ids":[762,782,960,1000,1086,1137,1308,1481,1489,1521,1540,1575,1603,1669,1740,2123,2237]},{"canonical_name":"REGUSHIELD 60GR","qty":1,"is_pack":false,"sale_ids":[1487,1537,1596,2225,2052]},{"canonical_name":"RETINAL INTENSE  50 ML","qty":1,"is_pack":false,"sale_ids":[1069,2141,2149,2068]},{"canonical_name":"SENSICLEAN 120ML","qty":1,"is_pack":false,"sale_ids":[1067,1538,1666,1718,2153,2218,2054,2094]},{"canonical_name":"SENSISHIELD 30GR","qty":1,"is_pack":false,"sale_ids":[2297]},{"canonical_name":"SENSITONIC","qty":1,"is_pack":false,"sale_ids":[2249,2296]},{"canonical_name":"SERUM ACNE CONTROL 30G","qty":1,"is_pack":false,"sale_ids":[1009,1014,1371,1430,2302]},{"canonical_name":"SHAMPOO MINOXIDIL","qty":1,"is_pack":false,"sale_ids":[2325]},{"canonical_name":"SHAMPOO MINOXIDIL GRASO","qty":1,"is_pack":false,"sale_ids":[731,754,858,914,916,1081,1506,1592,1686,2291,2227,2047,2085,2091]},{"canonical_name":"SHAMPOO MINOXIDIL SECO","qty":1,"is_pack":false,"sale_ids":[1122,1802,2273,2279]},{"canonical_name":"SKINREGENERATION 30GR","qty":1,"is_pack":false,"sale_ids":[680,698,788,814,845,976,979,1428,1465,1630,1643,2334,2156,2162,2262]},{"canonical_name":"ULTRA EYES ISDIN","qty":1,"is_pack":false,"sale_ids":[1507,1635,2169,2253,2316]},{"canonical_name":"ULTRAGLOW 30GR","qty":1,"is_pack":false,"sale_ids":[767,1033,1077,1539,1586,1627,1752,1770,1850,2254,2285]},{"canonical_name":"VITAL EYES ISDIN","qty":1,"is_pack":false,"sale_ids":[2140]},{"canonical_name":"ZINC 50MG x30","qty":0,"is_pack":false,"sale_ids":[1349]},{"canonical_name":"ZINC 50MG x30","qty":1,"is_pack":false,"sale_ids":[665,677,681,685,713,725,795,817,864,959,1070,1163,1169,1182,1345,1399,1532,1692,1845,1851,2130,2158,2163,2053,2098,2102,2103]}]
$json$::jsonb) as t(canonical_name text,qty numeric,is_pack boolean,sale_ids jsonb)
), expanded as (
  select g.canonical_name,g.qty,g.is_pack,(jsonb_array_elements_text(g.sale_ids))::bigint as sale_id
  from groups g
)
insert into public.aos_product_sale_fact_v1(
  sale_id,product_key,raw_alias_key,physical_qty,is_pack,resolution_status,resolution_source,locked,note
)
select e.sale_id,i.product_key,null,e.qty,e.is_pack,'RESOLVED','OWNER_XLSX_2026',true,'Owner-confirmed Phase 3 workbook'
from expanded e
join public.aos_product_identity_v1 i on i.canonical_name=e.canonical_name
on conflict (sale_id) do update set
  product_key=excluded.product_key,
  physical_qty=excluded.physical_qty,
  is_pack=excluded.is_pack,
  resolution_status='RESOLVED',
  resolution_source='OWNER_XLSX_2026',
  locked=true,
  note=excluded.note,
  updated_at=now();

-- 7) Six owner-confirmed rows intentionally excluded from product facts.
insert into public.aos_product_sale_fact_v1(
  sale_id,product_key,raw_alias_key,physical_qty,is_pack,resolution_status,resolution_source,locked,note
)
select x.sale_id,null,null,null,null,'EXCLUDED','OWNER_XLSX_2026',true,'Owner-confirmed: no canonical product assigned'
from unnest(array[1571,1611,1727,2159,2252,2310]::bigint[]) as x(sale_id)
on conflict (sale_id) do update set
  product_key=null,physical_qty=null,is_pack=null,resolution_status='EXCLUDED',resolution_source='OWNER_XLSX_2026',locked=true,note=excluded.note,updated_at=now();

-- 8) Derive raw alias keys only from current production descriptions; evidence stays in aos_ventas.
update public.aos_product_sale_fact_v1 f
set raw_alias_key=public.aos_product_normalize_alias_v2(v.descripcion),updated_at=now()
from public.aos_ventas v
where v.id=f.sale_id and f.resolution_source='OWNER_XLSX_2026';

-- 9) Build owner-confirmed aliases from locked facts. Quantity/pack defaults are set only when uniform.
with a as (
  select
    f.raw_alias_key as alias_key,
    min(v.descripcion) as alias_text,
    min(f.product_key) as product_key,
    case when count(distinct f.physical_qty)=1 then min(f.physical_qty) else null end as default_qty,
    case when count(distinct f.is_pack)=1 then bool_and(f.is_pack) else null end as default_is_pack,
    count(distinct f.product_key) as product_count
  from public.aos_product_sale_fact_v1 f
  join public.aos_ventas v on v.id=f.sale_id
  where f.locked=true and f.resolution_status='RESOLVED' and f.raw_alias_key is not null
  group by f.raw_alias_key
)
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack,source,confidence,active)
select alias_key,alias_text,product_key,default_qty,default_is_pack,'OWNER_XLSX_2026','OWNER_CONFIRMED',true
from a where product_count=1
on conflict (alias_key) do update set
  alias_text=excluded.alias_text,
  product_key=excluded.product_key,
  default_qty=excluded.default_qty,
  default_is_pack=excluded.default_is_pack,
  source='OWNER_XLSX_2026',
  confidence='OWNER_CONFIRMED',
  active=true,
  updated_at=now();

-- 10) Resolve any production product sales outside the owner seed (including later imports).
select public.aos_product_backfill_unlocked_v1();
