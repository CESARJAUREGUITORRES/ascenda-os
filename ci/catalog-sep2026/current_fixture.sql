-- Synthetic exact baseline for CATALOG SEP2026.1. No PROD rows copied.
create extension if not exists pgcrypto;

drop table if exists public.aos_catalogo_reconciliation_lineage_v1 cascade;
drop function if exists public.aos_catalogo_reconciliation_lineage_immutable_guard_v1() cascade;
drop table if exists public.aos_catalogo_servicios cascade;

create table public.aos_catalogo_servicios (
 id uuid primary key default gen_random_uuid(),
 nombre text not null,
 nombre_corto text,
 tipo text default 'SERVICIO',
 dominio_id uuid,
 enfoque_id uuid,
 categoria text,
 descripcion_comercial text,
 descripcion_clinica text,
 indicaciones text,
 contraindicaciones text,
 duracion_sesion text,
 num_sesiones text,
 frecuencia text,
 precio_base numeric,
 precio_oferta numeric,
 tiene_variantes boolean default false,
 requiere_doctora boolean default false,
 requiere_enfermeria boolean default false,
 imagen_url text,
 tags text,
 estado text default 'ACTIVO',
 orden integer default 0,
 created_at timestamptz default now(),
 updated_at timestamptz default now(),
 composicion text,
 mecanismo_accion text,
 beneficios text,
 perfil_paciente text,
 faqs jsonb default '[]'::jsonb,
 info_extendida jsonb default '{"preexisting":{"keep":true}}'::jsonb,
 rol_proceso text,
 lenguaje_si text,
 lenguaje_no text,
 errores_mercado text,
 tipo_formulario text default 'GENERAL',
 requiere_control boolean default false,
 dias_control integer default 0,
 tipo_control text default '',
 unidades_envase integer,
 dosis_diaria numeric,
 duracion_estimada_dias integer,
 contenido_ml numeric,
 modo_uso_corto text,
 moneda text not null default 'PEN' check (moneda in ('PEN','USD'))
);

insert into public.aos_catalogo_servicios
(nombre,nombre_corto,tipo,categoria,num_sesiones,precio_base,precio_oferta,moneda,estado,composicion)
select n,n,'SERVICIO','BASELINE_PLACEHOLDER','1',100,90,'PEN','ACTIVO',
       case when n like 'HIPERHIDROSIS%' then 'Toxina botulínica tipo A (Nabota 100U o 200U).' else 'Composición TEST baseline' end
from unnest(array[
'DETOX IÓNICO','DETOX IÓNICO x2','VITAMINA C PASCOE 7.5G','FULL B (EV o IM)','B12','1 SUPLEMENTO','2 SUPLEMENTOS','3 SUPLEMENTOS','HIERRO SACAROSA EV','COC. VITC + 1 SUP','COC. VITC + 2 SUP','COC. VITC + 3 SUP','VITA POWER (VITC+CH+L+P)','VITC + FULL B + 1 SUP','VITC + FULL B + 2 SUP','VITC + FULL B + 3 SUP','FULL VITAMINAS PASCOE','VITC + B12 + 1 SUP','VITC + B12 + 2 SUP','VITC + B12 + 3 SUP','MEGA VITAMINAS PASCOE','DÚO ESENCIAL (VIT C + B12)','DÚO VITAL PASCOE','BYE BYE ESTRÉS PASCOE','ANTIESTRÉS PASCOE','HEPATOPROTECTOR','PACK HEPATOREGEN','PROTECCIÓN VITAL PASCOE','PROTECCIÓN TOTAL PASCOE','VITA DETOX PASCOE','PACK ANTIALÉRGICO','FULL B + 1 SUP','FULL B + 2 SUP','FULL B + 3 SUP','FULL VITAL','FULL B VITAL DETOX','B12 + 1 SUP','B12 + 2 SUP','B12 + 3 SUP','HIDROFACIAL ROSTRO','HIDROFACIAL ROSTRO PACK DÚO','HIDROFACIAL ROSTRO + CUELLO','HIDROFACIAL PREMIUM','HIDROFACIAL ANTIACNE','HIDROFACIAL ANTIACNE R+C','HIDROVITAL PASCOE','FACIAL DIAMANTE','FACIAL DIAMANTE R+C','FACIAL DIAMANTE PREMIUM','FACIAL CÉLULAS MADRE x1','FACIAL CÉLULAS MADRE x2','MASCARILLA ESTHEMAX','MASCARILLA Q10','DESCONGESTIVO PÁRPADOS','PQ AGE x1','PQ AGE 3x2','PINK INTIMATE','ZK 1 SESIÓN','DERMAPEN PRP FACIAL x1','DERMAPEN PRP FACIAL x3','DERMAPEN VIT FACIAL x1','DERMAPEN VIT FACIAL x3','PINK GLOW x1 SIN TARJETA','PINK GLOW x3','ÁC. TRANEXÁMICO x1','ÁC. TRANEXÁMICO x3','MCCM EXO TRX x1','MCCM EXO TRX x3','ÁC. SUCCÍNICO AMBER x1','ÁC. SUCCÍNICO AMBER x3','PINK GLOW 1ML','YOUTH HEALTH (EXOSOMAS+PDRN) x1','YOUTH HEALTH (EXOSOMAS+PDRN) x3','V TECH (PDRN+EXOSOMAS+CEL MADRE) x1','V TECH x3','ELLANSÉ M x1 (EUROPA)','ELLANSÉ M x2 (EUROPA)','RADIESSE x1 (USA)','RICH PL 5ML (ITALIA)','RICH PL 10ML (ITALIA)','NUCLEOFILL SOFT 1J','NUCLEOFILL SOFT 2J','NUCLEOFILL MEDIUM 1J','NUCLEOFILL MEDIUM 2J','NUCLEOFILL STRONG 1J','NUCLEOFILL STRONG 2J','MONALISA 1ML','SKINFILL ITALIA','SKINFILL BLUE x1','SKINFILL BLUE x2','SUNEKO PERFORMANCE x1','SUNEKO PERFORMANCE x3','BACCIO LABIOS','PROFHILO x1 ROSTRO','PROFHILO x2 ROSTRO','NABOTA 1 ZONA 15U','NABOTA 3 ZONAS 50U','HIPERHIDROSIS MANOS','HIPERHIDROSIS AXILAS','ENZIMAS FACIAL MCCM x1','ENZIMAS FACIAL MCCM x3','ENZIMAS FACIAL PBSERUM x1','ENZIMAS FACIAL PBSERUM x3','EXO SLIM PAPADA x1','EXO SLIM PAPADA x3','HIFU BEAUTY','HIFU FULL FACE','HIFU CISNE','RF FRACCIONADA ROSTRO/CUELLO x1','RF FRACCIONADA ROSTRO/CUELLO x3','RF FRACCIONADA BRAZO x1','RF FRACCIONADA BRAZO x3','PRP CAPILAR x1','PRP CAPILAR x3','HAIR COCTEL MESO x1','HAIR COCTEL MESO x3','DUTASTERIDE CAPILAR x1','DUTASTERIDE CAPILAR x3','EXOSOMAS EXOSIGNAL HAIR x1','EXOSOMAS EXOSIGNAL HAIR x3','RF FRACCIONADA CAPILAR x1','RF FRACCIONADA CAPILAR x3','MESO CAPILAR VIT x1','MESO CAPILAR VIT x3','CASCO REGENERADOR COLÁGENO','CARBOXI PACK 1 (2-4 zonas)','CARBOXI PACK 2 (4-8 zonas)','CARBOXI PLUS','MESOTERAPIA CORPORAL 2 AMP x1','MESOTERAPIA CORPORAL 4+2 AMP x3','HIDROENZIMAS x3 EN 1 VISITA','ENZIMAS CORP BRAZOS x1','ENZIMAS CORP BRAZOS x3','ENZIMAS CORP ABDOMEN/GLÚTEOS x1','ENZIMAS CORP ABDOMEN/GLÚTEOS x3','HIFU 7D BRAZOS','HIFU CORP ABDOMEN ALTO','HIFU CORP ABDOMEN BAJO','HIFU CORP ENTREPIERNAS 1Z','HIFU CORP ENTREPIERNAS 2Z','PACK APARATOLOGÍA REDUCTOR','PACK APARATOLOGÍA REAFIRMANTE','PACK POSTLIPO/POSTCIRUGÍA','CRIOLIPÓLISIS 1 ZONA','CRIOLIPÓLISIS 3+1 ZONAS','CRIOLIPÓLISIS 8+2 ZONAS','PEPTOPLUS x5','BIOESTIMULADOR GLÚTEOS POWERFILL','AH SKINFILL GLÚTEOS 10ML','AH SKINFILL GLÚTEOS 50ML','CONSULTA MÉDICA VIRTUAL','CONSULTA CIRUJANO PLÁSTICO','CÁNULAS AZULES 23G','CÁNULAS ROSADAS 18G','OZONO HEMOTERAPIA MENOR','OZONO HEMOTERAPIA x6','GENEFILL PLUS 1ML (KOREA)','MESO CAPILAR MINOXIDIL','OZONIFICACIÓN CAPILAR','PRP + OZONO x1','PRP + OZONO x3','BCN LUMEN 1ML','ORGANIC SILICA DMA 2.5ML','DERMAPEN PRP+VIT x1','DERMAPEN PRP+VIT x3','DERMAPEN VITAL FACE x1','DERMAPEN VITAL FACE x3'
]::text[]) n;

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
(nombre,nombre_corto,tipo,categoria,descripcion_comercial,descripcion_clinica,indicaciones,contraindicaciones,
 composicion,beneficios,perfil_paciente,precio_base,precio_oferta,faqs,moneda,estado)
select name,name,'PRODUCTO',category,'Descripción comercial PRODUCT TEST','Descripción clínica PRODUCT TEST',
       'Uso PRODUCT TEST','Precaución PRODUCT TEST',
       case when name in ('APLICADOR MULTIZONA CAPILAR','LIP BALM ALOE VERA') then null else 'Composición PRODUCT TEST' end,
       'Beneficio PRODUCT TEST','Perfil PRODUCT TEST',100,90,
       '[{"q":"FAQ PRODUCT TEST","a":"Respuesta PRODUCT TEST"}]'::jsonb,'PEN','ACTIVO'
from rows;

drop table if exists public.aos_catalogo_toppings cascade;
create table public.aos_catalogo_toppings (
 id text primary key default gen_random_uuid()::text,
 nombre text not null,
 categoria_vinculada text,
 precio numeric,
 descripcion text,
 tipo_pago text,
 sesiones text,
 estado text default 'ACTIVO',
 created_at timestamptz default now(),
 moneda text not null default 'PEN' check (moneda in ('PEN','USD'))
);

insert into public.aos_catalogo_toppings(nombre,categoria_vinculada,precio,sesiones,tipo_pago,estado,moneda)
select nombre,categoria,precio,sesiones,'SOLO_CON_SERVICIO','ACTIVO','PEN'
from (values
('MESOTERAPIA CAPILAR MINOXIDIL PINEDA','CAPILAR',99,''),('OZONIFICACIÓN CAPILAR','CAPILAR',49,''),('SESIÓN CASCO REGENERADOR + PEINE','CAPILAR',89,'X 3 SESIONES'),('CRIOLIPÓLISIS 1 ZONA ADICIONAL','CORPORAL',150,''),('DRENAJE LINFÁTICO','CORPORAL',0,''),('PACK APARATOLOGÍA REDUCTOR','CORPORAL',279,''),('AMBER GLOW 1ML (POR ZONA) + DERMAPEN','FACIALES',99,'HASTA QUE SE ACABE'),('BCN LUMEN 1ML (POR ZONA) + DERMAPEN','FACIALES',99,'PARA MANCHAS'),('MASCARILLA ESTHEMAX','FACIALES',49,''),('MASCARILLA Q10','FACIALES',49,''),('ORGANIC SILICA & DMA 2.5ML (POR ZONA) + DERMAPEN','FACIALES',99,'TENSOR & REGENERADOR'),('PINK GLOW 1ml (POR ZONA) + DERMAPEN','FACIALES',99,'REVITALIZADOR C/ PDRN'),('Pink Intimate (efecto aclarante)','FACIALES',99,'DESPIGMENTADOR'),('TRATAMIENTO DESCONGESTIVO DE PÁRPADOS','FACIALES',49,''),('ZK 1 SESIÓN','FACIALES',99,'PEELING'),('1 suplemento','VITAMINAS',59,''),('2 suplementos','VITAMINAS',79,''),('2da Full B','VITAMINAS',99,''),('2da vitamina C','VITAMINAS',110,''),('3 suplementos','VITAMINAS',99,'')
) v(nombre,categoria,precio,sesiones);

do $$ begin
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO')<>167 then raise exception 'fixture service baseline !=167'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO')<>50 then raise exception 'fixture product baseline !=50'; end if;
 if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>20 then raise exception 'fixture topping baseline !=20'; end if;
end $$;
