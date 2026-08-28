-- WA-4A.1B isolated TEST fixture mirroring the CURRENT active catalog shape: 167 services + 50 products.
-- Names are synthetic except selected pattern-sensitive examples. No PROD data is copied.
alter table public.aos_catalogo_servicios add column if not exists descripcion_clinica text;
alter table public.aos_catalogo_servicios add column if not exists composicion text;
alter table public.aos_catalogo_servicios add column if not exists indicaciones text;
alter table public.aos_catalogo_servicios add column if not exists contraindicaciones text;
alter table public.aos_catalogo_servicios add column if not exists perfil_paciente text;
alter table public.aos_catalogo_servicios add column if not exists info_extendida jsonb default '{}'::jsonb;

delete from public.aos_catalogo_servicios;

with category_counts(category,n) as (values
 ('ACIDO HIALURONICO',9),('APARATOLOGÍA',3),('BIOESTIMULADOR',12),('BIOREVITALIZACIÓN',11),
 ('CAPILAR',17),('CONSULTA',4),('CORPORAL',15),('CRIOLIPÓLISIS',3),('DETOX',2),('ENZIMAS',6),
 ('EXOSOMAS',4),('FACIALES',15),('GLÚTEOS',3),('HIFU',3),('MESOTERAPIA',8),('PEELINGS',4),
 ('PEPTONAS',1),('RF FRACCIONADA',4),('TOXINA',4),('VITAMINAS',39)
), generated as (
 select category,gs as i from category_counts cross join lateral generate_series(1,n) gs
), rows as (
 select category,i,
 case
   when category='ACIDO HIALURONICO' and i in (1,2) then 'PROFHILO TEST '||i
   when category='ACIDO HIALURONICO' and i in (3,4) then 'SUNEKO TEST '||i
   when category='ACIDO HIALURONICO' then 'AH ESTRUCTURAL TEST '||i
   when category='BIOREVITALIZACIÓN' and i in (1,2) then 'MCCM EXO TEST '||i
   when category='BIOREVITALIZACIÓN' then 'PINK GLOW TEST '||i
   when category='CAPILAR' and i=1 then 'DUTASTERIDE CAPILAR TEST'
   when category='CAPILAR' and i=2 then 'MESO CAPILAR MINOXIDIL TEST'
   when category='CAPILAR' and i=3 then 'EXOSOMAS HAIR TEST'
   when category='CAPILAR' and i=4 then 'PRP CAPILAR TEST'
   when category='CAPILAR' then 'CAPILAR TEST '||i
   when category='CONSULTA' and i=1 then 'CÁNULAS AZULES 23G'
   when category='CONSULTA' and i=2 then 'CÁNULAS ROSADAS 18G'
   when category='CONSULTA' then 'CONSULTA TEST '||i
   when category='DETOX' then case when i=1 then 'DETOX IÓNICO' else 'DETOX IÓNICO x2' end
   when category='FACIALES' and i in (1,2,3) then 'HIDROFACIAL TEST '||i
   when category='GLÚTEOS' then 'GLÚTEOS TEST '||i
   when category='MESOTERAPIA' and i in (1,2) then 'DERMAPEN PRP TEST '||i
   when category='MESOTERAPIA' then 'DERMAPEN VIT TEST '||i
   when category='RF FRACCIONADA' and i in (1,2) then 'RF FRACCIONADA BRAZO TEST '||i
   when category='RF FRACCIONADA' then 'RF FRACCIONADA ROSTRO/CUELLO TEST '||i
   when category='TOXINA' and i=1 then 'HIPERHIDROSIS AXILAS'
   when category='TOXINA' and i=2 then 'HIPERHIDROSIS MANOS'
   when category='TOXINA' then 'NABOTA TEST '||i
   when category='VITAMINAS' and i=1 then 'HIERRO SACAROSA EV'
   when category='VITAMINAS' and i=2 then 'OZONO HEMOTERAPIA MENOR'
   when category='VITAMINAS' and i=3 then 'B12'
   when category='VITAMINAS' and i=4 then 'FULL B (EV o IM)'
   when category='VITAMINAS' and i=5 then 'VITAMINA C PASCOE 7.5G'
   when category='VITAMINAS' and i=6 then '1 SUPLEMENTO'
   else category||' TEST '||i end as name
 from generated
)
insert into public.aos_catalogo_servicios
(id,nombre,tipo,categoria,descripcion_clinica,descripcion_comercial,beneficios,composicion,indicaciones,contraindicaciones,perfil_paciente,precio_base,precio_oferta,faqs,estado,info_extendida,updated_at)
select gen_random_uuid(),name,'SERVICIO',category,
       'Descripción clínica TEST para '||name,
       case when category in ('VITAMINAS','DETOX') then null else 'Descripción comercial TEST para '||name end,
       'Beneficio TEST',
       case
         when category='VITAMINAS' then 'PLANTILLA DE CATEGORÍA — no fórmula individual'
         when category='DETOX' then 'Sistema electrofísico TEST'
         when category in ('MESOTERAPIA','ENZIMAS','EXOSOMAS','PEELINGS','GLÚTEOS','PEPTONAS','HIFU','CRIOLIPÓLISIS','RF FRACCIONADA','APARATOLOGÍA','CONSULTA') then null
         else 'Composición/fuente específica TEST'
       end,
       case when category in ('VITAMINAS','DETOX') then null else 'Indicación TEST' end,
       'Contraindicación TEST','Perfil TEST',100,90,
       '[{"q":"FAQ TEST","a":"Respuesta TEST"}]'::jsonb,'ACTIVO','{}'::jsonb,now()
from rows;

with category_counts(category,n) as (values
 ('CAPILAR ZV',7),('CORPORAL ZV',1),('FACIAL ZV',15),('FACIALES',5),('ISDIN',11),('NUTRICIONAL',11)
), generated as (
 select category,gs as i from category_counts cross join lateral generate_series(1,n) gs
), rows as (
 select category,i,
 case
   when category='CAPILAR ZV' and i=1 then 'ANTI HAIR LOSS CAPS MEN 30 UNID.'
   when category='CAPILAR ZV' and i=2 then 'ANTI HAIR LOSS CAPS WOMAN 30 UNID.'
   when category='CAPILAR ZV' and i=3 then 'ANTI HAIR LOSS SHAMPOO GRASO 150 ML'
   when category='CAPILAR ZV' and i=6 then 'APLICADOR MULTIZONA CAPILAR'
   when category='CORPORAL ZV' then 'PERFECT FORM B 90 GR'
   when category='FACIAL ZV' and i=1 then 'EXOFUSION ESSENCE 30 ML'
   when category='FACIAL ZV' and i=2 then 'LIFTING B 30GR'
   when category='FACIAL ZV' and i=3 then 'PERFECT FORM F 90 GR'
   when category='FACIAL ZV' and i=4 then 'LIP BALM ALOE VERA'
   when category='FACIALES' then 'POWER 10 TEST '||i
   when category='ISDIN' then 'ISDIN FACIAL TEST '||i
   when category='NUTRICIONAL' and i=1 then 'REDUFAST'
   when category='NUTRICIONAL' and i=2 then 'PRUNEX STICK x1'
   when category='NUTRICIONAL' and i=3 then 'PRUNEX STICK x3'
   when category='NUTRICIONAL' and i=4 then 'BEAUTY MAKER 330G'
   when category='NUTRICIONAL' and i=5 then 'HELIOCARE 240 MG 60 CÁPSULAS'
   when category='NUTRICIONAL' and i=6 then 'POLYPODIUM LEUCOTOMOS 480 MG 30 CÁPSULAS'
   when category='NUTRICIONAL' and i=7 then 'CITRATO DE MAGNESIO 400 MG 30 CÁPSULAS'
   else category||' PRODUCT TEST '||i end as name
 from generated
)
insert into public.aos_catalogo_servicios
(id,nombre,tipo,categoria,descripcion_clinica,descripcion_comercial,beneficios,composicion,indicaciones,contraindicaciones,perfil_paciente,precio_base,precio_oferta,faqs,estado,info_extendida,updated_at)
select gen_random_uuid(),name,'PRODUCTO',category,
       'Descripción clínica PRODUCT TEST','Descripción comercial PRODUCT TEST','Beneficio PRODUCT TEST',
       case when name in ('APLICADOR MULTIZONA CAPILAR','LIP BALM ALOE VERA') then null else 'Composición PRODUCT TEST' end,
       'Uso PRODUCT TEST','Precaución PRODUCT TEST','Perfil PRODUCT TEST',100,90,
       '[{"q":"FAQ PRODUCT TEST","a":"Respuesta PRODUCT TEST"}]'::jsonb,'ACTIVO','{}'::jsonb,now()
from rows;

-- Guard fixture shape before migrations.
do $$ begin
  if (select count(*) from public.aos_catalogo_servicios where estado='ACTIVO' and tipo='SERVICIO') <> 167 then
    raise exception 'fixture must contain 167 active services';
  end if;
  if (select count(*) from public.aos_catalogo_servicios where estado='ACTIVO' and tipo='PRODUCTO') <> 50 then
    raise exception 'fixture must contain 50 active products';
  end if;
end $$;
